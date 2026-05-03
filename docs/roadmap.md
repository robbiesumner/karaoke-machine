# v1 roadmap

Bite-size sessions toward shippable v1. One PR per session. VM-test before merge. Tick smoke-test items in `CLAUDE.md` as they become true.

Order front-loads risk: USDX rendering and SingStar audio are the unknowns that could invalidate other work, so they come first.

---

## S1 — Kiosk skeleton

**Goal:** boot VM → fullscreen USDX. No login, no desktop.

- Resolve compositor: try `cage` first. If USDX (SDL) renders poorly, fall back to Xorg + `xinit` + single fullscreen window.
- `karaoke` user, autologin on tty1 (`services.getty.autologinUser`).
- Launch loop in `kiosk.nix` (`pkgs.writeShellApplication`): `while true; do usdx; sleep 1; done`.
- Force 1080p via `wlr-randr` / `xrandr` shim depending on compositor (gotcha: USDX scales weirdly on 4K).
- Record compositor outcome in `CLAUDE.md` "Open decisions".

**Smoke ticks:** boots to USDX without TTY/login/desktop. Killing USDX → relaunch.

## S2 — Audio (SingStar)

**Goal:** USDX sees two independent mic inputs.

- `services.pipewire.enable = true`, `pulse.enable = true` (SDL apps).
- Channel-split SingStar composite device: PipeWire `loopback` modules or `wireplumber` config splitting ch1/ch2 into two virtual sources.
- USDX INI written declaratively into `karaoke` user home, pointing at split sources.

VM can't fully verify — needs real dongle. State explicitly in PR: `pactl list sources` on hardware shows two named sources. VM uses stub source for eval.

## S3 — Samba share

**Goal:** drop song folder from another machine → appears in USDX after `R`.

- `services.samba.enable`. Single share `songs` → `/var/lib/karaoke/songs/`. `guest ok = yes`, `read only = no`, force user `karaoke`, SMB2+ min protocol.
- `tmpfiles.d` rule: dir owned by `karaoke`.
- Open ports 139/445.

**Smoke tick:** mount from Mac, drop public-domain UltraStar pack, press `R`, song appears.

## S4 — Networking + mDNS

**Goal:** `\\karaoke.local\songs` resolves on typical home LAN.

- `networking.networkmanager.enable = true`.
- `services.avahi.enable = true` with `nssmdns4 = true`, `publish.workstation = true`.
- Idle screen / MOTD shows current IP as fallback (gotcha: some routers block multicast).

## S5 — First-boot wizard

**Goal:** fresh install → tty1 wizard asks WiFi + hostname → writes config → reboots → never seen again.

- Systemd unit `karaoke-firstboot.service`, ordered before kiosk session.
- Gate: `ConditionPathExists=!/var/lib/karaoke/.firstboot-done`.
- whiptail TUI in `pkgs.writeShellApplication`. Validate: SSID non-empty, hostname matches `^[a-z0-9-]+$`.
- Writes `/etc/NetworkManager/system-connections/<ssid>.nmconnection` (mode 600), sets hostname via sidecar file, touches sentinel, `systemctl reboot`.
- Kiosk session blocked until sentinel exists.

**Smoke tick:** first boot runs wizard; second boot skips.

## S6 — Installer ISO

**Goal:** flash ISO → boot from USB → auto-install wipes disk → reboots into S5 wizard.

- Base on `installer/cd-dvd/installation-cd-base.nix`.
- Autoinstall script: partition (ESP + ext4 root), `nixos-install --flake .#karaoke`, reboot.
- Single confirmation prompt: "this will erase the disk, type ERASE to continue".
- Test in qemu with a blank disk image, not just `build-vm`.

## S7 — Real hardware bring-up

Beelink N100 + real SingStar + real keyboard + real TV.

- Flash → install → wizard → boot → sing.
- Walk every smoke-test item in `CLAUDE.md`.
- Capture surprises in `## Gotchas`.

---

## Order rationale

- **S1 first:** if cage/Wayland can't render USDX cleanly, all later sessions assume Xorg. Find out cheap.
- **S2 second:** SingStar channel-split has no fallback. Whole product hinges on it.
- **S3, S4:** routine NixOS, low risk.
- **S5** depends on S4 (wizard writes NM connection).
- **S6** depends on a working end-to-end `system.nix`.
- **S7** only after VM is green.

## Skip / defer

- End-user docs (`docs/flashing.md`, etc.) — write after S7, behavior still in flux until then.
- `nix flake check` CI — add once flake shape stabilizes.
- Anything in `## Future work`.
