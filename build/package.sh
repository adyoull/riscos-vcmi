#!/bin/bash
# Makes dist/vcmi-$VERSION.zip (!VCMI) from the build in work/.
# Test builds (*test) have the extra log turned on in !Run.
set -euo pipefail
. "$(dirname "$0")/env.sh"
. "$CROSSDEV/env.sh"
T="$RISCOS_TOOLCHAIN"
SRC="$ROOT/app/!VCMI"
APP="$DIST/!VCMI"
rm -rf "$APP" && mkdir -p "$APP/docs" "$APP/H3data"
cp "$SRC/!Boot,feb" "$SRC/!Help,fff" "$APP/"
cp "$SRC/H3data/ReadMe,fff" "$APP/H3data/"
cp "$SRC/!Run,feb" "$APP/!Run,feb"
case "$VERSION" in *test) sed -i 's/^| Set VCMI\$LogOn 1$/Set VCMI$LogOn 1/' "$APP/!Run,feb" ;; esac

# Program: strip, then Absolute (AIF) so !SharedLibs isn't needed.
"$T/bin/arm-riscos-gnueabihf-strip" -o "$WORK/vcmi.stripped" "$WORK/build-vcmi/bin/vcmiclient"
"$T/bin/elf2aif" -e "$WORK/vcmi.stripped" "$APP/vcmi,ff8" >/dev/null
# WimpSlot: the program (with its zero-initialised data) plus 8 MB for the stack.
need=$(( ( $(arm-riscos-gnueabihf-size -A "$WORK/build-vcmi/bin/vcmiclient" | awk '$1 ~ /^\.(text|data|bss|rodata|ARM|init|fini|tbss|tdata|ctors|dtors|eh_frame|gcc_except_table)/ {s += $2} END {print s}') / 1024 + 8192 + 1023) / 1024 * 1024 ))
sed -i "s/^WimpSlot -min [0-9]*K -max [0-9]*K$/WimpSlot -min ${need}K -max ${need}K/" "$APP/!Run,feb"

# VCMI's own data: the game rules (config) and the built-in mod (Mods/vcmi).
cp -r "$WORK/vcmi/config" "$APP/config"
mkdir -p "$APP/Mods" && cp -r "$WORK/vcmi/Mods/vcmi" "$APP/Mods/vcmi"

# Icon from VCMI's own.
convert "$WORK/vcmi/clientapp/icons/vcmiclient.64x64.png" -resize 34x34 -depth 8 PNG32:"$WORK/icon34.png"
convert "$WORK/vcmi/clientapp/icons/vcmiclient.32x32.png" -resize 17x17 -depth 8 PNG32:"$WORK/icon17.png"
python3 "$CROSSDEV/package/png2sprite.py" "$APP/!Sprites,ff9" "!vcmi=$WORK/icon34.png" "sm!vcmi=$WORK/icon17.png"

cp "$T/riscos/PThrTicker,ffa" "$APP/"
cp "$T/riscos/PThreadTicker-Licence,fff" "$APP/docs/"
cp "$WORK/vcmi/license.txt" "$APP/docs/COPYING,fff"
cp "$WORK/vcmi/AUTHORS.h" "$APP/docs/AUTHORS,fff" 2>/dev/null || true
cp "$ROOT/CHANGELOG.md" "$APP/docs/RISCOS-Changes,fff"
printf 'VCMI %s for RISC OS (VCMI %s + patches/vcmi of riscos-vcmi)\n' "$VERSION" "$VCMI_REF" > "$APP/docs/Version,fff"

if strings -a "$APP/vcmi,ff8" | grep -q "/home/[c]laude\|$ROOT"; then echo "unwanted strings in the program" >&2; exit 1; fi
if grep -rIl -i "[c]laude\|[a]nthropic" "$APP" | grep -v "COPYING\|AUTHORS" | grep -q .; then echo "attribution found in the app" >&2; exit 1; fi
rm -f "$DIST/vcmi-$VERSION.zip"
python3 "$CROSSDEV/package/rozip.py" "$DIST/vcmi-$VERSION.zip" -C "$DIST" '!VCMI'
grep WimpSlot "$APP/!Run,feb"
ls -la "$DIST/vcmi-$VERSION.zip"; md5sum "$DIST/vcmi-$VERSION.zip" "$APP/vcmi,ff8"
