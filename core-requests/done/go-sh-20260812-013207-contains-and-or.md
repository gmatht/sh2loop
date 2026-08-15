# go-sh: `contains` call in a `||`/`&&` chain loses its value (native `.includes` never records `sh2.lastExit`)

## NEED
`expr_to_estree`'s `IrExpr::Call { func: "contains", .. }` arm
(shir.rs ~25071) must be STATUS-RECORDING — the same treatment the
`test` arm already gets — so a `contains` operand inside a `BinOp`
And/Or chain evaluates correctly.

## WHY
The go-sh frontend lowers `strings.Contains(s, sub)` in if/else-if
condition position to the A1 shape
`Call { func: "contains", args: [getVar("s"), Str("sub")] }` (the
same call the core itself produces from `echo X | grep PAT` pipelines,
and the A1 deserializer accepts). Used as a BARE if-cond this works:
the core emits `String(s).includes("sub")` directly into the `if`
test. But used as an operand of `||` (or `&&`), `native_and_or`
(shir.rs ~27201) emits:

    (lhs, (sh2.lastExit === 0) ? true : (rhs, sh2.lastExit === 0))

branching on `sh2.lastExit`, which the bare native
`String(s).includes(...)` NEVER sets — while the runtime `sh2.contains`
contract (and every runtime call) is expected to record its status
there. The result: the first `includes` is evaluated and DISCARDED,
and the chain falls through on the STALE `lastExit` from the outer
if's false `test` (1) — the else-if branch is silently skipped.
Generated for `else if strings.Contains(s, "l") || strings.Contains(s, "x")`:

    else if (String(s).includes("l"), ((sh2.lastExit === 0) ? true : (String(s).includes("x"), (sh2.lastExit === 0))))

(with `lastExit === 1` → always false). The shell frontend never
emits a bare `contains` in a chain (it emits grep pipelines, which
set lastExit), so the corpus never exercised this — the go-sh
frontend is the first caller.

## MINIMAL-CORE-CHANGE
In `expr_to_estree`, `func == "contains"` arm: wrap the native
`String(h).includes(n)` call in the exact status-recording sequence
the `test` arm already emits:

    (sh2._g = String(h).includes(n), sh2.lastExit = sh2._g ? 0 : 1, sh2._g)

- if-cond position: sequence value is the boolean — behavior for
  bare `contains` conds (t60) is unchanged;
- and/or chains: `lastExit` now records the contains result, so
  `native_and_or`'s status protocol holds;
- `!contains`: `not_native` sets `lastExit = v ? 1 : 0` from the
  boolean value — unchanged.

## FAILING-CASE
frontends/go-sh/testdata/t68_case_glob.go:

    s := "hello"
    if strings.HasPrefix(s, "h") {
        fmt.Println("star")
    } else if strings.Contains(s, "l") || strings.Contains(s, "x") {
        fmt.Println("alt")
    }
    s = "axl"
    if strings.HasPrefix(s, "h") {
        fmt.Println("star2")
    } else if strings.Contains(s, "l") || strings.Contains(s, "x") {
        fmt.Println("alt2")
    }

Native Go stdout: `star` / `alt2`. Transpiled (estree-runner): `star`
only — the `||` chain discards `includes("l")` and falls through.

## OUTCOME: implemented: expr_to_estree's `contains` arm now records the status like the `test` arm when AND_OR_DEPTH > 0 (`(sh2._g = String(h).includes(n), sh2.lastExit = sh2._g ? 0 : 1, sh2._g)`); bare if-cond contains stays native. Verified: go-sh t68_case_glob.go emits star/alt2 matching native Go; ESTree corpus 521/521; cargo test 236 pass.
