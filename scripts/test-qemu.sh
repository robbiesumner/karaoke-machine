#!/usr/bin/env bash
# Boot the most recently built karaoke-machine ISO in QEMU.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "${1:-}" == "--usb-audio" ]]; then
  echo "--usb-audio: not implemented yet (lands in v0.2 with SingStar work)." >&2
  exit 2
fi

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
  echo "qemu-system-x86_64 not found. Install QEMU:" >&2
  echo "  macOS: brew install qemu" >&2
  echo "  Debian/Ubuntu: sudo apt install qemu-system-x86" >&2
  exit 1
fi

shopt -s nullglob
isos=("$REPO_ROOT"/build/karaoke-machine-*.iso)
shopt -u nullglob
if (( ${#isos[@]} == 0 )); then
  echo "No ISO in build/. Run scripts/build-iso.sh first." >&2
  exit 1
fi
iso="${isos[0]}"
for f in "${isos[@]}"; do
  [[ "$f" -nt "$iso" ]] && iso="$f"
done

case "$(uname -s)" in
  Linux)  accel="kvm:tcg" ;;
  Darwin) accel="hvf:tcg" ;;
  *)      accel="tcg" ;;
esac

echo ">>> Booting $iso (accel=$accel)"
exec qemu-system-x86_64 \
  -accel "$accel" \
  -m 4G \
  -smp 2 \
  -cdrom "$iso" \
  -boot d \
  -vga virtio
