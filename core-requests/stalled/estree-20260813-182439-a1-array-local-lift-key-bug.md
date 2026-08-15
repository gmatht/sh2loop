# estree: CORRECTNESS — A1-path arrayIndex store-key also breaks FUNCTION-LOCAL lifted vars (extends …-a1-array-param-key-bug)

## NEED

Extend the arrayIndex store-key bug (request
`estree-20260813-182438-a1-array-param-key-bug.md`, params) to the
broader case: **any function-local variable the emitter lifts to a
native JS binding** (`let ma_i = "0"`) but references through the
**store-key form** in `sh2.arrayIndex("arr", "$ma_i")`. The store
lookup of a name that is a native binding (never `vars.set`) resolves
to `""` → index 0, so **every such array read returns element 0**.

## WHY

The game's `mime_at` (mime collision scan, called per block) compiles
on the A1 path to:

    function mime_at(ma_a, ma_b) {
      let ma_ex = "", ma_ez = "", ma_i = "0";      // ma_i LIFTED (native)
      …
      ma_ex = sh2.arrayIndex("mx", "$ma_i");       // STORE key — mx[0] ALWAYS
      ma_ez = sh2.arrayIndex("mz", "$ma_i");
      …
      ma_i = (Number(ma_i ?? (sh2.env.ma_i ?? "")) || 0) + 1;   // native update

`expandOperand("$ma_i")` → `getVar("ma_i")` → the store Map lacks
`ma_i` (the loop var is a native `let`) → `""` → `Number("")` = 0 →
`mx[0]` every iteration. Reproduced (array pre-seeded): mimes at
`(10,7) (20,8) (30,9)`, player at (20,8): `mf = 0` (expected 1 — only
mime 0 is ever tested; (10,7) "works" by luck). The TOP-LEVEL
equivalent (`i=0; … ${mx[$i]}`) emits the native key
(`sh2.arrayIndex("mx", i)`) and works — the inconsistency is
function-locals. The browser game is unaffected (`.sh` runs via the
debashcl path, which emits native keys), but the GUI / `otranspiler`
command (A1 path) mis-compile any script with a function-local
variable used as an array subscript.

## MINIMAL-CORE-CHANGE

In the A1 estree lowering's `arrayIndex` key emission (the
`Word::MapAccess` / baked-subscript path), a key that is a variable
reference must consult the **lift sets** (LIFTED_NUMERIC /
LIFTED_STRING — the same `is_lifted` check the top-level path uses):
lifted name → emit the **native binding** (`ma_i` or `` `${ma_i}` ``);
store-bound name → keep the store key. The top-level path already does
this; function-local lifted vars fall through to the store-key arm —
the fix is to make the function-local path use the same lift
consultation (the top-level fix in …-a1-array-param-key-bug covers
params; this covers every other lifted local).

## FAILING-CASE

    mx=(10 20 30)
    mz=(7 8 9)
    mime_count=3
    mime_at() {
      ma_i=0
      while [ "$ma_i" -lt "$mime_count" ]; do
        if [ "${mx[$ma_i]}" -eq 20 ]; then
          echo "found"
        fi
        ma_i=$((ma_i + 1))
      done
    }
    mime_at

Via `otranspilerl render(a1,"js")` this prints NOTHING (every read is
`mx[0]=10`); via the debashcl path it prints `found`. Both must print
`found`. Corpus gate: `./fail-estree` at the trusted baseline — the
same root cause as the param request; fixing the shared key-emission
path fixes both.
