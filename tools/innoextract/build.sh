#!/bin/bash
# Builds innoextract 1.9 for RISC OS: a static command-line program that
# unpacks Inno Setup installers, such as GOG's (setup_*.exe + setup_*-1.bin).
# Used by !GOGImport to get the Heroes III files out of the GOG installer.
#   tools/innoextract/build.sh   -> work/inno/innoextract (ELF), checked
# Libraries (all static, in work/inno/stage): bzip2 1.0.8, liblzma (xz 5.8.1),
# Boost 1.83 (iostreams with zlib + bzip2, filesystem, date_time, system,
# program_options); zlib is the riscos-mesa devkit's.
set -euo pipefail
. "$(dirname "$0")/../../build/env.sh"
[ -d "$CROSSDEV" ] || "$ROOT/build/build-deps.sh"
. "$CROSSDEV/env.sh"
I="$WORK/inno"
S="$I/stage"
mkdir -p "$I/src" "$S/lib" "$S/include"
CFLAGS_RO="$RISCOS_CFLAGS -mtune=cortex-a72"
check() { ( cd "$DL" && grep " $1\$" "$ROOT/build/SHA256SUMS.txt" | sha256sum -c --quiet - ); }

# --- bzip2 (only the library) ---------------------------------------------------
if [ ! -f "$S/lib/libbz2.a" ]; then
  check bzip2_1.0.8.orig.tar.gz
  rm -rf "$I/src/bzip2-1.0.8"; tar xzf "$DL/bzip2_1.0.8.orig.tar.gz" -C "$I/src"
  ( cd "$I/src/bzip2-1.0.8"
    for f in blocksort huffman crctable randtable compress decompress bzlib; do
      arm-riscos-gnueabihf-gcc $CFLAGS_RO -D_FILE_OFFSET_BITS=64 -ffile-prefix-map="$PWD=bzip2" -c $f.c -o $f.o
    done
    arm-riscos-gnueabihf-ar rcs "$S/lib/libbz2.a" blocksort.o huffman.o crctable.o randtable.o compress.o decompress.o bzlib.o )
  cp "$I/src/bzip2-1.0.8/bzlib.h" "$S/include/"
fi

# --- liblzma (xz) ----------------------------------------------------------------
if [ ! -f "$S/lib/liblzma.a" ]; then
  check xz-5.8.1.tar.gz
  rm -rf "$I/src/xz-5.8.1"; tar xzf "$DL/xz-5.8.1.tar.gz" -C "$I/src"
  ( cd "$I/src/xz-5.8.1"
    ./configure --host=arm-riscos-gnueabihf --prefix="$S" --disable-shared --enable-static \
      --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo --disable-lzma-links \
      --disable-scripts --disable-doc --disable-nls --disable-threads \
      CFLAGS="$CFLAGS_RO -ffile-prefix-map=$PWD=xz-5.8.1" >/dev/null
    make -j"$JOBS" -C src/liblzma >/dev/null
    make -C src/liblzma install >/dev/null )
fi

