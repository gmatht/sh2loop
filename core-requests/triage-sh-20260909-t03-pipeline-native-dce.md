# triage: shir-pipeline-native × dead-store-elim drops a live store (`sh t03`)

Date: 2026-09-09. From: frontend-js-gate `sh` FAIL on t03_pipeline.sh
(HELLO WORLD → HELLO␣). Bisected during estree status-record lowering work;
 NOT caused by it (all four shir.rs rendering hunks in flight are provably
dead for this IR: no `/`/`%`-with-Cast, no bigint-homed vars, no arrays,
and the read folds to `""` before getVar rendering).

## NEED
`name="world"` must survive to the pipeline read (native `HELLO WORLD`).

## FAILING-CASE
`frontends/posix-sh-go/testdata/t03_pipeline.sh`, first pipeline:
`name="world"` + `echo "hello $name" | tr a-z A-Z`.

## EVIDENCE

- Default flags: `let count = "", files = "";` (assign GONE) +
  `` `hello ${""}` `` (read folded to empty). Deterministic, all -O levels.
- `SH2_TRANSFORMS=none-such`: correct (`name = \`world\``, `` ${name} ``).
- Each transform alone: correct. Failing pair (only pair found):
  `SH2_TRANSFORMS=shir-pipeline-native,dead-store-elim`.

## MECHANISM HYPOTHESIS (for the pass owners, not verified)

`shir-pipeline-native` rewrites the echo stage so the `$name` read leaves
the store channel (bare native `` ${name} `` read in its output), while
`dead-store-elim`'s use-scan still counts only store-channel reads
(getVar): it concludes `name` is unread, deletes the assign, and the
never-written fold blanks the leftover read to `""`. I.e. the DCE's read
model is stale w.r.t. what pipeline-native emits. The two passes are each
correct alone; the composition is not.

## REPRO

```
CLI=otranspilerl/target/debug/otranspilerl-cli
SH2_TRANSFORMS=shir-pipeline-native,dead-store-elim \
  $CLI frontends/posix-sh-go/testdata/t03_pipeline.sh -O3 --target js \
  | head -2    # want: name = `world`; got: assign missing, ${""}
```

## SCOPE NOTE

This blocks the `sh` frontend-js-gate (86/88, single FAIL). It is unrelated
to the t89 bigint work, the list-append crash fix, the `--library` flag,
and the `|| store_only_var` revert (all provably dead for this input —
see above). Please keep it green independently; do not bless the DIFF.

## Sibling (zsh t73, same signature, different mechanism)

`frontends/zsh-sh-go/testdata/t73_zsh_arith_cond.zsh` (`x=5` +
`if (( x > 3 ))`): the assign vanishes and the read folds to `Number("")`
the same way — BUT it persists with `SH2_TRANSFORMS=none-such` (so it is
NOT the pipeline-native×DCE pair) while `--target sh` keeps `x=5` (so it
is estree-side: pre-analysis strip/fold or the never-written analysis
itself, whose walker plainly marks Assign targets — mechanism unproven).
Same ask: own it independently; the rendering hunks above are provably
dead for its IR (no div/mod-with-Cast, no arrays, no homed vars).
