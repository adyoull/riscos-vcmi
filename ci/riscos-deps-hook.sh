#!/bin/bash
# Run by .github/workflows/riscos-deps-update.yml as
#   ci/riscos-deps-hook.sh NAME OLD_TAG NEW_TAG
# before it moves the pin in .riscos-deps. build/env.sh reads the tags from
# .riscos-deps; the one other place a dependency is pinned is the devkit's
# sha256 in build/SHA256SUMS.txt, so a new riscos-mesa release's devkit is
# fetched and its sum added (a line for the old one stays, harmlessly).
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1#adyoull/} new=$3
case $name in
riscos-mesa)
  f=riscos-mesa-devkit-${new#v}.tgz
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  curl -fsSL --retry 3 -o "$tmp/$f" "https://github.com/adyoull/riscos-mesa/releases/download/$new/$f"
  tar tzf "$tmp/$f" >/dev/null
  sum=$(sha256sum "$tmp/$f" | cut -d' ' -f1)
  grep -v " $f\$" build/SHA256SUMS.txt > "$tmp/sums" || true
  echo "$sum  $f" >> "$tmp/sums"
  cat "$tmp/sums" > build/SHA256SUMS.txt
  echo "$f: $sum" ;;
*) ;;   # riscos-crossdev: the image and CROSSDEV_REF follow .riscos-deps
esac
