# Core request: `direct_shell_fn_calls` misses `getVar`-convention positional reads

Date: 2026-09-09. From: go-sh dogfood (linked CLI transpiles to empty output).
Owner: estree worker (sh2perl/src/estree.rs scan).

## Symptom

A sub that reads its params via the `getVar` convention, when its call
site is rewritten to `callDirect` (which does NOT set `this.positional`),
sees empty positionals. Single-file reproducer (go-sh corpus shape, but
the bug is backend-side — any frontend emitting these shapes hits it):

```go
func count1(s string) int {
	n := 0
	for i := 0; i < len(s); i++ {
		n++
	}
	return n
}
func main() {
	fmt.Println(count1("aba"))  // oracle: 3, transpiled: 0
}
```

The frontend emits `len(s)` (param) as `getVar("#1")` and the loop bound
compares against it. The backend's `direct_shell_fn_calls` pass (#10)
rewrites the call to `sh2.callDirect("count1", fn, [...])`; `callDirect`
invokes `fn(...args)` without setting `this.positional`, so
`getVar("#1")` → `getVar("1")` → `positional[0]` → `""` → length 0 →
the loop never runs.

## Root cause

`scan_fn_expr` (estree.rs) detects positional reads ONLY as a direct
`sh2.positional` member expression. It misses every `getVar`-convention
read the frontends actually emit:

- `sh2.getVar("1")` … `sh2.getVar("9")` (positional `$1` — go-sh params,
  also `$0`? no, that's `argv0`)
- `sh2.getVar("#1")` (length of `$1` — go-sh `len(param)`)
- `sh2.param("slice", "1", …)` / `sh2.param("len", "1")` (positional
  slices/lengths by number)
- `sh2.join(sh2.param(…))` compositions thereof (already recursed, but
  the leaves are the above)

So `pos_refs` stays false, the bridge (`sh2.positional = [args]; try…
finally restore`) is skipped, and the plain direct call silently drops
the arguments the body reads positionally.

## Suggested fix (5 lines in `scan_fn_expr`)

Alongside the existing `sh2.positional` arm, also set `*pos_refs` for:

1. `sh2.getVar(<str>)` where the string is `^[1-9]$` or `^#[A-Za-z_…]`
   / `^#[1-9]$` (positional value / length reads),
2. `sh2.param(<any>, <str>, …)` where the second arg is a literal
   `"1"`…`"9"` (positional slice/len/case-op reads by number).

Both are pure detections (no rendering change); the existing bridge
then preserves behavior exactly.

## Verification

- The reproducer above prints 3 (not 0).
- Full estree corpus gate unchanged (the bridge is behavior-preserving;
  only previously-miscompiled programs change).
- go-sh `fail-go` / `make test` unchanged (its gates currently pass
  because no corpus test routes a param-reading sub through a rewritten
  call site — the linked dogfood CLI is the first).

## Impact

Without this, no frontend can pass multi-line/user input through sub
params in a linked program whenever the pass fires — the go-sh
self-hosted CLI (Shir ← src) transpiles to an always-empty program.
This is the last known blocker for the linked Go→JS CLI demo
(go-sh/DOGFOOD.md app gate, `link-go-units.py` composition).
