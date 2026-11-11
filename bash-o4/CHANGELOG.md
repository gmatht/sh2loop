# `-O4` driver changelog

Covers the whole `-O4` driver family — `bash-O4` and `python-O4` are two front
ends over one pipeline (`ShIR` → C via tcc, or → PTX via the CUDA candidacy),
sharing one flag surface (`bash-o4/src/flags.rs`) and one dispatch vehicle
(`bash_o4::cu_run`).

## Unreleased — arr-load-fwd lands: MIMEcroft's per-call table copies read the table directly (first-frame −1.87% instructions; frame byte-exact vs bash)

The `arr-load-fwd` shIR→shIR transform (a single-def element load
`v=${T[$k]}` folded into its later reads, so the scalar copy never
materialises) existed and unit-tested, but rendered `MIMEcroft_fb.sh`
**byte-identically** with `SH2_NO_ARR_LOAD_FWD=1` or not. Two gates
were in the way, both fixed in the core:

- **One command substitution disabled the pass program-wide.**
  `has_dynamic` refused the whole pass on any `eval`/`source` **or any
  closure-shaped expression anywhere** — MIMEcroft's single
  `sl_x=$(exec cat …)` (`Capture{Arrow}`) was enough. The span rule
  already buys that soundness exactly: `stmt_refuses` refuses every
  statement form that can carry a closure/capture/call, so a forward
  only ever crosses provably inert statements. The `eval`/`source`
  clause stays (dead-store-elim has the same rule); the closure clause
  and its `expr_has_closure` walker are gone.
- **The orphaned store could never be removed.** Defer-to-DSE was the
  design, but `analyze_var_const` marks every site inside a function
  body multi-run ("a function may run 0..N times") → `Var` → never
  `Const` → DSE refuses forever — precisely `rb_mkhex`'s three
  `rbm_*=${RBHEX[$rbm_*]}` copies (3 string stores per call, 212 k
  calls per frame). The pass now sweeps its OWN orphans after the
  fold — only vars that fold orphaned — under DSE's own standards so
  the two cannot disagree: DSE's `census` (the read/escape verdict),
  DSE's `expr_pure`, `is_shell_implicit`, plus the `export` list
  (children read env-visible names).
- Supporting: `READ_ONLY_CALLS` is now one shared constant in
  `transforms.rs`, and DSE's `expr_pure` learns that a read-only helper
  call (`arrayIndex`, `param`, …) is pure — otherwise the generic Call
  refusal kept every orphaned `v = arrayIndex(…)` alive. Guards: no
  `$(`/backtick inside a `Str` arg, and no `?` in `param`'s op slot
  (`${x:?}` aborts the shell; dropping the store would drop the abort).

Measured on `MIMEcroft_fb.sh --first-frame`, 7 interleaved runs per arm
under `perf stat -e instructions:u`, every PPM md5-checked against the
bash oracle (`53d9cfa7…`): **2 554 479 151 vs 2 603 063 974 median
instructions = −48.58 M = −1.87%** (run spread < 0.001%). `rb_mkhex`
now emits zero scalar copies — the interpolation reads the 256-entry
`RBHEX` table inline — and the C shrinks by 288 bytes. Gates: `./fail`
563/563; c-gate verdicts unchanged ON vs OFF (639 pass / 7 skip / 5
pre-existing fail, identical lists); sh2perl unit suite 1842 green with
no regression attributable to the change. Seams: `SH2_NO_ARR_LOAD_FWD`
and the new `SH2_NO_DSE_CALL_PURE`.

## Unreleased — fb0 runtime hot paths, round 3: per-frame debug I/O out, flash-dirty gate, row-term hoist, identity window blit (bit-exact; demo −5.1% / −2.7% instructions on tcc / gcc -O2)

Round 3 takes the four remaining per-frame costs the round-1/2 profile
left standing, each bit-exact by the same construction as those rounds
— a hoist or inline computes the same value from the same operands,
and a gated fast path provably cannot change an output byte:

