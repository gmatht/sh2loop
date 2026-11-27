# uu-ffi: fork+exec vs in-process `uu_run`

Microbenchmark for the claim behind uu-ffi: replacing a `fork`+`execv` of a
coreutils utility with a call into `libcoreutils_ffi` removes the process, and
with it most of the per-invocation cost. Three arms, same argv, same sink:

| arm | how |
|---|---|
| `fork-gnu` | `fork` + `execv` the GNU binary (`gnuwc`, `gnusort`, `grep`) |
| `fork-uutils` | `fork` + `execv` the distro's uutils binary (multicall image) |
| `inproc` | `sh2_uu_run()` from `sh2perl/runtime/uu_run.c` + `libcoreutils_ffi.so` |

The other two conventions — captured `$(cmd)` and threaded dispatch — are
in `bench-concurrency.c` (below).

The command output goes to `/dev/null` in every arm: the fork child does
`dup2`, the in-process arm redirects its own fd 1 once, outside the timed
loop. This is the **direct** path — a captured substitution
(`_sh_uu_capture`) adds a pipe and a reader thread and is not timed here.

## Results

Medians of 15 trials (3 sessions × 5 trials), 2,000 invocations per trial,
input `input.txt` (200 lines / 2.2 KB), recorded in `results.csv`; load
average 4.7–14.0 on 16 threads, captured per measurement.

| per invocation | fork+exec, GNU | fork+exec, uutils | in-process |
|---|---:|---:|---:|
| `wc -l input.txt` | 1.21 ms | 3.11 ms | **26.5 µs** |
| `sort input.txt` | 1.26 ms | 5.97 ms | **310 µs** |
| `grep -c . input.txt` | 1.33 ms | — (no uutils binary) | **179 µs** |

Ratios come from the per-session medians, so they are ranges: `wc` 46–51×
against GNU and 103–122× against uutils; `sort` 4.2–5.0× and 15–24×; `grep`
7.9–8.7× (no uutils binary to compare against). Dividing the pooled medians
above does not reproduce them exactly, and the ranges are the safer number.

Per-trial spread over those 15 trials: fork/exec GNU 0.63–2.28 ms, fork/exec
uutils 1.68–7.80 ms, in-process 15–459 µs (depending on the utility).

**Read the ratios, not the absolute numbers.** Every absolute time moved by up
to ~2× between the three sessions (the machine carries other load), but the
ratios barely moved: `wc` 46–51× against GNU's binary, `sort` 4.2–5.0×, `grep`
7.9–8.7×; against the uutils binary, `wc` 103–122× and `sort` 15–24×. The
first, pre-repo session (load 6.5–13.5) measured 1.46/1.61/1.60 ms and
24/255/160 µs — the same shape at different values.

## Controls

- **`fork`+`exec` floor:** `/bin/true`, 2,000 invocations, 0.51–1.28 ms across
  the two recorded sessions (`exec-floor.txt`). That is a large part of the GNU
  column: the utilities' own work is the rest.
- **The uutils column is mostly startup:** the multicall binary is 11.8 MB
  with 116 hard links (one image under 116 names), against 60 KB for `gnuwc`
  and 105 KB for `gnusort`. `coreutils/wc --version` through
  `fork`+`exec` costs 1.9–5.3 ms, i.e. the whole `wc` fork-uutils number is
  reached before `wc` reads a file.
- **Same answers:** `--dump` captures each in-process arm's stdout, and
  `cmp` against `<gnu> -l input.txt`, `sort input.txt`, `grep -c . input.txt`
  is identical for all three (the `wc` filename in the output differs only if
  you pass a different input path).

## Caveats

- `grep` has no uutils binary on this install, so its fork arm is GNU grep
  3.12 and the in-process arm is uutils' grep: a cross-implementation
  comparison, which the project's parity gate is what licenses.
- Direct `sh2_uu_run` only; `_sh_uu_capture` (pipe + reader thread) is
  untimed, so these numbers do not cover `$(...)` substitutions.
