#!/bin/bash
# The GitHub build (and anyone's full build from a clean clone): libraries,
# VCMI, the package and the host tests. In riscos-crossdev's container image
# the kit and toolchain are the image's; elsewhere they're fetched.
#   build/ci.sh [VERSION]      (default "ci": dist/vcmi-ci.zip)
set -euo pipefail
cd "$(dirname "$0")/.."
export VERSION=${1:-ci}
build/build-deps.sh
build/build-vcmi.sh
build/package.sh
tests/present/run.sh
tests/tbbshim/run.sh
tests/sound/run.sh
ls -l dist/vcmi-"$VERSION".zip
