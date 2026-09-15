# shIR→shIR transforms for squares-map (and frontend A1 generally)

Three shared transforms close the gap between the **frontend-emitted**
A1 (py-sh-go, c-sh-go, …) and the shapes the renderers and the CUDA
candidacy want. They live in `sh2perl/src/transforms/`, are registered
in `transforms::all()`, and are also wired into the **frontend A1
ingress** (`otranspilerl::ingest`) so every backend benefits, not just
python-O4.

## The problem

`squares-map` (materialise `a[i]=i*i`, then a mod-2^32 checksum) is the
bench's fill+consume shape. The shell frontend's parser already emits a
native `ForInit` and `fuse-fill-consume` collapses the two loops, so the
bash GPU leg is fast. The Python frontend emits:

```python
N = …
a = []                          # a = setArray(a, [])
for i in range(N):              # i = 0; while (i < N) { …; i++ }
    a.append(i * i)             # a = setArrayAppend(a, [i*i])
s = 0
for i in range(N):
    s = (s + a[i]) % M          # ((s + a[Cast i]) % M + M) % M
```

— structured `Arith` conditions, `Cast(Int64, …)` exactness markers,
runtime `setArrayAppend`, an explicit empty init, and a sign-correct
floor-mod composition. None of the shell-shaped passes matched, so the
array stayed materialised and only `map-only` CUDA ran.

## 1. `counted-arith-forinit` (new)

Recovers `IrStmt::ForInit` from the counted `while` written with
**structured arithmetic** (`i = 0; while i < N { …; i++ }`), the
structured-`ArithAst` sibling of `counted-while-forinit` (which matches
the shell `BinOp`/`let`-text forms). Both feed the renderers' native
counted-loop arms and the CUDA candidacy; keeping them separate means
neither can regress the other's shapes.

**Vetoes:** the condition must read the counter; the trailing update
must be exactly `v += 1` / `v++` / `v = v + 1`; the body must not write
or escape the counter; `$?` reads veto (the step's deletion shifts
status observation).

## 2. `append-to-store` (new)

Rewrites a counted loop's growable append `a = setArrayAppend(a, [v])`
into the affine indexed store `a[i] = v`. Every backend renders the
store more cheaply than a growable call, and the shared analyses key on
stores (CUDA map candidacy, `fuse-fill-consume`).

**Vetoes (refuse > guess):** exactly one append site; the array has an
empty `setArray`/array-literal init and no other write anywhere in the
program; the append is 1:1 (`[v]`, not `[a, b]`); the loop is counted
from 0 stepping +1; no `break`/`continue`/`return`/`goto` in the body.
Reads elsewhere are allowed — after the fill the contents at every index
are identical to what the append built.

## 3. `fuse-fill-consume` (extended)

The existing pass (covering fill + same-space consumer → one loop, RHS
forwarded, materialisation deleted) now accepts the frontend shapes:

- `arith_affine` treats `Cast` as transparent, so `a[Cast(i)]` keys and
  `i = Cast(0)` inits forward (the forwarded RHS keeps its own casts);
- `bound_of_cond` gained the structured `Arith(Bin{cmp, Var, Var})` arm
  (the shell text form is unchanged);
- an explicit empty `a = setArray(a, [])` init no longer vetoes the
  whole-program array discipline (it is a dead store after fusion).

Everything else — the exact-shape vetoes, the whole-program array
discipline, the gap-write discipline — is unchanged.

## Wiring

`otranspilerl::ingest` runs, in order, for **every** target
(`c`, `perl`, `estree`, `go`, `rust`, `java`, `zig`, `python`, `sh`):

```
process-subst → split-set → [text-ops] → counted-arith-forinit
             → append-to-store → fuse-fill-consume → restructure
```

python-O4's CUDA candidacy view calls the same two transforms directly
(plus the cast-stripped i64 view the mask plan needs). One
implementation, both call sites.

## Effect

For the Python `squares-map` A1:

| render | before | after |
|---|---|---|
| C (`--emit-c`) | two `while` loops, `_sh_arr_set`/`_sh_arr_get` | **one loop, no array** |
| estree / perl / go / rust / zig / python / sh | `setArrayAppend` / array reads | **none** (0 refs) |
| CUDA candidacy | map-only (800 MB readback) | **fused** (map + reduce) |

The C-backend shell corpus is unchanged: `harness/c_gate_main.sh`
**637/0/7**. The frontend execution gate (`frontends/py-sh-go make test`,
frontend A1 → ESTree → node vs CPython) is **95/95**. The Perl corpus
is byte-identical with and without the new transforms
(`SH2_TRANSFORMS` A/B: 285/267 both, same fail set — the 267 are the
mid-flight coworker breakage, not this work).

## Tests

- `transforms::append_to_store::tests` — rewrite, two-appends veto,
  non-empty-init veto, other-write veto, break veto, step≠1 veto.
- `transforms::counted_arith_forinit::tests` — both step forms,
  `+1` assign, cond-must-read-counter veto, continue veto, shell-text
  cond left alone.
- `transforms::fuse_fill_consume::tests::frontend_cast_shapes_fuse` —
  the full frontend shape (Casts, structured cond, flattened `a[i]`,
  composed floor-mod, empty init) fuses; `frontend_literal_bound_still_vetoes_gap_write`.
- `bash_o4::py::tests::candidacy` — the same shapes reach map/reduce/seq
  candidacy through the shared transforms.

## Notes

- `counted-while-forinit` had a latent `i - 1` underflow after fusing a
  pair at index 1; both counted-loop passes now clamp with
  `.saturating_sub(1).max(1)`.
- The transforms are per-backend selectable through the existing §11
  machinery (`transform_applies` / `SH2_TRANSFORMS`); none declares a
  target restriction, so all backends see them.
