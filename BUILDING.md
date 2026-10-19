# Building VCMI for RISC OS

On x86-64 Linux (or the riscos-crossdev container image), with git, cmake
3.16+, ninja, python3, ImageMagick (`convert`) and a host C++ compiler:

```
build/build-deps.sh     # Boost, minizip, SDL2_image, SDL2_ttf, SDL2_mixer -> work/stage
build/build-vcmi.sh     # VCMI 1.7.5 + patches/vcmi -> work/build-vcmi/bin/vcmiclient
build/package.sh        # !VCMI -> dist/vcmi-$VERSION.zip
tools/innoextract/build.sh   # innoextract 1.9 (bzip2, liblzma, Boost) -> work/inno/build/innoextract
tools/gogimport/package.sh   # !GOGImport -> dist/gogimport-1.0.zip
```

`build-deps.sh` clones riscos-crossdev at `CROSSDEV_REF` and installs its
prebuilt toolchain and the riscos-mesa devkit, which it expects in `dl/`
(`TOOLCHAIN_TARBALL`, `DEVKIT_TARBALL`; their releases on GitHub). The other
tarballs are downloaded if missing; all are checked against
`build/SHA256SUMS.txt`.

Tests (host, need libsdl2-dev):

```
tests/tbbshim/run.sh    # TBB stand-in, ThreadSanitizer and ASan/UBSan
tests/present/run.sh    # presenter against a simple reference, ASan/UBSan
tests/sound/run.sh      # sound feeding into a simulated SharedSoundBuffer, ASan/UBSan and TSan
```

Editing the patches: commit in `work/vcmi` (branch `riscos`), then
`git -C work/vcmi format-patch -o patches/vcmi 1.7.5..riscos` and update
`patches/vcmi/series`.
