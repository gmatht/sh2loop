# Backend / Worktree Code-Quality Review Note

Date: 2026-08-19
Scope: `sh2perl` main checkout + the backend worktrees (`sh2perl/backends/*`),
per the `/goal` "analyse the quality of the code in main and the work trees".

## 1. Merge health (are the worktrees up to date?)

Measured with `git rev-list` (ahead = commits in `backend/<lang>` not in `main`,
behind = commits in `main` not in the branch):

| worktree | ahead of main | behind main | dirty files |
|----------|--------------|-------------|-------------|
| perl     | 48           | 58          | 29          |
| js       | 11           | 1           | 6           |
| c        | 34           | 106         | 8           |
| python   | 10           | 1           | 3           |
| zig      | 1            | 281         | 232         |
| go       | 5            | 281         | 242         |
| rust     | 33           | 44          | 63          |
| sh       | 57           | 106         | 100         |
| java     | 5            | 106         | 100         |

The `setup_backends.sh --sync` path was **broken**: the old one-liner
`git fetch ... || git fetch ... git merge ...` was parsed as
`(fetch_worktree || fetch_sub) && echo "merged cleanly"`. Because the first
fetch always succeeds, the entire `git merge main` was short-circuited and the
tool only ever printed "merged cleanly" without merging. **Fixed** — the merge
is now a separate `if` statement run unconditionally (see `sync_worktree` in
`setup_backends.sh`).

With the fix, a real sync shows:
- `python` and `js` merge cleanly (js conflicts resolved, merge committed).
- `c`, `go`, `java`, `rust`, `sh`, `zig` have **real renderer merge conflicts**
  (their renderer files diverged hundreds of commits from main) and/or
  significant uncommitted renderer WIP that must be preserved.
- Several worktrees carry large uncommitted renderer work (`go` 242 files,
  `zig` 232, `sh` 100, `java` 100) — these are per-backend WIP, not shared-core
  changes. `src/shir.rs`, `src/ir.rs`, `src/estree.rs`, `src/parser/` are the
  single-owner core and must not be forked.

## 2. Corpus gate baseline

`./fail` (Perl corpus, 549 examples, executed equivalence vs bash):
**261 passed / 288 failed.** This is the regression baseline for criterion 2:
any change that turns a currently-passing test red is a regression. The 288
failures include known check_qx violations (bash/sh -c wrapping builtins) and
stdout mismatches — pre-existing, not introduced here.

## 3. TODO-stub generation per backend (from sh2perl/examples)

Rendered all 549 examples through each backend renderer (`--shir-in-<lang>`)
and counted genuine `sh2.*`/`TODO(unsupported)` stub markers:

| backend | stub calls | files w/ stubs | render errors |
|---------|-----------|----------------|---------------|
| **sh**    | 0          | 0              | 16 (refusals) |
| **perl**  | 0          | 0              | 0             |
| java    | 23         | 12             | 505           |
| go      | 81         | 54             | 0             |
| c       | 312        | 141            | 7             |
| rust    | 2317       | 416            | 0             |
| js      | 2949       | 447            | 0 (sh2.* is the real estree runtime namespace) |
| python  | 3823       | 449            | 0             |
| zig     | 5956       | 512            | 0             |

Notes:
- **sh** and **perl** emit zero genuine stubs. The sh backend additionally
  documents its non-POSIX constructs in a generated header (local, array
  emulation, `(( ))`, grep -P) and provides POSIX fallbacks for `seq`,
  `readlink`, `cmp`, `grep -P`, and whole-array expansions — satisfying the
  criterion-5 sh requirement (POSIX-first, macOS Bash v3-compatible where
  feasible).
- **js** emits `sh2.*` calls, but these are the real `sh2.*` runtime namespace
  of the ESTree-JSON contract (enforced by the estree gate's whitelist), not
  stub markers — excluded by the gate for that reason.
- **java** is essentially a stub generator: most examples cannot render (505
  render errors) and those that do render an "external — v1 stub" placeholder.
- **go**, **c** are the most tractable native-language backends (81 / 312).
  Go's stubs cluster in a few categories: `capture` (20), `and` (14),
  `Redirect` (14), `pipeline` (12), `redirect` (8), `builtin` (6).
- **rust**, **python**, **zig** emit thousands of stubs (large remaining
  lowering effort).

## 4. Findings / notable gaps

1. **`--sync` was silently doing nothing** — the primary reason the worktrees
   were not up to date. Fixed.
2. **Go `and`/`or`**: `Call{func:"and"/"or"}` chains fall through to a stub.
   A native chain-lowering (render each Arrow body, guard on captured `st`)
   removes the `and` stub but surfaces deeper process-substitution internals
   (`Redirect`, `capture`, `rm __ps_tmp` cleanup) that go does not yet lower.
   Net stub count unchanged, so it was reverted to keep the baseline clean.
   The real gap is go's missing process-substitution lowering.
3. **Java** needs a real renderer (it only emits v1 stubs).
4. **Fork/exec**: go/c/python/rust/zig still shell out (e.g. `capRun`/`redirRun`
   wrapping bash -c) for constructs the language could do natively (string/list
   ops, command capture). Reducing this is the criterion-6 work.
5. **Core single-owner** respected throughout: no edits to `src/shir.rs`,
   `src/ir.rs`, `src/estree.rs`, `src/parser/` were made for backend fixes.

## 5. Worktree renderer superiority (which merges are worth it)

Measured each backend worktree's AUTHORITATIVE renderer (what `--backend-gate`
builds/uses) vs main's current renderer, over all 549 examples (stub counts):

| backend | main renderer | worktree renderer | who is superior |
|---------|--------------|-------------------|-----------------|
| c       | 312           | 2                 | worktree (merge into main: high value) |
| rust    | 2323          | 0                 | worktree (merge into main: high value) |
| java    | 23 (+505 err) | 0                 | worktree (merge into main: high value) |
| sh      | 0             | 0                 | equal — both complete; no merge value |
| go      | 137           | 2168              | main (worktree stale; sync FROM main) |
| python  | 3834          | 8405              | main (worktree stale; sync FROM main) |
| zig     | 5975          | 7239              | main (worktree stale; sync FROM main) |
| perl    | 0             | 70                | main (worktree stale; sync FROM main) |

Conclusion: the **c, rust, and java worktrees are clearly superior** to main and
are the high-value merges (c: 312→2, rust: 2323→0, java: 23→0). The **go,
python, zig, perl worktrees are stale and inferior** to main's renderer —
merging them into main would REGRESS coverage; they should be synced FROM main
(or not merged at all). The sh backend is already complete on both sides.

## 6. Recommended path

- Resolve the per-backend renderer merge conflicts (`--sync` now works) so the
  worktree branches actually track main.
- Prioritize go then c (most tractable native backends), eliminating the
  `capture`/`Redirect`/`pipeline`/`and`/`builtin` stub categories, then
  replace bash -c shell-out with native language constructs.
- Java: replace the stub generator with a real renderer.
- Leave js (real runtime namespace) and the 16 sh refusals (documented
  non-expressible constructs) as justified exceptions.
