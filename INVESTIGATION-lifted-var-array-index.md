# INVESTIGATION: a natively-lifted variable used as an ARRAY INDEX

Status: **OPEN** (found while building mimecroft; reproducer
`upstream-repros/01-lifted-var-in-array-index.sh`).

## Symptom

An indexed array write whose index is a variable **assigned from an
arithmetic expression** lands on the wrong key. The write disappears and
the matching read returns nothing. mimecroft's MIME entities moved in the
radar/HUD but their 3D cube stayed frozen at the original cell, because
`mime_lookup` (the 3D renderer's cell→mime map) was never re-keyed.

## Minimal reproducer

```bash
lookup=()
a=3
b=4
cell=$((b * 16 + a))
lookup[$cell]=-1
echo "direct: [${lookup[67]}]"
```

    real bash        direct: [-1]
    transpiled       direct: []

## Cause

`cell` is assigned from `$((…))`, so the emitter lifts it to a **native
JS `let`** and assigns it natively. The indexed write is emitted as

```js
sh2.setVar("lookup[$cell]", -1);
```

— a STRING whose `$cell` the **runtime** expands out of the sh2 store.
A natively-lifted variable has no store entry, so the expansion is empty
and the key becomes `"lookup[]"`.

The same shape appears with an arithmetic index in a function
(mimecroft `update_mimes`):

```js
sh2.setVar("mime_lookup[$um_ocell]", "-1");
sh2.setVar("mime_lookup[$um_ncell]", um_i);
```

Both writes land on `mime_lookup[]`.

## Why the two obvious fixes are wrong

* **Interpolating in a JS pass** (rewriting the string to `` `lookup[${cell}]` ``)
  is wrong for variables whose home IS the store: mimecroft's
  `map_set` does `mi=$1` (emitted as `sh2.vars.mi = …`), so `${mi}`
  reads a dead module placeholder and `map[$mi]` never gets written —
  `gen_maze` then spins forever in its unbounded placement loop.
* **Forcing such variables into the store** fights the lift analysis and
  costs the optimised hot paths the lifts exist for.

## Fix

In the emitter, when a name is lifted natively (declared as a module
`let` AND assigned natively), emit an **interpolated** name for indexed
writes/reads — `lookup[${cell}]` — and keep the `arr[$var]` string form
only for variables that genuinely live in the store. `liftLocalVars`
already does exactly this for the names *it* lifts; the gap is names the
**renderer** lifted itself (the arithmetic-assignment lift), which no
later pass knows about.

## Reproducer suite

    upstream-repros/01-lifted-var-in-array-index.sh   # OPEN  (this bug)
    upstream-repros/02-param-strip-live-value.sh      # fixed (guard)
    upstream-repros/03-single-quoted-payload.sh       # fixed (guard)

Each is bash-vs-transpiled stdout-compared by
`sh2runtime/run-upstream-repros.mjs`; the deploy gate
(`__upstream-guard-test.mjs`) pins the fixed ones and lists this one as
known-open so it cannot block unrelated deploys but also cannot be
forgotten.
