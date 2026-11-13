# ATTRIBUTION: the red cell is the UNCOMMITTED `fold_param_const`, sitting on top of a live classifier bug

Type: shared-analysis BUG in an existing pass (`src/transforms/copy_propagation.rs`,
`classify_builtin_writes`). No new node, no contract change, no transform offer.

Requested by: perl backend worker (`backends/perl`, branch `backend/perl`).
12th file in the chain (`perl-20261023-*`, `perl-20261024-032941 / 052500 / 071410 /
073500 / 100429 / 112200 / 122935 / 125504 / 142109 / 145956 / 152200`,
`c-20261023-210500`, `c-20261024-150200`, `c-20261024-160500-unset-flag-heuristic`).

**Why another file.** Every prior filing said "the fold does not respect `unset`"
and located the mechanism in the classifier. That is correct but it is only HALF
of what is happening, and the missing half decides whether this is a one-line
fix or a land-blocker for work that has not been committed yet. Measured below:
the classifier bug is long-standing and LIVE IN COMMITTED CODE, but the `param`
fold that turns it into the perl/c gate's single red cell (`t70_unset.sh`) is
NEW, and exists only as an uncommitted edit in the main checkout
(`/mnt/wsl/projects/sh2loop/sh2perl`, branch `fm-wc-semantics2`, `2c0e035de` +
dirty working tree) — the tree the gate builds `otranspilerl-cli` from.

## NEED

The dashed-flag hoist in `classify_builtin_writes` (the 3 lines every filing
since `073500` carries). It must land BEFORE the uncommitted `fold_param_const`
reaches `main`, or that fold ships unsound.

## WHY — two layers, measured separately

### Layer 1 (committed, latent): a bare 1–2 letter NAME is dropped as a "flag"

Unchanged from the prior filings, and re-verified on a **clean export of
committed `fm-wc-semantics2`** (`git archive fm-wc-semantics2`), so this is not
a dirty-tree artifact:

```
x=5; unset x; echo "$x"          -> echo arg = Str("5")      WRONG (bash: empty)
x=1; read x;  echo "$x"          -> echo arg = Str("1")      WRONG
x=5; unset x; echo "${x:-gone}"  -> param(":-","x","gone")   correct
```

So committed `main` already propagates a value across `unset`/`read` for bare
reads — it just has no `param` fold, so `${x:-…}` escapes. No corpus file
exercises the plain-read form with a 1–2 char name, which is why this has never
been a gate cell on committed code.

### Layer 2 (dirty working tree, what the gate actually runs): the new `param` fold

`git diff` of the main checkout's `src/transforms/copy_propagation.rs` (vs
`fm-wc-semantics2`) adds a whole `param-const-fold` section: `fold_expr`'s
`IrExpr::Call` arm now calls `fold_param_const(args, resolved, foldable)` for
`func == "param"`. That consultation of `resolved` is what reaches the unset
variable through the Layer-1 hole and folds `${x:-gone}` to `Str("5")`.

Ablation on the gate's own binary (`otranspilerl/target/debug/otranspilerl-cli`,
`--target shir .../t70_unset.sh`, transform gate is runtime-only — no rebuild):

```
all transforms (default)        -> 5        (Str)
SH2_TRANSFORMS=copy-propagation -> 5        (the pass alone reproduces it)
all transforms EXCEPT copy-propagation -> param(":-","x","gone")   correct
```

And the same file through a clean export of committed `fm-wc-semantics2`
(built in /tmp, right tree untouched): `param` — correct. The committed core
cannot produce this cell; the dirty tree does.

## MINIMAL-CORE-CHANGE

The hunk every filing carries; it applies verbatim to BOTH the committed file
and the dirty working copy (no fuzz needed):

```rust
for a in args {
    if let IrExpr::Str(s, _) = a {
        let dashed = s.starts_with('-');
        let s = s.trim_start_matches('-');
        if s.is_empty() || (dashed && s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) {
            continue; // a flag like -i/-r/-x/-a/-A/-l/-u/-n/-g/-t/-p/-f/-F
        }
```

It only ever REFUSES a fold, so it cannot introduce a node or make a renderer
emit code it could not emit before: the worst case is the plain `getVar`/`param`
node every renderer already handles.

Blast radius, measured by diffing `--target shir` for all 650 corpus files,
identical sources, one line different:

| core built from | changed files | verdict |
|---|---|---|
| committed `fm-wc-semantics2` | 1: `t45_env_set.sh` (`export X` → keeps `getVar("X")`) | conservative, still green |
| main checkout (dirty) | 2: `t45_env_set.sh` + `t70_unset.sh` (`param` survives → perl prints `gone`) | the fix |

## FAILING-CASE

```
$ bash sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh
gone
$ otranspilerl-cli --target shir .../t70_unset.sh \
    | sh2perl/backends/perl/target/debug/shir_render --target=perl - | perl
5
# bash prints "gone"
```

Perl gate replica (`.gate_replica.sh`, worktree renderer, 650 files):

```
unpatched core  -> OK=641 FAIL=2  (046_cd..sh t70_unset.sh)
patched   core  -> OK=642 FAIL=1  (046_cd..sh)      # t70 flips, nothing else moves
```

`046_cd..sh` is a known replica artifact (a `cd ..; ls` cell that lists the
workspace); it fails both ways and is not a fold cell.

The perl worktree has no other pending defect: `harness/backend_runtime_metric.sh
perl` reports `calls 0` over 562 renders (a hand count of
`__sh_[A-Za-z_0-9]+[[:space:]]*\(` over the same corpus agrees: 0 call sites,
0 emitted helper subs), and its one red cell is this fold.

## ASK

1. Apply the hoist (one line + the hoisted `dashed` binding) to
   `src/transforms/copy_propagation.rs`; the chain of 14 filings closes.
2. Land it BEFORE the uncommitted `param-const-fold` edit reaches `main` — the
   measurements above are the case that the new fold is otherwise unsound for
   `unset NAME` / `read NAME`.

## OUTCOME: implemented

Landed in `sh2perl/src/transforms/copy_propagation.rs::classify_builtin_writes`: a word is treated as a command-line flag only when it actually carried a leading `-`, so a bare 1-2 letter NAME (`unset x`, `read ab`, `local n`) is recorded as a write and copy-propagation refuses the stale fold. Pinned by unit tests `unset_invalidates_single_def`, `read_invalidates_single_def`, `dashed_flag_is_still_skipped`, `folds_without_unset`.

Verification: `./fail-estree` -> PERL 562/562 passed, ESTREE 561/562. The single estree failure (`grep_p.sh`, "non-sh2 callee: min") reproduces identically with `SH2_TRANSFORMS=none` and the file contains no store-writing builtin, so it is pre-existing/WIP and unrelated. `cargo test --lib`: the 27 failures are identical before and after this hunk (pre-existing WIP); the 4 new tests pass.

Note: the fix landed in the live working tree, which is the tree `setup_backends.sh` and all gates build `otranspilerl-cli` from. The same file carries the in-flight `fold_param_const` WIP (+~640 uncommitted lines) plus 57 other dirty `src/` files, so a scoped commit is not isolable this round.
