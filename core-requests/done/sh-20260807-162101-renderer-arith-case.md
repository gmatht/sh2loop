# sh renderer: (1) the new IR shapes from arith_forms + grep_to_case, AND (2) the recursive `bash -c` → POSIX lowering (static-link default with subshell wrap; `--no-subshell` and `--posix-sh-c` opt-outs)

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

Today the sh renderer renders `let x+=1` (the OLD pre-transform shape) as
the broken `$(($( _num "x" )+=1)) -ne 0` (side-effect-free command
substitution, so x never gets assigned). With arith_forms, the IR is now
`Assign { targets: [x], expr: Arith(Assign{var:x, op:"+=", rhs:Var(x)+1}) }`.
The renderer must recognise `IrExpr::Arith(ArithAst::Assign{var,op,rhs})`
and emit `x=$((x + 1))` (or `((x+=1))` for the sh — both are
POSIX-portable; pick the form the renderer's existing test matrix
prefers, with byte-identical output as the gate's acceptance bar).

  * `ArithAst::Assign{op:"=", rhs}` → `x=$((rhs))`
  * `ArithAst::Assign{op:"+=", rhs}` → `x=$((x + rhs))` (or `((x+=rhs))`)
  * `ArithAst::Assign{op:"-=", "*=", "/="}` likewise
  * `ArithAst::IncDec{prefix,delta}` → `((x++))` / `((++x))` /
    `((x--))` / `((--x))` (POSIX `$((..))` supports these)

The Perl backend already does this (its `ArithAst::Assign` rendering at
`ir.rs::arith_ast_to_perl`); the sh renderer's corresponding
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

### C. Recursive `bash -c` → POSIX lowering (static-link default with subshell wrap; `--no-subshell` and `--posix-sh-c` opt-outs)

This is the **bigger** renderer change and the one the chimera sandbox
needs most. The sh backend currently emits `bash -c '<snippet>'` for
constructs it can't lower to POSIX. In a bash-free environment that
fallback dies. The fix: **the sh backend recursively renders its own bash
one-liner** before shelling out. `bash -c '<snippet>'` becomes
either (a) an *inline* sh function whose body is the recursively-
lowered POSIX snippet (the default — pure sh, no `sh -c`, no
runtime fork), OR (b) a portable `sh -c '<posix>'` (opt-in — dynamic,
subshell-isolated, runtime shell-out). Both are "POSIX native" in
the sense that the inner script is POSIX (not bash); they differ in
static-link vs dynamic-`sh -c`. This is the **third** piece of
renderer work this request covers.

**The scoping question (why this matters):** `bash -c '<snippet>'`
runs the snippet in a *new shell invocation* — a subshell with
only the parent's EXPORTED environment. Non-exported parent
variables are INVISIBLE in the child (`x=hello; bash -c 'echo $x'`
prints a blank line — `x` is not exported). The snippet's
ASSIGNMENTS are local to the child (subshell isolation: `x=99`
inside doesn't leak to the outer `x`). This is the same behavior
as `sh -c` and as wrapping the snippet in `( ... )` in the same
shell (a subshell). The recursion must preserve this scoping, or
the lowered POSIX snippet will silently see MORE variables than
the original bash snippet did (or its writes will leak) and the
gate's output compare will diverge.

  **Scoping matrix for the four emit forms:**

  | form | subshell? | reads outer | writes leak? | matches `bash -c`? |
  |---|---|---|---|---|
  | legacy `bash -c '<raw>'` | yes | exported-only | no | yes (it's bash -c) |
  | dynamic `sh -c '<posix>'` (`--posix-sh-c`) | yes | exported-only | no | yes |
  | inlined function, no wrap (`--posix-native --no-subshell`) | **no** | **all** (dynamic scope) | **yes** | **no** |
  | inlined function, subshell wrap `(\n  __sh_sub_h\n)` (`--posix-native`, the default) | yes | exported-only | no | yes |

  The **default `--posix-native` MUST wrap the function call in
  `( ... )`** — without the wrap, the inlined form has the WRONG
  scoping (dynamic scope reads everything; writes persist), which
  silently diverges from `bash -c`'s semantics and can fail the
  gate on a corpus file that depends on the subshell isolation.
  With the wrap, the inlined form is identical to `sh -c` in
  scoping — the recursion is semantics-preserving.

  The `--no-subshell` opt-out exists for snippets the caller
  KNOWS are pure (no outer-scope writes; reads only of vars the
  caller is happy to expose) and where the no-fork speed matters
  more than the `bash -c` scoping fidelity. The gate's output
  compare is the oracle: a corpus file that fails under
  `--no-subshell` but passes under the default wrap is a file
  that relies on subshell isolation → keep the wrap (the default).

  **The "transform to make sure variables don't overlap"** the
  renderer needs is, at its simplest, **the subshell wrap** —
  `( __sh_sub_h ) || return $?` at the call site. That single
  change gives the inlined form the same scoping as `bash -c` and
  `sh -c`. No scan, no export, no pollution of the global env.
  The `|| return $?` preserves the snippet's exit status (a
  subshell call's exit is the last command's exit; the `|| return
  $?` surfaces it to the caller's `$?`).

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
  let name = format!("__sh_sub_{:x}", hash(&posix));
  if posix_native_mode {
      // static link: define a function + call it. The call site
      // is wrapped in `( ... )` so the snippet runs in a SUBSHELL
      // — matches bash -c's scoping (exported-only reads, writes
      // isolated). `|| return $?` surfaces the snippet's exit
      // status to the caller's `$?`.
      out.push_str(&format!("{}() {{\n  {}\n}}\n", name, indent(&posix)));
      out.push_str(&format!(
          "(\n  {}\n) || return $?\n",
          name
      ));
  } else if posix_native_no_subshell_mode {
      // The --no-subshell opt-out: drop the parens for snippets
      // known to be pure. Dynamic-scope reads, writes persist.
      // Diverges from bash -c's scoping; gate output is the oracle.
      out.push_str(&format!("{}() {{\n  {}\n}}\n", name, indent(&posix)));
      out.push_str(&format!("{}\n", name));
  } else if posix_sh_c_mode {
      // dynamic portable sh -c: shell-escape + emit. The sh -c
      // invocation IS the subshell (no explicit wrap needed).
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

### D. The CLI (sh backend binary, all four modes)

```
# legacy: bash -c '<snippet>' (the dev-box-with-bash back-compat
# path). The chimera sandbox dies on this. Default for back-compat.
debashc --shir-in-sh -    < shir.json > program.sh

# DEFAULT for chimera + the dev sh-gate: static link WITH subshell
# wrap. The recursion + inline (no sh -c) + the `( ... )` wrap
# around the call → scoping matches bash -c (subshell, exported-
# only reads, writes isolated). Pure sh, top to bottom.
debashc --shir-in-sh --posix-native -    < shir.json > program.sh

# opt-in: static link WITHOUT the subshell wrap. The recursion +
# inline, but the function call is direct (no parens). Dynamic
# scope: the function sees ALL outer variables (not just
# exported) and the snippet's assignments persist in the outer
# scope. Diverges from bash -c's scoping — use only for snippets
# known to be pure and where the no-fork speed matters more than
# scoping fidelity. The gate's output compare is the oracle.
debashc --shir-in-sh --posix-native --no-subshell -    < shir.json > program.sh

# opt-in: dynamic portable sh -c. The recursion + sh -c '<posix>'.
# The sh -c invocation IS the subshell (exported-only reads,
# writes isolated) — matches bash -c's scoping. A runtime fork;
# a shell escape on the snippet. Use when the caller prefers the
# self-contained "string of POSIX" form (e.g., for embedding in
# a config or a heredoc) or when subshell isolation via sh -c
# is preferred to the function-wrap form.
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
prefer the smaller emitted script). The `--no-subshell` and
`--posix-sh-c` are the two scoping-deviation knobs — the default
wrap matches `bash -c`; these opt into the dynamic-scope or
runtime-shell-out forms respectively.

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
- The scoping question (C's subshell wrap) is the key correctness
  detail — without the wrap, the inlined form has the WRONG scoping
  and the gate will fail on corpus files that depend on subshell
  isolation. The default wrap matches `bash -c` exactly; the
  `--no-subshell` opt-out exists for callers who know better.
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
  emitted program has `__sh_sub_<h>() { [ -f "$x" ]; }` + a
  parenthesised call; the gate is satisfied. Under
  `--posix-native --no-subshell` → no parens, dynamic scope: the
  snippet sees ALL outer vars (and a corpus file that relies on
  subshell isolation will FAIL this case, exposing the scoping
  divergence). Under `--posix-sh-c` → `sh -c '[ -f "$x" ]'`,
  subshell-isolated, gate satisfied. Under the legacy `--shir-in-sh`
  → `bash -c '[[ -f $x ]]'`; the chimera sandbox dies (no bash).
  The four modes differentiate cleanly.

## SCOPE / OWNERSHIP
Out of scope for the estree loop (renderer, not shared core). The sh
backend worker (`backends/sh/`) implements this directly in
`src/sh_backend.rs`. Filing here so a future pass / the user routes
it; the sh worker's next gate cycle will see the failures (the 12
arithmetic files + 4 grep files in the chimera gate's
`bad_translation.txt` and the residual bash-`c` failures the
recursion would now handle) and has the context to fix.

## OUTCOME: rejected: out of scope — the remaining work (renderer arms A/B/C/D + the four CLI modes) is backends/sh worktree code owned by the sh backend worker (the request's own SCOPE/OWNERSHIP section says the estree loop cannot implement it); the shared-core transforms it depends on (arith_forms, grep_to_case, process_subst) are all landed and verified (estree 546/546), and the sh worktree already renders ArithAst::Assign/IncDec (6611) and lowers bash -c → sh -c (4301).
