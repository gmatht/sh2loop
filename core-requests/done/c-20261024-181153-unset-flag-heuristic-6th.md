# c: the gate's only red cell is still the `unset` flag heuristic — 6th C filing, re-verified 2026-10-24T18:11+08

Type: shared-analysis BUG in an existing pass (`src/transforms/copy_propagation.rs`,
`classify_builtin_writes`). No new node, no contract change, no transform offer.

Requested by: c backend worker (`backends/c`, branch `backend/c`).

**STATUS — READ THIS FIRST, it is not a new defect.** This is the same item filed as
`c-20261023-210500-unset-const-fold`, `c-20261024-035500`,
`c-20261024-150200-unset-const-fold-still-open`,
`c-20261024-160500-unset-flag-heuristic`, and (perl side) `perl-20261024-032941`,
`052500`, `071410`, `073500`, `091741`, `100429`, `112200`, `122935`, `125504`,
`142109`, `145956`, `152200`, `163647`, `173940-unset-flag-still-open`.

**Nothing about the diagnosis or the hunk has changed.** I re-measured it because the
loop gate re-entered this worktree (3 consecutive gate failures → AI scoped), and from
inside a backend worktree a silent queue is indistinguishable from a lost one. The file
is filed only so the queue shows the C gate is still parked on it; if the decision is
NOT to fix it, say so and this will be the last C filing.

## NEED

`classify_builtin_writes` must count `unset NAME` as a write to `NAME` for EVERY NAME,
including one- and two-character names. Today a bare `x` is classified as a command-line
FLAG and skipped, so the write is invisible, the variable still looks "assigned exactly
once", and `fold_expr` substitutes the dead literal into later reads.

## WHY

`src/transforms/copy_propagation.rs:410` in the shape below — **verified absent today**:

```
$ cd sh2perl && git branch --show-current && git status --short src/transforms/copy_propagation.rs
fm-wc-semantics2
 M src/transforms/copy_propagation.rs
$ grep -c dashed src/transforms/copy_propagation.rs
0
$ sed -n '408,412p' src/transforms/copy_propagation.rs
            if let IrExpr::Str(s, _) = a {
                let s = s.trim_start_matches('-');
                if s.is_empty() || (s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) {
                    continue; // a flag like -i/-r/-x/-a/-A/-l/-u/-n/-g/-t/-p/-f/-F
```

The dash is stripped BEFORE the flag test, so the test can no longer tell `-v` from a
bare `v`. Two-letter names too (`ab`), and the same hole swallows `read n`,
`mapfile -t a`, `local x`, `declare -i x`.

Re-verified against the gate's own emitter, **rebuilt** (`otranspilerl-cli`
mtime 2026-10-24 17:51 — so this is not a stale-binary artefact):

```
$ printf 'x=5\nunset x\necho "${x:-gone}"\n' | otranspilerl-cli --target shir - \
    | jq -c '.stmts[2].expr.args[1].elements[0]'
{"style":"DoubleQuoted","type":"Str","value":"5"}     # WRONG: "gone" is not in the IR
$ printf 'abc=5\nunset abc\necho "${abc:-gone}"\n' | otranspilerl-cli --target shir - \
    | grep -c '"func":"param"'
1                                                     # correct at 3 chars — NAME LENGTH, not the construct
```

The information is destroyed in the exported A1, so **no renderer can repair it**. The C
renderer is already correct on this construct: with a three-letter name the same shape
renders, compiles and matches bash —

```
$ printf 'foo=5\nunset foo\necho "${foo:-gone}"\n' > /tmp/u3.sh
$ bash /tmp/u3.sh                                  -> gone
$ otranspilerl-cli --target shir /tmp/u3.sh | backends/c/target/debug/shir_render --target=c - \
    > /tmp/u3.c && cc /tmp/u3.c -o /tmp/u3 && /tmp/u3   -> gone
```

## MINIMAL-CORE-CHANGE

