# iso/

[`live-build`][lb] configuration for the karaoke-machine ISO. Consumed by
`scripts/build-iso.sh` (lands in v0.1).

## Layout

- `auto/` — `live-build` automation hooks (`config`, `build`, `clean`)
- `config/package-lists/` — Debian packages installed into the ISO
- `config/hooks/` — chroot scripts executed during the build
- `config/includes.chroot/` — files copied verbatim into the ISO root
  filesystem. Built at runtime from `../overlay/` by
  `scripts/build-iso.sh` — edit `../overlay/` rather than this dir.

## Reference

- live-build manual: https://live-team.pages.debian.net/live-manual/
- Debian 12 (Bookworm) is the base distro — see CLAUDE.md decision table.

[lb]: https://wiki.debian.org/DebianLive
