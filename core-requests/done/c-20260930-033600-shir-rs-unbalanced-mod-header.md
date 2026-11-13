# c: shared core does not compile — `mod range_analysis_tests` header deleted, body orphaned

## NEED

`src/shir.rs` in the **shared core** (`sh2perl/`, branch `main-worktree`) is left
in a NON-COMPILING state by an interrupted worker. This blocks *every* backend,
including c: `otranspilerl-cli` cannot be built, so the c gate cannot run at all.

```
$ cd /home/llm/sh2loop/otranspilerl && cargo build --bin otranspilerl-cli
error: unexpected closing delimiter: `}`
   --> /home/llm/sh2loop/sh2perl/src/shir.rs:57784:1
    |
1941 | ) -> HashSet<String> {
    |                      - this delimiter might not be properly closed...
1956 |     }
    |     - ...as it matches this but it has different indentation
...
57784 | }
      | ^ unexpected closing delimiter

error: could not compile `debashl` (lib) due to 1 previous error
```

This is NOT a c-backend defect and NOT a product bug. It is a half-finished
edit in a file the c worker is forbidden to touch.

## WHY — exact location

The file is modified-but-uncommitted:

```
$ git -C /home/llm/sh2loop/sh2perl status --short src/shir.rs
 M src/shir.rs
$ git diff --stat src/shir.rs
 src/shir.rs | 51 ++++++++++++++++++++++++++++++++++++++++++++++++---
 1 file changed, 48 insertions(+), 3 deletions(-)
```

A worker added a new test module `arith_len_placeholder_tests` and, while
inserting it, **overwrote the header of the existing `range_analysis_tests`
module**. Current state at `src/shir.rs:57076`:

```rust
57073:     }
57074: }
57075:
57076: #[cfg(test)]        <-- dangling: the `mod` line that followed was DELETED
57077:
57078:     fn ranges_of(src: &str) -> HashMap<String, (i128, i128)> {
57079:         let cmds = crate::Parser::new(src).parse().expect("parse");
```

HEAD has all three lines (`git show HEAD:src/shir.rs`, at 57028-57031):

```rust
#[cfg(test)]
mod range_analysis_tests {
    use super::*;
```

So `#[cfg(test)]` is now followed by a blank line and then a bare `fn` at
module scope, and the whole body of `range_analysis_tests` (every one of its
`#[test]` fns) is orphaned into the *previous* module. The stray `}` at the end
of file then closes nothing — hence `unexpected closing delimiter`.

The other delimiter hint rustc prints (the `}` at 1956, inside
`final_called_functions`) is **pre-existing at HEAD and harmless**; rustc only
lists it as a secondary candidate. Do not "fix" that one.

The work that the dead edit was attempting is a real, coherent fix (see the
`-48/+3` hunks): make the `${#arr[@]}` / `${#arr}` length placeholders
(`__sh2lena_*` / `__sh2lens_*`) never be wrapped/read as raw store variables in
arithmetic — in `wrap_true64_arith_ast`, `arith_bigint_safe_operand`, and
`exact_bigint_var_read`. That fix is worth KEEPING; only the module header was
clobbered.

## MINIMAL-CORE-CHANGE

Re-insert the deleted module header at `src/shir.rs:57076-57077`, restoring
`range_analysis_tests` as its own module and leaving the new
`arith_len_placeholder_tests` module intact:

```rust
#[cfg(test)]
mod range_analysis_tests {
    use super::*;
```

i.e. replace the current

```
#[cfg(test)]
<blank>
    fn ranges_of(src: &str) -> HashMap<String, (i128, i128)> {
```

with the three lines above. No production-code change is required; the +48/-3
arithmetic-length fix that is already in the working tree should be kept and
compiled/tested as-is.

## FAILING-CASE

```bash
cd /home/llm/sh2loop/otranspilerl && cargo build --bin otranspilerl-cli
# error: unexpected closing delimiter: `}`  --> src/shir.rs:57784:1

cd /home/llm/sh2loop/sh2perl && cargo test --lib range_analysis
# currently: the whole lib test target fails to COMPILE, so ZERO tests run
```

## NOTE — c worktree is clean and NOT implicated

For completeness, so the triager does not go looking in the c backend:

- `backends/c` compiles clean (`cargo build` → `Finished`, `cargo test --lib
  --no-run` → no errors). Its only defect was dead `SH2_DBG_VARS` scaffolding
  committed at HEAD, which I removed in the c worktree (0 occurrences remain).
- The c lib suite is **1043 passed, 8 failed**, and all 8 failures are
  pre-existing at HEAD (verified by stashing the c diff: 1040 passed, the SAME
  8 failed). Six are in `estree::tests` / `ir::tests`; two are the known brace
  pair filed as `c-20260930-021500-nested-brace-compound-not-constructed.md`.
- The c gate cannot be scored until this core file compiles again.

## OUTCOME: implemented — the `mod range_analysis_tests` header is restored (src/shir.rs:57996) and the tree compiles; `rustc` no longer reports the unexpected closing delimiter.
