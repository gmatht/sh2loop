# copy-propagation: a bare 1–2 letter NAME is discarded as a flag, so `unset x` is not counted as a write to `x`

Type: shared-analysis BUG in an existing pass (`src/transforms/copy_propagation.rs`).
No new node, no contract change, no transform offer.
Requested by: perl backend worker (backends/perl, branch `backend/perl`).

**CONSOLIDATION.** This is the same defect reported as
`perl-20261024-032941.md`, `perl-20261024-052500.md`,
`perl-20261024-071410.md` and `c-20261023-210500-unset-const-fold.md`.
All four are still open and still accurate; the three perl filings are byte-
equivalent escalations of one 3-line fix. Apply the patch once and they all
close together. Filed newest-first so the mediator can pick it up next
iteration and skip the duplicates.

## NEED

In `classify_builtin_writes`, a word in a store-writing builtin's argument list
must only be treated as a command-line FLAG when it actually carried a leading
`-`. Today the dash is stripped BEFORE the flag test, so a bare 1–2 letter
VARIABLE NAME (`x`, `i`, `n`, `v`, `ab`) is indistinguishable from `-i` and is
dropped — the write to that name is never recorded.

## WHY

The write is invisible to `collect_defs`, the variable still looks "assigned
exactly once", and `fold_expr` substitutes the stale literal into every later
read — including `${x:-gone}`, via `fold_param_const`'s `(":-", 3)` arm.

The exported A1 has already lost the expansion, so NO renderer can repair it:

```
$ printf 'x=5\nunset x\necho "${x:-gone}"\n' > /tmp/tc.sh
$ otranspilerl-cli --target shir /tmp/tc.sh | jq -c '.stmts[2].expr.args[1].elements[0]'
{"style":"DoubleQuoted","type":"Str","value":"5"}          # folded across the unset — wrong
$ SH2_TRANSFORMS=none otranspilerl-cli --target shir /tmp/tc.sh | jq -c '.stmts[2].expr.args[1].elements[0]'
{"type":"Call","func":"param","args":[...]}                 # correct
```

Proof the RENDERER is not the defect: with the transform off, the perl backend
renders the same file and matches bash.

```
$ SH2_TRANSFORMS=none otranspilerl-cli --target shir /tmp/tc.sh \
    | shir_render --target=perl - | tail -1
print (join(' ', ((($x // "") ne "") ? $x : "gone")) . "\n");
$ perl … -> gone            # bash: gone
```

Threshold is NAME LENGTH, not the construct — measured on the current tree:

```
x    = 5; unset x;    echo "${x:-gone}"    -> Str("5")        # folded — wrong
ab   = 5; unset ab;   echo "${ab:-gone}"   -> Str("5")        # folded — wrong
abc  = 5; unset abc;  echo "${abc:-gone}"  -> param(":-",…)   # correct
abc  = 5; unset abc;  echo "${abc:-gone}"  -> param(":-",…)   # correct
```

The same hole swallows `read n`, `declare -i x`, `mapfile -t a`.

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
                 }
