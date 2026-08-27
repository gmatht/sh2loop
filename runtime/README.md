# Using the bash runtime polyfills (backend consumption guide)

The pure-CPU core of the `sh2.*` runtime is authored **once in bash**
(`polyfills.sh` in this directory) and **transpiled per-backend** by the
same pipeline that compiles user programs. The host-bound/IO seam is
authored **once in C** (`polyfills.c` in this directory) and **linked
per-backend** (native POSIX/glibc). This doc is the consumption
contract for backend implementers. The design rationale and roadmap live
in `CROSS_BACKEND_RUNTIME.md` (workspace root).

## 1. What the polyfills are

`polyfills.sh` defines the pure-CPU `sh2.*` callees — parameter
expansion, string/array/text ops, glob matching, test evaluation — as
plain bash functions. **No I/O, no process model, no host state**: the
host-bound seam (`exec`, `fs.*`, `pipeline`, `redirect`, `capture`,
`background`, `subshell`, `exit`, `getVar`/`setVar`, error codes) stays
per-backend.

Current inventory (21 functions + 4 helpers):

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
| `param` | parameter-expansion dispatcher (len, case mods, `:-`/`:=`, `#`/`##`/`%`/`%%` glob strips incl. extglob, `/`/`//` literal replace, `:?` error marker, slice) | :3266 |
| `test` | test-expression evaluator (`-z`/`-n`, `==`/`!=`/`=`/`<`/`>`, `-a`/`-o`/`!`/parens, glob matching, `nocasematch` via the third `nocase` arg) | :1312 |
| `ext_alt_match` / `ext_match` | extglob helpers (`?(..)` `*(..)` `+(..)` `@(..)` `!(..)` in globMatch) | :8311 |
| `line_count` / `line_at` | newline-separated string access (heredoc read pattern) | — |
| `brace` | brace expansion cross-product (prefix, suffix, ngroups, groups...; the adapter maps sh2.brace's groups[]/middles[]/suffix shape) | :3699 |
| `wcLines` / `headLines` / `tailLines` | pure line-content cores of the wc/head/tail builtins (newline count, first/last n lines) — the first IO-composition polyfills: expressed in terms of the string primitives (strCount/strIndex/strSlice), so backends without a full runtime get the capture-lift data path | :2360/:6156 |
| `test` | test-expression evaluator (now with `nocasematch` via the third `nocase` arg — the adapter passes the shopt state) | :1312 |

`caseMatch`/`globMatch`/`param` limitations (first cut): no `nocasematch`, no
pattern-`$()`-expansion, no `:=`/`:?` side effects, no `$ref`-expansion
in defaults/patterns — the hand-written runtime handles those; the
polyfill defers them.

## 1b. The C polyfills (the host-bound/IO seam)

`polyfills.c` is the **C-implemented complement**: the parts bash cannot
express without recursing (the polyfills' own I/O would lower to sh2.*
calls). It covers the host-bound seam and the IO-bound builtins:

- **The seam (native C over POSIX)**: `exec`, `capture`, `fs_read`,
  `fs_write`, `fs_stat`, `pipeline`, `redirect`, `background`,
  `subshell`, `exit` — fork/exec, pipe, open/read/write/stat.
- **IO-bound builtins** (cat, ls, grep, sed, sort, wc, head, tail, cp,
  mv, rm, mkdir, date, uname, ...): thin wrappers over the host's
  standard tools — the host IS the implementation; the polyfill
  provides the builtin contract.
- **Shell-state builtins** (declare, export, local, set, shift, unset,
  read, readarray, ...): through the host callbacks below — the
  embedding backend owns the variable/positional store.
- **Native-C builtins** (echo, printf, seq, let, true, false, `:`, cd,
  pwd): implemented directly in C.

**Interface** — the same bash function convention as the transpiled
polyfills: `int sh2poly_<name>(int argc, char **argv)` (positional args
in, stdout out, exit status returned). `sh2poly_dispatch(argc, argv)`
with `argv[0]` = the builtin name dispatches by name.

**Host callbacks** — the state registers stay per-backend; the C
polyfills reach them through `sh2poly_set_callbacks(getvar, setvar,
getpos, setpos, poscount, exit, error)`. The defaults are process-level
(environ + exit), so the library is usable standalone.

**Build** — `make` in this directory produces `libsh2poly.a` (link
directly: C, Rust, Zig, Go) and `libsh2poly.so` (FFI: Python ctypes,
Perl FFI::Platypus, Java JNI). `make selftest` runs the oracle (diff
against real bash builtins); `make coverage` checks every sh2perl
builtin is covered by bash or C.

**Adapters** — thin per-backend adapters map the sh2.* call-site
convention to the C polyfills. Each adapter links/loads `libsh2poly`
and runs the shared oracle battery (`adapters/battery.txt`) in the C
self-test's output format; `make adapters` builds and verifies all of
them against the C oracle (`make selftest`, byte-identical to real bash
builtins):

- `adapters/c/polyfill-cli.c` — the C backend's adapter (a transpiled C
  program links `libsh2poly.a` and calls `sh2poly_dispatch` for every
  builtin it lowers to the seam).
