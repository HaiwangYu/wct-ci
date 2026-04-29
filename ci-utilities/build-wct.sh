#!/usr/bin/env bash
# Clone and build wire-cell-toolkit for either a reference tag/master or a PR branch.
# Usage: ./build-wct.sh <ref|pr> <tag|master|PR_number> <src_dir> <install_dir>
set -euo pipefail

MODE="$1"     # "ref" or "pr"
TARGET="$2"   # tag/master for ref mode; PR number for pr mode
SRC_DIR="$3"
INSTALL_DIR="$4"

WCT_REPO="https://github.com/WireCell/wire-cell-toolkit"

if [[ -d "$SRC_DIR" ]]; then
    echo "Removing existing source dir: $SRC_DIR"
    rm -rf "$SRC_DIR"
fi

echo "Cloning $WCT_REPO -> $SRC_DIR"
git clone "$WCT_REPO" "$SRC_DIR"

cd "$SRC_DIR"

if [[ "$MODE" == "ref" ]]; then
    echo "Checking out reference: $TARGET"
    git checkout "$TARGET"
elif [[ "$MODE" == "pr" ]]; then
    echo "Fetching PR #$TARGET"
    git fetch origin "pull/${TARGET}/head"
    git checkout FETCH_HEAD
else
    echo "ERROR: mode must be 'ref' or 'pr'" >&2
    exit 1
fi

echo "Configuring (compiler + prefix)..."
env CC=gcc CXX=g++ FC=gfortran \
./wcb configure \
    --build-debug="-O3 -g -fno-omit-frame-pointer" \
    --with-tbb="$TBBROOT" \
    --with-jsoncpp="$JSONCPP_FQ_DIR" \
    --with-jsonnet-include="$GOJSONNET_FQ_DIR/include" \
    --with-jsonnet-lib="$GOJSONNET_FQ_DIR/lib" \
    --with-eigen-include="$EIGEN_DIR/include/eigen3/" \
    --with-root="$ROOTSYS" \
    --with-fftw="$FFTW_FQ_DIR" \
    --with-fftw-include="$FFTW_INC" \
    --with-fftw-lib="$FFTW_LIBRARY" \
    --with-fftwthreads="$FFTW_FQ_DIR" \
    --boost-includes="$BOOST_INC" \
    --boost-libs="$BOOST_LIB" \
    --boost-mt \
    --with-hdf5="$HDF5_FQ_DIR" \
    --with-spdlog-include="$SPDLOG_INC" \
    --with-spdlog-lib="$SPDLOG_LIB" \
    --with-protobuf-include="$PROTOBUF_INC/" \
    --with-protobuf-lib="$PROTOBUF_LIB" \
    --with-grpc="$GRPC_FQ_DIR" \
    --with-grpc-include="$GRPC_INC" \
    --with-grpc-lib="$GRPC_LIB" \
    --with-triton-include="$TRITON_INC" \
    --with-triton-lib="$TRITON_LIB" \
    --with-libtorch="$LIBTORCH_FQ_DIR/" \
    --with-libtorch-libs torch,torch_cpu,c10 \
    --prefix="$INSTALL_DIR"

echo "Building and installing -> $INSTALL_DIR ..."
./wcb -p --notests build install 2>&1 | tee build.log

echo "Build complete: $SRC_DIR  (installed to $INSTALL_DIR)"
