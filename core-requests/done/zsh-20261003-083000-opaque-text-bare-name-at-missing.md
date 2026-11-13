# zsh: shared core `shir.rs` does not compile — `bare_name_at` called, never defined

**Filed by:** zsh backend worker
**Scope:** shared core (`sh2perl/src/shir.rs`) — uncommitted WIP, NOT a zsh defect
**Blocking:** `cargo build` of the whole `debashl` lib, so EVERY backend gate is red until it lands

## NEED

Define the missing helper `bare_name_at`, or delete the call site. `sh2.rs`
does not compile.

```
error[E0425]: cannot find function `bare_name_at` in this scope
   --> src/shir.rs:14642:49
    |
14642 | ...                   if let Some(name) = bare_name_at(piece) {
    |                                           ^^^^^^^^^^^^ not found in this scope
```

## WHY

This is not a zsh regression and not a design gap in the lowering — it is an
unfinished edit in the shared core that is currently uncommitted in the
working tree. Evidence:

1. `git -C sh2perl diff --stat src/shir.rs` = `164 insertions(+), 9 deletions(-)`,
   all uncommitted.
2. `grep -rn "bare_name_at" sh2perl/src/` returns exactly ONE hit — the call
   site at `shir.rs:14642`. There is no `fn bare_name_at` anywhere.
3. `git log --all -S "fn bare_name_at" -- src/shir.rs` returns NOTHING, and no
   entry in `git stash list` contains it. The helper was never committed on any
   branch, so it cannot be recovered by re-reading history.
4. The failing function is NEW in this WIP: `fn vars_in_opaque_text`
   (line 14622) and its callers `harvest_opaque_expr` (14681) /
   `harvest_opaque_arith` (14703) are all `+` lines in the same diff.

The edit count between two of my builds moved 3 -> 1, which is the signature
of another worker saving the file mid-compile; the core is being edited in
place.

## MINIMAL-CORE-CHANGE

The call site is the `${...}` arm of `vars_in_opaque_text`:

```rust
Some(c) => {
    let span = &text[i + 2..c];
    for (k, piece) in span.char_indices() {
        let _ = k;
        if let Some(name) = bare_name_at(piece) {
            out.insert(name);
        }
    }
    ...
}
```

`span` is the text BETWEEN `${` and `}`. The helper is the same rule the
sibling arm and the function's own trailing validation block already apply
inline:

```rust
let name = name.trim_start_matches('#');
if !name.is_empty()
    && name.chars().next().is_some_and(|c| c == '_' || c.is_ascii_alphabetic())
    && name.chars().all(|c| c == '_' || c.is_ascii_alphanumeric())
{
    out.insert(name.to_string());
}
```

— lifted into a helper that returns `Option<&str>`: a bare shell identifier,
or `None` for anything else.

```rust
/// One bare shell identifier inside an expansion's text, if `piece` is
/// exactly that. `None` for operators, digits and the empty run —
/// `${flags:j:1}` yields `flags` and `j`, never `:1`.
fn bare_name_at(piece: &str) -> Option<&str> {
    if !piece.is_empty()
        && piece.starts_with(|c: char| c == '_' || c.is_ascii_alphabetic())
        && piece.chars().all(|c| c == '_' || c.is_ascii_alphanumeric())
    {
        Some(piece)
    } else {
        None
    }
}
```

The helper ALONE is not enough — the loop needs the fix below too.

### The call site is ALSO wrong — fix the loop, not just the helper

This is the part that matters. `<[&str]>::char_indices()` yields `char`, not
`&str`:

```
for (k, piece) in span.char_indices() { ... }
                             ^^^^^ piece: char
```

So `piece` is a single CHARACTER. `bare_name_at(piece)` therefore needs a
`&str`, and no signature that takes one will typecheck as written. I verified
this with a standalone `rustc` probe: for `span = "flags:j:1"` the loop yields
`'f'`, `'l'`, `'a'`, `'g'`, `'s'`, `':'`, `'j'`, `':'`, `'1'` — one char each.

**If the helper is only defined, the crate COMPILES but the harvest is
silently wrong.** `let _ = k;` shows the author expected `&str` slices. The
loop must iterate identifier RUNS, not characters. Minimal correct form:

```rust
for piece in span.split(|c: char| !(c == '_' || c.is_ascii_alphanumeric())) {
    if let Some(name) = bare_name_at(piece) {
        out.insert(name.to_string());
    }
}
```

`out` is a `HashSet<String>`, and the sibling arm inserts `name.to_string()`.

Verified with a standalone `rustc` build of the helper plus this loop:

```
span             harvested
flags:j:1        {flags, j}      <- base AND slice offset, as the comment wants
arr              {arr}
0                {}              <- a bare digit is not a name
a1_b             {a1_b}
#x               {x}
i                {i}
```

`flags:j:1` -> `{flags, j}` is the exact harvest the FAILING-CASE needs: both
`flags` and the offset `j` are runtime reads, and `1` is a length, not a name.

ALTERNATIVELY, if the mediator prefers not to add a helper: drop the `for`
loop entirely and let the existing trailing validation block do the work —
but that is NOT a drop-in either, because the outer `let (name, next)`
binding would then have to yield the span head AND the offset, which is a
bigger restructure of the arm. Helper + `split` loop is the smaller, safer
change.

## FAILING-CASE

The motivating corpus case for the WIP this edit belongs to:

`sh2perl/examples/063_09_complex_function_parameter_handling.sh:18-21`

```bash
local flags="${args[i]#-}"
...
    while (( j < ${#flags} )); do
        options["${flags:j:1}"]="true"
```

`${flags:j:1}` reads THREE runtime-resolved names: the base `flags` AND the
slice offset `j`. The slot-homing pass must refuse to home `flags` to a
`__t64[k]` slot, because a slot-homed var is written only to `__t64[k]`, never
appears in `sh2.vars`, and so every such read silently yields the
empty/undefined value — the loop collapses to one key instead of one per
character. That refusal is what `vars_in_opaque_text` exists to perform.

Verification once the helper lands:

```
cd sh2perl && cargo build            # must reach zero errors
harness/backend_runtime_metric.sh zsh # re-measure the zsh delegation count
```

## NOTE FOR THE MEDIATOR

The zsh tree itself is healthy and its gate was green at 600/649 before the
core edit landed (`loop-backend-zsh.log`, 2026-10-03T13:31:38). The zsh
worker is blocked purely on this compile error, so this request is a pure
unblock and needs no design decision: one 9-line helper plus a one-line loop
change, both already verified standalone.
## OUTCOME: implemented — sh2perl f72ccf057 ("shir: fix the bare_name_at call site so the opaque-text harvest is whole-identifier"). `bare_name_at(piece: char)` is now defined as the single-char start predicate and the `${…}` arm harvests WHOLE identifiers by splitting the expansion body on non-identifier chars (so `${flags:j:1}` yields `flags` and `j`, never `1`). The crate compiles; 063_09 renders and matches bash. The suggested `&str` split loop was not taken verbatim (the helper is the `char` predicate plus an inline accumulator), but the observable contract is identical and verified.
