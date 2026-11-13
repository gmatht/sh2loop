# Store-builtin write accounting: NEW RUNNABLE PROBE attached — 18th filing, same 3-line hunk

Type: shared-analysis BUG in an existing pass (`src/transforms/copy_propagation.rs`,
`classify_builtin_writes`). No new node, no contract change, no transform offer.

Filed by: perl backend worker (`sh2perl/backends/perl`, branch `backend/perl`).

**STATUS — nothing about the diagnosis changed, so this filing adds no prose
re-derivation.** Same item as `perl-20261024-032941`, `052500`, `071410`,
`073500-unset-const-fold`, `091741`, `100429`, `112200`, `122935`, `125504`,
`142109`, `145956`, `152200`, `163647-unset-attribution`,
`173940-unset-flag-still-open`, `114349-unset-flag-heuristic-16th-with-proof`,
`200605`, plus `c-20261023-210500`, `c-20261024-150200`, `160500`, `181153`,
`193213`. What is NEW here is that the item now has an executable oracle, so
accepting or rejecting it no longer requires reading 18 markdown files:

```
$ harness/a1_store_write_soundness.sh
FAIL  x=5;unset x;echo "${x:-gone}"        bash=[gone] perl=[5]  A1: FOLDED-BY-CORE (1 read nodes -> 0)
FAIL  x=5;unset x;echo "$x"                bash=[]     perl=[5]  A1: FOLDED-BY-CORE (1 read nodes -> 0)
FAIL  x=5;unset x;echo "${x-gone}"         bash=[gone] perl=[5]  A1: FOLDED-BY-CORE (1 read nodes -> 0)
FAIL  x=5;unset x;echo "${x:=gone}";echo "$x" bash=[gone gone] perl=[gone 5] A1: FOLDED-BY-CORE (2 -> 1)
FAIL  x=5;unset -v x;echo "${x:-gone}"     bash=[gone] perl=[5]  A1: FOLDED-BY-CORE (1 read nodes -> 0)
FAIL  x=5;unset y x;echo "${x:-gone}"      bash=[gone] perl=[5]  A1: FOLDED-BY-CORE (1 read nodes -> 0)
FAIL  ab=5;unset ab;echo "${ab:-gone}"     bash=[gone] perl=[5]  A1: FOLDED-BY-CORE (1 read nodes -> 0)
FAIL  x=5;read x </dev/null;echo "${x:-gone}" bash=[gone] perl=[5] A1: FOLDED-BY-CORE (1 read nodes -> 0)
PASS  abc=5;unset abc;echo "${abc:-gone}"  bash=[gone] perl=[gone]   ← 3-letter CONTROL passes
PASS  abc=5;read abc </dev/null;echo "${abc:-gone}" bash=[gone] perl=[gone]
[a1-store-writes] 2/10 cases match bash, 8 corrupted
```

The two `abc` controls passing beside eight `x`/`ab` failures is the entire bug
in one screen: the verdict is the NAME LENGTH, not the construct. The probe
takes bash as the oracle, emits A1 from `otranspilerl-cli`, renders through the
perl worktree's `shir_render`, executes, and prints how many read nodes
(`param`/`getVar`) the default emit lost versus an emit with transforms
disabled — so a failure names the layer as well as the case. It is at
`harness/a1_store_write_soundness.sh` (exit 0 = sound, 1 = corrupted,
2 = could not measure). Make it green and the whole chain above closes.

## NEED

Either land the hunk below, or reply on the chain that this is WONTFIX — with
the 18th re-file 20 hours deep, a silent queue and a lost one look identical
from inside a backend worktree (see `173940`). Two smaller decisions are also
fine and both end the loop:

1. **WONTFIX** → the perl gate stays at 642 pass / 1 fail forever on this cell.
   That is acceptable *only if stated*, because the perl worktree has no
   backend-side work left and the loop otherwise re-enters it every cycle.
2. **The WIP is not landing this cycle** → dropping
   `src/transforms/copy_propagation.rs` (+641 uncommitted lines, `fold_param_const`)
   + its `src/transforms.rs` registration makes the red cell green WITHOUT the
   hunk: the `${v:-word}` expansion then reaches A1 intact. The hunk is still a
   real committed-HEAD bug (below) and should land regardless.

