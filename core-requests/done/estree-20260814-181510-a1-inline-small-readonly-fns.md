# estree: A1 should inline the small read-only bash functions (render hot path)

## NEED
The transpiled game (sh2runtime/examples/mimecroft.sh) renders each frame
through ~768 `try_draw` calls, each dispatching ~7 helper functions
(`get_cell`, `abs` ×2, `mime_at`, `mime_tex_of`, `block_color`,
`texture_of`, `draw_block`→`get_bhp`) through `sh2.fnCall`/`sh2.callDirect`.
Profiling the transpiled run: `callDirect` = 172k calls at ~50µs each
(28.5% of the window), `fnCall` = 821k at 5µs (13.8%) — the two biggest
single costs, and the movement-frame render (the frame the player
perceives as "20fps") is dominated by them. All seven helpers are small
and effectively READ-ONLY (map/lookup/bhp array reads + pure if/case
chains) — exactly what the existing inline-pure-fns transform targets —
yet none are inlined: the transpiled output still contains
`await sh2.fnCall("get_cell", [td_a, td_b, td_c])` etc.

## WHY
Game-side, the render hot path was already hand-inlined (commit
"mimecroft: inline the render hot path") because the A1 does not do it:
the frame render dropped 21→9ms headless. But hand-inlining is brittle
and only covers one function; the engine should inline these patterns
everywhere they appear (the game has 20 get_cell sites, 10 abs sites,
25 draw_text sites, etc.).

## MINIMAL-CORE-CHANGE
In otranspilerl/src/lib.rs, extend the inline-pure-fns conditions to
cover the common small helpers:
- functions whose body is only: param→local copies (`a=$1; b=$2`),
  array reads (`x=${arr[$i]}`), pure integer arithmetic, and if/case
  chains with no side effects (no setVar of a module-level array, no
  exec/echo), regardless of the positional-param form;
- `abs`-style single-expression setters (`av=$1; if [ "$av" -lt 0 ]; then av=$((0 - av)); fi`).
The current transform appears to skip functions that read arrays or
take `$1` params; the game's helpers are exactly that shape.

## FAILING-CASE
```
$ cat > /tmp/abs.sh <<'EOF'
abs() { av=$1; if [ "$av" -lt 0 ]; then av=$((0 - av)); fi; }
x=-5
abs $x
echo "$av"
EOF
$ node -e "… bashToJS('/tmp/abs.sh') …"   # A1 path
# emitted JS: sh2.fnCall("abs", [x]) — a runtime dispatch
# expected: the 3-statement body inlined at the call site (x < 0 ? -x : x)
```

## OUTCOME: rejected: target is `otranspilerl/src/lib.rs` — otranspilerl is a SEPARATE repo (owns its own git + its own core-request mediation workflow) whose A1 frontend/typing/emitter is the estree(A1) worker's domain, NOT the shared core (src/shir.rs, src/estree.rs, src/parser/, shir_json*, harness/*). No shared-core change can fix the A1 BigInt/await/inline/array-lift bugs it references; re-route this request to the otranspilerl worker's queue.
