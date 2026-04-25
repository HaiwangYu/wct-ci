#!/usr/bin/env bash
# Run wire-cell-toolkit unit tests on the PR build and save the log.
# Usage: ./run-wct-tests.sh <src_dir> <log_file>
set -euo pipefail

SRC_DIR="$1"
LOG_FILE="$2"

cd "$SRC_DIR"

export WIRECELL_PATH="$SRC_DIR/cfg:${WIRECELL_PATH:-}"

echo "Running ./wcb --tests --alltests in $SRC_DIR ..."
./wcb --tests --alltests 2>&1 | tee "$LOG_FILE" || true   # don't abort on test failures

echo ""
echo "--- Test summary ---"
# waf runs bats tests; passing tests are listed as "<path>.bats [<time>]"
# failures show "not ok" (TAP) or "FAILED" in the waf summary line
PASSED=$(grep -c "\.bats \[" "$LOG_FILE" 2>/dev/null || true)
FAILED=$(grep -cE "(^not ok |FAILED)" "$LOG_FILE" 2>/dev/null || true)
echo "  Passed : ${PASSED:-0} test files"
echo "  Failed : ${FAILED:-0}"
echo "  Full log: $LOG_FILE"
