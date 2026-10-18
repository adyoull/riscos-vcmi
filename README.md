# VCMI for RISC OS

The RISC OS port of [VCMI](https://github.com/vcmi/vcmi), the open-source
engine for Heroes of Might and Magic III: Shadow of Death / Complete.

This repository holds the RISC OS changes as patches on VCMI 1.7.5
(`patches/vcmi`), the scripts that cross-build it with
[riscos-crossdev](https://github.com/adyoull/riscos-crossdev), and the
`!VCMI` application around the program. You need the original game's files
to play; see `app/!VCMI/H3data/ReadMe,fff`.

**Status:** first test builds, not yet run on RISC OS.

- `patches/vcmi/`: `git am` on VCMI's tag 1.7.5 (`series` gives the order).
- `patches/boost/`: one patch for Boost 1.83 (UnixLib has statfs, not statvfs).
- `build/`: `build-deps.sh`, `build-vcmi.sh`, `package.sh`, versions and
  checksums (`env.sh`, `SHA256SUMS.txt`). See BUILDING.md.
- `tests/`: host tests of the TBB stand-in and of the presenter.
- `app/!VCMI`: `!Run`, `!Boot`, `!Help`, the data folder's ReadMe.

VCMI is GPL-2.0-or-later; so are the RISC OS changes (COPYING).
Heroes of Might and Magic III is (c) Ubisoft and is not part of this.
