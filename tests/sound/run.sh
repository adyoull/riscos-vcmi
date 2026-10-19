#!/bin/bash
# Host test of the RISC OS sound feeding (riscos/riscos_sound.cpp, FAKE_SSB)
# with SDL2_mixer 2.6.3 built from dl/ plus patches/sdl2_mixer, under
# AddressSanitizer + UBSan, then ThreadSanitizer.
#   tests/sound/run.sh [path to the patched vcmi tree]  (default work/vcmi)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
TREE=${1:-$ROOT/work/vcmi}
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
tar xzf "$ROOT/dl/SDL2_mixer-2.6.3.tar.gz" -C "$OUT"
for p in "$ROOT"/patches/sdl2_mixer/*.patch; do patch -s -d "$OUT/SDL2_mixer-2.6.3" -p1 < "$p"; done
( cd "$OUT/SDL2_mixer-2.6.3" && ./configure --disable-shared --enable-static --disable-music-ogg --disable-music-flac \
    --disable-music-mod --disable-music-midi --disable-music-opus --disable-music-mp3-mpg123 >/dev/null 2>&1 &&
  make -j"$(nproc)" build/libSDL2_mixer.la >/dev/null 2>&1 )
MIX="$OUT/SDL2_mixer-2.6.3"
for san in "address,undefined" "thread"; do
  g++ -std=c++20 -O1 -g -fsanitize=$san -DFAKE_SSB -I"$TREE/riscos" -I"$MIX/include" $(sdl2-config --cflags) \
    "$HERE/test.cpp" "$TREE/riscos/riscos_sound.cpp" "$MIX/build/.libs/libSDL2_mixer.a" -o "$OUT/t" $(sdl2-config --libs) -lm
  echo "== $san"
  timeout 120 "$OUT/t"
done
