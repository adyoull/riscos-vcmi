# Source this: . build/env.sh
# Versions and checksums of everything the RISC OS build of VCMI uses.
# Each can be overridden from the environment.
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

: "${VERSION:=1.7.5-riscos10test}"
: "${VCMI_REF:=1.7.5}"
: "${VCMI_GIT:=https://github.com/vcmi/vcmi.git}"
# fuzzylite is a submodule of VCMI (AI/FuzzyLite), at the commit VCMI pins.
: "${FUZZYLITE_GIT:=https://github.com/fuzzylite/fuzzylite.git}"

# riscos-crossdev (kit + prebuilt toolchain) and the riscos-mesa devkit (SDL2, zlib).
: "${CROSSDEV_REF:=v1.8.2}"
: "${CROSSDEV_GIT:=https://github.com/adyoull/riscos-crossdev.git}"
: "${TOOLCHAIN_TARBALL:=riscos-crossdev-toolchain-1.4-x86_64-linux.tar.xz}"
: "${DEVKIT_TARBALL:=riscos-mesa-devkit-20.3.5-17e.tgz}"
# 17e (a riscos-mesa test build) adds SDL_RISCOS_FB_RENDER_SIZE / _OVERLAY,
# newer than the 20.3.5-16 riscos-crossdev pins; build-deps.sh unpacks it
# from dl/ into $RISCOS_DEVKIT after checking this sum.
: "${DEVKIT_SHA256:=03e8f2f52ef4c8e4179f5515cfae2a20ada7d1e5f820c953bee94feaf64968f4}"

# Libraries built here (dl/ holds the tarballs; SHA256SUMS.txt checks them).
: "${BOOST_TARBALL:=boost-1.83.0.tar.xz}"
: "${BOOST_URL:=https://github.com/boostorg/boost/releases/download/boost-1.83.0/boost-1.83.0.tar.xz}"
: "${ZLIB_TARBALL:=zlib-1.3.1.tar.gz}"          # only for contrib/minizip (libz is the devkit's)
: "${ZLIB_URL:=https://github.com/madler/zlib/releases/download/v1.3.1/zlib-1.3.1.tar.gz}"
: "${MIXER_TARBALL:=SDL2_mixer-2.6.3.tar.gz}"
: "${MIXER_URL:=https://github.com/libsdl-org/SDL_mixer/releases/download/release-2.6.3/SDL2_mixer-2.6.3.tar.gz}"
: "${IMAGE_TARBALL:=SDL2_image-2.6.3.tar.gz}"
: "${IMAGE_URL:=https://github.com/libsdl-org/SDL_image/releases/download/release-2.6.3/SDL2_image-2.6.3.tar.gz}"
: "${TTF_TARBALL:=SDL2_ttf-2.20.2.tar.gz}"
: "${TTF_URL:=https://github.com/libsdl-org/SDL_ttf/releases/download/release-2.20.2/SDL2_ttf-2.20.2.tar.gz}"
: "${PNG_TARBALL:=libpng1.6_1.6.37.orig.tar.gz}"
: "${FREETYPE_TARBALL:=freetype_2.10.1.orig.tar.gz}"

: "${DL:=$ROOT/dl}"
: "${WORK:=$ROOT/work}"
: "${DIST:=$ROOT/dist}"
: "${CROSSDEV:=$WORK/riscos-crossdev}"
: "${STAGE:=$WORK/stage}"
export ROOT VERSION DL WORK DIST CROSSDEV STAGE
export RISCOS_TOOLCHAIN="${RISCOS_TOOLCHAIN:-$CROSSDEV/toolchain/env}"
export RISCOS_DEVKIT="${RISCOS_DEVKIT:-$WORK/devkit-${DEVKIT_TARBALL#riscos-mesa-devkit-}}"
RISCOS_DEVKIT=${RISCOS_DEVKIT%.tgz}
