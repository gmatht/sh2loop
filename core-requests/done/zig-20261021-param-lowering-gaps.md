# zig: three param-lowering gaps that no backend can work around (information loss in A1)

All three lose information at lowering time, so every backend misrenders
them identically (verified: perl and zig agree with each other and
disagree with bash on each case). Filed from the zig backend gate.

## 1. `${x:+y}` conflates to `param(":-", x, y)`

`echo ${x:+y}` lowers to `param(":-", "x", "y")` — byte-identical to
`${x:-y}`. The `+`/`:+` alternate-value semantics (empty→"", set→y) is
unrecoverable downstream.

Probe: `x=; echo "plus:${x:+y}"; echo "minus:${x:-d}"` → bash prints
`plus:` + `minus:d`; the A1 carries `:-` for both, so perl prints
`plus:y` (verified via `--target=perl`).

No corpus file uses `:+` today (grep), so this is latent, not gate-blocking.

## 2. `${s:off:-len}` re-lexes the negative length as `:-`

`echo "sl3:${s:1:-1}"` (s=hello; bash: `ell`) lowers to
`param(":-", "s:1", "1")` — the `-` of `-1` is consumed as the `:-`
operator and the length arrives as positive `1`. The true length (-1,
chop-last) is gone from the A1.

Note `${x::-2}` (no offset) lowers correctly to `slice(x, 0, -2)`, so
only the offset+negative-length combination mislexes. One corpus file
uses the working form (`parse-substring-double-colon.sh`); none uses
the broken combination, so latent, not gate-blocking. (The zig backend
re-splits `:-` names containing `:` into scalar slices as a partial
mitigation, which yields `slice(s,1,1)` = `e` here — still wrong, but
right for every shape the core emits correctly.)

## 3. `X=v; X+=w` drops the base assignment

`n=1; n+=2; echo "n=$n"` lowers to a single `assign(n, +=, 2)` — the
`n=1` base is gone. bash prints `n=12` (string append); the lowered
program computes from zero/unset. Same for `s=ab; s+=cd` (bash `s=abcd`).

Suspect: redundant-store-elim (or copy-propagation) treats `+=` as a
plain overwrite and deletes the base write, missing the
read-modify-write. 051_primes.sh (`y+=2`, `z+=(a b)`) exercises `+=`
without a same-var base in the corpus, so impact there is limited, but
any `X=v; X+=w` program miscompiles in every backend (perl verified:
`$s = "cd"` for the `s=ab; s+=cd` probe).

## OUTCOME: implemented
All three gaps fixed. (1) `:+` now maps to `UseAlternative(_, true)` at
every parser site (colon operators are recognised only at the FIRST
colon). (2) `${s:1:-1}` now lowers to `ArraySlice("1", Some("-1"))`; the
estree native scalar slice and the harness runtime handle a negative
length as `len + (-len)`. (3) a compound `assign(_, "+=", _)` (and a
compound arith assign / IncDec) is now counted as a READ of the target by
both the const-prop DSE and redundant-store-elim, so the base store
survives; the Perl renderer string-concatenates a scalar `+=` (matching
bash and the estree runtime). Verified byte-identical to bash on
`--target perl` and `--target estree` for all three probes, including a
store-backed (non-lifted) slice name. Regression pins:
`parser::words::colon_operator_tests` and
`transforms::redundant_store_elim::keeps_base_store_for_compound_assignment`.
