# VCMI for RISC OS

The RISC OS port of [VCMI](https://github.com/vcmi/vcmi), the open-source
engine for Heroes of Might and Magic III: Shadow of Death / Complete.

This repository holds the RISC OS changes as patches on VCMI 1.7.5
(`patches/vcmi`), the scripts that cross-build it with
[riscos-crossdev](https://github.com/adyoull/riscos-crossdev), and the
`!VCMI` application around the program. You need the original game's files
to play; see `app/!VCMI/H3data/ReadMe,fff`.

**Status:** 1.7.5-riscos2 released (Raspberry Pi 4, RISC OS 5). Built on
GitHub in riscos-crossdev's container image on every push (BUILDING.md).

- `patches/vcmi/`: `git am` on VCMI's tag 1.7.5 (`series` gives the order).
- `patches/boost/`: one patch for Boost 1.83 (UnixLib has statfs, not statvfs).
- `patches/sdl2_mixer/`: a seek table for MP3 music (resuming a track no longer
  stops the sound) and mixing on request without an SDL audio device.
- `build/`: `build-deps.sh`, `build-vcmi.sh`, `package.sh`, versions and
  checksums (`env.sh`, `SHA256SUMS.txt`), and `ci.sh`, the whole build and
  tests as GitHub runs it. See BUILDING.md.
- `.riscos-deps`, `.github/workflows/`, `ci/`: the GitHub build and the daily
  check for new riscos-crossdev / riscos-mesa releases.
- `tests/`: host tests of the TBB stand-in, the presenter and the sound feeding.
- `app/!VCMI`: `!Run`, `!Boot`, `!Help`, the data folder's ReadMe.
- `tools/gogimport/!GOGImport`: a desktop tool that unpacks the game's
  files from the GOG.com installer on RISC OS (drag the installer onto it).
  It runs innoextract 1.9, built by `tools/innoextract/build.sh`;
  `tools/gogimport/package.sh` makes `dist/gogimport-1.0.zip`. No game
  files are in it.

VCMI is GPL-2.0-or-later; so are the RISC OS changes (COPYING).
Heroes of Might and Magic III is (c) Ubisoft and is not part of this.
