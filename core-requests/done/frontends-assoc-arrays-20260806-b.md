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
