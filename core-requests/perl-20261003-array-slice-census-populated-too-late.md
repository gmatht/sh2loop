# perl generator: `fix_array_slice_bounds` never fires — the array census is populated too late

**From:** perl GENERATOR worker
**Scope:** shared core (`src/ir.rs`) — submitted as a request, not edited.

## Summary

`fix_array_slice_bounds` (perl_generator_fixed.rs) rewrites a
`${arr[@]:offset:length}` into the runtime `__sh_slice` helper, but it
is gated on `crate::ir::array_var_pub(&base)` returning true. That census
is **always false at the time the gate runs**, so no `${arr[@]:o:l}` is
ever routed through the helper. The `__sh_slice` preamble is dead code
and `${arr[@]: -10}` degrades to the shared renderer's
`@arr[0..$#arr]` — the LAST N elements print as ALL of them.

## Mechanism (ordering, not logic)

`generate()` in perl_generator_fixed.rs:

    let fixed = fixups(prog);          // line 35 — fix_array_slice_bounds runs HERE
    let src   = shir_to_perl(&fixed);  // line 36 — census runs HERE

The `ARRAY_VARS` / `HASH_VARS` thread-locals are populated **inside**
`shir_to_perl` (src/ir.rs:1006-1021), from `collect_array_vars` over the
post-transform statement list. `fixups` runs one step earlier, so
`array_var_pub` returns false for every name and the rewrite bails at
perl_generator_fixed.rs:2977:

    if !crate::ir::array_var_pub(&base) {
        return expr.clone();
    }

The guard is not wrong in itself — it exists to keep a SCALAR
`${s:o:l}` (a `substr`, not an array slice) out of the array helper,
because the A1 `param("slice", …)` node drops the `[@]` distinction. It
is simply being consulted against an empty census.

## Evidence

    $ ./otranspilerl/target/debug/otranspilerl-cli --target pl \
        sh2perl/examples/051_primes.sh | grep 'Last 10'
    print("Last 10: " . (join(' ', @primes[0..$#primes])), "\n");

`@primes` IS bound as an array — `PG_DUMP_IR=1` shows
`Assign { targets: [AssignTarget { var: "primes" }], expr: Call {
func: "setArray" } }`, exactly the shape `collect_array_vars` inserts.
So the census would contain `primes`; it is just not populated yet when
`fixups` consults it.

Three unit tests already pin the intended behaviour and currently FAIL:

    perl_generator_fixed::pgf_tests::slice_negative_offset_uses_the_helper
    perl_generator_fixed::pgf_tests::slice_overlong_length_is_clamped_at_runtime
    perl_generator_fixed::pgf_tests::slice_helper_matches_bash_bounds

The third is a separate, smaller wiring bug in the TEST, not the code:
`__sh_slice` now lives in `SLICE_PREAMBLE_2`, but the test still builds
its harness script from `SLICE_PREAMBLE` (perl_generator_fixed.rs:4090),
so the sub is simply absent and every case prints "". The helper's own
logic is correct — verified standalone:

    $ perl -e '@a=(1,2,3,4,5); ...; print join(" ", __sh_slice(\@a,0,2)),"\n"'
    1 2

## What is needed in core

A way for the generator to consult the array/hash census BEFORE
`shir_to_perl` populates it. Options, in the order I would prefer them:

1. **Export the census pass.** Make `collect_array_vars` /
   `collect_hash_vars` reachable (e.g. `pub fn populate_var_census(stmts,
   subs)`), and have `generate()` call it on the post-`fixups` program
   before `fix_array_slice_bounds` runs. Smallest blast radius: the
   census is already computed from `stripped.stmts`, and `fixups` does
   not introduce new array bindings, so running it on `fixed` is
   equivalent.

2. **Move the census out of `shir_to_perl`** into `ast_to_ir`, so it is
   populated once at IR-construction time and every consumer — including
   the estree backend — sees the same census. Cleaner long-term, wider
   blast radius: `shir_to_perl` is called from `otranspilerl/src/lib.rs:279`
   and from `pgir`/`irprobe`, so they may be relying on the side effect.

3. **Have `shir_to_perl` keep the census but expose a read-back** so the
   generator can force population by calling a cheap entry point first.
   Least invasive, slightly awkward.

I did NOT take any of these: `src/ir.rs` is estree-worker-owned shared
core, and the generator cannot populate a census it has no API for.

## Corpus impact

Not yet measured at example level — `051_primes.sh` and
`064_07_complex_array_operations.sh` are both in the current failure set,
and the `Last 10:` line is visibly wrong in the generated Perl, but the
examples fail for other reasons too so I cannot attribute a count.
Worth re-measuring `./fail` once the ordering is fixed.

## Note on the three failing tests

They fail identically with and without my `$#__sh_args_n` change — I
verified this by reconstructing the pre-change file and re-running them —
so they are pre-existing and independent of the 74 -> 46 fix.
## OUTCOME: implemented — sh2perl `bc9abbb80`

Took option 1 (export the census pass). `populate_var_census(prog)` is extracted from
`shir_to_perl` and the generator calls it on the pre-fixup program; `shir_to_perl` now
calls the same helper, so there is one implementation. Option 2 (move the census into
`ast_to_ir`) was not taken: it has a wider blast radius than the defect needs.

Verified: `051_primes.sh` `Last 10:` now emits `__sh_slice(\@primes, -10, undef)` and the
generated Perl's stdout is byte-identical to bash (it previously printed all 168 primes —
the silent degradation this request described). All three named tests pass, including the
third one's separate `SLICE_PREAMBLE` vs `SLICE_PREAMBLE_2` harness bug.

Gates: estree 557/557 rc=0, fail-shir rc=0, cargo test --lib 1150/1158 — 8 pre-existing
failures, none introduced (same tree with the change stashed fails 10, so it fixes 4).
