# CLAUDE.md

Guidance for Claude (and any other LLM agent) working in this repository.
Humans are also encouraged to read it — it doubles as the project guideline.

---

## What this project is

**karaoke-machine** is a plug-and-play Linux distribution for hosting karaoke parties.
Think *Batocera, but for UltraStar*.

Boot the ISO on a PC, plug in SingStar mics and a TV, drop songs into a network share,
and start singing. No terminal, no fiddling, no Linux knowledge required from the user.

## North star

A non-technical friend should be able to:

1. Flash the ISO to a USB stick.
2. Boot a random PC into karaoke mode.
3. Be singing within 60 seconds (assuming songs are already on the share).

If a step in that flow needs Linux knowledge, it is a bug.

## v1 scope (locked — do not expand without explicit approval)

**In scope (mandatory):**

- Bootable hybrid ISO for `x86_64` (BIOS + UEFI).
- Boots directly into UltraStar Deluxe (USDX) in fullscreen kiosk mode.
- Detects the classic SingStar USB stereo mic adapter and assigns
  Left → Player 1, Right → Player 2.
- Samba share `\\karaoke-machine\songs` (guest writable) for adding/managing songs.
- WiFi configurable via `nmtui` on tty2 (`Ctrl+Alt+F2`). Returning to tty1
  resumes the karaoke session.
- Verified boot + play on a Dell Optiplex (the test machine).

**Out of scope for v1 (do not be tempted):**

- Raspberry Pi / ARM builds.
- Auto-update mechanism.
- Web UI for configuration.
- YouTube / streaming integration (PiKaraoke-style).
- Multiple karaoke front-ends (UltraStar Play, WorldParty, OpenKJ, etc.).
- Read-only root filesystem (defer to v2 / Buildroot migration).
- Custom boot splash / theming.
- Pretty in-game wifi UI (tty2 + nmtui is enough).
- Song downloader, scoreboard server, anything cloud.

If a contributor or agent proposes any of the above, decline politely and point
them at `ROADMAP.md`.

## Key architectural decisions and *why*

| Decision               | Choice                       | Rationale (short)                                                                  |
| ---------------------- | ---------------------------- | ---------------------------------------------------------------------------------- |
| Base OS                | Debian 12 (Bookworm)         | Boring, stable, no Snap, well-documented `live-build` for custom ISOs.             |
| Karaoke front-end      | UltraStar Deluxe (Flatpak)   | Mature, active in 2025-2026, best SingStar mic story, simple SDL2 app.             |
| Display server         | Wayland via `cage`           | Cage is a single-window kiosk compositor — perfect for one-app appliance.          |
| Audio                  | PipeWire (Debian 12 default) | Modern, handles USB audio devices cleanly, compatible with PulseAudio clients.     |
| Networking             | NetworkManager + `nmtui`     | tty2 fallback is fine for v1. Replace with in-game UI in v3+.                      |
| File sharing           | Samba (guest writable)       | Universal — Windows / macOS / Linux all mount it without extra software.           |
| Init                   | systemd                      | Default on Debian; user services for the kiosk session.                            |
| ISO build tool         | `live-build`                 | Debian-native, reproducible, supports BIOS + UEFI hybrid ISOs.                     |
| Filesystem (installed) | Standard read-write ext4     | v1 keeps it simple. Read-only overlay is a v2 goal.                                |

If you change one of these, update the table and explain why.

## Why not Buildroot like Batocera (yet)?

Buildroot is the right answer eventually — tiny images, ~5s boot, read-only root,
trivial cross-architecture support. But:

- Every package change requires a partial rebuild.
- Packaging USDX as a Buildroot package is a project of its own.
- v1 is about *learning the problem domain* (mic detection, songs UX, audio
  routing on real hardware), not *learning a new build system*.

Plan: ship Debian-based v1, validate the UX, then migrate to Buildroot in v2
once we know exactly what we need.

## Repo layout

