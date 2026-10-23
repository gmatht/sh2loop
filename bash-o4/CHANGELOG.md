# `-O4` driver changelog

Covers the whole `-O4` driver family — `bash-O4` and `python-O4` are two front
ends over one pipeline (`ShIR` → C via tcc, or → PTX via the CUDA candidacy),
sharing one flag surface (`bash-o4/src/flags.rs`) and one dispatch vehicle
(`bash_o4::cu_run`).

## Unreleased — string `case` patterns compare by CONTENT in C: MIMEcroft demo 62.8s → 12.1s (5.2×)

- **C string Eq/Ne renders as a real strcmp** (c_backend `expr()` BinOp
  arm): the shared case lowering's `exact_cond` builds
  `BinOp{Ne}(subject, Str)` for an exact `case` pattern, and the C
  backend rendered that pair as **C pointer equality** — operands never
  alias, so `!=` was vacuously TRUE and `==` vacuously FALSE. On
  MIMEcroft, `case $lso_name in jpeg|png|octet|text)` never matched
  native (the binary kept 32px where bash picks 64), the texture-cache
  keys could never hit, and FOUR child-bash texture generators re-ran
  every single run — 87.9% of demo CPU in child bash (prof samples +
  ps child sampling). Fixed in the C backend only (rust/perl/python
  `!=` are content compares by language semantics) and conservatively:
  both operands must be certainly-text shapes (`str_cmp_valued`:
  Str/Interpolate/Capture/non-numeric Var/`getVar`/ternary of those) or
  the old numeric path stands; nocasematch still folds to
  `fnmatch(..., FNM_CASEFOLD)`. Only patterns WITHOUT glob
  metacharacters take the strcmp path — `case $x in \*)` keeps the
  backend's own fnmatch case render, where a literal star is right.
- **NULL-safety (RENDERER_REV 13 → 14)**: a string-homed global read
  before its first assignment is a NULL `char*`, and `strcmp(NULL, s)`
  segfaulted at startup (observed: AVX strcmp, rdi=0, frame `main`) —
  the pointer compare it replaced was NULL-safe only by accident.
  Both operands now pass through the `_sh_sc` helper (returns
  `x ? x : ""`; same rationale as `_sh_env` — one evaluation and the C
  static analyzer sees a non-NULL return); string literals stay bare.
  The rev bump re-renders every cached artifact whose C changed.
- **Measured** (same session, same box, A/B pair `mime-off` vs
  `mime-on`, `--demo`): off `wall=62.77 user=54.40` → on
  `wall=12.06 user=5.40` — **5.2× wall, 10× user CPU**; the ~49s of
  eliminated user CPU is exactly the four child-bash texture
  generators no longer re-running (native case match → cache hit).
  Game output byte-identical apart from the `#stats` timing lines.
- Regression test:
  `pipeline::tests::string_case_pattern_compares_by_content_not_pointer`
  (full-pipeline render of `case $x in "jpeg")` must emit strcmp, not
  a pointer compare). First render of the fix segfaulted because the
  operands were raw `self.expr()` renders (unguarded global reads) —
  hence `_sh_sc`.

## Unreleased — byte-reproducible renders + the driver-fed absorb table

- **Deterministic teardown frees** (c_backend): `var_lifetimes` was a
  `HashMap` that both free-emission sites (function exits, main's
  teardown) clone and iterate, so `HashMap::RandomState` ordering made
  the trailing `free(...)` lines flip between IDENTICAL renders — two
  `--emit-c` runs of `MIMEcroft_fb.sh` differed *only* in teardown free
  order (measured, then fixed). It is now a `BTreeMap`: generated C is
  byte-reproducible run over run, which every A/B methodology and the
  artifact cache's trust depend on (a per-run permutation of the same
  lines was semantically neutral — distinct live allocations commute —
  but it made byte-diff A/B impossible to read).
