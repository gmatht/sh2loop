#!/usr/bin/env bash
# test_core_rollback.sh — regression tests for the Core worker's rollback and
# invariant semantics (PLAN §11 marketplace, core-known-good ref).
#
# The bugs these pin:
#   1. a missing/failing compiler was counted as one A1 "violation" per
#      example (555 fake violations), so a broken measurement was
#      indistinguishable from a real red gate;
#   2. "rollback" used to stash/revert OTHER workers' shared-core WIP in the
#      MAIN checkout, and (twice) rewound main backwards — deleting 374
#      commits of real work and leaving the tree unbuildable;
#   3. an offer was marked accepted BEFORE the A1/ESTree gate ran, so a
#      later red gate left an accepted-but-broken bundle in done/.
#
# Every case builds a throwaway repo, so nothing here touches the fleet.
# The functions are EXTRACTED from run_core_worker.sh (brace-balanced), so the
# tests cannot drift from the shipped implementation.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKER="$ROOT/run_core_worker.sh"
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ if [ "$2" = "$3" ]; then ok "$1 [$2]"; else bad "$1 (got '$2', want '$3')"; fi; }

# ── extract one shell function body, brace-balanced ──
# Prints the function (its `name() {` header and matching `}`) from $1.
extract_fn() { # file fn
  awk -v fn="$2" '
    !inside && $0 ~ ("^[[:space:]]*" fn "\\(\\)[[:space:]]*\\{") { inside=1; depth=0 }
    inside {
      print
      line=$0
      opens=gsub(/\{/, "{", line); line=$0
      closes=gsub(/\}/, "}", line)
      depth += opens - closes
      if (depth <= 0 && NR > 1 && $0 ~ /^[[:space:]]*}/) exit
    }
  ' "$1"
}

WORKER_A1_BODY=$(extract_fn "$WORKER" a1_gate)
WORKER_RESTORE_BODY=$(extract_fn "$WORKER" restore_known_good)
if ! printf '%s' "$WORKER_A1_BODY" | grep -q 'echo "\$v \$okc \$badc"'; then
  echo "FATAL: could not extract a1_gate from $WORKER (extraction drifted)" >&2; exit 1
fi
if ! printf '%s' "$WORKER_RESTORE_BODY" | grep -q 'reset -q --hard'; then
  echo "FATAL: could not extract restore_known_good from $WORKER" >&2; exit 1
fi

# ── case 1-3: a1_gate accounting ──
A1_V=; A1_OK=; A1_BAD=
run_a1() { # SUB FAKEBIN -> "<violations> <probed> <failed>"
  local sub="$1" bin="$2" wd="$3" out
  # The extracted body only DEFINES the function; it must be called for it to
  # run (and its `echo` to reach us).
  out=$(SUB="$sub" DEBASHC="$bin" ROOT="$wd" LOG="$wd/log" \
        timeout 60 bash -c "$WORKER_A1_BODY"$'\n''a1_gate' 2>/dev/null)
  A1_V=$(printf '%s'  "$out" | awk '{print $1}')
  A1_OK=$(printf '%s' "$out" | awk '{print $2}')
  A1_BAD=$(printf '%s' "$out" | awk '{print $3}')
}

# A fake compiler emitting a fixed A1 document (or nothing).
write_fake() { # bin json
  cat > "$1" <<EOS
#!/usr/bin/env bash
case "\$1" in
  --shir) printf '%s' '$2' ;;
esac
EOS
  chmod +x "$1"
}

run_restore() { # SUB -> runs the worker's restore_known_good in that worktree
  ( cd "$1" && SUB="$1" LOG="$2" REPORTS="$3" \
    timeout 60 bash -c "$WORKER_RESTORE_BODY"$'\n''restore_known_good' ) >/dev/null 2>&1
}

