#!/bin/bash
# Makes dist/gogimport-$GOGIMPORT_VERSION.zip: !GOGImport with innoextract,
# for getting Heroes III's files out of the GOG installer on RISC OS.
# No game files go in it.
#   tools/innoextract/build.sh && tools/gogimport/package.sh
set -euo pipefail
. "$(dirname "$0")/../../build/env.sh"
. "$CROSSDEV/env.sh"
: "${GOGIMPORT_VERSION:=1.0}"
T="$RISCOS_TOOLCHAIN"
I="$WORK/inno"
SRC="$ROOT/tools/gogimport/!GOGImport"
APP="$DIST/!GOGImport"
[ -f "$I/build/innoextract" ] || { echo "build innoextract first: tools/innoextract/build.sh" >&2; exit 1; }
rm -rf "$APP" && mkdir -p "$APP/docs"
cp "$SRC"/* "$APP/"

"$T/bin/arm-riscos-gnueabihf-strip" -o "$I/innoextract.stripped" "$I/build/innoextract"
"$T/bin/elf2aif" -e "$I/innoextract.stripped" "$APP/innoextract,ff8" >/dev/null

# Licence texts of everything in innoextract,ff8.
cp "$I/src/innoextract-1.9/LICENSE" "$APP/docs/innoextract,fff"
cp "$I/src/xz-5.8.1/COPYING.0BSD" "$APP/docs/liblzma,fff"
cp "$I/src/bzip2-1.0.8/LICENSE" "$APP/docs/bzip2,fff"
cp "$I/src/boost-1.83.0/LICENSE_1_0.txt" "$APP/docs/Boost,fff"
tar xzf "$DL/zlib-1.3.1.tar.gz" -O zlib-1.3.1/LICENSE > "$APP/docs/zlib,fff"
cp "$ROOT/COPYING" "$APP/docs/COPYING,fff"
cat > "$APP/docs/Runtime,fff" <<'EOF'
innoextract,ff8 is built with GCC 10.2.0 (GCCSDK) and linked statically
with UnixLib 5.0.3.3 and GCC's runtime libraries (libgcc, libstdc++).

GCC's runtime libraries are under the GNU GPL version 3 with the GCC
Runtime Library Exception, which allows programs built with them to have
any licence.

UnixLib is mainly under BSD-style licences, with some parts under the
LGPL or the GPL with a linking exception. Its licences are in
libunixlib/COPYING of UnixLib's source:
https://github.com/adyoull/riscos-unixlib

Sources: innoextract 1.9 (https://constexpr.org/innoextract/), xz 5.8.1,
bzip2 1.0.8, Boost 1.83.0, zlib 1.3.1 (riscos-mesa devkit), built by
tools/innoextract/build.sh of https://github.com/adyoull/riscos-vcmi
with the patch in tools/innoextract/patches.
EOF
printf 'GOG Import %s for RISC OS (innoextract 1.9)\n' "$GOGIMPORT_VERSION" > "$APP/docs/Version,fff"

if strings -a "$APP/innoextract,ff8" | grep -q "/home/[c]laude\|$ROOT"; then echo "unwanted strings in the program" >&2; exit 1; fi
if grep -rIl -i "[c]laude\|[a]nthropic" "$APP" | grep -q .; then echo "attribution found in the app" >&2; exit 1; fi
if find "$APP" -iname '*.lod' -o -iname '*.snd' -o -iname '*.vid' -o -iname '*.h3m' -o -iname '*.mp3' | grep .; then
  echo "game files in the package" >&2; exit 1
fi
rm -f "$DIST/gogimport-$GOGIMPORT_VERSION.zip"
python3 "$CROSSDEV/package/rozip.py" "$DIST/gogimport-$GOGIMPORT_VERSION.zip" -C "$DIST" '!GOGImport'
ls -la "$DIST/gogimport-$GOGIMPORT_VERSION.zip"; md5sum "$DIST/gogimport-$GOGIMPORT_VERSION.zip" "$APP/innoextract,ff8"
