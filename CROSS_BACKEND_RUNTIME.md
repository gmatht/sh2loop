# Cross-Backend Runtime — the sh2.* polyfills written once, transpiled everywhere

Status: DRAFT (2026-08-26). Companion to PLAN.md; the plan remains the
authority. This doc covers one work item: **the pure-CPU core of the
`sh2.*` runtime, authored once in bash, transpiled per-backend by the
same pipeline that transpiles user programs.**

## 1. The problem

Every backend re-implements the `sh2.*` runtime semantics in its own
language. The reference implementation (`harness/sh2-namespace.mjs`,
8,777 lines, 189 functions) is hand-written JS; the C backend has its
own runtime helpers; Java has `__shRun`; the other backends have partial
or missing runtimes. The pure-CPU core — parameter expansion, test
evaluation, glob/case matching, brace expansion, arithmetic fallback,
string/array/text ops — is the *subtle* half (param expansion is the
hardest part of bash semantics) and it is duplicated per backend, with
drift risk.

**Backend consumption guide: `runtime/README.md`** — how to transpile,
link, adapt, and verify the polyfills per backend.

## 2. The idea

Write the pure-CPU runtime functions **once in bash** (the source
language the transpiler already handles), transpile them per-backend at
build time, and ship the transpiled polyfills as the runtime for
backends that lack one. For backends that already have a hand-written
runtime (ESTree/JS), keep the hand-written one and **benchmark
polyfill vs hand-written** before any swap.

```
runtime/polyfills.sh (bash, authored once)
        │  debashc file --estree / --target <lang>   (build time)
        ▼
polyfills.js  polyfills.c  polyfills.py  …   (per-backend native code)
        │
        ▼
backends that lack a runtime link the polyfills; JS/ESTree benchmarks first
```

Key properties:

- **Transpiled, not interpreted** — the polyfills are native code in
  each backend, produced by the same pipeline that compiles user
  programs. No interpreter, no per-backend runtime engine.
- **Native idioms stay preferred** — the M8 lowering ladder is
  unchanged. The polyfills are the *fallback seam*; the ladder keeps
  reducing how often the seam is called.
- **The polyfill source is a corpus program** — a fixed, known bash
  program that must transpile correctly on every backend. Runtime
  failures become loud (every generated program links it), and the
  corpus gate enforces the construct-set constraint.
- **The polyfill source is the executable spec** — semantics defined by
  `polyfills.sh` (runnable under bash directly) instead of prose + a
  hand-written reference.

## 3. Scope: pure-CPU core vs host-bound seam

**In scope (pure-CPU, written once in bash):**

| callee | semantics | hand-written ref |
|---|---|---|
| `param` | parameter expansion (`${x//p/r}`, `${x:0:5}`, case mods, `#`/`%` strips, defaults) | sh2-namespace.mjs:3266 |
| `test` / `testArith` | test-expression parser/evaluator | :1312 |
| `caseMatch` | glob matching (parseGlob/matchEnds) | :1837 |
| `brace` | brace expansion cross-product | :3699 |
| `arith`/`arithEval`/`fparith`/`idiv`/`imod` | arithmetic evaluator fallback | :3601 |
| `contains`, `grepText`, `cutText`, `grepMatches` | text ops | :1860 |
| `basename`, `dirname` | path string ops | :1410/:1474 |
| `strLen`, `strSlice`, `strSplit`, `strReplaceAll`, `strCompare`, `strHasPrefix`, `strHasSuffix`, `strCount`, `strLastIndex`, `strIndex`, `joinSep`, `strContainsAny` | string primitives | :2338–2563 |
| `setArray`, `arrayIndex`, `arrayLen`, `arrayItems`, `arrayKeys`, `arrayStore`, `listVar`, `join` | array primitives | :2961 |
| `fieldSplit`, `split` | word splitting | :1545 |
| `zshParamFlags` | zsh param flags | :3479 |
| `ternary`, `not`, `guard`, `shopt` | small pure helpers | :1243/:3683 |

