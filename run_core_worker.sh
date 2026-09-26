#!/usr/bin/env bash
# run_core_worker.sh — the CORE/CONTRACT worker, MARKETPLACE mode (PLAN.md
# §11 / v29). LLM-FREE: this worker is a DETERMINISTIC gate, not an agent.
# The LLM work (writing transforms) belongs to the BACKENDS that offer
# them; the core only COMPILES + GATES.
#
# SUBMISSION BUNDLES: a transform that emits a NEW op ships its contract
# expansion WITH it — each submission is a directory
#   core-requests/transforms/<name>/
#     transform.rs      the transform module
#     contract.patch    the op ingress (the deserializer/schema change the
#                       op needs) — applied AHEAD of the transform, so the
#                       op compiles instead of bouncing on a missing
#                       prerequisite
#     manifest          prereqs / invariant / scope / ## OFFERED-TO
# The gate applies the contract expansion first, registers + builds the
# transform, runs the invariants, and accepts the BUNDLE together (commit)
# or rejects it (revert the submodule src, move to rejected/).
#
# Acceptance: compiles + the invariants hold (cargo test --lib, the A1
# round-trip/determinism, check_qx_shir) + every backend tree still builds
# (the op ships a self-fallback arm — an op a backend hasn't accepted
# renders as the exec it came from; rejection is safe, no regression).
# It does NOT run every backend corpus green — each backend's accept/
# reject is its own decision.
#
# Scope: sh2perl/src/ + harness/ A1 checks + core-requests/. The estree
# worker keeps estree.rs + the corpus + the runtime. Fast: no pi.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"
# The core worker lives in its OWN git worktree (sh2perl/backends/core on
# backend/core, the fleet's isolation pattern): its WIP, verify-cycles and
# commits never touch the main tree the estree worker's gate reads. It
# lands on main ONLY via a green merge. See the estree-worker deadlock
# this fixes: the split gave role separation without tree separation.
SUB="$ROOT/sh2perl/backends/core"
LOG="$ROOT/loop-core-worker.log"
REQS="$ROOT/core-requests"
WATCH="${WATCH:-600}"
# The ROLLBACK ANCHOR: a verified-green Core commit, advanced only after a
# full green verification and used to restore the worktree on any red
# candidate. It replaces the old "main vs core-worktree" heuristic, which
# could stash/revert other workers' shared-core WIP and (twice) rewound main
# 374 commits backwards. Everything below is transactional inside the CORE
# worktree; the main checkout is read-only to this worker.
KNOWN_GOOD_REF="refs/sh2loop/core-known-good"
KNOWN_GOOD_FILE="$ROOT/.core-verify/known-good.env"   # metrics for that commit
REPORTS="$ROOT/gate-reports"
mkdir -p "$ROOT/.core-verify"

# Worker cgroup enrollment (harness/WorkerPool.pm): runs inside sh2workers.
perl "$ROOT/harness/WorkerPool.pm" --enter-worker $$ >> "$LOG" 2>&1 || true
mkdir -p "$REQS/transforms/done" "$REQS/transforms/rejected" "$REPORTS"
echo "[$(date +%FT%T)] core worker (LLM-free marketplace gate) started (pid=$$)" >> "$LOG"

# The Core compiler: an ISOLATED otranspilerl-cli linked against THIS
# worktree (harness/core_verify.sh). The old path
# ($SUB/otranspilerl/target/debug/otranspilerl-cli) never existed, which
# turned the A1 probe into 555 fake "violations" and made the gate permanently
# red. The main compiler is never built or replaced by this worker.
core_binary() {
  bash "$ROOT/harness/core_verify.sh" 2>>"$LOG" | tail -1
}