- 2.2 KB input and one argv shape per utility. This measures invocation cost,
  not throughput, and says nothing about script-shaped workloads where the
  same utility is called once.
- A shared desktop under someone else's load average of 4.7–14.0; not a quiet
  benchmark host.

## Environment

2026-11-27. Intel i7-10875H (8 cores / 16 threads), Linux 7.0.0-44-generic,
gcc 15.2.0, Ubuntu 26.04 with uutils coreutils 0.10.0 installed as
`/usr/bin/{wc,sort,cat,…}` (GNU 9.7 alongside as `/usr/bin/gnu*`), GNU grep
3.12 at `/usr/bin/grep`. `libcoreutils_ffi.so` from `sh2perl/runtime/lib`
(`uucore 0.10.0`). This is the same CPU model as the `bash-o4/bench` table,
on a different install.

## The calling conventions (2026-11-27, same box, load1 0.5–1.8)

`bench.c` above times ONE invocation at a time. `bench-concurrency.c`
answers the two questions that leaves open — threaded dispatch, and the
capture path `$(cmd)` actually takes — plus one bug found while doing it.

### Capture (`sh2_uu_capture` vs `fork`+`exec`+read)

Median of 5 trials × 200 invocations, 2.2 KB input. `plain` is
`sh2_uu_run` with output discarded — the floor the capture plumbing
(pipe + per-call drain thread) is measured *from*.

| arm | `wc -l` | `sort` | `grep -c .` |
|---|---:|---:|---:|
| `fork-capture` (fork, execv, read the pipe) | 950 µs | 887 µs | 955 µs |
| `capture` (`sh2_uu_capture`) | 57 µs | 227 µs | 160 µs |
| `plain` (`sh2_uu_run`, no capture) | 22 µs | 192 µs | 118 µs |

Capture costs 35 µs over the plain arm for `wc` (the pipe+thread), 35 µs
for `sort`, 42 µs for `grep` — but still 8–17× under the fork arm. With a
3.9 MB capture (beyond the 64 KiB pipe buffer, 30 invocations): 3.09 ms
per call for the fork arm vs 0.40 ms for `sh2_uu_capture`, both returning
the same 3,900,000 bytes (the concurrent drain is what makes that
possible; the naive run-then-read deadlocks, UU-FFI.md §3).

### Threaded (plain-run, N worker threads, private fd-1 sink)

3 trials × 300 calls per worker; "us/call" is the slowest worker's own
loop divided by its calls (median over trials), "agg/s" is all workers'
calls over that same interval.

| util | 1 thread | 2 threads | 4 threads |
|---|---:|---:|---:|
| `wc -l` | 20.8 µs / 48 k/s | 22.3 µs / 90 k/s | 24.1 µs / **166 k/s** |
| `grep -c .` | 110 µs / 9.1 k/s | 119 µs / 17 k/s | 124 µs / **32 k/s** |
| `sort` | 184 µs / 5.4 k/s | 186 µs / 11 k/s | 262 µs / **15 k/s** |

Per-call cost barely moves (1.0–1.4×) while aggregate throughput scales
2.0×, 3.5×, 2.8× on 2–4 threads. **`sort` at 4 threads is the one to
read**: +42% per call — its per-call setup allocates, and 4 threads
contend for the same allocator; it still aggregates 2.8× at 2→4.

**This table is the plain-run convention (`uu_run`), not the capture
one.** `sh2_uu_capture` redirects fd 1 PROCESS-WIDE, so two threads
capturing at once would interleave each other's output: it has no
per-thread state to make concurrent. The harness therefore gives each
worker its own fd-1 scratch file and never restores it. (While building
this, the same process-wide-fd-1 property showed up in three ways, all
recorded in `bench-concurrency.c`'s comments: a worker that restored its
own `dup(1)` raced another worker's redirect; a flush with fd 1 still on
the terminal sent the harness's own CSV — and once an entire `sort` page
— to the terminal; and a `dup2` + stdio sequence produced a clock read
that was 6 ms stale. None of it is a uutils bug; all of it is what
"capture is a process-wide convention" means for a threaded caller.)
No transpiled construct reaches the threaded convention either: the C
backend emits no `pthread_create` for `cmd &`. If in-process concurrent
*plain* utilities are ever wanted, `uu_run` on a private fd 1 per thread
is exactly what this harness does; concurrent *capture* would need a
per-thread implementation — a design change, not a benchmark.

