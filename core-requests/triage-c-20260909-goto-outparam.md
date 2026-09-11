# triage: C gate regressions — goto renders as no-op, out-params don't write back

Date: 2026-09-09. From: frontend-js-gate `c` (100/105; was green).
Owner: C worker (goto restructuring + out-param/memStore machinery).

## NEED
`t27_goto` must loop (print 3); out-param functions must write back
(`t71` prints "3 5").

## FAILING-CASES
`frontends/c-sh-go/testdata/`: `t27_goto.c`, `t30_goto_nested.c`
(goto family), `t71_multi_out.c`, `t72_multi_out_mix.c`,
`t78_readwrite_out.c` (out-param family). All were PASS; all now FAIL
(stdout mismatch). Repro: `./frontend-js-gate.sh c`.

## EVIDENCE

- Goto: `loop: i++; if (i < 3) goto loop;` renders the jump as `null;`
  (no-op) — the loop body runs once (`1` instead of `3`). Restructure
  stage emits no back-edge.
- Out-param: `getdim(&w, &h)` renders `memStore(addrOf(...))` writes
  inside the callee, but the caller reads plain `w`/`h` (still `""`) —
  the write-back channel (outparam_to_returns echo/capture destructure)
  is not connected.
- Both families are outside the estree arith/test lowering this session
  touched: no div/mod-with-Cast, no `test()` chains, no caseMatch, no
  arrays, no homed vars in any of the five IRs (the only shared-path
  contact is the `? 1 : 0` test unwrap, which provably preserves
  branch behavior — and these programs fail structurally, missing
  back-edges and write-backs, not misbranched).

## SCOPE NOTE
Unrelated to the t89 bigint work, crash fixes, `--library`, status
dedup, zero-cmp `%`, caseMatch lowering, and test-bool unwrap (all
provably dead for these inputs — see above). Please keep green
independently; do not bless the DIFFs.
