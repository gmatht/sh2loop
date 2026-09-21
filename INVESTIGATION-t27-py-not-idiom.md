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

**Three** gates each have to open, in this order. The first one alone is not enough —
which is why an earlier attempt at the analysis fix appeared to "do nothing".

1. **`analyze_var_borrowable` never saw the read.** The py frontend lowers `if not x:`
   to a `test` Call whose operand spelling lives in the **arg TEXT**
   (`test("-z \"$x\"")`). The expression walk (`shir.rs`) had no arm for `IrExpr::Str`,
   so the `$x` inside that text never registered as a read; the accumulator showed
   `read={}` and the verdict withheld.
   Probe: `analyze_var_const` → `[("x", Const)]` but `analyze_var_borrowable` → `{}`.

2. **`compute_local_vars` refused `x` as risky.** With the read registered,
   `use_scopes` returned `risky: true` for it, because `test` is not in
   `list_profile::scopes::is_inline_call` — the scope walk treats an unknown call as a
   possible file-scope helper that would *capture* the argument. `local_scope` rejects
   any name with a risky use, so `locals=[]` and `x` stayed a thread_local even though
   the borrow verdict now named it.

3. **The interpolator wrapped the operand.** `-z "$x"` renders through
   `dollar_interp`, which emits `format!("{}", <read>)` for the `$x` part; with the
   whole word being one part that is the identity, leaving `format!("{}", x).is_empty()`.

Opening all three gives the target output:

```rust
fn main() {
    let x = "";

    if x.is_empty() {
        print!("empty\n");
    }
}
```

## The fix that works for t27 — and why it was NOT landed

All three pieces together make t27 idiomatic. **It regresses the corpus, so it was
reverted.** Making these variables locals changes which renderer paths run and exposes
latent bugs in the pass-2 local machinery and its neighbours:

| Regression | Cause | Status |
|---|---|---|
| `bench-increment.sh` | the arith-status path emits `let __n = if __SH_ARITH_ERR…` **unconditionally**; when `__n` is *also* a user variable (this test's loop counter) it shadows it, and the rebind is immutable (E0384) | **diagnosed, fix known**: gensym that binding (`__n` → `__n8`) — verified to fix the test |
| `055_factorize.sh` | a nested `if` re-declares `let mut factors` instead of assigning, shadowing the function-top binding | open — the function-top `factors=""` never reaches `local_write_stmt` at all (see below) |
| `parse-glob-question-in-arg.sh` | `mismatched types: expected String, found &str` | open |
| `parse-test-with-source.sh` | `main function not found in crate` | open |
| `061_test_local_names_preserved.sh`, `parse-error-export-empty.sh`, `typeset-cmdsub.sh` | further fallout once the extra names become locals | open |

Differential gate: baseline **PASS=500 / FAIL=48**; with all three pieces **494 / 54**.

### The `055` puzzle (worth reading before attempting this)

Seeding the owner set correctly (`owned={"factors","n"}` for the body, confirmed by
trace) is *not* sufficient, and the reason is instructive: instrumenting
`local_write_stmt` shows that for `factors` it is called **only** at depth 4 and 5 —
the nested writes. The function-top `factors=""` never goes through it, even though
the emitted text contains `let mut factors = "".to_string();` at the right place.
So the function's leading assignments are rendered by a path other than
`Assign → write_str → local_write_stmt`, and any owner-seeding scheme that assumes
otherwise will mark the wrong statement. **That path must be found first.**

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

## Acceptance test

`harness/py-idiom-gate.sh` renders selected py-sh-go programs to Rust and asserts
local-variable shapes (must-absent + must-present regex per case). It exists because
**the bash corpus never exercises the py frontend** — `./fail` is 100% `.sh`, so t27's
shape was untested either way.

Current: **3/5**. The two failures are exactly this follow-up:

```
FAIL t27_not_expr: non-idiomatic (matched /thread_local/):
    thread_local! { … static __SHV_x: RefCell<String> … }
FAIL t27_not_expr: non-idiomatic (matched /\.borrow\(\)\.clone\(\)/):
    if format!("{}", __SHV_x.with(|v| v.borrow().clone())).is_empty() {
```

The three passing cases pin what is already landed: t26's constant-RHS compare (no
`__sh_glob_like`/`__sh_fnmatch`, no allocation) and t25/t24 rendering py variables as
plain locals. **A fix for this investigation must move the gate to 5/5** while keeping
the differential Rust-vs-bash gate at `PASS >= 500`.
