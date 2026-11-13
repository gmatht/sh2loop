# bash-o4: array-element string reassignment leaks the old value (unbounded heap growth)

Filed by the `bash-o4` (fb0-raster branch) worker. The C-backend runtime
leaks on every `arr[$i]=<string>` reassignment: the old element value is
never freed. Any program that churns a string array — e.g. a 320×240
framebuffer held as 240 hex-row strings, rebuilt per frame — grows
~600 MB/s and wedges the box (26 GB anon RSS, process in D-state
`__mem_cgroup_handle_over_high`, the page-cache/writeback wedge from
AGENTS.md — except this time the RSS is 99.5% anonymous heap, not cache).

## Minimal reproducer (12 lines of bash, no game code)

```sh
ROWS=(x)
y=0
while [ "$y" -lt 240 ]; do
  ROWS[$y]=""
  y=$((y + 1))
done
BIG="abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz0123456789"
i=0
while [ "$i" -lt 500000 ]; do
  y=0
  while [ "$y" -lt 240 ]; do
    ROWS[$y]="${BIG}${BIG}${BIG}${BIG}${BIG}${BIG}${BIG}${BIG}${BIG}${BIG}"
    y=$((y + 1))
  done
  i=$((i + 1))
done
echo done
```

```
./target/debug/bash-O4 -o /tmp/leakprobe6 /tmp/leakprobe6.sh
/tmp/leakprobe6 &  # then sample /proc/$!/status
  t=10s VmRSS:   7844860 kB
  t=20s VmRSS:  13964652 kB
  t=30s VmRSS:  20164108 kB
  t=40s VmRSS:  25096724 kB   (~600 MB/s, linear)
  t=50s VmRSS:  25822004 kB   (plateau = the 24.7 GiB box budget, then D-state)
```

Each sweep writes 240 × ~1.3 KB = ~312 KB of live data; RSS grows
~6 GB per 10 s, i.e. **every reassignment leaks roughly the full old
value** (no reuse, no free — the heap smaps total equals the RSS).

## What does NOT leak (same binary, same shapes)

- scalar capture reassignment: `x=$(echo hi)` × 20000 — clean
- small-string element writes: `ROWS[1]="...36 chars..."` × 20000 — clean
  (but see note: 20k × 36 B = <1 MB total, below sampling resolution —
  this probe was insensitive, not exonerating)
- computed-index + substring builds: `ROWS[$y]="${S:0:10}${S:10:10}..."` ×
  30000 with short strings — clean (same sensitivity caveat)

The leak needs large-ish element values to observe; whether small values
leak too is unmeasured. No threshold was bisected.

## Impact on this backend

`MIMEcroft_fb.sh` holds the frame as `RFB_ROWS[240]` (~2.5 KB/row) and
`rb_putrun` reassigns rows per painted pixel — thousands of reassignments
per frame at 20 fps in the settings-menu preview loop. Measured on the
game binary: 4.7 GB RSS after ~60 s in the menu, 14.5 GB after ~2 min,
26 GB + D-state wedge after ~9 min (runaway killed by hand both times;
`free` recovered fully, so it is process heap, not a box leak).

## Suspected location (not diagnosed — core owns this)

The array-element store in the emitted C runtime (`_sh_arr_set` or its
inlined equivalent in `tmp_run/emit.c`-style output): the old `char *`
for the slot is overwritten without `free`. Scalar variable assignment
frees correctly (probe 1 is clean), so the array path likely misses the
`free(_old)` that the scalar path has. One-line class of fix, but
`src/` is single-owner during the lowering phase — filing, not touching.

## Precedent

`core-requests/c-20261002-011500-getcwd-and-print-chars-leaks.md.stall`
was the same shape (C-runtime leak, backend-filed). This one bites
harder: it wedges the whole box, not just the process.

## OUTCOME: rejected: superseded by the landed heap-ownership fix

Landed in `sh2perl` commit `a5b871f93` (`src/c_backend.rs`): the six string
store sites (`_sh_arr_set`, `_sh_grow_str` zeroing, `emit_vec_index_write`,
`_sh_assoc_set`, the function-scope scalar store, the nested-declare store)
now free the previous value copy-first. The superseding request
`bash-o4-20261014-174500-heap-ownership-landed-residual.md` records the
reproducers going from 25 GB / 1.35 GB of growth to 2.4 MB / 2.2 MB flat;
what remains there is a different, ~30-60 KB/s residual, not this class.
