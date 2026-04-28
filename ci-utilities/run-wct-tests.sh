#!/usr/bin/env bash
# Run wire-cell-toolkit unit tests and save a full log plus a failure-only summary.
# Usage: ./run-wct-tests.sh <src_dir> <log_file> <summary_file> [label]
set -euo pipefail

SRC_DIR="$1"
LOG_FILE="$2"
SUMMARY_FILE="$3"
LABEL="${4:-wct}"

mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$SUMMARY_FILE")"

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

    {
        echo "=== WCT test runtime context ($LABEL) ==="
        echo "date: $(date -Is)"
        echo "src_dir: $SRC_DIR"
        echo "git_commit: ${git_commit:-unknown}"
        echo "command: ./wcb --tests --alltests"
        echo "PATH: $PATH"
        echo "LD_LIBRARY_PATH: ${LD_LIBRARY_PATH:-}"
        echo "WIRECELL_PATH: ${WIRECELL_PATH:-}"
        echo ""
        echo "--- resolved commands ---"
        echo "wcb: $SRC_DIR/wcb"
        echo "wire-cell: $(resolve_command wire-cell)"
        echo "wirecell-plot: $(resolve_command wirecell-plot)"
        log_ldd "$SRC_DIR/wcb"
        log_ldd "$(resolve_command wire-cell)"
        log_ldd "$(resolve_command wirecell-plot)"
        echo ""
        echo "=== WCT test stdout ($LABEL) ==="
    } > "$LOG_FILE"
}

extract_failed_tests() {
    local log_file="$1"
    local out_file="$2"
    local tmp_failed
    local summary_line
    local failed_count="0"
    local total_count="unknown"

    tmp_failed="$(mktemp)"
    awk '
        found && /^'\''build'\'' finished/ { exit }
        found && /^[[:space:]]+\// {
            sub(/^[[:space:]]+/, "")
            print
        }
        /tests that fail[[:space:]]+[0-9]+\/[0-9]+/ { found=1 }
    ' "$log_file" > "$tmp_failed"

    summary_line="$(grep -E "tests that fail[[:space:]]+[0-9]+/[0-9]+" "$log_file" | tail -n 1 || true)"
    if [[ "$summary_line" =~ tests[[:space:]]that[[:space:]]fail[[:space:]]([0-9]+)/([0-9]+) ]]; then
        failed_count="${BASH_REMATCH[1]}"
        total_count="${BASH_REMATCH[2]}"
    elif [[ -s "$tmp_failed" ]]; then
        failed_count="$(wc -l < "$tmp_failed" | tr -d '[:space:]')"
    fi

    {
        echo "WCT test failure summary ($LABEL)"
        echo "Source: $SRC_DIR"
        echo "Log: $LOG_FILE"
        echo "Failed: $failed_count"
        echo "Total: $total_count"
        echo ""
        echo "Failed tests:"
        if [[ -s "$tmp_failed" ]]; then
            cat "$tmp_failed"
        else
            echo "None"
        fi
    } > "$out_file"

    rm -f "$tmp_failed"
}

append_failed_test_ldd() {
    local summary_file="$1"
    local failed_exe
    local seen_file

    seen_file="$(mktemp)"
    {
        echo ""
        echo "=== Shared libraries for failed compiled tests ($LABEL) ==="
    } >> "$LOG_FILE"

    while IFS= read -r failed_exe; do
        failed_exe="${failed_exe%% \[*}"
        [[ "$failed_exe" == /* ]] || continue
        [[ -x "$failed_exe" ]] || continue
        if grep -Fxq "$failed_exe" "$seen_file"; then
            continue
        fi
        printf '%s\n' "$failed_exe" >> "$seen_file"
        log_ldd "$failed_exe" >> "$LOG_FILE"
    done < <(awk '/^Failed tests:$/ { found=1; next } found { print }' "$summary_file")

    rm -f "$seen_file"
}

cd "$SRC_DIR"

export WIRECELL_PATH="$SRC_DIR/cfg:${WIRECELL_PATH:-}"

write_context

set +e
{
    echo "Running ./wcb --tests --alltests in $SRC_DIR ..."
    ./wcb --tests --alltests
} 2>&1 | tee -a "$LOG_FILE"
WCB_STATUS=${PIPESTATUS[0]}
set -e
echo "wcb_exit_status: $WCB_STATUS" | tee -a "$LOG_FILE"

extract_failed_tests "$LOG_FILE" "$SUMMARY_FILE"
append_failed_test_ldd "$SUMMARY_FILE"

echo ""
echo "--- Test summary ($LABEL) ---"
cat "$SUMMARY_FILE"
echo "Full log: $LOG_FILE"

# Do not abort the CI workflow on test failures.
exit 0
