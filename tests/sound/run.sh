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
# ThreadSanitizer can't start on some kernels (newer ones randomise more of
# the address space: "unexpected memory mapping"), such as GitHub's runners
# inside a container, where it can't be turned off. Then it's skipped.
tsan_run() {
  local san=$1; shift
  if [ "$san" != thread ]; then "$@"; return; fi
  local rc=0
  "$@" 2>"$OUT/tsan.err" || rc=$?
  if [ $rc -ne 0 ] && grep -q "unexpected memory mapping" "$OUT/tsan.err"; then
    echo "ThreadSanitizer can't run on this kernel: skipped"; return 0
  fi
  cat "$OUT/tsan.err" >&2; return $rc
}
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
  tsan_run "$san" timeout 120 "$OUT/t"
done
