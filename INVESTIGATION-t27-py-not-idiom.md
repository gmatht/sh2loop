# t27 `not x` — why the Rust is a `thread_local!`, and what blocks the idiomatic form

## Symptom

```python
x = ""
if not x:
    print("empty")
```

renders (all opt levels) as:

```rust
thread_local! { static __SHV_x: RefCell<String> = const { RefCell::new(String::new()) }; }

#[allow(non_upper_case_globals)]
fn main() {
    __SHV_x.with(|v| *v.borrow_mut() = "".to_string());

    if format!("{}", __SHV_x.with(|v| v.borrow().clone())).is_empty() {
        print!("empty\n");
    }
}
```

while every other backend keeps the variable native (go `var x string` + `s2s(x) == ""`,
zig `var x: []const u8` + `x.len == 0`, py `x = ""` + `not x`, js `let x = ""` +
`String(x) === ""`).

## Root cause (found, verified)

The py frontend lowers `if not x:` to a `test` Call whose operand spelling lives in
the **arg TEXT**: `test("-z \"$x\"")`. `analyze_var_borrowable`'s expression walk
(`shir.rs`) had no arm for `IrExpr::Str`, so the `$x` reference inside that text never
registered as a read. The verdict therefore withheld (`read` was empty) and `x` stayed
an owned `thread_local`.

Verified with a direct probe: `analyze_var_const` → `[("x", Const)]` but
`analyze_var_borrowable` → `{}`, with `read={}` in the walk's accumulator.

## The fix that works for t27 — and why it was NOT landed

Adding the missing arm (`IrExpr::Str` → `dollar_vars()` mentions) makes the verdict
report `x`, and t27 becomes:

```rust
fn main() {
    let x = "";

    if x.is_empty() {
        print!("empty\n");
    }
}
```

(also needs two renderer-side pieces: a `format!("{}", X)` → `X` identity strip for the
interpolated `-z` operand, and treating `test`/`not` as inline calls in
`list_profile::scopes::is_inline_call` so the read is not marked risky.)

**It regresses the corpus, so it was reverted.** Making these variables locals changes
which renderer paths run and exposes latent bugs in the pass-2 local machinery:

| Regression | Cause |
|---|---|
| `bench-increment.sh` | `let __n` emitted without `mut` (E0384: cannot assign twice to an immutable variable) |
| `055_factorize.sh` | a nested `if` branch re-declares `let mut factors`, shadowing the function-top binding |
| `parse-glob-question-in-arg.sh` | `mismatched types: expected String, found &str` |
| `parse-test-with-source.sh` | `main function not found in crate` |

Differential gate: baseline **PASS=500 / FAIL=48**; with the walk fix **496 / 52**.
So the fix is correct in isolation but must land together with the pass-2 local repair
(see below), not before it.

## The prerequisite: pass-2 deferred `let` ownership

`Render::local_init` is consulted by `local_write_stmt` to decide whether a write emits
the declaration or a plain assignment. It is a single module-wide `BTreeSet` consumed in
render order, which breaks in three ways once more vars become locals:

1. **Function bodies.** The function's own first write must own its `let`. Two passes
   render each body (the pass-3 *probe*, then the *commit* render), and each needs the
   ownership seeded fresh — otherwise the probe consumes the slot and the commit emits
   a bare assignment to an undeclared name.
2. **Sibling blocks.** The IR can reach a variable's first write through several paths
   (`factors=""` at the function top, then again inside a nested `if`). Only the
   statement that actually renders FIRST may declare it.
3. **`mut`.** A local written more than once needs `let mut`; `local_mut` comes from
   `compute_local_vars` and must be correct for names that only became locals after the
   borrow verdict widened.

A sketch that addresses (1) and (2) — seeding the owner set per body with a
render-order walk (`IrStmt::Assign`/`Declare`/`Expr(setVar)` test at each statement
BEFORE descending into its blocks) and inverting the set's meaning from
"already initialised" to "still owes a declaration" (`remove` instead of `insert`) —
was written and got t27 fully idiomatic, but did not fix `055`'s shadowing and added the
`&str`/`mut` regressions above. It is worth doing as its own change, with the four
corpus tests as the acceptance criteria.

## Recommendation

Land the pass-2 local hardening first (with tests), then re-apply the walk fix plus the
two renderer pieces. t27 and the differential gate are the acceptance criteria:
`PASS >= 500` with `t27` rendering `if x.is_empty() { … }`.

Saved WIP for that follow-up (not committed):
* `/tmp/wip_now.rs`      — rust_backend.rs with the identity-strip + seeding sketch
* `/tmp/wip_shir.rs`     — shir.rs with the `IrExpr::Str` walk arm
* `/tmp/wip_scopes.rs`   — scopes.rs with `test`/`not` as inline calls