- **Driver-fed absorb table** (bash-o4 `pipeline::feed_absorb_table`,
  called from `cli.rs` before `artifact_key` so the feed keys the
  render): statically-named commands from every exec/capture site are
  collected on the A1 the compile already holds (no re-parse; function
  BODIES are walked — most of a real script's commands live there —
  and script-defined function names are SUBTRACTED, since bash resolves
  a def before any same-named external and `--ensure` must never be
  asked to grow the `.so` for `draw_text`-style names). Candidates are
  bounded by the built helper's availability stamp
  (`runtime/lib/uu-ffi.features`): `build_uu_ffi.sh --ensure <names>`
  grows the helper only when the request exceeds the stamp (cached
  no-op otherwise), and the driver re-reads the STAMP afterwards —
  never the command's stdout, which on a real grow is the cargo build
  log. The extras (stamp − `c_backend::UU_BUILTIN_CMDS`) are published
  as `SH2_ABSORB_CMDS`; the renderer UNIONS them onto its always-on
  builtin set, so an empty feed renders byte-for-byte the same and a
  discovery miss can only fail to widen. `SH2_NO_ABSORB=1` kills both
  sides; both vars are keyed in `render_env_key`. On MIMEcroft the
  feed is empty BY DESIGN: its only stamp-covered static commands
  (`cat`×6, `wc`×2, `date`×1) are already in the builtin set, and
  growth beyond the stamp is refused while the uu-ffi crate source is
  absent (availability is never guessed — an uncompiled util is rc 127
  at runtime). Unit test:
  `absorb_candidates_cover_function_bodies_and_exclude_defs`.
- **`render_env_key` superset capture**: every remaining env var the
  render path reads is now folded into the render cache key (the
  `SH2_ASSUME_*` gates, `SH2_NO_SCANFIX`/`NO_SPLIT_FOLD`/
  `NO_ARRAY_MIGRATE`/`NO_INT_ELEM`, `SH2_LIST_VEC`, `SH2_DUAL_LOOPS`,
  `SH2_BC_NATIVE`, `SH2_ARGV0`, `SH2_LIBRARY`, profile inputs, and the
  diagnostic gates) — same policy as `parse_key`'s doc: an extra input
  only costs a miss, a missing one risks a stale HIT (the failure
  class that has bitten this driver twice). Consequence: one-time
  invalidation of all cached renders. `SH2_NO_SCANFIX` in particular
  was render-time but unkeyed — a scanfix-off render could be served
  from a scanfix-on entry.
- Verification: `harness/c_gate_main.sh` **624 PASS / 19 FAIL / 7 SKIP**
  — the 19 all in the pre-existing `cc`/`stub` buckets (free ORDER
  cannot affect compile or stub stages; zero stdout/rc/timeout fails);
  `cargo test --lib cache::` 8/8, `pipeline` 4/4.

## Unreleased — `_sh_sset` strnlen fit test + single-scan strip helpers: −13.8% total string-scan bytes on the MIMEcroft demo

Caller-attributed byte sampling (`dladdr` on every 64th `strlen`, bytes
weighted by the sample rate) put the demo's main-process `strlen` at
29.9 GB over 42.2M calls, and named where it goes: `_sh_sset`'s reuse
test walked the whole old buffer on every store (15.1 GB / 52%, 431 B
avg) and `_sh_strippre`/`_sh_stripsuf` rescanned the copy they had just
made (7.8 GB / 27%, ~10 KB strings).

- **`_sh_sset` fit test is strnlen-capped** (c_backend): the verdict
  `strlen(old)+1 >= n` needs only that the first n−1 bytes hold no NUL,
  so `strnlen(old, n-1) == n-1` gives the identical decision while the
  scan stops at `n-1 = strlen(src)` instead of walking the whole old
  buffer — O(min(old,src)) per store, never more work than before.
- **Strip helpers scan once** (c_backend): `n` comes from `strlen(s)`
  before the copy; the old form called `strlen(sc.p)` on the just-made
  copy — a second full scan of a ~10 KB string.
- `SH2_NO_SCANFIX=1` restores both legacy forms.

