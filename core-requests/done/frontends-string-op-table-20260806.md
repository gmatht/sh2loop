# frontends: the shared string-op/param catalog (strip, trim, split(sep), join(sep), case)

## NEED

A documented catalog of shared string ops in the param/runtime family:
trim/strip (leading/trailing), split on an explicit separator, join on
an explicit separator, case conversion. Each frontend language has these
natively (py `.strip()`/`split(",")`, go `strings.TrimSpace`/`Split`,
fish `string trim`/`string split`, perl `s///`/`split`, zsh `${(s:,:)}`)
and currently either refuses them or invents a per-frontend runtime fn —
the shared shape should exist once.

## WHY

The runtime has the machinery (77 join / 82 split / 20 strip / 22 trim
references) but no documented contract mapping a language op to an A1
shape. The metric's param family is the growth knob; a catalog makes
each op a shared, testable shape instead of a per-frontend invention.

## MINIMAL-CORE-CHANGE

- A table (in sh2-namespace.json or a sibling): op name -> A1 shape
  (param op or sh2.* call) -> runtime behavior, for: trim, split(sep),
  join(sep), case fold/upper/lower, and the existing slice/subst/len.
- Whitelist additions for any new sh2.* names.
- Frontends map their languages' ops to the catalog.

## FAILING-CASE

```go
s := "  hi  "
fmt.Println(strings.TrimSpace(s))   // go-sh: no shared trim shape
```

## GATE

`cargo test --lib`; the catalog exists; two frontends lower the same op
to the same A1 shape; corpus unchanged.
