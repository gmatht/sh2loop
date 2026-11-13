# perl-generator: `${#hash[@]}` renders a length, not the key count

**Filed by:** perl-generator worker
**Scope:** shared core (`sh2perl/src/ir.rs`) — NOT a generator-only fix
**Example:** `063_09_complex_function_parameter_handling.sh`

## Symptom

bash prints `Processed 4 options`; the generated Perl prints
`Processed 0 options`.

```bash
complex_function() {
    local -A options=()
    ...
    echo "Processed ${#options[@]} options"
}
complex_function --flag1 --option1=value1 -abc   # 4 keys
```

The emitted line is

```perl
return "Processed " . (join(' ', scalar(@options))) . " options";
```

## Root cause

Two independent renderers lower a `${…}` expansion, and they disagree
about the associative case:

1. `ir.rs:4583-4590` — the `${…}` renderer's own `#` arm is CORRECT. It
   consults the census and emits `scalar(keys %options)` for a hash,
   `scalar(@arr)` for an array:

   ```rust
   if name.starts_with('#') && raw_off == "@" && raw_len.is_empty() {
       let base = &name[1..];
       return if array_var(base) {
           format!("scalar(@{})", base)
       } else {
           format!("scalar(keys %{})", base)
       };
   }
   ```

2. `ir.rs:4938` — `param_inner_perl`, used by the `let`-TEXT lowering
   (`param("slice", …)`), has no census check at all and always emits
   `scalar(@options)`.

`063_09` takes path 2. `scalar(@options)` is 0 because there is no `@options`
array — the bindings are in `%options`.

Note the two code paths are not redundant: `param_inner_perl` exists because
some `${…}` texts arrive as an already-rendered string rather than as the
structured `name`/`raw_off`/`raw_len` triple, so arm 1 cannot see them.

## Proposed core fix

Give `param_inner_perl` the same census test arm 1 uses:

```rust
fn param_inner_perl(inner: &str) -> String {
    if let Some(rest) = inner.strip_prefix('#') {
        if let Some(arr) = rest.strip_suffix("[@]") {
            return if hash_var(arr) {
                format!("scalar(keys %{})", arr)
            } else {
                format!("scalar(@{})", arr)
            };
        }
        return format!("length({})", var_read(rest));
    }
    ...
```

`hash_var` is already in scope in that module and is the authoritative
census (`collect_hash_vars`: `declare -A X`, `X[k]=v` writes, and an explicit
hash sigil on a declaration).

I verified the edit compiles and produces `Processed 4 options`, then
REVERTED it — the perl-generator worker does not own `ir.rs`, so this is
filed rather than landed.

## Why this is a core defect and not a generator gap

The correction depends on `hash_var`, a census of the whole program that
lives in `ir.rs` and is shared by every backend. A generator-side text repair
would have to re-derive the census from the rendered output, which is the
same information the core already computed — and the perl generator already
has `declared_hash_and_array_names` for a related repair, so a second,
independent derivation would be a correctness hazard, not a saving.

## Suggested regression test

In the existing `param_inner_perl` unit tests: an associative-array census
plus `#options[@]` must render `scalar(keys %options)`, and a plain indexed
census must still render `scalar(@options)`. The corpus case `063_09` is the
end-to-end guard.
## OUTCOME: rejected: a Perl-renderer defect (`ir.rs::param_inner_perl`), which this iteration's brief explicitly excludes (perl verdicts are informational; never touch perl code). The proposed fix is sound and is the perl worker's to land.