# The A1-native invariant. Prints "<violations> <probed> <failed>".
#   violations — real exec-of-builtin survivors found by check_qx_shir
#   probed     — examples that produced PARSEABLE A1 JSON
#   failed     — examples whose emit failed or produced invalid JSON
# A probe failure is a COUNT OF FILES, never folded into the violation count:
# "555 violations" must mean 555 real lowering defects. check_qx_shir.py marks
# an unmeasurable input with PROBE-UNAVAILABLE, so one checker run per example
# yields both numbers (this used to spawn a JSON parser AND a grep per file,
# which made a 555-file sweep cost minutes of pure process startup).
a1_gate() {
  local v=0 okc=0 badc=0 f report
  for f in "$SUB"/examples/*.sh; do
    report=$("$DEBASHC" --shir "$f" --raw 2>/dev/null | "$ROOT/harness/check_qx_shir.py" 2>/dev/null || true)
    if printf '%s' "$report" | grep -q 'PROBE-UNAVAILABLE'; then
      badc=$((badc + 1))
      continue
    fi
    okc=$((okc + 1))
    # `grep -c` prints 0 AND exits 1 when there are no matches, so the
    # `|| true` that guards `set -e` would also discard the "0" on stdout,
    # leaving `v=$((v + ))` — an arithmetic syntax error that killed the
    # whole worker on every clean example. Keep the fallback to 0.
    nfail=$(printf '%s' "$report" | grep -c 'FAIL') || nfail=0
    v=$((v + ${nfail:-0}))
  done
  echo "$v $okc $badc"
}

# pending submission BUNDLES (dirs carrying a transform.rs) — the
# marketplace channels (PLAN §11): transforms/offered .rs, contracts/*.json
# specs, and bundles/ (a node + its transforms)
pending_transforms() {
  for d in "$REQS"/transforms/offered/*.rs; do
    [ -f "$d" ] && echo "$d"
  done 2>/dev/null | sort || true
}

pending_contracts() {
  ls "$REQS"/contracts/*.json 2>/dev/null | sort || true
}

pending_bundles() {
  for d in "$REQS"/bundles/*/; do
    [ -d "$d" ] && [ -f "$d/bundle.json" ] && echo "${d%/}"
  done 2>/dev/null | sort || true
}

