#!/usr/bin/env bash
# Build the karaoke-machine ISO via live-build inside a debian:12 container.
# Works on macOS and Linux hosts. Requires Docker.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO_CONFIG_DIR="$REPO_ROOT/iso"
OVERLAY_DIR="$REPO_ROOT/overlay"
BUILD_DIR="$REPO_ROOT/build"

VERSION="${VERSION:-}"
if [[ -z "$VERSION" && -f "$REPO_ROOT/version.txt" ]]; then
  VERSION="$(<"$REPO_ROOT/version.txt")"
fi
if [[ -z "$VERSION" ]]; then
  VERSION="$(git -C "$REPO_ROOT" describe --always --dirty --tags 2>/dev/null || echo dev)"
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found in PATH. Install Docker Desktop (macOS) or docker.io (Linux)." >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"

echo ">>> Building karaoke-machine ISO version: $VERSION"

# The live-build chroot is created via debootstrap, which requires `mknod` to
# populate /dev. Bind-mounted host directories on macOS (Docker Desktop /
# OrbStack) are exposed with noexec/nodev and reject mknod, so we copy the
# config into a container-native path before building, then copy the produced
# ISO back into the host-mounted output dir.
docker run --rm --privileged \
  -v "$ISO_CONFIG_DIR":/srv/iso:ro \
  -v "$OVERLAY_DIR":/srv/overlay:ro \
  -v "$BUILD_DIR":/out \
  -e VERSION="$VERSION" \
  -e DEBIAN_FRONTEND=noninteractive \
  debian:12 \
  bash -euo pipefail -c '
    apt-get update -qq
    apt-get install -y --no-install-recommends \
      live-build debootstrap squashfs-tools xorriso \
      isolinux syslinux-common \
      grub-pc-bin grub-efi-amd64-bin \
      mtools dosfstools ca-certificates

    mkdir -p /build
    cp -a /srv/iso/. /build/

    # overlay/ is the canonical source of files that end up in the live
    # filesystem; live-build expects them under config/includes.chroot/.
    mkdir -p /build/config/includes.chroot
    cp -a /srv/overlay/. /build/config/includes.chroot/
    # Drop scaffolding placeholders from empty overlay dirs.
    find /build/config/includes.chroot -name .gitkeep -delete

    cd /build
    lb config
    lb build

    cp -f /build/*.iso /out/
  '

iso_src="$(find "$BUILD_DIR" -maxdepth 1 -type f -name '*.iso' -print -quit)"
if [[ -z "$iso_src" ]]; then
  echo "No ISO produced by live-build." >&2
  exit 1
fi

iso_dest="$BUILD_DIR/karaoke-machine-${VERSION}.iso"
if [[ "$iso_src" != "$iso_dest" ]]; then
  mv "$iso_src" "$iso_dest"
fi
( cd "$BUILD_DIR" && sha256sum "$(basename "$iso_dest")" > "$(basename "$iso_dest").sha256" )

echo ">>> Built: $iso_dest"
echo ">>> SHA256: $(cut -d' ' -f1 "$iso_dest.sha256")"
