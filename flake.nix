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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    #nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
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
        commonBuildFlags = [ "-tags=netgo,osusergo" "-trimpath" ];

        # --- Base Binary Derivations ---

        bbRunner = pkgs.buildGoModule {
          pname = "bbRunner";
          version = appVersion;

          src = fetchFromGitHub {
            owner = "buildbarn";
            repo = "bb-remote-execution";
            #rev = "master";
            rev = "1c726bdc27e7793c685d8788913f8f91f59bc887"; # repo doesn't have tags?  using commit from 2025 May 3rd
            hash = pkgs.lib.fakeSha256;
            #hash = "";
          };
          subPackages = [ "cmd/bb_runner" ];
          # Ensure this hash is updated when go.mod/go.sum changes
          # Run: nix build .#bbRunner --rebuild
          vendorHash = pkgs.lib.fakeSha256;
          #vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          #vendorHash = "sha256-iMUa+OE/Ecb3TDw4PmvRfujo++T/r4g/pW0ZT63zIC4=";
          ldflags = commonLdflags;
          buildFlags = commonBuildFlags;
          env = { CGO_ENABLED = 0; };
        };

        # --- UPX Packed Binary Derivations ---

        bbRunnerUpx = pkgs.runCommand "bbRunnerUpx" {
          nativeBuildInputs = [ pkgs.upx ];
          src = bbRunner;
        } ''
          mkdir -p $out/bin
          local orig_bin="$src/bin/bbRunner"
          echo "Original size ($(basename $orig_bin)): $(ls -lh $orig_bin | awk '{print $5}')"
          upx --best --lzma -o $out/bin/bbRunner "$orig_bin"
          echo "Compressed size ($(basename $out/bin/bbRunner)): $(ls -lh $out/bin/bbRunner | awk '{print $5}')"
          chmod +x $out/bin/bbRunner
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

        # Helper function to build layered images
        buildImage = { name, tag ? "latest", baseImage ? null, binaryPkg, extraContents ? [] }:
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

      in
      {
        packages = {
          # Binaries
          binary-bbRunner-noupx = bbRunner;
          binary-bbRunner-upx = bbRunnerUpx;

          # Images
          image-nix-scratch-bbRunner-noupx = imageNixScratchbbRunnerNoupx;
          image-nix-scratch-bbRunner-upx = imageNixScratchbbRunnerUpx;

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
          # Update keys to match package names
          image-scratch-bbRunner-noupx-tarball = flake-utils.lib.mkApp { drv = self.packages.${system}.image-nix-scratch-bbRunner-noupx; };
          image-scratch-bbRunner-upx-tarball = flake-utils.lib.mkApp { drv = self.packages.${system}.image-nix-scratch-bbRunner-upx; };
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
            echo "Entered Nix development shell for go-nix-simple."
          '';

          # You might have other shell attributes here
          # Example: GOPATH = "${pkgs.buildGoModule}/share/go";
        };
      });
}
# end
