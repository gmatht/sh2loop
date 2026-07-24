#!/bin/bash
# Reset the failure baseline to match current test results.
# Updates failing_tests.txt and .last_trusted_count in sh2perl/.
set -e

cd "$(dirname "$0")"

echo "Running full test suite to get current failure count..."
cd sh2perl
../fail 2>&1 | tee /tmp/fail_output.txt
FAIL_COUNT=$(grep -c '^  FAIL:' /tmp/fail_output.txt || true)
echo "FAIL lines: $FAIL_COUNT"

grep '^  FAIL:' /tmp/fail_output.txt | sed 's/^  FAIL: //;s/ \[perl\].*//' > failing_tests.txt
echo "$FAIL_COUNT" > .last_trusted_count

echo "Reset: failing_tests.txt has $(wc -l < failing_tests.txt) entries, .last_trusted_count = $FAIL_COUNT"
