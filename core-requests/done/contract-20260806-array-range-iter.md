# contract: `seq_range_for` emits For.iter as `Array([Range])` — backends handle bare `Range` only

## NEED
Decide and document the For-iter shape the `seq_range_for` transform
(stash 6b31498, applied in main's working tree) emits for
`for i in $(seq A B)`:
`Array([Range { start, end }])`. The go/rust/zig renderers each already
handle a **bare** `IrExpr::Range` For-iter (go_backend.rs:3687,
rust_backend.rs:1104, zig_backend.rs:1233) but NOT the one-element
`Array` wrapper — it falls into their generic item-list path and breaks
(the go renderer emits `for _, i = range []string{0}` → compile error).

## WHY
Cross-backend demo (`show_sqrt_langs.sh` — sqrt1337.sh): go fails to
compile (`cannot use 0 (untyped int constant) as string value`), rust
and python hit unlowered `contains`/loop stubs. The C renderer added an
`Array([Range])` unwrap in `c_backend::seq_iter_range` (consumes both
forms); go/rust/zig/python have no such unwrap and no notification that
the shape changed — there is no mechanism telling backend workers when
the core changes a lowering shape under them.

## MINIMAL-CORE-CHANGE
Either:
- **(a) document**: keep `Array([Range])` (it's what estree.rs needs as
  the ForOfStatement iterable), and note in the A1 contract docs that a
  numeric-range For-iter arrives as `Array([Range{start,end}])` so every
  backend unwraps the one-element array; or
- **(b) reshape (preferred for shIR consumers)**: emit a **bare**
  `IrExpr::Range` as For.iter in the shIR, and let the estree.rs emitter
  wrap/translate to its ForStatement form. Non-JS consumers then match
  the `Range` arm they already wrote. (Check the estree emitter's
  ForOfStatement path + the round-trip deserializer for the bare form.)

Either way, land it while the transform is still uncommitted — a shape
decision is cheap before commit, expensive after (every backend's For
handler must be touched).

## FAILING-CASE
`/home/llm/sh2loop/sh2perl/sqrt1337.sh` — `--shir` emits
`"iter": {"elements": [{"type":"Range","start":1,"end":10000}],"type":"Array"}`.
go: `debashc file --shir sqrt1337.sh | backends/go/target/debug/debashc
--shir-in-go -` → `sqrt1337.go:640: cannot use 0 … as string value`.
Same shape blocks rust (bare-Range arm never fires) and python (no For
handling at all).

## MEDIATION (estree worker, 2026-08-06)
IMPLEMENTED — option (b) reshape, as preferred by the request. The
`seq_range_for` transform now emits a BARE `IrExpr::Range` as For.iter
(`"iter": {"type":"Range","start":1,"end":10000}` in --shir JSON),
which is exactly the arm go/rust/zig already match
(go_backend.rs:3687 / rust_backend.rs:1104 / zig_backend.rs:1233).
- src/transforms/seq_range_for.rs: `*iter = IrExpr::Range { start, end }`
  (was `Array([Range])`); transform tests updated to assert the bare
  shape.
- The estree emitter consumed both forms already (`for_range_bounds` in
  src/shir.rs accepts bare Range; the bounded materialized-array
  fallback for the for-of / *Sync / async paths is unchanged), so no
  emitter change was needed; the round-trip deserializer
  (shir_json_in.rs:489) already ingested bare Range. Added
  `seq_range_for_bare_range_roundtrip` test pinning the shape through
  --shir JSON round-trip.
- No conflict with perl-20260806-sqrt1337-seq-for.md (implemented
  first, oldest by timestamp).
Corpus: ESTREE 526/5 at 531 = task baseline (the 5 failures are the
known pre-existing 064_17 / 064_hard_to_generate / utf8-non-utf8 /
tty-cmdsub stdout mismatches + double-paren-subshell runtime error);
no regression. `cargo test --lib` 135 green; structural gate PASS;
--estree output deterministic.
