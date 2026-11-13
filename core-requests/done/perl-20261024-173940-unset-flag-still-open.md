# The perl gate's ONLY red cell is still the `unset` flag heuristic — 15th filing, re-verified 2026-10-24T17:39Z

Type: shared-analysis BUG in an existing pass (`src/transforms/copy_propagation.rs`,
`classify_builtin_writes`). No new node, no contract change, no transform offer.

Requested by: perl backend worker (`backends/perl`, branch `backend/perl`).

**STATUS, so this file is not read as a new defect.** This is the same item filed as
`perl-20261024-032941`, `052500`, `071410`, `073500-unset-const-fold`,
`091741`, `100429`, `112200`, `122935`, `125504`, `142109`, `145956`, `152200`,
`163647-unset-attribution` and `c-20261023-210500` / `c-20261024-150200` /
`c-20261024-160500-unset-flag-heuristic`. Nothing about the diagnosis or the hunk
changed — I re-measured it on today's tree because the loop gate re-entered this
worktree and the item is still open. If you apply the 3-line hunk below, all of
these close together. If you have already decided NOT to fix it, say so on the
chain and I will stop re-filing; a silent queue is indistinguishable from a lost
one from inside a backend worktree.

## NEED

In `classify_builtin_writes` (`src/transforms/copy_propagation.rs:410`, inside the
function starting at `:388`), a word in a store-writing builtin's argument list is
dropped as a FLAG whenever the text left after `trim_start_matches('-')` is
all-alphabetic and ≤2 chars. The dash is stripped BEFORE that test, so a bare
1–2 letter VARIABLE NAME (`x`, `i`, `n`, `ab`) is indistinguishable from `-i`:
`unset x` records no write to `x`, so copy-propagation still believes the name
holds its single assigned literal.

## WHY

With the write invisible, `fold_expr` substitutes the stale literal into later
reads — including through `fold_param_const` (`:754`, `:1044`), whose `(":-", 3)`
arm folds `${x:-WORD}` to the dead value.

The exported A1 has ALREADY lost the expansion, so no renderer can repair it:

```
$ otranspilerl-cli --target shir .../t70_unset.sh | jq -c '.stmts[2].expr.args[1].elements[0]'
{"style":"DoubleQuoted","type":"Str","value":"5"}      # "gone" is not in the IR at all
```

Measured today on the gate's own emitter binary (no rebuild — `SH2_TRANSFORMS` is
runtime-only), same A1 → perl renderer:

```
default transforms                        -> prints 5      (folds across the unset)
all EXCEPT copy-propagation               -> prints gone   (correct)
bash                                      -> gone
```

Threshold is NAME LENGTH, not the construct (same three-line cause):

```
x=5;  unset x;   echo "${x:-gone}"   -> Str("5")        WRONG  (len 1)
ab=5; unset ab;  echo "${ab:-gone}"  -> Str("5")        WRONG  (len 2)
abc=5;unset abc; echo "${abc:-gone}" -> param(":-",…)   correct (len 3)
```

The same hole swallows `read n`, `mapfile -t a`, `local x`, `declare -i x`,
`export X` (bare name without a leading dash).

**The live tree matters here.** The `param` fold itself is still an UNCOMMITTED
edit in the main checkout (`sh2perl`, branch `fm-wc-semantics2`, `2c0e035de` +
dirty: `src/transforms/copy_propagation.rs` +641 lines, `src/ir.rs` +232), and that
dirty tree is what `setup_backends.sh` builds `otranspilerl-cli` from. So the
classifier hunk must land in THAT working copy (it applies verbatim) — patching
only the committed branch leaves the gate red.

## MINIMAL-CORE-CHANGE

One hoisted boolean at `src/transforms/copy_propagation.rs:410`:

```diff
     ) {
         for a in args {
             if let IrExpr::Str(s, _) = a {
+                let dashed = s.starts_with('-');
                 let s = s.trim_start_matches('-');
-                if s.is_empty() || (s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) {
+                if s.is_empty() || (dashed && s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) {
                     continue; // a flag like -i/-r/-x/-a/-A/-l/-u/-n/-g/-t/-p/-f/-F
                 }
```

- `--long-opt` still strips to `""` → `s.is_empty()` → still skipped.
- `-i`/`-r`/`-x`/`-v` still skipped (`dashed && len ≤ 2 && alphabetic`).
- The change can only ever REFUSE a fold, never introduce a node: the worst case
  is a plain `getVar`/`param` node, which every renderer already renders.

Previously verified (not reasoned about) on a scratch copy, perl gate mirror over
the 650-file corpus: `OK=641 FAIL=2` → `OK=642 FAIL=1`, i.e. `t70_unset.sh` flips
and nothing else moves. Whole-corpus `--target shir` diff, identical sources:
committed core 1 file (`t45_env_set.sh`, conservative), dirty core 2
(`t45_env_set.sh` + `t70_unset.sh`).

## FAILING-CASE

`sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh`

```sh
x=5
unset x
echo "${x:-gone}"
```

bash prints `gone`; the perl renderer prints `5`:

```perl
my $x;
$x = "5";
undef $x;
print (join(' ', "5") . "\n");     # the "gone" branch was folded away upstream
```

Perl gate state on this worktree, today (`harness/perl_gate_local.sh -v`, worktree
`shir_render --target=perl`, 650 corpus files):

```
649/650 render OK, 1 fail (0 stubs, 0 check_qx, 0 render-fail, 1 equiv), 7 skip
fails: t70_unset.sh
```

`t70_unset.sh` is the ONLY red cell; the loop gate reports the same single file.
The renderer is not the defect (with the fold disabled the same file renders
`((($x // "") ne "") ? $x : "gone")` → `gone`).

The perl worktree has nothing else pending: `harness/backend_runtime_metric.sh perl`
reports `calls 0` / `total 1109` over 562 renders — I re-decomposed every
`__sh_*` token in the 650-file corpus myself: 1062 × `__sh_st`, 41 × `__sh_ls0`,
30 × `__sh_bg`, 8 × fd lexicals, 2 × `__sh_eh0`, and **0 call sites**
(`grep -cE '__sh_[A-Za-z_0-9]+[[:space:]]*\('`). They are the renderer's `$?`
model lexicals, not runtime entry points, so that number cannot be lowered
without changing the status model — it is not a delegation backlog.

## OUTCOME: implemented

Landed in `sh2perl/src/transforms/copy_propagation.rs::classify_builtin_writes`: a word is treated as a command-line flag only when it actually carried a leading `-`, so a bare 1-2 letter NAME (`unset x`, `read ab`, `local n`) is recorded as a write and copy-propagation refuses the stale fold. Pinned by unit tests `unset_invalidates_single_def`, `read_invalidates_single_def`, `dashed_flag_is_still_skipped`, `folds_without_unset`.

Verification: `./fail-estree` -> PERL 562/562 passed, ESTREE 561/562. The single estree failure (`grep_p.sh`, "non-sh2 callee: min") reproduces identically with `SH2_TRANSFORMS=none` and the file contains no store-writing builtin, so it is pre-existing/WIP and unrelated. `cargo test --lib`: the 27 failures are identical before and after this hunk (pre-existing WIP); the 4 new tests pass.

Note: the fix landed in the live working tree, which is the tree `setup_backends.sh` and all gates build `otranspilerl-cli` from. The same file carries the in-flight `fold_param_const` WIP (+~640 uncommitted lines) plus 57 other dirty `src/` files, so a scoped commit is not isolable this round.
