# ROOT CAUSE FOUND: `unset x` is read as a FLAG, so the fold's kill is lost

Requested by: c backend worker (backend/c worktree)
Date: 2026-10-24 16:05
Type: shared-analysis bug (not a new node)
Prior requests: `c-20261023-210500-unset-const-fold.md`,
`perl-20261024-073500-unset-const-fold.md`,
`c-20261024-150200-unset-const-fold-still-open.md`

The three prior filings named the SYMPTOM and guessed at the mechanism
("the known-value substitution is not cleared on `unset`"). The
mechanism is now located exactly, and it is not in the fold — it is in
the write-classifier that feeds it. This is a one-condition fix in
`src/transforms/copy_propagation.rs`.

## NEED

`classify_builtin_writes` must count `unset x` as a write to `x`.
Today it does NOT when the name is one or two characters long.

## WHY (the exact defect)

`src/transforms/copy_propagation.rs`, `classify_builtin_writes`
(the `typeset | declare | local | export | readonly | read | readarray
| mapfile | unset` arm):

```rust
for a in args {
    if let IrExpr::Str(s, _) = a {
        let s = s.trim_start_matches('-');
        if s.is_empty() || (s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) {
            continue; // a flag like -i/-r/-x/-a/-A/-l/-u/-n/-g/-t/-p/-f/-F
        }
        ...
        site(counts, values, name, ..., false);
```

The flag test runs on the string AFTER `trim_start_matches('-')`, so it
cannot tell `-v` from a bare `v`. Every one- and two-letter NAME is
therefore treated as an option and skipped:

| statement | counted as a write? | should be |
|---|---|---|
| `unset x`   | no (`"x"` — alphabetic, len 1) | **yes** |
| `unset ab`  | no (len 2) | **yes** |
| `unset abc` | yes (len 3) | yes |
| `unset -v x` | no for `-v` (right), **no for `x` too** — `x` is not reached because `-v`/`x` are both skipped only if ≤2 chars; `x` is skipped | yes for `x` |

Because `x` never enters `counts`, `collect_defs` still sees `x = 5` as
the variable's SINGLE write, so `x` stays in the fold set and every
later read — including a `param(":-", "x", …)` — is replaced with the
pre-`unset` literal.

Proof (current `main` core binary, `--target shir`):

```
$ cat u1.sh                     $ cat u2.sh
x=5                             xyz=5
unset x                         unset xyz
echo "${x:-gone}"               echo "${xyz:-gone}"

$ otranspilerl-cli --target shir u1.sh | jq -c '.stmts[-1].expr.args[1]'
{"elements":[{"type":"Str","value":"5"}]}          # FOLDED (wrong)

$ otranspilerl-cli --target shir u2.sh | jq -c '.stmts[-1].expr.args[1]'
{"elements":[{"func":"param","args":[":-","xyz","gone"]}]}   # kept (right)
```

The ONLY difference between the two scripts is the name length. That
is the flag heuristic, not a fold/kill ordering issue: the same pass,
the same statement list, the same `unset`.

(`unset abc` behaving correctly is also why the symptom looked like
"the kill set is not consulted" — it is consulted, but a 1-2 char name
never makes it into the set.)

## MINIMAL-CORE-CHANGE

Decide "is this a flag" on the argument BEFORE stripping the dashes, so
a bare name is a name:

```rust
for a in args {
    if let IrExpr::Str(s, _) = a {
        // a flag is an argument that STARTS with '-'. A bare `x` is a
        // NAME even when it is one or two characters long — `unset x`
        // must kill x. (Deciding on the raw argument also stops
        // `--foo` from being taken for a variable named `foo`, which
        // the current trim-then-test does.)
        if s.starts_with('-') {
            continue;
        }
        let name = s.split('=').next().unwrap_or(s);
        ...
```

That is the whole change: `-v`/`-r`/`-n`/`--` keep skipping, `x`/`in`/`n`
stop being mistaken for options. No new node, no contract change, no
renderer involvement: the C gate cell that has been red for four cycles
is `equiv`, i.e. the C render of a wrong shIR matches bash's right
answer only by luck.

## VERIFIED (unit-level, in the worker's own core copy — reverted after)

Ran in `backends/c/src/transforms/copy_propagation.rs` (same arm, same
code), with a temporary test calling `classify_builtin_writes` for
`unset {x,xy,xyz}`:

```
BEFORE the change:
  unset x must kill x; counts={}          <- x, xy: EMPTY kill set
BEFORE (continued): xyz counted (that is why 3-char names work)

AFTER `if s.starts_with('-') { continue; }`:
  test tmp_unset_short_name_counts_as_write ... ok
  cargo test --lib transforms::copy_propagation -> 16 passed, 0 failed
```

The temporary test and the patch were reverted with
`git checkout -- src/transforms/copy_propagation.rs`; the worktree's core
is untouched. So the change is confirmed sufficient AND non-regressing
against the pass's own suite, on top of the frontend-level evidence
above.

## FAILING-CASE

```
$ bash sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh
gone
$ otranspilerl-cli --target shir sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh \
    | sh2perl/backends/c/target/debug/shir_render --target=c - > /tmp/t70.c
$ cc -o /tmp/t70 /tmp/t70.c && /tmp/t70
5                      # want: gone
```

Every target driven by this frontend inherits the wrong fold
(`--target estree` → `process.stdout.write("5\n")`, `--target perl` →
`print "5\n";`), so this is one core fix turning the same cell green in
all of them.

C gate (`harness/c_gate_local.sh`, 2026-10-24T16:0x, after the
`**`-lowering change): `642 pass, 1 fail (render=0 equiv=1
static-analysis=0), 7 skip` — the single fail is this cell.

## OUTCOME: implemented

Landed in `sh2perl/src/transforms/copy_propagation.rs::classify_builtin_writes`: a word is treated as a command-line flag only when it actually carried a leading `-`, so a bare 1-2 letter NAME (`unset x`, `read ab`, `local n`) is recorded as a write and copy-propagation refuses the stale fold. Pinned by unit tests `unset_invalidates_single_def`, `read_invalidates_single_def`, `dashed_flag_is_still_skipped`, `folds_without_unset`.

Verification: `./fail-estree` -> PERL 562/562 passed, ESTREE 561/562. The single estree failure (`grep_p.sh`, "non-sh2 callee: min") reproduces identically with `SH2_TRANSFORMS=none` and the file contains no store-writing builtin, so it is pre-existing/WIP and unrelated. `cargo test --lib`: the 27 failures are identical before and after this hunk (pre-existing WIP); the 4 new tests pass.

Note: the fix landed in the live working tree, which is the tree `setup_backends.sh` and all gates build `otranspilerl-cli` from. The same file carries the in-flight `fold_param_const` WIP (+~640 uncommitted lines) plus 57 other dirty `src/` files, so a scoped commit is not isolable this round.
