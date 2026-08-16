# estree: A1 array refs with loop-var indexes collapse to literal-string var names

## NEED
The A1 path expands array writes `arr[$i]=v` into `sh2.setVar("arr[$i]", v)`
(a LITERAL string key — the index expression is NOT computed) when `$i` is a
while-loop induction variable, but into `sh2.setVar(\`arr[${i}]\`, v)` (the
computed template) when `$i` is a function parameter. The two forms write to
DIFFERENT runtime slots, so reads see nothing. Reads are equally broken:
`x=${arr[$i]}` becomes `sh2.arrayIndex("arr", "$i")` — the literal index
string — instead of the computed value.

## WHY
`examples/textures/texture-crack.sh` fills `cr[]/cg[]/cb[]/ca[]` in a
`while [ "$pi2" -lt $((SIZE*SIZE)) ]` loop and reads them back in the emit
loop. In the browser (A1 path) every write went to the literal key
`cr[$pi2]` while the emit read `arrayIndex("cr", "$pi")` — always empty, so
the crack (RGBA damage overlay) payload was garbage, its upload was skipped,
and the null uCrack texture binding then failed every block draw
(INVALID_OPERATION → black blocks). The game-side workaround routes every
array access through functions whose index is a `$1` param (crack_set/
crack_get — the game's map_set pattern, which the A1 handles correctly).
The core should treat loop-var-indexed array refs exactly like
param-indexed ones.

## MINIMAL-CORE-CHANGE
In the A1 array-ref lowering (otranspilerl/src/lib.rs): the index operand
of an array write/read must always be emitted as a COMPUTED expression
(the `\`arr[${i}]\`` template form), never as the literal source text
(`"arr[$i]"`), and the read must pass the computed index value to
arrayIndex — `sh2.arrayIndex("arr", String(i))` — not the source string
`"$i"`. The distinction currently seems to be whether the index variable
was seen in an interprocedural (param) position; the array-ref emitter
should not depend on that.

## FAILING-CASE
```
$ cat > /tmp/arr.sh <<'EOF'
SIZE=4
cr=()
pi2=0
while [ "$pi2" -lt $((SIZE * SIZE)) ]; do
  cr[$pi2]=$((pi2 * 10))
  pi2=$((pi2 + 1))
done
echo "cr[2]=${cr[2]}"
EOF
$ node -e "… bashToJS('/tmp/arr.sh') …"   # A1 path
# emitted JS contains: sh2.setVar("cr[$pi2]", …)  (literal key)
# runtime: cr[2]=   (empty)
# expected: cr[2]=20  — and the JS: sh2.setVar(`cr[${pi2}]`, …)
```

## OUTCOME: rejected: target is `otranspilerl/src/lib.rs` — otranspilerl is a SEPARATE repo (owns its own git + its own core-request mediation workflow) whose A1 frontend/typing/emitter is the estree(A1) worker's domain, NOT the shared core (src/shir.rs, src/estree.rs, src/parser/, shir_json*, harness/*). No shared-core change can fix the A1 BigInt/await/inline/array-lift bugs it references; re-route this request to the otranspilerl worker's queue.
