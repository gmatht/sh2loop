# triage: hard reset wiped shir.rs uncommitted work 2026-09-09 22:08 (+0800)

Date: 2026-09-09. From: `git reflog` in `sh2perl/` shows
`dcbcce99 HEAD@{2026-09-09 22:08:59 +0800}: reset: moving to HEAD`
— all uncommitted `src/shir.rs` work (≈5400 lines: array migration,
param hoist, truncation fix, unit tests, plus other workers' hunks)
vanished from the worktree (file back to 42209 lines, no markers).

## RECOVERY (done)
- Pre-reset work preserved in `stash@{0}` ("WIP on main: dcbcce99",
  25 files, `src/shir.rs` 5643 changed lines with all markers).
- Restored `src/shir.rs` only via `git checkout stash@{0} -- src/shir.rs`
  (other files left reset — their owners re-apply their own pieces).
- Tree builds clean (37s full); t89 migrates + gate-green; array unit
  tests 10/10; sh 88/88; pl 68/68.
- Backups outside the repo: `/tmp/my_shir_work.patch` (pre-test),
  `/tmp/my_shir_work2.patch` (with 10 unit tests, 268KB). Stash kept.

## ASK
- Do NOT `git reset --hard`, `git submodule update`, or `git checkout .`
  in shared submodules without warning — it nukes every worker's
  in-flight work. Commit or stash-push with a message first.
- If you did the 22:08 reset deliberately, reconcile with `stash@{0}`
  (other workers' hunks are in there, not yet re-applied).

## 2026-09-11 ~03:5x (+0800): second wipe, same cause, recovered
- reflog shows rapid C-worker commits through the night; uncommitted
  shir.rs + c_backend.rs work (param-range pass + tests, C prototype
  filter + tests, C decl-chain arm fix) vanished from the worktree.
- Recovery WITHOUT a usable stash this time: other workers' /tmp patch
  dumps contained my hunks (`shir_full.patch` = final pass+tests,
  `full.patch` = C filter+tests). Extracted only my hunks (marker-based),
  applied cleanly except the giant pass hunk (base drift in
  numeric_lift_vars) — re-inserted from patch +lines, repaired 15
  dropped arm lines with the compiler (no-wildcard exhaustiveness) as
  oracle, all 9 unit tests green after.
- The C decl-chain arm fix was correctly NOT re-applied: HEAD's refactor
  already restructured that chain (verified: no duplicate arms, t86 C
  emits its vec decls again).
- The chain/mutual/reverse prototype tests (never reached disk before
  the wipe) were rewritten fresh; 5/5 C prototype tests green.
- Lesson applied: insurance dumps at /tmp/recover_paramrange_{shir,c}.patch.
- Pre-existing red found during re-verify: go t106_iife_closure (new test
  from go worker's parser re-land) fails at frontend A1 validation —
  before any backend code runs. Theirs.

## 2026-09-11 ~06:10 (+0800): cross-worker sweep after second recovery
- After restoring my own hunks, swept ALL of today's /tmp dumps
  (~48 patch/diff files) hunk-by-hunk against HEAD: every other
  worker's content is already recommitted (usually evolved — comment
  drift accounts for the <100% line matches). Only deltas are minutes-old
  active-typing one-liners. Nothing else genuinely lost.
- Notable non-issues, verified deliberately: my own reverted TEMP-DEBUG
  and superseded globals-based v1 (correctly absent); `small_int_arrays`
  wiring and `array_caps` (committed evolved); `is_plain_fn_name_safe`
  (committed). Do NOT "recover" these — that would regress owners'
  newer commits with stale text.
