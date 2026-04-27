#!/usr/bin/env bash
# Post-processing step — run OUTSIDE the container.
# Merges individual PDFs produced by run-ci.sh into a single report.
# Usage: ./make-report.sh <run_dir> <PR_number>
set -euo pipefail

RUN_DIR="$1"
PR_N="$2"

LOG="$RUN_DIR/wct-tests.log"
GEN_DIR="$RUN_DIR/pr-gen"
SIGPROC_DIR="$RUN_DIR/pr-sigproc"
GEN_PDF="$RUN_DIR/02-gen-plots.pdf"
SIGPROC_PDF="$RUN_DIR/03-sigproc-plots.pdf"
SUMMARY_PDF="$RUN_DIR/01-test-summary.pdf"
REPORT="$RUN_DIR/report-pr${PR_N}.pdf"

# gs is more lenient than pdfunite with matplotlib-generated PDFs
merge_pdfs() {
    local out="$1"; shift
    gs -dBATCH -dNOPAUSE -dQUIET -sDEVICE=pdfwrite -sOutputFile="$out" "$@"
}

# Convert test log to PDF — try tools in order of preference
convert_log_to_pdf() {
    local log="$1" out="$2"
    if command -v enscript &>/dev/null && command -v ps2pdf &>/dev/null; then
        enscript -p "${out%.pdf}.ps" "$log" 2>/dev/null
        ps2pdf "${out%.pdf}.ps" "$out"
    elif command -v a2ps &>/dev/null && command -v ps2pdf &>/dev/null; then
        a2ps -o "${out%.pdf}.ps" "$log" 2>/dev/null
        ps2pdf "${out%.pdf}.ps" "$out"
    elif command -v pandoc &>/dev/null; then
        pandoc "$log" -o "$out" --pdf-engine=pdflatex 2>/dev/null
    else
        echo "WARNING: no text-to-PDF tool found (enscript/a2ps/pandoc). Skipping test-summary PDF."
        return 1
    fi
}

# Merge gen plots
if [[ -f "$GEN_DIR/signal-frame.pdf" ]]; then
    echo "Merging gen plots -> $GEN_PDF"
    merge_pdfs "$GEN_PDF" \
        "$GEN_DIR/signal-frame.pdf" \
        "$GEN_DIR/signal-comp-wave.pdf"
else
    echo "WARNING: gen plots not found, skipping."
fi

# Merge sigproc plots
if [[ -f "$SIGPROC_DIR/sp-frame.pdf" ]]; then
    echo "Merging sigproc plots -> $SIGPROC_PDF"
    merge_pdfs "$SIGPROC_PDF" \
        "$SIGPROC_DIR/sp-frame.pdf" \
        "$SIGPROC_DIR/sp-comp-u.pdf" \
        "$SIGPROC_DIR/sp-comp-v.pdf" \
        "$SIGPROC_DIR/sp-comp-w.pdf"
else
    echo "WARNING: sigproc plots not found, skipping."
fi

# Convert test log
PARTS=()
if [[ -f "$LOG" ]]; then
    echo "Converting test log to PDF..."
    if convert_log_to_pdf "$LOG" "$SUMMARY_PDF"; then
        PARTS+=("$SUMMARY_PDF")
    else
        echo "  (test-summary PDF skipped; raw log is at $LOG)"
    fi
fi

[[ -f "$GEN_PDF"     ]] && PARTS+=("$GEN_PDF")     || echo "WARNING: gen PDF not found, skipping."
[[ -f "$SIGPROC_PDF" ]] && PARTS+=("$SIGPROC_PDF") || echo "WARNING: sigproc PDF not found, skipping."

if [[ ${#PARTS[@]} -eq 0 ]]; then
    echo "ERROR: no PDFs to merge." >&2
    exit 1
fi

echo "Merging ${#PARTS[@]} PDF(s) -> $REPORT"
merge_pdfs "$REPORT" "${PARTS[@]}"

echo "Report written: $REPORT"