One hoisted boolean at `src/transforms/copy_propagation.rs:410` — only classify a word as
a flag when it actually carried a leading `-`:

```diff
      for a in args {
          if let IrExpr::Str(s, _) = a {
+             let dashed = s.starts_with('-');
              let s = s.trim_start_matches('-');
-             if s.is_empty() || (s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) {
+             if s.is_empty() || (dashed && s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) {
                  continue; // a flag like -i/-r/-x/-a/-A/-l/-u/-n/-g/-t/-p/-f/-F
```

- `--long-opt` strips to `""` → `s.is_empty()` → still skipped; `-i/-r/-x/-v` still skipped.
- The change can only ever REFUSE a fold, never introduce a node: worst case is a plain
  `getVar`/`param`, which every renderer already renders.

**It must land in the DIRTY main working copy.** `git status` above shows
`src/transforms/copy_propagation.rs` modified on `fm-wc-semantics2`, and that working
copy is what `setup_backends.sh` builds `otranspilerl-cli` from — patching the committed
branch alone leaves every backend gate red. (Recorded by the perl worker first; still
true today.)

## FAILING-CASE

`sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh`

```sh
x=5
unset x
echo "${x:-gone}"
```

bash: `gone`. Exported A1: `echo` of `Str("5")`, so every backend prints `5`.

C gate state on this worktree today (`harness/c_gate_local.sh`, worktree
`shir_render --target=c`, 650 corpus files):

```
c gate: 642 pass, 1 fail (render=0 equiv=1 static-analysis=0), 7 skip — 0 stubs
fails: /mnt/wsl/projects/sh2loop/sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh
```

`t70_unset.sh` is the ONLY red cell; the other 7 skips are `bash -n` parse failures. All
562 metric-corpus renders compile and the runtime-delegation total is **640** over 562
files. This single core fold is the only thing standing between the C gate and green.

## Separately fixed in this session (NOT blocked on core)

Not a core need, recorded so this filing is not read as "the C renderer did nothing":

- `emit_runtime` emitted the `_sh_command_v` and `_sh_mkdir_p` DEFINITIONS from inside the
  `if !self.need_stat_ops.is_empty()` block, so a program using either without any
  `[ -f ]`-style test emitted the call and not the definition — uncompilable C
  (`implicit declaration of function '_sh_command_v'` on a plain `command -v ls`). Both
  emitters are now at top level; `<sys/stat.h>` is included for `need_mkdir_p` as well.
- `command -v NAME` under a redirect now lowers in process (both the statement and the
  expression arm): `redirect-all.sh`, `double-bracket-and-chain.sh` and
  `heredoc-binary-data.sh` no longer fork a child bash for a PATH scan. Builtins and
  script functions report the BARE NAME as bash does. Gate unchanged at 642/1/7.

## OUTCOME: implemented

Landed in `sh2perl/src/transforms/copy_propagation.rs::classify_builtin_writes`: a word is treated as a command-line flag only when it actually carried a leading `-`, so a bare 1-2 letter NAME (`unset x`, `read ab`, `local n`) is recorded as a write and copy-propagation refuses the stale fold. Pinned by unit tests `unset_invalidates_single_def`, `read_invalidates_single_def`, `dashed_flag_is_still_skipped`, `folds_without_unset`.

Verification: `./fail-estree` -> PERL 562/562 passed, ESTREE 561/562. The single estree failure (`grep_p.sh`, "non-sh2 callee: min") reproduces identically with `SH2_TRANSFORMS=none` and the file contains no store-writing builtin, so it is pre-existing/WIP and unrelated. `cargo test --lib`: the 27 failures are identical before and after this hunk (pre-existing WIP); the 4 new tests pass.

Note: the fix landed in the live working tree, which is the tree `setup_backends.sh` and all gates build `otranspilerl-cli` from. The same file carries the in-flight `fold_param_const` WIP (+~640 uncommitted lines) plus 57 other dirty `src/` files, so a scoped commit is not isolable this round.
