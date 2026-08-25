# rust-frontend: param("len", ARRAY) folds to String(getVar(name)).length — wrong for array variables

## NEED

`${#arr}` on an array variable must be the ELEMENT COUNT. The A1 shape
is `{"func":"param","args":["len","<name>"]}` (what debashc itself emits
for bash `${#a}`). On the ESTree/JS tier-1 stack this folds to

    String(sh2.getVar(name)).length        // shir.rs ~27852: member(val(), "length")

but the runtime's `getVar` returns the SCALAR view of an array variable
(`String(v[0] ?? "")`, sh2runtime.js getVar), so the count is the length
of the FIRST ELEMENT'S string, not the element count.

## REPRO (pure bash, canonical core shapes — no frontend involved)

    #!/bin/bash
    a=(10 20 30)
    echo "${#a}"          # native bash: 3

    debashc --shir al.sh | debashc --shir-in-estree | \
      node harness/estree-runner.mjs /dev/stdin
    # prints 2  (length of "10")

The generated ESTree is `String(sh2.getVar("a")).length`.

## WHY IT MATTERS

- Every frontend lowering Rust `Vec::len()` / Go `len(slice)` / C array
  counts wants this read; it currently cannot be expressed correctly,
  so frontends must refuse it (rust-frontend refuses Arr::len today).
- Pure-bash corpus scripts using `${#a}` on arrays are silently wrong
  on the JS tier (element counts vs first-element lengths).

## MINIMAL-CORE-CHANGE (either side; estree worker's call)

1. RUNTIME: make the known-array rewrite cover the folded form —
   lower.js already rewrites `X.length` on KNOWN array names and
   getVar on known arrays could return the array (or arrayLen) instead
   of the scalar view when the caller context is a length/count.
2. CORE: in the param-len fold, consult var verdicts/types: an
   array-typed name lowers to `sh2.arrayLen(name)` (the runtime exports
   it, sh2runtime.js:2832) instead of `String(getVar).length`.
3. CONTRACT: if arrays need a first-class type in var_types so the fold
   can see them, that is the larger open item (the rust frontend tracks
   Arr-typed vars and can emit annotations once a type exists).

## ALSO GATED ON THIS (added 2026-08-25)

The rust frontend's iterator-chain desugar now supports
`.enumerate()` / `.rev()` / `.map(|(i, x)| ..)` tuple-destructuring —
all lowering to exact index-based while-loops whose element reads go
through `arrayIndex` and whose positions are the loop index (never a
materialized pair). They still fail the stdout oracle because the
ACCUMULATED arrays are read back via `getVar`/`${#arr}` (same scalar
view). Example: testdata-pending/t56_enumerate_rev.rs — native prints
30/true/true/18, transpiled 0/c/8. Promotes automatically with the fix.

## ALSO GATED (added 2026-08-25, second feature)

`.skip(K)` / `.take(N)` / `.map(..)` iterator chains accumulate into a
new array via setArrayAppend (appends verified EXACT by instrumentation:
values 30/40/50 land in the store), then read their length back via
`${#acc}` — which folds through the same broken getVar scalar view
(`__sh2l5 = String(getVar("skipped")).length` => 2 instead of 3).
testdata-pending/t58_iter_skip.rs. Same single fix unblocks: t53, t56,
t58, and Vec::len generally.

## EVIDENCE

- al.sh repro above (native 3, transpiled 2).
- rust-frontend testdata/t51_len_isempty.rs exercises Vec::len via the
  exact same fold; its len prints are commented out until this lands
  (is_empty IS exact today: empty <=> "" under both models).
