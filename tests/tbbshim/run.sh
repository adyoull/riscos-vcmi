#!/bin/bash
# Host test of the TBB stand-in (riscos/tbb in the patched VCMI tree):
# once with ThreadSanitizer, once with AddressSanitizer + UBSan.
#   tests/tbbshim/run.sh [path to the patched vcmi tree]  (default work/vcmi)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
TREE=${1:-$HERE/../../work/vcmi}
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
for s in thread address,undefined; do
  g++ -std=c++20 -O1 -g -fsanitize=$s -fno-omit-frame-pointer -I"$TREE/riscos" \
    "$HERE/test.cpp" -o "$OUT/t" -pthread
  echo "== -fsanitize=$s"
  TSAN_OPTIONS=halt_on_error=1 tsan_run "$s" timeout 120 "$OUT/t"
done
