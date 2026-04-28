#!/usr/bin/env bash
# Post-processing step - run OUTSIDE the container.
# Merges the PR review, compact test summaries, and validation PDFs into one report.
# Usage: ./make-report.sh <run_dir> <PR_number>
set -euo pipefail

RUN_DIR="$1"
PR_N="$2"

WORK_DIR="$(dirname "$RUN_DIR")"
REF_INSTALL="$WORK_DIR/ref-install"
PR_INSTALL="$WORK_DIR/pr-${PR_N}-install"

REF_SUMMARY="$RUN_DIR/ref-wct-tests-failures.txt"
PR_SUMMARY="$RUN_DIR/pr-wct-tests-failures.txt"
REF_TEST_LOG="$RUN_DIR/ref-wct-tests.log"
PR_TEST_LOG="$RUN_DIR/pr-wct-tests.log"
MANUAL_NOTES="$RUN_DIR/review-notes.md"

GEN_DIR="$RUN_DIR/pr-gen"
SIGPROC_DIR="$RUN_DIR/pr-sigproc"

REVIEW_TXT="$RUN_DIR/01-pr-review.txt"
REVIEW_PDF="$RUN_DIR/01-pr-review.pdf"
REF_SUMMARY_PDF="$RUN_DIR/02-ref-test-failures.pdf"
PR_SUMMARY_PDF="$RUN_DIR/03-pr-test-failures.pdf"
GEN_PDF="$RUN_DIR/04-gen-plots.pdf"
SIGPROC_PDF="$RUN_DIR/05-sigproc-plots.pdf"
REPORT="$RUN_DIR/report-pr${PR_N}.pdf"

# gs is more lenient than pdfunite with matplotlib-generated PDFs.
merge_pdfs() {
    local out="$1"; shift
    gs -dBATCH -dNOPAUSE -dQUIET -sDEVICE=pdfwrite -sOutputFile="$out" "$@"
}

convert_text_to_pdf() {
    local text="$1" out="$2"

    if command -v enscript &>/dev/null && command -v ps2pdf &>/dev/null; then
        enscript -p "${out%.pdf}.ps" "$text" 2>/dev/null
        ps2pdf "${out%.pdf}.ps" "$out"
    elif command -v a2ps &>/dev/null && command -v ps2pdf &>/dev/null; then
        a2ps -o "${out%.pdf}.ps" "$text" 2>/dev/null
        ps2pdf "${out%.pdf}.ps" "$out"
    elif command -v pandoc &>/dev/null; then
        pandoc "$text" -o "$out" --pdf-engine=pdflatex 2>/dev/null
    else
        echo "WARNING: no text-to-PDF tool found (enscript/a2ps/pandoc). Skipping $out."
        return 1
    fi
}

summary_value() {
    local file="$1"
    local key="$2"
    awk -F': ' -v key="$key" '$1 == key { print $2; exit }' "$file" 2>/dev/null || true
}

normalized_failures() {
    local summary="$1"

    [[ -f "$summary" ]] || return 0
    awk '
        /^Failed tests:$/ { found=1; next }
        found && $0 != "None" && $0 != "" {
            sub(/[[:space:]]+\[[^]]+\][[:space:]]*$/, "")
            gsub(/^.*\/wct-pr-testing\/(ref-src|pr-[0-9]+-src)\//, "")
            print
        }
    ' "$summary" | sort -u
}

write_list_or_none() {
    local title="$1"
    local file="$2"

    echo "$title"
    if [[ -s "$file" ]]; then
        sed 's/^/  - /' "$file"
    else
        echo "  - None"
    fi
    echo ""
}

