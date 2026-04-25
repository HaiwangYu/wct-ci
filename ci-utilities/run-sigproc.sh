#!/usr/bin/env bash
# Run sigproc (signal processing) simulation and produce comparison plots.
# Usage:
#   ref mode: ./run-sigproc.sh ref <install_dir> <out_dir> <wct_ci_dir>
#   pr  mode: ./run-sigproc.sh pr  <install_dir> <out_dir> <wct_ci_dir> <ref_out_dir>
set -euo pipefail

MODE="$1"          # "ref" or "pr"
INSTALL_DIR="$2"
OUT_DIR="$3"
WCT_CI_DIR="$4"
REF_OUT_DIR="${5:-}"   # only required for pr mode

SIGPROC_DIR="$WCT_CI_DIR/sigproc"

export PATH="$INSTALL_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$INSTALL_DIR/lib:${LD_LIBRARY_PATH:-}"

mkdir -p "$OUT_DIR"

cp "$SIGPROC_DIR/check_pdsp_sim_sp.jsonnet" "$OUT_DIR/"
cp "$SIGPROC_DIR/depos.tar.bz2" "$OUT_DIR/"

cd "$OUT_DIR"

echo "[$MODE] Running signal processing simulation (sigproc)..."
wire-cell -l wire-cell-sp.log -L debug \
    -c check_pdsp_sim_sp.jsonnet \
    -C Nbit=12 -C elecGain=14 -C wire_col_nsigma=10.0 \
    -C use_dnnroi=true \
    -V input="$OUT_DIR/depos.tar.bz2" \
    -V output="$OUT_DIR/sp.tar.bz2"

if [[ "$MODE" == "pr" ]]; then
    [[ -z "$REF_OUT_DIR" ]] && { echo "ERROR: ref_out_dir required for pr mode" >&2; exit 1; }

    echo "[pr] Plotting sigproc frame..."
    wirecell-plot frame -n wave -o "$OUT_DIR/sp-frame.pdf" "$OUT_DIR/sp.tar.bz2"

    echo "[pr] Plotting waveform comparison — U plane (ch 700-701)..."
    wirecell-plot comp1d -n wave -t orig \
        --chmin 700 --chmax 701 \
        -o "$OUT_DIR/sp-comp-u.pdf" \
        "$REF_OUT_DIR/sp.tar.bz2" "$OUT_DIR/sp.tar.bz2"

    echo "[pr] Plotting waveform comparison — V plane (ch 1230-1231)..."
    wirecell-plot comp1d -n wave -t orig \
        --chmin 1230 --chmax 1231 \
        -o "$OUT_DIR/sp-comp-v.pdf" \
        "$REF_OUT_DIR/sp.tar.bz2" "$OUT_DIR/sp.tar.bz2"

    echo "[pr] Plotting waveform comparison — W plane (ch 2280-2281)..."
    wirecell-plot comp1d -n wave -t orig \
        --chmin 2280 --chmax 2281 \
        -o "$OUT_DIR/sp-comp-w.pdf" \
        "$REF_OUT_DIR/sp.tar.bz2" "$OUT_DIR/sp.tar.bz2"

    echo "[pr] Merging sigproc PDFs..."
    pdfunite "$OUT_DIR/sp-frame.pdf" "$OUT_DIR/sp-comp-u.pdf" "$OUT_DIR/sp-comp-v.pdf" "$OUT_DIR/sp-comp-w.pdf" \
        "$OUT_DIR/../03-sigproc-plots.pdf"
fi

echo "[$MODE] sigproc done: $OUT_DIR"
