# go-sh dog-food: contract boundaries (TRANSLATE_ONE_APPLICATION classification)

Mined from our own Go frontend (`frontends/go-sh/go-sh.go`) while growing
the Go idiom ladder. Nine constructs the shell-flavored A1 cannot express;
each is a shared-core/contract change, NOT a frontend fix (Refuse > guess
in the playbook). Classified (a)/(d) — the frontend must not fork the core.
§7–§9 added by the idiom-triage pass that landed the join/sprintf/
interface_type frontend gaps (templates/go: join, sort_pkg, sprintf,
interface_type, str_upper, filepath).

## 1. NEED — index+value range `for i, s := range arr`

The app's most common loop form (`for i, s := range args { a[i] = … }`,
26 uses). The A1 `For` node binds ONE loop var to each element; Go binds
BOTH the index and the value, and the app reads both (`a[i] = strExpr(s)`).

## WHY

The A1 `For { var, iter, body }` has a single var slot. `for _, v :=
range` maps to it; `for i, s := range` needs an index-binding form (or a
`ForIndexed` iter that exposes `$i` inside the body — the shell analog is
`for i in "${!arr[@]}"`, which the A1 also lacks).

## MINIMAL-CORE-CHANGE

Add an index form to the For iter contract: e.g. `For { var, index_var,
iter, body }` (index_var optional) or an `iter: {"type":"IndexRange",
"array": name}` whose body binding is the index. Deserializer + estree +
perl + C renderers each add the arm (per-target). The frontend then emits
the index form for `for i, s := range` / `for i := range`.

## FAILING-CASE

```go
a := []string{"x", "y"}
for i, s := range a {
    fmt.Println(i, s)
}
```
go-sh today: `expected assignment operator, got ","` — the parseFor range
branch only accepts `for _, v := range` (or `for i := range N`).

---

## 2. NEED — higher-order functions (`func`-typed params/literals)

The app threads functions as values (`foldPureLiteralCall`, emitter
helpers taking closures). Go `func(T) R` types, and calling a func-valued
variable, have no A1 shape.

## WHY

A func VALUE is not a shell command. `f := func() {…}; f()` lowers to
`Function` + a call, but `func(fn func(int) int, x int) int` (a param
whose type is a func) and `apply(func(v int) int {…}, 41)` (a func
literal passed as an ARG) need callable-value semantics the A1 lacks.

## MINIMAL-CORE-CHANGE

None proposed — this is a declared boundary for the shell-flavored A1.
The frontend keeps refusing loudly. If a future target needs it, a
func-value contract is a separate design.

## FAILING-CASE

```go
apply := func(fn func(int) int, x int) int {
    return fn(x)
}
fmt.Println(apply(func(v int) int { return v + 1 }, 41))
```
go-sh: `unsupported call "fn" in word position (v2)`.

---

## 3. NEED — struct/interface type declarations + method dispatch

The app is struct-heavy (`type parser struct {…}`, `type expr struct`…
with `func (p *parser) Method()` receivers, 4+ struct types).

## WHY

Structs, receivers, methods and interface dispatch are object-oriented
state — no shell-flavored A1 shape exists, and one is not planned (the
contract is command-oriented).

## MINIMAL-CORE-CHANGE

None — declared boundary. The frontend refuses loudly (today:
`type decls are outside the subset (v2) — struct/interface types have
no A1 shape` — the parseTopLevel `type` case added for the interface_type
frontend gap only erases EMPTY `interface{}` decls; every other type
decl falls to this refusal).

## FAILING-CASE

```go
type pair struct {
    a string
    b int
}
fmt.Println("decl")
```

---

## 4. NEED — string position values (`strings.Index`)

The app uses `strings.Index` (4 uses) to slice by substring position
(`x[:strings.Index(x, n)]` → the comment documents the desired
`${x%%n*}` shape).

## WHY

`strings.Index` RETURNS an integer position. The A1 has no string→int
position primitive; the shell `${s%%pat*}`/`${s%pat}` removals express
the *resulting slice*, not the position value.

## MINIMAL-CORE-CHANGE

