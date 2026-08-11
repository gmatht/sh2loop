# POSSIBLE_TESTING_IMPROVEMENTS.md

Review of the sh2loop testing infrastructure (2026-08-08), the policy rulings
that constrain it, and a ranked backlog. Grounded in observed failures:
the stderr-gate asymmetry, the GNU-isms example masking, the perl `declare -a`
hang, the `a#b`/non-ASCII parser gaps, shared-`/tmp` collisions, and bash
assoc-array hash-order nondeterminism.

## Policy rulings (binding)

1. **sh2js (estree) is the production path.** Regressions are not permitted
   in sh2js; every other backend (perl, sh, c, go, python, rust, zig, java)
   is expected to try and keep up — they may lag, and their gates are
   "keep-up" signals, not production gates. `estree.rs` lives in the shared
   core; the estree worker owns the core, so a core change is an sh2js change.
2. **Introducing a failing test is not a regression — it is the roadmap.**
   The failure-driven workers grind the failing-file work list; a new
   (or newly-exercised) construct that fails is exactly how they are guided
   toward real progress. Only a file that **was passing and starts failing**
   is a regression. Count-based "must stay at baseline" rules conflate the
   two and must not be used (the current estree worker prompt rule
   "estree_failed must stay 0 / at the trusted baseline" has this flaw).

## The invariant that follows

Per backend, persist the **pass set** (the set of corpus files that pass its
gate), and enforce pass-set **monotonicity** for sh2js:

- a previously-passing file may never start failing (hard fail);
- a new file that fails merely extends the baseline and becomes a work item;
- other backends: same data, no hard fail — drift is logged so core-change
  side effects stay attributable.

Mechanism: `harness/pass_sets.sh` + `.estree_pass_set`, `.perl_pass_set`,
`.sh_pass_set`, … (persisted in the workspace root). Verdict sources:
`.estree_failures.tsv` for estree (per-file, already maintained); the gates'
fails lists for the others.

## Ranked backlog

1. **Mechanical sh2js no-regression gate.** `fail-estree --gate` / the
   worker loop diffs the current estree pass set against `.estree_pass_set`
   and exits non-zero on any previously-passing file now failing. Replaces
   the prompt-soft "must stay 0" rule with the pass-set invariant (policy 2).
2. **Per-backend failure-set baselines** (this change): `.estree_pass_set`,
   `.perl_pass_set`, `.sh_pass_set`, … seeded from the current verdict
   sources, diffed by `harness/pass_sets.sh --check`. Core changes' side
   effects on lagging backends become visible (new failures attributable vs
   pre-existing red).
3. **Estree-first differential fuzzing.** Mutate corpus seeds (wrap in
   loops/ifs, swap operators, quoting variants), run bash vs the estree
   output under the existing equivalence machinery, feed new failures to the
   workers. The only improvement that compounds coverage indefinitely.
4. **Estree gate reliability: flake quarantine + panic/hang hard-guards.**
   Run each file in `mktemp -d` scratch (Chimera already does; the main
   gates don't); re-run flaky files once; distinct HANG/PANIC verdicts that
   hard-fail on the estree path. Also fixes shared-`/tmp` collisions
   (observed: a root-owned `/tmp/pg.sh` broke a probe run).
5. **Uniform verdict taxonomy across gates.**
   `PASS/SKIP/DIFF/TIMEOUT/HANG/PANIC/RENDER-REFUSE/PARSE-FAIL`. Today a
   renderer panic (rc 101), an infinite loop (perl `declare -a`, 20s per
   gate run), a graceful "not renderable" Err, and a wrong answer all
   collapse into "FAIL". Auto-bisect hangs to a minimal repro.
6. **Parser edge-gap probes (bash-differential).** Pin `a#b` mid-word
   comments, non-ASCII command words, `${x,}`-class constructs — one tiny
   construct per file with an expected-output check. The parser is shared
   core (estree-owned), so these protect sh2js first.
7. **Toolchain/environment manifest.** Record bash/coreutils/locale versions
   with each gate result (the coreutils gate already records the corpus git
   SHA) so environment drift is distinguishable from regression.
8. **Partial-credit reporting for lagging backends.** Line-match ratio +
   first diff hunks for near-miss files (a file with 55/63 matching lines is
   currently just "FAIL" — the worker gets no hint of the 8 wrong lines).
   Low priority: lagging paths only.
9. **check_qx trust model.** Hash-pin the allowlist; derive the perl
   shell-out list from `harness/builtins.json` automatically (maintained in
   two places today). Low priority under policy 1 (perl is a lagging path),
   but `builtins.json` also feeds the estree security allowlist.
10. **Repro ergonomics.** One `harness/eq-one <lang> <file>` entry point
    (render one file → run → diff, same env as the gate) across backends;
    `harness/dbg.sh` exists for estree only.

## Notes / non-goals

- A new corpus example that fails is a *desired* outcome — it guides the
  worker (policy 2). The GNU-isms example (070_gnuisms_thorough.sh) is the
  model: it passes estree (no regression) while pinning ~9 constructs for the
  perl/sh work lists.
- Never bless a regression (AGENTS.md): a failing test may join a blessed-fail
  allowlist only for a known runtime limitation, never to hide a bug.
- The `.sh_pass_set` baseline seeded from a *core-renderer* equivalence run
  (525 pass / 88 fail) differs from the sh gate's *worktree-renderer* pass
  set; re-seed from the gate's own fails list when convenient.
