# Karaoke Kiosk

Plug-and-play karaoke appliance. NixOS, declarative, shipped as flashable ISO. Boots into UltraStar Deluxe (USDX). Songs added via Samba. Wireless keyboard is the only remote.

## North Star

**Trivial for non-technical users.** Target user: my mom. If a feature needs explaining, it's broken. When in doubt, remove a step.

- Plug in → boots into karaoke. No login, no menus.
- Mics work on plug-in. No config dialogs.
- Add songs → drop folder on network share.
- Navigate → arrow keys + Enter.

## Scope (v1)

- **Hardware:** Beelink N100 or similar fanless x86_64 mini PC, HDMI to TV.
- **Inputs:** 2x SingStar USB mics (composite device, 2 channels). 1x wireless USB-dongle keyboard with trackpad.
- **OS:** NixOS, custom installer ISO.
- **Engine:** UltraStar Deluxe, fullscreen kiosk.
- **Songs:** Local dir, exposed as read-write Samba share, no auth (LAN-only appliance).

**Not in v1:** companion service, HTTP API, phone UI, QR codes, queue management beyond USDX, cross-session scoreboards, non-keyboard remotes. See [Future work](#future-work).

## User flows

**First boot (owner, once):** flash ISO → installer wipes disk → TUI wizard on tty1 asks WiFi + hostname → writes config, touches sentinel, reboots → never shown again.

**Daily:** plug in → ~30s → USDX song-select on TV → arrow keys + Enter.

**Add songs:** mount `\\karaoke\songs` (or `smb://karaoke.local/songs`) → drop UltraStar folders (`.txt` + audio + optional cover/video) → press `R` in USDX to rescan. ISO ships zero songs (licensing).

## Architecture

Four NixOS modules:

1. **Kiosk session.** Autologin to `karaoke` user, no DM. Compositor launches USDX fullscreen. Crash → relaunch (never show desktop).
2. **Audio.** PipeWire exposes SingStar's 2 channels as independent mic inputs (not stereo).
3. **Samba.** Single share `songs` → `/var/lib/karaoke/songs/`, read-write, no auth.
4. **First-boot wizard.** Systemd unit, gated by sentinel, whiptail TUI on tty1, WiFi + hostname, reboots.

## Repository layout (target — bootstrap in progress)

```
flake.nix              # ISO, NixOS configs, devShell
nix/
  modules/
    kiosk.nix          # autologin, compositor, USDX launch loop
    audio.nix          # PipeWire + SingStar mics
    samba.nix          # songs share
    firstboot.nix      # TUI wizard
    networking.nix     # NetworkManager + avahi
  iso.nix              # installer ISO
  system.nix           # installed appliance config
docs/                  # end-user + contributor docs
```

## Conventions

**Nix:**
- Flakes only. Pin nixpkgs in `flake.lock`, update intentionally.
- Modules expose options under `services.karaoke.*`. `nix/system.nix` reads like an appliance description, not plumbing.
- `pkgs.writeShellApplication` over loose scripts in units.
- USDX from nixpkgs unless specific reason to override.

**Commits/PRs:** Conventional commits (`feat:`, `fix:`, `nix:`, `docs:`). One logical change per PR.

## Open decisions

- **Compositor:** `cage` (Wayland kiosk). S1 VM-tested: cage starts, USDX renders fullscreen via native Wayland (`SDL_VIDEODRIVER=wayland` in `karaoke-session` — without it sdl2-compat picks Xwayland and ABRTs cage on USDX exit via the wlroots `xwayland_surface_destroy` assert). Inner shell loop respawns USDX on SIGTERM/SIGKILL, systemd `Restart=always` recovers cage on rare wlroots crashes. VM caveats — only present in `vmVariant`, real HW unaffected: needs `-vga virtio`, `WLR_RENDERER_ALLOW_SOFTWARE=1` (no GPU acceleration in qemu, llvmpipe path only), and `SDL_AUDIODRIVER=dummy` (no audio stack until S2). VM perf is unusable (TCG + llvmpipe + VNC stack) — that's a VM artifact, not a kiosk issue; real Beelink performance verified at S7. If HW rendering is poor on the N100, fall back to Xorg + minimal WM.
- **Keyboard:** USB-dongle assumed. Bluetooth needs pre-pairing → breaks plug-and-play → v2.
- **Updates:** v1 = reflash ISO. Remote-flake `nixos-rebuild` is v2.
- **Auto-rescan:** v1 = press `R`. Filesystem watcher is nicer but more complex; reconsider after real-party usage.

## Gotchas

- **SingStar = 1 USB device, 2 channels.** PipeWire sees one source; USDX must treat ch1/ch2 as separate mics, not stereo. Config in `nix/modules/audio.nix`.
- **USDX on Wayland is flaky.** Xwayland or pure Xorg if needed. Don't over-engineer.
- **USDX scales weirdly on 4K.** Force 1080p in kiosk session.
- **mDNS/Samba** depends on router multicast. Wizard should show device IP at idle for `\\192.168.x.x\songs` fallback.
- **SMB:** default SMB2+. Don't accommodate ancient Windows.
- **Trackpad on the keyboard is irrelevant** to USDX. Don't design around it.

## Common commands

```bash
nix develop                                                 # dev shell
nix build .#iso                                             # build installer ISO → result/iso/karaoke-*.iso
nixos-rebuild build-vm --flake .#karaoke && ./result/bin/run-*-vm   # local VM of full system
nix fmt                                                     # format
nixos-rebuild switch --flake .#karaoke --target-host root@karaoke.local   # deploy to LAN device
```

Local-environment wrappers (e.g. ssh into Linux VM) belong in `CLAUDE.local.md`.

## Smoke test (before claiming a change works)

Boot the VM and verify:

- [ ] Boots to USDX song-select. No TTY, login, or desktop visible.
- [ ] Killing USDX → session relaunches it. No desktop in between.
- [ ] First-boot wizard runs once on fresh install, never again.
- [ ] Both SingStar channels show as independent inputs (`pactl list sources` or USDX audio config).
- [ ] Samba share mountable from LAN, no auth, read-write. Drop folder + press `R` → song appears.
- [ ] 1080p forced on 4K (or sane VM display).

Items not testable in VM (real mics, real 4K TV) → state explicitly in PR, don't tick.

## Future work

- **Phone remote/queue/scoreboard.** Likely path: companion service + USDX Lua plugin reporting game events (scores, song-finished) → web UI on LAN. USDX Lua plugins can make outbound HTTP, so integration is cleaner than it looks.
- **Auto-update.** `nixos-rebuild` from remote flake, gated on idle.
- **Auto-rescan** via filesystem watcher.
- **Bluetooth keyboard** with guided pairing on first boot.
- **Pre-curated song packs** if licensing-clean source exists.

## Roadmap

v1 broken into 7 sessions (S1–S7). See `docs/roadmap.md`. Pick the lowest unfinished session unless told otherwise.

## Working rules

- **Read this file before suggesting architecture changes.** v1 scope is intentionally narrow.
- **VM-test before assuming things work.** Kiosk, audio, wizard all differ from a normal desktop.
- **Treat the end user as my mom.** Power for steps/concepts she'd have to learn = wrong trade.
- **Fewer moving parts.** Every extra service/dep/knob breaks on a Saturday night.
