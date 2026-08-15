# estree: A1 int64 loop-var typing leaks BigInt into mixed arithmetic (browser TypeError)

## NEED
The A1 path types purely-local while-loop induction counters (e.g. `y=0;
while [ "$y" -lt "$SIZE" ]; do … y=$(( y + 1 )); done`) as int64 and emits
`let y = BigInt("0")` / `y = BigInt.asIntN(64, BigInt(y)) + BigInt("1")`.
Any later expression that mixes such a counter with a Number operand
(`dy=$(( y - C1Y ))` then `pr1=$(( dx * C1DX + dy * C1DY ))`) throws
`TypeError: Cannot mix BigInt and other types, use explicit conversions`
at runtime in the browser. The transpiled JS must keep every variable in
ONE numeric domain — plain Number unless the analysis PROVES an operand
can exceed 2^53.

## WHY
Every texture generator in sh2runtime (`examples/textures/texture-*.sh`,
run in the browser via the A1 path) crashed this way: the per-pixel
crack math `dx=$(( x - C1X )); dy=$(( y - C1Y )); pr1=$(( dx * C1DX + dy * C1DY ))`
threw, `load_tex` got no payload, no texture uploaded, and every block
drew black. The game (mimecroft.sh) dodges it only because its loop
counters flow through function calls — a function-body global reference
(`tex_loop_bridge() { y=$(( y + 0 )); x=$(( x + 0 )); }`, added game-side)
unifies the typing back to Number. That is a workaround; the core should
not int64-type a counter that is compared against a small bound.

## MINIMAL-CORE-CHANGE
In the A1 type inference (otranspilerl/src/lib.rs — the loop induction
variable typing): default loop counters to the plain int/Number domain
and only widen to int64 when a use provably needs it (e.g. an operand
that itself is already int64, or a constant product above 2^53). At
minimum, make the int64 lowering CONTEXT-CONSISTENT: when one operand of
an arithmetic node is int64, convert the OTHERS to int64 too (the
current output already does this for `dy = BigInt(y) - BigInt("7")` but
NOT for `dy * C1DY` where C1DY stays a Number).

## FAILING-CASE
```
$ cat > /tmp/loop.sh <<'EOF'
SIZE=32
y=0
while [ "$y" -lt "$SIZE" ]; do
  dy=$(( y - 7 ))
  pr1=$(( dy * 2 ))
  y=$(( y + 1 ))
done
echo "$pr1"
EOF
$ node -e "… bashToJS('/tmp/loop.sh') …"   # A1 path
# runtime: TypeError: Cannot mix BigInt and other types, use explicit conversions
# expected: prints a Number (no BigInt anywhere in the emitted JS)
```
