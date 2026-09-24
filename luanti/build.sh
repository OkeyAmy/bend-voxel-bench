#!/bin/sh
# Builds luantiserver 5.17.0 with the bend-voxel-bench timing patch into
# luanti/src/bin/luantiserver (RUN_IN_PLACE, server only, Release flags).
# Needs: sudo dnf install -y cmake make gcc-c++ sqlite-devel luajit-devel zlib-devel libzstd-devel
set -eu
cd "$(dirname "$0")"
TAG=5.17.0
if [ ! -d src/.git ]; then
  git clone --depth 1 --branch "$TAG" https://github.com/luanti-org/luanti.git src
fi
cd src
test "$(git describe --tags --exact-match)" = "$TAG" || { echo "luanti/src is not at $TAG" >&2; exit 1; }
if ! grep -q "bend-voxel-bench timing patch" src/mapgen/mapgen_v7.cpp; then
  git apply ../timing.patch
fi
cmake -B build -DCMAKE_BUILD_TYPE=Release -DRUN_IN_PLACE=TRUE \
  -DBUILD_CLIENT=FALSE -DBUILD_SERVER=TRUE -DBUILD_UNITTESTS=FALSE \
  -DENABLE_CURL=FALSE -DENABLE_GETTEXT=FALSE -DENABLE_SOUND=FALSE
cmake --build build -j"$(nproc)"
./bin/luantiserver --version | head -1