```
karaoke-machine/
├── CLAUDE.md                  # this file
├── README.md                  # user-facing intro and quickstart
├── ROADMAP.md                 # versioned milestones
├── LICENSE
├── build/                     # ISO build artifacts (gitignored)
├── iso/                       # live-build configuration
│   ├── auto/                  # live-build hooks
│   ├── config/
│   │   ├── package-lists/     # which Debian packages go in the ISO
│   │   ├── hooks/             # chroot scripts run during build
│   │   └── includes.chroot/   # files copied into the ISO root filesystem
│   └── README.md
├── overlay/                   # files that end up in / on the live system
│   ├── etc/
│   │   ├── samba/smb.conf
│   │   ├── systemd/system/
│   │   └── karaoke-machine/
│   ├── usr/local/bin/         # our scripts (kiosk launcher, mic setup, etc.)
│   └── home/karaoke/          # default user profile, USDX config templates
├── scripts/
│   ├── build-iso.sh           # one-shot ISO build
│   ├── test-qemu.sh           # boot the ISO in QEMU for fast iteration
│   ├── flash-usb.sh           # safer wrapper around dd
│   └── detect-singstar.sh     # runtime: writes USDX mic config
├── docs/
│   ├── singstar-mics.md       # how the SingStar dongle works, channel mapping
│   ├── kiosk-architecture.md  # what runs where, in what order
│   └── testing.md             # manual test checklist before tagging a release
└── .github/workflows/         # build the ISO on tag, publish to releases
```

## Common commands

> All commands assume you are at the repo root unless noted. Build commands
> need Docker; you do not need to run any of them as root.

```bash
# Build the ISO (writes to build/karaoke-machine-<version>.iso)
./scripts/build-iso.sh

# Boot the latest built ISO in QEMU for fast iteration
./scripts/test-qemu.sh

# Boot QEMU with USB audio passthrough (for testing the SingStar mic flow)
./scripts/test-qemu.sh --usb-audio

# Flash the latest ISO to a USB stick (interactive — asks before writing)
./scripts/flash-usb.sh /dev/sdX

# Run only the chroot hooks (faster iteration when tweaking overlay/)
./scripts/build-iso.sh --hooks-only

# Lint shell scripts
shellcheck scripts/*.sh overlay/usr/local/bin/*
```

## Conventions

- **Shell scripts** are POSIX `sh` where possible, `bash` only when needed.
  Always `set -euo pipefail` at the top of bash scripts. Run through
  `shellcheck` before committing.
- **Systemd units** for our own services live under `overlay/etc/systemd/system/`
  and are prefixed `karaoke-` (e.g. `karaoke-kiosk.service`,
  `karaoke-mic-setup.service`).
- **Configuration files** we ship to `/etc/karaoke-machine/` are the single source
  of truth. Per-user state goes in `~/.config/karaoke-machine/`.
- **The `karaoke` user** is the auto-login user. UID 1000. No password. No sudo.
  An admin can drop to tty3 and log in as `root` (password set at build time,
  default `karaoke` — document this loudly in `README.md`).
- **Songs** live at `/var/lib/karaoke-machine/songs/`. The Samba share, the USDX
  config, and any future tooling all point here. Never hardcode a different path.
- **Logging**: prefer `journalctl` (systemd journal) over writing to files.
  Our scripts use `logger -t karaoke-<name>` so logs are filterable.
- **Versioning**: SemVer. v0.x = pre-release, v1.0.0 = first stable ISO.

## What NOT to do

- **Do not** pull packages from third-party APT repos in the ISO build.
  Debian main + Flathub (for USDX) only. Each new source is a maintenance burden.
- **Do not** add a desktop environment. We have *one* app on screen, ever.
- **Do not** install a display manager (gdm/sddm/lightdm). `cage` launched
  by a systemd unit on tty1 is enough.
- **Do not** introduce a config file format other than INI / plain text /
  systemd unit syntax. No YAML for system config in v1.
- **Do not** auto-download anything at first boot (songs, updates, telemetry).
  v1 is fully offline-capable.
- **Do not** change the karaoke front-end without updating `ROADMAP.md` and
  this file's decision table.
- **Do not** assume internet access exists. The WiFi requirement is for *after*
  setup, not as a precondition.

## Testing approach

Two layers:

1. **QEMU smoke test** (every commit, eventually CI):
   - Boots to the kiosk session.
   - USDX window appears within N seconds of boot.
   - Samba share is reachable from the host.
   - `nmtui` works on tty2.
2. **Real-hardware test** (every tagged release, manual):
   - Dell Optiplex (the reference machine).
   - SingStar dongle plugged in → both mics register, both score independently
     in USDX's input test screen.
   - Songs dropped via Samba from a Mac and a Windows laptop appear in USDX
     after a rescan.
   - WiFi connect via `nmtui` succeeds and persists across reboot.

Manual checklist lives in `docs/testing.md`. **Do not tag a release without
running it on real hardware.**

## Working agreements for AI agents

- Read this file and `ROADMAP.md` before proposing changes.
- Prefer minimal, reversible changes. We are early — over-engineering compounds.
- When unsure between two approaches, pick the one that's easier to delete.
- If a task implies expanding v1 scope, stop and ask the human first.
- Always update `ROADMAP.md` when completing a milestone item, and update this
  file's decision table when changing an architectural choice.