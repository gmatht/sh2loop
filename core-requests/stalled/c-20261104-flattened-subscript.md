# Core: element writes keep the subscript as TEXT — and `$((…))` in an array literal produces a stray `)`

From: c backend. Date: 2026-11-04. Severity: **B is a whole-script
failure**, A is a correctness hole every backend has to guess around.

## B. Unquoted `$((…))` inside an array literal emits a stray `)` command

Measured today against this tree (`--target shir --raw`):

| source                              | shIR                                          |
|-------------------------------------|-----------------------------------------------|
| `x=9; a=($x); echo "${a[0]}"`       | ok                                            |
| `a=($((1+1))); echo "${a[0]}"`      | 3rd stmt is `Block[Warn("syntax error near unexpected token `)'"), Exit 2]` |
| `x=9; a=($((x+1))); …`              | same                                          |
| `e=(1 2); e+=($x $((x+1))); …`      | same                                          |
| `a=("$((1+1))")`                    | ok (quoted)                                   |
| `echo $((1+1))`                     | ok (not a literal)                            |

bash prints `2` for the second row. What the C generator emits is not a
broken program — it IS the `stray_reserved_word` transform's abort
(`src/transforms/stray_reserved_word.rs`), built from a `SimpleCommand {
name: ")" }` the parser recovered out of the arithmetic expansion. So the
transform is behaving correctly on a statement that should never exist:
**anything after the array literal never runs, and the program exits 2**.

Blast radius: every backend (the transform is shared), and the class is
not exotic — `arr=($((n*2)))` is ordinary shell. The C battery has it
pinned as `58e_xfail_dense_append_arith`; it is NOT a subscript bug (a
quoted or non-literal form is fine, and `$x` alone is fine), it is the
expansion's own closing paren surviving as a command.

## A. `n[SUB]=v` arrives with `indices: []` and the subscript in the name

`declare -ia n; i=1; n[$((i*2))]=5` lowers to

```json
{"expr": {...}, "targets": [{"indices": [], "sigil": null, "var": "n[$((i*2))]"}],
 "type": "Assign"}
```

so the subscript is opaque TEXT. Consequences, all measured:

1. **Every consumer parses it separately.** The C backend now has one
   classifier (`subscript_explicit_arith` / `subscript_arith_inner` /
   `classify` in `proofs/verus/c_subscript.rs`) shared by the declaration
   census and the store arm, because when they were separate predicates
   `declare -ia n; i=2; n[i]=5` declared `long long n[]` and wrote
   `_sh_assoc_set(n_k, …)` — `'n_k' undeclared`, the C did not compile.
2. **No analysis can see the reads.** `i=3; n[$((i))]=9` kept 2 of 3 shIR
   statements: `dead_store_elim` judged `i` unread (its only mention is
   inside the name), deleted the store, and the renderer then substituted
   an undeclared var. I fixed the C-side census
   (`subscript_read_names` + `arith_read_names`, with the closure
   obligation in `c_subscript.rs`), but every OTHER pass that reasons
   about reads (copy propagation, const folding, list profiling, the
   numeric analyses) has the same blind spot, and each will need the same
   patch.
3. **`${i}` in a subscript**: the braces survive, so the C store arm's
   `starts_with("${")` branch routes it to assoc storage while the
   declaration census excludes every `$`-prefixed text. Still divergent;
   proved as a divergence (`assoc_dollar_brace_remains`), not fixed,
   because a renderer cannot know whether the core meant an index.

### What would make this disappear

Lower the subscript properly: `indices: [IrExpr::Arith(…)]` for the
arith forms (and a Str key for the assoc/word forms), with the storage
class left to the declare, exactly as `t.indices` already works for the
cases the core does split. Then a subscript reference is an ordinary IR
reference: no text parsing at any consumer, no read hidden from the
analyses, and no renderer guessing whether `$((i*2))` is an index or a
key.

Until then the C backend keeps its classifier (37 obligations pin the
bash truth table, including the asymmetry that an explicit `$((e))` is
the VALUE as an assoc key while a bare operator text is LITERAL:
`m[i*2]`→`i*2`, `m[$((i*2))]`→`2`), but that workaround is **not** the
contract — it is a per-backend reading of a string the core could have
given it structurally.

## Notes for whoever picks this up

- The C side is green around the workaround: `harness/ifs-probe.sh`
  81 PASS / 0 FAIL / 9 XFAIL, corpus gate 613/31/7 (7 examples fixed by
  the DSE half alone), `proofs/verus/c_subscript.rs` 37 obligations.
- A separate, smaller find while probing (NOT filed separately because it
  is a renderer bug I own): an INT array's element read next to its count
  in one printf lowers through the ARGV path with
  `_sh_idx_init(…, n, n_len)` — `char **` where `n` is `long long[]` —
  and SIGSEGVs. Pre-existing, pinned as `60_xfail_int_argv_face`.