**Out of scope (host-bound, stays per-backend):** `exec`, `_runProc`,
`builtin`, `pipeline`, `redirect`, `capture`, `captureWords`, `fs.*`,
`background`, `subshell`, `exit`, `readLine`, `eachLine`, `walkLines`,
`mktemp`, `date`, `uname`, `hostname`, `readlink`, `whoami`, the state
registers (`getVar`/`setVar`/`positional`/`lastExit`/`shoptState`/
`functions`), and error-`.code` semantics. These are thin wrappers over
host APIs and cannot be written in bash without recursing (the
polyfills' own I/O would lower to sh2.* calls).

## 4. The construct-set constraint

The polyfill source is written in a **transpiler-friendly bash subset**:
constructs the transpiler handles correctly on all target backends.
Verified examples:

- `[[ "$x" == *"$y"* ]]` transpiles correctly (substring/glob test).
- `case "$x" in *"$y"*)` does NOT (the pattern is emitted literally,
  `$y` unexpanded — a pre-existing transpiler gap; avoid quoted vars in
  case patterns).

The constraint is enforced by the corpus gate: the polyfill source is a
corpus program that must pass on every backend. When the transpiler
improves, the polyfills can use more constructs.

## 5. Rollout

1. **M1 — plan + first polyfill batch (this doc + `runtime/polyfills.sh`).**
   Author the first pure-CPU functions in bash; transpile to JS; verify
   against bash and the hand-written runtime on a test battery.
2. **M2 — benchmark (ESTree/JS).** Polyfill vs hand-written
   `sh2-namespace.mjs` on the same inputs: correctness (byte-equal
   results) and performance (ops/sec on hot functions: `param`, `test`,
   `caseMatch`, `contains`). Swap only when the polyfill matches or
   wins; keep the hand-written runtime otherwise.
3. **M3 — polyfill library.** Complete the in-scope callee list in
   `polyfills.sh` (param/test/caseMatch/brace/arith fallback/string/
   array/text ops).
4. **M4 — per-backend transpilation + linking.** Build-time generation
   of `polyfills.<lang>` for backends that lack a runtime (C, Java,
   Python, …); wire into their gates. Backends with a hand-written
   runtime keep it until M2 says otherwise.
5. **M5 — runtime test battery.** Edge cases beyond the corpus
   (`${x//p/r}` with special chars, test precedence, glob corner cases),
   run once against bash, then against every transpiled polyfill.

## 6. Guardrails

- **Corpus gate is the hard gate** — the polyfill source is a corpus
  program; a regression on any backend → fix or revert, never bless.
- **Determinism** — transpiled polyfills are byte-identical build
  artifacts (the transpiler is deterministic).
- **No regression to the hand-written runtimes** — JS/ESTree keeps
  `sh2-namespace.mjs` until the benchmark says the polyfill is
  equivalent or better.
- **Never `git add .`** — stage explicit paths (workspace rule).
- **sh2perl stays standalone** — the polyfill source lives in the
  workspace for now; the canonical home (likely sh2perl, since the
  transpiler generates the runtimes) is a decision for M4.

## 7. Current status

- 2026-08-27: **M3 COMPLETE — all planned polyfills landed**
  (`runtime/polyfills.sh`, 21 functions + 4 helpers): `test` (the
  self-containment keystone — tokenizer + parser + evaluator),
  `brace` (dynamic groups, cross-product; interface prefix/suffix/
  ngroups/groups — the adapter maps sh2.brace's array shape), `param`
  extglob + nocasematch (test's third arg). Plus the first
  IO-composition helpers: `wcLines`/`headLines`/`tailLines` (pure
  line cores of wc/head/tail via the string primitives) and
  `line_count`/`line_at` (newline-separated string access). All
  byte-identical to bash on the full self-test battery. Host-bound
  param ops (`:=`/`:?` side effects, `$ref`-expansion) are ADAPTER
  responsibilities — pure polyfills cannot write the store or exit.
- 2026-08-27: **transpiler/runtime fixes landed** (each with tests):
  heredoc/herestring `$var` targets counted as reads (never-written
  fold + dead-store-elim); runtime read-cursor reset per string
  redirect; case-pattern alternation splitting (`==|=` → `==` or `=`);
  native-echo capture sites + call-graph closure (recursive matcher
  output leaked); `$((...))` slice wrapper; dead-fn-elim ForInit
  bodies walked. These unblocked the `test`/extglob/brace polyfills.
- 2026-08-26: pipeline proven end-to-end
- 2026-08-26: pipeline proven end-to-end — a bash function transpiles
  via `debashc file --estree` → ESTree JSON → `estree-runner.mjs` →
  runs; function definition (`sh2.functions.set`) + call
  (`sh2.fnCall`) mechanism works. Construct-set constraint verified
  (`[[ ]]` form OK, case-pattern-with-quoted-var not).
- 2026-08-26: **transpiler bug fixed** — `s="${s%/}"` (parameter-
  expansion self-assignment) panicked the ESTree emitter
  ("lifted var assigned an unanalysed source", shir.rs:16752): the
  local-lift walker skips the store mark for `param` name args (the
  emitter inlines the value for lifted names), but the
  assignment-position emitter lacked the `param` arm. Added the arm
  (delegates to the general param emission, which injects the native
  value as the trailing override). `cargo test --lib` 386/386;
  estree corpus prefix 13/13. This widens the construct-set for every
  backend.
- 2026-08-26: **first polyfill batch landed** — `runtime/polyfills.sh`
  (basename, dirname, strLen, strHasPrefix, strHasSuffix, contains),
  transpiled output **byte-identical to bash** on the full battery
  (16 paths × basename/dirname vs GNU tools, strLen, prefix/suffix,
  contains incl. empty-string edges).
- 2026-08-26: **M3 progress — string-primitive batch landed**
  (`runtime/polyfills.sh` now 14 functions: +strSlice, strCompare,
  strIndex, strLastIndex, strCount, strReplaceAll, strContainsAny,
  joinSep), transpiled output **byte-identical to bash** on the full
  self-test battery. Three transpiler fixes landed to get there:
  (a) `interp_pattern_expr` — param patterns with `$ref`s
  (`${s%%"$sep"*}`) now lower natively (the runtime's stripGlob* never
  expands patterns); full shape matrix (P / *P / P* × #/##/%/%%),
  store-var single-eval wrap applied to every shape; (b) the
  module-level string lift excludes function-local names (a stale
  program-level binding was hoisted for store-bound locals); (c) the
  local-lift is all-or-nothing per multi-var decl + mixed decls split
  (lifted names → native bindings, rest → runtime local call).
  `cargo test --lib` 386/386. Known remaining gap: the same ref-pattern
  lowering in ECHO position (the `_g` wrap is dropped there — a
  pre-existing echo-path gap, not a regression).
- 2026-08-26: **M3 progress — glob matching landed** (`globMatch` +
  `caseMatch`, 16 functions total), transpiled output **byte-identical
  to bash** on the full battery (star/any/class/negated-class/escape/
  empty/multi-star + caseMatch first-match). Construct-set findings:
  `[[ $(fn) == "1" ]]` lowers to a runtime test with a literal `$(...)`
  — capture into a variable first; the runtime's test treats QUOTED
  `?`/`*`/`[` as globs (bash treats them literal) — dispatch on
  metachars via `case "$c" in \*|\?|\[)` (escaped patterns work);
  `${#p}` in test strings fails — use `(( plen > 1 ))`; nested
  `${rest:0:${#close}}` slices break the parser — precompute lengths.
  Limitations (first cut): no extglob, no nocasematch, no
  pattern-`$()`-expansion.
- 2026-08-26: **M3 progress — param dispatcher landed** (17 functions
  total): len, case mods (`^^`/`,,`/`^`/`,`), `:-` default, `#`/`##`/
  `%`/`%%` glob strips (scan + globMatch), `/`/`//` literal replace,
  slice — byte-identical to bash. Construct-set findings: `#)`/`##)`
  case patterns are COMMENT STARTERS in bash — quote them (`'#'`);
  `${v,}` (first-char lowercase) is a parser gap — use
  `${first,,}${rest}` manually.
- 2026-08-26: **M4 pilot — C backend blocker found.** The polyfills
  transpile to C (1501 lines, compiles) but the C renderer ABORTS on
  the while-loop + param self-assignment (`s="${s%/}"` in basename):
  the var is declared as raw `char*` (storage-class selection) but the
  loop assignment emits `_sh_mstr_set(&s, ...)` (managed) — a
  storage-class inconsistency in `src/c_backend.rs` (the C workers'
  territory). M4 wiring is blocked until the C renderer fixes it.
- 2026-08-26: **backend consumption guide** — `runtime/README.md`
  (transpile → link → adapter → dependency closure → self-test oracle →
  construct-set constraint → rollout status).
- 2026-08-26: **M2 benchmark (ESTree/JS) — polyfill vs hand-written**
  (`runtime/bench-polyfills.mjs`):

  | function | hand-written | polyfill (adapter) | ratio |
  |---|---|---|---|
  | basename | 12.8M ops/s | 43.7K ops/s | ~294× |
  | dirname | 6.9M ops/s | 36.6K ops/s | ~187× |
  | strLen | 26.7M ops/s | 1.29M ops/s | ~21× |
  | contains | 10.2M ops/s | 27.3K ops/s | ~374× |
  | strHasPrefix | 10.7M ops/s | 40.4K ops/s | ~264× |

  The polyfill is 20–370× slower on JS. Breakdown: (a) the adapter
  (stdout sink + fnCall dispatch + positional setup) dominates —
  strLen's simple body is only 21×; (b) the transpiled bodies call
  `sh2.test` for `[[ ]]` conditions and write `sh2.lastExit` per
  statement — runtime-call overhead the transpiler's native test
  lowering will shrink; (c) the transpiled functions use the NATIVE
  echo path (`process.stdout.write`), which bypasses the runtime's
  `captureSync` (fdTargets) — the adapter must sink
  `process.stdout.write` directly.

  **Decision (M2): JS/ESTree keeps the hand-written runtime.** The
  polyfill's value is single-source correctness for backends that
  LACK a runtime (C, Java, Python, …) — where the alternative is no
  runtime at all — not speed on JS. Re-benchmark after the native
  test lowering lands; the strLen result (21×) shows the gap is
  mostly adapter + dispatch, not computation.

## 8. Polyfill speedup plan — cross-backend shIR→shIR transforms (M2 follow-up)

Fresh benchmark (2026-08-27, current emitter — the M2 table above is
stale, it predates the native test lowering): every benchmarked polyfill
is still 39–650× slower than the hand-written ESTree runtime
(`runtime/bench-polyfills.mjs`): contains ~650×, basename ~300×,
strHasPrefix ~234×, dirname ~164×, strLen ~39×. The unbenchmarked ones
(globMatch, caseMatch, param #/##/%/%%, strCount, strReplaceAll,
strContainsAny) are structurally worse — loops + recursion + nested
calls. Call-site census of the transpiled polyfill (current emitter):
16 `sh2.test` string dispatches, 194 `sh2.lastExit` writes, 92
`sh2.fnCall`, 38 `sh2.positional` reads, 22 `sh2.setVar`, 52
`process.stdout.write`.

Three cross-backend shIR→shIR transforms attack the overhead, cheap
high-value first. All live in `src/transforms/` (one file, self-
contained, REFUSE > GUESS, every backend benefits); the estree-side
renderer hooks are listed per transform.

### 8.1 T1 — test-lowering: glob-affix `[[ ]]` → native primitives

**Problem.** The polyfill's hot conditions are glob-affix tests with
VARIABLE patterns — `[[ "$s" == "$p"* ]]`, `[[ "$s" == *"$p"* ]]`,
`[[ "$s" == *"$p" ]]` — and they all dispatch `sh2.test("...")` with
the test as a STRING (runtime tokenize + parse + glob match per
evaluation). The emitter's native test lowering (`try_native_glob_test`)
only handles LITERAL patterns (`[ "$x" = *P* ]` → `.includes(P)`); a
`$`-containing pattern is refused (`glob_to_regex` rejects it), and
`str_operand` reads only `is_lifted_str` (a local-lifted var — the
polyfill's `local s="$1"` — is not in that set, so even literal-pattern
tests like `[[ "$s" == */ ]]` stay runtime).

**Transform.** `src/transforms/test_lowering.rs` rewrites a `test` Call
whose text is a glob-affix shape with plain-var/literal operands to a
boolean-returning primitive call:

| test text | rewrite |
|---|---|
| `"$s"=="$p"*` | `strHasPrefix(s, p)` |
| `"$s"==*"$p"*` | `contains(s, p)` |
| `"$s"==*"$p"` | `strHasSuffix(s, p)` |
| `"$s"==*/` | `strHasSuffix(s, "/")` |
| `"$s"==/*` | `strHasPrefix(s, "/")` |
| `!=` variants | `Not(...)` of the above |

Guards: (a) fires only in If/While cond position whose status write is
provably unread (a simplified Plan-4 backward scan — the polyfill never
reads `$?` after a test); (b) refuses when the enclosing function is the
target primitive itself (the polyfill's own `contains` body must not
call `sh2.contains` — the adapter would recurse infinitely).

**Renderer hooks.** The estree emitter already lowers `Call "contains"`
natively (`String(h).includes(n)`, status-recording inside `&&`/`||`);
add the twin arms for `strHasPrefix`/`strHasSuffix` (`startsWith`/
`endsWith`). Also fix `str_operand` to read local-lifted vars (the
literal-pattern tests then lower natively too).

### 8.2 T2 — lastExit dead-store elimination

The `sh2.lastExit` writes are EMITTER-synthesized (the shIR has no
status nodes), so the cross-backend form is an ANALYSIS transform
(per-statement "status write is dead" verdicts into a static, like
`sync-ok-loops`) + per-backend renderer hooks that skip the write. The
estree side already has Plan 4 (`compute_lastexit_deadness` in
`shir.rs` — covers native `(( ))`, echo/printf, bare `[ ]` tests,
empty-else ifs); the polyfill's remaining writes come from the
native-decl `builtin("local")` path (`try_native_local_decl_stmt`'s
trailing `(sh2.lastExit = 0, true)`) and the loop wrappers. Extend Plan
4 to mark those dead when unread and consult in the emission.

### 8.3 T3 — echo-return lifting (value-returning function convention)

The bash function convention (positional in, stdout out) forces the
adapter's stdout sink + newline strip — the dominant cost (strLen's
one-liner body is still 39×, almost all adapter). The runtime already
has the value-returning dispatch (`sh2.fnValue`, used by the C
frontend). The transform recognizes the "echo a value and return" tail
shape (pure-output body, single echo tail, no other stdout writes),
rewrites the tail to a native value return, and rewrites in-program
call sites `fnCall` → `fnValue`. The per-backend adapter must switch to
`fnValue` for the marked functions (linking concern, documented per
backend). Bigger change (calling convention); design + recognition
analysis first, renderer wiring per backend.

**Design (implemented, `src/transforms/echo_return.rs`):**

1. **Recognition** — a function whose body is pure (no exec/capture/
   redirect/background/subshell/file-write/`$?`) and where EVERY path
   through the body emits EXACTLY ONE single-arg `echo` (no `-n`/`-e`,
   no multi-word output). A small state machine over {Need, Done, Dead}
   tracks each live path's echo count: an If unions over its arms; a
   loop whose body never reaches `Done` (an echo without a return would
   re-echo per iteration) is allowed; a bare `return` is only legal
   AFTER an echo on its path (a no-output return path loses the value).
   REFUSE > GUESS: any impure construct, a 0/2+-echo path, or a return
   inside a loop body (the runtime-loop callback lowers a return to the
   `sh2.return` SIGNAL — the value channel is lost there) refuses.
2. **Body rewrite** — every value echo becomes `Return(Some(value))`;
   the trailing bare `return`s are dropped (unreachable). The estree
   emitter renders `Return` natively (no new arms) and `Call("fnValue")`
   via the general call path (`sh2.fnValue(...)`); the perl renderer
   gained the `fnValue` sub-call arms (statement + expression paths in
   `ir.rs`). The recognized bodies are provably await-free, so the
   define arrows stay on the SYNC path — `fnValue` returns the raw
   value, not a Promise.
3. **Call-site rewrite** — every call of a recognized function (the
   shIR `exec("f", [args])` / `fnCall` shape) becomes
   `exec("echo", [fnValue("f", [args])])` — the value + newline the
   original echo produced, and the echo's status (0) == the original
   function's status. A CAPTURE of an eligible function collapses to
   the bare `fnValue` result (no stdout round-trip). The rewrite
   descends into function bodies (the param/globMatch dispatchers'
   captures of now-eligible primitives) and `case` bodies.

**Benchmark (fnValue adapter, current emitter):** T3 adds on top of
T1+T2: strLen ~5.5×, basename/dirname ~2.6-3×, contains/strHasPrefix
~1.8-2×. Cumulative vs the pre-T1 baseline: basename ~107×, dirname
~167×, strLen ~16×, contains ~5×, strHasPrefix ~3×.

### 8.4 Status

- 2026-08-27: **T1 landed** — `src/transforms/test_lowering.rs`
  (glob-affix `[[ ]]` tests with variable patterns →
  `strHasPrefix`/`strHasSuffix`/`contains`; guards: status-liveness
  backward scan (Plan 4's lastexit_scan_top_read), self-recursion
  guard) + emitter hooks (`str_operand` reads local-lifted vars;
  native `strHasPrefix`/`strHasSuffix` arms mirroring `contains` →
  `startsWith`/`endsWith`). Polyfill self-test diff identical; estree
  corpus 545/551 (the 6 reds are pre-existing, confirmed on baseline);
  perl corpus 266/285 (baseline-identical); lib tests 390/390.
  Benchmark (`runtime/bench-polyfills.mjs`, current emitter):
  basename 21.2K → 868K ops/s (~41×), dirname 15.2K → 847K (~56×),
  strLen 487K → 1.39M (~2.9×), contains 13.4K → 37K (~2.8×),
  strHasPrefix 28.1K → 44K (~1.6×). The `sh2.test` string dispatches
  dropped 16 → 7 (the 7 remaining are the self-recursion-guarded
  primitive bodies, param-slice operands, and liveness-guarded nested
  conds). The strCount/strReplaceAll/strContainsAny/strIndex/strLastIndex
  loops and the basename/dirname loop guards now lower natively
  (`.includes`/`.endsWith` — no per-iteration test-string parse).

- 2026-08-27: **T2 landed (estree side)** — lastExit dead-store
  elimination extended to the native-decl `local`/`declare` path
  (`try_native_local_decl_stmt_dead` twin) and made function-body-
  aware: the define arrow CLONES the body, so the global pointer-keyed
  deadness map never matched the clone's statements (a latent Plan 4
  gap — dead-write drops never fired inside function bodies). The
  Function arm now computes the clone's deadness into the
  `ARROW_BODY_DEAD`/`ARROW_BODY_COND_DEAD` statics for the duration of
  the arrow construction (save/restore; the clone's statements are alive
  then — the pointer keys cannot collide; the optimistic body emission
  in `fn_call_sync_set` skips — its clones are dropped right after).
  Polyfill lastExit writes 194 → ~139; the `_g` status protocol on the
  loop conds is gone (bare boolean conditions). Benchmark adds ~1.5× on
  top of T1. The cross-backend analysis-transform form (verdict statics
  + per-backend renderer hooks) remains the follow-up for C/Go/…

- 2026-08-27: **T3 landed** — `src/transforms/echo_return.rs`
  (recognition + body rewrite to native `Return(Some(v))` + call-site
  rewrite to `exec("echo", [fnValue(...)])` / capture-collapse to the
  bare `fnValue`), the perl renderer's `fnValue` sub-call arms
  (`src/ir.rs`), and the bench adapter switched to `sh2.fnValue`.
  Polyfill self-test diff identical; estree corpus 545/551 (the 6 reds
  pre-existing); perl corpus 267/284 (baseline 266/285 — one MORE pass,
  zero regressions); lib tests 398/398 (3 new echo-return tests).
  Benchmark: see §8.3 — cumulative basename ~107×, dirname ~167×,
  strLen ~16×, contains ~5×, strHasPrefix ~3× vs the pre-T1 baseline.

- 2026-08-27: **follow-up items 1–3 (the remaining structural gaps)**:
  - **Item 1 (return-in-loop → flag+break) LANDED** —
    `src/transforms/loop_return_lift.rs` (registered before
    echo-return): a loop whose body has `if C; then echo "$v";
    return; fi` is rewritten to a fresh `__sh2_found` flag + `break`,
    with the post-loop statements moved into the new if's else.
    `strContainsAny` is now echo-return-lifted (native value return,
    no stdout sink). `line_at` gets the flag+break (no more
    return-in-loop) but stays NON-liftable: its no-match path emits
    NOTHING, which the value channel cannot express (a value-returning
    version would print an empty line where bash prints nothing).
    Verified: self-test identical; estree 545/551; perl 267/284;
    lib 401/401 (2 new tests).
  - **Item 2 (test-parser token-accumulation) DEFERRED — SCC
    recognition LANDED** — the token-accumulation rewrite of
    tokenizeTest remains the concurrent worker's territory (the test
    polyfill is its self-containment keystone; the file changes under
    us). What landed instead is the recognition that makes that work
    easier: `src/shir_passes/scc.rs` — a shared call-graph
    strongly-connected-component analysis (Tarjan; `build_call_graph`,
    `tarjan_sccs`, `scc_index`/`scc_of`), wired into the pipeline as
    the `FunctionScc` analysis populating `PassContext.function_sccs`.
    The `test` parser's evaluator cluster (`eval_or` ↔ `eval_and` ↔
    `eval_not` ↔ `eval_primary`) is recognized as ONE SCC (unit-tested),
    so a transform can reason about the whole parser cluster at once
    instead of being defeated by a single-function fixpoint.
  - **Item 3 (glob-matcher pattern lift) LANDED (SCC-based
    echo-return)** — the echo-return eligibility fixpoint now iterates
    over the call graph's SCCs (the shared `shir_passes::scc` Tarjan)
    instead of single functions: the matchers' MUTUAL recursion
    (globMatch ↔ ext_alt_match ↔ ext_match) is recognized as a WHOLE
    under the coinductive assumption that same-SCC captures are pure.
    Two enablers: (a) `loop_return_lift` descends into `case` clause
    bodies (the matchers' `if [[ "$m" == "1" ]]; then echo 1;
    return; fi` lives inside a case clause); (b) `rewrite_stmt` no
    longer shadows the bare-call-to-eligible arm behind the value-echo
    arm — the bare `ext_match "$c" "$p" "$v"` recursion inside
    globMatch was left for pass 3 to wrap in an ECHO (printing the
    value instead of returning it — the extra-`0` self-test
    regression); it is now a value return of the fnValue result.
    Result: globMatch/ext_match/ext_alt_match/param echo-return-lifted
    (native value return, no stdout sink); polyfill self-test
    byte-identical; perl corpus 268/283 (2 more passes:
    040_process_substitution_comm, 061_test_local_names_preserved);
    estree 545/551; lib 406/407 (the 1 red is the concurrent worker's
    in-flight sh_backend grep_p test, red on baseline too).
    `caseMatch` stays non-liftable (its no-match path emits nothing —
    the same value-channel limitation as `line_at`).

## 9. Findings so far (construct-set + runtime notes)

- `[[ "$x" == *"$y"* ]]` transpiles correctly; `case "$x" in *"$y"*)`
  does NOT (pattern emitted literally, `$y` unexpanded).
- `${s##*/}` / `${s%/*}` lower to trailing-slash-aware expressions
  (basename/dirname semantics) — MORE correct than bash's actual
  pattern-removal for the dirname/basename use case; the polyfill
  source must still be written to match real bash (the while-loop
  strip + root guard), and source == transpiled is verified by diff.
- Functions are emitted only when CALLED (plus builtin-named special
  cases) — the polyfill file's self-test calls force emission AND are
  the correctness oracle.
- `source` is not inlined (dynamic-write treatment) — the polyfill
  links as a transpiled module, not via source.
- `_installStdoutBuffer` swallows `console.log` (flushed only at
  `_finish`) — benchmark JSON must go to a file, not stdout.
- The transpiled polyfill functions use the NATIVE echo path
  (`process.stdout.write`), bypassing `captureSync` — the adapter
  must sink `process.stdout.write` directly.
