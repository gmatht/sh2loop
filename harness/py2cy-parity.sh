#!/usr/bin/env bash
# py2cy.js parity oracle — mirrors frontends/py-sh-go/coverage/py2cy-parity.sh
# but drives harness/py2cy.js (Rust-analysis facts) instead of the Go binary.
# Annotate -> cython --embed -> cc -> run, compare stdout to CPython; the
# annotated file must also run unchanged under python3 (pure-Python mode).
#
# Usage: harness/py2cy-parity.sh ['glob']   (default testdata t0*+t1* slice)
# Env: PY2CY_JS=node harness/py2cy.js override; PY_SH_GO / OTRANSPILERL_CLI
#      binaries (defaults: repo builds).
set -uo pipefail
cd "$(dirname "$0")/.."
HERE="$PWD"
JS="${PY2CY_JS:-node $HERE/harness/py2cy.js}"
export PY_SH_GO="${PY_SH_GO:-$HERE/sh2perl/frontends/py-sh-go/py-sh-go}"
export OTRANSPILERL_CLI="${OTRANSPILERL_CLI:-$HERE/otranspilerl/target/debug/otranspilerl-cli}"
TD="$HERE/sh2perl/frontends/py-sh-go/testdata"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

ok=0
fail=0
failed=()
for f in ${1:-$TD/t0*.py $TD/t1*.py}; do
  bn="$(basename "$f")"
  if ! $JS "$f" > "$tmp/$bn.py" 2>"$tmp/$bn.err"; then
    echo "FAIL $bn (annotate)"; fail=$((fail+1)); failed+=("$bn"); continue
  fi
  if ! cython --embed -3 "$tmp/$bn.py" -o "$tmp/$bn.c" 2>"$tmp/$bn.cy"; then
    echo "FAIL $bn (cython)"; fail=$((fail+1)); failed+=("$bn"); continue
  fi
  if ! cc -O2 -o "$tmp/$bn" "$tmp/$bn.c" \
      $(python3-config --includes) $(python3-config --ldflags --embed) 2>/dev/null; then
    echo "FAIL $bn (cc)"; fail=$((fail+1)); failed+=("$bn"); continue
  fi
  stdin=/dev/null
  if [ -f "$TD/$bn.stdin" ]; then stdin="$TD/$bn.stdin"; fi
  got="$(PYTHONUNBUFFERED=1 timeout 20 "$tmp/$bn" <"$stdin" 2>/dev/null)"
  want="$(PYTHONUNBUFFERED=1 timeout 20 python3 "$f" <"$stdin" 2>/dev/null)"
  pygot="$(PYTHONUNBUFFERED=1 timeout 20 python3 "$tmp/$bn.py" <"$stdin" 2>/dev/null)"
  if [ "$pygot" != "$want" ]; then
    echo "FAIL $bn (not runnable CPython)"; fail=$((fail+1)); failed+=("$bn"); continue
  fi
  if [ "$got" = "$want" ]; then
    ok=$((ok+1))
  else
    echo "FAIL $bn (stdout mismatch)"; fail=$((fail+1)); failed+=("$bn")
  fi
done
echo "py2cy.js parity: $ok pass, $fail fail"
for x in "${failed[@]:-}"; do [ -n "$x" ] && echo "  $x"; done
[ "$fail" -eq 0 ]
