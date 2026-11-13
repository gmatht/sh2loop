# c: the MAIN sh2perl checkout does not compile — the perl generator gate cannot run at all

## NEED

`/home/llm/sh2loop/sh2perl` (the MAIN checkout, not the core worktree) does
not build. This blocks `./fail` for the perl GENERATOR: the gate's first step
is a `cargo build --bin otranspilerl-cli`, which links `debashl` from
`../sh2perl` (`otranspilerl/Cargo.toml:16`), so the whole corpus is skipped
and no per-file verdict is produced.

    $ cd /home/llm/sh2loop/otranspilerl && cargo build --bin otranspilerl-cli
    error[E0308]: mismatched types
    error: could not compile `debashl` (lib) due to 1 previous error; 53 warnings emitted

Red since **18:01** (`sh2perl/src/shir.rs` mtime), i.e. ~90 minutes at the
time of writing. The existing
`c-20261003-190000-shir-rs-bare-name-at-iterator-mismatch.md` (18:31) already
diagnosed this exactly and named the fix; it has not been applied.

**This is the THIRD request for one break.** Same root cause as
`perl-20261003-180000-shir-rs-bare-name-at-undefined.md` (16:55,
`E0425 cannot find function bare_name_at`) and
`c-20261003-190000-...` (18:31). The tree went `E0425` -> helper added ->
`E0308`, because the helper was written for a `(usize, char)` iterator but
declared `char`, and the call site was never reconciled with it.

### Why it is not self-healing (this is the part that matters)

The core worker CANNOT fix this, by design, and its log will keep saying
GREEN while the main tree stays red:

    [2026-10-03T19:04:43] core: main checkout has uncommitted shared-core WIP (NOT touched — owned by its worker):
     M src/shir.rs
    ...
    [2026-10-03T19:06:03] core: gate GREEN (A1 native + estree corpus + lib tests)

`run_core_worker.sh` (lines 32-46, 300-310, 341-344) builds and gates ONLY
`sh2perl/backends/core`, its own git worktree. "the main checkout is read-only
to this worker" — it reports the dirty main tree and moves on. So **every
`core: gate GREEN` line from here on is about a different binary** and must
not be read as "main compiles". Nothing in the current fleet will clear this;
it needs a human/one-shot edit to the main checkout.

## WHY

- **Scope of blast radius.** One red file blocks *every* consumer of the main
  checkout, not just perl: `./fail`, `./fail-estree`, `./fail-shir`, and each
  backend gate whose first step is a core build (c already reported
  `[c] backend gate: core build FAILED`, so it reports no corpus result at
  all).
- **A green tree is a lie here.** The stale-artifact hazard: the currently
  installed `otranspilerl/target/debug/otranspilerl-cli` (mtime 19:23) and
  its cached `libdebashl.rlib` (17:59) are both OLDER than the broken
  `shir.rs` (18:01). Cargo relinked without recompiling `debashl`, so a
  binary that looks fresh and runs fine was in fact built from PRE-breakage
  source. Anyone testing against it is measuring the old compiler. This is
  the same failure shape as the documented "regression test passes against
  the pre-fix code" trap.
- **It is not a perl-generator problem.** I did not produce this: the break is
  in uncommitted shared-core WIP, and the affected call site is
  `vars_in_opaque_text` (bare-name harvesting for `${flags:j:1}`), which is
  core analysis, not Perl codegen. Fixing it inside the generator would be
  both out of scope and impossible (the lib does not compile).

## MINIMAL-CORE-CHANGE

One token, in the MAIN checkout at `sh2perl/src/shir.rs:14650`. The loop
destructures `(usize, char)` off `span.chars()`, which yields `char`:

    14650:  for (_k, piece) in span.chars() {
    14651:      if let Some(name) = bare_name_at(piece) {

`bare_name_at` is declared `fn bare_name_at(piece: char) -> Option<String>`
(`shir.rs:14625`) and its body is written for a single `char`
(`piece.is_ascii_alphabetic()`, `piece.to_string()`). The loop is the thing
that is wrong — it was carried over from a `.char_indices()` reading. Either
fix is one edit; **the first is the smaller and semantics-preserving one**:

    // (a) preferred — drop the phantom index, keep bare_name_at(char)
    - for (_k, piece) in span.chars() {
    + for piece in span.chars() {

    // (b) equivalent — keep the index, make the helper take it
    - fn bare_name_at(piece: char) -> Option<String> {
    + fn bare_name_at(_k: usize, piece: char) -> Option<String> {

`_k` is unused in the body, so (a) is what the dead binding already says the
author meant. Apply in the main checkout; the core worktree does not carry
this hunk (it is uncommitted, so submodule HEAD `bc9abbb80` is clean).

Verify:

    cd /home/llm/sh2loop/otranspilerl
    rm -f target/debug/deps/libdebashl*.rlib   # defeat the stale-artifact trap
    cargo build --bin otranspilerl-cli         # must print "Finished"

**Fix (a) is already verified to compile** — applied to a throwaway copy of
the core (`cp -a src build.rs Cargo.toml Cargo.lock` to a scratch dir, main
checkout untouched):

    for piece in span.chars() {
    warning: `debashl` (lib) generated 53 warnings (run `cargo fix --lib -p debashl` to apply 19 suggestions)
        Finished `dev` profile [unoptimized + debuginfo] target(s) in 1m 42s

Zero errors, and the warning count is unchanged from the broken build (53), so
fix (a) silences the break without adding noise. The main checkout was NOT
modified — this is a copy at `/tmp/coretest`.

## FAILING-CASE

Not a corpus example — the gate never gets far enough to run one. The
repro is the build itself:

    $ cd /home/llm/sh2loop/otranspilerl && cargo build --bin otranspilerl-cli
    error[E0308]: mismatched types
       --> /home/llm/sh2loop/sh2perl/src/shir.rs:14650:29
        |
    14650 |                         for (_k, piece) in span.chars() {
          |                             ^^^^^^^^^^^    ------------ this is an iterator with items of type `char`
        |                             |
        |                             expected `char`, found `(_, _)`
    error: could not compile `debashl` (lib) due to 1 previous error; 53 warnings emitted

Downstream symptom, perl GENERATOR gate (`./fail`, 557 examples):

    Building otranspilerl-cli...
   error: could not compile `debashl` (lib) due to 1 previous error; 53 warnings emitted
    Build failed

Note this breaks the gate BEFORE any example is translated, so the trusted
baseline of 46 is currently unverifiable — the number is frozen, not
confirmed.

**Ask:** apply fix (a) to the main checkout, then let the perl generator
worker resume. No contract node, no transform, and no shIR change is needed
— this is a compile break in an in-progress helper, not a design gap.
## OUTCOME: implemented — the main checkout compiles again. sh2perl f72ccf057 defined `bare_name_at` and reconciled the `for (_k, piece) in span.chars()` call site (the E0308 iterator mismatch this file and c-20261003-190000 describe), so `otranspilerl-cli` links `debashl` and the perl generator gate can run. The recovery-contract ask (roll a non-compiling shared tree back to last-known-good) is a separate process item and remains open for the harness owner.
