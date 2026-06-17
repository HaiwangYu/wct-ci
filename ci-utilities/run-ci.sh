#!/usr/bin/env bash
# Main CI orchestrator: builds ref + target, runs tests and validation, produces a merged PDF report.
#
# The "target" (side under test) can be either:
#   - a GitHub PR:        --pr <PR_number>   [optionally --merge-pr]
#   - an arbitrary ref:   --target-ref <tag|master|branch>
#
# Usage:
#   ./run-ci.sh --ref <tag|master> --pr <PR_number> [--merge-pr]
#   ./run-ci.sh --ref <tag|master> --target-ref <tag|master|branch>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WCT_CI_DIR="$(dirname "$SCRIPT_DIR")"
WORK_DIR="/exp/dune/app/users/yuhw/wct-pr-testing"

REF=""
PR_N=""
TARGET_REF=""
SKIP_BUILD=0
SKIP_TESTS=0
MERGE_PR=0

usage() {
    echo "Usage: $0 --ref <tag|master> (--pr <PR_number> [--merge-pr] | --target-ref <tag|master|branch>) [--skip-build] [--skip-tests]"
    echo "  --pr <N>            test GitHub PR #N against --ref"
    echo "  --target-ref <ref>  test an arbitrary ref (tag/master/branch) against --ref"
    echo "  --merge-pr          (PR mode only) build/test the PR as REF plus the PR head merged in"
    echo "  --skip-build        skip clone/configure/build entirely; use existing installs in WORK_DIR"
    echo "  --skip-tests        skip ./wcb --tests --alltests; go straight to gen/sigproc validation"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ref)         REF="$2"; shift 2 ;;
        --pr)          PR_N="$2"; shift 2 ;;
        --target-ref)  TARGET_REF="$2"; shift 2 ;;
        --merge-pr)    MERGE_PR=1; shift ;;
        --skip-build)  SKIP_BUILD=1; shift ;;
        --skip-tests)  SKIP_TESTS=1; shift ;;
        *) usage ;;
    esac
done

[[ -z "$REF" ]] && usage

# Exactly one of --pr / --target-ref must be supplied.
if [[ -n "$PR_N" && -n "$TARGET_REF" ]]; then
    echo "ERROR: --pr and --target-ref are mutually exclusive" >&2
    usage
fi
if [[ -z "$PR_N" && -z "$TARGET_REF" ]]; then
    echo "ERROR: one of --pr or --target-ref is required" >&2
    usage
fi
if [[ -n "$TARGET_REF" && $MERGE_PR -eq 1 ]]; then
    echo "ERROR: --merge-pr is only valid with --pr" >&2
    usage
fi

# UPS setup scripts use unset variables and return non-zero; relax flags around them
set +eu
source /exp/dune/app/users/yuhw/setup.sh
set -eu

sanitize() { echo "$1" | sed 's#[^A-Za-z0-9._-]#_#g'; }

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REF_SRC="$WORK_DIR/ref-src"
REF_INSTALL="$WORK_DIR/ref-install"

if [[ -n "$TARGET_REF" ]]; then
    TARGET_KIND="ref"
    TARGET_ID="$TARGET_REF"
    TGT_SAFE="$(sanitize "$TARGET_REF")"
    REF_SAFE="$(sanitize "$REF")"
    PR_SRC="$WORK_DIR/target-${TGT_SAFE}-src"
    PR_INSTALL="$WORK_DIR/target-${TGT_SAFE}-install"
    RUN_DIR="$WORK_DIR/run-${TIMESTAMP}-target-${TGT_SAFE}"
    REPORT_LABEL="${TGT_SAFE}-vs-${REF_SAFE}"
    TITLE="Comparison: target '$TARGET_REF' vs reference '$REF'"
    TARGET_DESC="ref $TARGET_REF"
else
    TARGET_KIND="pr"
    TARGET_ID="$PR_N"
    PR_SRC="$WORK_DIR/pr-${PR_N}-src"
    PR_INSTALL="$WORK_DIR/pr-${PR_N}-install"
    RUN_DIR="$WORK_DIR/run-${TIMESTAMP}-pr${PR_N}"
    REPORT_LABEL="pr${PR_N}"
    TITLE="PR #$PR_N"
    TARGET_DESC="PR #$PR_N $([[ $MERGE_PR -eq 1 ]] && echo "(merged into $REF)" || echo "(PR head)")"