# --- Boost (with Iostreams) ------------------------------------------------------
if [ ! -f "$S/lib/libboost_iostreams.a" ]; then
  check "$BOOST_TARBALL"
  rm -rf "$I/src/boost-1.83.0"; tar xJf "$DL/$BOOST_TARBALL" -C "$I/src"
  for p in "$ROOT"/patches/boost/*.patch; do patch -s -d "$I/src/boost-1.83.0" -p1 < "$p"; done
  rm -rf "$I/build-boost"
  cmake -S "$I/src/boost-1.83.0" -B "$I/build-boost" -G Ninja -Wno-dev \
    -DCMAKE_TOOLCHAIN_FILE="$ROOT/build/riscos-stage.cmake" -DRISCOS_VCMI_CROSSDEV="$CROSSDEV" \
    -DRISCOS_VCMI_STAGE="$S" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$S" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBOOST_INCLUDE_LIBRARIES="iostreams;filesystem;date_time;system;program_options" \
    -DBOOST_IOSTREAMS_ENABLE_ZLIB=ON -DBOOST_IOSTREAMS_ENABLE_BZIP2=ON \
    -DBOOST_IOSTREAMS_ENABLE_LZMA=OFF -DBOOST_IOSTREAMS_ENABLE_ZSTD=OFF \
    -DZLIB_INCLUDE_DIR="$RISCOS_DEVKIT/include" -DZLIB_LIBRARY="$RISCOS_DEVKIT/lib/libz.a" \
    -DBZIP2_INCLUDE_DIR="$S/include" -DBZIP2_LIBRARIES="$S/lib/libbz2.a" \
    -DCMAKE_CXX_FLAGS="$RISCOS_CFLAGS -DBOOST_USER_CONFIG='<$ROOT/build/boost_riscos_user_config.hpp>' -mtune=cortex-a72" \
    -DCMAKE_CXX_FLAGS_RELEASE="-O2 -DNDEBUG -ffile-prefix-map=$I/src/boost-1.83.0=boost-1.83.0" \
    >"$I/boost-cmake.log"
  ninja -C "$I/build-boost" >"$I/boost-build.log" 2>&1 || { tail -30 "$I/boost-build.log"; exit 1; }
  cmake --install "$I/build-boost" >/dev/null
  # innoextract also uses header-only libraries (foreach, range, crc...): all headers.
  for d in "$I"/src/boost-1.83.0/libs/*/include "$I"/src/boost-1.83.0/libs/numeric/*/include; do
    cp -r --update=none "$d/boost" "$S/include/"
  done
fi

# --- innoextract -------------------------------------------------------------------
check innoextract-1.9.tar.gz
rm -rf "$I/src/innoextract-1.9"; tar xzf "$DL/innoextract-1.9.tar.gz" -C "$I/src"
for p in "$ROOT"/tools/innoextract/patches/*.patch; do
  [ -f "$p" ] && patch -s -d "$I/src/innoextract-1.9" -p1 < "$p"
done
rm -rf "$I/build"
cmake -S "$I/src/innoextract-1.9" -B "$I/build" -G Ninja -Wno-dev \
  -DCMAKE_TOOLCHAIN_FILE="$ROOT/build/riscos-stage.cmake" -DRISCOS_VCMI_CROSSDEV="$CROSSDEV" \
  -DRISCOS_VCMI_STAGE="$S" -DCMAKE_BUILD_TYPE=Release \
  -DUSE_STATIC_LIBS=ON -DUSE_LTO=OFF -DUSE_LDGOLD=OFF -DSET_OPTIMIZATION_FLAGS=OFF \
  -DWITH_CONV=builtin -DBoost_DIR="$S/lib/cmake/Boost-1.83.0" \
  -DLZMA_INCLUDE_DIR="$S/include" -DLZMA_LIBRARY="$S/lib/liblzma.a" \
  -DZLIB_INCLUDE_DIR="$RISCOS_DEVKIT/include" -DZLIB_LIBRARY="$RISCOS_DEVKIT/lib/libz.a" \
  -DBZIP2_INCLUDE_DIR="$S/include" -DBZIP2_LIBRARY_RELEASE="$S/lib/libbz2.a" \
  -DCMAKE_CXX_FLAGS_RELEASE="-O2 -DNDEBUG -mtune=cortex-a72 -DBOOST_USER_CONFIG='<$ROOT/build/boost_riscos_user_config.hpp>' -ffile-prefix-map=$I/src/innoextract-1.9=innoextract-1.9" \
  >"$I/inno-cmake.log" 2>&1 || { tail -30 "$I/inno-cmake.log"; exit 1; }
ninja -C "$I/build" >"$I/inno-build.log" 2>&1 || { grep -A8 "FAILED\|error" "$I/inno-build.log" | head -60; exit 1; }
"$CROSSDEV/checks/check-all.sh" "$I/build/innoextract"
if strings -a "$I/build/innoextract" | grep -q "$ROOT"; then echo "build paths in the program" >&2; exit 1; fi
echo "built $I/build/innoextract"