Measured on `MIMEcroft_fb.sh --demo`, same-binary A/B whose generated C
diff is exactly these edits: **total string scanning (strlen+strnlen)
29.03 GB → 25.04 GB (−13.8%)** in the main process. The strlen-only
figure is 29.94 → 17.74 GB (−40.7%, calls 42.2M → 26.8M) — but 8.20 GB
of that *moves into* `strnlen` (the fit test scans min(old,src), and
same-size reassigns dominate), so −13.8% is the honest headline, not
−40.7%. `perf stat`: **295.24B → 291.21B instructions (−1.4%), cycles
−6.5%, cache-misses −20% (IPC 1.72 → 1.82)**. Wall/user time is *not*
measurable on this box — load swings 7–19 between runs across parallel
workers and the demo is memory-bandwidth bound, which is also why the
earlier `memset`-tail experiment (normalize-on-realloc in `_sh_grow`)
was **reverted**: the byte A/B falsified it (identical scan bytes both
sides — `strlen` stops at the string's own terminator and never reads
the normalized tail), so the C was restored to the original body
rather than shipped as a no-op.

- `harness/c_gate_main.sh`: **628 PASS / 19 FAIL / 7 SKIP — the exact
  pre-change fail set (same 19 files)**.
- Demo stdout: byte-identical to baseline (only the `#stats:` timing
  lines differ, on both sides run-to-run).

## Unreleased — `store_ref` decl guard + `fb_size()`: the MIMEcroft build is green again

Two blockers stood between the renderer and a runnable MIMEcroft demo — one
a declaration guard that fired at the wrong set, one a runtime primitive
that had never been written:

