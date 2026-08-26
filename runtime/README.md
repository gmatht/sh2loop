# Using the bash runtime polyfills (backend consumption guide)

The pure-CPU core of the `sh2.*` runtime is authored **once in bash**
(`polyfills.sh` in this directory) and **transpiled per-backend** by the
same pipeline that compiles user programs. This doc is the consumption
contract for backend implementers. The design rationale and roadmap live
in `CROSS_BACKEND_RUNTIME.md` (workspace root).

## 1. What the polyfills are

`polyfills.sh` defines the pure-CPU `sh2.*` callees — parameter
expansion, string/array/text ops, glob matching, test evaluation — as
plain bash functions. **No I/O, no process model, no host state**: the
host-bound seam (`exec`, `fs.*`, `pipeline`, `redirect`, `capture`,
`background`, `subshell`, `exit`, `getVar`/`setVar`, error codes) stays
per-backend.

Current inventory (16 functions):

| function | semantics | hand-written ref (sh2-namespace.mjs) |
|---|---|---|
| `basename` | strip directory part (GNU semantics) | :1474 |
| `dirname` | strip filename part (GNU semantics) | :1410 |
| `strLen` | string length | :2422 |
| `strHasPrefix` / `strHasSuffix` | affix tests | :2562/:2563 |
| `contains` | substring test | :1860 |
| `strSlice` | `s[lo:hi]` | :2378 |
| `strCompare` | -1/0/1 string order | :2545 |
| `strIndex` / `strLastIndex` | first/last occurrence index | :2503/:2502 |
| `strCount` | non-overlapping count | :2360 |
| `strReplaceAll` | literal replace-all | :2539 |
| `strContainsAny` | any-char membership | :2552 |
| `joinSep` | join args with separator | :2522 |
| `globMatch` | recursive glob matcher (lit, `*`, `?`, `[class]`, `\`escape) | :8311 |
| `caseMatch` | first pattern matching value | :1837 |

`caseMatch`/`globMatch` limitations (first cut): no extglob
(`?(..)` `*(..)` `+(..)` `@(..)` `!(..)`), no `nocasematch`, no
pattern-`$()`-expansion — the hand-written runtime's `caseMatch`
handles those; the polyfill defers them.

## 2. The build step

Transpile the source per-backend at build time:

```sh
# JS/ESTree (the reference backend)
debashc file --estree runtime/polyfills.sh > polyfills.estree.json

# any other backend (C, Go, Rust, Zig, Java, Python, sh, ...)
otranspiler runtime/polyfills.sh --target <lang> > polyfills.<lang>
```

The transpiled output is a **standalone module/program** that defines the
functions in the backend's function convention and runs the self-test
calls (see §5). It is deterministic — byte-identical for the same input.

## 3. The linking model

The transpiled functions use the **bash function convention**: positional
args in, stdout out. Each backend's transpiler already emits user
functions this way:

- **JS/ESTree**: `sh2.functions.set("basename", () => { let s =
  sh2.positional[0] ?? ""; ... process.stdout.write(...) })` — the
  function reads `sh2.positional`, writes stdout, and is dispatched via
  `sh2.fnCall(name, args)`.
- **C**: `static void basename_(void) { ... }` reading `_sh_argv` /
  `_sh_argc`, writing stdout.

So a backend that can already run script-defined functions can run the
polyfills with **zero new machinery** — the transpiled polyfill module is
just another program.

## 4. The adapter (mapping the sh2.* call-site convention)

Generated code calls `sh2.<name>(...)` with the **runtime's call-site
convention** (JS values in, value/boolean out). The transpiled polyfill
function uses the bash convention (positional in, stdout out). A thin
per-backend adapter maps one to the other:

```js
// JS adapter (the pattern used by runtime/bench-polyfills.mjs)
let __buf = '';
const polyValue = (name, args) => {
  const saved = process.stdout.write;
  process.stdout.write = (s) => { __buf += String(s); return true; };
  try {
    sh2.fnCall(name, args);            // sets positional, dispatches
    const v = __buf.replace(/\n+$/, ''); // strip the echo newline
    __buf = '';
    return v;
  } finally {
    process.stdout.write = saved;
  }
};
// drop-in replacements
sh2.basename = (x) => polyValue("basename", [x]);
sh2.contains = (h, n) => polyValue("contains", [h, n]) === "1";
```

Notes:

- **The transpiled functions use the NATIVE echo path**
  (`process.stdout.write` directly), which bypasses the runtime's
  `captureSync` (fdTargets). The adapter must sink `process.stdout.write`
  itself — `captureSync` will not capture the polyfill's output.
- **Boolean-returning callees** (`contains`, `strHasPrefix`,
  `strHasSuffix`, `strContainsAny`) echo `"1"`/`"0"`; the adapter maps to
  the backend's boolean.
- **Array-arg callees** (`caseMatch(value, patterns)`, `brace(prefix,
  groups, ...)`) take the array as multiple positional args — the
  adapter spreads: `polyValue("caseMatch", [v, ...patterns])`.

## 5. The dependency closure

The transpiled polyfill functions call a small set of runtime services.
A backend using the polyfills must provide these (or the polyfill's own
`test` — see below):

| service | used for | notes |
|---|---|---|
| `sh2.test` | every `[[ ]]` condition | the polyfill's own `test` (once written) makes the closure self-contained |
| `sh2.fnCall` | function dispatch | the backend's existing user-function call |
| `sh2.positional` | `$1`/`$2`/... arg reads | the backend's existing positional state |
| `sh2.lastExit` | status writes | the backend's existing status register |
| echo / stdout | value return | the backend's existing output path |

The `[[ ]]` conditions in the polyfill source lower to `sh2.test` — so
`test` is the critical dependency. Until the polyfill ships its own
`test`, a backend without a runtime must provide a minimal `test`
implementation (or accept the dependency).

## 6. Verification (the self-test oracle)

The bottom of `polyfills.sh` is a **self-test section**: one call per
function with edge-case inputs. It serves two purposes:

1. **Forces emission** — the transpiler emits functions only when
   called (plus builtin-named special cases); without the self-test
   calls the transpiled module would be empty.
2. **Is the correctness oracle** — run the source under bash, run the
   transpiled output, diff:

```sh
bash runtime/polyfills.sh > /tmp/ref.out
<run the transpiled polyfills> > /tmp/poly.out
diff /tmp/ref.out /tmp/poly.out   # must be identical
```

The corpus gate is the second oracle: the polyfill source is a corpus
program that must pass on every backend.

## 7. The construct-set constraint

The polyfill source is written in a **transpiler-friendly bash subset** —
constructs the transpiler lowers correctly on all backends. Verified
findings (see CROSS_BACKEND_RUNTIME.md §8):

- `[[ "$x" == *"$y"* ]]` transpiles (to `sh2.test`); `case "$x" in
  *"$y"*)` does NOT (pattern emitted literally).
- `${s##*/}` / `${s%/*}` lower to trailing-slash-aware expressions
  (basename/dirname semantics) — the source must still be written to
  match real bash, verified by the self-test diff.
- `local x="$1"` with a multi-var decl (`local a="$1" b="$2"`) where a
  sibling is store-bound falls through to the runtime local builtin —
  keep decls single-var or ensure all names lift.
- Empty patterns in `while [[ "$rest" == *"$sub"* ]]` loops infinite-loop
  — guard with `[[ -z "$sub" ]]` first (the polyfills do).

## 8. Rollout status

- **M1/M2 done**: first batch (14 functions) transpiles byte-identical
  to bash; benchmark vs the hand-written JS runtime shows the polyfill
  is 20–370× slower on JS (adapter + dispatch overhead) — JS keeps its
  hand-written runtime; the polyfill's value is single-source
  correctness for backends that lack one.
- **M3 in progress**: `test`, `caseMatch`, `brace`, `param` (the hot
  pure-CPU callees) are the next additions.
- **M4 pending**: per-backend transpilation + linking for backends that
  lack a runtime (C is the natural first target — its transpiler already
  emits the polyfill functions as C functions).
