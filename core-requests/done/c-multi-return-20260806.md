# c-frontend: A1 multi-value Return (the out-param transform's multi-out-param blocker)

## NEED

The A1 `Return` stmt carries ONE value. The out-parameter elimination
transform (harness/outparam_to_returns.py) currently REFUSES functions
with more than one write-target param — "multiple write-targets need
multi-return A1" — because the shell value-return channel (echo + capture)
can carry several values (one echoed line each), but the A1 Return shape
cannot express them. Multi-out-param C functions are common
(`void getdim(int *w, int *h)`, split, decompose).

## WHY

The C frontend's out-param transform handles the single-out-param case
(proven: fill/copy before-after both a=7 b=7). The multi-out-param case
is the next rung; it needs the contract to say how several returned
values are carried.

## MINIMAL-CORE-CHANGE

A multi-value Return form, backward compatible:
- `{"type":"Return","value": e}` (existing, single) stays valid.
- `{"type":"Return","values":[e1, e2, ...]}` — the emitter renders one
  echo per value (each on its own line, so the capture channel carries
  them); a `sh2.captureLines`-style helper (or the caller-side split)
  produces the array; per-target destructuring (JS `[a, b] = ...`, Go
  multi-return, Perl list) is the renderer's choice.
- The deserializer (shir_json_in.rs) accepts either field; the transform
  emits `values` for multi-write functions.

## FAILING-CASE

```c
void getdim(int *w, int *h) { *w = 3; *h = 5; }
int main(void) { int w, h; getdim(&w, &h); printf("%d %d\n", w, h); }
```
The transform refuses (2 write-params); with multi-return A1 it becomes
`(w, h) = $(getdim)` — the function echoes 3 and 5, the caller captures
and destructures.

## GATE

`cargo test --lib`; the out-param transform's multi-write case lands;
corpus unchanged (single-value returns dominate).