- `adapters/rust/main.rs` — the Rust backend's adapter. `rustc -L . -l
  static=sh2poly` links the static archive directly; `main` reads
  `battery.txt`, calls `sh2poly_dispatch` per entry.
- `adapters/zig/main.zig` — the Zig backend's adapter. `zig build-exe
  ... -lsh2poly -lc` links the library directly; `main` reads
  `battery.txt`, calls `sh2poly_dispatch` per entry.
- `adapters/go/main.go` — the Go backend's adapter. cgo calls
  `sh2poly_dispatch`; linked against the static archive
  (`-l:libsh2poly.a`) so the binary is self-contained.
- `adapters/perl/polyfills.pl` — the Perl backend's adapter.
  `FFI::Platypus` loads `libsh2poly.so` and calls `sh2poly_dispatch`.
- `adapters/python/polyfills.py` — the Python backend's adapter
  (ctypes over `libsh2poly.so`; `from polyfills import sh2`).
- `adapters/java/` — the Java backend's adapter: `Polyfills.java`
  (reads `battery.txt`, calls a native method) over
  `polyfills_jni.c` (a JNI shim that links `libsh2poly.a` and forwards
  to `sh2poly_dispatch`).

**Out of scope** — the browser/WASI path cannot use the C seam: WASI
has no fork/exec, so the IO-bound polyfills would be stubs there. The
browser keeps its hand-written JS runtime (`harness/sh2-namespace.mjs`)
for the seam; the pure-CPU polyfills still transpile to JS as before.
This is a documented boundary, not a half-wiring.

## 1c. Builtin coverage (bash + C = all 68)

`check-coverage.py` (run via `make coverage`) maps every entry of
`sh2perl/data/sh2-builtins.json` (the A4 sync_builtins) to an
implementation in either `polyfills.sh` or `polyfills.c`:

| source | builtins |
|---|---|
| **bash** (pure-CPU core) | basename, dirname, test, wc, head, tail (line cores) |
| **C** (seam + IO + state) | the other 62: the seam (exec, capture, fs.*, pipeline, redirect, background, subshell, exit), the IO builtins (cat, ls, grep, sed, sort, ...), the native builtins (echo, printf, seq, let, ...), the state builtins (declare, export, read, ...) |

Zero gaps: every sh2perl builtin has an implementation in one of the
two polyfill sources.

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
per-backend adapter maps one to the other.

**Post echo-return-lifting** (CROSS_BACKEND_RUNTIME.md §8.3 — the
echo-return transform is ON for the current polyfill): the eligible
functions RETURN their value natively (`sh2.fnValue` dispatch — no
stdout sink, no newline strip). The adapter becomes:

```js
// JS adapter (the pattern used by runtime/bench-polyfills.mjs)
const polyValue = (name, args) => sh2.fnValue(name, args);
// drop-in replacements
sh2.basename = (x) => polyValue("basename", [x]);
sh2.contains = (h, n) => polyValue("contains", [h, n]) === "1";
```

The functions whose bodies were NOT lifted (globMatch/caseMatch/param —
captures + returns inside loops) keep the stdout convention; their
adapters keep the stdout-sink form below (the bench does not touch
them).

### Legacy stdout-sink adapter (unlifted functions)

```js
let __buf = '';
const polyValue = (name, args) => {
  const saved = process.stdout.write;
  process.stdout.write = (s) => { __buf += String(s); return true; };
  try {
    sh2.fnCall(name, args);
    const v = __buf.replace(/\n+$/, ''); // strip the echo newline
    __buf = '';
    return v;
  } finally {
    process.stdout.write = saved;
  }
};
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

### M4 — per-backend transpilation of `polyfills.sh` (status: in
progress; C blocked on architectural limits)

M4 transpiles `runtime/polyfills.sh` with each backend's transpiler and
**gates the source as a corpus program** (byte-identical to bash on the
full self-test battery). The polyfill's `[[ ]]` conditions lower to
sh2.test — the dependency closure (§5) is self-contained once the
polyfill ships its own `test`. Status per backend, assessed
2026-08-27 with `otranspiler runtime/polyfills.sh --target <lang>`:

