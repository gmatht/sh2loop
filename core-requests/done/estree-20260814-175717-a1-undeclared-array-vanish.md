# estree: A1 undeclared arrays — writes vanish (lift needs the `arr=()` declaration)

## NEED
The A1 array lift only routes runtime writes/reads through the shared
array store when the array was DECLARED (`arr=()`). A bash script that
uses `arr[$i]=v` WITHOUT the `arr=()` initializer (auto-vivification,
legal in bash) emits `sh2.setVar("arr[$i]", v)` to the flat var store and
the values are never readable. Real bash (and the debashcl path) accept
the implicit declaration.

## WHY
`examples/textures/texture-crack.sh` filled `cr[$pi2]=0` etc. without any
`cr=()` — valid bash, and the old engine handled it — but on the A1 path
the writes vanished (reads returned empty), so the RGBA crack overlay was
garbage and its failed upload left the uCrack sampler unit bound to NULL,
which fails every block draw (INVALID_OPERATION → black blocks). The
game-side fix declares `cr=(); cg=(); cb=(); ca=();` explicitly.

## MINIMAL-CORE-CHANGE
In the A1 frontend (otranspilerl/src/lib.rs): when an array write/read
references an identifier with NO declaration, treat it as an implicit
empty-array declaration (the way plain bash does) and run the SAME lift
path as a declared array — instead of falling through to the flat
var-store write.

## FAILING-CASE
```
$ cat > /tmp/arr2.sh <<'EOF'
SIZE=4
pi2=0
while [ "$pi2" -lt $((SIZE * SIZE)) ]; do
  cr[$pi2]=$((pi2 * 10))     # no cr=() anywhere
  pi2=$((pi2 + 1))
done
echo "cr[3]=${cr[3]}"
EOF
$ node -e "… bashToJS('/tmp/arr2.sh') …"   # A1 path
# runtime: cr[3]=   (empty — the write went to a flat var "cr[$pi2]")
# expected: cr[3]=30
```

## OUTCOME: rejected: target is `otranspilerl/src/lib.rs` — otranspilerl is a SEPARATE repo (owns its own git + its own core-request mediation workflow) whose A1 frontend/typing/emitter is the estree(A1) worker's domain, NOT the shared core (src/shir.rs, src/estree.rs, src/parser/, shir_json*, harness/*). No shared-core change can fix the A1 BigInt/await/inline/array-lift bugs it references; re-route this request to the otranspilerl worker's queue.
