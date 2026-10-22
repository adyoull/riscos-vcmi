#!/bin/bash
# Cross-builds the libraries VCMI needs that the toolchain and devkit don't have,
# into $STAGE (work/stage). Re-runnable: a library already in $STAGE is skipped.
#   Boost 1.83 (filesystem, locale, program_options, date_time + headers),
#   minizip (zlib 1.3.1 contrib; libz itself is the devkit's),
#   SDL2_image 2.6.3 (stb_image: PNG/JPG, no other formats),
#   SDL2_ttf 2.20.2 (bundled FreeType, no HarfBuzz),
#   SDL2_mixer 2.6.3 (WAV + MP3 via dr_mp3: HoMM3's sound and music; patches/sdl2_mixer).
set -euo pipefail
. "$(dirname "$0")/env.sh"
mkdir -p "$DL" "$WORK/src" "$STAGE/lib" "$STAGE/include/SDL2"

if [ ! -f "$CROSSDEV/env.sh" ]; then
  git -c advice.detachedHead=false clone -q --branch "$CROSSDEV_REF" --depth 1 "$CROSSDEV_GIT" "$CROSSDEV"
fi
[ -x "$RISCOS_TOOLCHAIN/bin/arm-riscos-gnueabihf-gcc" ] || "$CROSSDEV/toolchain/install-prebuilt.sh"
if [ ! -f "$RISCOS_DEVKIT/VERSION" ]; then
  [ -s "$DL/$DEVKIT_TARBALL" ] || curl -fSL --retry 3 -o "$DL/$DEVKIT_TARBALL" "$DEVKIT_URL"
  ( cd "$DL" && grep " $DEVKIT_TARBALL\$" "$ROOT/build/SHA256SUMS.txt" | sha256sum -c --quiet - ) ||
    { echo "no checked sha256 for $DEVKIT_TARBALL in build/SHA256SUMS.txt" >&2; exit 1; }
  mkdir -p "$RISCOS_DEVKIT" && tar xzf "$DL/$DEVKIT_TARBALL" -C "$RISCOS_DEVKIT" --strip-components=1
fi
. "$CROSSDEV/env.sh"
# The SDL2 libraries built here use the devkit's SDL2 headers: build them
# again when the devkit changes.
if [ "$(cat "$STAGE/.devkit" 2>/dev/null)" != "$DEVKIT_VERSION" ]; then
  rm -f "$STAGE"/lib/libSDL2_image.a "$STAGE"/lib/libSDL2_ttf.a "$STAGE"/lib/libSDL2_mixer.a
  echo "$DEVKIT_VERSION" > "$STAGE/.devkit"
fi
CFLAGS_RO="$RISCOS_CFLAGS -mtune=cortex-a72"
TC="$CROSSDEV/cmake/riscos.cmake"

fetch() {  # fetch TARBALL URL: download if missing, then check against SHA256SUMS.txt
  [ -s "$DL/$1" ] || curl -fsSL -o "$DL/$1" "$2"
  ( cd "$DL" && grep " $1\$" "$ROOT/build/SHA256SUMS.txt" | sha256sum -c --quiet - )
}
unpack() {  # unpack TARBALL DIR: a fresh copy of the source in work/src/DIR
  rm -rf "$WORK/src/$2"; tar xf "$DL/$1" -C "$WORK/src"
}

