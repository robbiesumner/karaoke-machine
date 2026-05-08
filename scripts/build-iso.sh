#!/usr/bin/env bash
# Build the karaoke-machine ISO via live-build inside a debian:12 container.
# Works on macOS and Linux hosts. Requires Docker.
#
# Usage:
#   ./scripts/build-iso.sh             full clean build (~10 min)
#   ./scripts/build-iso.sh --fast      reuse persistent chroot (~2-3 min)
#                                      use after the first full build to
#                                      iterate on overlay/ or config/hooks/
set -euo pipefail

FAST=0
for arg in "$@"; do
  case "$arg" in
    --fast|--hooks-only|--reuse) FAST=1 ;;
    --help|-h)
      sed -n '2,/^set /p' "$0" | sed 's/^# \?//;/^set /d'
      exit 0
      ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO_CONFIG_DIR="$REPO_ROOT/iso"
OVERLAY_DIR="$REPO_ROOT/overlay"
BUILD_DIR="$REPO_ROOT/build"
BUILD_VOLUME="karaoke-machine-build"

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
docker volume create "$BUILD_VOLUME" >/dev/null

echo ">>> Building karaoke-machine ISO version: $VERSION (fast=$FAST)"

# Bind-mounted host directories on macOS (Docker Desktop / OrbStack) reject
# mknod, which debootstrap needs to populate /dev. Keep the chroot inside a
# container-native named volume (lives on the Linux VM's filesystem and
# supports mknod) and only bind-mount the inputs (read-only) and the output
# directory.
docker run --rm --privileged \
  -v "$ISO_CONFIG_DIR":/srv/iso:ro \
  -v "$OVERLAY_DIR":/srv/overlay:ro \
  -v "$BUILD_DIR":/out \
  -v "$BUILD_VOLUME":/build \
  -e VERSION="$VERSION" \
  -e FAST="$FAST" \
  -e DEBIAN_FRONTEND=noninteractive \
  debian:12 \
  bash -euo pipefail -c '
    apt-get update -qq
    apt-get install -y --no-install-recommends \
      live-build debootstrap squashfs-tools xorriso \
      isolinux syslinux-common \
      grub-pc-bin grub-efi-amd64-bin \
      mtools dosfstools ca-certificates rsync

    sync_inputs() {
      # Refresh live-build config (auto/, config/, etc.) from source without
      # touching the persisted chroot/, cache/, or .build/ state.
      rsync -a --delete \
        --exclude=/chroot --exclude=/cache --exclude=/.build --exclude=/binary \
        --exclude=/*.iso --exclude=/*.contents --exclude=/*.files \
        --exclude=/*.packages --exclude=/binary.list \
        /srv/iso/ /build/

      # overlay/ → live-build expects files under config/includes.chroot/.
      rm -rf /build/config/includes.chroot
      mkdir -p /build/config/includes.chroot
      cp -a /srv/overlay/. /build/config/includes.chroot/
      find /build/config/includes.chroot -name .gitkeep -delete
    }

    cd /build

    if [[ "$FAST" = "1" && -d /build/chroot ]]; then
      echo ">>> Fast mode: reusing existing chroot, re-running chroot + binary stages"
      sync_inputs
      # Re-run the entire chroot stage (idempotent — apt sees packages
      # already installed, but re-runs includes, hooks, and re-stages the
      # kernel into chroot/boot which the binary stage needs) and the
      # binary stage. Keep .build/bootstrap_* so debootstrap is skipped.
      find /build/.build -maxdepth 1 -type f \
        \( -name "chroot_*" -o -name "binary_*" -o -name "build" \) -delete
      lb config
      lb build
    else
      if [[ "$FAST" = "1" ]]; then
        echo ">>> Fast mode requested but no chroot present yet — doing a full build"
      fi
      echo ">>> Full build: wiping persistent volume"
      find /build -mindepth 1 -delete 2>/dev/null || true
      cp -a /srv/iso/. /build/
      mkdir -p /build/config/includes.chroot
      cp -a /srv/overlay/. /build/config/includes.chroot/
      find /build/config/includes.chroot -name .gitkeep -delete
      lb config
      lb build
    fi

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
