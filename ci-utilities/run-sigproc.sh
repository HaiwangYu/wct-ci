#!/usr/bin/env bash
# Run sigproc (signal processing) simulation and produce comparison plots.
# Usage:
#   ref mode: ./run-sigproc.sh ref <install_dir> <src_dir> <out_dir> <wct_ci_dir>
#   pr  mode: ./run-sigproc.sh pr  <install_dir> <src_dir> <out_dir> <wct_ci_dir> <ref_out_dir>
set -euo pipefail

MODE="$1"          # "ref" or "pr"
INSTALL_DIR="$2"
SRC_DIR="$3"       # wire-cell-toolkit source (for cfg/)
OUT_DIR="$4"
WCT_CI_DIR="$5"
REF_OUT_DIR="${6:-}"   # only required for pr mode

SIGPROC_DIR="$WCT_CI_DIR/sigproc"
LOCAL_WIRE_CELL="$SRC_DIR/build/apps/wire-cell"

build_library_path() {
    local lib_path=""
    local lib_dir

    while IFS= read -r lib_dir; do
        if [[ -z "$lib_path" ]]; then
            lib_path="$lib_dir"
        else
            lib_path="$lib_path:$lib_dir"
        fi
    done < <(find "$SRC_DIR/build" -mindepth 1 -maxdepth 2 -type f -name 'libWireCell*.so' \
        -printf '%h\n' 2>/dev/null | sort -u)

    printf '%s' "$lib_path"
}

require_local_build() {
    if [[ ! -x "$LOCAL_WIRE_CELL" ]]; then
        echo "ERROR: local build executable not found or not executable: $LOCAL_WIRE_CELL" >&2
        echo "       Refusing to fall back to CVMFS wire-cell." >&2
        exit 1
    fi
}

log_ldd() {
    local exe="$1"

    if [[ -z "$exe" || ! -e "$exe" ]]; then
        return
    fi

    echo ""
    echo "--- ldd: $exe ---"
    if [[ -x "$exe" ]]; then
        ldd "$exe" 2>&1 || true
    else
        echo "not executable"
    fi
}

resolve_command() {
    local cmd="$1"
    command -v "$cmd" 2>/dev/null || true
}

write_context() {
    local git_commit
    git_commit="$(git -C "$SRC_DIR" rev-parse --short HEAD 2>/dev/null || true)"

    echo "=== sigproc runtime context ($MODE) ==="
    echo "date: $(date -Is)"
    echo "install_dir: $INSTALL_DIR"
    echo "src_dir: $SRC_DIR"
    echo "git_commit: ${git_commit:-unknown}"
    echo "out_dir: $OUT_DIR"
    echo "PATH: $PATH"
    echo "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH:-}"
    echo "WIRECELL_PATH: ${WIRECELL_PATH:-}"
    echo ""
    echo "--- resolved commands ---"
    echo "expected_wire-cell: $LOCAL_WIRE_CELL"
    echo "wire-cell: $(resolve_command wire-cell)"
    echo "wirecell-plot: $(resolve_command wirecell-plot)"
    if [[ "$(resolve_command wire-cell)" != "$LOCAL_WIRE_CELL" ]]; then
        echo "ERROR: wire-cell resolved outside the local build tree"
        echo "       expected: $LOCAL_WIRE_CELL"
        echo "       actual:   $(resolve_command wire-cell)"
        exit 1
    fi
    log_ldd "$(resolve_command wire-cell)"
    log_ldd "$(resolve_command wirecell-plot)"
    echo ""
    echo "=== sigproc stdout ($MODE) ==="
}

require_local_build
BUILD_LIB_PATH="$(build_library_path)"

# Prefer the build tree. The install prefix may not exist for --skip-build reruns.
export PATH="$SRC_DIR/build/apps:$INSTALL_DIR/bin:$PATH"
if [[ -n "$BUILD_LIB_PATH" ]]; then
    export LD_LIBRARY_PATH="$BUILD_LIB_PATH:$INSTALL_DIR/lib:${LD_LIBRARY_PATH:-}"
else
    export LD_LIBRARY_PATH="$INSTALL_DIR/lib:${LD_LIBRARY_PATH:-}"
fi
export WIRECELL_PATH="$SRC_DIR/cfg:${WIRECELL_PATH:-}"

mkdir -p "$OUT_DIR"

exec > >(tee "$OUT_DIR/run-sigproc.log") 2>&1
write_context

cp "$SIGPROC_DIR/check_pdsp_sim_sp.jsonnet" "$OUT_DIR/"
cp "$SIGPROC_DIR/depos.tar.bz2" "$OUT_DIR/"
cp -r "$SIGPROC_DIR/ts-model" "$OUT_DIR/"

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

    echo "[pr] sigproc plots written to $OUT_DIR (merge outside container)"
fi

echo "[$MODE] sigproc done: $OUT_DIR"