- **The three leftover `fprintf(stderr, ...)` debug prints in
  `fbdev.c` are gone** (`DBG ERASED`, `DBG COMPOSITE` — one formatted
  write per `fb_present`, i.e. per frame — and `DBG E` per erase
  record): ad-hoc state tracing from an earlier bug hunt that no gate
  reads (the bench oracles strip `DBG` lines anyway).
- **The flash half of `ov_composite` is gated by `O_flash_dirty`**:
  `ov_apply` arms it on ANY write to the flash layer, the composite
  pass clears it — the pass zeroes exactly the pixels that could be
  nonzero, so "cleared means all-zero" is an invariant, not a guess —
  and on the common frame (muzzle dark) the w*h flash loads and two
  failed branches per pixel are skipped by a persistent-only copy of
  the loop. A conservative arm (an erase record) costs one extra pass,
  never a missed one.
- **`tri_shaded` hoists the row's py terms** (`py - yN` for the edge
  tests, `yN - py` for the barycentric numerators): six double
  subtracts per ROW instead of per pixel, each hoisted value bit-for-
  bit the rounded result the inner loop rederived from the same two
  operands. The px terms stay per-pixel on purpose — an incremental
  `+= 1.0` walk is NOT bit-for-bit when the value crosses a power of
  two and the ulp halves.
- **`frag_sample`'s fast path drops its two lower clamps**, with
  `t->size > 0` added to the guard: the `[0,1)` comparisons exclude
  NaN/±inf and a positive size makes both products non-negative, so
  the truncations cannot go below 0; size-0 falls to the original
  path, whose four clamps compute what the old fast path computed.
  The upper clamps stay — for a non-power-of-two size the product can
  round UP to exactly `size`.
- **`fbwin_present` packs the identity layout with one 32-bit store
  per pixel**: on the depth-24 TrueColor visual every framebuffer here
  hands out, `(rsh,gsh,bsh)==(16,8,0)` makes the swizzle
  `v = p & 0x00FFFFFF`, whose four stored bytes are the word's own
  in-memory bytes on a little-endian host — checked 0 mismatches over
  65,536 pixels against the general form. Any other shift layout or a
  big-endian host falls through to the general form unchanged.

Measured on `MIMEcroft_fb.sh --demo` (100-frame render, 16 alternating
pairs, medians; the rendered prog.c is byte-identical within each
pair, so the ONLY delta is the device sources): **instructions −5.1%
(tcc) and −2.7% (gcc -O2)**, paired medians −5.4% / −2.8%. Task-clock
on this demo is pacing-dominated (the run sleeps ~2/3 of wall), so
instructions are the honest metric; the gcc -O2 arm also shows −4.7%
paired-median task-clock. Correctness: the deterministic fbdev suite
(48 checks + the 112-case silhouette oracle) is green under cc AND
tcc, built old-device vs new-device alike; stdout is identical across
all four arms; the identity blit is byte-equal to the general form by
the unit check above and ran live in every windowed bench arm.

Post-round-3 profile (cc -O2 -g, 999 Hz, in-binary shares):
`fb_blocks` (rasterizer, tri_shaded inlined into it) 56.9%,
`frag_pixel` 16.0%, `frag_sample` 14.8% — and the two targets of this
round fell sharply: `fbwin_present` 9.0% → 1.8%, `ov_composite` 4.6%
→ 1.5%. The transpiled program itself remains ≈1% (0 `_sh_*` function
above 1%); `S_txarr_get` is gone from current renders and the three
remaining `_sh_arr_get` sites are cold setup reads, so no new shIR
transform was warranted this round.

