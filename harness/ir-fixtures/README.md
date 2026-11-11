# IR fixtures — the shapes the shell corpus cannot reach

`fail-rs` renders all 563 shell examples and compares behaviour, so it can only
test IR shapes that some shell program produces. Measured 2026-11-11: the corpus
renders **zero** `num_bigint` — bash wraps past i64, so shell-derived IR never
carries a huge value. Two whole-program BigInt over-approximations lived in the
renderer untested for exactly that reason (PLAN v154).

These fixtures are A1 JSON (`--shir`) and are rendered by
`python3 harness/ir-surface.py --fixtures`, which compiles each backend's
output (bare `rustc`, `cc -fsyntax-only`, `py_compile`, `node --check`).

| fixture | source program | what it pins |
| --- | --- | --- |
| `bigint-arith.shir` | `n=$((2**64+1)); echo $((n*2))` | a huge value through a variable stays exact; its arithmetic folds at render time, so it compiles with bare `rustc` (no crate) |
| `positional-bigint.shir` | `f() { echo $(($1+1)); }; f $((2**64))` | **positional** taint: the huge argument marks `$1` only, and the callee's arithmetic on `$1` is the case that actually emits `num_bigint` |

Measured, not assumed: `--target rs bigint-arith.shir` contains no
`num_bigint`, while `positional-bigint.shir` does. The latter therefore needs
the emitted Cargo project, so the runner reports it as `dep` and skips the
bare-`rustc` arm; the other three backends compile it directly. That skip is a
property of a single-file program with no manifest, not a gap in the fixture.

Adding a fixture: write the shell source, run
`otranspilerl-cli --shir <source> > harness/ir-fixtures/<name>.shir`, add a row
above, and run `--fixtures`. To make the corpus's own coverage a checked
invariant, run `python3 harness/ir-surface.py --update` when a new IR type or
op is deliberately reached for the first time; the default mode fails if one
disappears.
