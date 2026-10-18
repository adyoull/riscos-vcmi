#!/bin/bash
# Builds VCMI for RISC OS (one static program: client + in-process server +
# AIs), with patches/vcmi applied. Run build/build-deps.sh first.
#   build/build-vcmi.sh           clone + patch (if needed), configure, build
#   build/build-vcmi.sh rebuild   build work/vcmi as it is
set -euo pipefail
. "$(dirname "$0")/env.sh"
. "$CROSSDEV/env.sh"
export CROSSDEV STAGE

if [ ! -d "$WORK/vcmi" ]; then
  git -c advice.detachedHead=false clone -q --depth 1 --branch "$VCMI_REF" "$VCMI_GIT" "$WORK/vcmi"
  ( cd "$WORK/vcmi"
    git submodule update --init --depth 1 AI/FuzzyLite >/dev/null
    git checkout -q -b riscos
    git -c user.name="Andrew Youll" -c user.email=adyoull@users.noreply.github.com \
      am -q $(sed "s|^|$ROOT/patches/vcmi/|" "$ROOT/patches/vcmi/series") )
fi

# Boost was built with build/boost_riscos_user_config.hpp; VCMI must see the same.
cmp -s "$ROOT/build/boost_riscos_user_config.hpp" "$WORK/vcmi/riscos/boost_riscos_user_config.hpp" ||
  { echo "build/boost_riscos_user_config.hpp differs from riscos/ in patches/vcmi" >&2; exit 1; }

S="$STAGE" D="$RISCOS_DEVKIT"
BOOSTCFG="-DBOOST_USER_CONFIG='<$WORK/vcmi/riscos/boost_riscos_user_config.hpp>'"
# -ffile-prefix-map keeps build paths out of the program (checked below).
# SDL2 needs the devkit's EGL and OSMesa (its OpenGL driver) after it on the
# link line: CMAKE_CXX_STANDARD_LIBRARIES puts them at the end.
CXXF="-O2 -DNDEBUG -mtune=cortex-a72 $BOOSTCFG -DBOOST_ASIO_DISABLE_SERIAL_PORT -ffile-prefix-map=$WORK/vcmi=vcmi-$VCMI_REF -ffile-prefix-map=$STAGE=stage"
cmake -S "$WORK/vcmi" -B "$WORK/build-vcmi" -G Ninja -Wno-dev \
  -DCMAKE_TOOLCHAIN_FILE="$ROOT/build/riscos-stage.cmake" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_FLAGS_RELEASE="$CXXF" -DCMAKE_C_FLAGS_RELEASE="-O2 -DNDEBUG -mtune=cortex-a72" \
  -DBoost_USE_STATIC_LIBS=ON -DBoost_DIR="$S/lib/cmake/Boost-1.83.0" \
  -DENABLE_STATIC_LIBS=ON -DENABLE_SERVER=OFF -DENABLE_LAUNCHER=OFF -DENABLE_EDITOR=OFF \
  -DENABLE_LOBBY=OFF -DENABLE_DISCORD=OFF -DENABLE_MMAI=OFF -DENABLE_LUA=OFF -DENABLE_ERM=OFF \
  -DENABLE_VIDEO=OFF -DENABLE_TEST=OFF -DENABLE_TRANSLATIONS=OFF -DENABLE_PCH=OFF \
  -DENABLE_GITVERSION=OFF -DENABLE_CCACHE=OFF -DENABLE_INNOEXTRACT=OFF \
  -DENABLE_MONOLITHIC_INSTALL=ON -DCOPY_CONFIG_ON_BUILD=OFF \
  -DSDL2_INCLUDE_DIR="$D/include/SDL2" \
  -DSDL2_LIBRARY="$D/lib/libSDL2.a" \
  -DCMAKE_CXX_STANDARD_LIBRARIES="$D/lib/libGLU.a $D/lib/libEGL.a $D/lib/libOSMesa.a $D/lib/libz.a -lm" \
  -DSDL2_IMAGE_INCLUDE_DIR="$S/include/SDL2" -DSDL2_IMAGE_LIBRARY="$S/lib/libSDL2_image.a" \
  -DSDL2_MIXER_INCLUDE_DIR="$S/include/SDL2" -DSDL2_MIXER_LIBRARY="$S/lib/libSDL2_mixer.a" \
  -DSDL2_TTF_INCLUDE_DIR="$S/include/SDL2" -DSDL2_TTF_LIBRARY="$S/lib/libSDL2_ttf.a" \
  -DMINIZIP_INCLUDE_DIR="$S/include" -DMINIZIP_LIBRARY="$S/lib/libminizip.a" \
  -DZLIB_INCLUDE_DIR="$D/include" -DZLIB_LIBRARY="$D/lib/libz.a" \
  >"$WORK/vcmi-cmake.log" 2>&1 || { tail -40 "$WORK/vcmi-cmake.log"; exit 1; }
ninja -C "$WORK/build-vcmi" -k 0 vcmiclient >"$WORK/vcmi-build.log" 2>&1 || {
  grep -A8 "FAILED\|error:" "$WORK/vcmi-build.log" | head -80; exit 1; }
P="$WORK/build-vcmi/bin/vcmiclient"
"$CROSSDEV/checks/check-all.sh" "$P"
if strings -a "$P" | grep -q "$ROOT"; then
  echo "build paths found in the program" >&2; exit 1
fi
echo "built $P"
