# core: `sh2perl` at HEAD does not build — `ParameterExpansionOperator::UseAlternative` is uncommitted

## NEED
Commit the `UseAlternative` variant so a clean checkout of `sh2perl` builds.
This is not a request to add anything; the code exists and works, it is
simply **not in any commit**, so `main` only compiles by accident.

## FAILING-CASE
    $ git -C sh2perl worktree add /tmp/wt 6d46578dd      # HEAD of main
    $ cd /tmp/wt && CARGO_TARGET_DIR=/tmp/t cargo build --lib
    error[E0599]: no variant or associated item named `UseAlternative`
                 found for enum `ast_words::ParameterExpansionOperator`
      --> src/shir.rs:18202:60
    error: could not compile `debashl` (lib) due to 1 previous error

The identical error reproduces on a pristine baseline worktree, so it is
pre-existing and not caused by any recent change.

## EVIDENCE

`src/shir.rs` (committed, last touched by `7c7c01d27`) references the
variant at :18202:

    ParameterExpansionOperator::UseAlternative(w, need_nonempty) => (

but the variant exists only in an **uncommitted** working-tree edit:

    $ git -C sh2perl log --all --oneline -S UseAlternative -- src/ast_words.rs
    (empty — present in NO commit on ANY branch)
    $ git -C sh2perl status --short src/ast_words.rs
     M src/ast_words.rs
    $ git -C sh2perl rev-parse --short HEAD
    6d46578dd

`git stash list` shows the same work was stashed and popped at least once
(`stash@{1}` is a `backend/zsh` stash that contains `ast_words.rs`), i.e. it
has already survived one near-loss.

**Why main appears to build right now:** the *working tree* has the file, so
`cargo build` in `sh2perl/` succeeds. Every worktree, CI run, and fresh
clone fails. Measured directly:

    # main working tree      -> Finished `dev` profile   (uses the uncommitted file)
    # pristine worktree @HEAD -> error[E0599] UseAlternative

## IMPACT
Any consumer that builds `sh2perl` from a committed state — every backend
worktree created by `setup_backends.sh`, `fail-estree`, CI — cannot
compile. It also means `run_core_worker.sh`'s revert guard treats the
uncommitted `src/*.rs` as unauthorized divergence, which is how this class
of work gets destroyed mid-flight.

## NOTE FOR WHOEVER PICKS THIS UP
There are **6 uncommitted `src/` files** right now (`ast_words.rs`,
`ir.rs`, `java_backend.rs`, `parser/words.rs`, `rust_backend.rs`,
`transforms/shir_native_stmt.rs`). They may be one coherent piece of work
or several workers' overlapping edits. Do not commit them as a batch
without building: commit at least the `ast_words.rs` half first so HEAD
compiles, then the rest one at a time. Check `git diff` per file.