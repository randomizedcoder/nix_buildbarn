#
# Makefile
#
# Makefile for nix_buildbarn flake

# --- Variables ---
# Get the system architecture Nix is using (e.g., x86_64-linux)
SYSTEM ?= $(shell nix eval --raw nixpkgs#system)

REPO_PREFIX := randomizedcoder
VERSION := $(shell cat VERSION)

NOUPX_BINARY_PKG := binary-bbRunner-noupx
UPX_BINARY_PKG := binary-bbRunner-upx
NOUPX_IMAGE_PKG := image-nix-scratch-bbRunner-noupx
UPX_IMAGE_PKG := image-nix-scratch-bbRunner-upx
NOUPX_DEV_IMAGE_PKG := image-nix-scratch-bbRunner-noupx-dev
UPX_DEV_IMAGE_PKG := image-nix-scratch-bbRunner-upx-dev

NOUPX_IMAGE_NAME := nix-bbrunner-noupx
UPX_IMAGE_NAME := nix-bbrunner-upx
NOUPX_DEV_IMAGE_NAME := nix-bbrunner-noupx-dev
UPX_DEV_IMAGE_NAME := nix-bbrunner-upx-dev

# # Define the target local registry (override with `make push-all LOCAL_REGISTRY=myregistry:port`)
# LOCAL_REGISTRY ?= localhost:5000

RESULT_NOUPX_BINARY := result-binary-noupx
RESULT_UPX_BINARY := result-binary-upx
RESULT_NOUPX_IMAGE := result-image-noupx.tar.gz
RESULT_UPX_IMAGE := result-image-upx.tar.gz
RESULT_NOUPX_DEV_IMAGE := result-image-noupx-dev.tar.gz
RESULT_UPX_DEV_IMAGE := result-image-upx-dev.tar.gz

# --- Phony Targets ---
.PHONY: all build-all load-all build-load-all \
        push-all push-image-scratch-noupx push-image-scratch-upx \
        build-binary-noupx build-binary-upx \
        build-image-scratch-noupx build-image-scratch-upx \
        build-image-scratch-noupx-dev build-image-scratch-upx-dev \
        build-dev build-nondev \
        load-image-scratch-noupx load-image-scratch-upx \
        load-image-scratch-noupx-dev load-image-scratch-upx-dev \
        clean help

all: help

help:
	@echo "Usage: make [TARGET]"
	@echo ""
	@echo "Available targets:"
	@echo "  build-binary-noupx           Build the non-UPX binary (${NOUPX_BINARY_PKG})"
	@echo "  build-binary-upx             Build the UPX-packed binary (${UPX_BINARY_PKG})"
	@echo "  build-image-scratch-noupx    Build the non-UPX scratch container image (${NOUPX_IMAGE_PKG})"
	@echo "  build-image-scratch-upx      Build the UPX-packed scratch container image (${UPX_IMAGE_PKG})"
	@echo "  build-image-scratch-noupx-dev Build the non-UPX scratch container image with dev tools (${NOUPX_DEV_IMAGE_PKG})"
	@echo "  build-image-scratch-upx-dev   Build the UPX-packed scratch container image with dev tools (${UPX_DEV_IMAGE_PKG})"
	@echo "  build-dev                     Build both dev container images (with dev tools)"
	@echo "  build-nondev                  Build both non-dev container images (without dev tools)"
	@echo "  build-all                    Build all container images"
	@echo "  load-image-scratch-noupx     Load non-UPX image into Docker and show info"
	@echo "  load-image-scratch-upx       Load UPX image into Docker and show info"
	@echo "  load-image-scratch-noupx-dev Load non-UPX dev image into Docker and show info"
	@echo "  load-image-scratch-upx-dev   Load UPX dev image into Docker and show info"
	@echo "  load-all                     Load all images into Docker and show info"
	@echo "  build-load-all               Build and load all container images into local Docker daemon"
	@echo "  push-image-scratch-noupx     Push non-UPX image to Docker Hub (${REPO_PREFIX}/${NOUPX_IMAGE_NAME})"
	@echo "  push-image-scratch-upx       Push UPX image to Docker Hub (${REPO_PREFIX}/${UPX_IMAGE_NAME})"
	@echo "  push-image-scratch-noupx-dev Push non-UPX dev image to Docker Hub (${REPO_PREFIX}/${NOUPX_DEV_IMAGE_NAME})"
	@echo "  push-image-scratch-upx-dev   Push UPX dev image to Docker Hub (${REPO_PREFIX}/${UPX_DEV_IMAGE_NAME})"
	@echo "  push-all                     Push all images to Docker Hub"
	@echo "  clean                        Remove Nix build result symlinks (result-*)"
	@echo "  help                         Show this help message"
	@echo ""

# --- Build Targets ---
build-binary-noupx:
	@echo "--> Building non-UPX binary..."
	nix build ".#${NOUPX_BINARY_PKG}" -o "${RESULT_NOUPX_BINARY}"

build-binary-upx:
	@echo "--> Building UPX binary..."
	nix build ".#${UPX_BINARY_PKG}" -o "${RESULT_UPX_BINARY}"

build-image-scratch-noupx: ${RESULT_NOUPX_IMAGE}
${RESULT_NOUPX_IMAGE}: flake.nix flake.lock VERSION
	@echo "--> Building non-UPX scratch image..."
	nix build ".#${NOUPX_IMAGE_PKG}" -o "${RESULT_NOUPX_IMAGE}"

build-image-scratch-upx: ${RESULT_UPX_IMAGE}
${RESULT_UPX_IMAGE}: flake.nix flake.lock VERSION
	@echo "--> Building UPX scratch image..."
	nix build ".#${UPX_IMAGE_PKG}" -o "${RESULT_UPX_IMAGE}"

build-image-scratch-noupx-dev: ${RESULT_NOUPX_DEV_IMAGE}
${RESULT_NOUPX_DEV_IMAGE}: flake.nix flake.lock VERSION
	@echo "--> Building non-UPX scratch image with dev tools..."
	nix build ".#${NOUPX_DEV_IMAGE_PKG}" -o "${RESULT_NOUPX_DEV_IMAGE}"

build-image-scratch-upx-dev: ${RESULT_UPX_DEV_IMAGE}
${RESULT_UPX_DEV_IMAGE}: flake.nix flake.lock VERSION
	@echo "--> Building UPX scratch image with dev tools..."
	nix build ".#${UPX_DEV_IMAGE_PKG}" -o "${RESULT_UPX_DEV_IMAGE}"

build-dev: build-image-scratch-noupx-dev build-image-scratch-upx-dev
	@echo "--> Built both dev container images"

build-nondev: build-image-scratch-noupx build-image-scratch-upx
	@echo "--> Built both non-dev container images"

build-all: build-nondev build-dev
	@echo "--> Built all container images"

# --- Load & Info Targets ---
load-image-scratch-noupx: ${RESULT_NOUPX_IMAGE}
	@echo "--> Loading and getting info for non-UPX image (${REPO_PREFIX}/${NOUPX_IMAGE_NAME}:latest)..."
	docker load -i "${RESULT_NOUPX_IMAGE}"
	@echo "--- Image Info (${REPO_PREFIX}/${NOUPX_IMAGE_NAME}:latest) ---"
	@docker images "${REPO_PREFIX}/${NOUPX_IMAGE_NAME}:latest"
	@echo "Number of layers: $$(docker history --no-trunc --format "{{.ID}}" "${REPO_PREFIX}/${NOUPX_IMAGE_NAME}:latest" | wc -l)"

load-image-scratch-upx: ${RESULT_UPX_IMAGE}
	@echo "--> Loading and getting info for UPX image (${REPO_PREFIX}/${UPX_IMAGE_NAME}:latest)..."
	docker load -i "${RESULT_UPX_IMAGE}"
	@echo "--- Image Info (${UPX_IMAGE_NAME}:latest) ---"
	@docker images "${UPX_IMAGE_NAME}:latest"
	@echo "Number of layers: $$(docker history --no-trunc --format "{{.ID}}" "${UPX_IMAGE_NAME}:latest" | wc -l)"

load-image-scratch-noupx-dev: ${RESULT_NOUPX_DEV_IMAGE}
	@echo "--> Loading and getting info for non-UPX dev image (${REPO_PREFIX}/${NOUPX_DEV_IMAGE_NAME}:latest)..."
	docker load -i "${RESULT_NOUPX_DEV_IMAGE}"
	@echo "--- Image Info (${REPO_PREFIX}/${NOUPX_DEV_IMAGE_NAME}:latest) ---"
	@docker images "${REPO_PREFIX}/${NOUPX_DEV_IMAGE_NAME}:latest"
	@echo "Number of layers: $$(docker history --no-trunc --format "{{.ID}}" "${REPO_PREFIX}/${NOUPX_DEV_IMAGE_NAME}:latest" | wc -l)"

load-image-scratch-upx-dev: ${RESULT_UPX_DEV_IMAGE}
	@echo "--> Loading and getting info for UPX dev image (${REPO_PREFIX}/${UPX_DEV_IMAGE_NAME}:latest)..."
	docker load -i "${RESULT_UPX_DEV_IMAGE}"
	@echo "--- Image Info (${REPO_PREFIX}/${UPX_DEV_IMAGE_NAME}:latest) ---"
	@docker images "${REPO_PREFIX}/${UPX_DEV_IMAGE_NAME}:latest"
	@echo "Number of layers: $$(docker history --no-trunc --format "{{.ID}}" "${REPO_PREFIX}/${UPX_DEV_IMAGE_NAME}:latest" | wc -l)"

load-all: load-image-scratch-noupx load-image-scratch-upx load-image-scratch-noupx-dev load-image-scratch-upx-dev

build-load-all: load-all
	@echo "--> All images built and loaded into local Docker daemon"

# --- Docker Hub Push Targets ---
push-image-scratch-noupx: ${RESULT_NOUPX_IMAGE}
	@echo "--> Tagging and Pushing non-UPX image to Docker Hub (${REPO_PREFIX}/${NOUPX_IMAGE_NAME}:${VERSION})..."
	docker tag "${REPO_PREFIX}/${NOUPX_IMAGE_NAME}:latest" "${REPO_PREFIX}/${NOUPX_IMAGE_NAME}:${VERSION}"
	docker tag "${REPO_PREFIX}/${NOUPX_IMAGE_NAME}:latest" "${REPO_PREFIX}/${NOUPX_IMAGE_NAME}:latest"
	docker push "${REPO_PREFIX}/${NOUPX_IMAGE_NAME}:${VERSION}"
	docker push "${REPO_PREFIX}/${NOUPX_IMAGE_NAME}:latest"
	@echo "--> Pushed ${REPO_PREFIX}/${NOUPX_IMAGE_NAME}:${VERSION} and :latest"

push-image-scratch-upx: ${RESULT_UPX_IMAGE}
	@echo "--> Tagging and Pushing UPX image to Docker Hub (${REPO_PREFIX}/${UPX_IMAGE_NAME}:${VERSION})..."
	docker tag "${REPO_PREFIX}/${UPX_IMAGE_NAME}:latest" "${REPO_PREFIX}/${UPX_IMAGE_NAME}:${VERSION}"
	docker tag "${REPO_PREFIX}/${UPX_IMAGE_NAME}:latest" "${REPO_PREFIX}/${UPX_IMAGE_NAME}:latest"
	docker push "${REPO_PREFIX}/${UPX_IMAGE_NAME}:${VERSION}"
	docker push "${REPO_PREFIX}/${UPX_IMAGE_NAME}:latest"
	@echo "--> Pushed ${REPO_PREFIX}/${UPX_IMAGE_NAME}:${VERSION} and :latest"

push-image-scratch-noupx-dev: ${RESULT_NOUPX_DEV_IMAGE}
	@echo "--> Tagging and Pushing non-UPX dev image to Docker Hub (${REPO_PREFIX}/${NOUPX_DEV_IMAGE_NAME}:${VERSION})..."
	docker tag "${REPO_PREFIX}/${NOUPX_DEV_IMAGE_NAME}:latest" "${REPO_PREFIX}/${NOUPX_DEV_IMAGE_NAME}:${VERSION}"
	docker tag "${REPO_PREFIX}/${NOUPX_DEV_IMAGE_NAME}:latest" "${REPO_PREFIX}/${NOUPX_DEV_IMAGE_NAME}:latest"
	docker push "${REPO_PREFIX}/${NOUPX_DEV_IMAGE_NAME}:${VERSION}"
	docker push "${REPO_PREFIX}/${NOUPX_DEV_IMAGE_NAME}:latest"
	@echo "--> Pushed ${REPO_PREFIX}/${NOUPX_DEV_IMAGE_NAME}:${VERSION} and :latest"

push-image-scratch-upx-dev: ${RESULT_UPX_DEV_IMAGE}
	@echo "--> Tagging and Pushing UPX dev image to Docker Hub (${REPO_PREFIX}/${UPX_DEV_IMAGE_NAME}:${VERSION})..."
	docker tag "${REPO_PREFIX}/${UPX_DEV_IMAGE_NAME}:latest" "${REPO_PREFIX}/${UPX_DEV_IMAGE_NAME}:${VERSION}"
	docker tag "${REPO_PREFIX}/${UPX_DEV_IMAGE_NAME}:latest" "${REPO_PREFIX}/${UPX_DEV_IMAGE_NAME}:latest"
	docker push "${REPO_PREFIX}/${UPX_DEV_IMAGE_NAME}:${VERSION}"
	docker push "${REPO_PREFIX}/${UPX_DEV_IMAGE_NAME}:latest"
	@echo "--> Pushed ${REPO_PREFIX}/${UPX_DEV_IMAGE_NAME}:${VERSION} and :latest"

push-all: push-image-scratch-noupx push-image-scratch-upx push-image-scratch-noupx-dev push-image-scratch-upx-dev

# --- Clean Target ---
clean:
	@echo "--> Cleaning Nix build results..."
	rm -f result-*

# --- nix flake stuff ---
update:
	nix flake update

build:
	nix flake build

#
docker_load:
	zcat result-image-noupx-dev.tar.gz | docker load

# end