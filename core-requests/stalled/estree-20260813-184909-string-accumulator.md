# estree: string-accumulator transform — `v="$v$seg"` in a loop → chunk array + join at reads

## NEED

An IR-level analysis + estree-renderer lowering for the **string
accumulator** pattern: a scalar var `v` whose only writes are
self-appends (`v = Interpolate(v, seg)` — `v="$v$seg"`) inside a loop,
initialized before the loop and read only after it. Lowering: append
each `seg` to a chunk array (`__acc_v.push(seg)`) in the loop, and
materialize once per post-loop read (`__acc_v.join("")`) instead of
re-concatenating the growing string every iteration.

## WHY

The game's render path builds the block list this way (4 A1
self-append sites; the two in `try_draw`/`draw_block` run **768×/
frame**):

    blk_p=""
    while …; do
      blk_p="$blk_p$td_a $td_b $td_c 1 1 1 $r $g $b $tx 0
"
      …
    done
    echo "$blk_p" > /dev/webgl/…     # read only after the loop

The emitted JS re-evaluates a growing template literal per append:
`blk_p = \`${blk_p}${td_a} …\n\`` — ~1500 appends/frame growing to
~30KB. V8's cons-strings blunt the naive O(n²), so the measured win is
modest per frame (~1-2%), but it scales with output size, removes a
cons node + template evaluation per append, and the pattern is
general (texture generators, any file-building loop: `log="$log$line"`,
`csv="$csv$a,$b"`). The same transform also makes the accumulator
**read-friendly for the native-array fold** (chunks are a flat array →
`join` folds to a native join).

## MINIMAL-CORE-CHANGE

Analysis (shir_passes or the transforms channel — analysis-only, like
`sync_ok_loops`, with renderer hooks):

1. **Recognize**: scalar `v` (Str verdict, `var_types`) where every
   `Assign { targets:[{var:v}], expr: Interpolate }` has exactly ONE
   read of `v`, as the leading part (`param("", "v")`), and occurs
   inside a `While`/`For` body. `v` is initialized to a const before
   the loop(s). **No read of `v` inside any loop body that appends to
   it** (a mid-loop read observes the growing string — deferral would
   change the value). All other reads of `v` are AFTER the last
   appending loop. `v` does not escape (var_lifetimes `escapes:false`)
   and is never sliced/len'd/compared (`${v:0:4}`, `${#v}`, `[ "$v" =
   x ]` disqualify — those need the materialized string).
2. **Verdict store**: per-var pointer-keyed verdicts (the
   `ASYNC_REGION_LOOPS`/`lastexit_dead` static pattern) read by the
   renderer.

Renderer hooks (estree.rs):

3. An appending assign emits `__acc_v.push(<seg>)` where `<seg>` is
   the interpolation's parts[1..] flattened to one string expression
   (the emitter's existing parts→template lowering, minus the leading
   self-read); the `let __acc_v = []` decl replaces the `let v = ""`
   binding (the init const, if non-empty, seeds `[C]`).
4. Every post-loop read of `v` (getVar/param-"" / interpolation
   operand) emits `__acc_v.join("")` — one materialization per read
   site, never per append.

Shared-A1 alternative (if a cross-backend form is preferred): rewrite
the self-append to `Expr(setArrayAppend("v", [seg]))` and post-loop
reads to `join(arrayItems("v"))` — the estree backend already renders
these natively; the c/go backends render arrays correctly (correct,
not necessarily faster). The estree-specific form above is the minimal
change.

## FAILING-CASE

    blk=""
    i=0
    while [ "$i" -lt 3 ]; do
      blk="$blk x $i
"
      i=$((i + 1))
    done
    echo "$blk"

currently emits three growing `blk = \`${blk} x ${i}\n\`` template
concats (each re-reading the accumulated string); with the transform:
`__acc_blk.push(\` x ${i}\n\`)` × 3 and `echo` joins once →
`__acc_blk.join("")`. Output bytes identical for any number of
iterations (including zero — `[].join("")` is `""`); corpus gate
(`./fail-estree` at the trusted baseline) judges. The bisect's risk is
a mid-loop read (wrong deferred value) or a slice/len on the
accumulator — both excluded by the guards above.
