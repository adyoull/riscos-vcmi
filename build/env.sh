# Source this: . build/env.sh
# Versions and checksums of everything the RISC OS build of VCMI uses.
# Each can be overridden from the environment.
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

: "${VERSION:=1.7.5-riscos11test}"
: "${VCMI_REF:=1.7.5}"
: "${VCMI_GIT:=https://github.com/vcmi/vcmi.git}"
# fuzzylite is a submodule of VCMI (AI/FuzzyLite), at the commit VCMI pins.
: "${FUZZYLITE_GIT:=https://github.com/fuzzylite/fuzzylite.git}"

# riscos-crossdev (kit + prebuilt toolchain) and the riscos-mesa devkit (SDL2, zlib).
# riscos-crossdev and riscos-mesa: the releases named in .riscos-deps.
deps_tag() { awk -v n="$1" '$1 == n || $1 == "adyoull/" n {print $2}' "$ROOT/.riscos-deps"; }
: "${CROSSDEV_REF:=$(deps_tag riscos-crossdev)}"
: "${MESA_TAG:=$(deps_tag riscos-mesa)}"
: "${CROSSDEV_GIT:=https://github.com/adyoull/riscos-crossdev.git}"
: "${TOOLCHAIN_TARBALL:=riscos-crossdev-toolchain-1.4-x86_64-linux.tar.xz}"
: "${DEVKIT_VERSION:=${MESA_TAG#v}}"
# The riscos-mesa devkit of that release (20.3.5-17 has the overlay path for
# SDL software windows, newer than the devkit riscos-crossdev installs):
# build-deps.sh fetches it if it isn't in dl/, checks it against
# SHA256SUMS.txt and unpacks it into $RISCOS_DEVKIT.
: "${DEVKIT_TARBALL:=riscos-mesa-devkit-$DEVKIT_VERSION.tgz}"
: "${DEVKIT_URL:=https://github.com/adyoull/riscos-mesa/releases/download/$MESA_TAG/$DEVKIT_TARBALL}"

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
# In riscos-crossdev's container image (GitHub), RCD_DIR is the kit, with
# its toolchain installed; elsewhere it's cloned into work/.
if [ -z "${CROSSDEV:-}" ] && [ -f "${RCD_DIR:-}/env.sh" ] && [ -x "${RISCOS_TOOLCHAIN:-}/bin/arm-riscos-gnueabihf-gcc" ]; then
  CROSSDEV=$RCD_DIR
fi
: "${CROSSDEV:=$WORK/riscos-crossdev}"
: "${STAGE:=$WORK/stage}"
export ROOT VERSION DL WORK DIST CROSSDEV STAGE
export RISCOS_TOOLCHAIN="${RISCOS_TOOLCHAIN:-$CROSSDEV/toolchain/env}"
# Our devkit, unless the one already set (the image's) is the same version.
if ! grep -qx "riscos-mesa devkit $DEVKIT_VERSION" "${RISCOS_DEVKIT:-/nonexistent}/VERSION" 2>/dev/null; then
  RISCOS_DEVKIT=$WORK/devkit-$DEVKIT_VERSION
fi
export RISCOS_DEVKIT