echo "== case 1: a compiler that emits nothing is a PROBE failure, not N violations =="
WD=$(mktemp -d); mkdir -p "$WD/core/examples"
: > "$WD/core/examples/a.sh"; : > "$WD/core/examples/b.sh"
ln -s "$ROOT/harness" "$WD/harness"
write_fake "$WD/fake" ""
run_a1 "$WD/core" "$WD/fake" "$WD"
check "no violations counted"   "$A1_V"   "0"
check "nothing counted as probed" "$A1_OK" "0"
check "both examples marked probe-failed" "$A1_BAD" "2"
rm -rf "$WD"

echo "== case 2: a real exec-of-builtin survivor IS counted =="
WD=$(mktemp -d); mkdir -p "$WD/core/examples"
: > "$WD/core/examples/a.sh"; : > "$WD/core/examples/b.sh"
ln -s "$ROOT/harness" "$WD/harness"
write_fake "$WD/fake" '{"stmts":[{"type":"Call","func":"exec","args":[{"type":"Str","value":"echo"}]}]}'
run_a1 "$WD/core" "$WD/fake" "$WD"
check "violation per example"  "$A1_V"   "2"
check "valid A1 counted probed" "$A1_OK" "2"
check "no probe failures"      "$A1_BAD" "0"
rm -rf "$WD"

echo "== case 3: a clean corpus reports 0/2/0 =="
WD=$(mktemp -d); mkdir -p "$WD/core/examples"
: > "$WD/core/examples/a.sh"; : > "$WD/core/examples/b.sh"
ln -s "$ROOT/harness" "$WD/harness"
write_fake "$WD/fake" '{"stmts":[]}'
run_a1 "$WD/core" "$WD/fake" "$WD"
check "zero violations" "$A1_V"   "0"
check "both probed"     "$A1_OK" "2"
check "zero probe failures" "$A1_BAD" "0"
rm -rf "$WD"

# ── cases 4-6: rollback against a REAL worktree ──
# Setup mirrors production: a main checkout plus a linked core worktree, with
# the anchor ref pointing at the last verified-green commit.
make_repo() { # -> $MAIN $SUBWORK
  WD=$(mktemp -d)
  MAIN="$WD/main"
  git init -q "$MAIN"
  git -C "$MAIN" config user.email t@t
  git -C "$MAIN" config user.name t
  echo "green" > "$MAIN/shared.txt"
  git -C "$MAIN" add -A; git -C "$MAIN" commit -qm "green state"
  GREEN=$(git -C "$MAIN" rev-parse HEAD)
  # the candidate the core worker made, then found red
  echo "candidate" > "$WD/candidate.txt"
  git -C "$MAIN" add -A; git -C "$MAIN" commit -qm "red candidate"
  BAD=$(git -C "$MAIN" rev-parse HEAD)
  git -C "$MAIN" worktree add -q "$WD/core" -b backend/core 2>/dev/null
  SUBWORK="$WD/core"
}

echo "== case 4: rollback moves the CORE worktree to known-good and never rewinds main =="
make_repo
# the worktree is at the RED candidate; the anchor says GREEN is the last green
git -C "$MAIN" update-ref refs/sh2loop/core-known-good "$GREEN"
# simulate a half-applied candidate in the worktree (uncommitted WIP)
echo "half-applied" > "$SUBWORK/shared.txt"
mkdir -p "$WD/reports"; : > "$WD/reports/core-worker.report"; : > "$WD/log"
run_restore "$SUBWORK" "$WD/log" "$WD/reports"
check "core worktree rolled back to green" "$(git -C "$SUBWORK" rev-parse HEAD)" "$GREEN"
check "worktree content restored"           "$(cat "$SUBWORK/shared.txt")" "green"
check "MAIN HEAD untouched (not rewound)"   "$(git -C "$MAIN" rev-parse HEAD)" "$BAD"
check "anchor still points at green"        "$(git -C "$MAIN" rev-parse refs/sh2loop/core-known-good)" "$GREEN"
rm -rf "$WD"

