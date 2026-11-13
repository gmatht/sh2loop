# c: gate's only red cell is still the `unset` flag heuristic — 7th C filing, re-verified 2026-10-24T19:32+08

Type: shared-analysis BUG in an existing pass (`src/transforms/copy_propagation.rs`,
`classify_builtin_writes`). No new node, no contract change, no transform offer.

Requested by: c backend worker (`backends/c`, branch `backend/c`).

**STATUS — this is not a new defect.** Same item as `c-20261023-210500-unset-const-fold`,
`c-20261024-035500`, `c-20261024-150200-unset-const-fold-still-open`,
`c-20261024-160500-unset-flag-heuristic`, `c-20261024-181153-unset-flag-heuristic-6th`,
and (perl side) `perl-20261024-032941` … `perl-20261024-173940-unset-flag-still-open`.
Per the 6th filing's closing sentence, this is the LAST C filing of this item: the C
gate is otherwise green (642/650 render OK, 0 stubs, 0 static-analysis), so if the
decision is to leave the heuristic as-is, say so and stop re-entering this worktree on
this cell.

**NEW EVIDENCE IN THIS FILING (C-specific, cheap, reproducible).** The the error is
isolated to the heuristic by NAME LENGTH alone, run end-to-end through the C renderer:

```
name  c output   bash   verdict
x     5          gone   WRONG  (1 char  -> skipped as a flag)
ab    5          gone   WRONG  (2 chars -> skipped as a flag)
abc   gone       gone   correct (3 chars -> counted as a write)
```

and with the fold switched off the C renderer is already correct on the exact cell:

```
$ printf 'x=5\nunset x\necho "${x:-gone}"\n' > /tmp/b.sh
$ SH2_TRANSFORMS=none otranspilerl-cli --target shir /tmp/b.sh \
    | backends/c/target/debug/shir_render --target=c - | cc -x c - -o /tmp/b && /tmp/b
gone            # bash: gone
```

So no C renderer change is needed or possible — the A1 handed to it has already lost
the expansion (the emitted C is `fputs("5\n")`; the `$x` read is gone, not mis-rendered).

## NEED

`classify_builtin_writes` must count `unset NAME` as a write to `NAME` for EVERY NAME,
including one- and two-character names. Today a bare `x` is classified as a command-line
FLAG and skipped, so the write is invisible, the variable still looks "assigned exactly
once", and `fold_expr` substitutes the dead literal into every later read (including
`${x:-gone}` via `fold_param_const`'s `(":-", 3)` arm).

## WHY

`src/transforms/copy_propagation.rs:410` (current main tree `fm-wc-semantics2`, the
line number is unchanged despite the uncommitted `param-const-fold` work in that file —
verified absent today, `grep -c dashed = 0`):

```
            if let IrExpr::Str(s, _) = a {
                let s = s.trim_start_matches('-');
                if s.is_empty() || (s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) {
                    continue; // a flag like -i/-r/-x/-a/-A/-l/-u/-n/-g/-t/-p/-f/-F
```

The dash is stripped BEFORE the flag test, so the test can no longer tell `-v` from a
bare `v`. Two-letter names too (`ab`), and the same hole swallows `read n`,
`mapfile -t a`, `local x`, `declare -i x`.

Bisect proving this transform is the sole producer of the bad A1 (each name run alone):

```
SH2_TRANSFORMS=copy-propagation   -> echo arg is Str("5")            WRONG
SH2_TRANSFORMS=dead-store-elim    -> echo arg is param(":-", x, …)   correct
SH2_TRANSFORMS=i32-provable       -> echo arg is param(":-", x, …)   correct
SH2_TRANSFORMS=const-condition-elim -> echo arg is param(":-", x, …) correct
```

## MINIMAL-CORE-CHANGE

`src/transforms/copy_propagation.rs`, line 410 — one hoisted boolean:

```diff
@@ -407,9 +407,10 @@
     ) {
         for a in args {
             if let IrExpr::Str(s, _) = a {
-                let s = s.trim_start_matches('-');
-                if s.is_empty() || (s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) {
+                let dashed = s.starts_with('-');
+                let s = s.trim_start_matches('-');
+                if s.is_empty() || (dashed && s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) {
                     continue; // a flag like -i/-r/-x/-a/-A/-l/-u/-n/-g/-t/-p/-f/-F
```

Notes for the applier:

- `--` long options still strip to `''` → `s.is_empty()` → still skipped.
- `-i`/`-r`/`-x`/`-v` still skipped (`dashed && len <= 2 && alpha`).
- `-o pipefail` strips to `o pipefail` → not all-alpha → counted as a name, exactly as
  today (the dash does not alter that arm).
- `-A` in the comment never matched the predicate anyway (not ASCII-alphabetic).
- The `let` arm below uses `str_maybe_read_vars`, which has no flag heuristic — no change.
- Direction is conservative: more names count as writes → fewer folds → the worst case
  is a `param`/`getVar` node the renderers already handle. No renderer changes, no corpus
  re-bless, no re-baseline.

Unit test beside the module's existing tests:

```rust
// must NOT fold: the unset is a write
assert!(run_copy_prop("x=5; unset x; echo \"$x\"").contains("getVar"));
// must fold
assert!(run_copy_prop("x=5; echo \"$x\"").contains("Str(\"5\")"));
```

Patch verification already on file: `perl-20261024-073500-unset-const-fold.md` built the
diff in `/tmp/corefix` and measured the chat corpus with this same shared core —
`unpatched OK=641 FAIL=2`, `patched OK=643 FAIL=0`, `t70_unset` flipping and nothing else
moving. The C arm above shows why the c gate follows identically: with the fold gone the
C renderer already produces `gone`.

## FAILING-CASE

`sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh`

```sh
x=5
unset x
echo "${x:-gone}"
```

bash prints `gone`; every backend prints `5` (perl/estree/python checked directly).
C worktree state (measured 2026-10-24T19:2xZ, `harness/c_gate_local.sh`, the mirror of
the loop gate's equivalence arm):

```
[c] backend gate: 642/650 corpus render OK, 1 fail (0 stubs, 1 equiv, 0 static-analysis),
    7 skip (0 allowlisted)
fails: frontends/posix-sh-go/testdata/t70_unset.sh
```

`t70_unset.sh` is the only deterministic red cell, it is red on the shared A1, and it is
the only thing standing between this backend and a green gate.

## OUTCOME: implemented

Landed in `sh2perl/src/transforms/copy_propagation.rs::classify_builtin_writes`: a word is treated as a command-line flag only when it actually carried a leading `-`, so a bare 1-2 letter NAME (`unset x`, `read ab`, `local n`) is recorded as a write and copy-propagation refuses the stale fold. Pinned by unit tests `unset_invalidates_single_def`, `read_invalidates_single_def`, `dashed_flag_is_still_skipped`, `folds_without_unset`.

Verification: `./fail-estree` -> PERL 562/562 passed, ESTREE 561/562. The single estree failure (`grep_p.sh`, "non-sh2 callee: min") reproduces identically with `SH2_TRANSFORMS=none` and the file contains no store-writing builtin, so it is pre-existing/WIP and unrelated. `cargo test --lib`: the 27 failures are identical before and after this hunk (pre-existing WIP); the 4 new tests pass.

Note: the fix landed in the live working tree, which is the tree `setup_backends.sh` and all gates build `otranspilerl-cli` from. The same file carries the in-flight `fold_param_const` WIP (+~640 uncommitted lines) plus 57 other dirty `src/` files, so a scoped commit is not isolable this round.
