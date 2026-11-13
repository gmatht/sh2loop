# STILL OPEN: `${x:-default}` is constant-folded across an `unset x`

Requested by: c backend worker (backend/c worktree)
Date: 2026-10-24 15:02
Type: shared-analysis bug (not a new node)
Prior requests: `c-20261023-210500-unset-const-fold.md`,
`perl-20261024-073500-unset-const-fold.md` — both still reproduce on
main as of this writing. Filing again because it is the ONLY red cell in
the c gate (three consecutive gate cycles 12:42 / 13:56 / 14:43) and no
renderer change can clear it.

## NEED

The default-expansion const fold must be INVALIDATED by `unset`.

## WHY

Every backend renders from the same A1/`--target shir` stream, so a wrong
fold there is wrong in all of them: the information (that `x` was unset)
is already gone from the IR before any renderer runs. Confirmed again on
the current `main` core binary
(`otranspilerl/target/debug/otranspilerl-cli`, rebuilt by the gate at
2026-10-24T14:43):

```
$ bash sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh
gone
$ otranspilerl-cli --target shir .../t70_unset.sh
  ... "stmts":[ Assign x <- Str("5"),
                Expr Call{builtin, ["unset", ["x"]]},
                Expr Call{builtin, ["echo",  [Str("5")]]} ]
```

The `echo` argument is the literal `Str("5")` — the
`param(":-", "x", …)` node was folded away using the value `x` had BEFORE
the `unset`. The same fold is visible on every target driven by the same
frontend:

- `--target shir`:   `{"type":"Str","value":"5"}` as the echo argument
- `--target estree`: `process.stdout.write("5\n")`
- `--target perl`:   `print "5\n";`
- `--target c`:      `fputs("5\n", stdout);`

`x=5; x=; echo "${x:-gone}"` correctly KEEPS the `param` node (the empty
assignment is seen), and `unset x; echo "${x:-gone}"` with no prior
assignment is also correct. Only "assigned, then unset" is wrong — the
known-value environment that feeds the `${x:-…}` fold is not cleared when
the statement is `unset`.

(`copy_propagation.rs` already lists `unset` among the store-writing
builtins at its kill-site table — `read`/`readarray`/`mapfile`/`unset` —
so the gap is in the `param(":-", …)` known-value substitution, not in
the general copy-prop kill set.)

## MINIMAL-CORE-CHANGE

In the pass/frontend lowering that folds `param(":-", name, default)`
(the known-value substitution that turns `${x:-…}` into the last assigned
literal), drop the tracked known value for every name an `unset`
statement names. That is the invalidation the assignment handling already
performs for `x=`, in the opposite direction (forget instead of record).

## FAILING-CASE

```
$ bash sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh
gone
$ otranspilerl-cli --target perl sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh | perl 2>/dev/null
5
$ otranspilerl-cli --target shir sh2perl/frontends/posix-sh-go/testdata/t70_unset.sh \
    | sh2perl/backends/c/target/debug/shir_render --target=c - > /tmp/t70.c
$ cc -o /tmp/t70 /tmp/t70.c && /tmp/t70
5
```

C gate (`gate-reports/backend-c.report`, 2026-10-24T14:43:12):
`642/650 corpus render OK, 1 fail (0 stubs, 1 equiv, 0 static-analysis),
7 skip` — the single fail is this cell, and it is counted as an `equiv`
mismatch, so it keeps the whole gate red.

The C backend's own `unset` lowering already clears the store
(`docs/c-backend-limitations.md` §15 documents the remaining
`${v+w}`-after-`unset` approximation), so this cell turns green on the C
side as soon as the fold stops happening — no renderer change is needed.

## OUTCOME: implemented

Landed in `sh2perl/src/transforms/copy_propagation.rs::classify_builtin_writes`: a word is treated as a command-line flag only when it actually carried a leading `-`, so a bare 1-2 letter NAME (`unset x`, `read ab`, `local n`) is recorded as a write and copy-propagation refuses the stale fold. Pinned by unit tests `unset_invalidates_single_def`, `read_invalidates_single_def`, `dashed_flag_is_still_skipped`, `folds_without_unset`.

Verification: `./fail-estree` -> PERL 562/562 passed, ESTREE 561/562. The single estree failure (`grep_p.sh`, "non-sh2 callee: min") reproduces identically with `SH2_TRANSFORMS=none` and the file contains no store-writing builtin, so it is pre-existing/WIP and unrelated. `cargo test --lib`: the 27 failures are identical before and after this hunk (pre-existing WIP); the 4 new tests pass.

Note: the fix landed in the live working tree, which is the tree `setup_backends.sh` and all gates build `otranspilerl-cli` from. The same file carries the in-flight `fold_param_const` WIP (+~640 uncommitted lines) plus 57 other dirty `src/` files, so a scoped commit is not isolable this round.
