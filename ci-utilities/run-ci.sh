#!/usr/bin/env bash
# Main CI orchestrator: builds ref + PR, runs tests and validation, produces a merged PDF report.
# Usage: ./run-ci.sh --ref <tag|master> --pr <PR_number>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WCT_CI_DIR="$(dirname "$SCRIPT_DIR")"
WORK_DIR="/exp/dune/app/users/yuhw/wct-pr-testing"

REF=""
PR_N=""
SKIP_BUILD=0
SKIP_TESTS=0

usage() {
    echo "Usage: $0 --ref <tag|master> --pr <PR_number> [--skip-build] [--skip-tests]"
    echo "  --skip-build  skip clone/configure/build entirely; use existing installs in WORK_DIR"
    echo "  --skip-tests  skip ./wcb --tests --alltests; go straight to gen/sigproc validation"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ref)         REF="$2"; shift 2 ;;
        --pr)          PR_N="$2"; shift 2 ;;
        --skip-build)  SKIP_BUILD=1; shift ;;
        --skip-tests)  SKIP_TESTS=1; shift ;;
        *) usage ;;
    esac
done

[[ -z "$REF" || -z "$PR_N" ]] && usage

# UPS setup scripts use unset variables and return non-zero; relax flags around them
set +eu
source /exp/dune/app/users/yuhw/setup.sh
set -eu

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$WORK_DIR/run-${TIMESTAMP}-pr${PR_N}"
REF_SRC="$WORK_DIR/ref-src"
REF_INSTALL="$WORK_DIR/ref-install"
PR_SRC="$WORK_DIR/pr-${PR_N}-src"
PR_INSTALL="$WORK_DIR/pr-${PR_N}-install"

mkdir -p "$RUN_DIR" "$WORK_DIR"

echo "=== WCT CI run ==="
echo "  ref       : $REF"
echo "  PR        : #$PR_N"
echo "  work dir  : $WORK_DIR"
echo "  run dir   : $RUN_DIR"
echo ""

# Build reference
if [[ $SKIP_BUILD -eq 1 ]]; then
    echo "[1/6] Skipping reference build (--skip-build)"
else
    echo "[1/6] Building reference ($REF)..."
    "$SCRIPT_DIR/build-wct.sh" ref "$REF" "$REF_SRC" "$REF_INSTALL" \
        2>&1 | tee "$RUN_DIR/build-ref.log"
fi

# Build PR
if [[ $SKIP_BUILD -eq 1 ]]; then
    echo "[2/6] Skipping PR build (--skip-build)"
else
    echo "[2/6] Building PR #$PR_N..."
    "$SCRIPT_DIR/build-wct.sh" pr "$PR_N" "$PR_SRC" "$PR_INSTALL" \
        2>&1 | tee "$RUN_DIR/build-pr.log"
fi

# Run wct unit tests on reference and PR builds
if [[ $SKIP_TESTS -eq 1 ]]; then
    echo "[3/6] Skipping wct unit tests (--skip-tests)"
else
    echo "[3/6] Running wct unit tests for reference and PR..."
    "$SCRIPT_DIR/run-wct-tests.sh" "$REF_SRC" "$RUN_DIR/ref-wct-tests.log" \
        "$RUN_DIR/ref-wct-tests-failures.txt" "ref"
    "$SCRIPT_DIR/run-wct-tests.sh" "$PR_SRC" "$RUN_DIR/pr-wct-tests.log" \
        "$RUN_DIR/pr-wct-tests-failures.txt" "pr"
fi

# Run gen validation (reference, then PR)
echo "[4/6] Running gen validation..."
"$SCRIPT_DIR/run-gen.sh" ref "$REF_INSTALL" "$REF_SRC" "$RUN_DIR/ref-gen" "$WCT_CI_DIR"
"$SCRIPT_DIR/run-gen.sh" pr  "$PR_INSTALL"  "$PR_SRC"  "$RUN_DIR/pr-gen"  "$WCT_CI_DIR" "$RUN_DIR/ref-gen"

# Run sigproc validation (reference, then PR)
echo "[5/6] Running sigproc validation..."
"$SCRIPT_DIR/run-sigproc.sh" ref "$REF_INSTALL" "$REF_SRC" "$RUN_DIR/ref-sigproc" "$WCT_CI_DIR"
"$SCRIPT_DIR/run-sigproc.sh" pr  "$PR_INSTALL"  "$PR_SRC"  "$RUN_DIR/pr-sigproc"  "$WCT_CI_DIR" "$RUN_DIR/ref-sigproc"

echo ""
echo "In-container steps done. Run the following OUTSIDE the container to merge PDFs:"
echo ""
echo "  $SCRIPT_DIR/make-report.sh $RUN_DIR $PR_N"
