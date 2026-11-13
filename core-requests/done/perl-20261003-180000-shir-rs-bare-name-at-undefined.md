# perl: shared core does not compile — `bare_name_at` called but never defined

## NEED

`sh2perl/src/shir.rs` does not build. `cargo build --lib` fails:

    error[E0425]: cannot find function `bare_name_at` in this scope
        --> src/shir.rs:14642:49
         |
    14642 | ...                   if let Some(name) = bare_name_at(piece) {

The helper is CALLED at `src/shir.rs:14642` inside `vars_in_opaque_text`
(added by the "harvest EVERY bare name inside `${…}`" fix — see the comment
block directly above the call) but there is no `fn bare_name_at` anywhere in
`src/`, at any revision of the file, and no import that would bring one in.

    $ command grep -rn "fn bare_name_at" --include=*.rs src/
    (no output)

The only occurrence of the identifier in the entire tree is the call itself.

## WHY

This is a hard build break, so it blocks **every** backend and the whole
corpus gate — not just the Perl generator. Nothing downstream of `debashl`
can be compiled or tested until it lands.

**This is NOT caused by the perl-generator worker.** Proven by stashing
only that worker's file and rebuilding the pristine tree:

    $ git stash push -- src/perl_generator_fixed.rs
    $ cargo build --lib
    error[E0425]: cannot find function `bare_name_at` in this scope
    error: could not compile `debashl` (lib) due to 1 previous error

The break is present with the generator file reverted to its committed state,
so it originates in the shared core's own working tree. Submodule HEAD is
`bc9abbb80` ("ir: let a consumer populate the array/hash census before its
fixups"); the working tree carries additional uncommitted edits to `shir.rs`,
`ir.rs`, `estree.rs`, `parser/words.rs` and several backends, which is where
the half-landed change lives.

This is the same class already filed twice today and left unresolved —
`core-requests/perl-20261001-core-wip-build-break.md` (both copies now
`.stall`) and
`core-requests/c-20261002-004500-usepalternative-uncommitted-build-break.md`.
A third occurrence of the same "uncommitted core WIP breaks the build"
failure mode means the underlying need is for a **recovery contract**, not
another one-off revert: the core worker must detect a non-compiling shared
tree and roll it back to a last-known-good state instead of leaving every
backend blocked on it.

## MINIMAL-CORE-CHANGE

Add the missing helper next to `vars_in_opaque_text` in `src/shir.rs`. The
call site fixes the signature exactly — `span.char_indices()` yields
`(usize, char)`, and `piece` is the `char`, so it takes one `char` and
returns the identifier starting at that character (if any):

```rust
/// The identifier starting at `c`, if `c` begins one — `true` and `my`
/// yield `true` / `my`, `+` and `1` yield None. Stops at the first
/// character that cannot appear in a shell identifier, so `${flags:j:1}`
/// harvests `flags`, `j` and (not) `1`.
fn bare_name_at(c: char) -> Option<String> {
    if !(c == '_' || c.is_ascii_alphabetic()) {
        return None;
    }
    Some(c.to_string())
}
```

If the original intent was to harvest the WHOLE identifier from an offset
into `span` rather than the single leading character, then the call site —
not the helper — is what needs the fix: pass `&span[k..]` and let the helper
walk to the first non-identifier character. That is the correct reading of
"harvest the whole span" in the comment, and it changes the outcome only for
identifiers longer than one character (`${a1}` currently contributes just `a`).
Either resolution unblocks the build; please pick per the original intent
rather than per the shortest diff.

## VERIFY

    cd sh2perl && cargo build --lib          # must reach "Finished"
    cd .. && ./fail                          # corpus gate runs again

The first corpus signal after the break is expected to be far worse than the
46 trusted Perl failures, since no backend has been able to build.
## OUTCOME: implemented — sh2perl f72ccf057 defines `bare_name_at` next to `vars_in_opaque_text` and repairs the call site (whole-identifier harvest). `cd sh2perl && cargo build --lib` is green; the corpus gate runs again.
