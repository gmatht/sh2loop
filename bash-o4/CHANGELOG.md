# `-O4` driver changelog

Covers the whole `-O4` driver family — `bash-O4` and `python-O4` are two front
ends over one pipeline (`ShIR` → C via tcc, or → PTX via the CUDA candidacy),
sharing one flag surface (`bash-o4/src/flags.rs`) and one dispatch vehicle
(`bash_o4::cu_run`).

## Unreleased — void calling-convention lift: bare calls become plain C calls (C backend)

The step the entry below named as designed-next: every bare
shell-function call — `try_draw` ×768/frame, plus `rb_cube`/
`draw_rect`/`draw_char`/`get_cell`/… — used to build an argv array,
swap `_sh_argv`/`_sh_argc` around the call and restore them, with
bounds-checked `_sh_argv[k]` reads in the callee. `scan_void_lifts`
(`sh2perl/src/c_backend.rs`, the dual of `scan_fn_lifts`) makes those
plain C calls:

- **eligible** when the fn's only uses are bare statements (its
  observable channels are `_sh_rc` + globals), its body reads only
  `$1..$9` (no `$@`/`$*`/`$#`/`$0`, no `shift`/`set --`), it has no
  nested defs of unknown shape, and it does not call itself. `return N`
  and stdout writers are allowed — nothing captures a bare call, so
  body stdout *is* process stdout either way. Arity 0 lifts too (a
  zero-arg bare call paid the argv swap as well).
- **signature**: `static void f(char *_pN)`, or `long long _pN` when
  `analyze_native_num_fns` proves the params integral and every call
  site passes a small non-bigint arg (phase 2 — that analysis now
  counts void-lifted fns alongside value-lifted ones).
- **`LiftScan::child` veto (correctness)**: a positional read inside a
  capture/pipeline/Arrow body refuses the lift, because the renderer
  hoists those bodies into `_cap_N`/`_sh_site_N` builders that have no
  `_pN` in scope. Measured both ways it fails: `v=$(echo "$1")` →
  ‘_p1’ undeclared (this is `examples/087_function_cmd_sub.sh`, which
  regressed to a gate skip until the veto landed), and the silent kind
  — `v=$(echo "$v-$1")` compiled and dropped the value, and
  `echo $(($1+1)) | tr` compiled and printed 1 where bash prints 6. The
  same veto closes the identical hole in the pre-existing *value* lift
  (a `$(…)`-captured fn with a positional body read failed to compile
  on HEAD too).

Measured on `MIMEcroft_fb.sh` (`--emit-c`, same-tree A/B — both
binaries built from one checkout, only `src/c_backend.rs` stashed):

| metric | HEAD | void-lift |
|---|---|---|
| argv swap/restore sites | 645 | 20 |
| C bytes · lines | 1,423,253 · 32,159 | 1,211,983 · 27,861 |
| lifted `static void f(char *)` defs | 14 | 124 |
| `atoll(` · `_sh_xstrdup(` sites | 430 · 1135 | 430 · 1135 |

Correctness: frame-1 PPM **byte-identical** (same-tree pair); `--demo`
rc=0 on both. Full C corpus gate **497/10/53 for BOTH builds with an
identical failure set** (all 10 pre-existing — param-heavy/stringy
corners); `c_backend` unit tests **157/10** (143/10 on HEAD + 14 new
void-lift tests), failure set byte-identical to HEAD; `bash-o4` suite
green (131).

Timing, stated honestly: 4 paired `--demo` runs give scene render
**71.0 vs 68.3 ms/frame** (ranges 68–78 vs 64–73, box load 4 → 10 over
the sweep) — directionally positive but inside box noise, and consistent
with the transport never being the frame cost: the argv swap costs
sub-1% of a 70 ms frame even at 768 calls. The wall-clock levers are
the rasterizer and the remaining per-cell `atoll`s/`strdup`s (both
untouched here — the last two columns above), not call plumbing; what
this change buys is a **14.8% smaller render** and call sites the
optimiser can actually see through.

## Unreleased — redirect-text marking + coinductive copy-cycle reads (C backend)

