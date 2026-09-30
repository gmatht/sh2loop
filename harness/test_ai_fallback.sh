#!/usr/bin/env bash
# test_ai_fallback.sh — regression tests for harness/ai_fallback.pm, the
# Laguna daily-quota fallback shared by the A1/estree loops
# main_loop_estree.pl.
#
# THE BUG (2026-09-26). The module compared the model id by exact string
# equality against `poolside/laguna-s-2.1-free` (hyphen variant), but BOTH
# loops actually run the OpenRouter colon form
# `poolside/laguna-s-2.1:free` (main_loop_estree.pl:78)
# — confirmed in the live process table. So `ai_fallback_for` returned undef
# for the model in use, the switch never fired, and the worker sat in pir's own
# infinite 429 retry (observed climbing: attempt 5 at 480s ... attempt 10 at
# 15360s) while the module believed a fallback was configured and ready.
#
# The existing Python test (tests/test_model_rotation.py) exercises
# ai_invoke.py with the HYPHEN id, so it passed happily while the Perl path
# the loops actually use was broken. These cases test the Perl module directly
# with the model string production really uses.
#
# WHAT IS ASSERTED:
#   - the model the loops REALLY run (colon form) resolves to a fallback;
#   - both the colon and hyphen forms are the same model;
#   - the real OpenRouter quota error is detected;
#   - a non-Laguna model NEVER switches (a transient 429 keeps its normal
#     infinite retry — switching Space Bunny Alpha would suppress it);
#   - near-miss 429s (weekly limit, billing, plain rate limit) do not match;
#   - the switch is one-way, so the worker cannot oscillate;
#   - WORKER_FALLBACK_MODEL= (empty) disables the fallback;
#   - a fallback identical to the model is refused (never fall back to itself).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD="$ROOT/harness/ai_fallback.pm"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1 [$2]"; else bad "$1 (got '$2', want '$3')"; fi; }

