#!/usr/bin/env bash
# Flash the most recently built karaoke-machine ISO to a USB stick.
# Interactive — refuses to write without explicit confirmation, and refuses
# non-removable devices unless FORCE=1.
#
# Usage:
#   ./scripts/flash-usb.sh                    # list candidate devices and exit
#   ./scripts/flash-usb.sh /dev/sdX           # Linux
#   ./scripts/flash-usb.sh /dev/diskN         # macOS
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

list_candidates() {
  echo "Candidate removable devices:" >&2
  case "$(uname -s)" in
    Linux)
      # RM=1 means "removable", TRAN=usb covers most thumb drives.
      lsblk -d -o NAME,SIZE,MODEL,VENDOR,RM,TRAN | awk 'NR==1 || $5=="1" || $6=="usb"'
      ;;
    Darwin)
      diskutil list external 2>/dev/null || diskutil list
      ;;
    *)
      echo "Unsupported host: $(uname -s)" >&2
      ;;
  esac
}

device="${1:-}"
if [[ -z "$device" ]]; then
  echo "Usage: $0 /dev/sdX (Linux) or /dev/diskN (macOS)" >&2
  echo >&2
  list_candidates
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

iso_size_bytes=$(stat -f%z "$iso" 2>/dev/null || stat -c%s "$iso")

case "$(uname -s)" in
  Linux)
    if [[ ! -b "$device" ]]; then
      echo "Error: $device is not a block device" >&2
      exit 1
    fi
    is_rm=$(lsblk -dno RM "$device")
    if [[ "$is_rm" != "1" && "${FORCE:-0}" != "1" ]]; then
      echo "Error: $device is NOT a removable device." >&2
      echo "  Override with FORCE=1 if you are certain." >&2
      exit 1
    fi
    info=$(lsblk -d -o NAME,SIZE,MODEL,VENDOR,TRAN "$device")
    target_bytes=$(blockdev --getsize64 "$device" 2>/dev/null || echo 0)
    sudo_prefix=(sudo)
    write_target="$device"
    ;;
  Darwin)
    if [[ ! -e "$device" ]]; then
      echo "Error: $device does not exist" >&2
      exit 1
    fi
    info=$(diskutil info "$device" | grep -E "Device / Media Name:|Disk Size:|Removable Media:|Protocol:|Device Identifier:")
    if ! diskutil info "$device" | grep -q "Removable Media:.*Yes"; then
      if [[ "${FORCE:-0}" != "1" ]]; then
        echo "Error: $device is NOT marked as removable." >&2
        echo "  Override with FORCE=1 if you are certain." >&2
        exit 1
      fi
    fi
    target_bytes=$(diskutil info "$device" | awk -F'[()]' '/Disk Size:/ {print $2}' | awk '{print $1}')
    sudo_prefix=(sudo)
    # Use raw character device for ~10x faster writes on macOS
    write_target="${device/\/dev\/disk//dev/rdisk}"
    ;;
  *)
    echo "Unsupported host: $(uname -s)" >&2
    exit 1
    ;;
esac

if [[ -n "${target_bytes:-}" && "$target_bytes" -gt 0 && "$target_bytes" -lt "$iso_size_bytes" ]]; then
  echo "Error: target ($target_bytes bytes) is smaller than the ISO ($iso_size_bytes bytes)." >&2
  exit 1
fi

cat <<EOF

About to flash:
  ISO:    $iso
  Size:   $((iso_size_bytes / 1024 / 1024)) MiB
  Target: $device
$info

ALL DATA on $device WILL BE DESTROYED.
EOF

read -rp "Type the device path ($device) to confirm: " confirm
if [[ "$confirm" != "$device" ]]; then
  echo "Mismatch — abort." >&2
  exit 1
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  echo ">>> Unmounting $device"
  diskutil unmountDisk "$device"
fi

echo ">>> Writing ISO to $write_target"
case "$(uname -s)" in
  Linux)
    "${sudo_prefix[@]}" dd if="$iso" of="$write_target" bs=4M status=progress conv=fsync
    ;;
  Darwin)
    # macOS dd lacks status=progress; siginfo (Ctrl-T) shows progress instead.
    echo "    (Press Ctrl-T to see progress.)"
    "${sudo_prefix[@]}" dd if="$iso" of="$write_target" bs=4m
    ;;
esac

sync
echo ">>> Flush complete."

case "$(uname -s)" in
  Linux)
    echo ">>> Eject before unplugging:  sudo udisksctl power-off -b $device"
    ;;
  Darwin)
    echo ">>> Eject before unplugging:  diskutil eject $device"
    ;;
esac