- **`store_ref` became the decl-aware choke point (`has_c_decl`).** `store`
collects READ mentions (`collect_store_expr` inserts plain `Var` names), so
an env-only var — the game's `sm_size_old`, written by the child bash and
read only in the texture-cache replay tests — sits in `store` with nothing
hoisted for it, and every read rendered `atoll((sm_size_old ?
sm_size_old : ""))`: an undeclared ident that fails tcc *and* cc and takes
the whole program down. The first attempt at the guard keyed on
`var_types || top_vars || inventory_vars` — but `collect_vars_full` skips
function bodies (`_ => {}`) and for-loop counters (`for_vars`), so it
over-fired on **249 reads** of perfectly declared fn-local vars, and
`start_level`'s loops then waited on `_sh_env("")` forever (the demo hung
to its timeout). The predicate is now `has_c_decl` = typed verdict /
file-scope walk / **`hoist_vars`** (pass-1 `collect_assigned_vars` over
the whole program — exactly the set the file-scope and fn-local hoists
declare), consulted at `store_ref` itself (every bare-ident read site
funnels through its null-guard arm), `store_read`, the expr `Var` arm and
the test-word expander; `store_read`'s `_sh_env` fallbacks also set
`need_sh`, without which the helper block they live in is trimmed and the
program fails to link. `_sh_env` reads on MIMEcroft: **249 → 17**,
byte-for-name the pre-regression set (the `sm_*_old` quartet, FB_DUMP/
FBWIN, the array-element shapes). `RENDERER_REV` 8→9.
- **`fb_size()` implemented in `runtime/fbdev.c`/`.h`** — the missing half
of the Oct-9 capture lift (`5e7774b7b`, “capture fb_size() so the DISPLAY
row's read-back works”): the entry made renders *call* `fb_size()` while no
translation unit ever defined it (absent from `runtime/` history
throughout), so once `sm_size_old` compiled the demo died at link
(`undefined symbol 'fb_size'`). Contract per the game's own comments:
`"WxH"` of the open surface, `"-1"` before the first successful
`fb_open` (S_opened only rises on success); static buffer, the lifetime
the capture helper strdups.

Verified:

- `MIMEcroft_fb.sh --demo`: rc=0, GAME DONE, **290 frames / 10.0 s
  (34 ms/frame)**, zero compiler diagnostics, `fb0: native framebuffer
  800x600` (the read-back line that used to resolve empty), and no
  `regenerating textures…` — the replay tests hit, i.e. `_sh_env` reads
  exactly what the child exported (the rev-7 perf win, preserved).
- `harness/c_gate_main.sh`: **641 PASS / 4 FAIL / 7 SKIP — the exact
documented baseline**, the 4 the same pre-existing files (063_07 cc,
parse-bracket-unexpected cc, two frontend stubs).
- `cargo test --lib`: 1370 passed / 10 failed; `c_backend::` **158/9 vs
  143/10 at committed HEAD** (run in the `backends/core` worktree as a
  clean baseline): same 9-failure set — the documented pre-existing
  lift/rc/GMP/int-homing reds, none touching this change — plus one
  baseline failure (`p1_strdup_checked_at_call_sites`) now passing.


## 0.1.2 — 2026-10-20

MIMEcroft (`MIMEcroft_fb.sh --demo`) render performance: the shared
numstr seeding pass is now *wired* into the C ingest, plus two
C-specific lowering wins — each with a kill switch.

### Added

- **Shared numstr seeding** (`sh2perl/src/shir_passes/numstr.rs`, wired
  via `seed_numstr_fixpoint`): the vars×params fixpoint seeds `Int`
  verdicts into `var_types` ahead of `demote_stringy_ints`, which
  re-validates every seed, so an over-eager seed can only be removed.
  The `GpuOp` Ext node is exempted from the walk's blanket block — a
  lifted device write carries a payload and no variable target, i.e. an
  `Output`-like consumer. Render-loop counters (`dt_i` and 205 others)
  home to `long long`: no per-iteration `atoll`/`snprintf`/`strncpy`
  round trip. `SH2_NO_NUMSTR=1` disables.
- **Stable-substr copy elision** (`is_stable_src`): `_sh_substr` only
  reads its source, so `store_read`'s null-guard form `(x ? x : "")`
  around a bare ident needs no stabilizing copy — drops a per-slice
  `strlen`+`strcpy` of the whole source (`draw_text` paid it once per
  character). `SH2_NO_STABLE_SUBSTR=1` keeps the legacy copy.
- **fbdev near-first raster with a coverage mask** (`runtime/fbdev.c`):
  faces/records paint from the last pixel backwards while a mask marks
  what a near-first pass may no longer change — byte-equivalent pixels
  by construction (exactly one write per covered pixel). `SH2_NO_FB_MASK=1`
  restores the legacy painter.
- **In-place string store `_sh_sset`** (c_backend): every file-scope
  `char *_old = v; v = _sh_xstrdup(…); free(_old);` temp-swap renders
  as ONE capacity-reusing helper call — `memmove` into the old buffer
  when the new value fits (`memmove` covers a self-aliasing RHS like
  `s="$s-x"`), checked `_sh_xstrdup` allocation otherwise, so the P1
  fail-stop OOM policy is unchanged (the helper's inner call keeps the
  canonical `_sh_xstrdup((char*)…)` marker
  `p1_strdup_checked_at_call_sites` greps). MIMEcroft demo: strdup
  calls 1,396,163 → 749,687 (**−46.3%**), `_old` sites 479 → 0, emitted
  C −22.5 KB. `SH2_NO_SSET=1` keeps the legacy swap (keyed in
  `render_env_key`).
- **Take-field splits store in place** (`emit_take_block`): the fused
  `${var%%d*}` / `${var#*d}` split block used to `_sh_xstrdup` the
  field AND the whole remaining payload on every token, then
  swap-and-free the olds — O(n²) bytes through the allocator per
  stream. Heap dests now store through `_sh_sset`; for the remainder
  dest the source pointer is a suffix of that var's own buffer, so the
  capacity branch memmoves the suffix forward with no allocation at
  all. MIMEcroft demo: **strdup 747,797 → 34,602 calls (−95.4%)**,
  interposed libc time 488–539 ms → ~4 ms across three interleaved
  rounds (−99%), ~713k fewer malloc/free pairs per run, emitted C
  −772 B. `SH2_NO_TAKE_SSET=1` keeps the legacy fresh-copy path
  (keyed in `render_env_key`); `RENDERER_REV` 10→11.
- **`unset` of an owned string no longer aliases static storage**
  (c_backend unset arm — a pre-existing HEAD bug found by the perf
  harness): `s=hi; unset s` rendered `s = "";` — pointing an owned
  `char*` at a literal — while the exit teardown (and every later
  store's `free(_old)`) still owned it, so the program segfaulted at
  exit on `free(rodata)`. The arm now emits `free(s); s = NULL;` for
  exactly the teardown walker's own `is_heap_store_var` set (const-
  lifted literals keep the literal clear — teardown never frees them,
  so aliasing is safe there); NULL still reads as `""` through the
  store guards and `free(NULL)` is a no-op, so the NULL-or-heap
  invariant every free site depends on is preserved. The repro family
  (`s=hi; s=""; unset s; …` and `unset`-first) now matches bash with
  the in-place store on and off.
- `RENDERER_REV` 8→10: 9 folded the numstr/stable-substr switches into
  the artifact cache key (`render_env_key`), so a render cached under
  one switch value is never served for another (this class of staleness
  bit the session once before the switch keys existed); 10 is the
  in-place string store, which landed after 9 and changes default
  render output.

### Measured

`MIMEcroft_fb.sh --demo`, `DEMO_FRAMES=300`, gcc -O2, interleaved A/B/C/D
rounds ×5, `/usr/bin/time` user seconds (mean of 5): legacy **4.74 s** →

| config | user s | vs legacy |
|---|---|---|
| raster only | 3.43 | −27.6% |
| codegen levers only | 4.71 | −0.6% (within noise, n=5) |
| raster + codegen levers | **3.29** | **−30.6%** |

The codegen levers' direct effect is source-level (per-iteration round
trips gone, emitted C −16.8 KB); on top of the raster win they add a
−3.6% median further cut. Demo stdout is byte-identical between levers
on/off (modulo `#stats` timing lines); the demo's final score can differ
across builds because its scripted events are wall-clock scheduled — a
faster build plays a slightly different game.