echo "== case 5: no anchor -> NO-KNOWN-GOOD reported, no anchor invented =="
make_repo
# deliberately DO NOT create the anchor ref
echo "wip" > "$SUBWORK/shared.txt"
mkdir -p "$WD/reports"; : > "$WD/reports/core-worker.report"; : > "$WD/log"
run_restore "$SUBWORK" "$WD/log" "$WD/reports"
check "reports NO-KNOWN-GOOD"  "$(grep -c 'NO-KNOWN-GOOD' "$WD/reports/core-worker.report")" "1"
check "no anchor was created"  "$(git -C "$MAIN" rev-parse -q --verify refs/sh2loop/core-known-good >/dev/null 2>&1 && echo yes || echo no)" "no"
# With no anchor there is nothing to roll back TO, so the worktree resets to
# its OWN head: the uncommitted "wip" edit is discarded (file matches the
# committed content again) and the red-candidate commit is NOT unwound.
check "uncommitted WIP discarded" "$(cat "$SUBWORK/shared.txt")" "green"
check "worktree left at its own HEAD" "$(git -C "$SUBWORK" rev-parse HEAD)" "$BAD"
rm -rf "$WD"

echo "== case 6: acceptance happens only after the green gate (staged, not accepted) =="
# The worker must NOT contain the pre-gate acceptance lines any more: an offer
# may only be moved to done/ inside the GREEN branch.
pre_gate=$(awk '/staged offer is accepted|awaiting invariants/{f=1} f&&/transforms\/done\//{print NR}' "$WORKER" | head -1)
green_branch=$(grep -n 'staged_offer" "$REQS/transforms/done/"' "$WORKER" | head -1)
if [ -n "$green_branch" ]; then
  ok "offer moves to done/ inside the GREEN branch (line ${green_branch%%:*})"
else
  bad "offer-to-done must live in the GREEN branch"
fi
if [ -n "$pre_gate" ] && [ -n "$green_branch" ] && [ "$pre_gate" -lt "${green_branch%%:*}" ]; then
  bad "a done/ move appears BEFORE the green gate (line $pre_gate)"
else
  ok "no offer is marked done before the gate is green"
fi

echo
echo "== case 7: lib tests are BASELINED, not required to be perfectly green =="
# The bug: the gate required `cargo test --lib` to exit 0. This tree has a set
# of known-red lib tests that predate any candidate, so the gate could NEVER go
# green, NEVER advance the known-good anchor, and rolled back + discarded every
# candidate forever (23 consecutive RED iterations, 0 progress). The fix counts
# failures and compares against a baseline, like the estree corpus.
if grep -q 'lib_fails=' "$WORKER"; then
  ok "the known-good record carries a lib_fails baseline"
else
  bad "the known-good record does not record lib_fails — the anchor cannot hold a lib baseline"
fi
if grep -q 'lib .*failures vs baseline' "$WORKER"; then
  ok "lib failures are compared against a baseline"
else
  bad "lib failures are not compared against a baseline"
fi
# A candidate must not be able to make the lib count WORSE and still pass.
if grep -q 'lib_fails" -le "\$kg_lib"' "$WORKER"; then
  ok "candidate passes only when lib_fails <= baseline (no regression)"
else
  bad "no lib_fails <= baseline guard found"
fi
# A HANG must be a hard failure, never silently adopted as a baseline: libtest
# prints its `test result:` line only when the suite finishes.
if grep -q 'no lib-test summary line' "$WORKER"; then
  ok "a hung/crashed lib suite is distinguished from a red one (no summary line = fail)"
else
  bad "a hung lib suite is not distinguished from a red one"
fi

echo "== case 8: every RED names a reason (no more empty 'gate RED ()') =="
# The old gate let a lib-test failure produce an EMPTY reason, so a spinning
# test and a genuine red suite both logged `gate RED ()` and the investigation
# had nothing to follow. A hang was the actual cause and it was invisible.
if grep -q 'gate conditions changed under the run' "$WORKER"; then
  ok "an unexplained RED is reported as such, never as an empty reason"
else
  bad "an unexplained RED can still be logged with an empty reason"
fi
for sig in 'A1 not clean' 'estree .*vs baseline' 'lib .*reason'; do
  if grep -q "$sig" "$WORKER"; then
    ok "RED reason covers: $sig"
  else
    bad "RED reason missing a source: $sig"
  fi
done

echo
echo "core rollback tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