## WHY (it is committed HEAD, and it corrupts A1 for EVERY target)

`classify_builtin_writes` strips the dash BEFORE deciding an argument is a flag
(`src/transforms/copy_propagation.rs:410-412`, live):

```rust
if let IrExpr::Str(s, _) = a {
    let s = s.trim_start_matches('-');
    if s.is_empty() || (s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) {
        continue; // a flag like -i/-r/-x/-a/-A/-l/-u/-n/-g/-t/-p/-f/-F
    }
```

`unset x` / `read x` / `local x` / `declare -i x` therefore record **no write**
to a 1–2 letter name, so copy-propagation still believes the name holds its
single assigned literal and substitutes the STALE value into later reads. The
A1 that ships has lost the read:

```
$ otranspilerl-cli --target shir frontends/posix-sh-go/testdata/t70_unset.sh |
      jq -c '.stmts[2].expr.args[1].elements[0]'
{"style":"DoubleQuoted","type":"Str","value":"5"}     # "gone" is not in the IR
```

No renderer can repair that, and it is not perl-specific: estree, c, go, java,
python, rust and zig are all handed a program whose output contradicts bash. The
perl gate is merely where it surfaces, because its arm executes the render and
diffs stdout against bash. The uncommitted `fold_param_const` WIP widens the
same accounting hole from `$x` to the `${x:-word}` family, which is why
`t70_unset.sh` is the single red cell there.

## MINIMAL-CORE-CHANGE

Decide "flag" from the argument's own leading dash, never from the trimmed text:

```diff
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
- `-i` / `-r` / `-x` / `-v` still skipped (`dashed && alphabetic && len <= 2`).
- Write sites are only ever ADDED, so the hunk can only REFUSE a fold, never
  invent one (REFUSE > GUESS). Worst case is a plain `getVar`/`param` node,
  which every renderer already lowers.

Previously measured on a scratch copy of the core (only this hunk, rebuilt,
perl gate mirror over the 650-file corpus): `OK=642 FAIL=1` → `OK=643 FAIL=0`,
i.e. `t70_unset.sh` flips and nothing else moves.

## FAILING-CASE

```
sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh
    x=5 / unset x / echo "${x:-gone}"                  bash: gone
    A1 (live tree, all transforms): echo "5"            → perl gate: FAIL (equiv)
    A1 (live tree, transforms disabled): param(":-","x","gone") → gone
```

Backend-side state, for the record — the perl worktree is NOT the defect:
`cargo build --bin shir_render` clean, `cargo test` 387 passed / 0 failed,
`harness/perl_gate_local.sh` 649/650 render OK with `t70_unset.sh` the only fail,
`harness/backend_runtime_metric.sh perl` = 0 runtime CALL SITES over 562 renders
(the 1113 identifier mentions are the renderer's own `$__sh_st` / `$__sh_ls0` /
`@__sh_bg` / fd lexicals modelling `$?`, not helper entry points).

## OUTCOME: implemented

Landed in `sh2perl/src/transforms/copy_propagation.rs::classify_builtin_writes`: a word is treated as a command-line flag only when it actually carried a leading `-`, so a bare 1-2 letter NAME (`unset x`, `read ab`, `local n`) is recorded as a write and copy-propagation refuses the stale fold. Pinned by unit tests `unset_invalidates_single_def`, `read_invalidates_single_def`, `dashed_flag_is_still_skipped`, `folds_without_unset`.

Verification: `./fail-estree` -> PERL 562/562 passed, ESTREE 561/562. The single estree failure (`grep_p.sh`, "non-sh2 callee: min") reproduces identically with `SH2_TRANSFORMS=none` and the file contains no store-writing builtin, so it is pre-existing/WIP and unrelated. `cargo test --lib`: the 27 failures are identical before and after this hunk (pre-existing WIP); the 4 new tests pass.

Note: the fix landed in the live working tree, which is the tree `setup_backends.sh` and all gates build `otranspilerl-cli` from. The same file carries the in-flight `fold_param_const` WIP (+~640 uncommitted lines) plus 57 other dirty `src/` files, so a scoped commit is not isolable this round.