The in-place string store's own A/B (same protocol, ×5 interleaved,
equal frame counts) moves wall-clock −2.1% on the otranspilerl path
(1.360 → 1.332 s user) and +1.2% on the bash-O4 path (3.344 → 3.384 s)
— both inside the box's ±13% run-to-run spread, so its win is claimed
at source level only (−46% strdup, −22.5 KB emitted C). PPM byte-
identity is not achievable on the 300-frame demo for ANY lever: the
demo's final frame varies run-to-run (scripted HUD events), including
between two runs of the *same* binary — measured directly. This
lever's render-equivalence evidence is the 631-program c_gate corpus
(stdout vs bash, identical verdicts with `SH2_NO_SSET` on and off)
plus a dedicated grow/shrink/self-alias/empty/unset program compiled
and diffed against bash.

The take-field in-place split shows the same shape with a bigger
instrumented gap: the libc saving is large and stable (488–539 ms of
interposed strdup time, three interleaved pinned rounds) but
wall-clock with one CPU pinned (taskset, ×8 interleaved) moves only
−0.7% (sd 0.18–0.26 s) — malloc/free of small blocks is cheap enough
that the freed time lands inside this box's noise floor. The lever's
claim is again source-level: **−95.4% strdup calls, −713k malloc/free
pairs per demo run**, with ON ≡ OFF byte-identical stdout on the
split repro family (loop/no-space/empty/fused) and an unchanged
corpus verdict set (629/16/7, the same files as before the lever —
its renders change but every take-block program still matches bash).

### Known limitations

- `harness/c_gate_main.sh` at this commit: **631/14/7** (`_sh_rc`
  undeclared in generated `main` for test/nested-if shapes) and 9
  `c_backend` unit tests red — both sets reproduce **with both switch
  env vars set** (this entry's changes fully disabled), so they come
  from in-flight shared-core edits in this workspace
  (`src/parser/`, `src/ir.rs`, `src/pipeline_native/` ≈ 2.8k
  uncommitted lines), not from 0.1.2. Prior recorded baselines:
  637/0/7 at 0.1.1, 641/4/7 before this session's work began.

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
