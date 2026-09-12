# Why C is harder than JS (as a transpiler target)

Shell and JS are the same genus — dynamically typed, garbage-collected,
stringly, hoisted, `eval`-capable. Transpiling sh→JS is *translation*:
near-neighbor mappings. Transpiling sh→C is *compilation*: every dynamic
property must be proven, lowered, or rebuilt as runtime machinery. The
BASHC failure list (§BASHC_FIX.md) is the proof obligations not yet
discharged. Concretely:

1. **No runtime to lean on.** GC strings, growable arrays, assoc maps,
   closures, eval, exceptions, first-class functions — JS has them; C
   needs each rebuilt as `_sh_*` machinery plus a shadow discipline
   (ownership/frees, buffer sizing, OOM fail-stop). Most BASHC bugs are
   *runtime-model* bugs, a category that barely exists for JS.
2. **The type chasm.** Shell has one type (string); JS coerces well
   enough that most programs just work. C demands every value be
   declared up front — hence the whole proof program (width analysis,
   int-domains, exact capacities, profiling). Where proof fails, C
   needs a per-construct fallback; JS degrades gracefully by itself.
3. **Zero means success.** C/JS falsy-0 vs shell success-0. Every
   boolean context in C must cross this inversion by hand (`_sh_rc == 0`
   tests, `, 1` truthy tails, `value_discarded`); JS expressions don't
   double as the status channel, so the meanings never collide textually.
4. **Textual declaration order.** Shell/JS hoist; C requires
   declaration-before-use. The backend carries an ordering subsystem
   (decl hoisting, `main_private`, forward decls, helper staging), and
   "use before decl" is a bug class inconceivable in JS.
5. **Bug severity.** A JS lowering bug is a wrong value. A C lowering
   bug is a segfault, hang, or UB — hence sanitizer passes, capacity
   guards, gate timeouts. "Runs and prints" isn't evidence of soundness.
6. **The process model, by hand.** Pipelines/subshells/jobs/traps are
   `child_process` or closures in JS; fork/pipe/dup2/waitpid/SIGPIPE
   bookkeeping in C, where every mistake is a hang or lost signal.

The payoff (LISTS, DUAL_LOOPS, PROFILING docs): once discharged, the
proofs buy native speed in a tiny binary — something JS can't give.
JS is cheaper to reach; C is worth reaching.
