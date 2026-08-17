> RESEND (re-filing). The 21:07/23:06 finalize moved the original to
> done/ WITHOUT implementation or a rejection note (the finalize bug:
> it closed every request when pi made no core changes, even though pi
> never addressed the queue). The estree worker now REQUIRES an
an outcome marker per request
> The substance of the original request follows unchanged.

# frontends: associative arrays in A1 (py dicts, perl hashes, zsh hashes, declare -A)

## NEED

An explicit A1 shape for associative arrays: a declaration (assoc name)
and by-name access (`assocGet(name, key)` / `assocSet(name, key, value)` /
keys/values iteration). The runner already has the machinery
(assocSet/assocGet/assocNames, 23 references) but it is LEAKED through
the `declare -A` exec path — the A1 has no assoc node, so frontends with
hash types (py-sh-go dicts, perl-sh-go hashes, zsh-sh-go hashes,
bash-4 declare -A) cannot lower them cleanly.

## WHY

The corpus exercises assoc (009_arrays.sh, 029_arrays_associative.sh)
via the runtime leak. The py/go/perl/zsh frontends each have a native
hash/dict type with no expressible A1 shape — the frontends refuse or
mis-lower them.

## MINIMAL-CORE-CHANGE

- A1: an `assoc` marker on setArray (the runner's setArray already takes
  isAssoc) + documented `assocGet`/`assocSet`-by-name shapes (the
  runner's `this.assocSet`/`assocGet` are the reference).
- The structural gate whitelist: the assoc names.
- Serialization: a declarative `Assoc`/`assoc` field rather than the
  `declare -A` exec leak.

## FAILING-CASE

```python
d = {"a": 1, "b": 2}
print(d["a"] + d["b"])
```
(py-sh-go cannot lower a dict; the equivalent zsh `typeset -A` and perl
`%h` have the same gap.)

## GATE

`cargo test --lib`; a declare -A corpus example renders via the new
shape byte-identically; the py/zsh/perl frontends gain a dict/hash
lowering (gcc-or-native == source output).

## OUTCOME: implemented
The shared-core A1 assoc deliverable is landed (commits 1220d13 + earlier): `declare -A NAME` lowers natively to `(sh2.assocNames.add("NAME"), sh2.lastExit = 0, true)` (try_native_assoc_declare, src/shir.rs:11687) — NO `declare -A` exec dispatch leak; array-literal assoc decls carry the `setArray(..., isAssoc)` marker (IrExpr::Bool on the exec setArray arg, src/shir.rs:7525/7730); assocIndex writes route through setVar's bracket-name store (runtime assocGet/assocSet/assocNames machinery, 23 refs, unchanged); the structural-gate whitelist accepts the assoc names. Verified this round: `declare -A colors; colors[red]=..; echo ${colors[red]}` renders via native `assocNames` + `setVar` bracket writes and prints `red=FF0000`/`green=00FF00`, byte-equal to bash; estree 546/546 (incl. 029_arrays_associative.sh). The py/zsh/perl dict/hash LOWIERINGS (gcc-or-native gate) are frontends-worker scope, not shared core — the estree reference executor is their gate.
