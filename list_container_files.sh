#!/usr/bin/env bash
set -euo pipefail

# List files in a Docker image by exporting the container and listing files with sizes
list_files_with_sizes() {
  local image_name="$1"
  local output_file="$2"

  # Create a temporary container
  container_id=$(docker create "$image_name")

  # Export the container's filesystem
  docker export "$container_id" > temp_container.tar

  # Extract to a temporary directory with correct ownership and permissions
  temp_dir=$(mktemp -d)
  tar --no-same-owner --no-same-permissions --mode='u+rwX,go+rX' -xf temp_container.tar -C "$temp_dir"

  # List all files with sizes (in bytes), relative to root
  find "$temp_dir" -type f -printf '%s %P\n' | sort -k2 > "$output_file"

  # Clean up
  docker rm "$container_id"
  rm temp_container.tar
  rm -rf "$temp_dir"
}

echo "Building containers..."
nix build .#image-nix-scratch-bbRunner-noupx-dev
nix build .#image-nix-scratch-bbRunner-noupx-filtered-dev

echo "Loading images into Docker..."
docker load < result

echo "Listing files for randomizedcoder/nix-bbrunner-noupx-dev into all_files_dev.txt..."
list_files_with_sizes randomizedcoder/nix-bbrunner-noupx-dev all_files_dev.txt

echo "Listing files for randomizedcoder/nix-bbrunner-noupx-filtered-dev into all_files_dev_filtered.txt..."
list_files_with_sizes randomizedcoder/nix-bbrunner-noupx-filtered-dev all_files_dev_filtered.txt

echo "Done! Check all_files_dev.txt and all_files_dev_filtered.txt for the results."