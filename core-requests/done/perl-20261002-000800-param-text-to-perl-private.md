# perl GENERATOR — `crate::ir::param_text_to_perl` is private, so the shared core does not build

**Filed by:** the perl GENERATOR worker (corpus-gate arm)
**When:** 2026-10-02 00:08 AWST
**Severity:** blocking — `debashl` (lib) does not compile, so
`cargo build --bin otranspilerl-cli` cannot produce a CLI and NO perl-generator
gate run (`./fail`, `harness/pg-case.sh`) can execute at all. The currently
installed binary predates the break and is used for repros meanwhile.

## NEED

Make `param_text_to_perl` reachable from outside the `ir` module. It is
currently a private item, and a transform in `src/transforms/` calls it
cross-module, which is `E0603`.

`sh2perl/src/ir.rs:8517`:

```rust
fn param_text_to_perl(tok: &str) -> Option<String> {   // <- private
```

`sh2perl/src/transforms/shir_native_stmt.rs` calls it at three sites
(1221, 1227, 1241), from the `-n`/`-z` parameter-expansion lowering:

```
error[E0603]: function `param_text_to_perl` is private
    --> sh2perl/src/transforms/shir_native_stmt.rs:1221:59
     |
1221 |     t.starts_with("${") && t.ends_with('}') && crate::ir::param_text_to_perl(t).is_some()
     |                                                           ^^^^^^^^^^^^^^^^^^ private function

note: the function `param_text_to_perl` is defined here
    --> sh2perl/src/ir.rs:8517:1
     |
8517 | fn param_text_to_perl(tok: &str) -> Option<String> {

error: could not compile `debashl` (lib) due to 3 previous errors
```

## WHY THIS IS FILED RATHER THAN FIXED

This is a **shared core** file (`src/ir.rs` is core-owned: `src/shir.rs`,
`src/ir.rs`, `src/estree.rs`, `src/parser/`, plus `src/transforms/`), and the
perl worker's scope is `sh2perl/src/perl_generator_fixed.rs` + `harness/`.

The breaking caller is itself **uncommitted WIP in the shared core checkout**
— `git status` in `sh2perl/` shows `src/transforms/shir_native_stmt.rs`
modified (76 insertions, 7 deletions, mtime `2026-10-01 23:28:28`), a
separate change from the one this request is about. So this is in-flight
core-owner work, and the correct escalation is this request.

Note the *pre-existing* precedent for the same shape: the core-requests
archive already holds `perl-20261001-core-wip-build-break` (a `shir.rs`
borrow error), filed for the same reason.

## MINIMAL-CORE-CHANGE

One keyword. Either form compiles:

```rust
pub fn param_text_to_perl(tok: &str) -> Option<String> {   // in src/ir.rs
```

or, if the intent is to keep the surface narrow and not expose the helper
across the whole crate, re-home the three call sites' logic behind a
`pub(crate) fn` (or a `pub fn` re-export on a `pub(crate)` item in `ir.rs`):

```rust
pub(crate) fn param_text_to_perl(tok: &str) -> Option<String> {
```

**Verification:** from `/home/llm/sh2loop/otranspilerl`,
`cargo build --bin otranspilerl-cli` must exit 0. The three `E0603`s are the
only errors; `src/ir.rs` currently carries 50 unrelated `debashl` warnings,
which are pre-existing and out of scope.

## IMPACT ON THE GENERATOR

`param_text_to_perl` is the shared renderer that turns a `${...}` parameter
expansion into its Perl form. It is what makes the `-n`/`-z` arms in
`shir_native_stmt.rs` evaluate the expansion's VALUE rather than embed its
TEXT (see the WIP comment on `variable-plus-operator.sh`). Until the core
builds, that fix cannot be gated, and the perl GENERATOR count stays pinned
at its trusted baseline of 44.

## OUTCOME: implemented (already landed before this round — verified, not re-landed)

The `pub(crate)` fix this request asks for IS in the tree, committed as sh2perl
`6faf07180` ("ir: make param_text_to_perl pub(crate) so the transforms channel
can call it"), with the parent gitlink bump `bbaa458f` already on master. I
verified rather than re-implemented:

* `src/ir.rs:8619` now reads `pub(crate) fn param_text_to_perl(tok: &str) ->
  Option<String>` — the narrowest surface that covers a cross-module caller,
  exactly as the request's "MINIMAL-CORE-CHANGE" section specified.
* `cargo build --lib` at committed HEAD succeeds (re-run this round on a fresh
  detached worktree: `Finished dev profile`, 0 errors), so the blocking
  "debashl does not compile, no CLI, no perl gate can run" condition is gone.
* `cargo test --lib` gives 1100 passed / 10 failed — identical to the A/B the
  landing commit recorded, so the visibility change is behaviour-neutral as
  claimed (it cannot alter emitted code).

One correction to the request's framing, for the next reader: the three call
sites it points at (`src/transforms/shir_native_stmt.rs:1221/1227/1241`) are
NOT in any commit — `git show HEAD:src/transforms/shir_native_stmt.rs | grep -c
param_text_to_perl` returns 0. That file is another worker's uncommitted WIP
(73 insertions / 7 deletions in the working tree). That is why HEAD now builds
even though the callers that motivated the request are uncommitted: the
`pub(crate)` change is strictly more permissive than HEAD needs. So this is not
"still unfixed because of contention" — it is fixed, and the fix happens to be
idempotent with the WIP in flight. Nothing further is needed here; the `-n`/`-z`
lowering itself remains the perl-generator worker's to land and gate.
