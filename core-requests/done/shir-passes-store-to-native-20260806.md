# shir-passes: StoreToNative — setVar on a provably-store-only var -> Assign (native lift)

## NEED

A shared `shir_passes` transform: convert `setVar(name, value)` Expr-stmts
to plain `Assign` stmts when the variable is PROVABLY STORE-ONLY, so the
emitter's existing native-lift (Assign stmt -> JS binding, `x = v`) fires
instead of a runtime `sh2.setVar` store round-trip. Same analysis as the
M9 const-markup: which vars can be proven plain.

## WHY

The frontend-side equivalent is proven (frontends/c-sh-go/main.go
`applyStoreRouting`, the reverse direction): a var whose storage is only
ever accessed through literal-name setVar/getVar calls can live in a
native binding — the runtime store is pure overhead. The core's own
lift already does this for Assign STMTS (`x=5` -> `let x = 0; x = 5`),
but a `setVar` CALL is opaque to it (it could target an array element,
an assoc, or a dynamic name — unprovable). So every frontend that emits
setVar calls for plain vars pays a store round-trip the lift could
eliminate; the corpus's own setVar call sites (~253 in the M8 baseline)
are the metric signal.

## MINIMAL-CORE-CHANGE

A `shir_passes` Transform (the M9 library; wired into the canonical
pipeline like `transform::ConstMarkup`):

1. ANALYSIS — a variable v is STORE-ONLY iff EVERY reference is:
   - `setVar("v", expr)` / `getVar("v")` calls with a LITERAL name, and
   - never: `memLoad`/`memStore`/`addrOf` on v (the mem.* seam),
     `arrayIndex`/`arrayLen`/`arrayItems`/`setArray`/`setArrayAppend`
     on v, `param(..., "v", ...)` by name, assoc ops, or any
     non-literal/dynamic name. (The c-sh-go `addrTaken` set and the
     shir_passes escape/lifetime analyses are the precedent.)
2. TRANSFORM — replace `Expr(setVar("v", e))` with `Assign{var: v, expr: e}`
   for every store-only v.
3. SOUNDNESS — a var NOT provably store-only keeps its setVar calls. The
   transform must be conservative: a wrong conversion recreates the
   stale-store divergence (store written, native binding not updated).
4. The estree emitter needs NO change (its lift already handles Assign
   stmts); the C backend's const rendering also benefits.

## FAILING-CASE

```c
int x = 5;
int *p = &x;
*p = 7;
printf("%d\n", x);
```

(hand-crafted A1: `setVar("x","5")`, then a seam or store write to x,
then `getVar("x")` — the emitted JS round-trips through the store for x
when a native binding would be correct AND cheaper. The reference
frontend-side implementation: c-sh-go's `applyStoreRouting` — the
reverse direction, proven across t01-t12.)

Reference: the c-sh-go frontend post-pass (frontends/c-sh-go/main.go,
`applyStoreRouting`) does the reverse (Assign -> setVar for NOT-folded
address-taken vars); this request is the general, shared forward pass.

## GATE

`cargo test --lib`; corpus byte-identical or better (the corpus's setVar
call sites shrink; no output change for vars the analysis keeps in the
store); the metric (fail-estree --metric) total must not increase.
