# `${!arr[*]}` loses its 1-char FACE in the shIR (keys always arrive as `@`)

Status: **open** — filed 2026-11-04 by the C backend. Backend-side
consequence is pinned as an xfail (`harness/ifs-probe.sh`
`56_xfail_keys_star_face`) and modelled in `c_join_ifs.rs` (e3).

## What happens

The values face preserves `[*]` vs `[@]`; the **keys** face does not.
Measured on the current core (`--target shir --raw`):

| source | shIR |
|---|---|
| `a=(x y); echo "${a[*]}"`    | `param("", "a[*]")` — the face rides in the NAME |
| `a=(x y); echo "${a[@]}"`    | `param("slice", "a", "@", "")` |
| `declare -A m=([b]=1); echo "${!m[*]}"` | `param("slice", "!m", "@", "")` |
| `declare -ia n; echo "${!n[*]}"`        | `param("slice", "!n", "@", "")` |

The two `!`-lines are byte-identical whatever the source face was, so
`[*]` is unrecoverable downstream.

## Why it matters (bash MEASURED)

`[*]` joins on IFS[0] and an empty IFS concatenates, while `[@]` is a
space:

```
declare -ia n; n[0]=7; n[2]=9; n[5]=4
IFS=:   ${!n[*]} -> 0:2:5     ${!n[@]} -> 0 2 5 (three words)
IFS=    ${!n[*]} -> 025
declare -A m=([b]=1 [a]=2); IFS=:
        ${!m[*]} -> b:a       (the assoc key list obeys IFS[0] too)
```

The C backend therefore renders the `[@]` space for both faces: with
`IFS=:` it prints `0 2` where bash prints `0:2`, and `b a` where bash
prints `b:a`.

## Minimal change

Carry the face the same way `param("slice", name, "@"|"*", …)` already
carries it for VALUES: emit `"*"` (and, for the assoc/whole shapes, the
name `!m[*]` or an explicit 4th face argument) when the source subscript
was `[*]`. libc-front ends and the transform set then need no change —
`StrStyle` and every `IrExpr` shape stay as they are.

## Acceptance test

```
core-request-check: IFS=:; declare -ia n; n[0]=7; n[2]=9
  expect shIR: param("slice", "!n", "*", ...)   (or name "!n[*]")
```

Backend-side, `harness/ifs-probe.sh` `56_xfail_keys_star_face` is the
end-to-end probe: it goes green (and stops being an xfail) the day the
face survives, because `array_keys_join` already takes the face as a
parameter and uses IFS[0] for `[*]`.

## Blast radius

Every backend that renders `${!arr[*]}` — the same one-line
face-selection each already has for the values face. No storage or
transform change. The assoc key list keeps its insertion order; only the
separator selection is at stake.