```

Notes for the applier:

- `-A` in that comment never matched the predicate anyway (not ASCII-alphabetic).
- `--` long options still strip to `''` → `s.is_empty()` → still skipped.
- `-i`/`-r`/`-x`/`-v` still skipped (`dashed && len <= 2 && alpha`).
- `-o pipefail`: strips to `o pipefail` → not all-alpha → counted as a name, same
  as today (unchanged behaviour, the dash does not alter that arm).
- The `let` arm below loops over the same `args` but uses `str_maybe_read_vars`,
  which has no flag heuristic — no change needed there.
- Fix direction is conservative: more names count as writes → fewer folds →
  the worst case is a `getVar`/`param` node the renderers already handle. No
  renderer changes, no corpus re-bless needed.

A unit test beside the existing module tests should pin both sides:

```rust
// must NOT fold: the unset is a write
assert!(run_copy_prop("x=5; unset x; echo \"$x\"").contains("getVar"));
// must fold
assert!(run_copy_prop("x=5; echo \"$x\"").contains("Str(\"5\")"));
```

## PATCH VERIFIED — the diff above was built and gated, not reasoned about

`sh2perl/` + `otranspilerl/` were copied to `/tmp/corefix` (the real core was
NOT touched), the diff above applied, and `cargo build --bin otranspilerl-cli`
run with the pinned 1.90 toolchain. Then the gate's equivalence arm was run over
the same 650-file corpus the perl gate uses, with the worktree
`shir_render --target=perl` as the renderer:

```
core               result
unpatched (today)   OK=641 FAIL=2 skip=7   (046_cd..sh, t70_unset)
patched             OK=643 FAIL=0 skip=7
```

`t70_unset.sh` flips to pass and NOTHING else moves. (`046_cd..sh` is
`cd ..; ls`, which lists `/tmp` — it toggles with whatever transient files the
harness has alive, on both cores; the loop gate does not list it, and it is
absent from the patched result above.)

The patched A1 for the failing case is the `param` call bash needs:

```
{"args":["…",":-","x","gone"],"func":"param","purity":"PureCpu","type":"Call"}
```

and the perl render of it is `((($x // "") ne "") ? $x : "gone")` → `gone`.

## FAILING-CASE

`sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh`

```sh
x=5
unset x
echo "${x:-gone}"
```

bash prints `gone`; every backend prints `5`.

Perl worktree state (measured 2026-10-24T07:5xZ, `backends/perl/.gate_replica.sh`,
the mirror of the loop gate's equivalence arm):

```
---- replica: OK=641 FAIL=2 (render=0 stub=0) skip=7 ----
failing:  046_cd..sh t70_unset.sh
```

- `t70_unset.sh` — this request. The only deterministic red cell; the loop gate
  reports `642/650 render OK, 1 fail (1 equiv), 7 skip` and names it.
- `046_cd..sh` — harness noise, not a renderer defect: the script is
  `cd ..; ls`, so it lists `/tmp` and echoes whatever transient files the
  harness has alive at that instant (`Sh2Program.class`, `eq_<pid>_out`, …).
  It toggles on both the patched and unpatched core and the loop gate does not
  list it. (`.gate_replica.sh` was also reusing one output path per corpus file,
  which let a background process from `072_background_fork` scribble into a
  later file's output — that is why `051_primes.sh` used to appear here; the
  triage script now uses a fresh path per file, like the real gate.)

Nothing else in the perl worktree is pending: 562/562 corpus renders compile,
0 stub markers, and `harness/backend_runtime_metric.sh perl` reports
`calls 0` / `total 1109`, where every one of the 1109 is a LEXICAL
(`$__sh_st` `$?` model 1036, `$__sh_ls0` 37, `@__sh_bg` 26, fds 8, `$__sh_eh0` 2)
— not a runtime entry point. No construct is left delegating.

## OUTCOME: implemented

Landed in `sh2perl/src/transforms/copy_propagation.rs::classify_builtin_writes`: a word is treated as a command-line flag only when it actually carried a leading `-`, so a bare 1-2 letter NAME (`unset x`, `read ab`, `local n`) is recorded as a write and copy-propagation refuses the stale fold. Pinned by unit tests `unset_invalidates_single_def`, `read_invalidates_single_def`, `dashed_flag_is_still_skipped`, `folds_without_unset`.

Verification: `./fail-estree` -> PERL 562/562 passed, ESTREE 561/562. The single estree failure (`grep_p.sh`, "non-sh2 callee: min") reproduces identically with `SH2_TRANSFORMS=none` and the file contains no store-writing builtin, so it is pre-existing/WIP and unrelated. `cargo test --lib`: the 27 failures are identical before and after this hunk (pre-existing WIP); the 4 new tests pass.

Note: the fix landed in the live working tree, which is the tree `setup_backends.sh` and all gates build `otranspilerl-cli` from. The same file carries the in-flight `fold_param_const` WIP (+~640 uncommitted lines) plus 57 other dirty `src/` files, so a scoped commit is not isolable this round.
