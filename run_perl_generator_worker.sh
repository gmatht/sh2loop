#!/usr/bin/env bash
# perl-generator scoped worker — FAILURE-DRIVEN.
#
# Fixes the AST Generator's Perl OUTPUT (otranspilerl-cli file.sh -> Generator ->
# Perl text — the product path `./fail` gates). Failure-driven like the
# frontend workers: green -> commit scoped changes; red -> invoke pi;
# 3 consecutive failures -> TRAP (core-request + sleeping marker).
#
# Gate: ./fail (byte-for-byte stdout + exit codes + side effects, since
# the strict-gate change). Scope: sh2perl/src/generator/ + harness/*.
# NEVER the shared core (src/shir.rs, src/ir.rs, src/estree.rs,
# src/parser/) — that is the estree worker's; escalate via core-requests.
set -euo pipefail
cd "$(dirname "$0")"
WORKSPACE="$(pwd)"
LOG="$WORKSPACE/loop-perl-generator.log"
SUBM="$WORKSPACE/sh2perl"
echo "[$(date +%FT%T)] perl-generator worker started (pid=$$)" >> "$LOG"
trusted_file="$WORKSPACE/.perl_gen_trusted_count"
trusted=-1   # seed from the first gate run
fail_count=0
while true; do
  bash "$WORKSPACE/setup_backends.sh" --wait >> "$LOG" 2>&1 || true
  echo "[$(date +%FT%T)] perl-generator: gate run" >> "$LOG"
  timeout 500 ./fail > "$WORKSPACE/.perlgen-gate.out" 2>&1 || true
  fails=$(grep -c '  FAIL:' "$WORKSPACE/.perlgen-gate.out" || true)
  [ "$trusted" = -1 ] && { trusted=$fails; echo "$fails" > "$trusted_file"; echo "[$(date +%FT%T)] seeded trusted=$fails" >> "$LOG"; }

  if [ "$fails" -eq 0 ]; then
    fail_count=0
    echo "[$(date +%FT%T)] perl-generator: gate GREEN" >> "$LOG"
    trusted=0; echo "0" > "$trusted_file"
  elif [ "$fails" -lt "$trusted" ]; then
    # improved — commit the scoped changes that did it, update trusted
    fail_count=0
    trusted=$fails; echo "$fails" > "$trusted_file"
    echo "[$(date +%FT%T)] perl-generator: improved to $fails (was $((fails+1))+)" >> "$LOG"
    changes=$(git -C "$SUBM" status --porcelain -- src/generator/ harness/ 2>/dev/null | wc -l)
    if [ "$changes" -gt 0 ]; then
      git -C "$SUBM" add src/generator/ 2>/dev/null || true
      git -C "$SUBM" commit -q -m "perl-generator: gate improved to $fails (trusted)" >> "$LOG" 2>&1 || true
      git -C "$WORKSPACE" add sh2perl 2>/dev/null || true
      git -C "$WORKSPACE" commit -q -m "perl-generator: gitlink bump" >> "$LOG" 2>&1 || true
      echo "[$(date +%FT%T)] committed improvement (fails=$fails)" >> "$LOG"
    fi
  elif [ "$fails" -gt $((trusted + 3)) ]; then
    # REGRESSION — stash pi's changes first
    git -C "$SUBM" stash -q 2>/dev/null || true
    fail_count=$((fail_count+1))
    echo "[$(date +%FT%T)] perl-generator: gate FAILED ($fail_count/3, fails=$fails trusted=$trusted) — invoking pi" >> "$LOG"
    if [ "$fail_count" -ge 3 ]; then
      echo "[$(date +%FT%T)] perl-generator: TRAPPED — escalating to core request and sleeping" >> "$LOG"
      bash "$WORKSPACE/setup_backends.sh" --worker-trapped perl-generator backend >> "$LOG" 2>&1 || true
      fail_count=0
      sleep 300
      continue
    fi
    {
      printf 'The Perl GENERATOR (the AST->Perl backend) has %s corpus failures (trusted baseline %s).\n' "$fails" "$trusted"
      printf 'Gate: ./fail — otranspilerl-cli file.sh -> Generator -> Perl text -> run vs bash, BYTE-FOR-BYTE stdout + EXIT CODE + side effects (the strict gate).\n\n'
      printf 'The failure list (first 60):\n'
      grep '  FAIL:' "$WORKSPACE/.perlgen-gate.out" | head -60
      printf '\nScope (DO NOT TOUCH the shared core): you may edit sh2perl/src/generator/ and harness/.\n'
      printf 'Shared core (the estree worker owns it): sh2perl/src/shir.rs, sh2perl/src/ir.rs, sh2perl/src/estree.rs, sh2perl/src/parser/.\n'
      printf '\nRECIPE:\n'
      printf '  1. Rebuild otranspilerl-cli (cd sh2perl && cd otranspilerl && cargo build --bin otranspilerl-cli) and reproduce a failing example.\n'
      printf '  2. Fix the GENERATOR codegen in src/generator/ so the emitted Perl matches bash byte-for-byte + exit code.\n'
      printf '  3. Common classes: exit-code propagation ($main_exit_code/$CHILD_ERROR), trailing whitespace/final newline, CRLF echo.\n'
      printf '  4. Land the smallest green: fix 1-3 files, re-run ./fail, verify the count drops.\n'
      printf 'If a SHARED-CORE change is required (parser fix, IR node), APPEND a structured request to core-requests/perl-generator-<timestamp>.md per core-requests/README.md and exit 0. Do NOT touch the core.\n'
    } > /tmp/pi-fix-prompt-$$
    bash "$WORKSPACE/setup_backends.sh" --wait >> "$LOG" 2>&1 || true
    pi --mode json --provider opencode-go --model deepseek-v4-flash \
       --thinking xhigh < /tmp/pi-fix-prompt-$$ >> "$LOG" 2>&1 || true
    rm -f /tmp/pi-fix-prompt-$$
  else
    # flat (fails in (trusted, trusted+3]): no measurable change, but
    # fails > 0 means there IS work — invoke pi on the failures without
    # committing or stashing.
    fail_count=0
    echo "[$(date +%FT%T)] perl-generator: flat (fails=$fails trusted=$trusted) — pi on the failures" >> "$LOG"
    {
      printf 'The Perl GENERATOR has %s corpus failures (trusted baseline %s) and your last edits did not improve the count. The failure list (first 60):\n' "$fails" "$trusted"
      grep '  FAIL:' "$WORKSPACE/.perlgen-gate.out" | head -60
      printf '\nScope (DO NOT TOUCH the shared core): edit sh2perl/src/generator/ and harness/ (workspace). Shared core (estree worker owns): src/shir.rs, src/ir.rs, src/estree.rs, src/parser/.\n'
      printf 'RECIPE: reproduce a failing example, fix the GENERATOR codegen so the Perl matches bash byte-for-byte + exit code, land 1-3 files, re-run ./fail, confirm the count drops below $trusted. Core change needed? APPEND a core-request and exit 0.\n'
    } > /tmp/pi-fix-prompt-$$
    bash "$WORKSPACE/setup_backends.sh" --wait >> "$LOG" 2>&1 || true
    pi --mode json --provider opencode-go --model deepseek-v4-flash \
       --thinking xhigh < /tmp/pi-fix-prompt-$$ >> "$LOG" 2>&1 || true
    rm -f /tmp/pi-fix-prompt-$$
  fi
  sleep 120
done
