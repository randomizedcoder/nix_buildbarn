#!/usr/bin/env bash
set -euo pipefail

# Usage: ./summarize_filtered_sizes.sh all_files_dev.txt

FILE_LIST="$1"

# List of filter paths (relative to image root, supports wildcards)
FILTER_PATHS=(
  # Documentation and localization (safe to remove)
  "share/locale"
  "share/doc"
  "share/man"
  "share/info"
  "share/gtk-doc"
  "share/terminfo"
  "share/tabset"
  "share/zoneinfo"
  "share/emacs"
  "share/bash-completion"
  "share/zsh"
  "share/fish"
  "share/vim"
  "share/nano"
  "share/readline"

  # Kernel headers (safe to remove)
  "usr/include/linux"
  "usr/include/asm"
  "usr/include/asm-generic"
  "usr/include/drm"
  "usr/include/mtd"
  "usr/include/rdma"
  "usr/include/scsi"
  "usr/include/sound"
  "usr/include/video"
  "usr/include/xen"

  # Debug symbols (safe to remove)
  "lib/debug"
  "usr/lib/debug"
  "usr/lib64/debug"

  # Static libraries (safe to remove if we have shared libraries)
  "lib/*.a"
  "lib/*.la"
  "lib/*.lai"
  "usr/lib/*.a"
  "usr/lib/*.la"
  "usr/lib/*.lai"
)

# Convert filter paths to regex patterns
FILTER_REGEX=()
for filter in "${FILTER_PATHS[@]}"; do
  # Escape dots, convert * to .*
  regex="^${filter//./\\.}"
  regex="${regex//\*/.*}"
  FILTER_REGEX+=("$regex")
done

declare -A size_by_path
for filter in "${FILTER_PATHS[@]}"; do
  size_by_path[$filter]=0
done

echo "Summing file sizes for filtered paths..."

while IFS=' ' read -r size path; do
  [ -z "$path" ] && continue
  # Remove nix store prefix
  path=${path#nix/store/*/}
  for i in "${!FILTER_REGEX[@]}"; do
    if [[ "$path" =~ ${FILTER_REGEX[$i]} ]]; then
      filter="${FILTER_PATHS[$i]}"
      ((size_by_path[$filter]+=size))
      break
    fi
  done
done < "$FILE_LIST"

echo -e "\nSummary of space used by filtered paths:"
for filter in "${FILTER_PATHS[@]}"; do
  size=${size_by_path[$filter]}
  # Pure Bash floating point MB calculation using printf
  mb=$(printf "%.2f" "$((size * 10000 / 1048576))e-4")
  printf '%-20s %10d bytes (%s MB)\n' "$filter" "$size" "$mb"
done