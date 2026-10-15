# Core bug: two assignment shapes are DROPPED from the IR (all backends)

**Reporter:** fish backend worker
**Severity:** silent wrong output (the assignment vanishes; no error)
**Affects:** EVERY backend — this is core IR emission, not a renderer.

Verified against the **c** backend for both cases below, so neither is a
blind/cherry-picked fish observation.

## Case 1 — backtick assignment to a bare `echo`, and to a single-quoted literal

```sh
# sh2perl/examples/zz_probe_edge.sh
c=`echo`
e=`echo 'single $notvar'`
```

`otranspilerl-cli --target shir examples/zz_probe_edge.sh` emits assignments for
`a`, `b`, `d`, `f`, `g` only — **`c` and `e` never appear**, so no renderer can
emit them. The c backend confirms: it emits `""` and `"single $notvar"` as
literals where the *values* belong, i.e. it never saw an assignment either.

bash prints `[]` for `c` and `[single $notvar]` for `e`; fish prints `[]` and
`[single ]`.

## Case 2 — the combined `IFS=<value> NAME=(…)` form loses the IFS assignment

```sh
# sh2perl/examples/064_07_complex_array_operations.sh
IFS=$'\n' sorted=($(sort <<<"${config[*]}"))
```

Minimal repro:

```sh
IFS=$'\n' x=($(echo a))
echo "[$x]"
```

```
otranspilerl-cli --target shir /tmp/ia.sh | jq '.stmts[0].body | length'
# 1     <- only the `x` assignment; the `IFS=$'\n'` prefix is gone
```

The c renderer emits no `IFS` handling for it either.

**Why it matters:** bash joins `${arr[*]}` with the FIRST CHARACTER of `IFS`.
With the assignment dropped, a file that sets `IFS=$'\n'` still joins on a
space, so `sort` receives ONE line instead of one per element — 064_07 prints
`admin localhost 8080` where bash prints `8080 admin localhost`.

## Why this is not a fish worktree matter

`src/parser/` and the `src/ir.rs` lowering are single-owner shared core
(AGENTS.md: "The core stays single-owner during the lowering phase"). Filed per
the README's "BUG in an existing shared analysis" row.
