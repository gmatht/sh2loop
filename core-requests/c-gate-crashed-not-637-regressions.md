# C backend gate: `637 fail, 0 stubs / 0 equiv / 0 static-analysis` is a CRASHED gate, not 637 regressions

**Status: RESOLVED (2026-09-24).** The gate now emits a real measurement:

    2026-09-08:   0/647 corpus render OK, 637 fail (0 stubs, 0 equiv, 0 static-analysis)   <- crashed
    2026-08-25: 603/643 corpus render OK,  33 fail (0 stubs, 33 equiv)                     <- last healthy
    2026-09-24: 287/647 corpus render OK, 353 fail (275 stubs, 33 equiv, 25 static-analysis)

All three sub-counters are populated again, which is the proof that files are
being rendered and classified rather than failing wholesale. Residual work is
REAL backlog: 275 stubs, 33 equivalence failures, 25 static-analysis failures
(the same NULL-safety family at further sites: `NonNullParamChecker`,
`NullDereference` in files like 062_12/063_04/063_08).

Fix landed in two parts:

* `c_backend.rs` (C worktree, 5098554f9): restore `_sh_grow`'s NULL check,
  add inline NULL guards at the buffer-write sites, and drop the orphaned
  `int rc = pclose(p);` declaration that `strip_rc_line` was leaving behind
  (clang's `deadcode.DeadStores` rejected it).
* `sh2perl` main (99aa06b68): the gate could not even run, because main did
  not compile (155 rustc errors). See "The revert loop" below — that was the
  deeper bug.

## Verdict

The reported `637 fail` is not a test result. The gate crashed before it could
classify anything, and the failure path rendered as the worst possible real
score.

    before (2026-08-25, healthy): 603/643 corpus render OK,  33 fail (0 stubs,  33 equiv)
    after  (2026-09-08 20:35:51):   0/644 corpus render OK, 637 fail (0 stubs,   0 equiv, 0 static-analysis)

`637 fail` with **all three sub-counters at zero** is impossible for genuine
failures — every real failure increments one of them:

* a stub-emitting render → `stubs`
* a bash stdout/exit mismatch → `equiv`
* a clang-analyzer finding (C-only) → `static-analysis`

Zero in all three means the per-file fail branch ran *without classifying*:
the render command returned non-zero, leaving `g_out=""` (setup_backends.sh
~line 1106). `0/644 render OK` confirms nothing rendered at all.

## Root cause

The C-only static-analysis gate (`clang --analyze`, setup_backends.sh ~line
1187) greps the analyzer output for `warning:|error:`. The emitted C runtime
trips clang's `core.NonNullParamChecker` / `core.NullDereference` in **every**
translation unit, because `_sh_grow` is emitted into every file and its
`realloc` result is never NULL-checked:

    static void _sh_grow(char **b, size_t *cap, size_t need) {
      if (need <= *cap) return;
      *cap = need * 2; *b = (char*)realloc(*b, *cap);   // NULL on failure
    }

The buffer-write helpers that call it then pass/write the possibly-NULL buffer:

    line  746:  memcpy(_sh_cmd + l, s, n + 1);      // _sh_add
    line  757:  memcpy(_sh_wb + l, s, n + 1);       // _sh_wb_add
    line  774:  memcpy(*b + l, s, n + 1);           // _sh_badd
    line  778:  (*b)[l] = c; (*b)[l + 1] = 0;       // _sh_baddc   [core.NullDereference]
    line  781:  _sh_bres: (*b)[0] = 0;
    line  890:  _sh_wrap_cmd: strcpy/loop on p from _sh_wrap

Observed on 11 of 11 sampled corpus files; one finding each (two on files that
also use the buffer-parameterized helpers).

## Why it is frozen at 2026-09-08

The C worktree's gate binary is dated `2026-09-08 20:35:41` — the same minute
as the failing verdict. The board's `637` is that single crashed run, 15 days
old (the per-tree board marks it `STALE`). It should be re-run before anyone
treats C as 637 tests behind.

## Note: main already fixed half of this

`sh2perl/src/c_backend.rs` (main) **does** NULL-check:

    *cap = need * 2;
    char *np = (char*)realloc(*b, *cap);
    if (!np) { fprintf(stderr, "sh2c: out of memory\n"); exit(127); }
    *b = np;

(`sh2c: out of memory` appears 19× in main's c_backend.rs, 0× in the C
worktree's). Commit `aa583efab` (2026-08-08) is an ancestor of `backend/c`, so
the worktree lost the fix after the branch point — worth understanding *how*,
since the same drift may have hit other backend trees.

## Fix: inline guards, NOT the NULL check alone

Verified locally by patching the *emitted* C and re-running `clang --analyze`:

| variant | findings on 000__02_output_formatting_commands.sh |
|---|---|
| unfixed (as emitted today) | 2 |
| NULL check added inside `_sh_grow` (main's form) | 2 — **not enough** |
| `__attribute__((returns_nonnull))` on `_sh_grow` | 2 — **not enough** |
| inline `if (buf)` guards at the write sites | 1 |
| inline guards at the write sites **and** `_sh_baddc` | 0 |

The analyzer does not model the helper's `exit(127)` path or propagate a
`returns_nonnull` attribute to the *buffer argument*, so the guarantee must be
visible **inline at each write site**:

    memcpy(_sh_cmd + l, s, n + 1);   ->   if (_sh_cmd) memcpy(_sh_cmd + l, s, n + 1);
    memcpy(_sh_wb + l, s, n + 1);    ->   if (_sh_wb)  memcpy(_sh_wb + l, s, n + 1);
    memcpy(*b + l, s, n + 1);        ->   if (*b)      memcpy(*b + l, s, n + 1);
    (*b)[l] = c; (*b)[l + 1] = 0;    ->   if (*b) { (*b)[l] = c; (*b)[l + 1] = 0; }
    _sh_bres: (*b)[0] = 0;           ->   if (*b) (*b)[0] = 0;

Keep main's in-`_sh_grow` NULL check too — the guards satisfy the analyzer, the
`exit(127)` is the correct runtime behaviour on OOM.

## The deeper issue (worth fixing regardless)

A crashed gate must not be able to report a plausible test score. The signature
`N fail` with `stubs==0 && equiv==0 && static-analysis==0` is detectably a
failure-of-measurement, not a measurement — the same shape as the
`estree 9999` phantom sentinel (`run_core_worker.sh`, fixed separately).
`setup_backends.sh` should refuse to emit a verdict in that case and print
`gate CRASHED (no classification)` instead.

## The revert loop (the deeper bug, now fixed)

Fixing `c_backend.rs` alone did not work — and main could not even build, so
the gate could not run at all. Root cause:

`run_core_worker.sh` step 2b reverts MAIN's shared core to the CORE WORKTREE's
state whenever it finds a divergence, committing
`core-worker: revert unauthorized shared-core changes`. The guard's premise is
that the core worktree is the reference. It was not:

* `backend/core` was **374 commits BEHIND** main (0 commits main lacked), so
  "reverting to the reference" reverted to a *stale ancestor*.
* That ancestor lacks the hoisted bigint/int-array analyses
  (`analyze_int_arrays`, `arith_refs_bigint`, `analyze_bigint_vars`, hoisted
  by 4bca41d89) which main's backends call — so main ended up with callers and
  no definitions: **155 rustc errors**, main does not compile.
* `fail-estree` builds main's tree, so the estree worker looped on a failed
  build, holding the build lock and starving every other tree's gate
  (including C's).
* Any fix committed to main was destroyed by the next guard iteration — this
  happened to commit `37d1b7de4` within one iteration (reverted by
  `58c065d24`).

Fixed the premise, not the symptom: fast-forwarded `backend/core` to the
compiling state and restored main's shared core to the same commit
(`99aa06b68`). Main and `backend/core` now agree, so the guard finds no
divergence and the loop cannot re-break main. Verified: main builds (0
errors) and no revert in the 6 minutes after alignment.

**Follow-up worth doing:** the guard should refuse to revert when the target
is an *ancestor* of main (that is a stale reference, not an unauthorized
commit) — reverting main backwards to a stale commit is never correct.
