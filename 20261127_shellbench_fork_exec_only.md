=== shellbench samples (bash / dash / transpiled JS / transpiled C) ===
bench                          bash/s       dash/s         js/s     tcc-O2/s
assign:positional params       103525       388416       558167          ERR   sh2[1	0	0]
assign:variable                136985       241571       382197          ERR   sh2[1	0	0]
assign:local var               123515       385593       385907          ERR   sh2[1	0	0]
assign:local var (typeset)       103600       240032       384377          ERR   sh2[1	0	0]
cmp:[ ]                         83382       240442       557156          ERR   sh2[0	0	0]
cmp:[[ ]]                      124197        66008       556531          ERR   sh2[0	0	0]
cmp:case                       103345       237189       381302          ERR   sh2[0	0	0]
count:posix                     89117       287640       386003          ERR   sh2[0	0	0]
count:typeset -i                73387       238887       387938          ERR   sh2[1	0	0]
count:increment                 89151         1123       388065          ERR   sh2[1	0	0]
eval:direct assign              58019       231861        95960          ERR   sh2[1	0	0]
eval:eval assign                38514       136644        95177          ERR   sh2[2	0	0]
eval:command subs                 932         1615         6042          ERR   sh2[3	0	1]
func:no func                    95473       235244       384602          ERR   sh2[0	0	0]
func:func                       66016       238045       294348          ERR   sh2[1	0	0]
null:assign variable           112555       240187       387566          ERR   sh2[0	0	0]
null:define function           123371       296739       383760          ERR   sh2[0	0	0]
null:undefined variable         78050       239312       295605          ERR   sh2[2	1	0]
null:: command                 112308       240247       540262          ERR   sh2[0	0	0]
output:echo                     77260       241320       201253          ERR   sh2[0	0	0]
output:printf                   77532       197959       200295          ERR   sh2[0	0	0]
output:print                      778        30068          208          ERR   sh2[2	1	0]
stringop1:string length         88949       240411       295291          ERR   sh2[0	0	0]
stringop2:substr 1 builtin        89171     14575268       175053          ERR   sh2[0	0	0]
stringop2:substr 1 echo | cut          126          134         8638          ERR   sh2[1	0	0]
stringop2:substr 1 cut here doc          143          165         6011          ERR   sh2[2	0	0]
stringop2:substr 1 cut here str          127       255167         8701          ERR   sh2[1	0	0]
stringop2:substr 2 builtin        89199     29277219       239049          ERR   sh2[0	0	0]
stringop2:substr 2 echo | cut          109          128         6000          ERR   sh2[1	0	0]
stringop2:substr 2 cut here doc          118          156         4657          ERR   sh2[2	0	0]
stringop2:substr 2 cut here str          113       220022         6050          ERR   sh2[1	0	0]
stringop2:substr 2 expr           171          196          118          ERR   sh2[3	2	0]
stringop3:str remove ^ shortest builtin       113087       297448       380176          ERR   sh2[0	0	0]
stringop3:str remove ^ shortest echo | cut          162          168         8745          ERR   sh2[1	0	0]
stringop3:str remove ^ shortest cut here doc          191          242         5841          ERR   sh2[2	0	0]
stringop3:str remove ^ shortest cut here str          207       591716         6075          ERR   sh2[1	0	0]
stringop3:str remove ^ longest builtin        96147       202702       297910          ERR   sh2[0	0	0]
stringop3:str remove ^ longest echo | cut          120          174         8653          ERR   sh2[1	0	0]
stringop3:str remove ^ longest cut here doc          191          234         6063          ERR   sh2[2	0	0]
stringop3:str remove ^ longest cut here str          177       580720         8704          ERR   sh2[1	0	0]
stringop3:str remove $ shortest builtin       137528       201571       297156          ERR   sh2[0	0	0]
stringop3:str remove $ shortest echo | cut          157          193         8749          ERR   sh2[1	0	0]
stringop3:str remove $ shortest cut here doc          164          207         8747          ERR   sh2[2	0	0]
stringop3:str remove $ shortest cut here str          177       534474         6084          ERR   sh2[1	0	0]
stringop3:str remove $ longest builtin       112646       241229       383571          ERR   sh2[0	0	0]
stringop3:str remove $ longest echo | cut          141          147         5979          ERR   sh2[1	0	0]
stringop3:str remove $ longest cut here doc          155          204         4586          ERR   sh2[2	0	0]
stringop3:str remove $ longest cut here str          167       556483         8744          ERR   sh2[1	0	0]
stringop4:str subst one builtin       113204     37937167        42138          ERR   sh2[0	0	0]
stringop4:str subst one echo | sed          367          265         5919          ERR   sh2[3	0	1]
stringop4:str subst one sed here doc          244          341         3693          ERR   sh2[2	0	0]
stringop4:str subst one sed here str          295       355745         8745          ERR   sh2[2	0	0]
stringop4:str subst all builtin        95741     33578174        36112          ERR   sh2[0	0	0]
stringop4:str subst all echo | sed          361          320         8735          ERR   sh2[3	0	1]
stringop4:str subst all sed here doc          496          896         8761          ERR   sh2[2	0	0]
stringop4:str subst all sed here str          566       497018         8762          ERR   sh2[2	0	0]
stringop4:str subst front builtin       137675     39776259        54882          ERR   sh2[0	0	0]
stringop4:str subst front echo | sed          508          706         8760          ERR   sh2[3	0	1]
stringop4:str subst front here doc          535          706         8753          ERR   sh2[2	0	0]
stringop4:str subst front sed here str          550       614628         8765          ERR   sh2[2	0	0]
stringop4:str subst back builtin       154096     37602820        40849          ERR   sh2[0	0	0]
stringop4:str subst back echo | sed          472          638         8766          ERR   sh2[3	0	1]
stringop4:str subst back here doc          508          790         6048          ERR   sh2[2	0	0]
stringop4:str subst back sed here str          618       651042         8763          ERR   sh2[2	0	0]
subshell:no subshell           203162       560700       992848          ERR   sh2[0	0	0]
subshell:brace                 175513       389954       997677          ERR   sh2[0	0	0]
subshell:subshell                3177         4663         8743          ERR   sh2[0	0	0]
subshell:command subs            2743         4669        15631          ERR   sh2[0	0	0]
subshell:external command         1397         2152        15619          ERR   sh2[2	1	0]

