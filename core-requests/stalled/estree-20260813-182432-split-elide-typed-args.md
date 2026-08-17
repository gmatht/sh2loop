# estree: extend the no-op field-split elision to fnCall/exec arguments

## NEED

The ESTree renderer should skip the `String(x).split(/\s+/).filter(w =>
w.length > 0)` word-split wrapper on **function-call and exec
arguments** whose value is provably no-space — the same
`expr_known_nospace` shortcut the **echo/print** arg path already has
(estree.rs, `echo_single_arg_skips_the_join` test): an Int-typed var,
an int literal, an `$(( ))` expression, or a quoted arg cannot contain
IFS whitespace, so the field-split is a provable no-op.

## WHY

The word-split wrapper exists for unquoted-word semantics (bash splits
`$x` on IFS), but every fnCall arg in MIMEcroft's render loop is an
int cell coordinate: `await sh2.fnCall("get_cell", [String(td_a).split(
/\s+/).filter(w => w.length > 0), "2", String(td_c).split(/\s+/)…])`.
Measured: `String(x).split(/\s+/).filter(...)` is **21×** a plain value
(295ms vs 14ms per 2M), and the game emits ~113 such wrappers
statically, hit ~1500–2300×/frame. The A1 already carries the type
verdicts (`var_types`: 122 Int / 116 Str in the mimecroft contract), so
the emitter can decide at emission time — no new analysis needed.

## MINIMAL-CORE-CHANGE

In the function-call / exec-argument lowering (shir.rs fnCall path →
estree.rs emit): when an arg expression `expr_known_nospace`s — it is
an Int-typed variable read, an integer literal, a quoted (non-split)
word, or an `arith`/binary expression over no-space operands — emit the
bare value (direct binding / native int expr) instead of the
`String(v).split(/\s+/).filter(...)` wrapper. Keep the wrapper for
Str-typed/unknown/multi-word args (an unquoted string var can still
split). Reuse the existing `expr_known_nospace` verdict — the gap is
that the echo path consults it but the fnCall/exec path does not.

## FAILING-CASE

    get_cell() { a=$1; b=$2; c=$3; idx=$((b * 16 + c * 16 + a)); gv=${map[$idx]}; }
    ax=3; az=7
    get_cell $ax 0 $az
    echo "$gv"

currently emits `fnCall("get_cell", [String(ax).split(/\s+/).filter(w =>
w.length > 0), "0", String(az).split(/\s+/).filter(w => w.length > 0)])`
— six split/filter calls for three int values. With the elision the
args emit as `[ax, "0", az]`. Output bytes are identical (an int has no
spaces to split); the corpus gate (`./fail-estree`) is the judge.

## NOT-A-TRANSFORM: estree worker (estree.rs fnCall/exec argument lowering)
## REASON: Renderer-specific emission — estree.rs decides at emit time, per the shared expr_known_nospace verdict, whether to skip the String(x).split(/\s+/).filter(...) word-split wrapper on fnCall/exec args. It consumes the already-shared A1 var_types verdicts (122 Int/116 Str in the mimecroft contract); no IR mutation, no new op, no shared analysis — nothing to bundle (the rubric's split-elide example verbatim).
