# shared core: `src/` is left uncompiling between edits, so every backend cycle pays a full buildability probe

## NEED

`sh2perl/src/` is left in a **non-compiling** state between edits often enough
that the backend workers' buildability probe fails most of the time. Measured
over a 6h window of `loop-backend-zsh.log` (89 events, 352 min):

| event                                                            | count |
|------------------------------------------------------------------|-------|
| `core dirty and not yet building (probe failed)`                 | **62** |
| `core mid-edit (estree-worker WIP)`                              | 13    |
| `core dirty but COMPILES (buildable, WIP unverified)`            | **10** |

The probe is one full `cargo build` of `otranspilerl` per poll, so a cycle that
cannot start spends minutes confirming the core still compiles. The gate row
gaps (zsh mean 37m, fish 59m, rust 47m) are largely this wait, not gate work.

(The counts above are a live trailing-6h window and drift as the log grows —
54/13/10 when last sampled, 62/13/10 about 40 minutes earlier. The ratio is the
stable part: **failing polls outnumber succeeding ones roughly 5:1**, which is
the figure to watch after any fix. Recompute with a grep over the last few
thousand lines of any `loop-backend-<lang>.log`.)

Two occurrences of the same failure class were observed on 2026-10-03 alone,
each lasting long enough to stall every backend:

- 18:00 — `src/shir.rs:14650`, `for (_k, piece) in span.chars()`
  (`chars()` yields `char`, destructured as a tuple; E0308). Five backend
  workers each burned `CORE_DIRTY_WAIT_S=900` and then trapped; 3 of 5 were
  asleep on `core-requests/sleeping-*` at once, and the `c` worker had trapped
  58 times.
- 00:07 — `src/perl_generator_fixed.rs:307`, indexing a `u8` as
  `b[(j - 1) as usize]` where `b` was a scalar (E0608). Observed while the
  tree was being edited: the file's mtime advanced `00:07:04 -> 00:08:50`
  mid-build, and the tree went green ~4 minutes later once the edit settled.
  **This one has since been corrected in the working tree** (`b` is now
  `line.as_bytes()`, so `b[j - 1] == b'"'` is a correct `u8` compare) — it is
  cited as an *occurrence of the class*, not as an outstanding defect. There
  is nothing to fix at that line.

Both windows were caught only because a build was attempted by hand. Neither
appears in the core gate's own output, for the reason in WHY.

## WHY

The core gate does **not** see this, which is why it goes unnoticed. The gate
builds `sh2perl/backends/core` (a separate worktree — see `SUB=` in
`run_core_worker.sh`), while every backend worker probes the **shared
main checkout** (`setup_backends.sh:869`, `--manifest-path
"$ROOT/otranspilerl/Cargo.toml"`). So the gate can report GREEN while the tree
five workers depend on does not compile at all. There is no signal that
combines the two.

This is NOT a reason to weaken the probe. The probe is correct: gating against a
core that does not build produces a meaningless verdict. (An experiment to cache
the probe verdict for 5 minutes and skip the repeat builds was rejected on
exactly this reasoning.) The cost being asked about is the *frequency*, not the
check.

**Minimal ask: build-check before leaving an edit.** If each WIP commit or edit
session ends with the tree compiling, `src/` is buildable at the moment control
returns to the backend workers, and the probe succeeds on its first or second
poll instead of failing 62 times. A local `cargo build --lib` between edits is
cheap next to the fleet-wide stall it prevents: measured 13.8s warm on this
box (`cd sh2perl && cargo build --lib`), versus a backend cycle that loses
minutes to probe polls.

A second, smaller ask, if the first is not wanted: have the **core gate also
build the shared checkout** (or record its build state) so a red main checkout
is visible from the gate side. Today the two trees' health is reported
independently and neither implies the other.

## MINIMAL-CORE-CHANGE

None in lowering code. This is an edit-hygiene / observability request:

1. End each WIP session with `cargo build --lib` (or `cargo build -p debashl`)
   green before moving on. No new files, no interface change.
2. Optionally: surface the shared checkout's build state in the core gate
   report alongside the `backends/core` verdict, so "gate GREEN" cannot be read
   as "every backend can gate".

## FAILING-CASE

Not a corpus case — a process case. Reproduce by watching the two windows above:

```
$ cd /home/llm/sh2loop/sh2perl && cargo build --lib     # E0308 / E0608 mid-edit
$ stat -c '%y' src/perl_generator_fixed.rs             # advances while building
```

## VALIDATION

1. With the estree worker active, sample `loop-backend-<lang>.log` over 6h:
   `probe failed` should drop well below the current ~86% of polls. The change
   is measurable directly from the existing log lines — no new instrumentation.
2. `cargo build --lib` in `sh2perl/` must be green at the top of any
   core-worker iteration, not only inside `backends/core`.
3. No regression: the two core-request fixes above (`shir.rs` whole-identifier
   harvest, `perl_generator_fixed.rs` `b[...]` indexing) must both stay green —
   the second was itself an instance of this class, and landed as an uncommitted
   edit that the tree only regained at ~00:12.

## NOTE

The probe's per-poll cost is ~1 build, and a no-op build was measured at up to
5m24s wall-clock purely from build-lock queueing (6 concurrent `cargo`
processes, 3+ waiters) — so the tax is amplified by lock contention, not by
compilation. Worth knowing when weighing any fix: making the tree buildable
removes most polls, but each remaining poll is still queue-dominated.