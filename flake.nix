#
# https://github.com/randomizedcoder/nix_buildbarn
#
#
# https://github.com/buildbarn/bb-aremote-execution/blob/master/cmd/bb_runner/main.go
#
# https://github.com/buildbarn
#
# https://github.com/buildbarn/bb-deployments/tree/master?tab=readme-ov-file#example-deployments-of-buildbarn
#
# flake.nix
#
{
  description = "A Nix flake to build buildbarn";

  inputs = {
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        appVersion = builtins.readFile ./VERSION;

        # Common ldflags for Go builds
        #commonLdflags = [ "-s" "-w" "-X main.version=${appVersion}" "-X main.commit=nix-build" "-X main.date=unknown" ];
        commonLdflags = [ "-s" "-w" ];
        # Common buildFlags for Go builds
        #commonBuildFlags = [ "-tags=netgo,osusergo" "-trimpath" ];
        commonTags = [ "netgo" "osusergo" ];

        # --- Base Binary Derivations ---

        bbRunner = pkgs.buildGoModule {
          pname = "bbRunner";
          version = appVersion;

          src = pkgs.fetchFromGitHub {
            owner = "buildbarn";
            repo = "bb-remote-execution";
            #rev = "master";
            rev = "1c726bdc27e7793c685d8788913f8f91f59bc887"; # repo doesn't have tags?  using commit from 2025 May 3rd
            #hash = pkgs.lib.fakeSha256;
            hash = "sha256-TBkIWE3A/GN6IDTp1/7Y2wCAX21j//1+DZNESum8L2M=";
          };
          subPackages = [ "cmd/bb_runner" ];
          # Ensure this hash is updated when go.mod/go.sum changes
          # Run: nix build .#bbRunner --rebuild
          #vendorHash = pkgs.lib.fakeSha256; # I don't know why this doesn't work
          #vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          vendorHash = "sha256-3ppaT3biRIPBe3ZQgheuFs19fBrR57T0vwwBMU0CTqM=";
          ldflags = commonLdflags;
          #buildFlags = commonBuildFlags;
          #env = { CGO_ENABLED = 0; };
          tags = commonTags;
          enableCgo = false;
        };

        # --- UPX Packed Binary Derivations ---

        bbRunnerUpx = pkgs.runCommand "bbRunnerUpx" {
          nativeBuildInputs = [ pkgs.upx ];
          src = bbRunner;
        } ''
          mkdir -p $out/bin
          # The binary name comes from the subPackages entry 'cmd/bb_runner'
          local input_binary_name="bb_runner"
          local output_binary_name="bbRunner"
          local orig_bin="$src/bin/$input_binary_name"
          echo "Original size ($(basename $orig_bin)): $(ls -lh $orig_bin | awk '{print $5}')"
          upx --best --lzma -o "$out/bin/$output_binary_name" "$orig_bin"
          echo "Compressed size ($(basename $out/bin/$output_binary_name)): $(ls -lh $out/bin/$output_binary_name | awk '{print $5}')"
          chmod +x "$out/bin/$output_binary_name"
        '';

        etcFiles = pkgs.runCommand "etc-files" {} ''
          mkdir -p $out/etc
          echo 'nogroup:x:65534:' > $out/etc/group
          echo 'nobody:x:65534:65534:Nobody:/:/sbin/nologin' > $out/etc/passwd
        '';

        versionFilePkg = pkgs.runCommand "version-file" {} ''
          mkdir -p $out
          cp ${./VERSION} $out/VERSION
        '';

        buildImage = { name, tag ? "latest", baseImage ? null, binaryPkg, extraContents ? [], extraCommands ? "" }:
          pkgs.dockerTools.buildLayeredImage {
            inherit name tag;
            fromImage = baseImage;
            contents = [ binaryPkg versionFilePkg etcFiles ] ++ extraContents;
            config = {
              User = "nobody";
              WorkingDir = "/";
              ExposedPorts = { "9980/tcp" = {}; };
              Cmd = [ "${binaryPkg}/bin/bbRunner" ];
            };
            extraCommands = extraCommands;
          };

        # --- Image Derivations

        # Scratch + bbRunner + NoUPX
        imageNixScratchbbRunnerNoupx = buildImage {
          name = "randomizedcoder/nix-bbRunner-noupx";
          binaryPkg = bbRunner;
        };

        # Scratch + bbRunner + UPX
        imageNixScratchbbRunnerUpx = buildImage {
          name = "randomizedcoder/nix-bbRunner-upx";
          binaryPkg = bbRunnerUpx;
        };

        # Scratch + bbRunner + NoUPX + DevTools
        imageNixScratchbbRunnerNoupxDev = buildImage {
          name = "randomizedcoder/nix-bbRunner-noupx-dev";
          binaryPkg = bbRunner;
          extraContents = [ devTools ];
        };

        # Scratch + bbRunner + UPX + DevTools
        imageNixScratchbbRunnerUpxDev = buildImage {
          name = "randomizedcoder/nix-bbRunner-upx-dev";
          binaryPkg = bbRunnerUpx;
          extraContents = [ devTools ];
        };

        # Filtered development tools package (just use devTools)
        filteredDevTools = devTools;

        # Scratch + bbRunner + NoUPX + FilteredDevTools with pruning via extraCommands
        imageNixScratchbbRunnerNoupxFilteredDev = buildImage {
          name = "randomizedcoder/nix-bbRunner-noupx-filtered-dev";
          binaryPkg = bbRunner;
          extraContents = [ devTools ];
          extraCommands = ''
            rm -rf share/locale
            rm -rf share/doc
            rm -rf share/man
            rm -rf share/info
            rm -rf share/gtk-doc
            rm -rf share/terminfo
            rm -rf share/tabset
            rm -rf share/zoneinfo
            rm -rf share/emacs
            rm -rf share/bash-completion
            rm -rf share/zsh
            rm -rf share/fish
            rm -rf share/vim
            rm -rf share/nano
            rm -rf share/readline
          '';
        };

        # Development tools package
        devTools = pkgs.buildEnv {
          name = "dev-tools";
          paths = with pkgs; [
            # Basic build tools
            bash
            gnumake
            automake
            libtool
            pkg-config
            ninja

            # Compression tools (needed for Go module downloads and C/C++ builds)
            gzip
            bzip2
            xz
            zstd

            # Binary packer (for Go binaries)
            upx

            # LLVM/Clang toolchain (needed for race detection and C/C++ builds)
            llvmPackages_19.libcxxClang
            llvmPackages_19.lld
            llvmPackages_19.libcxx.dev

            # Essential development libraries (minimal headers)
            glibc.dev
            stdenv.cc.cc.lib
            zlib.dev
            openssl.dev
            ncurses.dev

            # Build system generators (needed for C/C++ projects)
            flex
            bison

            # Go tools with race detection support
            go
            golint
            golangci-lint

            # Version control
            git
          ];
          extraOutputsToInstall = [ "out" ];
        };

      in
      {
        packages = {
          # Binaries
          binary-bbRunner-noupx = bbRunner;
          binary-bbRunner-upx = bbRunnerUpx;

          # Images
          image-nix-scratch-bbRunner-noupx = imageNixScratchbbRunnerNoupx;
          image-nix-scratch-bbRunner-upx = imageNixScratchbbRunnerUpx;
          image-nix-scratch-bbRunner-noupx-dev = imageNixScratchbbRunnerNoupxDev;
          image-nix-scratch-bbRunner-upx-dev = imageNixScratchbbRunnerUpxDev;
          image-nix-scratch-bbRunner-noupx-filtered-dev = imageNixScratchbbRunnerNoupxFilteredDev;

          # Default package for `nix build`
          default = self.packages.${system}.image-nix-scratch-bbRunner-noupx;
        };

        # --- Apps ---
        apps = {
          # Default app for `nix run`
          default = flake-utils.lib.mkApp {
            drv = self.packages.${system}.binary-bbRunner-noupx;
            exePath = "/bin/bbRunner";
          };

          # Apps to output image tarballs (useful for loading into Docker)
          image-scratch-bbRunner-noupx-tarball = flake-utils.lib.mkApp { drv = self.packages.${system}.image-nix-scratch-bbRunner-noupx; };
          image-scratch-bbRunner-upx-tarball = flake-utils.lib.mkApp { drv = self.packages.${system}.image-nix-scratch-bbRunner-upx; };
          image-scratch-bbRunner-noupx-dev-tarball = flake-utils.lib.mkApp { drv = self.packages.${system}.image-nix-scratch-bbRunner-noupx-dev; };
          image-scratch-bbRunner-upx-dev-tarball = flake-utils.lib.mkApp { drv = self.packages.${system}.image-nix-scratch-bbRunner-upx-dev; };
        };

        # --- Dev Shell ---
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bash
            #
            go
            gopls
            gotools
            golint
            golangci-lint
            #go-tools
            golangci-lint-langserver
            gomod2nix.packages.${system}.default
            #gomod2nix
            upx
            # https://github.com/bazelbuild/bazel/tags
            # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/tools/build-managers/bazel/bazel_7/default.nix#L524
            bazel_7
            # https://github.com/bazel-contrib/bazel-gazelle/tags
            # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/ba/bazel-gazelle/package.nix#L26
            bazel-gazelle
            bazel-buildtools
            bazelisk
            #
            curl
            jq
            #
            dive
          ];
          shellHook = ''
            export PS1='(nix-dev) \w\$ '
            echo "Entered Nix development shell for nix_buildbarn."
          '';

          # You might have other shell attributes here
          # Example: GOPATH = "${pkgs.buildGoModule}/share/go";
        };
      });
}
# end
