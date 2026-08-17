# estree: lastExit-write liveness for [ ]-test conditions (drop the _g/lastExit dance)

## NEED

Extend the existing lastExit-write liveness analysis
(`compute_lastexit_deadness` / `mark_lastexit_dead`, shir.rs) to **test
conditions** so the ESTree renderer emits a plain boolean condition
instead of the `(sh2._g = …, sh2.lastExit = …, sh2._g)` sequence
whenever nothing reads `$?` before the next write.

## WHY

Every `[ ]` test in the emitted JS becomes

    if ((sh2._g = !Number.isNaN(Number(x ?? (sh2.vars.x ?? (sh2.env.x ?? "")))) && Number(...) === Number(AIR),
           sh2.lastExit = sh2._g ? 0 : 1, sh2._g)) { … }

— 816 `sh2._g` + 732 `sh2.lastExit` assignments in the mimecroft build,
every one of them hit in the hot render loops (the `[ "$gv" -eq "$AIR" ]`
per-block air test, the `[ "$rf_x" -lt "$MAP_W" ]` loop guards). The
game never reads `$?` after the vast majority of these tests. The
`lastexit_dead` machinery already exists for `(( ))`-statement
lowering (shir.rs:388: "the `(( ))` statement lowering drops the"
lastExit write when dead) but the `test`/`[ ]` lowering still emits the
full sequence unconditionally.

## MINIMAL-CORE-CHANGE

1. `compute_lastexit_deadness`: mark `test`-expression statements
   (`Call { func: "test" }`, the `[ ]` lowering) as lastExit-dead the
   same way the `(( ))` path does — the analysis already tracks which
   statements read `$?` before the next write.
2. estree.rs test emission: when the test's lastExit write is dead,
   emit `if (cond)` with the bare boolean (no `_g` temp, no
   `sh2.lastExit = …`); keep the sequence for live sites (`$?` still
   observable). The `_g`-sequence form only exists to record $? — a
   dead write is pure overhead.

## FAILING-CASE

    x=5
    if [ "$x" -eq 5 ]; then echo yes; fi
    echo done

currently emits the `(sh2._g = !Number.isNaN(Number(x)) && Number(x) ===
Number(5), sh2.lastExit = sh2._g ? 0 : 1, sh2._g)` condition — three
assignments + the Number dance per test. With the elision:
`if (Number(x) === 5) { … }` (the Number coercion itself is transform
1/6 territory; this request is only about the `_g`/`lastExit` bookkeeping
— the `$?` protocol must be byte-identical for the cases that DO read
it: `if cmd; then …; fi` chains, `cmd && …`, `$?` in `$(( ))`). Corpus
gate: `./fail-estree` at the trusted baseline.

## SUPERSEDED: compute_test_cond_deadness / TEST_COND_DEAD (the Plan 4 test-condition liveness)
## REASON: Both minimal-core-change points landed in the core: shir.rs compute_test_cond_deadness (line 941) is populated by compute_lastexit_deadness (1023) and consumed by every [ ]-condition emission — If (16698), While (17010), DoWhile (17243) — emitting the bare boolean condition (no _g/lastExit seq) when the status write is provably unread; live sites keep the byte-identical statused form.
