# sh renderer: (1) the new IR shapes from arith_forms + grep_to_case, AND (2) the recursive `bash -c` → POSIX lowering (printenv-capture + subshell wrap, the corrected scoping)

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
`Assign { targets: [x], expr: Arith(Assign{var:x, op:"+=",
rhs:Var(x)+1}) }`. The renderer must recognise `IrExpr::Arith(ArithAst::Assign{var,op,rhs})`
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

### C. Recursive `bash -c` → POSIX lowering (printenv-capture + subshell wrap, the corrected scoping)

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

**The corrected scope-sanitization transform — `printenv` capture
+ subshell wrap at the call site (the empirical winner).** The
unset-prelude approach (the first attempt) failed the shadowing
test (T4) and the conditional-export test (T8) because the
inlined form's subshell is a fork (sees all) and no amount of
unsetting can make a fork match an exec's env-only reads. The
correct approach is to capture each shared variable's value
from the env at the call site, using `printenv` (which reads
ONLY the exported env, exactly what `bash -c`'s exec would
see), then call the inlined function inside a subshell (for
write-isolation). The full design — the user's
`printenv`-at-the-call-site insight — reproduces `bash -c`'s
exec-scoping exactly for all the test cases that matter.

The **correct call-site form** for a snippet that references
`$x`, `$y`, and `$z`:

```sh
(
  x="$(printenv x)"
  y="$(printenv y)"
  z="$(printenv z)"
  __sh_sub_a1b2c3d4
) || return $?
```

The `printenv VAR` reads ONLY the exported env (POSIX
behavior, available as a shell builtin in most sh
implementations and as `/usr/bin/printenv` everywhere). The
assignment `x="$(printenv x)"` sets the local `x` to the env
value. When the var is NOT in the env, `printenv VAR` exits
non-zero and prints nothing — the assignment becomes `x=""`
(matching `bash -c`'s "non-exported var is invisible"). When
the var IS exported, the assignment sets `x` to the exported
value. The subshell wrap isolates the snippet's writes (a
write inside the subshell doesn't leak to the outer program,
matching `bash -c`'s subshell-isolation). The `|| return $?`
preserves the snippet's exit status.

This handles every test case correctly:

  * **T1 (local var, not exported):** the program has `x=1` (no
    export). `printenv x` exits non-zero and prints nothing.
    `x=""`. The snippet sees `x=""` → `[]`. `bash -c` for the
    same program: the exec inherits the env (x not exported) →
    `[]`. Match.
  * **T2 (local var, EXPORTED):** `x=1; export x`. `printenv x`
    → "1". `x="1"`. Snippet sees `[1]`. `bash -c`: env has x=1
    → `[1]`. Match.
  * **T3 (inherited env var, program doesn't touch it):**
    `export FOO=env`. The program doesn't touch FOO. `printenv
    FOO` → "env" (the inherited export). `FOO="env"`. Snippet
    sees `[env]`. `bash -c`: env has FOO=env → `[env]`. Match.
  * **T4 (shadowing — the test the unset-prelude approach got
    wrong):** `export FOO=parent; FOO=local` (the assignment
    to an already-exported var updates the env to FOO=local).
    `printenv FOO` → "local". `FOO="local"`. Snippet sees
    `[local]`. `bash -c`: the exec inherits the env at exec
    time (FOO=local) → `[local]`. MATCH. The unset-prelude
    approach got this wrong (it cleared the var and the snippet
    saw empty). The printenv approach correctly captures the
    env-as-of-call-time, which is exactly what `bash -c` sees.
  * **T5 (locally-defined + exported, snippet in function
    scope):** `x=1; export x; f() { printenv x = 1 }`. Match.
  * **T6 (function-local var, snippet inside the function):** f
    has `local x=1` (not exported to the env). `printenv x`
    → empty. The snippet sees `[]`. `bash -c` from outside f
    (a fresh exec with the env that has no x) → `[]`. Match.
  * **T7 (var referenced, defined NOWHERE):** `printenv z` →
    empty. Snippet sees `[]`. `bash -c`: empty. Match.
  * **T8 (conditional export, cond=no, export didn't fire):**
    `printenv x` → empty (x not exported). Snippet sees `[]`.
    `bash -c`: env has no x → `[]`. Match.
  * **T9 (env-only read, program never touches it):** `printenv
    FOO` → "env". Snippet sees `[env]`. `bash -c`: `[env]`. Match.
  * **T10 (var defined in a program-internal subshell, snippet
    at top level):** the subshell's x=1 is local to that subshell.
    The snippet at the top level (after the subshell) sees
    `printenv x` → empty. Snippet sees `[]`. `bash -c`: env
    has no x → `[]`. Match.

The **empirical validation** (the test battery with 10 cases,
each in a fresh subshell to avoid state leakage between
cases): 10/10 PASS. The printenv + subshell approach
reproduces `bash -c`'s exec-scoping exactly.

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
    // static link: define a function + capture shared vars from
    // the env at the call site (the corrected scoping), then call
    // inside a subshell for write-isolation. The printenv
    // capture matches bash -c's exec-scoping exactly.
    let mut captures = String::new();
    for var in &snippet_vars {
        captures.push_str(&format!("  {}=\"$(printenv {})\"\n", var, var));
    }
    out.push_str(&format!("{}() {{\n  {}\n}}\n", name, indent(&posix)));
    out.push_str(&format!(
        "(\n{}{}\n) || return $?\n",
        captures,
        name
    ));
    // The `--no-subshell` opt-out: drop the parens for snippets
    // known to be pure. Dynamic-scope reads, writes persist.
    // Diverges from bash -c's scoping; gate output is the oracle.
} else if posix_native_no_subshell_mode {
    // emit the captures WITHOUT the subshell wrap
    out.push_str(&format!("{}() {{\n  {}\n}}\n", name, indent(&posix)));
    let mut inline = String::new();
    for var in &snippet_vars {
        inline.push_str(&format!("  {}=\"$(printenv {})\"; ", var, var));
    }
    out.push_str(&format!("{}{}\n", inline, name));
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

The renderer's call site, at the point where it would emit
`bash -c '<snippet>'`:

(Empirical validation note: the test battery with 10 cases,
each in a fresh subshell, 10/10 PASS. The printenv + subshell
approach reproduces `bash -c`'s exec-scoping exactly.)

**The two approaches the unset-prelude attempt tried** (now
superseded by the printenv approach, kept here for context):

  * **(a, superseded) Clear (unset) the locally-defined,
    non-exported vars the snippet references.** The unset
    prelude was the first attempt. It failed the shadowing
    test (T4) and the conditional-export test (T8) because the
    subshell is a fork (sees all state) and no amount of
    unsetting can make a fork match an exec's env-only reads.
    The printenv approach (above) replaces it.

  * **(b, alternative) Rename + pass as args.** The snippet's
    variable references are renamed to unique names
    (`__sh_sub_h__x`, `__sh_sub_h__y`, …) and the outer values
    are passed as positional args. The snippet sees ONLY the
    values it was given. More invasive than the printenv
    approach; the printenv approach achieves the same scoping
    result with less rewriting (no rename, no variable-capture
    analysis pass).

  The **(c) sidestep** remains: `--posix-sh-c` (the dynamic
  form) gives `bash -c`'s exec-scoping NATIVELY — no transform
  needed, no analysis pass, no fork-scoping leak. The cost is a
  runtime fork+exec. For corpus files that prefer the
  self-contained "string of POSIX" form, this is the right pick.

  **The design, in summary.** The inlined form's scoping is
  correct (matches `bash -c`) via:
  `( x="$(printenv x)"; y="$(printenv y)"; ...; __sh_sub_h ) || return $?`
  — the subshell wrap for write-isolation, the printenv capture
  for env-only reads (matching `bash -c`). The renderer
  identifies the snippet's referenced variables (parse the
  snippet) and emits the captures at the call site. The
  printenv is POSIX (via coreutils or shell builtin). The
  captures are emitted in name-sorted order for determinism.
  The gate's output compare is the oracle for whether the
  scoping is right for a given corpus file — and the test
  battery confirms it is for all the meaningful cases.

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

# DEFAULT for chimera + the dev sh-gate: static link WITH
# printenv capture + subshell wrap. The recursion + inline
# (no sh -c) + `( x="$(printenv x)"; y="..."; ...; __sh_sub_h )`
# — scoping matches bash -c exactly (printenv reads ONLY the
# exported env, the subshell isolates the snippet's writes).
# Pure sh, top to bottom.
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
printenv capture + subshell wrap matches `bash -c`; these opt
into the dynamic-scope or runtime-shell-out forms respectively.

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
- The scoping design (C's printenv capture + subshell wrap) is
  the key correctness detail — it reproduces `bash -c`'s
  exec-scoping for every test case (the test battery confirms
  10/10). No analysis of "is this var locally-defined or
  exported" is needed — printenv reads the env at call-site time,
  which is exactly what `bash -c`'s exec would see.
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
  parenthesised call with printenv captures; the gate is
  satisfied. Under `--posix-native --no-subshell` → no parens,
  dynamic scope: the snippet sees ALL outer vars (and a
  corpus file that relies on the exported-only isolation will
  FAIL this case, exposing the scoping divergence). Under
  `--posix-sh-c` → `sh -c '[ -f "$x" ]'`, exec-scoping, gate
  satisfied. Under the legacy `--shir-in-sh` → `bash -c '[[ -f
  $x ]]'`; the chimera sandbox dies (no bash). The four modes
  differentiate cleanly.