# Run a snippet against a FRESHLY loaded module with the given env.
# Each case needs its own process: the module reads %ENV at load time.
#
# The snippet must RETURN its value, never print it: `perl -e` appends the
# truth value of the last statement to STDOUT, so a snippet ending in
# `print ...` emitted its result and then a stray "1", which made every case
# fail against a correct module. The wrapper prints the returned value itself
# and exits 0 so nothing is appended.
probe() { # <env assignments...> -- <perl expression>
  local envs=() code=""
  while [ $# -gt 0 ]; do
    if [ "$1" = "--" ]; then shift; code="$*"; break; fi
    envs+=("$1"); shift
  done
  env -i PATH="$PATH" HOME="$HOME" "${envs[@]}" perl -e '
    require "'"$MOD"'";
    my $r = eval { '"$code"' };
    if ($@) { print "ERROR: $@"; exit 0; }
    print defined $r ? $r : "UNDEF";
    exit 0;
  ' 2>/dev/null
}

# The id the loops actually run is the OpenRouter COLON form; the module must
# recognise it (and the hyphen variant) as Laguna.
FB='ollama-cloud/deepseek-v4.1-flash'

echo "== case 1: the model the loops actually run resolves to a fallback =="
got=$(probe -- 'ai_fallback::ai_fallback_for("poolside/laguna-s-2.1:free")')
check "colon form (what main_loop_*.pl run) has a fallback" "$got" "$FB"

echo "== case 2: colon and hyphen forms are the SAME model =="
a=$(probe -- 'ai_fallback::ai_fallback_for("poolside/laguna-s-2.1:free")')
b=$(probe -- 'ai_fallback::ai_fallback_for("poolside/laguna-s-2.1-free")')
if [ "$a" = "$b" ] && [ "$a" != "UNDEF" ]; then
  ok "both variant separators resolve identically ($a)"
else
  bad "colon='$a' hyphen='$b' — the two forms disagree"
fi

echo "== case 3: the real OpenRouter quota error is detected =="
got=$(probe -- 'ai_fallback::quota_marker("HTTP 429: Rate limit exceeded: free-models-per-day. Add 10 credits") ? "MATCH" : "NOMATCH"')
check "free-models-per-day is detected" "$got" "MATCH"

echo "== case 3b: the CAPACITY error also triggers the fallback =="
# Laguna is single-provider, so a saturated provider leaves it with nothing
# to fail over to and it retries the same dead request forever. Observed
# 2026-09-28: 316 such errors and `attempt 19, retry in 300s` on the c worker.
got=$(probe -- 'ai_fallback::capacity_marker("The request limited providers for this model and they are currently at capacity. Add more providers or remove restrictions for automatic fallback. Providers considered: poolside.") ? "MATCH" : "NOMATCH"')
check "providers-at-capacity is detected" "$got" "MATCH"

echo "== case 3c: ordinary output does NOT look like capacity exhaustion =="
for t in "Build complete." "test result: ok. 498 passed" "provider timeout" "at capacity of the cache"; do
  r=$(probe -- "ai_fallback::capacity_marker('$t') ? 'MATCH' : 'NOMATCH'")
  if [ "$r" = "NOMATCH" ]; then
    ok "ordinary output not matched: $t"
  else
    bad "ordinary output wrongly matched: $t"
  fi
done

echo "== case 4: near-miss 429s do NOT match (they keep their normal retry) =="
for t in "HTTP 429: Rate limit exceeded" \
         "HTTP 429: weekly usage limit reached" \
         "HTTP 429: insufficient credits" \
         "HTTP 503: upstream timeout"; do
  r=$(probe -- "ai_fallback::quota_marker('$t') ? 'MATCH' : 'NOMATCH'")
  if [ "$r" = "NOMATCH" ]; then
    ok "near-miss not matched: $t"
  else
    bad "near-miss wrongly matched (would switch a model it should not): $t"
  fi
done

echo "== case 5: a non-Laguna model NEVER switches =="
# Switching Space Bunny Alpha on a transient 429 would suppress its rotating
# retry and leave the worker with no working model at all.
for m in "stealth/space-bunny-alpha" "some/other-model:free" "anthropic/claude-sonnet-4"; do
  r=$(probe -- "ai_fallback::ai_fallback_for('$m')")
  if [ "$r" = "UNDEF" ]; then
    ok "no fallback for non-Laguna model: $m"
  else
    bad "non-Laguna model $m would switch to $r — it must keep its normal retry"
  fi
done

echo "== case 6: the switch is one-way (no oscillation) =="
got=$(probe -- '
  my $sw = ai_fallback::QuotaSwitch->new("poolside/laguna-s-2.1:free");
  my $first = $sw->switch_to();
  my $second = $sw->switch_to();
  (($first eq $second && $sw->switched) ? "ONCE" : "OSCILLATES")
')
check "a second switch is a no-op" "$got" "ONCE"

echo "== case 7: WORKER_FALLBACK_MODEL= (empty) disables the fallback =="
got=$(probe "WORKER_FALLBACK_MODEL=" -- 'ai_fallback::ai_fallback_for("poolside/laguna-s-2.1:free")')
check "empty fallback disables the switch" "$got" "UNDEF"

echo "== case 8: a fallback identical to the model is refused =="
got=$(probe "WORKER_FALLBACK_MODEL=poolside/laguna-s-2.1:free" -- \
  'ai_fallback::ai_fallback_for("poolside/laguna-s-2.1:free")')
check "never falls back to itself" "$got" "UNDEF"

echo "== case 9: the module's Laguna id is still a LAGUNA id =="
# This case originally asserted the module's $LAGUNA_MODEL equalled the
# loops' *primary* model, on the assumption that the loops run Laguna. That
# conflated two different things and became wrong the moment the fleet moved
# to Space Bunny Alpha (operator, 2026-09-30).
#
#   $LAGUNA_MODEL answers "which model am I allowed to FALL BACK FROM?".
#   The loops' default answers "which model do I RUN?".
#
# Those are independent by design: pinning the fleet to Alpha is exactly the
# case where the fallback guard must still recognise Laguna, so a worker
# re-pinned to Laguna for the A/B gets its quota escape route back without
# any edit here. So the invariant worth asserting is that the guard's id is a
# Laguna id and the RUNNING id is not — i.e. the fleet is not on the model
# the guard would switch away from.
loop_model=$(grep -oE "WORKER_MODEL\} // '[^']+'" "$ROOT/main_loop_estree.pl" | head -1 | sed "s/.*\/\/ '//; s/'$//")
# Read the module's Laguna id with perl. Note the `$ai_fallback::` sigil is
# referenced inside SINGLE quotes so bash expands nothing: inside double quotes
# bash substitutes $ai_fallback to the empty string and the comparison silently
# failed for the wrong reason.
mod_model=$(env -i PATH="$PATH" HOME="$HOME" perl -e '
  require "'"$MOD"'";
  my $r = $ai_fallback::LAGUNA_MODEL;
  print defined $r ? $r : "UNDEF";
  exit 0;
' 2>/dev/null)
case "$mod_model" in
  *[Ll][Aa][Gg][Uu][Nn][Aa]*) ok "the fallback guard still targets a Laguna id ($mod_model)" ;;
  *) bad "the guard's id '$mod_model' is not a Laguna id — a re-pinned worker would lose its quota escape route" ;;
esac
if [ "$loop_model" = "$mod_model" ]; then
  bad "the loops RUN '$loop_model', the same id the guard switches away from — the fallback could never fire"
else
  ok "the running model ('$loop_model') is not the fallback guard's target ('$mod_model')"
fi

echo "== case 10: BOTH id forms of the running model do NOT fall back =="
# The loops now run the provider-qualified Alpha id; case 5 only covered the
# bare form. The guard must refuse both, or a re-pin would be half-guarded.
for m in "commandcode/stealth/space-bunny-alpha" "stealth/space-bunny-alpha"; do
  r=$(probe -- "ai_fallback::ai_fallback_for('$m')")
  if [ "$r" = "UNDEF" ]; then
    ok "no fallback for the running model: $m"
  else
    bad "the running model $m would switch to $r — it must keep its normal retry"
  fi
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