- **C** — emits + **compiles** (`polyfills.c`, ~3330 lines). The three
  original M4-pilot renderer bugs are fixed (the storage-class
  inconsistency where a raw `char*` is assigned via `_sh_mstr_set`;
  the `sh2_fnValue` conflicting-types forward declaration; array-type
  assignments). Two further renderer bugs found and fixed during M4:
  `local x="$var"` into a fixed buffer was emitted as a no-op clear
  (the `value_c` RHS `(name ? name : "")` was not classified stringy
  by `emit_guarded_copy`, so the buffer was zeroed instead of copied);
  and `local off="$a" len="$b"` dropped the `len` value (the
  `declare_words` value-expr lookahead refused a `Str` word carrying a
  `$var`). **But the full self-test battery is BLOCKED by two
  architectural limits of the C backend's pseudo-global variable
  model** (no fix in the three-bug scope resolves them): (1) command-
  substitution recursion has no per-call stack frame — every function's
  locals are file-scope, so `$(globalMatch …)` (and any `$(fn …)`)
  recurses infinitely / corrupts state (confirmed via gdb: `strHasPrefix`
  → `_sh_capture_fn(strHasPrefix, …)` → `strHasPrefix` infinite loop;
  `globMatch` genuinely self-recurses via `$(globMatch "${p:1}" "$v")`);
  (2) cross-function global-variable collisions — many polyfill
  functions share short names (`i`, `n`, `c`, `ch`, `line`) hoisted to
  file scope for capture helpers, so a call from one function clobbers
  another's locals. A recent *relax of the test-lowering self-recursion
  guard* (staged WIP, not part of M4) additionally lowers
  `strHasPrefix`/`contains`/`strHasSuffix` OWN bodies to recursive calls
  — valid for ESTree (`startsWith`/`includes`) but fatal for C (renders
  as `$(strHasPrefix …)`). Isolated functions (single fn, no cross-
  calls) transpile byte-identical to bash. **M4 for C requires stack-
  frame / per-function-local isolation** — a backend-architecture change
  tracked separately, not a renderer-bug fix.
- **Go** — emits ~1981 lines but **40 `TODO` markers** for the `sh2.*`
  runtime helpers (`harness/sh2-namespace.json`); not runnable as-is.
- **Zig** — emits ~1710 lines but **278 `TODO` markers** for the `sh2.*`
  runtime helpers; not runnable as-is.
- **Sh** — `render: command call not renderable: "strHasPrefix"` — the
  sh backend cannot emit script-defined functions as shell functions.
- **Java** — `render: expr not in the v1 Java subset: Call{func:
  "param"}` — the Java subset cannot render `param` calls.
- **Rust (`rs`)** — CLI bug: `rs` normalizes to `rust` but `BACKENDS`
  lists `rs`, so `otranspiler … --target rs` errors (`unknown target
  'rust'`); even if invoked, runtime status unverified.
- **Python** — emits ~53 KB with no render error; not yet gated against
  the oracle battery.
- **JS/ESTree** — keeps its hand-written runtime (M2: polyfill 20–370×
  slower). Does NOT use the transpiled polyfills (documented boundary,
  §1b).

- **M1/M2 done**: first batch (14 functions) transpiles byte-identical
  to bash; benchmark vs the hand-written JS runtime shows the polyfill
  is 20–370× slower on JS (adapter + dispatch overhead) — JS keeps its
  hand-written runtime; the polyfill's value is single-source
  correctness for backends that lack one.
- **M3 done**: `test`, `caseMatch`, `brace`, `param` (the hot pure-CPU
  callees) landed — see CROSS_BACKEND_RUNTIME.md §7.
- **M5 (backend adapter wiring) done**: the Rust, Zig, Go, Perl, and
  Java adapters landed and verified against the same oracle battery as
  the C and Python adapters (`make adapters` — all seven backends
  reproduce the C self-test output byte-for-byte on
  `adapters/battery.txt`). The C-renderer integration (c_backend.rs
  emitting `sh2poly_*` calls instead of `bash -c` shell-outs) is
  explicitly **out of scope** for this step and tracked as a separate
  follow-up: today the adapters are the consumption contract, the
  C backend still lowers builtins to `bash -c`. Per-backend
  transpilation of the bash polyfills for backends that lack a runtime
  remains the wider follow-up (C is the natural first target — its
  transpiler already emits the polyfill functions as C functions).
