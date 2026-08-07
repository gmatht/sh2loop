# sh renderer: (1) the new IR shapes from arith_forms + grep_to_case, AND (2) the recursive `bash -c` → POSIX lowering (static-link default; dynamic `sh -c` opt-in)

## NEED
The shared core shipped two new transforms/lifts (the estree worker's
share, done in this session because the estree loop was slow):

  1. `src/transforms/arith_forms.rs` — rewrites `let "x+=1"` and
     `let "x++"` execs into structured `IrStmt::Assign` with
     `IrExpr::Arith(ArithAst::Assign{compound})` / `Arith(IncDec)`.
     ~12 corpus files (the rc=2 cluster: let-plusassign,
     arithmetic-equality, 055/058/etc.).

  2. `src/shir_passes/pattern/grep_to_case.rs` + the canonical-
     pipeline wiring (`shir_passes/mod.rs::apply_lifts`) — rewrites
     test-position `echo "$x" | grep PAT` and the `&&`/`||` chain
     into a native `IrStmt::Case { discriminant: Var("x"),
     clauses: [*PAT*) then, (*) else]`. The `-i` variant lowercases
     both sides via `tr 'A-Z' 'a-z'` and the discriminant becomes a
     capture-of-tr. ~4 corpus files (015_grep_advanced,
     017_grep_context, 018_grep_params, 019_grep_regex; the
     strong-POSIX form).

Without the sh renderer's cooperation these are IR-only — the chimera
gate's pass count does NOT move. The sh backend worker owns the
renderer (`backends/sh/src/sh_backend.rs`); the estree loop cannot
implement this (out of scope — renderer, not shared core).

**Separately, and in the same renderer pass:** the sh backend
currently emits `bash -c '<bash snippet>'` for constructs it can't
directly lower to POSIX (the residual — `[[` tests, c-style `for`,
complex `${var/pat/repl}`, `select`, etc.). In a bash-free sandbox
(the chimera BSD shell, dash, busybox sh) that fallback dies on the
spot. The fix: **the sh backend recursively renders its own bash
one-liner** before shelling out. `bash -c '<snippet>'` becomes
either (a) an *inline* sh function whose body is the recursively-
lowered POSIX snippet (the default — pure sh, no `sh -c`, no
runtime fork), OR (b) a portable `sh -c '<posix>'` (opt-in — dynamic,
subshell-isolated, runtime shell-out). Both are "POSIX native" in
the sense that the inner script is POSIX (not bash); they differ in
static-link vs dynamic-`sh -c`. This is the **third** piece of
renderer work this request covers.

## RENDERER CHANGES REQUIRED

### A. `IrStmt::Assign` with `IrExpr::Arith(ArithAst::Assign{compound})`

