# ROADMAP

karaoke-machine ships in small, demonstrable increments. Each milestone has an
**exit criterion** — a single sentence describing the test that proves we're
done. If you can't write the exit criterion, the milestone isn't ready to start.

---

## v0.1 — "It boots, and it sings"

**Goal:** end-to-end proof on the Dell Optiplex with the simplest possible setup.

- Set up the repo, `live-build` skeleton, and `scripts/build-iso.sh`.
- Produce a Debian 12 live ISO (BIOS + UEFI hybrid) that:
  - Auto-logs in as the `karaoke` user on tty1.
  - Launches `cage` with USDX (Flatpak) as the only app.
- Songs sourced from a hardcoded `/var/lib/karaoke-machine/songs/` baked into the
  ISO with 2-3 free demo songs.
- No mic config yet — keyboard navigation only.

**Exit criterion:** boot the ISO from USB on the Optiplex, see USDX in
fullscreen, navigate the menu with the keyboard, and play one song through
the TV's HDMI audio.

---

## v0.2 — "SingStar mics work"

**Goal:** the iconic SingStar dongle Just Works™.

- Write `scripts/detect-singstar.sh` (runs at boot via
  `karaoke-mic-setup.service`) that:
  - Detects USB audio devices matching the SingStar VID/PID
    (and a fallback heuristic for generic USB stereo input).
  - Generates the relevant `[Record]` block in USDX's `config.ini`
    (channel L → player 1, channel R → player 2).
  - Re-runs on udev `add` events so hot-plugging works.
- Document the SingStar dongle's quirks in `docs/singstar-mics.md`
  (it shows up as a single 2-channel input device, not two devices).
- Add a "Test microphones" launcher script that opens USDX's input test page
  for quick verification.

**Exit criterion:** plug the SingStar dongle into the Optiplex, USDX shows
two active inputs, both score independently in the input test screen.

---

## v0.3 — "Songs over the network"

**Goal:** anyone on the LAN can drop songs in.

- Add `samba` to the package list.
- Ship `/etc/samba/smb.conf` with a single guest-writable share `[songs]`
  pointing to `/var/lib/karaoke-machine/songs/`.
- Set the system hostname to `karaoke-machine` so `\\karaoke-machine\songs` resolves
  via mDNS (install `avahi-daemon`).
- Add a `karaoke-songs-rescan.path` systemd unit that watches the songs
  directory and tells USDX (or just restarts the kiosk session) when files
  change. Acceptable v1 behavior: songs appear after USDX is restarted from
  its menu.
- Permissions: songs dir is `karaoke:karaoke 0775`. Samba writes as the
  `karaoke` user.

**Exit criterion:** from a Mac and a Windows laptop on the same LAN, mount
`\\karaoke-machine\songs`, drop a USDX song folder in, restart USDX from its menu,
and the new song appears.

---

## v0.4 — "Wifi without a monitor swap"

**Goal:** get this thing online when you're at someone else's house.

- Install `network-manager` and ensure `nmtui` is available.
- Configure `getty@tty2.service` so `Ctrl+Alt+F2` lands you on a login prompt.
- Add a Message Of The Day on tty2 explaining: "Run `nmtui` to configure WiFi.
  Press `Ctrl+Alt+F1` to return to karaoke."
- Verify wifi credentials persist across reboots (NetworkManager default).

**Exit criterion:** boot a fresh ISO on the Optiplex with no ethernet, switch
to tty2, run `nmtui`, connect to a WPA2 network, switch back to tty1, and the
Samba share is reachable from a phone on that same network.

---

## v0.5 — "Polish for v1"

**Goal:** turn the working prototype into something you'd hand to a friend.

- A first-boot screen if the songs directory is empty: "Plug a USB stick with
  songs into a port, or copy songs to `\\karaoke-machine\songs` from your computer."
- Boot messages quieted (`quiet splash` kernel cmdline; no Plymouth theme yet).
- ISO compressed (`xz`), target ≤ 1.5 GB.
- `README.md` with: download link, "how to flash", "how to add songs",
  "where to get songs", troubleshooting.
- `docs/testing.md` checklist filled in and signed off on the Optiplex.

**Exit criterion:** a friend who has never used Linux can flash the ISO using
Balena Etcher on their Mac, boot it on the Optiplex, follow the README, and
sing a song they added themselves — without asking us a single question.

---

## v1.0 — "First public release"

- All v0.x milestones complete and signed off on the Optiplex.
- ISO published to GitHub Releases with SHA256SUMS.
- Source tag matches release.
- `README.md` finalized; project page on GitHub looks presentable.
- A short demo video / GIF in the README.

**Exit criterion:** v1.0.0 tag is pushed, ISO is downloadable, three people
outside the project have successfully used it.

---

## Beyond v1 (rough ideas, unsorted, no commitment)

- **v1.1 — Hardware coverage:** test on 3-5 more x86 machines, fix what breaks.
  Document a "known-good hardware" list.
- **v1.2 — More input devices:** generic USB mics, Bluetooth mics, jack splitter
  setups.
- **v1.3 — In-kiosk WiFi UI:** small overlay launched from a USDX hotkey, no
  more tty switching for end users.
- **v2.0 — Buildroot rewrite:** read-only root, ~5s boot, single 600MB image,
  proper appliance feel. Migrate the configs and scripts; keep the same UX.
- **v2.x — More front-ends behind a chooser:** UltraStar Play, PiKaraoke (for
  YouTube mode), Performous (for guitar/drums) — pick at boot or hot-swap from
  a menu.
- **v2.x — Raspberry Pi 5 build:** once on Buildroot, ARM is a config flip.
- **v3 — Auto-update channel:** signed images, A/B partitions.
- **v3 — Phone as remote:** companion app for queueing songs (PiKaraoke does
  this nicely; UltraStar Play has a phone-as-mic mode too).
- **v3 — Song downloader:** integration with the major USDX song archives
  (legality permitting).

Anything in the "Beyond v1" list is fair game to discuss but **not** to
implement before v1.0.0 ships.