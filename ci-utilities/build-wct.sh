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
# Pass --prefix through to configure-ssi-gcc.sh so it issues a single
# ./wcb configure call with both the compiler flags and the install prefix.
./gpvm/configure-ssi-gcc.sh --prefix="$INSTALL_DIR"

echo "Building and installing -> $INSTALL_DIR ..."
./wcb -p --notests build install 2>&1 | tee build.log

echo "Build complete: $SRC_DIR  (installed to $INSTALL_DIR)"