### A bug this harness found in the single-invocation one

`bench.c`'s in-process loop used `run_uu()`, which returns after the
**first** non-zero exit and reports the trial as failed. `grep` with a
non-matching pattern exits 1 legitimately (`grep -c foo file` → 0 matches
→ rc 1), so the arm would have measured one invocation and reported
`iters`. Fixed: the loop now calls `sh2_uu_run` per iteration and counts
non-zero exits (`nonzero` column) instead of abandoning the trial.

## Reproducing the convention tables

```sh
# build (same line as the single-invocation harness)
cc -O3 -o /tmp/bench-uu-conc benchmarks/uu-ffi/bench-concurrency.c \
   sh2perl/runtime/uu_run.c -I sh2perl/runtime -L sh2perl/runtime/lib \
   -lcoreutils_ffi -lpthread -Wl,-rpath,$PWD/sh2perl/runtime/lib -lm

/tmp/bench-uu-conc capture 5 200 benchmarks/uu-ffi/input.txt
/tmp/bench-uu-conc threads 3 300 4 benchmarks/uu-ffi/input.txt
/tmp/bench-uu-conc big     3  30 100000 /tmp/scratch.txt     # 3.9 MB capture
```

Raw trials for the tables above: `results-capture.csv`,
`results-threads.csv`, `results-big.csv`. The single-invocation matrix was
re-recorded on the same session (`results.csv`, 3 trials × 500; its
columns are those of the `bench.c` above, including `us_per_call` and
`nonzero`; the early recording was `wc` 17.8/858/1959 µs and `sort`
169/744/2685 µs against GNU fork/uutils fork, and `grep` 110 µs vs 847 µs).
The re-recording was taken ~40 min later at load ≈8.9 and moved the
*absolutes* by ~2.2× (GNU fork `wc` 858 → 1955 µs, in-process `wc`
17.8 → 37.8 µs); ratios against GNU became 17× (`wc`), 3.8× (`sort`), 7×
(`grep`) — the same band as the first session's 46–51× / 4.2–5.0× / 7.9–8.7×
on a quieter box. Load-bound absolutes, ratio-stable result.
End-to-end (the same convention through the *transpiler*) is
`benchmarks/uu-conventions/`.

## Running the single-invocation harness

```sh
# from the repo root
cc -O2 -o /tmp/bench-uu-ffi benchmarks/uu-ffi/bench.c sh2perl/runtime/uu_run.c \
   -I sh2perl/runtime -L sh2perl/runtime/lib -lcoreutils_ffi -lpthread \
   -Wl,-rpath,$PWD/sh2perl/runtime/lib -lm

/tmp/bench-uu-ffi 2000 10 benchmarks/uu-ffi/input.txt  # CSV matrix on stdout
/tmp/bench-uu-ffi --exec /bin/true 2000               # fork+exec floor
/tmp/bench-uu-ffi --dump wc benchmarks/uu-ffi/input.txt out.wc
/tmp/bench-uu-ffi --capture wc benchmarks/uu-ffi/input.txt
```

Binary paths default to the layout above and can be overridden with
`UUBENCH_UUTILS_WC`, `UUBENCH_UUTILS_SORT`, `UUBENCH_GNU_WC`,
`UUBENCH_GNU_SORT`, `UUBENCH_GNU_GREP`; an arm whose binary is absent is
skipped (as `grep`'s uutils arm is here).

Files: `bench.c` (single-invocation harness), `bench-concurrency.c`
(capture/threaded harness), `input.txt` (200-line corpus), `results.csv`
(every trial of the recorded run), `results-capture.csv`,
`results-threads.csv`, `results-big.csv`, `exec-floor.txt` (control),
`session.txt` (session timestamps and load averages).
