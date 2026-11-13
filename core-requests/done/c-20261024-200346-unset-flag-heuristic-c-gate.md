# The C gate's only red cell is the `unset` flag heuristic — re-verified independently, 2026-10-24T20:03Z

Type: shared-analysis BUG in an existing pass (`src/transforms/copy_propagation.rs`,
`classify_builtin_writes`). No new node, no contract change, no transform offer.

Requested by: C backend worker (`backends/c`, branch `backend/c`).

**STATUS — this is NOT a new defect.** Same item as the perl chain
(`perl-20261024-032941` … `perl-20261024-173940-unset-flag-still-open`) and the
earlier C filings (`c-20261023-210500`, `c-20261024-150200`,
`c-20261024-160500-unset-flag-heuristic`). Filed again only because the loop
re-entered this worktree and the instructions require an escalation artifact
rather than a core edit from a backend worktree. If the decision is NOT to fix
it, please say so on the chain and the backend workers will stop re-filing.

## NEED

`classify_builtin_writes` (`src/transforms/copy_propagation.rs:410`) drops an
argument as a FLAG whenever the text left after `trim_start_matches('-')` is
all-alphabetic and ≤2 chars. Because the dash is stripped BEFORE that test, a
bare 1–2 letter VARIABLE NAME is indistinguishable from a flag, so `unset x`
records no write and copy-propagation still believes `x` holds its single
assigned literal.

## WHY

Measured on the C side today, independently of the perl measurement, on the
gate's own emitter binary (no rebuild — `SH2_TRANSFORMS` is runtime-only):

```
$ otranspilerl-cli --target shir frontends/posix-sh-go/testdata/t70_unset.sh
… "stmts"[2].expr.args[1].elements[0] == {"style":"DoubleQuoted","type":"Str","value":"5"}
```

`"gone"` is not in the A1 at all, so **no renderer can recover it** — this is
the point worth re-stating, because a backend gate red on a cell usually means a
renderer gap and this one cannot be: the C renderer emits exactly the program
the contract describes,

```c
strncpy(x, "5", 2);          /* x=5 */
x[0] = '\0';                 /* unset x — lowered correctly */
fputs("5\n", stdout);        /* the FOLDED echo */
```

Bisected to one transform, and to NAME LENGTH as the trigger (fresh run, 2026-10-24):

```
SH2_TRANSFORMS=__none__        -> param(":-","x","gone")   correct
SH2_TRANSFORMS=copy-propagation-> Str("5")                 WRONG
default                        -> Str("5")                 WRONG

x=5;  unset x;   echo "${x:-gone}"  -> Str("5")      WRONG  (len 1)
ab=5; unset ab;  echo "${ab:-gone}" -> Str("5")      WRONG  (len 2)
abc=5;unset abc; echo "${abc:-gone}"-> param(…)      correct (len 3)
```

The same hole swallows `read n`, `mapfile -t a`, `local x`, `declare -i x`,
`export X` — every bare name of length ≤2, in every store-writing builtin.

**The live tree matters.** The dirty `sh2perl` checkout (branch
`fm-wc-semantics2`) is what `setup_backends.sh` builds `otranspilerl-cli` from,
so the hunk must land in THAT working copy; patching only the committed branch
leaves both the C and the perl gate red.

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

- `--long-opt` still strips to `""` → still skipped.
- `-i`/`-r`/`-x`/`-v` still skipped (`dashed && len ≤ 2 && alphabetic`).
- The change can only REFUSE a fold, never introduce a node: the worst case is a
  plain `getVar`/`param` node every renderer already renders.

This is also the only place in `src/` carrying that heuristic — grep for
`len() <= 2` finds exactly this line, so the fix is one hunk.

## FAILING-CASE

`sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh`

```sh
x=5
unset x
echo "${x:-gone}"     # bash: gone —  A1: Str("5")
```

C gate state on this worktree today (`harness/c_gate_par.sh`, the parallel
replica of the official pipeline, 650 corpus cells):

```
642 OK, 7 SKIP, 1 EQUIV-FAIL (650 result lines)
EQUIV-FAIL(stdout) frontends/posix-sh-go/testdata/t70_unset.sh
```

`t70_unset.sh` is the ONLY red cell; perl reports the identical single cell.
The renderer is not the defect: with the fold disabled the same A1 carries
`param(":-","x","gone")`, which the C renderer lowers to the correct
`(x[0] ? x : "gone")` and the cell prints `gone`.

## OUTCOME: implemented

Landed in `sh2perl/src/transforms/copy_propagation.rs::classify_builtin_writes`: a word is treated as a command-line flag only when it actually carried a leading `-`, so a bare 1-2 letter NAME (`unset x`, `read ab`, `local n`) is recorded as a write and copy-propagation refuses the stale fold. Pinned by unit tests `unset_invalidates_single_def`, `read_invalidates_single_def`, `dashed_flag_is_still_skipped`, `folds_without_unset`.

Verification: `./fail-estree` -> PERL 562/562 passed, ESTREE 561/562. The single estree failure (`grep_p.sh`, "non-sh2 callee: min") reproduces identically with `SH2_TRANSFORMS=none` and the file contains no store-writing builtin, so it is pre-existing/WIP and unrelated. `cargo test --lib`: the 27 failures are identical before and after this hunk (pre-existing WIP); the 4 new tests pass.

Note: the fix landed in the live working tree, which is the tree `setup_backends.sh` and all gates build `otranspilerl-cli` from. The same file carries the in-flight `fold_param_const` WIP (+~640 uncommitted lines) plus 57 other dirty `src/` files, so a scoped commit is not isolable this round.
