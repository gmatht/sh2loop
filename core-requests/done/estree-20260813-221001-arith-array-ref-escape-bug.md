# estree: CORRECTNESS — `${arr[$i]}` inside $(( )) on the debashcl path emits escaped-text the runtime mis-expands

## NEED

The **parse-tree estree path** (`estree.rs ast_to_estree_json`) must
emit a **value read** for an array reference inside a `$(( ))`
arithmetic text, not an **escaped `\$` literal** that the runtime's
arith expander then mis-parses. Today:

    mb_cxm=$((RADAR_X + ${mx[$mb_i]}*44))

emits

    mb_cxm = sh2.arith(`RADAR_X + \${mx[${mb_i}]}*44`)

— the outer `$` is escaped, so the runtime receives the literal string
`"RADAR_X + ${mx[2]}*44"`, expands `${mx[2]}` with its bash-arith
expander (which handles the `${arr[idx]}` form incorrectly — a
whole-array join + bracket artifact), and computes a garbage coordinate
(mime HUD blips landed ~0.3 NDC below the radar: `1720 - ${mz[1]}*60`
→ −3140 milli).

## WHY

The game's radar blips (`draw_mime_blip`) drew `1720 - ${mz[$mb_i]}*60`
→ negative milli → blips below the 16×16 map. Bash itself evaluates
`${arr[$i]}` BEFORE the arithmetic (expansion happens first), so the
source is correct — the EMITTER is what breaks: it escapes the outer
`$` (intending the runtime to expand it) but the runtime's arith
expander only handles plain `$var` / `${name}`, not `${name[idx]}`.
The top-level equivalent (`mb_mx=${mx[$mb_i]}; $((RADAR_X + mb_mx*44))`,
reading to a scalar first) emits correctly because `mb_mx` interpolates
as a value — the game's workaround. The emitter should do the same for
the direct form.

## MINIMAL-CORE-CHANGE

In `ast_to_estree_json`'s `$(( ))` text emission: an in-arith
`${name[expr]}` (or `$name[expr]`) reference should emit the **value**
— the same native/store read the top-level array read uses
(`sh2.arrayIndex("mx", <expr>)` or a store read interpolated into the
template), NOT an escaped `\$` literal. The A1 path handles this (its
arith-text lowering rewrites `$ref`s to native reads); the debashcl
path's escaping is the gap. Quoted `\${...}` that the SOURCE escaped
stays literal.

## FAILING-CASE

    mx=(10 20 30)
    mz=(7 8 9)
    mb_i=1
    mb_cxm=$((100 + ${mx[$mb_i]}*2))
    echo "$mb_cxm"

via the debashcl path emits `sh2.arith(`100 + \${mx[${mb_i}]}*2`)` →
runtime expands `${mx[1]}` wrong → garbage; via host bash and via the
A1 path it is `140` (100 + 20*2). Both must print `140`. Corpus gate:
`./fail-estree` at the trusted baseline — the fix changes only the
escaped-`$`-in-arith emission; any corpus example relying on the
runtime's (broken) expansion of that shape is a bug the gate catches.

## OUTCOME: implemented — verified end-to-end via the debashcl path: `mb_cxm=$((100 + ${mx[$mb_i]}*2))` emits the unescaped literal `sh2.arith("100 + ${mx[$mb_i]}*2")` and the harness runtime's arithExpand `${name[idx]}` arm expands it to 140 (the escaped-`\$` emission this request describes is gone from the current core).
