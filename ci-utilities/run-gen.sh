#!/usr/bin/env bash
# Run gen (signal + noise) simulation and produce comparison plots.
# Usage:
#   ref mode: ./run-gen.sh ref <install_dir> <src_dir> <out_dir> <wct_ci_dir>
#   pr  mode: ./run-gen.sh pr  <install_dir> <src_dir> <out_dir> <wct_ci_dir> <ref_out_dir>
set -euo pipefail

MODE="$1"          # "ref" or "pr"
INSTALL_DIR="$2"
SRC_DIR="$3"       # wire-cell-toolkit source (for cfg/)
OUT_DIR="$4"
WCT_CI_DIR="$5"
REF_OUT_DIR="${6:-}"   # only required for pr mode

GEN_DIR="$WCT_CI_DIR/gen"

# Prepend the built install and its cfg to the search paths
export PATH="$INSTALL_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$INSTALL_DIR/lib:${LD_LIBRARY_PATH:-}"
export WIRECELL_PATH="$SRC_DIR/cfg:${WIRECELL_PATH:-}"

mkdir -p "$OUT_DIR"

# Copy configs (jsonnet) and input data into the run directory
cp "$GEN_DIR"/*.jsonnet "$OUT_DIR/"
cp "$GEN_DIR/depos.tar.bz2" "$OUT_DIR/" 2>/dev/null || \
    cp "$WCT_CI_DIR/sigproc/depos.tar.bz2" "$OUT_DIR/"

cd "$OUT_DIR"

echo "[$MODE] Running signal simulation (gen)..."
wire-cell -l wire-cell-signal.log -L debug \
    -c check_pdsp_sim.jsonnet \
    -C Nbit=12 -C elecGain=14 -C wire_col_nsigma=10.0 \
    -V input="$OUT_DIR/depos.tar.bz2" \
    -V output="$OUT_DIR/signal.tar.bz2"

echo "[$MODE] Running noise simulation (gen)..."
# check_pdsp_noise.jsonnet appends ".tar.bz2" to the output value, so pass path without extension
wire-cell -l wire-cell-noise.log -L debug \
    -c check_pdsp_noise.jsonnet \
    -C Nbit=12 -C elecGain=14 -C wire_col_nsigma=10.0 \
    -V output="$OUT_DIR/noise"

if [[ "$MODE" == "pr" ]]; then
    [[ -z "$REF_OUT_DIR" ]] && { echo "ERROR: ref_out_dir required for pr mode" >&2; exit 1; }

    echo "[pr] Plotting signal frame..."
    wirecell-plot frame -n wave -o "$OUT_DIR/signal-frame.pdf" "$OUT_DIR/signal.tar.bz2"

    echo "[pr] Plotting signal waveform comparison (ch 700-701)..."
    wirecell-plot comp1d -n wave \
        --chmin 700 --chmax 701 \
        --transform=median \
        -o "$OUT_DIR/signal-comp-wave.pdf" \
        "$REF_OUT_DIR/signal.tar.bz2" "$OUT_DIR/signal.tar.bz2"

    echo "[pr] gen plots written to $OUT_DIR (merge outside container)"
fi

echo "[$MODE] gen done: $OUT_DIR"
