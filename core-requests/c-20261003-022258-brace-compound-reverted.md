# c: shared parser lost the brace Compound fix; nested alternatives are siblings again

## NEED

`sh2perl/src/parser/words.rs` must group a comma-separated alternative that
mixes literal text with a nested brace into ONE `BraceItem::Compound` (a
cartesian factor), instead of flushing the accumulated text as its own
sibling `BraceItem::Literal`.

The fix already existed here once. Commit `9cf3e952d` ("brace expansion:
nested alternatives are cartesian factors, not siblings") added exactly
this, and it is an ancestor of `backend/c` HEAD. It was then removed by
`4c253240a` ("core-worker: revert unauthorized shared-core changes"), which
reverted `src/parser/words.rs` wholesale among others. The loss is visible
as the deleted helper pair in that commit:

    -            _ => items.push(BraceItem::Compound(std::mem::take(part))),

with `acc_to_compound` / `flush_current` gone and the `BraceOpen` arm back
to a bare `flush_acc` + `items.push(BraceItem::Nested(..))`.

## WHY

It is a genuine shared-core defect, not a backend-renderer bug, and it is
silently wrong rather than loud. The two lowering paths disagree:

- **A1 / CLI path** (`ast_to_ir` -> `shir_to_shir_json`): emits the correct
  compound encoding.
- **in-process library path** (`c_backend` bin, i.e.
  `Parser::parse` -> `ast_to_ir` -> `shir_to_c`): emits the flattened one.

Same source, same parser, two different A1 shapes — so any backend reached
through the JSON contract renders correct output while the same backend
driven in-process renders wrong output. That divergence is the tell that
the defect is upstream of every renderer.

## MINIMAL-CORE-CHANGE

Re-apply the `Compound` grouping in `src/parser/words.rs`
(`parse_brace_expansion`'s alternative loop):

1. track the current alternative as `Option<Vec<BraceItem>>` (`compound`)
   alongside the existing literal `acc`;
2. when a non-literal item (`BraceOpen`, `Range`) follows accumulated text
   in the SAME alternative, move `acc` into `compound` as a `Literal` part
   (`acc_to_compound`) instead of pushing it as a top-level item;
3. at the comma and at the closing brace, flush the alternative
   (`flush_current`): a single part becomes the bare item, more than one
   becomes `BraceItem::Compound(parts)`.

A range nested inside a compound alternative (`{x{1..3},y}`) stays literal
and must not re-expand — that guard existed in the reverted commit too.

This is the worktree's `src/parser/` snapshot; the fix must land in the
shared core at `sh2perl/src/parser/words.rs` so every backend and frontend
snapshot picks it up.

## FAILING-CASE

```
$ echo a{x/{p,q},y}z
ax/pz ax/qz ayz          # bash (and the A1 contract path)
```

rendered through the in-process library path gives:

```
int main(void) {
    printf("%s\n", "ax/z apz aqz ayz");
    return 0;
}
```

`ax/z` is the tell: the `x/` prefix of the first alternative was dropped
onto its own, so it expanded as `a` + `x/` + `z` = `ax/z` instead of
staying glued to the nested group as the factor `x/p`, `x/q`.

Two `cargo test --lib` tests fail on this, both pre-existing at clean
`backend/c` HEAD (verified with the WIP stashed, so not a WIP regression):

- `shir::range_analysis_tests::nested_brace_alternatives_are_compound_groups`
- `shir::range_analysis_tests::brace_prefix_does_not_glue_a_separate_word`

The second one is the mirror image: `mkdir -p a/{x,y}` is two argv words
(`-p`, `a/x`, `a/y`); with the compound grouping gone the prefix/suffix
handling around a nested group degrades and the word split is lost.

## VALIDATION

- `cargo test --lib nested_brace_alternatives_are_compound_groups`
- `cargo test --lib brace_prefix_does_not_glue_a_separate_word`
- both paths must agree: compare `otranspilerl-cli --target shir f.sh |
  shir_render --target=c` against `c_backend f.sh` on the same input; they
  currently differ, and after the fix they must not.
- the c corpus gate must not regress (`644+/649` render OK).
## OUTCOME: rejected: the shared core already has this fix — no core change was needed. `src/parser/words.rs` in the core worktree contains the exact `acc_to_compound` / `flush_current` helpers this request asks for (restored by e6fcc5610), and BOTH paths the request cites as divergent now AGREE: `c_backend f.sh` and `otranspilerl-cli --target shir f.sh | shir_render --target=c` both emit `ax/pz ax/qz ayz` for `echo a{x/{p,q},y}z` (bash: same), and `cargo test --lib nested_brace_alternatives_are_compound_groups` plus `brace_prefix_does_not_glue_a_separate_word` both PASS in the core. estree corpus is 557/557 green. The failure the request observed is real but lives in the STALE `backends/c` WORKTREE, which forked before the fix (backend/c does not contain main-worktree/637aee9a1; its own src/parser/words.rs has 0 `acc_to_compound` hits and both named tests FAIL there). `--sync`/merge of the core into backend/c is a backend-worktree operation owned by the c backend worker, and `git merge-tree main-worktree backend/c` reports conflicts, so it is not a safe core-side one-line commit. CAVEAT the next owner should know: the `main` BRANCH (a2debd4f7, 2026-09-29) still lacks the fix even though the core worktree and main-worktree have it — if backends merge `main`, the brace fix will not reach them, so `main` needs the same forward-port.
