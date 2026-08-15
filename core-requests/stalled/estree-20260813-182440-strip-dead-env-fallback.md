# estree: strip the dead `?? (sh2.env.x ?? "")` fallback tail on store reads

## NEED

The ESTree emitter should emit **`sh2.vars.x` alone** for store reads
instead of `sh2.vars.x ?? (sh2.env.x ?? "")` — the nullish tail is dead
code (465 sites in the mimecroft build): the runtime's `sh2.vars`
Proxy already resolves the shell env fallback and returns `""` for a
missing name (never nullish), so the `??` never fires.

## WHY

Every store read pays a property access (`sh2.env.x`), a nullish check
(`??`), and a second `?? ""` for the empty-string case — 469
`sh2.vars.` + 465 `sh2.env.` reads in the build, hit thousands of
times per frame in the render loops. Verified against the runtime
(sh2runtime.js, the `vars` Proxy): `sh2.vars.unset` → `""`,
`sh2.vars.USER` (env var) → `"root"`, `sh2.vars.x` (set) → `"5"` —
the proxy get is exactly
`vars.has(k) ? vars.get(k) : (env[k] ?? "")`, never `undefined`/`null`.
The generated tail is dead by construction.

## MINIMAL-CORE-CHANGE

In the store-read emission (`store_var_read`, shir.rs ~27483 and the
native-store fold estree.rs ~3094): emit the bare `sh2.vars.<name>`
call; delete the `?? (sh2.env.<name> ?? "")` binary/nullish tail. (The
runtime comment at sh2runtime.js:1092 already documents that the env
fallback is handled proxy-side and the generated fallback is dead —
this request removes the dead code the emitter still emits.) The
`process.env` variant (some paths emit `?? (process.env.x ?? "")`) has
the same deadness when `process` is in scope; the proxy handles it.

## FAILING-CASE

    x=5
    echo "$x"

currently emits `process.stdout.write(String(`x=${sh2.vars.x ??
(sh2.env.x ?? "")}`)…)` — two property reads + a nullish chain for one
variable. With the strip: `String(\`x=${sh2.vars.x}\`)` — identical
output for set, unset, env-backed, and boxed values (all never
nullish). Corpus gate: `./fail-estree` at the trusted baseline — a
pure dead-code removal; the risk is a read where the runtime's proxy
is NOT in scope (a scope where `sh2.vars` is undefined would change
from "" to a TypeError — the emitter only emits this for store reads,
which always have the runtime, so the gate judges).
