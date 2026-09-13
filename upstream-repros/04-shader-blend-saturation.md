# 04 — a shader blend weight that saturates on the first unit of damage

**Class:** shared fixed-point shader maths. Status: **fixed in the app,
pattern recorded here** (the bug is in app-authored maths, but the
*detection* is reusable and the drift it exposes is an upstream hazard).

## Symptom

Damaged blocks in mimecroft rendered as near-black slabs instead of the
block's own colour crossed by dark cracks.

## Cause

The crack overlay is a texture of near-black (28,28,28) lines with alpha
255 on the lines and alpha 0 elsewhere. The fragment blended it with

```
mix = min(damage * cr_a, 127)          # authored in bash
g_mix = min(uDamage * int(_crack.a * 127.0), 127.0)   # the float rewrite
r = r - (r - cr_r) * mix / 128
```

With `cr_a = 255` on a crack line, `mix` hits the 127 cap on the FIRST
hit, so the crack texel takes 127/128 ≈ 99% of the pixel — a damaged
block is drawn as the crack colour, i.e. black. The weight must scale
with damage (`mix = damage * cr_a / 4` gives 24% / 50% / 99% at damage
1 / 2 / 4).

## The reusable hazard

The same maths exists in **two places**: the bash-authored fragment and
the float-native `OPT_MAIN` the GPU optimiser substitutes for it. Nothing
checked they agreed, so a change to one copy silently diverges from what
the GPU runs. The regression test therefore:

1. reads the crack texel from the *texture generator*
   (`texture-crack.sh` — `crack_set … 28 28 28 255`);
2. parses the weight out of **both** copies (`mix=$((damage * cr_a …))`
   in the game, `g_mix = min(…)` in `shglsl-opt.js`);
3. evaluates both on a damaged block and asserts
   - damage 1 keeps ≥ 50% of the base colour (not black),
   - the pixel darkens monotonically with damage,
   - the two copies produce the same value (≤ 3/255 drift).

Negative control: with the unscaled weight the test fails, so it cannot
silently go green again.

## Generalisation

For any shader maths that exists in two forms (authored + optimised),
assert *both* evaluate to the same observable output — not that both
contain the same text. A text check passes while the GPU runs the other
copy.