Either (i) a `stringIndex(s, pat)` pure-call primitive (returns the
position, then `param` slice can use it), or (ii) declare the boundary:
the frontend lowers the *compound* slice-by-index idioms directly to
`${s%%pat*}` (what the app's comment already describes) and refuses a
bare `strings.Index` value use. (ii) is cheaper and matches the app's
actual usage.

## FAILING-CASE

```go
fmt.Println(strings.Index("hello", "l"))
```
go-sh: `unsupported call "strings.Index" in word position (v2)`.

---

Related documented divergence (not escalated): `go func(){…}()` races in
native Go; the translation deterministically orders `bg` then the rest
(testdata t44/t79; the probe stays red, documented).

---

## 5. NEED — error values (`fmt.Errorf`, 359 uses)

The app returns errors as first-class VALUES (`return nil, fmt.Errorf("subroutine %s: %v", name, err)` — 359 `fmt.Errorf` uses in bat-sh-go/busybox). Go errors are created with a formatted MESSAGE, returned alongside a value (multi-value return), nil-compared by the caller, and printed via `%v` — no A1 node holds an error value or its text. The A1's error channel is the exit status (`$?`, the err_check probe); the formatted message has no carrier.

## WHY

`return nil, fmt.Errorf(...)` needs both a multi-value Function return AND an error value. The shell-flavored A1 Function model is echo-based; inventing a convention (`echo msg >&2; return 1`) would guess at the calling contract. The frontend refuses loudly today.

## MINIMAL-CORE-CHANGE

None proposed — declared boundary (same class as #3). An error-value contract (an `errorf(msg)` Emulable call whose value is a status + stderr text, or multi-value Function returns) is a separate design.

## FAILING-CASE

```go
err := fmt.Errorf("subroutine %s: %v", "name", "boom")
fmt.Println(err)
```
go-sh: `unsupported call "fmt.Errorf" in word position (v2)`.

---

## 6. NEED — delimiter string split (`strings.Split`, 47 uses)

`lines := strings.Split(src, "\n")` — Go splits on an exact delimiter into an ARRAY value, preserving empty fields (trailing ones included). The A1 `split` marker (`split(getVar x)`, the unquoted-expansion word-split) splits on IFS whitespace and DROPS empty fields — different semantics, and it takes no delimiter argument. There is no array-valued delimiter-split in the A1.

## WHY

The app needs the split ARRAY as a value (`strings.Split(bodyLines, "\n")` feeds `newParser(lines, ...)`). The `read`-with-IFS shape (the Object-arg contract) is statement-level and stdin-driven, not a value-producing expression; `param` ops never split into arrays.

## MINIMAL-CORE-CHANGE

Either (i) a `stringSplit(s, delim)` PureCpu primitive (the runtime renders `String(s).split(delim)` — JS split preserves empty/trailing fields exactly like Go), or (ii) declare the boundary and keep the refusal (the app rewrites as a while-read loop). (i) is cheap and matches the app's actual usage.

## FAILING-CASE

```go
fmt.Println(strings.Split("a,b,c", ","))
```
go-sh: `unsupported call "strings.Split" in word position (v2)`.

---

## 7. NEED — in-place slice sort (`sort.Strings` / `sort.Slice`, 24 uses)

`sort.Strings(names)` (c-sh-go main.go:657, posix-sh-go analysis.go ×6)
sorts a `[]string` IN PLACE; `sort.Slice(userDefs, func(i, j int) bool {…})`
(c-sh-go main.go:5044) sorts with a comparator CLOSURE.

## WHY

The A1 has no in-place array-mutation primitive for reordering a stored
array. The shell's `sort` command is a line-oriented text filter
(`printf '%s\n' "${a[@]}" | sort` would need a capture+split round-trip,
mangles elements containing spaces, and inherits locale-dependent
ordering — a guessed composite, not a shape); `sort.Slice` needs a
first-class func VALUE (boundary §2). Both app forms are therefore
unreachable without a contract change.

## MINIMAL-CORE-CHANGE

None proposed — declared boundary (same class as §2/§3; DOGFOOD.md lists
`sort` with structs/methods/interfaces as no-A1-shape). A sort-array
primitive (`sh2.sortArray(name)` or a `sortArray` A1 Call) would be a
separate design.

## FAILING-CASE

```go
a := []string{"b", "a", "c"}
sort.Strings(a)
fmt.Println(a)
```
go-sh: `unsupported call sort.Strings (v2)` — the probe
(templates/go/sort_pkg.go) stays red, documented.

---

## 8. NEED — custom-separator array join (`strings.Join(arr, sep)` with
sep ≠ " ", 26 uses)

The app's dominant join form is `strings.Join(bodyLines, "\n")`
(bat-sh-go bat.go:172, fish-sh-go fish-sh-go.go:276) — a NEWLINE
separator. The A1 `join` func joins arrays with a SPACE only
(`join(param("slice", name, "@", ""))` — the runtime's `.join(" ")`).

## WHY

The `join` Call takes no separator argument — the space join IS the
contract's shape (`"${arr[@]}"` in the shell lowers to the same
space-joined value). A `\n` join would need a separator-carrying join
form (or an IFS-style parameter), which the runtime/core do not have.

## MINIMAL-CORE-CHANGE

Either (i) a separator arg on the `join` call (or a `joinSep(s, sep)`
PureCpu primitive — the runtime renders `arr.join(sep)`, exactly Go's
strings.Join), or (ii) declare the boundary and keep the refusal. (i) is
cheap and matches the app's actual usage.

## FAILING-CASE

```go
a := []string{"x", "y"}
fmt.Println(strings.Join(a, "\n"))
```
go-sh: `strings.Join needs (arr[lo:hi]|arr, " ") (v2)`.

NOTE (landed): the SPACE-separator forms are NOT a boundary — the
triage pass extended the frontend to lower `strings.Join(arr, " ")` on a
FULL array to `join(param("slice", arr, "@", ""))` (the `${arr[@]}`
shape; probe templates/go/join.go green). Only non-space separators
remain here.

---

## 9. NEED — path ops on VARIABLES (`filepath.Dir/Ext(path)`, 6 uses)

`switch filepath.Ext(path)` (busybox main.go:63) — the path is a RUNTIME
VALUE, not a literal. The frontend folds `filepath.Dir("lit")` /
`filepath.Ext("lit")` at emit time with exact Go stdlib semantics (t55)
and refuses var args.

## WHY

No A1 param op matches Go's filepath semantics on a store value:
`${path##*.}` (the natural Ext lowering) strips the longest prefix
ending in a dot ANYWHERE in the path — `/a/b.c/d` → `c/d`, where Go's
filepath.Ext gives `""` (verified against bash) — and `dirname`/`basename`
diverge on trailing slashes (`filepath.Dir("a/b/")` = `a/b` vs `dirname`
= `a`). The runtime's zsh-gated `:e`/`:h`/`:t` param modifiers exist but
are zsh-mode-only, and are the same semantics family, not Go's.

## MINIMAL-CORE-CHANGE

None proposed — declared boundary. A `pathExt`/`pathDir` PureCpu
primitive (runtime `String(p).slice(...)`, Go-exact) would be a separate
design; the app's switch-on-Ext would then need the switch-expression
path too.

## FAILING-CASE

```go
path := "main.go"
fmt.Println(filepath.Ext(path))
```
go-sh: `filepath.Ext needs a string literal (v2)` — the probe
(templates/go/filepath.go) stays red, documented.

---

## 10. Variant notes (probes green; variants refused)

- `strings.ToUpper(sliceExpr)` — the c-sh-go form `strings.ToUpper(kw[:1])`
  (main.go:3738): the frontend's `strings.ToUpper` var case lowers to the
  `param("^^", name)` op, whose args are NAMES — a slice EXPRESSION has no
  param-op shape (same position-value class as §4). Plain-var ToUpper is
  green (templates/go/str_upper.go — the `${s^^}` UppercaseAll op).
- `fmt.Sprintf` verb set — the frontend's var-arg Sprintf lowering
  (templates/go/sprintf.go, green) delegates the format to the runtime
  `printf` builtin exactly like the fmt.Printf statement path (t46): the
  bash-printf verb set. Go-only verbs (`%v`, `%t`, `%q`) print literally
  on that path — the app's `%t`/`%v` uses also hit the §2/§3 boundaries
  (struct fields, variadics) first and stay refused via the literal-format
  gate.
- `os.ReadFile` in the if-init form (`if b, err := os.ReadFile(p); err ==
  nil {` — busybox main.go:118, posix-sh-go analysis.go:3567): REFUSED.
  The cond is a READ-STATUS test, and the A1 If cond is a `test` call,
  not a command status (`if b=$(cat p); then` has no If-cond shape); the
  STATEMENT form (`b, _ := os.ReadFile(p)` → `b = $(cat p)`) is green
  (templates/go/read_file.go) — a FRONTEND-GAP fix that landed with this
  triage pass (the os.Stat if-form works only because `err == nil` maps
  to a path test, `test -e`).

  NOTE (landed, FRONTEND-GAP not boundary): this bullet's core
  justification was STALE — the A1 If cond IS a command-status shape:
  the core's own `if b=$(cat p); then` lowering (debashc file --shir)
  is Call{func:"assign", args:[Str(b), Str("="), Capture{native:false,
  expr:Arrow{body:[Expr exec cat …]}}]}, and `if ! b=$(cat p); then` is
  the Not BinOp over the same assign (both verified executing correctly
  end-to-end through --shir-in-estree + estree-runner). The frontend
  fix landed in go-sh.go parseIf: `if <name>, err := os.ReadFile(p);
  err == nil {` lowers to that assign-capture cond (err != nil → the
  Not BinOp); the old behavior was a bare parser crash (`expected "{",
  got ","` — parseIf only special-cased `if _, err := os.Stat(...)`),
  not a deliberate refusal. Probe templates/go/read_file_if.go GREEN
  (oracle == translated; the app's instance is cmd/go-sh/main.go:29 —
  `if b, err := os.ReadFile(inp); err == nil {`). Corpus 93/93 + make
  test green.

---

## 11. NEED — array-valued positional copy (`os.Args[1:]`, 2 uses)

`args := os.Args[1:]` (busybox main.go:81, posix-sh-go analysis.go:3550)
— the program's argv with argv0 stripped, the shell's `"$@"`. Both apps
consume `args` as an ARRAY: `args[i]`, `len(args)`, `for i := 0; i <
len(args); i++` (and the §1 index-range family).

## WHY

The A1/runtime resolve positional state as SCALARS only: `getVar("@")`
→ the space-joined string, `getVar("#")` → the count, `$1`..`$9` → one
element (the estree emitter's `sh2.positional[..]` member accesses are
scalar reads). There is NO array-valued materialization of the
positional list — the shir side has a `listVar("@")` word lowering
(shir.rs), but the JS runtime has no `listVar`, so `args` cannot be
stored in the array store. `len(args)`/`args[i]`/`range args` all read
the array STORE; an `args`-as-positional-alias design would need
runtime positional-index support for computed subscripts — Refuse >
guess.

## MINIMAL-CORE-CHANGE

None proposed — declared boundary (same class as §2/§3/§7). A
`listVar("@")` array-valued positional read in the JS runtime (shir's
listVar already exists; the runner's `getVar`/`param` would need an
array return, or a `sh2.listVar(name)` native), plus the frontend
lowering `os.Args[1:]` → `setArray(args, <positional-list>)`, would be
a separate design; the §1 index-range family would then follow.

## FAILING-CASE

```go
args := os.Args[1:]
fmt.Println(len(args))
```
go-sh: frontend cannot parse/lower (EMIT-FAIL) — the probe
(templates/go/args.go) stays red, documented. The oracle runs with no
args (`go run </dev/null`), so `len(os.Args[1:])` is deterministically
0.

NOTE (landed, FRONTEND-GAP not boundary): the §11 core-justification
was STALE — the runtime HAS the array-valued positional slice
(`param("slice", "@", off, len)` → the native positional list;
sh2-namespace.mjs + the shir.rs native lowering), and setArray SPLICES
array elements into the array store. The frontend fix landed in
go-sh.go: `args := os.Args[1:]` lowers to `setArray("args",
[param("slice", "@", "1", "")])` (Go 0-based os.Args vs bash 1-based
`${@:off}`: os.Args[i:] ↔ offset i; os.Args[i:j] ↔ length j-i;
os.Args[:j]/os.Args[0:] ↔ offset 0, the [argv0, ...params] form).
Probe templates/go/args.go GREEN (oracle == translated for 0 and 2
args); corpus 93/93 + make test green. REMAINING boundary in the same
family: `for _, a := range args` over the runtime-loaded array — the
A1 For iter is a STATIC element list, so the frontend refuses it
loudly ("range over unknown array") rather than unroll an empty
iteration; a runtime-array For iter is a separate contract design.

## OUTCOME: rejected: contract-extension proposals (#1 index_var For form, #4 stringIndex, #6 stringSplit) have no emitting consumer — go-sh refuses loudly by design (Refuse > guess); boundaries #2/#3/#5 need no core change. A new A1 primitive is a plan-level design decision, not a corpus fix.

---

## 12. Re-hit (2026-08-16): struct type DECLS from the dogfood loop — `type token struct {` (go-sh.go:70)

The app loop (`run_go_idiom_worker.sh app_transpile` → `fail-go --app
frontends/go-sh/go-sh.go`) first refuses at the golib's FIRST struct
decl — the lexer's value type. §3 already classifies the struct cluster
(decls + composite literals + field access + receiver methods) as a
declared boundary; this section pins the DECL-alone construct as it
surfaces from the app run, with its ladder probe.

## NEED

No new core shape. The construct is `type Name struct { field-list }`
at top level; the app's instance is

```go
type token struct {
    kind tokKind
    text string
    raw  string
    line int
}
```
(go-sh.go:70; `tokKind` itself is an ERASED named-scalar decl —
`type tokKind int`, go-sh.go:57: the type-position erasure contract
covers compile-time SCALAR and EMPTY-`interface{}` types only, not
composite underlying types).

## WHY

`token` is the lexer's value type; the app constructs `token{…}`
composite literals, reads `t.kind`/`t.text`, and `parser`
(go-sh.go:78, 30+ fields) has receiver methods — the whole cluster has
no shell-flavored A1 shape (§3; DOGFOOD.md: "no shIR representation …
a Go struct or method call cannot be expressed"). The DECL alone is
compile-time-only (same class as the erased `type tokKind int`), but
erasing it would only move the refusal to the first composite-literal /
field-access USE — the boundary does not open. The frontend keeps ONE
loud refusal at the decl so the app fails fast and diagnosably
(Refuse > guess; the loop then advances via the `seen/go-sh.go:70`
marker).

## MINIMAL-CORE-CHANGE

None — same verdict as §3 and the OUTCOME (declared boundary; no
emitting consumer; a struct-value contract is a plan-level design
decision, not a corpus fix). The frontend's refusal stays.

## FAILING-CASE

Ladder probe `templates/go/struct_type.go` (sig `type .* struct`):

```go
type pair struct {
    a string
    b int
}
fmt.Println("decl")
```
Oracle (`go run` of the wrapped snippet): `decl`. go-sh today:
`type decls are outside the subset (v2) — struct/interface types have
no A1 shape` (exit 2) — the same message as the app's refusal at
go-sh.go:70. Probe stays red, documented (ladder baseline 41/46,
DOGFOOD.md).

---

## 13. Re-hit (2026-08-17): package-qualified call in WORD position — `out, err := golib.Shir(src)` (cmd/go-sh/main.go:32)

The app loop's CLI first refuses at main.go:32: `go-sh: line 32:
unsupported call "golib.Shir" in word position (v2)` — the app's ONLY
non-stdlib qualified call: `golib` is the import alias for the
frontend library itself (`github.com/gmatht/sh2loop/frontends/go-sh`).

## NEED

The construct is a DOTTED (package-qualified) function call in WORD
position — `pkg.Func(args)` as an expression VALUE (here the RHS of a
multi-assign). The frontend's word-position call contract is a stdlib
whitelist (exprToWord's call case); any callee outside it refuses.
The qualifier is incidental: a SAME-UNIT user function in word position
refuses identically (`out := greet("bob")` with `greet` defined in the
same file → `unsupported call "greet" in word position (v2)`). The gap
is the call-EXPRESSION, not the import.

## WHY

The A1 `Function` node is a statement-level sub (echo-based); there is
no call-expression primitive that carries a function's RETURN VALUE
into a word — a word-position call to a user function has no value
carrier. The app instance is doubly unreachable: (i) the callee's body
lives in ANOTHER compilation unit (go-sh.go — the golib), which is not
in the transpiled input (the app is the CLI, main.go only), and (ii)
even inlined, the golib is the §2/§3/§5 no-A1 dialect (maps, structs,
methods, interfaces, json, goroutines — DOGFOOD.md (a)/(d)). A
lowering that drops the qualifier (`Shir "$src"`) would emit a call to
an UNDEFINED sub — a runtime failure where `go run` prints shIR JSON
and exits 0 — a silent divergence, not a translation (Refuse > guess).
The whitelist's value-returning special cases (`n, err :=
strconv.Atoi`, `b, _ := os.ReadFile` — the `err` target skipped) are
per-function foldings, not a call-expression contract; the app's
`([]byte, error)` multi-value return is the §5 error-value class.

## MINIMAL-CORE-CHANGE

None proposed — declared boundary (same class as §2 function values /
§5 error values). A call-expression contract (a Function return-value
convention — e.g. capture of the sub's stdout, or a call node with an
out-var) is a plan-level design decision, not a corpus fix; the
frontend keeps refusing loudly.

## FAILING-CASE

Ladder probe `templates/go/qualified_call.go` (sig
`golib\.[A-Z][A-Za-z0-9]*\(` — fires on main.go:32):

```go
before, after, found := strings.Cut("a=b", "=")
fmt.Println(before, after, found)
```
Oracle (`go run` of the wrapped snippet): `a b true`. go-sh today:
`unsupported call "strings.Cut" in word position (v2)` (exit 2) — the
same refusal path and message shape as the app's
`unsupported call "golib.Shir" in word position (v2)` (main.go:32).
strings.Cut is the hermetic stdlib stand-in for the app's user-package
call: same parse shape (`call{callee:"pkg.Func"}`), same position
(multi-assign RHS), a multi-value return like the app's `([]byte,
error)` — and `go run` of the wrapped snippet is deterministic with no
module deps (a user-package call cannot compile in the single-file
probe wrapper). Probe stays red, documented (verdict EMIT-FAIL).
