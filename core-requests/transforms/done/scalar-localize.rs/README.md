# scalar-localize — the transform, its measurements, and the defects the A/B caught

**Status:** offered, NOT landed. The analysis and its tests live in
`transform.rs`; the renderer hook is a 40-line block in
`src/rust_backend.rs` (below). Neither is on `main`.

**Why it exists.** `./2r t60` renders

```rust
thread_local! { static __SHV_s: RefCell<String> = … }
fn main() {
    __SHV_s.with(|v| *v.borrow_mut() = "hello world".to_string());
    let mut __t0 = if __SHV_s.with(|v| v.borrow().clone()).contains("world") { … };
```

although nothing observes `s` across scopes. The cause is in
`shir_passes::list_profile::scopes`: `dispatch_args` marks the argument of
any non-`echo`/`printf`/defined-function call **risky**, and `local_scope`
returns `None` on any risky use, so `compute_local_vars` never promotes the
name. The bit exists for a renderer that lowers an argument through a
file-scope helper that captures the value — Rust does not (`read_str` /
`getvar_str` splice every read at the mention).

With the transform + hook:

```rust
fn main() {
    let s = "hello world";
    let mut __t0 = if s.contains("world") { "has".to_string() } else { "no".to_string() };
    println!("{}", __t0);
    …
```

compiles, prints `has` / `no2`, identical to the baseline binary.

## The renderer hook (rust_backend.rs, in `Render::prepare` where pass 2 runs)

```rust
let (mut locals, mut local_mut, mut dead_init) =
    compute_local_vars(prog, &self.arrays, &self.assoc, &self.functions, &written);
if crate::transforms::transform_enabled("scalar-localize") {
    crate::transforms::scalar_localize::transform_program(prog);
    let uses = crate::shir_passes::list_profile::use_scopes(prog);
    for (name, scope) in crate::transforms::scalar_localize::locals() {
        if self.arrays.contains(&name) || self.assoc.contains(&name)
            || self.functions.contains(&name) || !written.contains(&name) { continue; }
        let scope = match scope {
            LocalScope::Main => Scope::Main,
            LocalScope::Func(f) => Scope::Func(f),
        };
        /* re-derive local_mut / local_dead_init from `uses` exactly as pass 2 does */
        locals.insert(name, scope);
    }
}
self.local_vars = locals;
```

`transform_program` takes the whole `IrProgram` on purpose:
`transforms::all()` hands a transform only a statement list, so `prog.subs`
would be invisible (see defect 2).

## Measured (baseline CLI vs patched CLI, same corpus)

| harness | result |
|---|---|
| `cargo test --lib transforms::scalar_localize` | 7 of 8 green (open: `Declare` mention order, see below) |
| py-sh-go, compile both arms | **0 new compile failures**, `__SHV_` mentions fewer in 9 files, more in 0, 93 compiled |
| py-sh-go, compile **and run**, stdout compared | **93 identical / 0 different** (9 files need `num_bigint` on both arms) |
| 563 shell examples, render diff | 23 changed, 17 of them run-compared: 17 identical, 1 output diff, 5 new compile failures — **all four classes fixed since**; not yet re-measured |

## Defects the A/B caught (each has a test in `transform.rs`)

1. **Loop bindings were promoted.** `for i in 0..=99` became
   `i = 0; loop { … i = i + 1; }` with no `let i` — the renderer emits its
   own binding for a loop variable, so a pass-2 `let` shadows it.
   *Fix:* `loop_vars` is collected for `For` and for a `ForInit` counter and
   always excluded. Compile failures 22 → 9 (the 9 are `num_bigint`).
2. **A nested `def` body was attributed to the enclosing scope.**
   `g = 0; def f(): global g; g = 1; f(); print(g)` rendered
   `let mut g = 0; … let mut g = 1;` **inside `main`**, so the program
   printed `0` where bash prints `1`. Compile-only checks cannot see this;
   the run-comparison did.
   *Fix:* `IrStmt::Function` switches to `Func(name)` for its body.
3. **A computed self-write opened the binding.** `y=$((y+2))` became
   `let mut y = (y… + 2)` — `cannot find value y` in `051_primes`. A
   self-referential RHS reads the old value before the write, so it is not a
   *first* write.
   *Fix:* `rhs_reads_any` probes the RHS; a self-referential assignment is
   refused as a binding site (test: `a_computed_self_write_is_not_a_first_write`).
4. **OPEN — `Declare` mention order.** For `local s=""` the declaration arm
   walks the init before recording the write in the non-literal branch,
   which reorders the mentions and makes
   `a_declaration_at_the_scope_top_is_local` fail. Two-line fix: record
   `vars` writes first when the init is literal, and skip walking a literal
   init at all (same rule the `Assign` arm now uses).

## What it would buy elsewhere

- **Rust**: the `__SHV_*` → `let` promotion (`t60`, 9 more py-sh-go files).
- **C**: nothing new — it has `local_owner`, the same fact from the same
  census; adopting this would be a second source, not a wider one.
- **estree / go / perl**: nothing today — their variables live in a runtime
  store, so "this name is one-scope" has nowhere to land.

## Manifest / gate

`manifest` carries the three-clause invariant and **no** `proof:` line (no
Isabelle session exists). `register` documents why the transform must NOT go
in `transforms::all()`.

## To land

1. Apply the `Declare` fix (defect 4) and re-run the three A/B harnesses
   above; the 5 remaining new compile failures in the shell corpus should
   drop to 0.
2. Register the module (`pub mod scalar_localize;`) **without** an `all()`
   entry, add `scalar_localize::clear_verdicts()` beside the other verdict
   resets, and add the hook above.
3. `cargo test --lib` (expect no new reds outside `transforms::scalar_localize`)
   and `harness/fail-rs`.