# --- Boost ----------------------------------------------------------------
# Boost's own CMake build. Boost.Config doesn't know RISC OS, so every Boost
# user (VCMI included) must see boost_riscos_user_config.hpp (the same file as
# VCMI's riscos/boost_riscos_user_config.hpp). CMAKE_CXX_FLAGS replaces the
# toolchain file's flags, so RISCOS_CFLAGS (stack probes, FPU) go in it again.
if [ ! -f "$STAGE/lib/libboost_filesystem.a" ]; then
  fetch "$BOOST_TARBALL" "$BOOST_URL"
  unpack "$BOOST_TARBALL" boost-1.83.0
  for p in "$ROOT"/patches/boost/*.patch; do patch -s -d "$WORK/src/boost-1.83.0" -p1 < "$p"; done
  rm -rf "$WORK/build-boost"
  cmake -S "$WORK/src/boost-1.83.0" -B "$WORK/build-boost" -G Ninja -Wno-dev \
    -DCMAKE_TOOLCHAIN_FILE="$TC" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$STAGE" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBOOST_INCLUDE_LIBRARIES="filesystem;locale;program_options;date_time;asio;format;algorithm;crc;uuid;heap;multi_array;logic;range;geometry;container;bimap;stacktrace;lexical_cast;assign;endian;process;qvm" \
    -DBOOST_LOCALE_ENABLE_ICU=OFF \
    -DBOOST_STACKTRACE_ENABLE_BACKTRACE=OFF -DBOOST_STACKTRACE_ENABLE_ADDR2LINE=OFF \
    -DBOOST_STACKTRACE_ENABLE_BASIC=OFF -DBOOST_STACKTRACE_ENABLE_WINDBG=OFF \
    -DBOOST_STACKTRACE_ENABLE_WINDBG_CACHED=OFF \
    -DCMAKE_CXX_FLAGS="$RISCOS_CFLAGS -DBOOST_USER_CONFIG='<$ROOT/build/boost_riscos_user_config.hpp>' -mtune=cortex-a72" \
    -DCMAKE_CXX_FLAGS_RELEASE="-O2 -DNDEBUG -ffile-prefix-map=$WORK/src/boost-1.83.0=boost-1.83.0" \
    >"$WORK/boost-cmake.log"
  ninja -C "$WORK/build-boost" >"$WORK/boost-build.log" 2>&1 || { tail -30 "$WORK/boost-build.log"; exit 1; }
  cmake --install "$WORK/build-boost" >/dev/null
fi

# --- minizip ----------------------------------------------------------------
if [ ! -f "$STAGE/lib/libminizip.a" ]; then
  fetch "$ZLIB_TARBALL" "$ZLIB_URL"
  unpack "$ZLIB_TARBALL" zlib-1.3.1
  M="$WORK/src/zlib-1.3.1/contrib/minizip"
  ( cd "$M"
    for f in ioapi unzip zip; do
      arm-riscos-gnueabihf-gcc $CFLAGS_RO -DNOCRYPT=0 -DUSE_FILE32API -I"$RISCOS_DEVKIT/include" \
        -ffile-prefix-map="$M=minizip" -c $f.c -o $f.o
    done
    arm-riscos-gnueabihf-ar rcs "$STAGE/lib/libminizip.a" ioapi.o unzip.o zip.o )
  mkdir -p "$STAGE/include/minizip"
  cp "$M"/{ioapi.h,unzip.h,zip.h} "$STAGE/include/minizip/"
  # VCMI looks for minizip with find_package(minizip): a small config file.
  mkdir -p "$STAGE/lib/cmake/minizip"
  cat > "$STAGE/lib/cmake/minizip/minizipConfig.cmake" <<EOF
if(NOT TARGET minizip::minizip)
  add_library(minizip::minizip STATIC IMPORTED)
  set_target_properties(minizip::minizip PROPERTIES
    IMPORTED_LOCATION "$STAGE/lib/libminizip.a"
    INTERFACE_INCLUDE_DIRECTORIES "$STAGE/include"
    INTERFACE_LINK_LIBRARIES "$RISCOS_DEVKIT/lib/libz.a")
endif()
set(minizip_FOUND TRUE)
EOF
fi

SDL_CF="-I$RISCOS_DEVKIT/include/SDL2 -I$RISCOS_DEVKIT/include -D_REENTRANT"
SDL_LB="-L$RISCOS_DEVKIT/lib -lSDL2"

# --- SDL2_image ---------------------------------------------------------------
if [ ! -f "$STAGE/lib/libSDL2_image.a" ]; then
  fetch "$IMAGE_TARBALL" "$IMAGE_URL"
  unpack "$IMAGE_TARBALL" SDL2_image-2.6.3
  ( cd "$WORK/src/SDL2_image-2.6.3"
    ./configure --host=arm-riscos-gnueabihf --prefix="$STAGE" --disable-shared --enable-static \
      SDL2_CONFIG=/bin/false SDL_CFLAGS="$SDL_CF" SDL_LIBS="$SDL_LB" \
      CFLAGS="$CFLAGS_RO -ffile-prefix-map=$WORK/src/SDL2_image-2.6.3=SDL2_image-2.6.3" \
      --enable-stb-image --enable-png --enable-jpg --disable-png-shared --disable-jpg-shared \
      --disable-avif --disable-jxl --disable-tif --disable-webp --disable-sdltest >/dev/null
    make -j"$JOBS" libSDL2_image.la >/dev/null )
  cp "$WORK/src/SDL2_image-2.6.3/.libs/libSDL2_image.a" "$STAGE/lib/"
  cp "$WORK/src/SDL2_image-2.6.3/SDL_image.h" "$STAGE/include/SDL2/"
fi

# --- SDL2_ttf (bundled FreeType; its gzip module uses the devkit's zlib, not its own copy) -------------------------------------------------
if [ ! -f "$STAGE/lib/libSDL2_ttf.a" ]; then
  fetch "$TTF_TARBALL" "$TTF_URL"
  unpack "$TTF_TARBALL" SDL2_ttf-2.20.2
  ( cd "$WORK/src/SDL2_ttf-2.20.2"
    ./configure --host=arm-riscos-gnueabihf --prefix="$STAGE" --disable-shared --enable-static \
      SDL2_CONFIG=/bin/false SDL_CFLAGS="$SDL_CF" SDL_LIBS="$SDL_LB" \
      CFLAGS="$CFLAGS_RO -ffile-prefix-map=$WORK/src/SDL2_ttf-2.20.2=SDL2_ttf-2.20.2 -DFT_CONFIG_OPTION_SYSTEM_ZLIB -I$RISCOS_DEVKIT/include" \
      --enable-freetype-builtin --disable-harfbuzz --disable-sdltest >/dev/null
    make -j"$JOBS" libSDL2_ttf.la >/dev/null )
  cp "$WORK/src/SDL2_ttf-2.20.2/.libs/libSDL2_ttf.a" "$STAGE/lib/"
  cp "$WORK/src/SDL2_ttf-2.20.2/SDL_ttf.h" "$STAGE/include/SDL2/"
fi

# --- SDL2_mixer (WAV + MP3) ---------------------------------------------------------
if [ ! -f "$STAGE/lib/libSDL2_mixer.a" ]; then
  fetch "$MIXER_TARBALL" "$MIXER_URL"
  unpack "$MIXER_TARBALL" SDL2_mixer-2.6.3
  for p in "$ROOT"/patches/sdl2_mixer/*.patch; do patch -s -d "$WORK/src/SDL2_mixer-2.6.3" -p1 < "$p"; done
  ( cd "$WORK/src/SDL2_mixer-2.6.3"
    ./configure --host=arm-riscos-gnueabihf --prefix="$STAGE" --disable-shared --enable-static \
      SDL2_CONFIG=/bin/false SDL_CFLAGS="$SDL_CF" SDL_LIBS="$SDL_LB" \
      CFLAGS="$CFLAGS_RO -ffile-prefix-map=$WORK/src/SDL2_mixer-2.6.3=SDL2_mixer-2.6.3" \
      --disable-music-cmd --disable-music-mod --disable-music-midi --disable-music-ogg \
      --disable-music-flac --disable-music-opus --disable-music-mp3-mpg123 \
      --enable-music-wave --enable-music-mp3 --enable-music-mp3-drmp3 --disable-sdltest >/dev/null
    make -j"$JOBS" build/libSDL2_mixer.la >/dev/null )
  cp "$WORK/src/SDL2_mixer-2.6.3/build/.libs/libSDL2_mixer.a" "$STAGE/lib/"
  cp "$WORK/src/SDL2_mixer-2.6.3/include/SDL_mixer.h" "$STAGE/include/SDL2/"
fi
echo "dependencies in $STAGE"
