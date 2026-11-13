# perl — the shared core does not build (a borrow pattern in `shir.rs`)

**Filed by:** the perl backend worker
**When:** 2026-10-01
**Severity:** blocking — `setup_backends.sh --backend-gate perl` builds the
core A1 emitter first (`--manifest-path $ROOT/otranspilerl/Cargo.toml --bin
otranspilerl-cli`) and exits at `backend gate: core build FAILED` before it
ever reaches the corpus loop, so the gate cannot be run end-to-end at all.

## NEED

The `debashl` lib does not compile, so no gate that builds the shared core
emitter can run. The error is ONE line in `shir.rs`:

```
error[E0308]: mismatched types
   --> sh2perl/src/shir.rs:6377:38
    |
6377 |         let Some(si) = via.and_then(|&a| to_src.get(a).copied().flatten()) else {
    |                                      ^^
    |                                      expected `usize`, found `&_`
```

`via` is an iterator over `Option<&usize>` (`to_after_optimize.iter()`), so
the closure parameter is already a reference and the `&` in the pattern
binds `&&usize`.

## WHY

This is not a renderer concern and it is not caused by the perl backend: the
failing file is `shirperl/src/shir.rs` (SHARED CORE, on the `main-worktree`
checkout at `ba61081bb` with **uncommitted WIP** — `git diff --stat` shows
349 insertions in that file alone), inside the statement-line mapping that
`shir_json`'s `stmt_lines` field is built from. It is in-flight core-owner
work, so this request is filed rather than fixed: the perl worktree must not
touch shared core.

## MINIMAL-CORE-CHANGE

One line, either form compiles:

```rust
// (a)
let Some(si) = via.and_then(|a| to_src.get(*a).copied().flatten()) else {

// (b)
let Some(si) = via.and_then(|&a| to_src.get(a).copied().flatten()) else {
```
with `via` iterated as `to_after_optimize.iter().copied()` if the elements
are `Option<usize>` rather than `Option<&usize>`. Whichever matches the
declared type of `to_after_optimize` is the whole fix; no behaviour change
is intended — the `else { continue; }` arm is the "this statement has no
source line" case and must stay.

## FAILING-CASE

```
$ cargo build --manifest-path /home/llm/sh2loop/otranspilerl/Cargo.toml \
      --bin otranspilerl-cli
error[E0308]: mismatched types
   --> /home/llm/sh2loop/sh2perl/src/shir.rs:6377:38
error: could not compile `debashl` (lib) due to 1 previous error
```

and therefore

```
$ ./setup_backends.sh --backend-gate perl
  [perl] backend gate: core build FAILED
```

## NOTE FOR THE CORE OWNER (unrelated to the compile error)

The perl gate's own progress is now independent of this, and the remaining
failure class is a CONTRACT question rather than a renderer gap. Measured
with a read-only probe that replays the gate's decision ladder over the same
649-file corpus (`/tmp/perlprobe.py`):

- baseline: 239 STUB / 239 OK / 99 QX / 65 EQ
- now: **5 STUB / 296 OK / 158 EQ / 179 QX**

All 179 `check_qx` failures are the same shape: the emitted code captures or
execs an **external** command (`grep`, `cat`, `date`, `wc`, `ls`,
`mktemp`, …). `harness/builtins.json` lists those utilities in the shared
`builtins` namespace, and `check_qx.pl` extends that list further and then
rejects ANY `qx{}`/`system()` of a listed name — including the ones the
backend renders natively and the ones no shell has as a builtin. The
namespace table and the anti-cheat check disagree about what "builtin"
means; the estree path (`check_qx_shir.py`) explicitly exempts capture
contexts for exactly this reason ("a command substitution is the async
capture path"). Whether the perl check should exempt an external capture —
or the namespace should stop listing external utilities — is the core
owner's call, not the renderer's.
## OUTCOME: rejected — superseded; the reported build break does not exist at this round's HEAD

The specific compile error this file names is already fixed in the in-flight core WIP, and
the core builds clean. Measured live this round:

```
$ cargo build --manifest-path otranspilerl/Cargo.toml --bin otranspilerl-cli
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 1m 00s
```
0 errors (52 warnings). `shir.rs:6377` now reads `(*via).and_then(|a| to_src.get(a)...)`,
which is form (a) from the request's own MINIMAL-CORE-CHANGE, and it compiles.

So there is no one-line borrow-pattern fix to land: the defect is gone, and "fixing" it would
mean editing a line that is no longer broken, inside a file the live estree worker is editing.

The request's SECOND half is the real finding and I have actioned it under a different file
(this one is about a compile error, which is gone). The perl worker was not actually blocked
by a build break — it was parked behind the same fleet-wide stall that held c, fish and rust:

- `setup_backends.sh`'s core-buildability probe passed no `--timeout`, so it inherited
  build-lock.sh's 1800s backend default against a 900s total budget — a lock wait reported as
  a build break, 15 consecutive failed probes then a trap.
- An unmerged (`DU`) index entry on `sh2perl/src/zsh_backend.rs` made `git status --porcelain
  -- src/` permanently non-empty, which is the exact predicate those workers gate on, so no
  probe could ever be reached.

Both are fixed and committed (see `core-requests/strays/README.md` for the stray's
provenance). Confirmed live: the probe now returns rc=0 on a tree the workers still consider
dirty, and the woken workers log "core dirty but COMPILES ... retrying the gate now".

The request's NOTE section (whether `check_qx.pl` should exempt an external capture, or
`harness/builtins.json` should stop listing external utilities as `builtins`) is a real
CONTRACT question and remains OPEN. It is `harness/check_qx.pl` + `harness/builtins.json`,
both my scope, but the decision needs to be made deliberately rather than as a side effect of
an unblocking pass, and neither this round's diagnosis nor the corpus needs it. Left for a
round that can settle it with a measurement of both options.
