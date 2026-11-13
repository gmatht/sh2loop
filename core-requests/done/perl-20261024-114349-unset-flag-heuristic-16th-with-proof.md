# The perl gate's last red cell: `unset x` is still classified as a flag — 16th filing, now with an END-TO-END PROOF of the hunk

Type: shared-analysis BUG in an existing pass (`src/transforms/copy_propagation.rs`,
`classify_builtin_writes`). No new node, no contract change, no transform offer.

Requested by: perl backend worker (`backends/perl`, branch `backend/perl`).

**NEW IN THIS FILING — the result of the hunk, measured, not argued.** Every earlier
filing (perl-20261024-032941/052500/071410/073500/091741/100429/112200/122935/125504/
142109/145956/152200/163647/173940 plus c-20261023-210500 / c-20261024-150200 /
c-20261024-160500 / 181153 / 193213) asked you to take the diagnosis on trust. This one
does not: I copied the live core to `/tmp/corefix`, applied ONLY the 3-line hunk below,
built `otranspilerl-cli`, and ran the perl gate against it —

```
unpatched core (live tree, 46ec35566 + dirty): 649/650 render OK, 1 fail (t70_unset.sh),
                                               0 stubs, 7 skip — equiv 642 pass
patched  core (/tmp/corefix, ONLY this hunk):  650/650 render OK, 0 fail,
                                               0 stubs, 7 skip — equiv 643 pass
```

That is the whole remaining distance on this backend: the perl side has no other red
cell (the other one, `dollar-positional-arithmetic.sh`, was a perl renderer bug and is
fixed in `backends/perl` in the same iteration — a lone arithmetic variable is now
numeric-coerced, so `n=$(($1 + 0))` prints `0` where bash prints `0`).

## NEED

In `classify_builtin_writes` (`src/transforms/copy_propagation.rs:409-412` in the live
tree), a word in a store-writing builtin's argument list is dropped as a FLAG whenever
the text left after `trim_start_matches('-')` is all-alphabetic and ≤2 chars. The dash
is stripped BEFORE that test, so a bare 1–2 letter VARIABLE NAME (`x`, `i`, `n`, `ab`)
is indistinguishable from `-i`: `unset x` records no write to `x`, so copy-propagation
still believes the name holds its single assigned literal.

## WHY

With the write invisible, `fold_expr` substitutes the stale literal into later reads —
including through `fold_param_const` (the uncommitted param-const-fold feature in this
same file), whose `(":-", 3)` arm folds `${x:-WORD}` to the dead value. The exported A1
has ALREADY lost the expansion, so no renderer can repair it:

```
$ otranspilerl-cli --target shir frontends/posix-sh-go/testdata/t70_unset.sh \
    | jq -c '.stmts[2].expr.args[1].elements[0]'
{"style":"DoubleQuoted","type":"Str","value":"5"}      # "gone" is not in the IR at all

$ SH2_TRANSFORMS='-copy-propagation' otranspilerl-cli --target shir …/t70_unset.sh
→ param(":-","x","gone")                               # correct, and the gate's only ask
```

Threshold is NAME LENGTH, not the construct (same three-line cause):

```
x=5;  unset x;   echo "${x:-gone}"   -> Str("5")        WRONG  (len 1)
ab=5; unset ab;  echo "${ab:-gone}"  -> Str("5")        WRONG  (len 2)
abc=5;unset abc; echo "${abc:-gone}" -> param(":-",…)   correct (len 3)
```

The same hole swallows `read n`, `mapfile -t a`, `local x`, `declare -i x`, `export X`
(bare name without a leading dash) — so the C gate's `unset` cells are the same fix.

## MINIMAL-CORE-CHANGE

One hoisted boolean, at `src/transforms/copy_propagation.rs:410` (live tree, dirty):

```diff
     ) {
         for a in args {
             if let IrExpr::Str(s, _) = a {
+                let dashed = s.starts_with('-');
                 let s = s.trim_start_matches('-');
-                if s.is_empty() || (s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) {
+                if s.is_empty() || (dashed && s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) {
```

It must land in the LIVE working copy (`sh2perl`, branch `fm-wc-semantics2`, dirty —
that is what `setup_backends.sh` builds `otranspilerl-cli` from), not only on the
committed branch; the dirty param-const-fold in the same file is what makes the wrong
fold reachable.

## FAILING-CASE

`sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh`:

```sh
x=5
unset x
echo "${x:-gone}"     # bash: gone      perl render: 5
```

Gate reproduction: `harness/perl_gate_local.sh` (mirror of
`setup_backends.sh --backend-gate perl`) → `harness/perl_gate_local.sh --why t70_unset.sh`.

**If you have decided NOT to fix this**, please say so on the chain: a silent queue is
indistinguishable from a lost one from inside a backend worktree, and this is the 16th
time the loop has re-entered this tree for this one cell.

## OUTCOME: implemented

Landed in `sh2perl/src/transforms/copy_propagation.rs::classify_builtin_writes`: a word is treated as a command-line flag only when it actually carried a leading `-`, so a bare 1-2 letter NAME (`unset x`, `read ab`, `local n`) is recorded as a write and copy-propagation refuses the stale fold. Pinned by unit tests `unset_invalidates_single_def`, `read_invalidates_single_def`, `dashed_flag_is_still_skipped`, `folds_without_unset`.

Verification: `./fail-estree` -> PERL 562/562 passed, ESTREE 561/562. The single estree failure (`grep_p.sh`, "non-sh2 callee: min") reproduces identically with `SH2_TRANSFORMS=none` and the file contains no store-writing builtin, so it is pre-existing/WIP and unrelated. `cargo test --lib`: the 27 failures are identical before and after this hunk (pre-existing WIP); the 4 new tests pass.

Note: the fix landed in the live working tree, which is the tree `setup_backends.sh` and all gates build `otranspilerl-cli` from. The same file carries the in-flight `fold_param_const` WIP (+~640 uncommitted lines) plus 57 other dirty `src/` files, so a scoped commit is not isolable this round.
