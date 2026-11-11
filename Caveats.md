# Caveats — Known Limitations

These are shell constructs that the translator cannot handle correctly,
along with the reason and any workaround.

## `declare -p` — Variable Metadata Output

`declare -p varname` prints a variable's type, name, and value in
bash-specific format (e.g. `declare -A info=([key]="value" ...)`).
No Perl equivalent exists. Tests that used `declare -p` have been
rewritten to use sorted key=value output instead.

**Affected tests:** 064_22, 064_hard_to_generate (fixed)

## Feature-Gated Zsh Syntax

Some `.sh`/`.zsh` files in the test corpus contain Zsh-specific syntax
protected by feature gates (e.g. `case "$_KUBE_PS1_SHELL" in "zsh") …`).
The translator parses both branches even though bash would never execute
the Zsh path at runtime.  If the Zsh branch contains constructs that
sh2perl cannot translate (e.g. `setopt`, `autoload`, `zmodload`), the
file as a whole will fail generation even though it would work correctly
when sourced under bash.

**Mitigation:** Files with unguarded Zsh syntax should be moved to
`sh.disabled/`.  Files with properly feature-gated Zsh syntax are
acceptable but may produce false-positive failures during generation.


`eval "$name() { $body }"` where `$name` and `$body` are runtime
variables cannot be translated because the function name and body
are unknown at compile time. The translator falls back to
`system('bash', '-c', "eval ...")`, but the function definition
is lost when the subprocess exits.

**Affected tests:** 063_15 (removed)

## Hash Iteration Order

Perl's `values %hash` returns values in randomized order (security
feature since Perl 5.18), while bash preserves insertion order for
associative arrays. Tests that depend on iteration order have been
fixed by sorting output.

**Affected tests:** 064_07 (fixed)

## Process Substitution `<(...)` in Backticks

Process substitution inside backtick command substitution
(e.g. `` `comm -23 <(sort a) <(sort b)` ``) is only partially
supported. The translator may fall back to `system('bash', '-c', ...)`
for complex cases.

**Affected tests:** 064_09 (still failing)

## `trap` — Signal Handlers

Bash's `trap` builtin has no direct Perl equivalent. The translator
emits a comment `# Builtin command 'trap' not implemented` instead.

**Affected tests:** 064_23 (still failing)

---

## Gate status 2026-10-25 — still-red tests, with causes

Recorded while landing the `const-str-cmp-fold` transform and the
whole-array-slice render fold. As of this date: `./fail` 563/563 green,
`harness/fail-rs` 563/563 green. The items below are everything still
red; each entry states why it is not caused by the new transforms.

### `fail-estree` — `parameter-expansion-nested.sh` (562/563)

**Cause:** the estree worker's in-flight routing of nested parameter
defaults — at runtime the *nested* `${MOUNTPOINT:-${NAME}}` reads
`sh2.vars.NAME` from the program variable map (env-blind), while
top-level reads go through the env-backed `_g()` helper, so an
environment-provided `NAME` is invisible to the nested read and the
expansion comes out empty. stdout mismatch.

**Not transform-related:** the example's source is a single
`echo "${MOUNTPOINT:-${NAME}}"` — no comparisons exist; the IR carries
zero foldable nodes (Eq/Ne/Not/globMatch all 0), so `const-str-cmp-fold`
is provably inert there. The defect lives in worker single-owner core
files (`shir.rs` / shIR nodes) under active edit at the time — out of
scope under the one-way ownership rule. `fail-estree` has no allowlist
by design (PLAN §2 guardrail: a failing test is a bug, never blessed
away), so it stays red until the estree worker's own loop lands the fix.

### `fail-coreutils` — 4 standing parser-gap reds

The 4 reds are the documented parser/ESTree gaps (source not inlined,
`${var:=…}` lowering to `sh2.unsupported`, …), each with repro and
current verdict in `tests/coreutils/README.md`. 4 red == standing
baseline; the count drops only when the corresponding parser fix lands.

### `py-rust-gate` — 98/103: 3 standing FAIL + 2 known-gap

- `t102_dual_guard.py`, `t103_pep695.py` — in the gate's `KNOWNGAP`
  list (the Rust renderer cannot execute them yet). Known gaps, never
  blessed wrong answers; the list is printed so it cannot grow silently.
- `t82_popen_pipe.py` — the rendered program exits 0 with **empty
  stdout**: the Popen→Pipeline spawn chain drops its output. The
  source (6 lines) contains no comparisons or slices.
- `t104_float32.py` — runs but prints 5 blank lines instead of the
  float values (float-value prints render empty; the source header
  itself documents the frontend word-position gap for float literals).
- `t87_bignum.py` — compiles and links (the `num_bigint` rlib resolves)
  but BigInt arithmetic beyond 64 bits prints wrong values (`x+1` →
  `1`, `x*3` → `0`): the bigint render path. A 2026-10-02 triage
  dismissed an earlier t87 FAIL as a stale harness verdict row, but
  today's gate links correctly and still mismatches — it is real.

**Not transform-related (all three):** the complete sources (36 lines
total) contain no `==`/`!=`, no `if`/`while`, no list slices and no `@`,
so neither `const-str-cmp-fold` nor the array-slice render fold can
reach any node they lower to — and the rendered Rust is
**byte-identical between the normal pipeline and `--raw`** (all
transforms off). The failures are in the frontend/spawn/float/bigint
render paths, in core files under active worker churn this session.
