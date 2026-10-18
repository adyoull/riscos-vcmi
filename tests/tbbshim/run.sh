#!/bin/bash
# Host test of the TBB stand-in (riscos/tbb in the patched VCMI tree):
# once with ThreadSanitizer, once with AddressSanitizer + UBSan.
#   tests/tbbshim/run.sh [path to the patched vcmi tree]  (default work/vcmi)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
TREE=${1:-$HERE/../../work/vcmi}
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
for s in thread address,undefined; do
  g++ -std=c++20 -O1 -g -fsanitize=$s -fno-omit-frame-pointer -I"$TREE/riscos" \
    "$HERE/test.cpp" -o "$OUT/t" -pthread
  echo "== -fsanitize=$s"
  TSAN_OPTIONS=halt_on_error=1 timeout 120 "$OUT/t"
done
