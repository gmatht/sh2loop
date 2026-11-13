# `[[ … ]]` arrives as RAW TEXT — a `$(…)` inside it forces every backend to shell out

## NEED

ShIR hands a test expression to the renderer as an opaque string:

```json
{"type":"Call","func":"test","purity":"Emulable",
 "args":[{"type":"Str","style":"DoubleQuoted","value":"\"$(wc -l < \"$file\")\" -gt 10"},
         {"type":"Str","style":"DoubleQuoted","value":"[["}]}
```

The value carries the test body verbatim, including any command substitution
and its quoting. A renderer cannot lower that: evaluating the `$(…)` means
re-parsing shell text, and the ShIR contract exists precisely so the renderer
does not have to.

So every backend treats "test text containing `$(…)`" as a fork/exec case.
Measured on the c backend, this is the LARGEST single reason a corpus cell
still emits a child-bash site (14 of the 39 single-site `ir_to_*`/`shir_to_*`
shapes enumerated at 2026-10-09; `harness/c_body_tally.sh`).

## WHY it is not a renderer bug

`c_backend.rs::test_needs_shell` bails on a `$(` outside a `$((…))` span and
routes to `test_shell_site`, which builds `[[ <text> ]]` and runs it through
`bash -c`. The alternative — scanning `$(`…`)` out of the text, re-lowering
the inner command, substituting a temp back into the text, then running the
existing native test path — is a shell FRONTEND living inside every renderer,
duplicated per backend, and it would drift from the real parser. REFUSE >
GUESS applied to the whole family, deliberately.

This is one of the two places where the A1 contract is not actually
language-neutral: the renderer is asked to re-derive shell structure the core
already had. (`case` patterns had the same shape until core started emitting
`expr` patterns; the note left in `c_backend.rs`'s `IrStmt::Case` arm —
"Proper fix needs expr-patterns (frontend/core)" — is the same request.)

## WHY it costs the metric

Per-cell cost of the workaround, measured 2026-10-09 with the worktree
renderer:

    190 sites over 118 of 560 corpus cells (before the 2026-10-09 redirect work)
    a site drags in _sh_site_N + _sh_reset + _sh_add/_sh_badd + _sh_cmd +
    _sh_bash_argv + _sh_system_rc, and keeps the whole bash-text runtime
    alive in that cell even when it is the cell's ONLY site
    (_sh_bres 948 + _sh_reset 795 + _sh_capture 790 + _sh_pipeline 776
     + _sh_system_rc 515 + _sh_add 496 + _sh_bash_argv 276 ≈ 4600 mentions
     of the 17418 total = 26%)

`[[ "$(…)" … ]]` is ~14 of the 89 cells that carry exactly ONE site, i.e.
the cells where removing the construct removes the whole runtime, not just
one call. It is the highest-leverage single shape left.

## MINIMAL-CORE-CHANGE

Lower the `$(…)` operand out of the test text, exactly as `case` patterns
were fixed. Any of these is sufficient; the first is smallest:

1. **Preferred — split the test into a structured test node.** Emit the
   existing `test` call for the operand shape, but replace each `$(cmd)`
   operand with an `IrExpr::Capture`/`captureWords` child and let the
   renderer evaluate it natively (it already lowers both). A shape like
   `test {args: [Array[Entry, Entry], "["], …}` would be additive: the
   `Str`-text form stays the fallback, renderers keep their parsers, and a
   renderer that does not understand the array form refuses as today.

2. **Alternatively — pre-evaluate in core.** Emit the `$(…)` operands as
   preceding statements assigning to hygienic temps (`__sh2_t7`) and put the
   temp NAMES into the test text. The test text then contains no `$(` and the
   existing native test lowering accepts it unchanged, in every backend, with
   no new node. Cheapest for renderers; costs a temp per operand.

Do NOT change the text form's meaning for existing consumers: the `Str`
body must stay byte-identical when it contains no `$(…)` / backtick.

## FAILING-CASE

    examples/016_grep_basic.sh          ([[ … ]] is not used; unrelated)
    examples/070_gnuisms_thorough.sh    `[[ "ABC" == "abc" ]]` — natively
                                        lowered today; its `$(…)` siblings
                                        are not
    examples/062_hard_to_lex.sh         `[[ "$(…)" … ]]` shapes

Minimal reproductions (c backend, 2026-10-09):

    $ printf '[[ "$(wc -l < f)" -gt 10 ]]\n' | shir_render --target=c -
      → int main(void) { _sh_site_0(); return _sh_rc; }      # child bash

    $ printf '[[ "x" = "x" ]]\n' | shir_render --target=c -
      → int main(void) { _sh_rc = (strcmp("x", "x") == 0); … }   # native

Confirmed the same shape is a site for perl / rust / python on
`examples/parse-redirect-in-case-pattern.sh`'s sibling pattern, so this is
shared-surface, not c-specific.

## STATUS of the c backend today

Not blocking: the c gate is 645 OK / 0 fail on the corpus with this family
still shelling out (`harness/c_gate_par.sh`). This request is about the
runtime-delegation metric, not correctness — the sites are correct, just not
native.

## OUTCOME: implemented

Option 2 (pre-evaluate the operand in core) is implemented in the lowering
(`shir.rs`): `prelower_test_captures` scans a test body (single-quote aware,
`$((…))` excluded, balanced `$(` nesting), parses each `$(cmd)` with the real
shell parser, and emits one `ir = $(cmd)` statement per operand; the body
carries `${ir}`. Wired into standalone tests (a `Block`), `if` conditions and
the LEFT operand of `&&`/`||` chains (both evaluate that operand
unconditionally, so hoisting is side-effect-faithful). A body with no `$(…)`,
an unparseable one, or a shape the emitter already folds natively
(uname/hostname/whoami/date/readlink/pwd, `echo X | tr …`, `… | grep -q …`)
keeps the exact previous text — byte-identical IR. `while`/`until` conditions
are deliberately left on the text path (the capture must re-run per iteration;
wrapping it needs a re-evaluating expression node per backend, follow-up).
Result: `sh2.test("\"$(wc -l < f)\" -gt 10")` becomes a native capture plus a
native compare on every backend; the corpus stays 562/562 on both paths.