Two follow-ups to the Class-F homes (`sh2perl@d510030f2`,
`src/c_backend.rs` +106/−2; mirror in `bash-o4/src/int_cycles.rs`):

- Redirect targets are genuine text observations. The uses walk
  ignored them (`Redirect { inner, .. }`), so a path var only ever
  written by `> $p` could home `Int` — `p="007"` vs `p=7` are
  different files. New `mark_redirect_text`: scalar reads mark
  `str_use`, element reads mark whole-array `str_read`; even
  `getVar` marks here (transparent in value position, text through
  a redirect). `rbd_p` is `char*` again.
- `assigns_numeric` reads copy cycles coinductively (revisit
  assumes int, was refuse). Sound via the existing three gates:
  the `str_use` seed exclusion, the removal-only fixpoint, and
  demote re-validation. `proven_nonneg`/`bound_of` stay
  conservative (a wrong bound is a miscompile, a missed seed is
  just slower).

Measured on `MIMEcroft_fb.sh` (`--emit-c` counts, HEAD vs patched):

| scope | `atoll` | `_sh_xstrdup` |
|---|---|---|
| whole render | 449 → 430 | 1316 → 1135 |

~30 more vars home `long long` (`um_*` mime-update nest, `mx`/`mz`,
`rmx`/`rmz`, `RBTEX_OFF`, `dm_*`/`ka_*`/`mb_*`/`ru_*` radar caches).
Same-condition `--demo`: render **72 vs 70–76 ms/frame** — inside
box noise (load ~11, demo frame counts differ run to run), i.e. no
measurable render change; the win is static (−14% `xstrdup`). The
render bottleneck is the scene phase's 768 `try_draw` argv-swaps +
remaining per-cell `atoll`s — void-lifting `try_draw`/`rb_cube` is
the designed next step, not yet implemented.

Correctness: frame-1 PPM 4-way byte-identical (two archived + two
fresh builds); the older archived `base-frame.ppm` differs but is
stale (predates the change under different inputs/code) — the
HEAD-vs-patched C diff is free-ordering noise only, so no codegen
behavior changed. `--demo` clean (rc=0) on both builds. Full C corpus gate
**499/8/53 with a failure set byte-identical to unmodified HEAD**
(all 8 pre-existing — param-heavy/stringy corners); `bash-o4`
suite green (115); `c_backend` unit tests 143/10, identical set to
HEAD.

## Unreleased — Class-F int arrays: positionals + full-cover homes (C backend)

`MIMEcroft_fb.sh`'s per-frame cost was dominated by string round-trips
on the game-board arrays: every cell read did `_sh_arr_get` + `strdup`
+ `atoll`, because `map`/`bhp`/`mime_lookup`/`mtype` stayed `char*`.
Two conservative refusals in `int_element_verdict`
(`sh2perl/src/c_backend.rs`) blocked them, and both are unnecessary
for full-cover fixed arrays:

- Positional-sourced stores (`set_cell`'s `v=$4` → `map[$idx]=$v`)
  failed the int-writes fixpoint (`assigns.get("4")` is `None`).
  `getVar`/`Var` of a positional (all digits, except `$0`) is now
  int-valued: one `atoll` at the copy observes exactly what every
  per-use `atoll` observes, and seeds still require int-use-only
  while demote re-validates.
- Dynamic keys needed a `[ $k -lt N ]` guard + proven-nonneg proof.
  Dropped for arrays with a full literal cover (Class F): no holes
  can form, fixed-array stores render the exact `_sh_arr_set` guard
  in both representations (negative stores nothing, past-cap exits
  127), and reads render the len guard per context (`""` vs `0`).
  The old guard calls stay behind `SH2_DEBUG_INT_ELEM=6` logging.

The worktree mirror (`bash-o4/src/int_cycles.rs`) accepts the same
two shapes so its scalar/array fixpoint proposes through them
(demote re-validates as before). Ablation: with the backend fix,
`SH2_NO_INT_CYCLES=1` and `SH2_NO_INT_ELEM=1` change nothing — the
`int_arrays_for_c` path (which calls `int_element_verdict` directly,
past the wrapper's kill-switch) carries the win alone.

Measured on `MIMEcroft_fb.sh` (`-O4 --emit-c` counts):

| scope | `atoll` | `_sh_xstrdup` |
|---|---|---|
| whole render | 1285 → 589 | 3332 → 1326 |

`map`/`bhp`/`mime_lookup`/`mtype` now emit `static long long …[1024]`;
`gv`/`td_mi` read as direct guarded loads (`gv == AIR`, no `atoll`).
Same-condition `--demo`: render **83 → 61 ms/frame** (1.36×), avg
108 → 88 ms/frame. Frame-1 PPM byte-identical across runs.

Verified: full C corpus gate **642/3/7 byte-identical vs baseline**
(the 3 fails — 2 `cc`, 1 `stub` — fail identically on unmodified
HEAD); `bash-o4` suite green (131); `c_backend` unit tests 143/10,
identical set to HEAD (pre-existing failures).

## Unreleased — int-cycles: scalar copy-cycle Int seeding (O3/O4)

Worktree-local ShIR→ShIR pass (`bash-o4/src/int_cycles.rs`, wired into
`render_c_with` beside the loop-opt hoist): pushes `Int` verdicts for the
greatest fixpoint of scalars whose every assign is int-valued under
transparent-copy semantics — `Arith`/`Int`, canonical-numeric text (no
leading zeros, `i64`-parseable), `Var`/`getVar` of a member, and
`arrayIndex`/`min`/`max`/`sum` over literally-dense int-domain arrays
(literal cover + guarded cursor stores + int-valued RHS, joint scalar/array
fixpoint mirroring the backend's intwrites rules). Closes the gap the
shared backend deliberately leaves: mixed-form assigns (an `arrayIndex`
read here, a plain `v=$w` copy there) are pushed by neither of its two
seeders, so the whole per-pixel nest (`rbt_x2` → `rbt_t` swap hub →
bounds/shade/bridge) cascaded back to `char*`.

Only proposes — `demote_stringy_ints` re-validates every verdict at C
ingest, so a wrong proposal is a missed optimisation, never a
miscompile. O3/O4 only (`SH2_NO_INT_CYCLES=1` kills it); O0/Og never
invoke it. String-observed vars, subshell-written vars, `for`-iteration
vars, hex/row/capture text and `${v#pat}` strips are never proposed.

Measured on `MIMEcroft_fb.sh` (`--emit-c` counts, hoist-only vs +cycles):

| scope | `atoll` | `_sh_xstrdup` |
|---|---|---|
| `rb_tri` (per-pixel nest) | 67 → 3 | 53 → 7 |
| whole render | 1285 → 716 | 3332 → 3241 |

88 scalar decls flip `char*`/`char[21]` → `long long` (300 pushes;
`pl_secs`, hex rows, `rbx_s=$1`, `RFB_ROWS`/`RBTEX_*` correctly refused).
Frame-1 oracle score (`tools/oracle-vs-fb0.sh` recipe vs archived
`frame1-A.png`): **33.17%** — the documented walkthrough baseline —
vs 33.05–33.06% without the pass, deterministic across 8+3+2 runs.
Same-condition `--demo`: render **86 → 44 ms/frame**, movement-frame
render 1533 → 761 ms. CUDA: no dispatchable loop in this program
(`--check`: 0 GLSL/CUDA candidates — the rasterizer is `while`-based;
`--gpu=force` correctly refuses), so the CUDA leg is unchanged.

Verified: full `bash-o4` suite green (131 passed / 0 failed);
`ground-regress.sh` PASS; kill-switch (`SH2_NO_INT_CYCLES=1`) frame
matches the no-pass render; `--check` output unchanged.

## Unreleased — MIMEcroft_fb leaks fixed (heap `setenv` + capped string arrays)

Two independent leak classes found by running MIMEcroft_fb under LSan and by
`mallinfo2()` probes at each step of the menu loop. Both are **codegen**
defects, so every transpiled program benefits; MIMEcroft_fb is just the
program big enough to make them visible.

### Fixed — `_sh_export` leaked the whole exported value on every export

`_sh_export(name, val)` was `setenv(name, val, 1)`. glibc allocates a fresh
`name=value` block per call and does not reuse it at a stable address, so a
variable re-exported with a **large** value per frame grows the parent heap
without bound. Measured `MIMEcroft_fb` (`rb_present` exports its 41 KB
`rbp_chunk` 15× per presented frame):

| build | menu-loop heap |
|---|---|
| `setenv` (before) | `uordblks` **324 MB** and climbing at f=1420; RSS 55 MB rising |
| value capped at 1 KiB (control) | **flat** 21 MB — growth is O(exported value), not the program's own allocs |
| `putenv` (after) | **flat 5.5 MB**, RSS 14.6 MB |

`_sh_export` now keeps ONE parent-owned `name=value` block per name (a
64-slot table, `realloc`'d only when the value grows) and hands the child
that block with `putenv()`, so a re-export is a `memcpy` into a stable buffer
instead of a fresh glibc copy. The block is intentionally never freed — the
environment outlives every call and `putenv` keeps the pointer. Past 64
distinct names it falls back to `setenv`.

End-to-end: MIMEcroft_fb sat in the game loop at a **flat 34.5 MB over
10 minutes**, where the pre-fix build reached 329 MB in the same window.

### Fixed — a string array's elements leaked on every re-literal

`arr=(...)`/`declare -a arr=(...)` reset `arr_len = 0` and re-`strdup`'d the
slots, but the free-before-reset loop was emitted for **vec** (growable)
string arrays only. A **capped** array (`static char *a[cap] = {0}`)
re-literalized per call dropped the old strings forever — the source comment
said so outright ("fixed arrays leak them — pre-existing"). LSan pointed
straight at it: `_sh_xstrdup -> label_glyphs -> gen_label_tex -> load_labels`
(`lgi=(...)` runs once per glyph). The same omission existed at
`unset arr`, `unset arr[i]` and `declare -a arr=(...)`.

All four now free the dropped slots first (`is_string_array` decides — not
int, not assoc, not the `mpz_t[]` array-return arrays). LSan on the demo path
went from `EXIT=23`/96 leaked allocations to **`EXIT=0`, no leak report**.

Verified: C corpus gate `598 PASS / 652` **byte-identical verdicts per file**
with and without the change (`harness/c-gate-run.sh`, baseline vs patched);
`bash-o4` test suite green. Output byte-identical vs bash on the export-path
probes (shrink, grow, one-shot, heredoc, multi-var).

### Known, not fixed here

- **Background `&` jobs are only reaped by an explicit `wait`.** Nothing
  `waitpid`s `_sh_bg_pids` otherwise, so MIMEcroft_fb's `tex_bg_submit`
  leaves ~30 zombies per menu session. Separate defect, no heap growth
  attributable to it (the flat 1 KiB control accumulates the same zombies).
- The ~30–60 KB/s residual the previous session documented is gone with the
  two fixes above.

## Unreleased — fb0 fragment dispatch loop (PLAN v52)

Closes the emit-half §11.14 called "remains": the `fb_frag` static
GLSL450 pairs (`blocks`/`overlay`) now dispatch offscreen on a real
Vulkan device (Lavapipe-pinned).

### Added

- **`fb_draw::RasterRunner`** (`bash-o4/src/fb_draw.rs`): offscreen
  color+depth target, atlas upload (crack = layer 9), blocks (36-vert
  list, depth on) + overlay (6-vert list, src-alpha) graphics
  pipelines, push constants, readback. Struct layouts verified against
  `vulkan_core.h` (gcc sizeof probe).
- **`tests/fb_dispatch.rs`**: blocks centre pixel == Rust oracle of
  `frag_pixel` (204,0,0 for shade-800 red) + clear corners +
  determinism; overlay opaque green full-screen. Reported skip with no
  device, loud failure on misrender.
- **`--fb-proof[=WxH]`**: the proof scene through the real binary as a
  P6 PPM (translucent-green-over-red exercises the blend path).

### Fixed

- Two emitter bugs the missing dispatch hid (both pinned by
  strengthened unit tests): `gl_InstanceID`/`VertexID` are OpenGL names
  — Vulkan wants `gl_InstanceIndex`/`VertexIndex`; `fy`/`fz` missed the
  `/1e6` milli divisor and exploded verts to ±50000.
- Lavapipe teardown faults found + documented (pool/framebuffer/
  render-pass freed pool-last / cached / device-leaked by design).

Verified 2026-10-12: `cargo test --offline --test fb_dispatch` 2/2 ok,
`--fb-proof=64x64` rc=0 12301-byte P6, `--emit-shader fb-blocks` rc=0.

### Fixed

- **Grass (and every) texture rendered one row + black**
  (`MIMEcroft_fb.sh` `rb_tex_load`, mirrored in
  `src/sh/rb-raster.sh`): the loop ran `N` times where the
  `fb_texture` contract (`sh2perl/runtime/fbdev.c`: `total = n*n`)
  loads `N*N` texels, so a 32×32 texture uploaded 32 texels and
  every sample past the first row read unset (black) slots.
- **Textured surfaces ~2× overbright** (same files, `rb_cube` +
  `rb_frag`): the tint ran at 0..255 with a 255 clamp, but the
  canonical fragment shader (`examples/mimecroft-frag.sh`:
  `vcolor = int(vColor*127)`, `out = vcolor*tex/128`, max 253, no
  upper clamp) quantizes tint×shade to 0..127. Grass (white tint)
  blew out to 255; now byte-exact vs the shader chain on 1120/1120
  probed (tint, shade, texel) combinations, and the grass band
  shares its palette with the oracle frame.
- **Settings menu never displayed in fbview** (`MIMEcroft_fb.sh`
  `settings_menu`/`preview_frame`, 2026-10-14): `draw_settings_menu`
  drew the card into the rows with no present, and every loop iteration
  then wiped it — `preview_frame` ends in `render_frame` (whose first
  op is `rb_clear`) + `rb_present`, the no-preview branch in
  `rb_clear` + `rb_present` — so the file and the window showed the
  bare 3D scene while the menu existed only as terminal echoes.
  `preview_frame` now renders without presenting; the loop tail
  composites once per iteration (3D-or-clear → `draw_settings_card` →
  single `rb_present`). The card draw is split out of
  `draw_settings_menu` (terminal echoes stay once-per-call, safe from
  the 20Hz loop). Verified live: window shows the SETTINGS card over
  the AI preview, SPACE dismisses into the game, in-game frames keep
  presenting (fb hash changes frame to frame).
- **fbview froze on any missed mtime** (`tools/fbview.py`): the window
  repainted only when the fb file's mtime changed, so a coarse
  timestamp or a stalled-then-resumed game left a stale window with no
  recovery. A 1Hz re-read tick now re-presents whenever the pixels
  actually differ (Exposes feed the same pixel-compare path).
- **Transpiled code leaked every reassigned heap string** (sh2perl
  `a5b871f93`, `src/c_backend.rs`): ownership was honoured only for
  file-scope reassignments and a few custom store sites, so
  `_sh_arr_set`, the string-vec indexed store, `_sh_assoc_set`'s
  replace arm, the non-top-level branch of the main assign path, and
  nested `declare x=...` all overwrote the pointer without freeing the
  old value. All six now copy first, then free (the RHS may alias the
  slot); `_sh_grow_str` also zeroes the grown region so the new
  free-on-store can never hit an uninitialized slot. A 12-line
  array-reassignment reproducer went from 25 GB in 60 s to 2.4 MB flat;
  a function-scope growing string from 1.35 GB to 2.2 MB flat;
  `MIMEcroft_fb`'s menu loop from ~26 GB + a D-state wedge at 10 min to
  26 MB at 5 min (game heap row-string copies 28,741 → 251). Output
  byte-identical vs bash on the array corpus; `c_backend` unit-test
  failure set unchanged; `bash-o4` tests green. A residual ~30-60 KB/s
  growth remains and is documented, with the evidence trail, in
  `core-requests/bash-o4-20261014-174500-heap-ownership-landed-residual.md`.

### Added

- **`./play.sh`: one-command interactive play** (2026-10-14): builds
  the game if stale (`--build` forces, `--no-build` skips), opens the
  fbview window, runs the game against it (frames via a temp BGRX
  file, window keys back through the queue), and cleans up both plus
  all temp files on exit. ` -- --demo` auto-plays for a smoke test;
  `--scale N` sizes the window. Verified live: menu card over the 3D
  in the window, SPACE in the window dismisses into the game, q quits
  cleanly (game + launcher exit 0, no stray processes or temp files).

### Still open (unchanged)

- The `_sh_gpu_*` host split in generated C; the proof scene is not a
  program payload.

### Performance (offered, sh2perl 22e354c33 — int-element array homing)

- **Transpiled-C game frame: 462ms → 181ms (scene 428ms → 158ms)**
  measured `MIMEcroft_fb --demo` (`#stats avg`, two runs 194/181ms).
  New C-local pass (`SH2_NO_INT_ELEM=1` kills it, C backend only):
  int-store + dense + join-free arrays home as native `long long[]`
  (polygon/texture-index buffers that the shared analysis kept
  `char*`), element-readers and pure-arith temps seed `Int`.
  Frame pixels 99.9987% identical (1 adjacent-texel edge pixel);
  oracle agreement unchanged within tree drift. Unit tests: zero new
  failures. Offered per §11 marketplace (workspace gitlink not bumped
  here — see PLAN.md §11.14). Remaining gap to the ~7ms JS oracle:
  per-pixel argv marshal (int-param ABI), RBTEX texel-parse modeling +
  per-triangle slot-load LICM, row-buffer accumulation.

## 0.1.1 — 2026-09-14

Transpiled GPU (CUDA) reaches parity with hand-written kernels, and the
CPU backend closes the last known codegen gap.

### Added

- **Transpiled CUDA** (`cutranspile` / `bash_o4::cu_run`): bash → ShIR →
  candidacy → PTX → CUDA with **no hand kernels**. `cutranspile
  <script.sh> <N>` prints `<median_ms> <checksum>`; `SKIP …` + exit 2
  when there is no device, no runnable shape, or an extern that needs an
  explicit `--bind VAR=VAL` (values are never guessed).
- **CUDA candidacies** (`cu_candidacy`): *map* (one or more independent
  affine stores), *reduce* (`acc+X`, `acc*X`, `(acc+X)%m`,
  `(acc+X)&mask`, optionally reading an array a fusable map produces),
  and *seq* (a sequential per-lane kernel). Map+reduce over the same
  iteration space **fuse** into two kernels with one array and a
  partials-only readback.
- **Sequential lane-nests** (`shir_passes::lane_private`): a shared
  privatization analysis proving an outer iteration is independent
  (ordered init dominance, chain writes dominated by those inits,
  accumulate only in the tail, pure tests), so one lane can run a whole
  `while` chain — this is what makes `collatz` dispatchable.
- **`fuse-fill-consume`**: a covering array-fill loop plus a same-space
  consumer becomes one loop with the fill's RHS forwarded, and the fill
  and its materialization are deleted. Now handles **multi-store** fills
  (one binding per array).
- **`isolate-accumulate`**: single-use loop-private temporaries fold into
  a self-referential tail, isolating one accumulate statement.
- **Shared maskable / unsigned lowering** (`shir_passes::maskable`) with
  loop versioning: `% 2^k` lowers to `& (2^k-1)` on a verified fast path
  (dividend provably non-negative and nowrap) with a signed slow path.
- **`python-O4`**, a Python front end reusing the same C render, `tcc`
  JIT/AOT and CUDA dispatch (`--gpu`).
- **Vulkan**: per-dispatch pipeline cache (compiled pipeline set keyed by
  SPIR-V hash) and an optional `spirv-opt -O` post-pass.
- **Benchmarks** (`bench/bench.sh`, `bench/bench-opt.sh`) with an
  agreement gate — no row is printed unless every running leg's checksum
  byte-agrees — and the `twoarr`, `hash` cases.
- Build-time content-addressed cache revision (HEAD SHAs + dirt hash of
  the workspace and the sh2perl submodule), so uncommitted edits force a
  cache *miss* rather than serving a stale pre-fix render.

### Measured (see `bench/README.md` for the method)

Per-leg minimum over 3 suite runs of 5 reps, on a shared 8-CPU box.

| problem | N | gcc-O3 | bo4-gcc | cuda (hand) | cuda-tx (transpiled) |
|---|---|---|---|---|---|
| sumred | 1B | 1.107 s | 1.028 s (1.1×) | 0.004 s | 0.004 s (**1.0×**) |
| squares-map | 100M | 0.326 s | 0.115 s (2.8×) | 0.001 s | 0.001 s (**~1×**) |
| twoarr | 50M | 0.423 s | 0.066 s (6.4×) | — | 0.001 s |
| collatz | 18M | 1.365 s | 1.178 s (1.2×) | 0.013 s | 0.014 s (**1.08×**) |

- The **transpiled CUDA leg is level with hand-tuned PTX** (1.0–1.1×) on
  all three shapes that have both, with byte-identical checksums.
- The C column's 2.8×/6.4× on `squares-map`/`twoarr` is **algorithmic**:
  fusion deletes an unobservable intermediate array, so bash-O4 makes one
  pass where the reference makes two. It is not a codegen claim.

### Fixed

- Signed `%` blocking strength reduction (the previous round's identified
  ~2× gap), via the shared maskable analysis + versioning.
- Loop-invariant bound hoisting (LIC), worth ~4–6× on bound-variable loops.

### Open release decisions (not code)

- **Licensing is undeclared.** `bash-o4` links the `sh2perl` core, whose
  `LICENSE` states GPL-3 *with an additional Apache-2.0 permission* for named
  paid-work recipients and their subrecipients. That has no single SPDX id, so
  `Cargo.toml` deliberately carries no `license`/`license-file` key rather than
  a wrong one. Decide before publishing (probably `license-file` pointing at a
  copy of `../sh2perl/LICENSE`).
- **Not `cargo publish`-able**: `../sh2perl` and `../otranspilerl` are path
  dependencies and the frontends build separately.
- **`tcc` is a runtime dependency** for the default (JIT) path, with a loud
  cc/gcc/clang fallback; it is not vendored.

### Known limitations

Recorded in full under "Known limitations" in `README.md` and section 7
of `docs/BASH-O4.md`. The short list:

- Vulkan here is **Lavapipe** (software); the `gpu` column is a scaffold
  measurement, not a hardware claim.
- `tcc` cannot parse glibc `<regex.h>`; the driver falls back to
  `cc`/`gcc`/`clang` **loudly** (never silently).
- The C backend keeps a fixed array-capacity backstop (`ARR_CAP`, 1024)
  for arrays whose size it cannot prove.
- `--gpu` offloads **one loop**, not the whole program: the kernel's trip
  count comes from `--n`/`--bind`, so a loop whose bound the driver cannot
  supply (a function-local) is vetoed by the candidacy, and a program outside
  the single-integer-output contract reports the offloaded loop's checksum
  rather than its stdout. The whole-program host split is the open M3 item.
- `hash` has no hand-written GPU kernel: its `cuda-tx` row is
  correct-and-fast, not proven-optimal.
- `./fail` (Perl corpus) sits at a pre-existing 260/552 baseline owned by
  the ESTree/Perl workstream. The gates for this work are
  `harness/c_gate_main.sh` (637/0/7) and `harness/gpu_gate.sh` (545/0/7).
- Benchmarks ran on a shared box (load average 7–10 on 8 CPUs); ratios
  are stable, absolute seconds are indicative.

## 0.1.0 — 2026-09-13

Initial M1/M2/M4: the `bash-O4` driver (tcc JIT/AOT, artifact cache,
hash-pinned library fetch), GPU-candidacy analysis (`--check`), GLSL-450
shader emission (`--emit-shader`) with SPIR-V proof, and the C/Vulkan
gates.
