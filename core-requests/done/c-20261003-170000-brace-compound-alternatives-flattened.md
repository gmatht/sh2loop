# parser: nested brace alternatives flatten — `{x/{p,q},y}z` expands to the wrong cartesian product

**Filed by:** c backend worker (`backends/c`, branch `backend/c`)
**Scope:** shared core (`src/parser/words.rs`) — NOT a renderer-only fix
**Failing test:** `shir::range_analysis_tests::nested_brace_alternatives_are_compound_groups`
**Corpus surface:** every backend that expands braces (c, perl, rust, java, python, estree)

## NEED

`parse_brace_expansion` never constructs `BraceItem::Compound`, so an
alternative that CONTAINS a nested brace is spliced into the parent as a
sibling item instead of being grouped as one alternative. The expansion
computes the wrong cartesian product.

```bash
echo a{x/{p,q},y}z
```

| | output |
|---|---|
| bash (ground truth) | `ax/pz ax/qz ayz` |
| generated C (today)  | `ax/z apz aqz ayz` |

The last term `ax/z` is not reachable in bash at all — it is the artifact of
the flattening.

## WHY

`BraceItem::Compound` is declared (`src/ast_words.rs:146`, and again in
`ast_words_clean.rs:123`) and every CONSUMER handles it —

- `src/shir.rs:18215` — `brace_item_json`
- `src/ast_words.rs:256`, `:405`, `:571`

— but there is no construction site anywhere in `src/`. The variant is dead
by construction, not by decision: the renderer plumbing was written and the
parser never filled it in.

The flattening happens in the comma branch of `parse_brace_expansion`
(`src/parser/words.rs:4899`):

```rust
Some(Token::Comma) => {
    // Comma terminates the current accumulated item.
    flush_acc(&mut items, &mut acc);
    lexer.next(); // consume ','
}
```

There is no notion of "the current alternative". `flush_acc` pushes the
accumulated literal, and the `BraceOpen` arm (`:4888`) pushes
`BraceItem::Nested` — both straight into the SAME flat `items` vec. So
`{x/{p,q},y}` parses as the sibling sequence
`[Literal("x"), Nested({p,q}), Literal("y")]` instead of
`[Compound([Literal("x"), Nested({p,q})]), Literal("y")]`.

Each `BraceItem` in that flat vec is then treated as one top-level
alternative, which is exactly why `x` cross-multiplies against `{p,q}` to
give the bogus `ax/z`.

## MINIMAL-CORE-CHANGE

Track an in-progress ALTERNATIVE and wrap it in `Compound` at the `,` / `}`
boundary. The invariant: `items` holds *alternatives*; a multi-part
alternative is a `Compound`, a single-part one stays the bare item it already
is — so every currently-correct case stays byte-identical.

```rust
// new state alongside `acc`
let mut alt: Vec<BraceItem> = Vec::new();

/// Close the in-progress alternative: one part stays bare, two or more
/// become a Compound (a cartesian factor).
fn flush_alt(items: &mut Vec<BraceItem>, alt: &mut Vec<BraceItem>) {
    match alt.len() {
        0 => {}
        1 => items.push(alt.pop().expect("len 1")),
        _ => items.push(BraceItem::Compound(std::mem::take(alt))),
    }
}

/// flush_acc now targets the CURRENT ALTERNATIVE, not `items`:
///     alt.push(BraceItem::Literal(text));
```

Route every push through the alternative:
- `flush_acc` → `alt.push(Literal(..))` (was `items.push`)
- the `BraceOpen` arm (`:4915`) → `alt.push(BraceItem::Nested(..))`
- `Range` (`:4808` … `:4870`) → `alt.push(BraceItem::Range(..))`
- `,` → `flush_acc` + `flush_alt`
- `}` → `flush_acc` + `flush_alt`

**Ordering note (this is what I got wrong first).** The accumulator must
push onto `alt`, and `alt` must be closed ONLY at the boundary. Do not push
the first part straight into `items` — that keeps `alt` empty and every part
lands as a sibling, reproducing the bug. `flush_alt` is what collapses the
group, and it must run after the final `flush_acc` at each `,`/`}`.

Because `Compound` push sites then actually fire for the first time, the
existing consumers (`shir.rs:18215`, `ast_words.rs:256/405/571`) start
executing for the first time. They should be read as the intended contract,
but they are untested-in-practice — gate on the corpus, not just the unit
test.

### Verified (prototype applied, then reverted)

I implemented this in `backends/c` to confirm the diagnosis before filing,
then reverted it (core-owned). Results:

| | before | after |
|---|---|---|
| `cargo test --lib` | 1047 pass, 6 fail | **1048 pass, 5 fail** |
| `nested_brace_alternatives_are_compound_groups` | FAIL | **PASS** |
| other 5 pre-existing failures | FAIL | FAIL (unchanged) |

Zero regressions; the target test flips green. Behaviour against bash:

```
echo a{x/{p,q},y}z    bash=ax/pz ax/qz ayz        after=ax/pz ax/qz ayz   FIXED
echo {x/{p,q},y}z     bash=x/pz x/qz yz           after=x/pz x/qz yz    FIXED
echo {a/{p,q},b}z     bash=a/pz a/qz bz           after=a/pz a/qz bz    FIXED
echo {a,b} / {1..5} / pre{a,b}post / x/{p,q}      unchanged (OK)
```

### Second, INDEPENDENT core defect this uncovered

`echo {a/{b,c}}d` — bash applies its comma rule only at the TOP level:

| | output |
|---|---|
| bash | `{a/b}d {a/c}d` (nested commas suppressed) |
| baseline (today) | `a/d bd cd` |
| with the Compound fix | `a/bd a/cd` |

The Compound fix is a strict improvement here (correct cartesian structure;
only the nested-comma suppression rule is still missing), but the remaining
divergence is a **separate** bug in the same function and needs its own fix.
Flagging it so the sweep is not gated on it, and so it is not lost — it is
the general "a nested brace's commas do not split the parent" rule.

## FAILING-CASE

```bash
cd backends/c
cargo test --lib nested_brace_alternatives_are_compound_groups
```

```
thread 'shir::range_analysis_tests::nested_brace_alternatives_are_compound_groups' panicked
missing "ax/pz" in C:
int main(void) {
    printf("%s\n", "ax/z apz aqz ayz");
    return 0;
}
```

The sibling assertion in the same test covers the second shape:
`echo {a,{b,c}}d` → `ad bd cd`.

## Notes for the core owner

- `cargo test --lib` on `backends/c` is **1047 passed, 6 failed**. Two of the
  six are this one plus its brace-prefix sibling; the other four are
  independent (`estree::tests::assignment_lowers_to_setvar`,
  `estree::tests::nested_param_default_chain_lowers_to_getvar_ternaries`,
  `ir::tests::echo_tr_pipeline_renders_native_transliterate`,
  `ir::tests::param_plus_renders_defined_test_not_the_variable`). All six
  are in core files (`shir.rs`, `estree.rs`, `ir.rs`); none are in
  `c_backend.rs`, and this branch never edited the core files that own them.
- The failing test lives in `src/shir.rs` but calls
  `crate::c_backend::shir_to_c` — it is a backend test housed in core. It is
  a good place for the assertion (it pins the end-to-end cartesian product)
  and worth keeping, but note it means the core test suite will report a
  backend failure if the c renderer regresses.
## OUTCOME: implemented — same fix as c-20260930-021500 / c-20261003-022258: the core parser builds the Compound group again and the unit test passes; the divergence the request saw lives in the stale `backends/c` worktree, not the shared core.
