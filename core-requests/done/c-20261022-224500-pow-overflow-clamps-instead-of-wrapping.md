# C backend: `_sh_pow` clamps overflow to 0 where bash wraps (and folds nothing)

Filed by: an ad-hoc investigation session, 2026-10-22. Not committed — see
Landing. Related: `C_UB_PROOF.md`, `verif/PLAN-P1.md` (the width/interval
proof obligations); this is a different layer (the `_sh_*` runtime helper
for `**`), which those documents explicitly put out of scope.

## Symptom (reproduced)

```sh
n=3
r=$((n * 1000 ** 7))
echo "$r"
```

| | value |
|---|---|
| bash 5.2 | `-6819284014656913408` (int64 wrap) |
| rendered C (gcc, `--target c`) | `0` |
| IR (both) | `Bin { *, Var(n), Bin { **, Num(1000), Num(7) } }` |

`k = 8, 9` behave the same way (`0` vs `6011292615620689920` /
`-2345952408623906816`). `k <= 6` agrees — the inputs that fit in `i64` are
correct, so this is specifically the overflow arm.

## Cause 1: the helper's stated semantics is inverted

`_sh_pow` (emitted by `c_backend.rs`, `need_pow`):

```c
static long long _sh_pow(long long b, long long e) {
  long long r = 1; if (e < 0) return 0;
  while (e--) {
    if (b != 0 && (r > (9223372036854775807LL / b) || r < (-9223372036854775807LL / b)))
      return 0; /* bash: overflow wraps to garbage — clamp to 0 */
    r *= b;
  }
```

The comment says bash "wraps to garbage" and then clamps anyway. Bash
*does* wrap (two's-complement, `i64`), deterministically:

```
$ bash -c 'echo $((3 * 1000 ** 7))'   ->  -6819284014656913408
$ bash -c 'echo $((3 * 1000 ** 8))'   ->   6011292615620689920
$ bash -c 'echo $((3 * 1000 ** 9))'   ->  -2345952408623906816
```

Clamping is not a conservative approximation here: it converts a wrong
*number* into a different wrong number, and — unlike an OOM or an
unsupported-stub path — it is silent. A `return 0` on overflow is exactly
the "a miscounted proof can only exit loudly" assumption this tree has
already found false for widths (`C_UB_PROOF.md` §1).

Two candidate fixes, in increasing fidelity:

* **wrap**: perform the multiply in `uint64_t` and cast back (`(long long)`
  of the unsigned product is implementation-defined-but-universal in
  practice; `memcpy` from the `uint64_t` avoids that for a strict reading).
  This matches bash exactly.
* **refuse**: return a sentinel the *renderer* turns into a stub/error
  rather than a plausible value. Consistent with `refuse > guess`, but it
  changes behaviour for programs that currently print `0`.

The wrap path is the faithful one and is what `--true64`'s BigInt mode
already promises at the JS end.

## Cause 2: a literal `**` should never reach the helper

The IR is `Bin { **, Num(1000), Num(7) }` at the point `transforms::apply`
and the C renderer see it. `optimize_stmts`' Pass 0.5 (`fold_stmt`,
`ir.rs:15118`) folds only `Call { arith, Str }` — a *string* arith form —
not `ArithAst` nodes, so a fully literal `**` survives to the renderer and
becomes `_sh_pow(1000,7)` plus a runtime overflow branch.

Folding `Bin { **, Num, Num }` (with the same wrapping semantics as
`_sh_pow`'s replacement) removes the helper call for every literal
exponent, which is the common shape in the corpus' arithmetic tests. It
also makes the k=7..9 cases agree with bash without touching the helper.

Note the ordering trap: `div-mod-pow2` documents that `optimize_stmts`
already folds literal arithmetic — true for the `arith("…")` spelling, NOT
for `ArithAst`. That asymmetry is worth stating in one place.

## What this is NOT

Not the `arith_op_wide` / T3 narrowing gap that `verif/PLAN-P1.md`
predicts. I tried to construct that: `n + 15**k` and `n * 1000**k` all got
widths tracking the true range (`uint32_t` through `15**8` = 2.5G,
`long long` at `15**9` = 38G), and no narrow declaration overflowed. The
plan's `uint8_t result = 15 + _sh_pow(5,2)` motivating example should be
re-derived against the current renderer before T3 is mechanised — I could
not reach it.

## Landing

`sh2perl/src/c_backend.rs` is being rewritten by the concurrent backend
workers (uncommitted edits present, tree not building), so this is filed
rather than patched. The fix is small and self-contained once that lane is
free: one helper body + (optionally) one fold arm in `fold_stmt`.

## OUTCOME: implemented

`_sh_pow` no longer clamps: it multiplies in `unsigned long long` (wrapping is
well defined there) and `memcpy`s the bits back into `long long`, so
`3 * 1000 ** 7` prints bash's `-6819284014656913408` instead of `0`; a negative
exponent still returns 0 (bash errors — unchanged, documented). Cause 2 is also
fixed: `optimize_stmts` folds a fully literal `Bin { **, Num, Num }` with the
same two's-complement wrapping (`pow_wrapping`, repeated squaring), so the
common literal shape never reaches the helper. Regression test
`c_backend::tests::pow_helper_wraps_instead_of_clamping` pins the emitted
helper (uint64 multiply + memcpy, no clamp); `ir::tests::
literal_pow_folds_with_bash_wrapping` pins the fold against bash's k=6/7 values.
Verified on the affected corpus: 562/562 estree + 562/562 perl, C renders of
the corpus cells still compile and match bash.
