#!/usr/bin/env bash
# Build the karaoke-machine ISO via live-build inside a debian:12 container.
# Works on macOS and Linux hosts. Requires Docker.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO_CONFIG_DIR="$REPO_ROOT/iso"
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

docker run --rm --privileged \
  -v "$REPO_ROOT":/work \
  -w /work/iso \
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

    lb clean --purge >/dev/null 2>&1 || true
    lb config
    lb build
  '

# live-build emits the ISO into iso/ with a fixed name; rename it into build/.
iso_src="$(find "$ISO_CONFIG_DIR" -maxdepth 1 -type f -name '*.iso' -print -quit)"
if [[ -z "$iso_src" ]]; then
  echo "No ISO produced by live-build." >&2
  exit 1
fi

iso_dest="$BUILD_DIR/karaoke-machine-${VERSION}.iso"
mv "$iso_src" "$iso_dest"
( cd "$BUILD_DIR" && sha256sum "$(basename "$iso_dest")" > "$(basename "$iso_dest").sha256" )

echo ">>> Built: $iso_dest"
echo ">>> SHA256: $(cut -d' ' -f1 "$iso_dest.sha256")"
