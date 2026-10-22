# Building VCMI for RISC OS

On x86-64 Linux (or the riscos-crossdev container image), with git, cmake
3.16+, ninja, python3 and a host C++ compiler:

```
build/build-deps.sh     # Boost, minizip, SDL2_image, SDL2_ttf, SDL2_mixer -> work/stage
build/build-vcmi.sh     # VCMI 1.7.5 + patches/vcmi -> work/build-vcmi/bin/vcmiclient
build/package.sh        # !VCMI -> dist/vcmi-$VERSION.zip
tools/innoextract/build.sh   # innoextract 1.9 (bzip2, liblzma, Boost) -> work/inno/build/innoextract
tools/gogimport/package.sh   # !GOGImport -> dist/gogimport-1.0.zip
```

`build-deps.sh` clones riscos-crossdev at `CROSSDEV_REF` and installs its
prebuilt toolchain (expected in `dl/` as `TOOLCHAIN_TARBALL`, a
riscos-crossdev release on GitHub), and unpacks the riscos-mesa devkit
20.3.5-17 (`DEVKIT_TARBALL`, fetched from the riscos-mesa release on GitHub if
it isn't in `dl/`). 1.7.5-riscos2 was built with the test devkit 20.3.5-17e,
attached to that release. The other
tarballs are downloaded if missing; all are checked against
`build/SHA256SUMS.txt`.

Tests (host, need libsdl2-dev):

```
tests/tbbshim/run.sh    # TBB stand-in, ThreadSanitizer and ASan/UBSan
tests/present/run.sh    # presenter against a simple reference, ASan/UBSan
tests/sound/run.sh      # sound feeding into a simulated SharedSoundBuffer, ASan/UBSan and TSan
```

`build/ci.sh` does all of that (without innoextract) from a clean clone and
runs the tests: the build on GitHub.

## Building on GitHub

`.github/workflows/riscos-build.yml` runs `build/ci.sh` in riscos-crossdev's
container image (`ghcr.io/adyoull/riscos-crossdev:<version>`) on every push
and pull request, and keeps `dist/vcmi-ci.zip` as a download on the run's
page. `dl/` and `work/stage` are cached between runs.

`.riscos-deps` names the riscos-crossdev and riscos-mesa releases it's built
with; `build/env.sh` reads them. `.github/workflows/riscos-deps-update.yml`
checks every day for newer releases of those, and if there is one, moves the
pin (`ci/riscos-deps-hook.sh` adds a new devkit's sha256 to
`build/SHA256SUMS.txt`), builds with it and opens a pull request saying
whether the build passed. Nothing is released and nothing runs on RISC OS:
merge, test on a Pi, then release. See riscos-crossdev's `docs/CI.md`.

The update workflow needs, in Settings > Actions > General, "Workflow
permissions: Read and write" and "Allow GitHub Actions to create and approve
pull requests".

Editing the patches: commit in `work/vcmi` (branch `riscos`), then
`git -C work/vcmi format-patch -o patches/vcmi 1.7.5..riscos` and update
`patches/vcmi/series`.