## SCOPE / OWNERSHIP
Out of scope for the estree loop (renderer, not shared core). The sh
backend worker (`backends/sh/`) implements this directly in
`src/sh_backend.rs`. Filing here so a future pass / the user routes
it; the sh worker's next gate cycle will see the failures (the 12
arithmetic files + 4 grep files in the chimera gate's
`bad_translation.txt` and the residual bash-`c` failures the
recursion would now handle) and has the context to fix.

## EMPIRICAL VALIDATION (the scoping test battery)

The scoping design was validated against 10 test cases run
with `bash` (the canonical POSIX/extension semantics on this box).
Each test runs in a fresh subshell to avoid state leakage between
cases. The inlined form is the printenv-capture + subshell call
site form. The `bash -c` reference is constructed to mirror the
same env. Results (10/10 PASS):

  T1  local var, not exported                    [both: []      ]
  T2  local var, EXPORTED                        [both: [1]     ]
  T3  inherited env var, program doesn't touch   [both: [env]   ]
  T4  shadowing (parent exports, program local)   [both: [local] ]
  T5  local + exported, snippet in function      [both: [1]     ]
  T6  function-local var, snippet inside f       [both: []      ]
  T7  var referenced, defined NOWHERE             [both: []      ]
  T8  conditional export (cond=no)                [both: []      ]
  T9  env-only read, program never touches       [both: [env]   ]
  T10 var in program-internal subshell, snippet
      at top level                                 [both: top: []  ]

The unset-prelude approach (the first attempt) failed T4 and
T8 (the shadowing and conditional-export cases) because a fork
cannot match an exec's env-only reads. The printenv capture at
the call site is the correct approach: it reads ONLY the exported
env, matching `bash -c`'s scoping. Combined with the subshell
wrap (write-isolation), the full design reproduces `bash -c`'s
exec-scoping exactly.