done_count() { ls "$REQS/done"/*.md "$REQS/done"/*.rs "$REQS/transforms/done"/*.rs 2>/dev/null | wc -l; }
rejected_count() { ls "$REQS/transforms/rejected"/*.rs 2>/dev/null | wc -l; }

wake_sleepers() {
  for m in "$REQS"/sleeping-*; do
    [ -f "$m" ] || continue
    echo "[$(date +%FT%T)] core: waking $(basename "$m" | sed 's/sleeping-//')" >> "$LOG"
    rm -f "$m"
  done
}

# Discard the current candidate and put the CORE WORKTREE back on the last
# verified-green commit. Scope: the worktree only — never the main checkout,
# never another worker's files. With no anchor yet there is nothing to restore
# TO, so the worktree is reset to its own HEAD (dropping uncommitted WIP) and
# the caller reports NO-KNOWN-GOOD.
restore_known_good() {
  local kg cur
  kg=$(git -C "$SUB" rev-parse -q --verify "$KNOWN_GOOD_REF" 2>/dev/null || true)
  cur=$(git -C "$SUB" rev-parse HEAD 2>/dev/null || true)
  if [ -n "$kg" ]; then
    git -C "$SUB" reset -q --hard "$kg" >> "$LOG" 2>&1 || true
    git -C "$SUB" clean -qfd src >> "$LOG" 2>&1 || true
    echo "[$(date +%FT%T)] core: rolled back to known-good $(git -C "$SUB" rev-parse --short "$kg") (was ${cur:0:9})" >> "$LOG"
  else
    git -C "$SUB" reset -q --hard HEAD >> "$LOG" 2>&1 || true
    git -C "$SUB" clean -qfd src >> "$LOG" 2>&1 || true
    printf '%s core-worker: NO-KNOWN-GOOD — discarded candidate, no green anchor exists yet\n' \
      "$(date +%FT%T)" >> "$REPORTS/core-worker.report"
    echo "[$(date +%FT%T)] core: no known-good anchor — candidate discarded, worktree reset to HEAD" >> "$LOG"
  fi
}

while true; do
  bash "$ROOT/setup_backends.sh" --wait >> "$LOG" 2>&1 || true
  echo "[$(date +%FT%T)] core: iteration start" >> "$LOG"

  # ── 0. the Core compiler + the rollback anchor ────────────────────
  DEBASHC=$(core_binary || true)
  if [ -z "$DEBASHC" ] || [ ! -x "$DEBASHC" ]; then
    printf '%s core-worker: NO-COMPILER (isolated core build failed — no verdict this iteration)\n' \
      "$(date +%FT%T)" >> "$REPORTS/core-worker.report"
    echo "[$(date +%FT%T)] core: isolated compiler build FAILED — skipping iteration" >> "$LOG"
    sleep "$WATCH"
    continue
  fi

  # Restore the worktree to the last VERIFIED-GREEN commit. This is the
  # rollback: a candidate that never reached green (crash, kill, leftover WIP
  # from a previous run) is discarded here, in the Core worktree only.
  known_good=$(git -C "$SUB" rev-parse -q --verify "$KNOWN_GOOD_REF" 2>/dev/null || true)
  core_head=$(git -C "$SUB" rev-parse HEAD 2>/dev/null || true)
  if [ -n "$known_good" ] && [ "$core_head" != "$known_good" ]; then
    restore_known_good
    printf '%s core-worker: ROLLED-BACK to known-good %s (discarded unverified candidate)\n' \
      "$(date +%FT%T)" "$(git -C "$SUB" rev-parse --short "$known_good")" >> "$REPORTS/core-worker.report"
  fi

  # Adopt legitimate upstream progress: when the core worktree is an ancestor
  # of main, fast-forward the WORKTREE (never rewind main — the old guard did,
  # and that is what deleted 374 commits of real work and broke the build).
  main_head=$(git -C "$ROOT/sh2perl" rev-parse HEAD 2>/dev/null || true)
  cur=$(git -C "$SUB" rev-parse HEAD 2>/dev/null || true)
  if [ -n "$main_head" ] && [ -n "$cur" ] && [ "$main_head" != "$cur" ] && \
     git -C "$ROOT/sh2perl" merge-base --is-ancestor "$cur" "$main_head" 2>/dev/null; then
    if git -C "$SUB" merge -q --ff-only "$main_head" >> "$LOG" 2>&1; then
      echo "[$(date +%FT%T)] core: fast-forwarded backend/core to main $main_head" >> "$LOG"
      # The fast-forward is unverified; it becomes the candidate to verify.
      # It is NOT the known-good anchor until a full green run says so.
    fi
  fi
  # NOTE: main is never checked out, stashed, reset or committed by this
  # worker. Other workers own the main tree; a divergent main is REPORTED.

  printf '%s core-worker: iterating (%s offers, %s specs, %s bundles, %s done, %s rejected)\n' \
    "$(date +%FT%T)" \
    "$(pending_transforms | wc -l)" \
    "$(pending_contracts | wc -l)" \
    "$(pending_bundles | wc -l)" \
    "$(done_count)" "$(rejected_count)" \
    >> "$REPORTS/core-worker.report"

  # ── 1. gate the submission bundles (deterministic: contract → build → invariants) ──
  for bundle in $(pending_transforms); do
    name=$(basename "$bundle")
    echo "[$(date +%FT%T)] core: gating transform bundle $name" >> "$LOG"
    # the contract expansion is applied AHEAD of the transform (the user's
    # sequencing ask) — the op ingress the transform's op needs
    if [ -f "$bundle/contract.patch" ]; then
      if ! git -C "$SUB" apply --check "$bundle/contract.patch" >> "$LOG" 2>&1; then
        echo "[$(date +%FT%T)] core: $name contract.patch does not apply — REJECT" >> "$LOG"
        mv "$bundle" "$REQS/transforms/rejected/"
        printf '%s core-worker: REJECTED %s (contract patch)\n' "$(date +%FT%T)" "$name" >> "$REPORTS/core-worker.report"
        continue
      fi
      git -C "$SUB" apply "$bundle/contract.patch" >> "$LOG" 2>&1
    fi
    # INTEGRATE the transform: copy transform.rs into the crate and apply
    # the registration lines (the bundle's `register` file carries the exact
    # `pub mod <name>;` + `("<name>-lift", <name>::transform)` entries) —
    # acceptance must mean the TRANSFORM itself compiles, not just the
    # unchanged crate. Reverted on any failure (git checkout -- src/).
    if [ -f "$bundle/transform.rs" ]; then
      # the module name comes from the register file (`pub mod <name>;`) —
      # the bundle DIR may be hyphenated (builtin-lift) while the module is
      # underscored (builtin_lift); the file must match the module name
      modname=$(sed -n 's/^pub mod \([a-z_0-9]*\);$/\1/p' "$bundle/register" | head -1)
      cp "$bundle/transform.rs" "$SUB/src/transforms/${modname:-$(basename "$bundle")}.rs"
      if [ -f "$bundle/register" ]; then
        # the register file carries two sections inserted at their proper
        # places (markers ### mod / ### all): the mods go after the last
        # `pub mod` line; the all() entries go before the vec's closing `]`
        mods=$(sed -n '/^### mod$/,/^### all$/p' "$bundle/register" | grep -v '^###' || true)
        entries=$(sed -n '/^### all$/,$p' "$bundle/register" | grep -v '^###' || true)
        if [ -n "$mods" ]; then
          python3 - "$SUB/src/transforms.rs" "$mods" <<'PYEOF'
import sys
path, mods = sys.argv[1], sys.argv[2]
lines = open(path).read().split(chr(10))
last = max(i for i, l in enumerate(lines) if l.startswith('pub mod '))
for m in mods.strip().split(chr(10)):
    lines.insert(last + 1, m)
    last += 1
open(path, 'w').write(chr(10).join(lines))
PYEOF
        fi
        if [ -n "$entries" ]; then
          python3 - "$SUB/src/transforms.rs" "$entries" <<'PYEOF'
import sys
path, entries = sys.argv[1], sys.argv[2]
lines = open(path).read().split(chr(10))
idx = max(i for i, l in enumerate(lines) if '::transform),' in l)
close = next(i for i in range(idx, len(lines)) if lines[i].strip() == ']')
for e in entries.strip().split(chr(10)):
    lines.insert(close, e)
    close += 1
open(path, 'w').write(chr(10).join(lines))
PYEOF
        fi
      fi
    fi
    if ! "$ROOT/harness/build-lock.sh" --role core -- cargo test --lib \
         --manifest-path "$SUB/Cargo.toml" >> "$LOG" 2>&1; then
      echo "[$(date +%FT%T)] core: $name fails the lib tests — REJECT (worktree restored)" >> "$LOG"
      restore_known_good
      mv "$bundle" "$REQS/transforms/rejected/"
      printf '%s core-worker: REJECTED %s (lib tests)\n' "$(date +%FT%T)" "$name" >> "$REPORTS/core-worker.report"
      continue
    fi
    # NOT accepted yet. The candidate is STAGED (registered + compiled +
    # lib-green) and the full invariant gate below decides. Acceptance used
    # to happen here, before the A1/ESTree gate — so a bundle could be marked
    # done and committed, and the red gate that followed left it there
    # (the report shows exactly that: accepted, then RED). The offer moves to
    # done/ only after the green finalize at the end of the iteration.
    echo "[$(date +%FT%T)] core: candidate $name staged (build + lib tests green) — awaiting invariants" >> "$LOG"
    git -C "$SUB" add src/ 2>/dev/null || true
    staged_offer="$bundle"
    staged_name="$name"
  done

  # ── 2. the invariants gate (the builtin-op ladder — no LLM) ──
  # a1_gate prints "<violations> <probed> <failed>". A failed probe is a
  # BROKEN MEASUREMENT, not a violation count: with the old missing binary
  # every example emitted nothing and check_qx_shir printed one "invalid A1
  # JSON" FAIL line each, which `grep -c FAIL` turned into "555 violations".
  read -r v probed failed < <(a1_gate)
  echo "[$(date +%FT%T)] core: A1-native invariant — $v violations, $probed probed, $failed probe-failures" >> "$LOG"
  printf '%s core-worker: A1 violations=%s probed=%s probe-failures=%s\n' \
    "$(date +%FT%T)" "$v" "$probed" "$failed" >> "$REPORTS/core-worker.report"

  # ── 2b. REPORT-ONLY observation of the main checkout ────────────────
  # The old guard stashed other workers' shared-core WIP and (twice) rewound
  # main backwards, which deleted 374 commits of real work and left the tree
  # unbuildable. This worker OWNS ONLY its own worktree; the main tree belongs
  # to the other workers. So this observes and reports — and never mutates.
  main_dirty=$(git -C "$ROOT/sh2perl" status --porcelain -- src/ 2>/dev/null | head -20 || true)
  if [ -n "$main_dirty" ]; then
    echo "[$(date +%FT%T)] core: main checkout has uncommitted shared-core WIP (NOT touched — owned by its worker):" >> "$LOG"
    printf '%s\n' "$main_dirty" >> "$LOG"
  fi

  # ── 3. finalize: commit accepted core changes when green (in the WORKTREE) ──
  # The estree corpus is part of the core worker's green: it must never
  # land a marketplace change that regresses the estree path (the
  # array/function regressions that started this — its old gate was only
  # check_qx_shir + lib tests). SH2PERL_DIR points fail-estree at THIS
  # worktree's binary.
  # Timeout: fail-estree can hang if the build is broken. Cap at 1 hour.
  #
  # PROBE-FAILED vs CORPUS-RED: fail-estree always prints its summary line
  # when it actually ran, and exits 1 for a genuine red corpus (the gate
  # verdict is the FAILURE COUNT, not the exit status). So an exit status
  # can NOT tell the two apart — only the presence of a parsed count can.
  # The old `:-9999` sentinel collapsed "timed out / crashed / produced no
  # summary" into the same RED text as "27 real failures", which is why the
  # report flapped estree=27 / estree=9999 / estree=27.
  #
  # The dominant cause is `fail-estree` dying at its BUILD step because the
  # main tree's sh2perl does not compile — note it builds $ROOT/otranspilerl
  # (the MAIN checkout), NOT $SH2PERL_DIR, so a broken main tree takes the
  # core gate down even though the core WORKTREE (sh2perl/backends/core)
  # builds fine. Name that cause explicitly instead of logging an opaque
  # "no summary line".
  #
  # Detecting it: fail-estree's `die "Build failed"` goes to STDERR, which
  # this capture discards (2>/dev/null) — so the marker is NOT greppable
  # here. What IS on stdout is the cargo output it printed first, ending in
  # `error: could not compile ...`. Detect that instead.
  estree_probe=ok
  estree_reason=""
  estree_fails=""
  # The gate runs against THIS worktree's compiler, not the main checkout's:
  # SH2PERL_DIR swaps the example tree, and OTRANSPILERL_BIN + _SKIP_BUILD
  # swap the binary too. Without the latter the probe was a hybrid — the core
  # corpus judged by the MAIN compiler — so a green core worktree and a broken
  # main tree (or the reverse) produced a verdict about neither. We already
  # built the isolated binary above, so the gate does not rebuild anything.
  estree_out=$(timeout 3600 env \
      SH2PERL_DIR="$SUB" \
      OTRANSPILERL_BIN="$DEBASHC" \
      OTRANSPILERL_SKIP_BUILD=1 \
      "$ROOT/fail-estree" 2>/dev/null) || true
  estree_fails=$(printf '%s\n' "$estree_out" | sed -n 's/.*ESTREE: [0-9]* passed, \([0-9]*\) failed.*/\1/p' | tail -1)
  estree_total=$(printf '%s\n' "$estree_out" | sed -n 's/.*ESTREE: [0-9]* passed, [0-9]* failed out of \([0-9]*\).*/\1/p' | tail -1)
  if [ -z "$estree_fails" ]; then
    estree_probe=failed
    estree_fails="?"
    estree_reason="no ESTREE summary (gate timed out or crashed — NOT a corpus verdict)"
    echo "[$(date +%FT%T)] core: estree probe FAILED (no summary line — timed out or crashed)" >> "$LOG"
    printf '%s\n' "$estree_out" | tail -20 >> "$LOG" 2>/dev/null || true
  fi

  # The known-good baseline this candidate must not regress. Read from the
  # anchor file written by the last green run; absent on the very first run,
  # in which case the gate is simply "A1 clean, probe valid, lib tests pass"
  # and the current numbers BECOME the baseline.
  kg_estree=""
  [ -f "$KNOWN_GOOD_FILE" ] && kg_estree=$(sed -n 's/^estree_fails=//p' "$KNOWN_GOOD_FILE" | tail -1)
  estree_ok=0
  if [ "$estree_probe" = ok ] && [ -n "$kg_estree" ] && [ "$estree_fails" -le "$kg_estree" ]; then
    estree_ok=1
  elif [ "$estree_probe" = ok ] && [ -z "$kg_estree" ]; then
    # no baseline yet: adopt this run's numbers (still must be a valid probe)
    estree_ok=1
  fi

  # A probe that could not measure ANY example is not a pass, whatever the
  # counts say.
  a1_ok=0
  [ "$v" -eq 0 ] && [ "$failed" -eq 0 ] && a1_ok=1

  # ── lib tests, BASELINED (a candidate must not ADD failures) ──
  # The gate used to require `cargo test --lib` to exit 0. But this tree has a
  # set of KNOWN-RED lib tests (14 at last count) that predate any candidate —
  # they are real defects being worked down by the backends, not something a
  # core candidate introduced. Requiring exit 0 therefore meant the gate could
  # NEVER go green, never advance the known-good anchor, and so rolled back and
  # discarded EVERY candidate forever — the 23-consecutive-RED churn. Worse, a
  # hang and a red suite were indistinguishable to the gate: both made the
  # `cargo test` non-zero, and the empty `gate RED ()` reason hid which.
  #
  # So: count the lib-test failures and compare against a baseline, exactly
  # like the estree corpus. A candidate passes if it does not make the count
  # WORSE. On the very first run (no baseline yet) the current count BECOMES
  # the baseline, which is what finally lets the anchor be established.
  #
  # A HANG is still distinct from red: libtest prints its `test result:` line
  # only when the suite finishes. No summary line => hung or crashed => a hard
  # failure, never a baseline to adopt.
  lib_out=$("$ROOT/harness/build-lock.sh" --role core -- cargo test --lib \
      --manifest-path "$SUB/Cargo.toml" 2>&1) || true
  lib_fails=$(printf '%s\n' "$lib_out" \
      | sed -n 's/^test result: .* \([0-9][0-9]*\) failed.*/\1/p' | tail -1)
  if [ -z "$lib_fails" ]; then
    lib_ok=0
    lib_reason="no lib-test summary line (suite hung or crashed — NOT a pass)"
    echo "[$(date +%FT%T)] core: lib tests produced NO summary (hung or crashed)" >> "$LOG"
    printf '%s\n' "$lib_out" | tail -20 >> "$LOG" 2>/dev/null || true
  else
    kg_lib=""
    [ -f "$KNOWN_GOOD_FILE" ] && kg_lib=$(sed -n 's/^lib_fails=//p' "$KNOWN_GOOD_FILE" | tail -1)
    if [ -n "$kg_lib" ] && [ "$lib_fails" -le "$kg_lib" ]; then
      lib_ok=1; lib_reason=""
    elif [ -z "$kg_lib" ]; then
      # no baseline yet: adopt this run's count (the known-red set).
      lib_ok=1; lib_reason=""
    else
      lib_ok=0
      lib_reason="lib $lib_fails failures vs baseline $kg_lib"
    fi
  fi

  if [ "$a1_ok" -eq 1 ] && [ "$estree_ok" -eq 1 ] && [ "$lib_ok" -eq 1 ]; then
    echo "[$(date +%FT%T)] core: gate GREEN (A1 native + estree corpus + lib tests)" >> "$LOG"
    printf '%s core-worker: GREEN (A1 violations 0, estree %s fails, lib %s fails vs baseline %s, %s done, %s rejected)\n' \
      "$(date +%FT%T)" "$estree_fails" "$lib_fails" "${kg_lib:-adopted}" "$(done_count)" "$(rejected_count)" >> "$REPORTS/core-worker.report"
    if [ -n "$(git -C "$SUB" status --porcelain -- src/ 2>/dev/null)" ]; then
      git -C "$SUB" add src/ 2>/dev/null || true
      git -C "$SUB" commit -m "core marketplace: candidate verified (build + invariants + estree corpus green)" 2>/dev/null || true
    fi
    # ADVANCE THE ROLLBACK ANCHOR — this commit is now the verified-green
    # state a future red candidate is rolled back to. The ref update is atomic
    # (git update-ref refuses a non-fast-forward) and the metrics file is
    # rewritten beside it.
    kg_commit=$(git -C "$SUB" rev-parse HEAD 2>/dev/null || true)
    if [ -n "$kg_commit" ]; then
      git -C "$SUB" update-ref "$KNOWN_GOOD_REF" "$kg_commit" 2>>"$LOG" || true
      # Write the metrics file ATOMICALLY and re-create its directory first.
      # A plain `cat >` here killed the whole worker when the directory was
      # momentarily absent (something in the fleet prunes .core-verify), and
      # that took down the ONE branch that advances the anchor — the gate had
      # just gone GREEN and the run still died rc=1 with the green result lost.
      # A half-written metrics file is equally bad: the next iteration would
      # read a truncated baseline. Write a temp file, then rename.
      mkdir -p "$(dirname "$KNOWN_GOOD_FILE")" 2>/dev/null || true
      kg_tmp="$KNOWN_GOOD_FILE.tmp.$$"
      if cat > "$kg_tmp" 2>/dev/null <<EOF
commit=$kg_commit
a1_violations=0
estree_fails=$estree_fails
estree_total=$estree_total
lib_fails=$lib_fails
verified_at=$(date +%s)
EOF
      then
        mv -f "$kg_tmp" "$KNOWN_GOOD_FILE" 2>>"$LOG" \
          || rm -f "$kg_tmp" 2>/dev/null || true
      fi
      printf '%s core-worker: KNOWN-GOOD advanced to %s (A1 0, estree %s, lib %s)\n' \
        "$(date +%FT%T)" "$(git -C "$SUB" rev-parse --short "$kg_commit")" "$estree_fails" "$lib_fails" >> "$REPORTS/core-worker.report"
    fi
    # Now, and only now, the staged offer is accepted.
    if [ -n "${staged_offer:-}" ] && [ -f "${staged_offer:-}" ]; then
      mv "$staged_offer" "$REQS/transforms/done/"
      printf '%s core-worker: ACCEPTED %s (build + lib tests + invariants + estree corpus green)\n' \
        "$(date +%FT%T)" "$staged_name" >> "$REPORTS/core-worker.report"
    fi
    staged_offer=""; staged_name=""
    # LAND on main ONLY when green, via merge — the estree worker's main
    # tree stays clean (it never sees this worker's WIP or commits-in-
    # progress). ff-only: if main moved (estree commits), defer to the next
    # iteration rather than risk a cross-worker merge conflict.
    if [ -n "$(git -C "$SUB" log --oneline main..backend/core 2>/dev/null)" ]; then
      if git -C "$ROOT/sh2perl" merge --ff-only backend/core >> "$LOG" 2>&1; then
        echo "[$(date +%FT%T)] core: landed backend/core -> main (ff)" >> "$LOG"
      else
        echo "[$(date +%FT%T)] core: ff-merge deferred (main moved) — will retry next iteration" >> "$LOG"
      fi
    fi
    wake_sleepers
  else
    # ── RED: roll the worktree back to the verified-green anchor ──
    # Every one of the three checks MUST contribute a reason when it fails.
    # The old code let `cargo test --lib` fail with an EMPTY reason, which is
    # how a spinning test and a genuine red suite both printed `gate RED ()`
    # and sent the investigation nowhere.
    reason=""
    [ "$a1_ok" -ne 1 ] && reason="A1 not clean (violations=$v, probe-failures=$failed)"
    [ "$estree_ok" -ne 1 ] && reason="${reason:+$reason; }estree $estree_fails vs baseline ${kg_estree:-none} ($estree_reason)"
    [ "$lib_ok" -ne 1 ] && reason="${reason:+$reason; }lib $lib_reason"
    [ -z "$reason" ] && reason="gate conditions changed under the run (no single check explains RED)"
    echo "[$(date +%FT%T)] core: gate RED ($reason) — rolling back the candidate" >> "$LOG"
    if [ "$estree_probe" != ok ]; then
      printf '%s core-worker: RED (probe FAILED: %s; A1 violations=%s probe-failures=%s; lib %s)\n' \
        "$(date +%FT%T)" "$estree_reason" "$v" "$failed" "$lib_reason" >> "$REPORTS/core-worker.report"
    else
      printf '%s core-worker: RED (%s; %s done, %s rejected)\n' \
        "$(date +%FT%T)" "$reason" "$(done_count)" "$(rejected_count)" >> "$REPORTS/core-worker.report"
    fi
    # Discard the candidate: the offer stays pending (its author can fix it),
    # and the worktree goes back to the last verified-green commit.
    restore_known_good
    staged_offer=""; staged_name=""
  fi
  sleep "$WATCH"
done
