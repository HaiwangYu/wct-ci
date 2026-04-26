#!/usr/bin/env bash
# Convert the test log to PDF and merge all PDFs into a single report.
# Usage: ./make-report.sh <run_dir> <PR_number>
set -euo pipefail

RUN_DIR="$1"
PR_N="$2"

LOG="$RUN_DIR/wct-tests.log"
SUMMARY_PDF="$RUN_DIR/01-test-summary.pdf"
GEN_PDF="$RUN_DIR/02-gen-plots.pdf"
SIGPROC_PDF="$RUN_DIR/03-sigproc-plots.pdf"
REPORT="$RUN_DIR/report-pr${PR_N}.pdf"

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

echo "Converting test log to PDF..."
PARTS=()
if convert_log_to_pdf "$LOG" "$SUMMARY_PDF"; then
    PARTS+=("$SUMMARY_PDF")
else
    echo "  (test-summary PDF skipped; raw log is at $LOG)"
fi

[[ -f "$GEN_PDF"     ]] && PARTS+=("$GEN_PDF")     || echo "WARNING: gen plots PDF not found, skipping."
[[ -f "$SIGPROC_PDF" ]] && PARTS+=("$SIGPROC_PDF") || echo "WARNING: sigproc plots PDF not found, skipping."

if [[ ${#PARTS[@]} -eq 0 ]]; then
    echo "ERROR: no PDFs to merge." >&2
    exit 1
fi

echo "Merging ${#PARTS[@]} PDF(s) -> $REPORT"
gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile="$REPORT" "${PARTS[@]}"

echo "Report written: $REPORT"