check_expected_command_path() {
    local log="$1"
    local cmd="$2"
    local expected_prefix="$3"

    [[ -f "$log" ]] || return 0
    local resolved
    resolved="$(awk -F': ' -v cmd="$cmd" '$1 == cmd { print $2; exit }' "$log")"
    [[ -n "$resolved" ]] || return 0
    if [[ "$resolved" != "$expected_prefix"/* ]]; then
        echo "$log: $cmd resolved to $resolved, expected under $expected_prefix"
    fi
}

generate_review() {
    local ref_norm pr_norm common pr_only ref_only suggestions
    local ref_failed pr_failed

    ref_norm="$(mktemp)"
    pr_norm="$(mktemp)"
    common="$(mktemp)"
    pr_only="$(mktemp)"
    ref_only="$(mktemp)"
    suggestions="$(mktemp)"

    normalized_failures "$REF_SUMMARY" > "$ref_norm"
    normalized_failures "$PR_SUMMARY" > "$pr_norm"
    comm -12 "$ref_norm" "$pr_norm" > "$common"
    comm -13 "$ref_norm" "$pr_norm" > "$pr_only"
    comm -23 "$ref_norm" "$pr_norm" > "$ref_only"

    ref_failed="$(summary_value "$REF_SUMMARY" "Failed")"
    pr_failed="$(summary_value "$PR_SUMMARY" "Failed")"

    {
        echo "PR #$PR_N review summary"
        echo "Generated: $(date -Is)"
        echo "Run directory: $RUN_DIR"
        echo ""
        echo "Test overview"
        echo "  - Reference failures: ${ref_failed:-unknown}"
        echo "  - PR failures: ${pr_failed:-unknown}"
        echo ""
        write_list_or_none "PR-only failures" "$pr_only"
        write_list_or_none "Failures common to ref and PR" "$common"
        write_list_or_none "Ref-only failures" "$ref_only"
        echo "Validation artifacts"
        for required in \
            "$REF_TEST_LOG" "$PR_TEST_LOG" \
            "$RUN_DIR/ref-gen/run-gen.log" "$RUN_DIR/pr-gen/run-gen.log" \
            "$RUN_DIR/ref-sigproc/run-sigproc.log" "$RUN_DIR/pr-sigproc/run-sigproc.log" \
            "$GEN_DIR/signal-frame.pdf" "$GEN_DIR/signal-comp-wave.pdf" \
            "$SIGPROC_DIR/sp-frame.pdf" "$SIGPROC_DIR/sp-comp-u.pdf" \
            "$SIGPROC_DIR/sp-comp-v.pdf" "$SIGPROC_DIR/sp-comp-w.pdf"; do
            if [[ -f "$required" ]]; then
                echo "  - present: $required"
            else
                echo "  - missing: $required"
                echo "Missing validation artifact: $required" >> "$suggestions"
            fi
        done
        echo ""

        check_expected_command_path "$RUN_DIR/ref-gen/run-gen.log" "wire-cell" "$REF_INSTALL" >> "$suggestions"
        check_expected_command_path "$RUN_DIR/ref-gen/run-gen.log" "wirecell-plot" "$REF_INSTALL" >> "$suggestions"
        check_expected_command_path "$RUN_DIR/pr-gen/run-gen.log" "wire-cell" "$PR_INSTALL" >> "$suggestions"
        check_expected_command_path "$RUN_DIR/pr-gen/run-gen.log" "wirecell-plot" "$PR_INSTALL" >> "$suggestions"
        check_expected_command_path "$RUN_DIR/ref-sigproc/run-sigproc.log" "wire-cell" "$REF_INSTALL" >> "$suggestions"
        check_expected_command_path "$RUN_DIR/ref-sigproc/run-sigproc.log" "wirecell-plot" "$REF_INSTALL" >> "$suggestions"
        check_expected_command_path "$RUN_DIR/pr-sigproc/run-sigproc.log" "wire-cell" "$PR_INSTALL" >> "$suggestions"
        check_expected_command_path "$RUN_DIR/pr-sigproc/run-sigproc.log" "wirecell-plot" "$PR_INSTALL" >> "$suggestions"

        for log in "$REF_TEST_LOG" "$PR_TEST_LOG" \
            "$RUN_DIR/ref-gen/run-gen.log" "$RUN_DIR/pr-gen/run-gen.log" \
            "$RUN_DIR/ref-sigproc/run-sigproc.log" "$RUN_DIR/pr-sigproc/run-sigproc.log"; do
            if [[ -f "$log" ]] && grep -q "not found" "$log"; then
                echo "$log: ldd reported at least one missing shared library" >> "$suggestions"
            fi
        done

        if [[ -s "$pr_only" ]]; then
            echo "PR-only test failures are present; inspect these as possible PR regressions." >> "$suggestions"
        fi
        if [[ ! -s "$pr_only" && -s "$common" ]]; then
            echo "PR failures match reference failures; these are more likely pre-existing or environment-related." >> "$suggestions"
        fi
        if [[ -s "$ref_only" ]]; then
            echo "Reference-only failures are present; compare environment/setup before attributing differences to the PR." >> "$suggestions"
        fi

        write_list_or_none "Suggestions and warnings" "$suggestions"

        if [[ -f "$MANUAL_NOTES" ]]; then
            echo "Manual review notes"
            cat "$MANUAL_NOTES"
            echo ""
        else
            echo "Manual review notes"
            echo "  - Add optional notes in $MANUAL_NOTES before rerunning make-report.sh."
            echo ""
        fi
    } > "$REVIEW_TXT"

    rm -f "$ref_norm" "$pr_norm" "$common" "$pr_only" "$ref_only" "$suggestions"
}

generate_review

# Merge gen plots.
if [[ -f "$GEN_DIR/signal-frame.pdf" && -f "$GEN_DIR/signal-comp-wave.pdf" ]]; then
    echo "Merging gen plots -> $GEN_PDF"
    merge_pdfs "$GEN_PDF" \
        "$GEN_DIR/signal-frame.pdf" \
        "$GEN_DIR/signal-comp-wave.pdf"
else
    echo "WARNING: gen plots not found, skipping."
fi

# Merge sigproc plots.
if [[ -f "$SIGPROC_DIR/sp-frame.pdf" && -f "$SIGPROC_DIR/sp-comp-u.pdf" \
    && -f "$SIGPROC_DIR/sp-comp-v.pdf" && -f "$SIGPROC_DIR/sp-comp-w.pdf" ]]; then
    echo "Merging sigproc plots -> $SIGPROC_PDF"
    merge_pdfs "$SIGPROC_PDF" \
        "$SIGPROC_DIR/sp-frame.pdf" \
        "$SIGPROC_DIR/sp-comp-u.pdf" \
        "$SIGPROC_DIR/sp-comp-v.pdf" \
        "$SIGPROC_DIR/sp-comp-w.pdf"
else
    echo "WARNING: sigproc plots not found, skipping."
fi

PARTS=()
if convert_text_to_pdf "$REVIEW_TXT" "$REVIEW_PDF"; then
    PARTS+=("$REVIEW_PDF")
fi
if [[ -f "$REF_SUMMARY" ]] && convert_text_to_pdf "$REF_SUMMARY" "$REF_SUMMARY_PDF"; then
    PARTS+=("$REF_SUMMARY_PDF")
fi
if [[ -f "$PR_SUMMARY" ]] && convert_text_to_pdf "$PR_SUMMARY" "$PR_SUMMARY_PDF"; then
    PARTS+=("$PR_SUMMARY_PDF")
fi

[[ -f "$GEN_PDF" ]] && PARTS+=("$GEN_PDF") || echo "WARNING: gen PDF not found, skipping."
[[ -f "$SIGPROC_PDF" ]] && PARTS+=("$SIGPROC_PDF") || echo "WARNING: sigproc PDF not found, skipping."

if [[ ${#PARTS[@]} -eq 0 ]]; then
    echo "ERROR: no PDFs to merge." >&2
    exit 1
fi

echo "Merging ${#PARTS[@]} PDF(s) -> $REPORT"
merge_pdfs "$REPORT" "${PARTS[@]}"

echo "Review written: $REVIEW_TXT"
echo "Report written: $REPORT"
