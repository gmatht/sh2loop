# go-sh dog-food: contract boundaries (TRANSLATE_ONE_APPLICATION classification)

Mined from our own Go frontend (`frontends/go-sh/go-sh.go`) while growing
the Go idiom ladder. Four constructs the shell-flavored A1 cannot express;
each is a shared-core/contract change, NOT a frontend fix (Refuse > guess
in the playbook). Classified (a)/(d) — the frontend must not fork the core.

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
`expected assignment operator, got "pair"`).

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
