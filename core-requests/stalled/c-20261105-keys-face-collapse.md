# `${!a…}` collapses five spellings onto one node — the face bit and the bounds are lost in the PARSER

Filed 2026-11-05 by the C backend. Shared-analysis/parser scope, so an `.md`
request rather than an offer: no backend can carry this alone.

## What the shIR says (measured with the CLI's own `--target shir --raw`)

Five different programs, one node:

```
a=(p q r); v="${!a[*]}"        -> param("slice", "!a", "@", "")
a=(p q r); v="${!a[@]}"        -> param("slice", "!a", "@", "")
a=(p q r); v="${!a[*]:1:2}"    -> param("slice", "!a", "@", "")
a=(p q r); v="${!a[@]:1:2}"    -> param("slice", "!a", "@", "")
a=(p q r); v="${!a[1]}"        -> param("slice", "!a", "@", "")
```

The `[*]`/`[@]` face, the offset/length, and even the SUBSCRIPT are gone. A
renderer of that node therefore cannot distinguish any two of them.

## What bash does (measured, bash 5.2.21, one-word context)

| spelling | bash | note |
|---|---|---|
| `${!a[*]}` | `0 1 2` | IFS[0]; an EMPTY IFS concatenates (`012`) |
| `${!a[@]}` | `0 1 2` | IFS[0]; an EMPTY IFS falls back to a SPACE (`0 1 2`) |
| `${!a[*]:1:2}` | **error** `p q r: invalid variable name`, rc 1 | the slice INDIRECTS the joined VALUE list — it is not a key slice at all |
| `${!a[@]:1:2}` | same error | |
| `${!a[1]}` | empty | indirect expansion of element `q`, which is not a variable name |

So the family has FOUR behaviours behind ONE node. `sh2perl/proofs/verus/c_join_ifs.rs`
now carries this as a proved impossibility (`k1b`/`k1c`: no `g(false, 0, big(),
·, ·)` is exact for all five) plus the exactness DOMAIN of what a renderer can
still do (`k1d`).

## What the C backend does today, and what it costs

The keys join reads IFS[0] and falls back to a space (the `[@]` rule). That is

- **exact** for `${!a[@]}` under every IFS, and for `${!a[*]}` whenever IFS is
  non-empty (both faces read IFS[0] there) — this retired `ifs-probe` case 56
  (`declare -ia n; n[0]=7; n[2]=9; IFS=:; ${!n[*]}` -> `0:2`);
- **wrong for exactly one row**: `${!a[*]}` with an EMPTY IFS (bash `012`,
  we render `0 1 2`);
- unable to reproduce the two SLICE spellings (bash rejects them) or
  `${!a[1]}` (bash is empty) — both are indistinguishable from the whole form.

## The ask

Either of two shapes, whichever fits the node model:

1. **carry the face + bounds** on the existing node:
   `param("slice", "!a", "@"|"*", off, len)` — i.e. stop rewriting the face to
   `"@"` and stop dropping `off`/`len` for a `!`-prefixed name. The renderer
   then has everything it needs for the two whole forms (and can reject or
   approximate the slice spellings honestly). This is a parser change, no new
   node.
2. a distinct node for the whole family, e.g. `keys(arr, face, off, len)` with
   an explicit "indirect" flag for the slice spellings — the more honest shape,
   but it needs a contract-gen spec plus a renderer arm in every backend.

(1) is a strict improvement and is what the C renderer is written against
already. Acceptance test on the C side: the five rows above, measured by
`harness/ifs-probe.sh` plus the empty-IFS row; the model's `k1d` already states
what becomes provable once the bit arrives.

Blast radius if the change lands: `c_join_ifs.rs` `k1c` (the impossibility)
stops applying and is replaced by the exactness proof; no other model reads
this node.
