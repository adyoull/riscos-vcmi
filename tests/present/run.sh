#!/bin/bash
# Host test of the RISC OS presenter (riscos/riscos_present.cpp in the
# patched VCMI tree), with AddressSanitizer + UBSan.
#   tests/present/run.sh [path to the patched vcmi tree]  (default work/vcmi)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
TREE=${1:-$HERE/../../work/vcmi}
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
g++ -std=c++20 -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer -DRISCOS_PRESENT \
  -I"$TREE/riscos" $(sdl2-config --cflags) "$HERE/test.cpp" "$TREE/riscos/riscos_present.cpp" \
  -o "$OUT/t" $(sdl2-config --libs)
SDL_VIDEODRIVER=dummy timeout 300 "$OUT/t"
