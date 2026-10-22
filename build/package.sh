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
# RISC OS file names can't hold % (two of the random map templates have it):
# "200%" becomes "200pc". Nothing refers to these files by name (VCMI finds
# templates by listing the directory). Any other character RISC OS can't
# store stops the build.
find "$APP/config" "$APP/Mods" -depth -name '*%*' | while read -r f; do
  mv "$f" "$(dirname "$f")/$(basename "$f" | sed 's/%/pc/g')"
done
if find "$APP/config" "$APP/Mods" -name '*[$&@^#\\|":*<>]*' | grep .; then
  echo "file names RISC OS can't hold" >&2; exit 1
fi

# Icon from VCMI's own.
convert "$WORK/vcmi/clientapp/icons/vcmiclient.64x64.png" -resize 34x34 -depth 8 PNG32:"$WORK/icon34.png"
convert "$WORK/vcmi/clientapp/icons/vcmiclient.32x32.png" -resize 17x17 -depth 8 PNG32:"$WORK/icon17.png"
python3 "$CROSSDEV/package/png2sprite.py" "$APP/!Sprites,ff9" "!vcmi=$WORK/icon34.png" "sm!vcmi=$WORK/icon17.png"

cp "$T/riscos/PThrTicker,ffa" "$APP/"
cp "$T/riscos/PThreadTicker-Licence,fff" "$APP/docs/"
cp "$WORK/vcmi/license.txt" "$APP/docs/COPYING,fff"
cp "$WORK/vcmi/AUTHORS.h" "$APP/docs/AUTHORS,fff" 2>/dev/null || true
cp "$ROOT/CHANGELOG.md" "$APP/docs/RISCOS-Changes,fff"
# The licences of everything linked into vcmi,ff8.
L="$APP/docs/Licences"
mkdir -p "$L"
cp "$WORK/vcmi/AI/FuzzyLite/LICENSE" "$L/FuzzyLite,fff"
cp "$WORK/src/boost-1.83.0/LICENSE_1_0.txt" "$L/Boost,fff"
cp "$WORK/src/SDL2_mixer-2.6.3/LICENSE.txt" "$L/SDL2_mixer,fff"
cp "$WORK/src/SDL2_image-2.6.3/LICENSE.txt" "$L/SDL2_image,fff"
cp "$WORK/src/SDL2_ttf-2.20.2/LICENSE.txt" "$L/SDL2_ttf,fff"
cp "$WORK/src/SDL2_ttf-2.20.2/external/freetype/docs/FTL.TXT" "$L/FreeType,fff"
cp "$WORK/src/zlib-1.3.1/LICENSE" "$L/zlib-minizip,fff"
tail -n 40 "$WORK/src/SDL2_mixer-2.6.3/src/codecs/dr_libs/dr_mp3.h" > "$L/dr_mp3,fff"
cp "$RISCOS_DEVKIT/LICENCES.txt" "$L/SDL2-Mesa-UnixLib,fff"
cat > "$L/ReadMe,fff" <<'EOF'
Licences of what is in vcmi,ff8
===============================

VCMI 1.7.5 and the RISC OS changes: GNU GPL version 2 or later
  (docs.COPYING).
FuzzyLite 6 (VCMI's AI uses it): GNU GPL version 3 (FuzzyLite). With it
  linked in, vcmi,ff8 as a whole can be passed on under the GPL version 3.
Boost 1.83: Boost Software Licence 1.0 (Boost).
SDL2_mixer 2.6.3 (with patches/sdl2_mixer of riscos-vcmi), SDL2_image
  2.6.3, SDL2_ttf 2.20.2: zlib licence (SDL2_mixer, SDL2_image, SDL2_ttf).
dr_mp3 (in SDL2_mixer, the MP3 decoder): public domain or MIT No
  Attribution (dr_mp3).
FreeType (in SDL2_ttf): the FreeType Licence (FreeType). Portions of this
  software are copyright (c) The FreeType Project (www.freetype.org).
  All rights reserved.
minizip (zlib 1.3.1 contrib) and zlib: zlib licence (zlib-minizip).
SDL2 (riscos-mesa 20.3.5-17), Mesa (OSMesa, EGL, GLU), zlib, UnixLib and
  GCC's runtime libraries: SDL2-Mesa-UnixLib (the riscos-mesa devkit's
  LICENCES.txt).
PThreadTicker: docs.PThreadTicker-Licence.

The sources: https://github.com/adyoull/riscos-vcmi (the release page has
the VCMI and library sources used).
EOF
printf 'VCMI %s for RISC OS (VCMI %s + patches/vcmi of riscos-vcmi)\n' "$VERSION" "$VCMI_REF" > "$APP/docs/Version,fff"

if strings -a "$APP/vcmi,ff8" | grep -q "/home/[c]laude\|$ROOT"; then echo "unwanted strings in the program" >&2; exit 1; fi
if grep -rIl -i "[c]laude\|[a]nthropic" "$APP" | grep -v "COPYING\|AUTHORS" | grep -q .; then echo "attribution found in the app" >&2; exit 1; fi
rm -f "$DIST/vcmi-$VERSION.zip"
python3 "$CROSSDEV/package/rozip.py" "$DIST/vcmi-$VERSION.zip" -C "$DIST" '!VCMI'
grep WimpSlot "$APP/!Run,feb"
ls -la "$DIST/vcmi-$VERSION.zip"; md5sum "$DIST/vcmi-$VERSION.zip" "$APP/vcmi,ff8"
