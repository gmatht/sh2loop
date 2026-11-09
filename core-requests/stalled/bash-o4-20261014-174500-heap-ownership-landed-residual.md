# bash-o4: heap-string ownership fix landed; residual ~30-60 KB/s growth in MIMEcroft_fb

Filed by the `bash-o4` (fb0-raster branch) worker. This supersedes
`bash-o4-20261014-123500-array-reassign-leak.md` (that file is gone from
`core-requests/`, but the leak it described is FIXED — see below).

## LANDED (sh2perl `a5b871f93`, `src/c_backend.rs`)

Ownership was only honoured for file-scope reassignments and a few custom
store sites; every other string store overwrote the pointer and leaked the
old value. Six emission sites fixed (copy-first, then `free(old)` — the RHS
may alias the slot; decls are `char* v = NULL` so the first free is a no-op):

| site | shape before |
|---|---|
| `_sh_arr_set` | `a[i] = strdup(v);` (no free) |
| `_sh_grow_str` | realloc'd slots uninitialized → the new free-on-store would hit garbage; grown region now zeroed |
| `emit_vec_index_write` (string branch) | `id[k] = strdup(v);` |
| `_sh_assoc_set` (replace arm) | `v[i] = strdup(val);` |
| main assign path, non-top-level branch | `name = strdup(rhs);` — function-scope scalars (the rasterizer's per-pixel row copies) |
| nested-fn-scope `declare x=...` | `name = strdup(v);` |

Reproducer (12 lines, element stores) and the function-scope variant both
went from GB/s growth to flat:

```
element-store reproducer: 25 GB after 60 s   -> 2.4 MB flat
fn-scope growing string:  1.35 GB after 100 s -> 2.2 MB flat
MIMEcroft_fb menu loop:   ~26 GB + D-state wedge @ 10 min -> 26 MB @ 5 min
game heap row-string copies: 28,741 live -> 251 (240 are the live rows)
```

Semantics byte-identical vs bash on the array corpus (`_sh_arr_set` with a
slot-aliasing RHS, sparse vec holes, assoc overwrites); `c_backend` unit
failure set unchanged (143 pass / 10 pre-existing); `bash-o4` tests all green.

## RESIDUAL (unresolved — needs someone with better tooling than this box)

MIMEcroft_fb still grows ~30-60 KB/s in the menu loop after all six fixes
(26.5 MB @ 5 min → 33.3 MB @ 9 min → 80 MB @ 26 min in the same binary).
Not the original class — the row-string census is clean.

Evidence gathered (all reproducible):

- The heap accumulates ~1,600 **live** 41 KB blocks whose first bytes are
  `rbp_chunk=<41 KB of hex>\0` (glibc `setenv`'s exact `name=value`
  allocation shape). A chunk-walk of a gdb heap dump shows them fully live
  by `PREV_INUSE` and by their first 16 bytes holding TEXT (not arena fd/bk
  pointers, which rules out unsorted-bin residents).
- The environ table holds exactly ONE `rbp_chunk` at any time (checked
  live: `getenv("rbp_chunk")` returns a single 41 KB value), so these are
  orphans, not environ entries.
- `setenv` is NOT the leaker: 3 M replaces with constant and varying 41 KB
  values, with and without fork+system between calls — all flat ~2 MB.
- The `rbp_chunk` variable itself IS handled: the current render emits the
  temp-swap for it (`{ char *_old = rbp_chunk; ...; free(_old); }`) and
  disassembly of the built binary confirms the free.
- An LD_PRELOAD shim that counts malloc/free and scans for outstanding
  blocks shows allocation balance (~200 k allocs/s ≈ frees/s) while RSS
  still grows — i.e. RSS growth without allocation imbalance, which is why
  the block census was needed to see it at all.
- ASan builds die silently right after `ready.` (just before frame 1), so
  LSan's report is unavailable here; the menu path's `&`-fork texture jobs
  are the likely reason sanitizer runs cannot complete.

Suspects worth the next look: (1) a `setenv`/environ-adjacent path in the
generated runtime that detaches an entry without freeing (nothing in the
emitter writes `__environ`/`unsetenv`/`clearenv`, so this would be
libc-interaction, not emitted code); (2) glibc arena interaction with the
16-step realloc growth of `rbp_chunk` (2.5 KB→41 KB per present) where each
present's sizes differ slightly, leaving non-reusable slop that my
live/free test cannot distinguish. A `valgrind --tool=massif` or a working
ASan/LSan run of the --demo path would settle it in minutes.

## OUTCOME: rejected: superseded — the residual does not reproduce on the current shared core; the binary it was measured on predates the export-table fix.

Evidence (2026-10-23):

- `bash-o4/target/mimecroft-fb-leaktest` (the artifact behind the report, mtime 2026-10-14 22:31) has `setenv@GLIBC` as its ONLY env symbol — no `putenv`, no `unsetenv`. The current emitter's export table (`_sh_export`, one parent-owned `name=value` block per name handed to the child via `putenv`) has been in `src/c_backend.rs` since that fix; the stale binary never contained it. That is exactly the "1600 live 41 KB blocks shaped `rbp_chunk=<hex>`" signature: pre-fix `setenv` re-exports of the 41 KB raster chunk.
- Rebuilt from the CURRENT core (`target/debug/bash-O4 --emit-c MIMEcroft_fb.sh` -> `cc -O2`): the emitted C does use `_sh_export` + `putenv`/`unsetenv`. Driven through the same settings-menu redraw (keys every second, texture jobs harvesting — `/tmp/rb-frame.hex` rewritten, 7 job harvests) RSS is FLAT: 9.7 MB from t=17 s through t=54 s, versus the stale binary's 5.8 MB -> 21.2 MB over the same 47 s (~200 KB/s).
- A ≥20 KB live-allocation tracker (LD_PRELOAD malloc/realloc/free interposer with per-call-site backtraces, dumped mid-run) reports ZERO live blocks at 12 s of menu redraws.
- The `setenv`/`unsetenv` alternation hypothesis (import_env's `setenv` racing the table's `unsetenv`) is refuted directly: 3000 iterations x 42 KB across `setenv`, `setenv+unsetenv`, `setenv+putenv` and `unsetenv+putenv` are all flat (+276 KB for 126 MB of potential leakage).

If it ever reappears, re-check in this order: (1) does the binary under test have `putenv`/`unsetenv` in `readelf --dyn-syms` (stale builds silently measured the old emitter), (2) the ≥20 KB live-block dump, (3) only then heap forensics.
