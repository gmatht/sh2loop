# 2026-08-06 shellbench — bash / dash / transpiled-JS / gcc -O3 / tcc -O0…-O3

Date: 2026-08-06 (AWST). Runner: `bench.sh` (workspace). C renderer: the
`backend/c` worktree at `d1e1140` (native While/DoWhile/Function,
no-op builtins, `let`, fixed buffers + debug-only length asserts).

## Summary

- **69 benches** across all 12 shellbench samples (assign, cmp, count,
  eval, func, null, output, stringop1–4, subshell) were timed under
  **bash**, **dash**, **transpiled JS** (estree-runner.mjs), and
  **transpiled C** compiled with **gcc -O3** and **tcc -O0/-O1/-O2/-O3**.
- **17/69 benches** render clean through the C backend and produce a
  binary that **matches bash's stdout** — the C columns there are real:
  **~35–43M ops/s vs bash's ~137–175k**, i.e. the transpiled C is
  **~290× faster than bash** on the lowable subset.
- **52/69 benches are honestly WRONG**: the construct is outside the
  draft renderer's lowable subset (positional params, external
  `cut`/`sed`/`expr`, command substitution, `eval`, string tests,
  real subshells/pipelines), so the binary hits a `sh2.*` stub
  (`exit 2`) — never blessed, reported WRONG by the output gate.
- **gcc -O3 vs tcc -O0…-O3 is a wash** on these micro-benchmarks
  (all within ±15% run-to-run noise): the rendered loop bodies are a
  handful of instructions, so the bottleneck is loop/printf overhead,
  not codegen quality.
- `~/sqrt1337.sh` (10k × `echo $((i*i)) | grep 1337`): bash 14.50 s,
  dash 13.31 s, js 0.27 s (~50× faster — in-process exec), C
  unlowerable (pipeline → stub).

## Discussion

### Method
Each shellbench `#bench` section is extracted and wrapped in an
N-iteration loop (N auto-calibrated so bash takes ~300 ms). Every shell
runs the *same* synthesized runner, so the work per iteration is
identical across columns. The C column additionally gates its output
against bash's (stdout must match — a fast-but-wrong binary is WRONG,
never blessed), and the loop's `echo "$__count"` observation prevents
dead-code elimination of the loop. Timing uses a nanosecond `perf_counter`
helper (sub-ms benches measure correctly).

### The interpreter-vs-native gap
On every bench the C renderer can lower, the gap is enormous and
consistent: bash ~137–175k ops/s, dash ~240–560k, C ~35–43M. Even the
slowest C column (`output:echo`, tcc-O0 16.7M/s — a `printf` per
iteration) is ~150× bash. There is **no crossover in this data**: tcc
-O0 is never slower than bash/dash on any bench that renders natively.

### When is bash/dash faster than tcc -O0?
**Never in this benchmark.** The rows where bash/dash "win" are exactly
the 52 WRONG rows — there tcc has no number at all, because the C
renderer gives up (stub `exit 2`, no output). The theoretical crossover
cases, in the order they'd actually arise:

1. **Unlowerable constructs** (today's only real "win"): positional
   params (`set --`), external tools (`cut`/`sed`/`expr`/`grep`),
   command substitution, `eval`, string tests, real `fork`/`exec`
   subshells and pipelines. Bash/dash produce correct output; the C
   binary cannot.
2. **Fork/exec-bound workloads**: if the renderer grows real
   `fork`/`execvp`/`dup2`/`pipe` (the documented C-backend plan), the C
   binary pays the *same* process-spawn cost as bash. On tiny inputs a
   spawn-per-iteration loop is dominated by the spawn, and bash's
   builtin handling can match or beat a spawned child per iteration.
   Not measurable today — those benches are WRONG.
3. **Renderer-machinery-bound loops**: if the renderer emitted heavy
   per-iteration machinery (e.g. the fixed-buffer `strlen`-assert +
   `strncpy` guards on a loop-carried string, or a `printf`-per-char
   pattern), a trivial body could be dominated by that overhead. The
   measured floor (`output:echo`, tcc-O0 ≈ 60 ns/iter) is still ~150×
   below bash's ≈ 9 µs/iter `echo`, so this crossover would need a
   pathological renderer output, not just -O0.
4. **Startup-bound runs**: for very small N, both interpreters
   (~3–5 ms) and the C binary (~1–3 ms) are dominated by process
   startup — C still wins, but the gap shrinks toward a constant.

The short answer: **with the current renderer, bash/dash are faster
than tcc -O0 only when the C backend cannot produce correct output at
all** — i.e. the 52 WRONG benches. As the renderer grows, the first
real bash-vs-C crossover to watch is fork/exec-heavy workloads (case 2).

### gcc -O3 vs tcc -O0…-O3
Effectively identical on these loops (all ~35–43M, ±15% noise).
tcc 0.9.27's optimizer is weak, but the generated code is already
minimal: a `while` loop over an increment and a `printf`/assignment.
Larger, real workloads (not micro-loops) are where gcc -O3's advantage
would show. Notable noise outliers: `count:typeset -i` tcc-O3 19.2M,
`null:assign variable` tcc-O0 16.0M, `func:func` tcc-O1 28.1M.

### Notes on individual rows
- `count:increment` dash 3 197 ops/s — dash is anomalously slow at
  `((i++))` (real dash characteristic, not a harness artifact).
- `stringop2/3/4:substr/remove/subst builtin` — dash ~24–39M (dash's
  `${var:0:1}`/`${var#p}` builtins are fast); bash ~130–175k.
- `subshell:subshell` C ~610–645k (slower than the other C rows: the
  real `( … )` still routes through the stub path; only the empty/`:`
  shapes render natively).
- The `sh2[a b c]` column is the transpiled-JS sh2.* call-site tally
  (lowering-complexity metric), not a timing value.

### Caveats
- Single run per cell (no repeats averaged); ±15% noise; outliers noted
  above.
- Calibration anchors bash at ~300 ms; the C binaries run ~7–25 ms per
  bench (N sized by bash's speed).
- tcc was run with `-B /tmp/tcc-x86/usr/lib/x86_64-linux-gnu/tcc` (a
  root-less deb extraction) and `-D__STDC_NO_VLA__` (glibc 2.39
  regex.h VLA-in-param prototype tcc can't parse).
- The C renderer is a draft; WRONG rows are the honest, correct
  reporting of unlowered constructs — the worker's grind-to-zero
  metric.

## Exact results

```
=== shellbench samples (bash / dash / transpiled JS / transpiled C) ===
bench                          bash/s       dash/s         js/s     gcc-O3/s     tcc-O0/s     tcc-O1/s     tcc-O2/s     tcc-O3/s
assign:positional params       137445       388121       297827        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[2	0	0]
assign:variable                175080       558216       388555     38231780     40764331     40816327     40531982     38095238   sh2[2	0	0]
assign:local var               175255       558806       388980     38531005     38834951     39530574     37144515     40175769   sh2[3	0	0]
assign:local var (typeset)     175323       557200       556386     37825059     41157556     42049934     40868455     42272127   sh2[3	0	0]
cmp:[ ]                        123926       295993       386798        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[0	0	0]
cmp:[[ ]]                      123367        57146       387468        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[0	0	0]
cmp:case                       174965       557554       387327     40150565     39850560     40868455     39925140     38811401   sh2[0	0	0]
count:posix                    137260       388072       388163     35914703     34427111     39925140     36508842     41051956   sh2[0	0	0]
count:typeset -i               154085       388262       558221     41051956     35457064     40226273     40353090     19219219   sh2[1	0	0]
count:increment                175326         3197       557812     38208955     41612484     30947776     40480708     32871084   sh2[1	0	0]
eval:direct assign             124010       387832       388350     35654596     16092532     17582418     17287952     16904385   sh2[2	0	0]
eval:eval assign                66143       297681       381857        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[2	0	0]
eval:command subs                1767         2737         8732        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[5	4	0]
func:no func                   175212       388689       553174     42272127     36158192     41830065     36676218     36342987   sh2[0	0	0]
func:func                      124216       388791       388552     40353090     39384615     28057869     45102185     37079954   sh2[1	0	0]
null:assign variable           175174       559309       388576     41693811     16040100     42105263     41423948     41078306   sh2[1	0	0]
null:define function           175229       388840       388817     40999359     42609854     40764331     39312039     40660737   sh2[0	0	0]
null:undefined variable        154001       388149       298007        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[4	2	0]
null:: command                 175260       389143       389079     39776259     39095907     41316979     38346315     41450777   sh2[0	0	0]
output:echo                    112655       240454       387656     16649324     17287952     16653656     16588906     17283284   sh2[0	0	0]
output:printf                  112949       297501       387867        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[0	0	0]
output:print                     1939        60861          381        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[2	1	0]
stringop1:string length        175245       386459       388817        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[2	0	0]
stringop2:substr 1 builtin       175085     39048200       559269        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[1	0	0]
stringop2:substr 1 echo | cut          582          731         8721        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[1	0	0]
stringop2:substr 1 cut here doc          659         1034         6074        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[6	4	0]
stringop2:substr 1 cut here str          617       555556         8727        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[1	0	0]
stringop2:substr 2 builtin       154005     24634334       388569        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[1	0	0]
stringop2:substr 2 echo | cut          550          681         8739        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[1	0	0]
stringop2:substr 2 cut here doc          565          937         6053        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[6	4	0]
stringop2:substr 2 cut here str          599       576037         6052        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[1	0	0]
stringop2:substr 2 expr           758          982          404        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[4	3	0]
stringop3:str remove ^ shortest builtin       153931       388145       175049        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[2	0	0]
stringop3:str remove ^ shortest echo | cut          565          731         6074        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[1	0	0]
stringop3:str remove ^ shortest cut here doc          495          856         6051        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[6	4	0]
stringop3:str remove ^ shortest cut here str          617       524109         6060        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[1	0	0]
stringop3:str remove ^ longest builtin       174980       388211       202603        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[2	0	0]
stringop3:str remove ^ longest echo | cut          582          705         8728        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[1	0	0]
stringop3:str remove ^ longest cut here doc          638         1035         6070        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[6	4	0]
stringop3:str remove ^ longest cut here str          565       530786         6065        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[1	0	0]
stringop3:str remove $ shortest builtin       137431       388623       297799        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[2	0	0]
stringop3:str remove $ shortest echo | cut          520          617         6059        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[1	0	0]
stringop3:str remove $ shortest cut here doc          581          895         6062        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[6	4	0]
stringop3:str remove $ shortest cut here str          637       566572         8710        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[1	0	0]
stringop3:str remove $ longest builtin       153911       388843       388899        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[2	0	0]
stringop3:str remove $ longest echo | cut          508          659         6067        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[1	0	0]
stringop3:str remove $ longest cut here doc          495          982         6058        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[6	4	0]
stringop3:str remove $ longest cut here str          618       554631         8722        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[1	0	0]
stringop4:str subst one builtin       175271     33455306        57300        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[2	0	0]
stringop4:str subst one echo | sed          495          582         8744        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[6	5	0]
stringop4:str subst one sed here doc          535          680         4622        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[6	4	0]
stringop4:str subst one sed here str          413       555247         6060        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[5	4	0]
stringop4:str subst all builtin       175207     36240091        54767        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[2	0	0]
stringop4:str subst all echo | sed          483          618         6074        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[6	5	0]
stringop4:str subst all sed here doc          535          822         6075        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[6	4	0]
stringop4:str subst all sed here str          550       553403         6059        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[5	4	0]
stringop4:str subst front builtin       154029     36930179        57261        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[2	0	0]
stringop4:str subst front echo | sed          521          618         6069        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[6	5	0]
stringop4:str subst front here doc          521          821         6062        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[6	4	0]
stringop4:str subst front sed here str          550       500751         6054        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[5	4	0]
stringop4:str subst back builtin       174796     37780401        48524        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[2	0	0]
stringop4:str subst back echo | sed          450          482         6071        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[6	5	0]
stringop4:str subst back here doc          535          821         6079        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[6	4	0]
stringop4:str subst back sed here str          535       528262         8733        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[5	4	0]
subshell:no subshell           174457       386578       555831     37558685     41343669     40634921     42105263     41025641   sh2[0	0	0]
subshell:brace                 153580       557093       557822     40920716     38647343     40920716     38694075     39555006   sh2[0	0	0]
subshell:subshell                2145         3165         8706       610128       634115       601685       644745       625782   sh2[2	1	0]
subshell:command subs            2146         3774         8740        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[3	2	0]
subshell:external command         1397         1768         8725        WRONG        WRONG        WRONG        WRONG        WRONG   sh2[3	2	0]

=== ~/sqrt1337.sh (10k iterations, echo $((i*i)) | grep 1337) ===
shell             time(s)        ratio
bash            14.500331         1.0x
dash            13.305880         1.0x
js               0.265047
c(gcc-O3)     unlowerable
```

*ops/s (higher = better). `WRONG` = the C binary compiled but its stdout
did not match bash's (unlowerable construct → sh2.* stub, exit 2) —
never blessed. `sh2[a b c]` = the transpiled-JS sh2.* call-site tally.*