fi

mkdir -p "$RUN_DIR" "$WORK_DIR"

# Record resolved paths/labels so make-report.sh can run without re-deriving them.
cat > "$RUN_DIR/ci-meta.env" <<EOF
REF='$REF'
TARGET_KIND='$TARGET_KIND'
TARGET_ID='$TARGET_ID'
REF_SRC='$REF_SRC'
REF_INSTALL='$REF_INSTALL'
PR_SRC='$PR_SRC'
PR_INSTALL='$PR_INSTALL'
REPORT_LABEL='$REPORT_LABEL'
TITLE='$TITLE'
EOF

echo "=== WCT CI run ==="
echo "  reference : $REF"
echo "  target    : $TARGET_DESC"
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

# Build target (PR head, PR merged into ref, or an arbitrary ref)
if [[ $SKIP_BUILD -eq 1 ]]; then
    echo "[2/6] Skipping target build (--skip-build)"
elif [[ "$TARGET_KIND" == "ref" ]]; then
    echo "[2/6] Building target ref ($TARGET_REF)..."
    "$SCRIPT_DIR/build-wct.sh" ref "$TARGET_REF" "$PR_SRC" "$PR_INSTALL" \
        2>&1 | tee "$RUN_DIR/build-pr.log"
elif [[ $MERGE_PR -eq 1 ]]; then
    echo "[2/6] Building PR #$PR_N merged into $REF..."
    "$SCRIPT_DIR/build-wct.sh" merge-pr "$PR_N" "$PR_SRC" "$PR_INSTALL" "$REF" \
        2>&1 | tee "$RUN_DIR/build-pr.log"
else
    echo "[2/6] Building PR #$PR_N..."
    "$SCRIPT_DIR/build-wct.sh" pr "$PR_N" "$PR_SRC" "$PR_INSTALL" \
        2>&1 | tee "$RUN_DIR/build-pr.log"
fi

# Run wct unit tests on reference and target builds
if [[ $SKIP_TESTS -eq 1 ]]; then
    echo "[3/6] Skipping wct unit tests (--skip-tests)"
else
    echo "[3/6] Running wct unit tests for reference and target..."
    "$SCRIPT_DIR/run-wct-tests.sh" "$REF_SRC" "$RUN_DIR/ref-wct-tests.log" \
        "$RUN_DIR/ref-wct-tests-failures.txt" "ref"
    "$SCRIPT_DIR/run-wct-tests.sh" "$PR_SRC" "$RUN_DIR/pr-wct-tests.log" \
        "$RUN_DIR/pr-wct-tests-failures.txt" "target"
fi

# Run gen validation (reference, then target)
echo "[4/6] Running gen validation..."
"$SCRIPT_DIR/run-gen.sh" ref "$REF_INSTALL" "$REF_SRC" "$RUN_DIR/ref-gen" "$WCT_CI_DIR"
"$SCRIPT_DIR/run-gen.sh" pr  "$PR_INSTALL"  "$PR_SRC"  "$RUN_DIR/pr-gen"  "$WCT_CI_DIR" "$RUN_DIR/ref-gen"

# Run sigproc validation (reference, then target)
echo "[5/6] Running sigproc validation..."
"$SCRIPT_DIR/run-sigproc.sh" ref "$REF_INSTALL" "$REF_SRC" "$RUN_DIR/ref-sigproc" "$WCT_CI_DIR"
"$SCRIPT_DIR/run-sigproc.sh" pr  "$PR_INSTALL"  "$PR_SRC"  "$RUN_DIR/pr-sigproc"  "$WCT_CI_DIR" "$RUN_DIR/ref-sigproc"

echo ""
echo "In-container steps done. Run the following OUTSIDE the container to merge PDFs:"
echo ""
echo "  $SCRIPT_DIR/make-report.sh $RUN_DIR"