Gates: `harness/c_gate_main.sh` 584/650 with **0 of the 59 reds in an
fb-using cell** (the corpus contains no fb cells at all, so a device
edit cannot reach them; they sit in the concurrently-dirty sh2perl
core); `cargo test` for this crate: 92 pass, 3 pre-existing failures
in files this work does not touch (2 candidacy veto tests fed by that
dirty core, 1 spirv-toolchain probe); `fbwin-test.sh` still cannot
build on this box (no X11/Xlib.h — pre-existing, its oracle is header-
bound while fbwin.c itself deliberately dlopen's libX11).

## Unreleased — fb0 runtime hot paths rounds 1–2, plus `BASH_O4_CFLAGS`: demo tcc→gcc -O2 −14.9% instructions / −15.8% task-clock

Two rounds of bit-exact C-runtime work on the fb0 device (the current
CPU profile of `MIMEcroft_fb.sh --demo` is ~99% inside the runtime: the
`rb_*` software rasterizer left the rendered C entirely, so `_sh_sset`
is 0.2% and `tri_shaded`/`frag_sample`/`fbwin_present`/`frag_pixel`/
`s_div*` are everything) — plus the toolchain knob that turns out to
matter more than either.

**Round 1** (`runtime/fbdev.c`, `runtime/fbwin.c`; full write-up with
the per-site profile table in the fb0 worktree's changelog):

- `frag_sample` `[0,1)` fract fast path — for in-range uv the fixup is
  `x - (double)(long)x == x - 0.0` with the sign branch never firing,
  so skipping it computes the identical `iu/iv`.
- `s_div1000`/`s_div_nonneg` inlined byte-for-byte into `frag_pixel`/
  `frag_vignette` (helpers kept as reference forms, the `tri_covers`
  precedent).
- `fbwin_present` hoisted into the four fixed shapes: the three channel
  shifts and both flags belong to the XImage created at open and were
  re-read per pixel per frame.
- Reverted with numbers: a `_sh_slen`/`_sh_snlen` byte-loop scan in
  `_sh_sset` (instructions wash, user time +3.7% — glibc's IFUNC
  strnlen already answers the short case).
- 16 CPU-pinned pairs, same rendered program, runtime sources the only
  diff: instructions −2.5% paired (−3.0…−3.6% within each gameplay
  band), task-clock −6.1% mean / −2.7% median. `fbdev-test.sh` all
  green (48 checks, silhouette oracle 112 cases 0-outside, coverage 0
  differ); demo stdout identical between arms.

**Round 2** (same two files, after re-profiling round 1):

- **`tri_shaded` edge-diff hoist**: the six vertex-coordinate
  subtractions (`x1-x0` … `y0-y2`) are triangle invariants — computing
  them once yields bit-for-bit the value the per-pixel form produced
  (same operands, same IEEE op; SSE2 doubles carry no excess precision),
  and `py = y + 0.5` moves to its row loop, `px = x + 0.5` to the
  column loop for the same reason. Six subs plus two adds leave every
  candidate pixel. Reassociating the per-pixel halves (`px-x0` as
  `(x-x0)+0.5`) is refused in the comment for the same rounding reason
  the incremental edge walk is refused.
- **`fb_clear` doubling fill**: every element ends at `argb`, so the
  n-iteration store loop becomes log2(n) memmoves (same values, same
  cells; order differs and nothing observes it). Was 2.0% of in-binary
  samples.
- Deterministic micro-A/B (the fb0 device suite, gcc -O0, same test
  program, only `fbdev.c` differing): **432.2 → 418.3 M instructions
  (−3.2%, 3/3 pairs)**.
- `fbdev-test.sh` all green after round 2; demo stdout identical across
  all three arms (tcc old-runtime / tcc new-runtime / gcc -O2).
- Honest limit: a whole-demo A/B of round 2 alone is NOT separable from
  demo play-path band variance (instructions cluster ±3% by gameplay
  path on both sides) — the micro-A/B is the claim, not the demo.

**`BASH_O4_CFLAGS`** (`src/tcc.rs` `compile_exe`, key fold in
`src/cli.rs` + `src/main_py.rs`) — the C-toolchain gap the profiles
kept pointing at: the default toolchain is millisecond tcc with NO
optimization level in front of it, and the cc/gcc/clang fallback also
ran at -O0. The knob appends flags verbatim to the compile command and
folds them into the artifact cache key, so runs with different flags
can never be served each other's executable (the `SH2_NO_*` discipline).
Measured end-to-end through the driver (`BASH_O4_CC=cc
BASH_O4_CFLAGS='-O2 -fno-strict-aliasing'`, same render, 8
CPU-pinned counterbalanced pairs): **instructions 4.914 → 4.183 G
(−14.9%), task-clock 1.672 → 1.408 s (−15.8%), 4/4 pairs both
metrics**; on the deterministic device suite, tcc vs gcc -O2 is
**−20.7% instructions / −18.3% task-clock**. Deliberately not
defaulted: gcc -O2 costs seconds per compile where tcc costs
milliseconds, and every one-shot corpus cell would pay it once.

A note on attribution: a first attempt at this knob landed in an
untracked `backends-sh-fb0/` copy of the crate (relative edit paths
resolve to the caller's workspace root, which was that tree), and its
first A/B arm (`BASH_O4_CC=cc` without the working knob) was gcc at
-O0 — a tcc-vs--O0 comparison that reads like a wash and is NOT an
-O2 result. The numbers above are from the rebuilt real-tree driver
with the knob verified end-to-end (distinct text sizes and `.comment`
sections per flag set in one cache root).

## Unreleased — dynamic string-array reads render inline: `_sh_arr_get` call gone (demo CPU −8% paired, byte-identical output)

- **C renderer (c_backend `array_index_read`)**: a string array with a
  dynamic key (`${RBTEX_R[$ti]}`) rendered as a
  `_sh_arr_get(id, id_len, k)` CALL; the static-key path and the
  int-homed path both already rendered an inline bounds/NULL check.
  The dynamic path now emits the same thing the helper did, spelled
  out — `(kt >= 0 && kt < (long long)id_len && id[kt]) ? id[kt] : ""`
  with the key bound to a temp so it drives guard and index once — in
  the helper's own short-circuit order (empty array never reaches the
  index; NULL element renders `""`). The C toolchain in front of a
  render inlines nothing (tcc, cc at -O0), so every call survived to
  runtime.
- **Why (fresh profile of the current pipeline's demo, 199 Hz samples,
  offline symbolization via setarch -R + addr2line — perf cannot
  symbolize this box's binaries)**: `_sh_arr_get` self time was
  **13.5% of all game CPU**, almost all of it MIMEcroft's software
  rasterizer paying it four times per textured pixel (the RBTEX_*
  channel fetches) through 36 static sites. After the change the same
  profile shows `_sh_arr_get` at **0.00%**, with the bounds branches
  visibly absorbed by `rb_tex_sample` (+6.5 pts); the rest of the
  redistribution is code-layout noise (an untouched function moving
  ±3 pts is the tell).
- **Measured (three counterbalanced `--demo` perf-stat pairs, same
  binary pair, identical Score 230 / frames=1200 / byte-identical
  `--first-frame` PPM)**: CPU-time C vs B = −13.5%, −8.0%, −2.7%
  (pair order B→C, C→B, B→C) — every pair same direction, mean ≈ −8%,
  min-of-runs −13%. The spread is the box: harness workers were
  running, and the unmodified binary itself drifted 137→147 s across
  runs. Wall clock does NOT show the win (the demo's sleep/idle phases
  track wall); CPU-time is the metric.
- **Render diff is exactly this change**: after normalizing temp
  names, old vs new `prog.c` differs in 160 statement fragments — 33
  `_sh_arr_get` call→inline substitutions plus their `_akN` key-temp
  bindings; everything else was temp renumbering. First frame is
  byte-identical; demo gameplay identical (same score, same frames).
- Tests: `index_read_renders_arr_get` → `index_read_renders_inline_bounds_check`
  (asserts the inline bounds shape and the ABSENCE of the call — same
  TODO guard kept). Note: 9 other `c_backend` tests were already
  failing in the working tree BEFORE this change (bigint/mpz, rc, sorted-join
  family — reproduced with the emission reverted, byte-for-byte the
  same set); they are not this change's.
- Follow-ups this points at: the same profiling shows `_sh_sset` at
  ~21% (two string-global copies per pixel for rb_frag's argument
  globals) and the per-pixel `snprintf`→`rb_mkhex`→`rb_putrun` pixel→
  string protocol at ~15% — the former wants a string-assignment
  inlining or numeric re-homing of `rbp_ftx`/`rbp_fdam`, the latter is
  the game's own display protocol and is load-bearing.

## Unreleased — fb0 device hot paths: divide strength-reduction + hoisting (measured NEUTRAL under tcc; kept, exact)

- **`runtime/fbdev.c` hot-path round** (the C the generated render links
  against; embedded into the driver via `include_str!`, so every build
  since 2026-10-23 19:33 carries it):
  - *Exact divide strength-reduction* in the fragment program
    (`s_div1000`/`s_div100`/`s_div_nonneg`): a constant divide becomes a
    multiply-shift when the operand range is proved (unsigned guard +
    the original expression as fallback, so an out-of-range operand
    gets the old value, not a new rounding rule). `/128`,`/4`,`/256`
    on a non-negative operand are shifts; signed blends keep the
    divide (trunc-toward-zero is not floor).
  - *`tri_shaded` invariants hoisted* per triangle (mask pointer/state,
    fb-map branch, faceid verdict, row index) and the three
    `tri_covers` edge tests inlined byte-for-byte; `put_px`/`tri_covers`
    kept as `__attribute__((unused))` reference forms.
  - *`faceid_on_p()`* — the env-latched verdict resolved once per
    primitive instead of once per pixel.
  - *`ov_composite` fused to one pass* over the surface (persistent
    layer, then flash, then the flash-alpha clear, per pixel); the old
    form walked w*h twice for a layer that is transparent almost
    everywhere. Semantics preserved exactly, including `a==0`
    skipping the clear (a no-op write).
- **Exactness** (this is what the round rests on; the perf claim does
  not stand on its own): fbdev suite 48/48 under cc AND tcc including
  the 112-case silhouette oracle; a device microbenchmark
  (`/tmp/mcab/bench_dev.c`, `bench_heavy.c` — CPU-time phases,
  checksums, P6 frame dumps) with baseline/optimized builds
  byte-identical on every frame and every phase checksum (frag,
  blocks, composite); the game's `--first-frame` PPM byte-identical
  between a driver built with the baseline device and one built with
  the optimized device.
- **Measured: NEUTRAL under tcc** (this box, 2026-10-23). Microbench
  frag phase 518–603ms (baseline) vs 555–602ms (optimized); heavy
  blocks phase 533–601ms vs 555–642ms — overlapping, no resolvable
  effect. Game `--demo` (1200 frames): wall 154.5/152.6s baseline vs
  140.6/153.6s optimized (one fast pair, one flat pair — the box was
  running the harness workers, wall spread ±10%), `perf stat` CPU-time
  −2.6%, instructions identical (WSL perf counters look derived —
  cycles ≈ task-clock × 2.04GHz — so treat them as CPU-time too).
  Overlay phase ~1.5% faster (the fused composite pass). Verdict: no
  measurable scene win under tcc; the multiply-shift helpers do not
  beat tcc's own division lowering, and call removal did not move the
  per-pixel cost. Kept because they are proven exact and the fused
  composite is a real simplification — NOT as a claimed speedup.
- **New regression lock**: `t_overlay`'s partial-alpha flash check —
  `draw_flash` writes the muzzle glow at alpha 0.45, and every prior
  flash check used a record with no alpha field (which defaults to
  255), so the partial-alpha composite path had ZERO coverage: a flash
  loop that cleared a partial-alpha flash WITHOUT blending it (the
  exact bug class a fumbled edit produces) passes everything else in
  the suite. The check locks the layer's write-time source-over
  storage rule too (green at a=128 lands as 128 in the layer, so the
  frame is (127,64,0) over opaque red, not (127,128,0)).
- **Baseline archaeology, recorded because it cost a night**: the
  baseline was reconstructed by reverse-editing and got the flash loop
  wrong (dropped the `else`), which showed up as a 19,481-pixel frame
  diff in the composite phase of the microbench. The TRUE pre-round
  source was recovered byte-exact from the 19:33 driver binary's
  embedded `include_str!` copy of `fbdev.c` (string-scan between the
  file header and its final `fclose` tail). Any future A/B against an
  uncommitted device state should extract the embedded copy from a
  driver built in that state rather than reverse-editing by hand.

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
