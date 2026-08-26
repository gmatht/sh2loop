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

## 8. Findings so far (construct-set + runtime notes)

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
