# triage: t86/t88 red from undefined `_i_sqrt_nv` loop bound (concurrent)

Date: 2026-09-09. From: py gate 85/87 (DIFF t86_factor.py, t88_factor53.py).

## NEED
`_i_sqrt_nv` (cstyle-loop bound for `int(n**0.5)`) must be defined where
used, or the cond must reference the store temp that is.

## FAILING-CASE
`t86_factor.py` / `t88_factor53.py`: emitted body has
`sh2.setVar("_i_sqrt_n", sh2.arith("(int(sqrt($1)) + 1)"))` but the loop
cond reads `_i_sqrt_nv` (native-`v` suffix), which is never declared —
`i < undefined` is false, zero trips, every factor list is `[]`.

## EVIDENCE
- `SH2_NO_ARRAY_MIGRATE=1` (store path, array pass fully disabled):
  still `[]` — NOT the array migration (kill-switch proof).
- t89/t90 (different bounds, no `isqrt` temp) pass, t89 with the array
  migration active (`const factors` + push, output byte-identical).
- Frontend `main.go` working tree renames hoist temps (`_i_sqrt_n`,
  commit 3be84da5 context); the `v`-suffixed native binding the cond
  expects is never emitted (store-only-native side, in flight).

## OWNERSHIP
Frontend hoist-temp naming × store-only-native binding emission (both
in flight). The array migration is behavior-preserving here (both paths
`[]`) and verified sound on t89; no action on the array side.