=== sqrt1337.sh (10k iterations, echo $((i*i)) | grep 1337) ===
shell             time(s)        ratio
bash            14.242106         1.0x
dash            12.237763         1.0x
js               0.064137
c(tcc-O2)      render-err

---

## 2026-11-27 C-column re-capture (the four samples whose benches compile)

`./bench.sh`, `CAL_MS=80`, `CC_LEVELS='gcc -O2'`, load ≈5–8. The table above
is the bash/dash/js columns (complete, 69 benches); the C column there is
`ERR` because at capture time `run_c` did not link `-lgmp` (every bench that
constant-folds emits `mpz_*`). After that fix:

```
bench                          bash/s       dash/s         js/s     gcc-O2/s
null:assign variable            96837       131415        94611      4685212   sh2[0	0	0]
null:define function            96590       245053        95790      8452192   sh2[0	0	0]
null:undefined variable         96566       139093        74448          ERR   sh2[2	1	0]
null:: command                139620       139771       139186      9461857   sh2[0	0	0]
assign:positional params        61942       241706        24019          ERR   sh2[1	0	0]
assign:variable                 96470       243780       139526      9137636   sh2[1	0	0]
assign:local var                60002       246990        97074      4199475   sh2[1	0	0]
assign:local var (typeset)      74377       139262        97120      9362200   sh2[1	0	0]
count:posix                     59506       137550        95923      8303062   sh2[0	0	0]
count:typeset -i                61625       119962        24274      2196595   sh2[1	0	0]
count:increment                137830         2866       139725      8421053   sh2[1	0	0]
func:no func                    74484       139511       139654      6843456   sh2[0	0	0]
func:func                       34816       123537        24244      2001001   sh2[1	0	0]

=== sqrt1337.sh (10k iterations, echo $((i*i)) | grep 1337) ===
shell             time(s)        ratio
bash            17.556490         1.0x
dash            10.591180         1.0x
js               0.063938
c(gcc-O2)        0.007557
```

Transpiled C is 2.0–9.5 M ops/s against bash's 35–140 k (15–200×), and
`sqrt1337` is 7.6 ms against bash's 17.6 s. The three `ERR`s are C-backend
gaps, not harness failures: `assign:positional params` and `string length`
(`/tmp/shellbench/sample/stringop1.sh`) do not compile — the latter renders
`var = _s1`, a `char*` stored into a `long long` — and
`null:undefined variable` is a `set -u` shape.

