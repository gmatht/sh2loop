# INVESTIGATION: a natively-lifted variable used as an ARRAY INDEX

Status: **PARTLY FIXED.** The runtime/JS-side half is fixed in
sh2runtime's toolkit (`src/lower.js` `interpolateNativeIndexNames`) —
mimecroft's 3D mime cubes move again. The **A1 frontend half is still
OPEN**: reproducer `upstream-repros/01-lifted-var-in-array-index.sh`.

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

## Cause (A1 level — the remaining open half)

The A1 for reproducer 01 is:

```json
{"type":"Assign","targets":[{"var":"a"}],        "expr": Str "3"}
{"type":"Assign","targets":[{"var":"b"}],        "expr": Str "4"}
{"type":"Assign","targets":[{"var":"lookup[$cell]"}], "expr": Str "-1"}
```

`cell=$((b*16+a))` is **absent**: the indexed target was lowered to a raw
STRING `"lookup[$cell]"` (left for the runtime to expand), so the
frontend's own liveness pass cannot see that the statement uses `cell`
and drops it as dead code. At run time the store has no `cell`, `$cell`
expands to "", and the write lands on `lookup[]`.

Fix: carry the key as a real expression in the indexed target (so
liveness and the backends see the use), instead of embedding `$var` in
the target's rendered name.

## Cause (below the A1, for completeness)

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

## Follow-up: the same class hits FUNCTION PARAMS (mimecroft, 1 of 10)

`upstream-repros/05-param-only-use-in-index.sh` — a param whose only use is
inside the indexed target:

```bash
set_pos() { sp_i=$1; sp_x=$2; sp_z=$3
  tpx[$sp_i]=$sp_x
  tpz[$sp_i]=$sp_z
}
set_pos 1 10 20
set_pos 2 11 21
```

bash: `tpx[1]=10 tpz[1]=20` / `tpx[2]=11 tpz[2]=21`
transpiled: `tpx[1]= tpz[1]=` / `tpx[2]= tpz[2]=` / `all=11|21`

The emitted function is

```js
sh2.functions.set("set_pos", () => {
  sp_x = sh2.positional[1] ?? "";      // sp_i=$1 was DROPPED ...
  sp_z = sh2.positional[2] ?? "";      // ... so the args renumber
  sh2.setVar("tpx[$sp_i]", sp_x);      // sp_i is read from the store: empty
});
```

Two compounding frontend bugs, both from the same blind spot (a variable
read inside a *rendered index name* is not counted as a use):

1. the assignment feeding the index is dropped as dead code;
2. the remaining assignments keep their ORDER but not their ARG NUMBER,
   so every value shifts down one positional.

Impact in mimecroft: `set_treasure_pos` records only ONE artifact
(`tpx = ["8","0","0",…]`) even though all ten are placed on the map
(`count_map_treasures` sees 10), so nine artifacts can never be claimed
by walking into them — the live "touching them to claim only worked
once" report. The single-claim test could not see it; the loop over all
ten can (`__claim-all-test.mjs`).

Fix: index targets must carry the key as an EXPRESSION (or the use must
be recorded) so liveness keeps the assignment and the positional
numbering is preserved.
