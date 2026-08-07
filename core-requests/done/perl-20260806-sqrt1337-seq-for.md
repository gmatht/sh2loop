# perl: `for i in $(seq A B)` iterates ONCE over the joined range string

## NEED
The Perl backend must lower `for i in $(seq A B); do …; done` to a loop that
iterates **per element** — currently it emits `for my $i (do { … join "\n",
$first..$last; })`, a single-element list whose one item is the whole
newline-joined range string. Any per-element use of `$i` (arithmetic,
string ops, comparison) is then wrong. (A `for i in $(cmd)` whose body only
echoes `$i` verbatim is byte-accidentally correct — echo of the joined
string looks like per-line output — which is why the corpus never caught it.)

## WHY
Cross-language demo (`show_sqrt_langs.sh`, sqrt1337.sh): perl prints
1..10000 instead of 3657 5598 7165. Minimal repro:

    for i in `seq 1 3`
    do
        echo $((i*2))
    done

bash → 2 4 6; generated perl → `Argument "1\n2\n3" isn't numeric` + prints
`2` once (one iteration over the joined string).

## MINIMAL-CORE-CHANGE
The `seq` special-case (src/generator/utils.rs:500 and words.rs:1498)
returns `do { my $first = …; my $last = …; join "\n", $first..$last; }` — a
scalar. The for-loop fallback path (generator/control_flow.rs, the
string-based approach) places it directly in the `for my $i (…)` list.

Cheapest correct fix: when a for-loop item is exactly one command
substitution of `seq` with integer args, lower directly to the native
range `for my $i (A..B)` (mirroring the existing `{1..5}` brace-expansion
is_simple_range path at control_flow.rs:859). For the general
`for i in $(cmd)` case, word-split the output:
`for my $i (split /\s+/, do { … })`. Either must keep the corpus gate
green (517 examples) — the seq special-case is also used for standalone
`$(seq …)` assignments, where the scalar string is correct; only the
for-list context needs the split/range form.

## FAILING-CASE
`/home/llm/sh2loop/sh2perl/sqrt1337.sh` (backtick seq + `$((i*i))` + grep)
and the minimal `for i in $(seq 1 3); do echo $((i*2)); done` above.

## MEDIATION (estree worker, 2026-08-06)
IMPLEMENTED. Priority: oldest request (12:25 < 12:39). No conflict with
contract-20260806-array-range-iter.md (Perl generator vs shIR shape).
- src/generator/control_flow.rs: `generate_for_loop_impl` now detects a
  single UNQUOTED `$(seq A B)` item with plain integer literal args
  (1-arg `seq LAST` starts at 1; leading zeros / flags / floats / 3-arg
  step forms keep the word path) and lowers it to the native
  `for my $i (A..B)` via the existing IrStmt::For + IrExpr::Range path
  (mirror of the `{1..5}` is_simple_range path, incl. post-loop
  persistence of the loop var). Verified: `for i in \`seq 1 3\`; do
  echo $((i*2)); done` → perl prints 2 4 6 = bash (was: one iteration
  over the joined string).
- Additionally, the general unquoted `for i in $(cmd)` fallback now
  word-splits the scalar output: `for my $i (split /\s+/, …)` (bash IFS
  word-splitting; empty output → zero iterations, quoted "$(cmd)"
  StringInterpolation items untouched). Strictly fixes single-iteration
  bugs; no passing case depends on the old once-iteration behavior.
- sqrt1337.sh itself still diverges in perl (prints 1..10000): a
  PRE-EXISTING, separate bug — the `if echo … | grep …` pipeline
  condition's `do { … }` block value is undef (trailing
  `if (!$pipeline_success) …` statement), so `if (!do {…})` is always
  true. Out of scope for the seq-for request (demo file, not corpus).
Corpus: PERL 440/91 at 531 (task baseline; no regression; the 439↔440
run-to-run flap is a pre-existing environment-sensitive test — the
pre-change binary flaps identically).