Today the sh renderer renders `let x+=1` (the OLD pre-transform shape)
as the broken `$(($( _num "x" )+=1)) -ne 0` (side-effect-free command
substitution, so x never gets assigned). With arith_forms, the IR is
now `Assign { targets: [x], expr: Arith(Assign{var:x, op:"+=",
rhs:Var(x)+1}) }`. The renderer must recognise
`IrExpr::Arith(ArithAst::Assign{var,op,rhs})` and emit `x=$((x + 1))`
(or `((x+=1))` — both POSIX-portable; pick the form the renderer's
existing test matrix prefers, with byte-identical output as the
gate's acceptance bar).

  * `ArithAst::Assign{op:"=", rhs}` → `x=$((rhs))`
  * `ArithAst::Assign{op:"+=", rhs}` → `x=$((x + rhs))` (or `((x+=rhs))`)
  * `ArithAst::Assign{op:"-=", "*=", "/="}` likewise
  * `ArithAst::IncDec{prefix,delta}` → `((x++))` / `((++x))` /
    `((x--))` / `((--x))` (POSIX `$((..))` supports these)

The Perl backend already does this (its `ArithAst::Assign` rendering
at `ir.rs::arith_ast_to_perl`); the sh renderer's corresponding
`sh_backend.rs` arm needs the equivalent.

### B. `IrStmt::Case` from grep_to_case

The sh renderer already renders `IrStmt::Case` natively
(011_brace_expansion passes through unchanged). The grep_to_case lift
produces the SAME `IrStmt::Case` shape — `discriminant:
IrExpr::Var("x", None)` (or `capture-of-tr` for `-i`), `clauses:
[(*PAT*) then, (*) else]`. Verify the existing Case rendering handles
the bare `Var("x")` discriminant (brace expansion's discriminant is
also a Var — so likely "just works"). For the `-i` capture-of-tr
discriminant (an `IrExpr::Call { func: "capture", args:
[Arrow([Exec("tr", ...)])] }`), the renderer's existing `capture`
dispatch should materialise the temp file; verify the Case rendering
nests the capture correctly.

The only NEW concern: the Case pattern with `?` in the source
(`grep 'a?b'`) refuses the lift (regex-vs-glob ambiguity, per the
core-request's REGEX-POLICY NOTE — `?` is refused). `*` and `[abc]`
pass through; these are already valid case globs. No new rendering
work — just verify.

### C. Recursive `bash -c` → POSIX lowering (static-link default; dynamic `sh -c` opt-in)

This is the **bigger** renderer change and the one the chimera sandbox
needs most. The sh backend currently emits `bash -c '<snippet>'` for
constructs it can't lower to POSIX. In a bash-free environment that
fallback dies. The recursion: parse the snippet back into IR via
the core's `ast_to_ir_raw`, render the sub-IR with the sh backend
itself (in-process — both the parser and the renderer live in the
sh backend binary, which links `debashl`), get a POSIX string. Then
emit one of two forms:

  **C-1. Static link (default, `--shir-in-sh --posix-native`):**
  inline the lowered POSIX snippet as a function definition in the
  emitted sh program, and call it at the original call site. Pure
  sh — no `sh -c`, no runtime fork, variables in scope (sh is
  dynamically scoped, so the function sees the caller's `$x`,
  `$IFS`, etc.). A unique function name (`__sh_sub_<hash>`) avoids
  collisions; the hash is over the snippet so identical snippets
  dedupe to one definition. This is the recommended default for
  the chimera sandbox AND the dev-box `sh` gate (both have no bash).

  Example. For `if [[ -f $x ]]; then A; else B; fi`, the recursion
  produces the POSIX snippet `[ -f "$x" ]`. The renderer emits:

  ```sh
  __sh_sub_a1b2c3d4() { [ -f "$x" ]; }
  if __sh_sub_a1b2c3d4; then A; else B; fi
  ```

  The function body is pure sh; the emitted program is pure sh; the
  gate is satisfied. The function name is `__sh_sub_<8 hex>` over
  the snippet bytes.

  **C-2. Dynamic portable `sh -c` (opt-in, `--shir-in-sh --posix-sh-c`):**
  emit `sh -c '<lowered posix>'` at the call site. The inner
  snippet is still POSIX (the recursion lowered it), but it's run
  in a new shell invocation (subshell-isolated: variables assigned
  in the snippet do NOT leak to the outer program). This is the
  right form when the snippet mutates outer-scope state and the
  caller wants isolation, OR when the caller prefers the
  self-contained "string of POSIX" form. Trade-off: a runtime
  fork+exec (slower), shell-escape the snippet (single-quote the
  whole string, escape internal `'` as `'\''`). The gate's output
  compare is the oracle — it tells you when the subshell isolation
  was load-bearing (a `($x=99; echo $x)` snippet: static-link
  mutates the outer `$x` to `99` and a later `echo $x` would
  differ; dynamic `sh -c` keeps the outer `$x` unchanged).

  Example. Same input, dynamic form:

  ```sh
  sh -c '[ -f "$x" ]'
  ```

  (the snippet is `[ -f "$x" ]` — POSIX, lowercased, no bash left).

  **The recursion — in-process, in the sh backend binary:**

  ```rust
  const MAX_RECURSION: u32 = 5;

  fn render_program(prog: &IrProgram) -> String { ... }  // existing

  fn lower_bash_c_fallback(snippet: &str, depth: u32)
      -> Result<String, Error>
  {
      if depth >= MAX_RECURSION { return Err(...); }  // base case
      // parse the bash snippet back into IR
      let cmds = parse_commands_from_text(snippet)?;    // core::parser
      let sub_prog = ast_to_ir_raw(&cmds);             // core::shir
      // recursively render it. If the sub-render emits ANOTHER
      // bash -c, lower_bash_c_fallback is called again on that
      // inner snippet — the depth limit catches non-termination.
      render_program(&sub_prog)
  }
  ```

  The renderer's call site, at the point where it would emit
  `bash -c '<snippet>'`:

  ```rust
  let posix = lower_bash_c_fallback(&snippet, 0)
      .map_err(|_| /* refuse loudly — bash -c is not an option
                       in a bash-free env, and the snippet refused
                       to lower */)?;
  if posix_native_mode {
      // static link: define a function + call it
      let name = format!("__sh_sub_{:x}", hash(&posix));
      out.push_str(&format!("{}() {{\n  {}\n}}\n", name, indent(&posix)));
      // call site (subshell-isolated if the snippet assigns to
      // outer-scope names — the gate's output compare is the oracle)
      out.push_str(&format!("(\n  {}\n) || return $?\n", name));
  } else if posix_sh_c_mode {
      // dynamic portable sh -c: shell-escape + emit
      let escaped = shell_escape_single_quotes(&posix);
      out.push_str(&format!("sh -c '{}'\n", escaped));
  } else {
      // legacy: bash -c (the dev-box-only back-compat path)
      out.push_str(&format!("bash -c '{}'\n", shell_escape_single_quotes(&snippet)));
  }
  ```

  **The shell escape for `sh -c`:** single-quote the whole POSIX
  string; replace any `'` in the string with `'\''` (close-open-
  escape-open, the standard POSIX `sh -c` escape). The POSIX output
  is itself sh source, so the only `'` it contains are the ones the
  backend emitted.

  **The recursion terminates** because each level either (a) lowers
  the snippet to pure POSIX (no further `bash -c` emitted →
  recursion stops) or (b) emits another `bash -c` at a deeper
  level (depth counter increments; at the depth limit, refuse).
  The only non-termination path is a snippet whose POSIX form
  STILL contains `bash -c` — the depth limit catches it. The
  common case (depth=1) covers everything the shared-core
  transforms (arith_forms, grep_to_case, process_subst) enable.

### D. The CLI (sh backend binary, all three modes)

```
# legacy: bash -c '<snippet>' (the dev-box-with-bash back-compat
# path). The chimera sandbox dies on this. Default for back-compat.
debashc --shir-in-sh -    < shir.json > program.sh

# DEFAULT for chimera + the dev sh-gate: static link. The
# recursion + inline (no sh -c). Pure sh, top to bottom.
debashc --shir-in-sh --posix-native -    < shir.json > program.sh

# opt-in: dynamic portable sh -c. The recursion + sh -c '<posix>'.
# Use when subshell isolation is wanted (the snippet mutates outer
# state and the caller needs the isolation) or when the caller
# prefers the "string of POSIX" form. A runtime fork; a shell
# escape on the snippet.
debashc --shir-in-sh --posix-sh-c -    < shir.json > program.sh

# the primitive — renders the sh BODY of a ShIR JSON (no
# shebang, no preamble). The recursion uses this internally;
# tests use it directly. Exposed for completeness even though
# the high-level modes are the user-facing ones.
debashc --shir-in-sh-fragment -    < shir.json > body.sh
```

The `--posix-native` is the recommended default for the chimera
sandbox AND the dev-box `sh` gate. The legacy `--shir-in-sh` stays
for back-compat (bodies that genuinely have `bash` available and
prefer the smaller emitted script).

## MINIMAL-CHANGE STRATEGY
- The sh worker is mid-corpus-grind (its own renderer improvements).
  This is a parallel, non-overlapping change: handle the new IR
  shapes in the existing `Assign` and `Case` render arms (A, B),
  and add the recursive lowering in the bash-`c` fallback path (C).
- Reuse the Perl backend's arith lowering as the spec (it already
  does this correctly); the sh rendering is the same arithmetic,
  POSIX-portable syntax.
- Reuse the sh renderer's existing `Capture` dispatch for the
  grep_to_case `-i` discriminant's `tr`-capture.
- The recursion (C) is in-process: the sh backend binary links
  `debashl` and calls `parse_commands_from_text` + `ast_to_ir_raw`
  + its own `render_program`. No subprocess overhead.
- Verify with the existing test surfaces: the 12-example + 4-example
  set (the chimera gate's `bad_translation.txt` shows the exact
  files) plus the dev-box `sh` quick-gate.

## FAILING-CASE
- `let "x+=1"; echo $x` → must print `2` under dash + busybox +
  BSD sh (today: prints `1` because the compound assignment ends up
  inside a command substitution subshell).
- `if echo "hello" | grep hel; then A; else B; fi` → `A` must run
  (the if-cond grep succeeds; the post-grep→case IR preserves that).
- `if echo "Hello" | grep -i hello; then A; else B; fi` → `A` must
  run (the discriminant is the lowercased capture-of-tr, the
  pattern is the lowered `*hello*`).
- `if [[ -f $x ]]; then A; else B; fi` (the bash-`[[` test) under
  `--posix-native` → the recursion produces `[ -f "$x" ]`; the
  emitted program has `__sh_sub_<h>() { [ -f "$x" ]; }` + a call;
  the gate is satisfied. Under `--posix-sh-c` → the emitted
  program has `sh -c '[ -f "$x" ]'` and the gate is satisfied.
  Under the legacy `--shir-in-sh` → `bash -c '[[ -f $x ]]'`; the
  chimera sandbox dies (no bash). The three modes differentiate.

## SCOPE / OWNERSHIP
Out of scope for the estree loop (renderer, not shared core). The sh
backend worker (`backends/sh/`) implements this directly in
`src/sh_backend.rs`. Filing here so a future pass / the user routes
it; the sh worker's next gate cycle will see the failures (the 12
arithmetic files + 4 grep files in the chimera gate's
`bad_translation.txt` and the residual bash-`c` failures the
recursion would now handle) and has the context to fix.
