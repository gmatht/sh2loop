# estree: native test compilation — stop string-parsing sh2.test on the debashcl path

## NEED

The **parse-tree estree path** (`estree.rs ast_to_estree_json`, what
`bash script.sh` / `runBashScript` / the browser game + texture
generators run) should compile `[ ... ]` tests to **native JS
comparisons** exactly like the A1 path (`shir.rs shir_to_estree_json`)
already does. Today it emits `sh2.test(`"${x}" -lt "$SIZE"`)` — a
**full string parse per evaluation** (tokenizer + operator dispatch +
operand expansion + Number coercion) — and the runtime has NO way to
avoid it.

## WHY

Measured: the emitted test form costs **2510ms per 2M** evaluations
vs **10ms** for the native compare — a **250×** gap. The game's
debashcl build has 153 static `sh2.test` sites; the hot loops (render
16×16×3 with per-block air/mime tests, the mime scans, movement
guards) execute **~5-10k parses per frame ≈ 6-12ms of the ~48ms frame
budget**. The A1 path emits `!Number.isNaN(Number(x)) && Number(x) ===
Number(AIR)` for the same source — the debashcl path never got the
native lowering. The emitter ALREADY KNOWS the operator and the
quoting (it generated the string); it can emit the comparison
directly.

## MINIMAL-CORE-CHANGE

In `ast_to_estree_json`'s test lowering (the site that builds
`sh2.test("…")`), compile the test node natively when its shape is
provably compilable:

1. **Numeric operators** `-eq -ne -lt -le -gt -ge`: emit
   `(sh2._g = !Number.isNaN(Number(a ?? (sh2.vars.a ?? ""))) &&
   !Number.isNaN(Number(b)) && Number(a ?? …) < Number(b), sh2.lastExit
   = sh2._g ? 0 : 1, sh2._g)` — the A1 path's exact emission (operand
   reads: quoted-ref → the native/store read form the emitter already
   has for the arg; literal → the literal).
2. **String equality** `= == !=` with quoted operands: `String(a) ===
   String(b)` (shell `==` is string equality post-expansion) — with the
   lastExit wrapper when the test's status is live.
3. **Keep the runtime call** for file tests (`-e -f -d -r -w`), regex
   `=~`, `-z/-n` on unset-able vars, compound `&& || ! ()` that can't
   be flattened, and any operand that is a bare (unquoted) word whose
   IFS-splitting matters.
4. Gate: the corpus judges — the risk is a test whose shell semantics
   differ from the native form (`abc -eq 1` errors in bash; Number()
   gives NaN → false — verify against the runtime's parseTest for the
   same case and match it).

## FAILING-CASE

    i=0
    while [ "$i" -lt 16 ]; do
      echo "$i"
      i=$((i + 1))
    done

currently emits `while (sh2.test(`"${i}" -lt "16"`))` — tokenized and
parsed every iteration. Native: `while ((sh2._g = !Number.isNaN(Number(
sh2.vars.i ?? (sh2.env.i ?? ""))) && !Number.isNaN(Number(16)) &&
Number(sh2.vars.i ?? (sh2.env.i ?? "")) < Number(16), sh2.lastExit =
…, sh2._g))` — byte-identical output, no string parse. Corpus gate:
`./fail-estree` at the trusted baseline; the mimecroft
`gspan "render"` (~48ms) is the target.

## OUTCOME: implemented — the parse-tree estree path (ast_to_estree_json) has routed through shir_to_estree since the M3 reroute (2026-07-31, cb3702e), which emits the A1 path's native test lowering. Verified on the request's failing case (`while [ "$i" -lt 16 ]`): the emitted WhileStatement test is a native BinaryExpression `i < 16` (lifted binding), zero `sh2.test` dispatches, and estree-runner output is byte-identical to bash. Corpus gate: estree 521/521 at the trusted baseline.
