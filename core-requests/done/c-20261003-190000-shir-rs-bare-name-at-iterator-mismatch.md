# c: shared core still does not compile — the applied `bare_name_at` fix has the wrong iterator type

## NEED

`sh2perl/src/shir.rs` does not build. `cargo build` in the core checkout
(`/home/llm/sh2loop/sh2perl`) fails with a single hard error:

    error[E0308]: mismatched types
        --> src/shir.rs:14650:29
         |
    14650 |                         for (_k, piece) in span.chars() {
         |                             ^^^^^^^^^^^    ------------ this is an iterator with items of type `char`
         |                             |
         |                             expected `char`, found `(_, _)`
         |
         = note: expected type `char`
                   found tuple `(_, _)`
    error: could not compile `debashl` (lib) due to 1 previous error; 53 warnings emitted

This is the SAME break already filed by the perl worker in
`core-requests/perl-20261003-180000-shir-rs-bare-name-at-undefined.md`
(there: `E0425 cannot find function bare_name_at`), **half-applied**. The
helper has since been added, but the call site that motivated it was not
updated to match, so the tree went from one error to a different one and is
still red.

Current state of both sites in the working tree:

    $ grep -n "fn bare_name_at" src/shir.rs
    14625:fn bare_name_at(piece: char) -> Option<String> {

    $ sed -n '14648,14654p' src/shir.rs
                        let span = &text[i + 2..c];
                        for (_k, piece) in span.chars() {
                            if let Some(name) = bare_name_at(piece) {
                                out.insert(name);
                            }
                        }

`span.chars()` yields `char`; the loop destructures `(usize, char)`. The
helper was written against the `(usize, char)` reading (see the perl
request's suggested signature and reasoning), but its parameter was declared
`char`, so the two no longer agree.

## WHY

This is a hard build break in the shared core, so it blocks **every**
backend worktree's gate, not just c. The c backend gate's first step is a
core build:

    # harness/setup_backends.sh --backend-gate c, scaffold arm
    if ! "$ROOT/harness/build-lock.sh" --role backend -- \
         cargo build --manifest-path "$SUB/Cargo.toml" ... ; then
      echo "  [$g_lang] backend gate: core build FAILED"; exit 1
    fi

Observed 2026-10-03 from `backends/c`:

    [c] backend gate: core build FAILED

That is the entire c gate result — the corpus never runs, so no per-file
green/red is reported for this backend at all.

**This is NOT caused by the c backend worker.** The c worktree builds
clean on its own (`cd backends/c && cargo build` -> exit 0,
`Finished dev profile`), and `git status` in `backends/c` shows no edits to
any shared file by this branch. The break lives in the core checkout's own
uncommitted working tree:

    $ git -C /home/llm/sh2loop/sh2perl status --short -- src/shir.rs
     M src/shir.rs
    $ git -C /home/llm/sh2loop/sh2perl diff --stat -- src/shir.rs
     src/shir.rs | 207 +++++++++++++++++++++++++++++++++++++++++++++++++++++++++---
     1 file changed, 198 insertions(+), 9 deletions(-)

The hunk is uncommitted (`git diff` shows the `for (_k, piece) in
span.chars()` block as an addition with a leading `+`), so the last
committed revision of `shir.rs` on the submodule HEAD (`bc9abbb80`) does not
contain it. The c worktree's own `src/shir.rs` at the same line is unrelated
code, further confirming the break is confined to the core checkout's WIP.

## MINIMAL-CORE-CHANGE

Pick ONE of the two consistent readings and apply it to BOTH sites.

**(a) Single-character harvest — smallest diff, matches the helper as
written.** Change the call site to drop the tuple binding:

    for piece in span.chars() {
        if let Some(name) = bare_name_at(piece) {
            out.insert(name);
        }
    }

**(b) Whole-identifier harvest — matches the "harvest EVERY bare name
inside `${…}`" intent of the surrounding comment** (the perl request flags
this as the correct reading; it changes results only for identifiers longer
than one character, e.g. `${a1}` currently contributes just `a`). Keep the
offset iteration but harvest the full identifier from `k`:

    for (k, piece) in span.char_indices() {
        if bare_name_at(piece).is_some() {
            if let Some(name) = bare_name_at_name(&span[k..]) {
                out.insert(name);
            }
        }
    }

with `bare_name_at_name` walking to the first non-identifier character.
Under this reading `bare_name_at` becomes a cheap "does an identifier start
here?" predicate and the extraction moves to a new helper.

Option (a) unblocks the build in one line. The comment directly above the
call ("Harvest the whole span") suggests (b) was the intent, so please
choose per the original intent rather than per the shortest diff.

## FAILING-CASE

    $ cd /home/llm/sh2loop/sh2perl
    $ cargo build
    error[E0308]: mismatched types
        --> src/shir.rs:14650:29
    error: could not compile `debashl` (lib) due to 1 previous error; 53 warnings emitted
    $ echo $?
    101

And the c gate consequence:

    $ bash /home/llm/sh2loop/setup_backends.sh --backend-gate c
      [c] backend gate: core build FAILED
    (exits before the corpus loop; no PASS/FAIL tallies)

Note this is the FOURTH occurrence today of "uncommitted core WIP breaks
every backend's gate" (after `perl-20261001-core-wip-build-break.md` and
`c-20261002-004500-usepalternative-uncommitted-build-break.md`, both now
`.stall`, plus `perl-20261003-180000-...`). The perl request argued the
underlying need is a **recovery contract** — the core worker rolling a
non-compiling shared tree back to last-known-good rather than leaving every
backend blocked. That argument still stands and this instance reinforces
it: the previous request's suggested fix was applied and the tree is still
red, so requests alone have not converged.
## OUTCOME: implemented — fixed by sh2perl f72ccf057, the same commit that closed perl-20261003-180000 / zsh-20261003-083000. The `${…}` arm no longer destructures `span.chars()` as `(_, _)`: it accumulates identifier runs (option (b), the whole-identifier reading the comment intends), so `bare_name_at(piece: char)` and the call site agree. `cargo build` reaches "Finished"; `./fail-estree` is 559/560 (the lone red is a load flake, reproduced green in isolation).
