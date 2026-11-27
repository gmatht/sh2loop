# uu-conventions — the uutils calling conventions, end to end

Each script here is fed through the *user-facing* pipeline, so the numbers
are for a transpiled program rather than for a runtime entry point alone:

```
script.sh --otranspilerl --target c--> prog.c --cc -O2--> prog
```

| script | convention exercised | uu entry point in the emitted C |
|---|---|---|
| `sort.sh` | plain run, no capture | `_sh_uu_run` |
| `wc.sh` | plain run, cheapest utility | `_sh_uu_run` |
| `sort-capture.sh` | captured substitution `v=$(sort -r F)` | `_sh_uu_capture` (pipe + per-call drain thread) |

`run.sh` builds both legs of each script, gates stdout against bash, and
times them (`results.csv`: `script,leg,N,sec,us_per_call,stdout_vs_bash`;
`sec` is the median of `RUNS` ns-timed runs — `/usr/bin/time %e` rounds to
10 ms and reported the single-digit-ms `wc` leg as either 0.01 s or 10 µs
per call depending on the run).
The `fork` leg is the same source rendered with `SH2_UU_FFI=0`, i.e. the
`bash -c` sites the in-process path replaces.

Both the renderer's absorb table and the runtime resolve a *static
command name* — neither consults PATH — so the scripts say `sort`/`wc`
and the GNU binaries are put on PATH under those names
(`run.sh` builds `/tmp/uupath` from `gnu*`). That keeps both legs on the
same implementation, so the table isolates the convention, not GNU vs
uutils (that comparison is `benchmarks/uu-ffi/bench.c`).

## What is NOT measured here, and why

- **threaded / concurrent** (`cmd &`, `xargs -P`, `wait`): the C backend
  emits **no** `pthread_create` for background jobs — a transpiled script
  never reaches that convention. And `sh2_uu_capture` is process-wide
  fd-1 redirection, so it is not thread-safe as written: the threaded
  numbers exist only at the runtime level
  (`benchmarks/uu-ffi/bench-concurrency.c threads`). Making them reach a
  transpiled program is a backend change, not a benchmark.
- **fork/exec as a *fallback shape*** (`SH2_UU_FFI=0`) is measured as the
  `fork` column here; the fork/exec *floor* (`/bin/true`) is in
  `benchmarks/uu-ffi/exec-floor.txt`.
- **multicall / busybox-style dispatch** is not a separate convention for a
  transpiled program: the runtime takes the utility from `argv[0]`'s
  basename, so `sort` and `/path/to/sort` render the same
  `_sh_uu_av = {"sort", …}` and call the same `uu_run`. The only place a
  multicall *binary* shows up is the fork arm's exec target
  (`/usr/lib/cargo/bin/coreutils/wc` in `benchmarks/uu-ffi/`).
