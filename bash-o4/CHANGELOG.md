# `-O4` driver changelog

Covers the whole `-O4` driver family — `bash-O4` and `python-O4` are two front
ends over one pipeline (`ShIR` → C via tcc, or → PTX via the CUDA candidacy),
sharing one flag surface (`bash-o4/src/flags.rs`) and one dispatch vehicle
(`bash_o4::cu_run`).

## Unreleased — the fb0 HUD re-draws its static base every frame (parts of the HUD stopped disappearing after frame 1)

The simple framebuffer has no retained HUD layer: `render_frame` opens with
`rb_clear`, which wipes every pixel before the world is repainted, so the
static base — the SCORE/HP/ART/FPS/LIC labels, the instructions line, the
radar base and the gun — has to be re-emitted on every presented frame.
`draw_hud_canvas` still gated it on `hud_static_dirty` (the rule for a device
that keeps a persistent layer between swaps), so frame 1 was complete and
every later frame carried only the dynamic parts (digits, mime blips,
labels) — the "parts of the HUD disappearing" symptom.

Proof, same build and same frame cadence, only the gate restored: frames 2-4
of the gated build hash `ae92eced…`, while the fixed build's frames 1-4 all
hash `965f7b3d…` — the frame-1/oracle image, HUD intact. Cost: the rebuild is
13 ms/frame at 320x240 under `cc -O1` (hudb, 7% of the frame in the RAM
build). With the base now re-drawn every frame, `MINIMAP_MODE=0` also skips
the MAP_W*MAP_D radar scan it used to run and throw away (the default).

## Unreleased - the fb0 surface is configurable (DISPLAY ladder, `--view WxH`, `$FB0_GEOM`; default frame byte-identical)

The simple framebuffer was pinned to 320x240 while the WebGL build re-shaped
its canvas on demand, so every "same game, same moment" comparison was a
resample and every resolution question was a code edit. The port now resolves
its surface the way the browser does — **the canvas is the truth**:
`$FB0_GEOM=WxH` (the variable `--publish-fb0` sizes the node with) first, then
`--view WxH`, then the JS DISPLAY ladder (568x320 … 2560x1440), then the
measured default 320x240. The settings menu's DISPLAY row now really re-sizes:
`rb_resize` moves RFBW/RFBH, re-opens the row store and refreshes the fragment
view, so the rasterizer, the presented frame and the PPM header move together
instead of the row only relabelling the canvas.

Two hard ceilings are enforced rather than discovered: 1024 rows (the
`RFB_ROWS` store's capacity) and 4 digits per side (`disp_w`/`disp_h` are
5-byte strings on the C path). An impossible `$FB0_GEOM` is refused with a
message and the default is used — never half-adopted.

`rb_present`/`rb_dump_ppm` chunk by surface now: a fixed 16-row echo is
102 KB at 800 wide, past the ~100 KB redirect ceiling the runtime drops
silently while reporting success, so chunks stay ≤64 KB at any width.

Also: `tools/fbview.py --size WxH` (default `$FB0_GEOM`, else 320x240),
`play.sh --size WxH` sizes the temp frame file, the viewer and the game
together, and `src/sh/rb-raster.sh` carries the same `rb_resize`/chunking for
the standalone rasterizer.

The CLI now parses its flags in **any order** (`--view 800x600
--first-frame f.ppm` used to silently never exit, because each flag was
tested against `$1` only): one `shift` loop consumes the whole list, and
`shift` is the one positional mechanism the C path implements faithfully.
`$#` and an array built from positional params both mis-compile, so the loop
is bounded and stops on the first empty slot.

Default run unchanged: `--first-frame` at 320x240 is still md5
`965f7b3dad4cfd516ff637c8943681bc` / 230,415 B — byte-identical to the bash
oracle frame.

## Unreleased - arr-load-fwd reaches the row splice: the scalar copy disappears and the fused store writes its own cell (C; MIMEcroft first-frame -16.37% instructions vs both seams off; frame byte-exact vs bash)

The `arr-load-fwd` fold (a single-def element load `v=${T[$k]}`
folded into its later reads, so the scalar copy never materialises)
stopped three statements short of MIMEcroft's hottest site:
`rbp_row=${RFB_ROWS[$rbp_y]}` still materialised a copy, and the row
splice behind it (str-splice-fold's fused store) still rebuilt every
run through two `_sh_substr` temps, a join and `_sh_arr_set`
(realloc + xstrdup per pixel run). Three core defects kept the
forward from reaching it, found by instrumenting the span with the
new `SH2_ARR_LOAD_FWD_DEBUG=1` seam (candidate / kv / refuses / FOLD
trace):

- **`expr_refuses` never consulted `READ_ONLY_CALLS`.** `param` /
  `getVar` / `arrayIndex` fell to the catch-all refuse, so a span
  broke at the first sibling element read - exactly the idiom the
  module doc exists for (`gh=${RBHEX[$g]}` sits between the `bh` def
  and the `bh` read). The read-only call arm now answers those names
  first; a `cw` entry (a program definition shadowing the builtin)
  still wins the verdict.
- **The fwd loop consulted the refusal verdict inverted.**
  `stmt_inert` returns TRUE for "refuses" (its arms and doc always
  said so); the loop broke on `!stmt_inert`: it CROSSED refusals and
  STOPPED at provably inert statements, so every site that fired
  before did so by accident, over refusals. Renamed
  `stmt_refuses`; the loop now breaks on `writes_key || refuses`.
- **The folded read wore a spelling the node codec rejects.**
  `fold_expr` built `IrExpr::Index`, but StrSplice operands cross
  `shir_nodes::enc`, which maps `Index` to `Other` and fails decode
  (`unknown expr encoding`): the render crashed. The rewrite now
  emits `element_load()`: the def's own
  `Call { "arrayIndex", [Str(arr), key] }` lowering of `${arr[$k]}`.

C side (the only backend that fuses this store):

- `try_splice_arr_store` accepts the call spelling as `row_alias`
  (same verdict as `Index`), so the capacity-guarded store emits
  `if (_row == _slot)` and, when the splice rewrites the very cell
  it reads, skips the prefix memmove entirely;
- `ext_value_c` StrSplice value fallback normalises the call
  spelling onto the fresh-vbuf `Index` arm instead of TODO-ing `""`;
- the captured plain body validation pins the STORE shape (exactly
  one `_sh_arr_set({id}`, the final line; no `_sh_assoc_set`, no
  int-slot write) instead of rejecting every `{id}[` mention: the
  value setup legitimately READS the table now (the folded base),
  and a read is not routing;
- test-side `expr_reads` learns the call spellings, so the pins no
  longer read a folded `arrayIndex` as a possible read of the
  scalar.

Net effect on MIMEcroft: five scalar copies (`rbm_bh/gh/rh`,
`rbp_row`, `tbd_name`) no longer exist, `um_a`/`um_b` read their
int tables inline, and `rb_putrun` writes the row cell in place;
the normalized ON/OFF render diff is 55 lines (the rest of the
3.5 k-line delta is temp renumbering). This is generic shIR to shIR
(the pass is backend-neutral; every renderer consuming the folded
IR gets the copy-elimination) with one C-specific complement (the
in-place identity-guarded store arm).

Measured on `MIMEcroft_fb.sh --first-frame`, 7 interleaved runs per
arm under `perf stat -e instructions:u`, medians, one build: ON
2 378 033 773; arr-load-fwd seam alone (`SH2_NO_ARR_LOAD_FWD=1`)
2 615 170 880; both seams off (`SH2_NO_ARR_LOAD_FWD=1
SH2_NO_SPLICE=1`) 2 843 473 285: **-16.37% vs both seams off and
-9.07% vs the seam-alone arm** (spread <= 0.005%; absolute baselines
are not comparable with earlier entries - same caveat as the
RENDERER_REV 18 round: this is an ON-vs-OFF delta inside one build
of the current tree). Frame md5-identical bash == ON == OFF on a
LIVE bash-oracle rerun (`53d9cfa7`, 230 415 B), stdout identical
but for the `#stats` lines and one bash-only shell-error line.
Gates: `./fail` 563/563; `harness/c-gate-run.sh` with an
otranspilerl-cli wrapper 531/651 both arms with ZERO verdict
differences ON vs OFF; `transform_laws` green and all 9
`arr_load_fwd` unit tests pass; the 49 remaining `cargo test --lib`
failures reproduce at a HEAD baseline and under the seam-off run
(none sits in a file this round touches). New seam:
`SH2_ARR_LOAD_FWD_DEBUG=1`.

## Unreleased — direct string concat + the itoa conversion: value fill, fused accumulator append and num_temp stop round-tripping through snprintf (C; MIMEcroft first-frame −17.64% instructions, demo −15.4% per frame)

`RENDERER_REV` 17 → 18: three C-backend render arms, both gated
(`SH2_NO_CONCAT` / `SH2_NO_ITOA`, folded into `render_env_key` AND
cli.rs's opts key, so an arm-on render can never be served for an
arm-off one):

- **value-context fill (a)** — an all-text `Interpolate` in value
  context fills its vbuf by capture + per-part `strlen` + `memcpy`
  instead of the `snprintf` grow loop: no format parse, no second
  strlen per part.
- **fused self-append (b)** — the accumulator growth arm FUSES with
  its materialize: the segment's parts are captured once, the
  accumulator is sized from the summed part lengths, and the bytes are
  copied straight in (three copies + a format parse + a second strlen
  per append, gone). It refuses a seg part that MENTIONS the
  accumulator — its pointer must not survive the realloc, and only the
  materialize path evaluates parts before the grow — and both arms
  keep any fmt carrying a non-`%s` conversion.
- **`num_temp` itoa (c)** — the per-value `snprintf(_sN, "%lld", …)`
  becomes the hand-rolled `_sh_ll2s`, byte-identical for every
  `long long` including `LLONG_MIN`.

On MIMEcroft the itoa arm alone rewrites 221 int→text sites
(`_sh_ll2s` 221 / `snprintf(_s…)` 1 in the ON render vs 0 / 221 in
the OFF render).

Not a shared rewrite, and not shapeable into one: what these arms
delete is the cost of C's own `snprintf` round trip against a
`realloc`-ing `_sh_vbuf`. Rust's `String`, Perl's SV concat and
Java's `StringBuilder` never take that path, so there is no
shIR→shIR fact another backend could consume. The eligibility facts
(all-text value context; does the accumulator get re-mentioned) are
read at render time inside `c_backend` — no new node, no new shared
pass, and no other backend's output moves.

Measured on the workspace's `MIMEcroft_fb.sh` (both arms built by the
same driver link line, fb0 path): `--first-frame` 3.438 B → 2.831 B
instructions (**−17.64%**, 7 interleaved runs/arm, `perf stat -e
instructions:u`, median, spread ≈0.001%); `--demo` (6 runs/arm,
wall-paced) instructions per FRAME 140.1 M → 118.6 M (**−15.4%**,
median — demo totals track the wall-paced frame count, 151–166 OFF /
166–179 ON, so they are paired per-frame, never per-run). Absolute
baselines are not comparable with earlier entries: the shared
`sh2perl` submodule and the link line both moved after `RENDERER_REV`
17 was recorded, so this round's number is an ON-vs-OFF delta inside
one build of the current tree.

Frame byte-identical bash == ON == OFF on a LIVE bash-oracle rerun
(md5 `53d9cfa7`, 230,415 B); stdout identical but for the `#stats`
timing lines. Corpus gate `c-gate-repro` ON == OFF: **527/651 PASS in
both arms with byte-identical PASS / compile / stub / stdout / rc
lists**. `sh2perl` `cargo test --lib` 1788/46/5 and `bash-o4` 95/3
(23:38 snapshot): the 46 = the 43-red baseline + 3 that belong to the
submodule's concurrent store-bound/assoc work — two of them are tests
that exist only in its still-uncommitted `shir.rs` diff — and none
sit in a file this round touches; the 3 `bash-o4` reds are
`candidacy::tests::brace_range_loop_is_candidate`,
`candidacy::tests::veto_reasons_cover_doc_shapes` and
`cu_candidacy::seq_tests::collatz_is_seq_candidate`, and they reproduce
unchanged in the `master` worktree carrying none of this round's edits
(`src/candidacy.rs` is unmodified here and reads no `SH2_*` env).
New `sh2perl/tests/c_direct_cat.rs` 1/1 green.

## Unreleased — case-lowering first-char bucketing: the 256-arm hex decode stops scanning (C; MIMEcroft first-frame −1.86% instructions, demo −0.38% per workload)

case-lowering now re-groups a LONG all-exact dispatch chain into an
outer `strHasPrefix(subject, c)` dispatch — the shared primitive the
`lit*` arm already emits, rendered natively by every accepting backend
(C `strncmp`, rust `.starts_with`, perl's affix preamble, java
`startsWith`) — plus one inner chain per first-char bucket, clauses in
original order (first-match) and the original `*` else replicated
into every fall-through. Buckets are disjoint on the first char, so a
subject that enters its bucket and matches nothing there matched
nothing anywhere: the fall-through is exactly the flat chain's, at
every nesting level. Pure shIR (no new node, no backend arm) — every
code-generating backend that runs case-lowering gets it.

Refuse > guess (the chain stays flat): any clause that is not a pure
exact-literal clause (affix/glob condition, empty literal,
alternatives spanning first chars), fewer than 16 clauses, a worst
case that would not at least halve (`k + bmax > n/2` —
glyph_index's single-character alphabet qualifies for nothing and
stays flat), an else body over 8 statements (it clones per bucket),
or `SH2_NO_CASE_BUCKET=1` (folded into `render_env_key` AND cli.rs's
opts key, so the two arms can never share a cache entry).

On MIMEcroft exactly one chain qualifies: rb_h2d, the 256-arm
hex-pair decode behind rb_o_blend's three calls per blended pixel —
render delta +64 lines (the 16 guards), replacing up to 256
strcmp-arm evaluations + `_sh_rc` stores with 16 prefix guards plus
one ≤16-arm bucket (~128 avg → ~24 comparisons per lookup). The
full corpus never reaches the threshold: 651 SAME / 0 DIFF.

`RENDERER_REV` 16 → 17. Measured: `--first-frame` 3.279 B → 3.218 B
(**−1.86%**, median of 7 interleaved runs/arm, `perf stat -e
instructions:u`, spread ±0.001%); `--demo` (3 runs/arm,
wall-paced) workload-matched pairs 16.341 B → 16.277 B and
17.938 B → 17.872 B (**−0.39% / −0.37%** — demo totals are
deterministic per workload level, frame counts 127–136 wall-paced).
Frames byte-identical bash == ON == OFF (live bash oracle rerun, md5
`53d9cfa7`, 230,415 B); `c_gate_main` 599/45/7 BOTH arms with
byte-identical FAIL sets (45 lines); corpus render delta 651 SAME /
0 DIFF; `cargo test --lib` 1773/43/5 — the same 43-red baseline,
plus 5 new bucketing tests green.

## Unreleased — value_ll's split arm: int-position args stop round-tripping through snprintf+atoll (C; MIMEcroft first-frame −34.4% instructions, demo −39.3% per frame)

The lifted native call renders a proven-int position with `value_ll`,
whose fallback was `atoll(value_c(e))`: for the arg shape every
unquoted word actually has — `split(getVar("x"))`, 414 of MIMEcroft's
444 int-arg sites — that materialized the value as TEXT (a `static
char _sN[32]` + `snprintf("%lld", …)` per int-homed var) and parsed it
straight back with `atoll` at the call. `value_c`'s value-context
split arm already drops the split entirely (split only matters when
the word feeds a child shell, where the command-position arm
re-exports it to a fresh temp; and `atoll` stops at the first
word-break byte anyway), so `value_ll` now recurses through the
wrapper and returns the numeric value directly — byte-identical
semantics by construction (numstr's `split` arm is what proved the
position int in the first place; the two are one unit).

Deliberately **not** a shared shIR rewrite: the split marker is
semantic for the child-shell path and for the backends that really
split at runtime (rust/perl/java all render it), so only this
C-int-ABI conversion may ignore it — the C-specific arm the shared
analysis licenses. Program-wide, `snprintf(_sN)` 694 → 284 and
`atoll((char*)(_sN))` 210 → 4 (the four left are array-literal inits,
a different class); `SH2_DEBUG_VLL=1` prints whatever still reaches
the fallback.

`RENDERER_REV` 15 → 16. Measured (7 interleaved runs/arm, `perf stat
-e instructions:u`): `--first-frame` 4.741 B → 3.110 B (**−34.4%**,
spread <0.001%; cumulative **−57.5%** vs the pre-copy-closure build);
`--demo` (3 runs/arm, wall-paced ~10 s window) 262.9 M → 159.5 M
instructions per FRAME (**−39.3%**; cumulative **−66.3%**), 226–227
frames now fit where the arm-less build fit 182–196. Frame
byte-identical bash == ARM == no-ARM (230,415 B); stdout identical;
`c_gate_main` 599/45/7 BOTH arms with byte-identical FAIL sets; the
`cargo test --lib` red count moved 43 → 44 only because a concurrent
worker's `shir.rs` edit broke `positional_lift_tests::`
`lifted_call_status_and_return_signal_boundary` — verified failing
WITH and WITHOUT this arm (JS-lowering test; this change cannot
reach it).

## Unreleased — numstr copy-closure: copy/swap pass-throughs seed as Int, rb_tri's corners home to `long long` (C; MIMEcroft first-frame −35.2% instructions, demo −44.8% per frame)

The shared `shir_passes::numstr` seed grows in two phases: a grounded
least fixpoint, then an anchored coinduction whose candidates were vars
carrying at least one ANCHOR (an assign int-valued under the grounded
sets alone). A pure pass-through has no anchor of its own —
`rbt_t=$rbt_x1` in MIMEcroft's `rb_tri` is only ever copied from other
vars — and without `t` in the candidate set the anchored cycle around
it collapsed in the removal loop: x2's copy of the unseeded `t` failed
first, then x1's copy of x2 followed. Every rb_tri/rb_face corner
coordinate consequently stayed `char*`, paying `atoll` on each read,
`snprintf` on each write and a three-string swap chain per winding
flip, on every triangle of every frame.

Phase 2b admits any var whose every assign is int-valued while
GRANTING the candidates int, grown least-fixpoint-style FROM the
anchored set: a var only enters when its reads already resolve, so a
purely text cycle (`w=$x; x=$w` with no producer anywhere) never
enters round 1 — grounding still comes from the anchors — and the
existing removal loop re-validates every candidate afterwards, so
cupport that collapses still takes its dependents down with it. Pure
shIR-side change (the C ingest consumes the verdict); seeded vars
188 → 227, rbt_x1/x2/t/minx/maxx/s1 homed to `long long` (87 fewer
`atoll`, 31 fewer `snprintf` sites in the render), and env-blocked
text (`rbt_v`) is still refused.

`RENDERER_REV` 14 → 15. Measured (7 interleaved runs/arm,
`perf stat -e instructions:u`): `--first-frame` 7.315 B → 4.741 B
(**−35.2%**, run-to-run spread <0.001%); `--demo` (3 runs/arm,
wall-paced ~10 s window) 473.6 M → 261.5 M instructions per FRAME
(**−44.8%**), 67–74 → 51–53 ms/frame, 152 → 196 frames per window.
Frames byte-identical bash == ON == OFF (230,415 B); stdout ON == OFF
exactly, ON == bash modulo one pre-existing bash-only `mlabel`
stderr line (present in OFF too — not this change); `c_gate_main`
599/45/7 BOTH arms with byte-identical FAIL sets; `cargo test --lib`
43 reds = exact baseline (established by stripping the hunk and
re-running: 43 both ways). No new env switch: `PIPELINE_REV` already
separates the arms, and the A/B above was a source strip.

## Unreleased — str-splice-fold: one node + one in-place store for the rasterizer's row splice (C; MIMEcroft first-frame −6.9% instructions)

`rb_putrun`'s per-pixel row rebuild `${rbp_row:0:$o}$rb_run${rbp_row:$k}`
used to render as 2 substring temps + an snprintf join + an array-store
copy — four passes over a 2560-byte framebuffer row per run. The new
shared shIR transform **str-splice-fold** (target-gated to C; the PLAN §11
offer) folds it to a single `StrSplice` node whose meaning is exactly the
concat it replaced, and the C backend's capacity-guarded fused element
store writes the result straight into the destination slot's own buffer
when it fits (strnlen capacity check, three memmoves); the `else` branch
is the old path verbatim, and value-position sites reconstruct the
original Interpolate byte-for-byte from the node's fields.

The fold's node also had to join `chop_operands`' whitelist: the three
lift/bare-call scanners (`lift_scan_expr`, `scan_void_uses`, `walk_expr`)
refuse **program-wide** on an unknown Ext tag (`bad` voids the whole lift
map), so a single splice store somewhere silently pushed all 130 lifted
MIMEcroft functions back onto the argv transport (+36% instructions —
the first A/B measured that integration bug, not the fold). Whitelisted
(`FieldStripEnd` precedent — same failure class already documented
there) and pinned by `str_splice_node_keeps_void_lift`.

`SH2_NO_SPLICE=1` disables the fold and the fused store (it is in
`render_env_key`, so both arms key the artifact cache separately);
`RENDERER_REV` 13 → 14. Measured, 5 interleaved runs per arm (median):
`--first-frame` instructions 4.035 B → 3.758 B (**−6.9%**); after
temp-renumbering is normalized the rendered C differs only at the fused
site, and frames are byte-identical ON/OFF vs the bash oracle.

## Unreleased — fb0 runtime hot paths: fract fast path, divide inlines, present-hoist (bit-exact; demo −2.5…−3.6% instructions)

A fresh symbolized profile of the CURRENT pipeline (60 s `--demo`, cc
-O0 -g, setarch -R + offline addr2line — 4,747 in-binary samples) shows
the shape has moved: **the `rb_*` software rasterizer is no longer in the
rendered C at all** (0 references; the work now lives in the fb0 device
runtime), the transpiled program itself is ≈1% of CPU, and the runtime
is everything:

| symbol | share | where |
|---|---|---|
| `tri_shaded` | 51.3% | `runtime/fbdev.c` |
| `frag_sample` | 14.9% | `runtime/fbdev.c` |
| `fbwin_present` | 8.4% | `runtime/fbwin.c` (WSLg window) |
| `frag_pixel` | 8.3% | `runtime/fbdev.c` |
| `s_div1000`+`s_div_nonneg` | 8.7% | `runtime/fbdev.c` |
| `_sh_sset` | 0.2% | rendered C (was 16.8% under the old shape) |

`tri_shaded` is at its documented ceiling (the hoists and tri_covers
inlining are already in; the incremental edge walk and the `area`
divides are deliberately NOT done — the silhouette oracle exists to
catch their 1-ulp flips), so this round takes the three sites that still
pay per-pixel call/branch/reload costs on an unoptimized build. All
three are **bit-exact by construction** — each inline is the helper's
own body with the same operands in the same order, each hoist only
removes re-reads of values that cannot change mid-frame:

- **`frag_sample` `[0,1)` fast path** (`fbdev.c`): for u,v in [0,1)
  (the barycentric uv of an interior texel) the fract fixup is
  `x - (double)(long)x == x - 0.0` with the sign branch never firing,
  so skipping it computes the very same `iu/iv`; anything outside
  [0,1) takes the original path unchanged.
- **`s_div1000`/`s_div_nonneg` inlined into their hot callers**
  (`frag_pixel`, `frag_vignette`): byte-for-byte the helpers' guard,
  multiply-shift and fallback, with the argument bound to a temp once —
  exactly what the call bound it to. The helpers stay as reference
  forms (`s_div1000` gets the `__attribute__((unused))` block
  `put_px`/`tri_covers` already carry; `s_div_nonneg`/`s_div100` keep
  their remaining live callers).
- **`fbwin_present` loop-invariant hoist** (`fbwin.c`): `X_rsh/X_gsh/
  X_bsh`, `X_msb` and `bps` belong to the XImage created at open and
  cannot change mid-frame, but the old form re-loaded all three shifts
  and re-tested both flags per pixel; the loop is now the four fixed
  shapes (the byte-order bug history comment moved with the bps==4
  pair it documents).

Measured (16 counterbalanced, CPU-pinned `perf stat` pairs of the
100-frame demo, same rendered program, only the runtime sources
differing): **instructions 5.104 → 4.971 G (−2.5% paired mean; −3.0…
−3.6% within each gameplay band, lower in 6/8 pairs), task-clock −6.1%
paired mean / −2.7% median, lower in 7/8 pairs.** The two-band
instruction clusters (≈5.25/4.85 G old vs ≈5.06/4.71 G new) are demo
play-path variance present on both sides; wall/user time remains
unmeasurable on this shared box (the established caveat — one −531 ms
outlier pair drags the task-clock mean, hence the median).

Oracles:

- `sh2perl/runtime/fbdev-test.sh`: **all green — 48 checks, 0 failures;
  silhouette oracle 112 cases, 0 px outside the hull; coverage 0 differ**
  (the bit-exactness net these changes exist to respect), re-run on the
  FINAL source after every edit above.
- Demo stdout: `== Quit at level 1. Score 0 … == | frames=100`
  identical old vs new runtime, both arms.
- `harness/c_gate_main.sh`: **584 PASS / 59 FAIL / 7 SKIP** on a tree
  under concurrent core-workstream edit (a second run with a binary
  rebuilt 20 min later gave the identical 584/59/7 while `src/` kept
  changing). The gate links only `-lgmp -lm` + the uu runtime — it
  **compiles and links no file this round changed** (fbdev/fbwin are not
  in it; `c_backend.rs` carries zero markers of the reverted experiment,
  byte-level), and the fail class is a heap bug in the current core
  render (`free(): invalid pointer`, rc 134, in a generated program —
  e.g. `051_primes`), i.e. shIR/render domain, not this change. Last
  documented baseline for that gate is 641/4/7 (the store_ref round);
  the delta belongs to the in-flight workstream (a 67 KB
  `transforms/copy_propagation.rs` landed mid-session) and is reported
  here rather than claimed as green. `harness/c-gate-repro.sh` with a
  same-session `c_backend` build: 637/650 (3 stdout + 3 rc, all in the
  parse-heavy 062/063/064 family), 0 stub/sa/compile/render-crash.
- `fbwin-test.sh` is **blocked on this box** (environment, not the
  change): its oracle harness needs `X11/Xlib.h`, which is not
  installed; `fbwin.c` itself compiles clean under `cc -Wall -Wextra`.
- The `_sh_sset` byte-loop scan experiment (`_sh_slen`/`_sh_snlen`
  replacing the libc scan in the fast path) was built, A/B'd and
  **reverted**: instructions came out a wash (−0.1%) and user time
  +3.7% (6/8 pairs slower) — glibc's IFUNC strnlen already answers the
  short-string case well enough that a byte loop trades PLT dispatch
  for scan bytes. `c_backend.rs` is back to the exact strnlen-capped
  emission, verified byte-identical against a `SH2_NO_SSETSCAN=1`
  render of the same core (diff = only the 12 lines of then-unused
  helper defs).

Open lever, deliberately NOT taken: compiling the whole program with
`gcc -O2 -fno-strict-aliasing` (instead of tcc / the -O0 fallback)
measures **−13.1% instructions, −5.9% task-clock** on the same demo —
bigger than this round, but it changes every gate's compile latency and
needs the corpus green under it first; `compile_exe` currently passes no
`-O` to either toolchain, so the mechanism would be a `BASH_O4_CFLAGS`
passthrough (opt-in) before any default changes.

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

## Unreleased — c_backend native operand lift: −43% snprintf / −21% atoll on the MIMEcroft demo

Three render-time lifts in `sh2perl/src/c_backend.rs`, each value-preserving
by construction (`atoll(num_temp(x)) == x` for every `long long`; a
still-string operand keeps `atoll` of the exact text it rendered before):

- **`raw_num_text_native`** — a bare `$name` / `${name}` / `$((…))` in a
  numeric context reads the store directly instead of materialising the
  expansion into a buffer and parsing it back (the `${row:0:$rbp_o}` slice
  index in the fb0 game). Compound/defaulting forms stay on the old path.
- **`test_numeric_cmp`** — a numeric `test` compare (`-eq`…`-ge`) lifts each
  operand INDEPENDENTLY, so an Int-homed var is never stringified only for
  `atoll` to parse it back (`[ "$y" -ge "$RFBH" ]` runs per rasterized
  span); a fully textual compare renders exactly as before.
- **`test_value_dollar`** — `[ -f /tmp/tex-$name ]` and friends expand
  whole-`$name`/`${name}` and mixed simple-ref words through `value_c`
  instead of emitting the raw literal word (the game's texture-cache
  replay tests can now hit).

Measured on `MIMEcroft_fb.sh --demo` with LD_PRELOAD call counters, equal
frame counts (121 lift-on vs 122 off):

| metric | lift off | lift on | Δ |
|---|---|---|---|
| snprintf | 35,120,684 | 20,119,996 | **−42.7%** |
| atoll | 64,664,896 | 50,871,997 | **−21.3%** |
| strcmp | 1,026,403 | 627,553 | −38.9% |

An earlier two-build pair on the 19:21 tree agrees directionally (−29% /
−9.6% raw, −34% / −16% per frame, scene 66→52 ms/frame, wall 16.7→13.5 s).
Wall-clock is not claimable on the shared box (load 8–11 with a concurrent
interactive game); the call counts are the hard signal.

Behavior: demo stdout identical modulo the nondeterministic `#stats:`
lines; `--first-frame` PPM byte-identical (230,415 B); `harness/c_gate_main.sh`
verdicts identical with the lift on and off — 641 PASS / 4 FAIL / 7 SKIP,
the 4 failing files fail identically with `SH2_NO_NATIVE_LIFT` set (they
are concurrent core-work failures, not this change's). Corpus scope:
58/652 renders change, the other 594 are byte-identical.

The toggle is `SH2_NO_NATIVE_LIFT` (validation switch in the
`render_env_key` family in `bash-o4/src/cache.rs`, so the artifact cache
keys on it); `RENDERER_REV` 6→7.

## Unreleased — C backend: case-clause hoist + bigint constant identifiers (the MIMEcroft build blockers)

Three fixes in `sh2perl/src/c_backend.rs`, each with a validation
switch or a render-level A/B proof:

- **`case`/`select` clause assignments reach the fn-local hoist**:
  `collect_assigned_vars` had no `IrStmt::Case` arm, so a variable first
  assigned inside a clause (`case $hd_t in 2) h=2 …`) never reached the
  per-function declaration hoist and rendered as an undeclared C
  identifier — the MIMEcroft build blocker on `h`. The blanket
  `collect_vars_full` discriminant arm tried alongside it regressed
  `063_09` (a store-update header vanished) and was reverted; only the
  hoist half ships. Toggle: `SH2_CASEWALK_OFF` (in `render_env_key`,
  with `SH2_NO_NATIVE_LIFT`; `RENDERER_REV` → 8).
- **Negative bigint constant names are valid C identifiers**: the
  global mpz registry built `_bigint_<value>` verbatim, so a negative
  constant emitted `mpz_t _bigint_-42;` — a syntax error at the
  declaration. `-` now encodes as `n` in the IDENTIFIER only
  (`_bigint_n42`); `mpz_init_set_str` keeps the original value text.
- **Store-only/env vars bail out of the test-word expander**: a pure
  env var (`sm_size_old` — written by the child shell, never assigned
  in script) collects into `store` but hoists no C declaration, so the
  expander's bare-identifier read was undeclared. It now requires a
  typing verdict or a top-level hoisted declaration and falls back to
  the `_sh_env(name)` arm otherwise.

## Unreleased — play.sh 127 closed: the export leak is fixed, proven flat, game binary rebuilt

The `game exited 127 after hitting its 4096 MiB cap` the launcher
reported was the stale `target/mimecroft-fb-play` (built Oct 14, before
either leak fix) meeting the fixed-HEAD reality: the current renderer
(`sh2perl` HEAD `7c9b73b39`, carrying `d6ea96f31` export table +
`a5b871f93` heap-string ownership) emits no per-frame growth on any
path this session could probe. No renderer change in this entry — the
fix was already committed; what was missing was the artifact and the
proof.

Proven with `mallinfo2()` step probes in the emitted C (per the taste
rule: every counted line re-run before committing), same `--demo`
workload, fixed-vs-control where control is the identical emit with
`_sh_export` reverted to plain `setenv` (the exact pre-`d6ea96f31`
shape):

| build | demo heap slope | max RSS, full `--demo` |
|---|---|---|
| control (`setenv` per export) | **+23.6 KB/frame** (17.4 → 21 MB over 151 frames) | **8,476,600 KB** (stale Oct-14 binary, 102 frames — past the 4 GiB cap) |
| fixed (putenv table, current emit) | **+0.5 B/frame** over the 342-frame tail (frames 200–541: +176 B total; +8 KB over the full 541, all warmup in the first ~200) | **12,740 KB** (178 frames), stdout identical to stale except the `$FB_DUMP` path, frame-1 PPM byte-identical (230,415 B both) |

Menu path (16 idle iterations + texture harvests, headless=0): 893 KB
→ 1.14 MB at iteration 2 (texture-table warmup) → flat ±64 B, one
+34 KB step at iteration 12 (second harvest landing), then flat. No
unbounded class on any probed path; the menu zombies (`tex_bg_submit`
never `waitpid`'d) remain, as documented, a separate defect with no
heap growth attributed.

Miniature of the cap-hit (growing-value export loop, 3000 iterations):
control max RSS **138,748 KB** vs fixed **5,368 KB**, outputs
byte-identical; under a 64 MiB `ulimit -v` the control exits **127**
and the fixed build completes rc 0 — the exact play.sh signature,
now with the sides assigned.

Also verified: fresh `game.c` carries exactly one `setenv` (the 64+-
name fallback) and one `putenv` — no remaining per-frame export path;
free-before-store / free-before-re-literal shapes intact throughout.
Targeted parity at the committed renderer (Oct-16 `otranspilerl-cli`,
pre-dirty-tree): `009`/`028`/`062_14`/`array-subscript` arrays +
`064_20` env + `045` perl-call **6/6 PASS** vs bash. (The live driver
binary currently fails those array emits with `arr_len undeclared` —
that is the parallel session's uncommitted int-homing work in the
dirty sh2perl tree, mid-flight at the time of writing, not this entry
and not HEAD.)

Changed here: rebuilt `target/mimecroft-fb-play` with the current
driver (gitignored artifact — the player was running the leaky
binary because the source predates it, so `play.sh` auto mode never
rebuilt); `play.sh` 127 text no longer blames the fixed residual
(the cap stays as defense-in-depth, and a 127 now means something
new — file the growth shape).

## Unreleased — shared `split_fold` pass + native-int store arms (MIMEcroft C: −46% `atoll`, −48% `snprintf`)

The remaining text round trips on MIMEcroft's frame path were `split[e]` in
NUMERIC position (word-split result stringified and re-parsed) plus the
`snprintf`/`atoll` conversions at integer call and store sites. Three
layered changes, one shared and two C-side:

- **`sh2perl/src/shir_passes/split_fold.rs` (shared, offered to all
  backends).** `split[e]` → `e` when `e` is provably free of IFS
  whitespace: the `analyze_var_nospace` per-var fixpoint or the A2 `Int`
  verdict (canonical decimal text), with literals/arith/templates/`${#x}`
  whitespace-free by shape; never when the program may set a CUSTOM IFS
  (`program_may_custom_ifs`). That is a fact about shell semantics, so
  every renderer inherits the fold; the ESTree render-time fold becomes
  redundant (stays harmlessly idempotent). A split in ARRAY-ELEMENT
  position (`setArray`/`setArrayAppend` values, array-literal declares,
  indexed-assign RHS) folds only when the target array is already
  A2-`Int`-homed: the rewrite is value-preserving either way, but it
  removes the string-store evidence the C ingest homes arrays on, and
  the flip to `long long*` crashes the string-array-only slice path
  (found the hard way — `051_primes` died at `${primes[@]:0:10}`;
  2 tests pin both sides of the carve-out). Wired at the O3/O4
  pre-render stage next to `loop_opt`/`int_cycles`;
  `$SH2_NO_SPLIT_FOLD=1` disables pass + arms (the A/B and rollback
  switch).
- **C backend: split-strip in the native-int paths.** `value_ll` and
  `store_int_item_c` now see through a `split[...]` wrapper to the inner
  expression (`expr_as_num`), so numeric reads and indexed stores reach
  the native `long long` form instead of `atoll(sh_split_word(...))`.
  Two new tests (scalar read, array-indexed store).
- **Artifact cache key: include the `SH2_NO_*` validation switches.**
  The `--emit-c` cache key (`opt=… t64 gpu=…`) ignored them, so a gated
  A/B run was a cache hit on the other side and the feature appeared
  dead (it cost a 54 KB emission delta to discover); the key now folds
  every `SH2_NO_*` env switch in (worktree-local).

Measured on MIMEcroft (`MIMEcroft_fb.sh`, deterministic 400-frame build,
same-tree A/B through the gate): `atoll` calls −45.9%, `snprintf` calls
−47.9%, wall −5.4%, emission −54 KB (1,105,261 vs 1,159,299 B). `--demo`
stdout is identical except the timing-stats lines. The first-frame PPM
differs by 4,049 bytes between the two binaries, but a layout-only
control (base C + one unused global) reproduces the exact same delta —
the runtime's paint order depends on addresses (pointer-hashed map
iteration), so cross-binary PPM equality is not a correctness
instrument; within one binary it is deterministic.

Gates (`/tmp/csweep4.sh`, feature on vs `SH2_NO_SPLIT_FOLD=1`, full
examples corpus): emit-leg rc sets identical AND JIT-run-leg rc sets
identical; `cargo test --lib` 1298/3 (the 3 are the pre-existing
strdup/GMP helper shapes; split_fold module 9/9). One harness lesson
recorded: bpaf stops option parsing at the first positional, so
`bash-O4 script.sh --emit-c` silently JIT-*runs* the program with the
flags as program args — gate invocations must put flags BEFORE the
script (that accident is how the run leg, and the `051_primes` crash,
were discovered).

## Unreleased — per-position native ABI (mixed `long long | char*` params) + dead-caller param rows

Two layered changes, one in the shared analysis and one in its C
consumption, both aimed at the remaining text round trips on MIMEcroft's
draw path:

- **numstr: a site row's CALLER liveness gates the param leg.** A
  defined fn with no observed call site never executes (the walk's
  statement-enum exhaustiveness is already assumed), so rows recorded
  FROM such a caller no longer disqualify a callee position — a dead
  helper must not poison a position every live caller passes canonically.
  The var leg is untouched (an uncalled fn's `v=$N` copies still key on
  its absent param set). 2 new tests; module 9/9.
- **C backend: `native_positions`.** `analyze_native_num_fns` also
  returns the per-position Int-typed set (equal to the shared numstr
  params verdict by construction), and a partial set now emits a MIXED
  signature — `static void rb_putrun(long long _p1, long long _p2,
  long long _p3, char *_p4)` — with per-position call-site conversion
  (`value_ll`/`value_c`) and a per-position `cur_native_pos` in the
  positional read/string paths. Bigint-param and array-return fns are
  excluded and keep their whole-fn convention; `param_copy_alias` stays
  whole-fn-gated. Previously one text position forced ALL positions
  through the stringify→atoll detour (the old all-or-nothing rule).

Measured on `MIMEcroft_fb.sh` (deterministic 400-frame A/B, one gcc -O2
each, identical patches; emitted C −1,830 bytes):

| metric (whole run) | baseline | this change |
|---|---|---|
| strtoll | 120,625,982 | 112,863,848 (**−6.4%**) |
| wall, 400 frames | 33.98 s (84 ms/f) | **31.53 s (78 ms/f, −7.2%)** |
| snprintf / snprintf_chk | 3,542,449 / 104,525,113 | flat (text-typed actuals merely move the atoll to the call site) |
| malloc / free / realloc | 147.1M / 147.1M / 4.49M | flat |

Correctness: `--first-frame` / `--first-frame-3d` PPMs byte-identical;
demo stdout byte-identical (both stock and 400-frame); gcc warning
multiset identical (line numbers aside); `harness/c_gate_main.sh`
**641/4/7** with each of the 4 failures inspected — none carries a
mixed-ABI fingerprint (pre-existing frontend/stub bugs); `c_backend`
tests **stash A/B: HEAD 157/10 vs this change 161/10, failure sets
byte-identical**; full lib 1271/18 = the documented baseline. Next
levers (recorded in PLAN): numstr payload modeling for `rb_mkhex`'s
`RBTEX_*` tables, a fractional ABI for `rb_cube`, and caller-side var
typing so `value_ll` stops paying atoll at text-actual call sites.

## Unreleased — slice splice without stabilizing copies + native numeric index (C backend)

Two provable no-ops on the row-splice path (`rb_putrun`, ~1.7M calls per
400-frame demo), both consuming verdicts the shared pipeline already
carries (Int-homed vars from A2/numstr/`demote_stringy_ints`):

- **Slice OFF/LEN `$ident` text reads the C slot directly.**
  `value_num_dollar` (which intercepted before the expansion fallback)
  and `value_num`'s Str arm now resolve a whole `$i` / `${i}` naming an
  Int-homed var (also bigint/tiered via the Var arm's verdicts) to the
  native `long long` — killing the getVar → stringify-to-temp → vbuf
  copy → `atoll` chain per index. Mixed text (`"x$i"`, unbalanced
  braces) falls through unchanged (`dollar_ref` = whole refs only).
- **The slice subject's stabilizing copy accepts the stable-store
  vocabulary.** `_sh_substr` only reads its input, so a bare ident, the
  null-guard `(id ? id : "")` store read, or `_sh_mstr_get(&id)` is
  passed in place (`stable_store_read`) — no full-row vbuf copy. The
  guard keeps unset-is-empty semantics; anything else (calls, other
  ternaries) keeps its copy.

Measured on `MIMEcroft_fb.sh` (deterministic A/B: BOTH emitted C sources
patched identically to quit at exactly 400 demo frames — the stock
`--demo` quits on wall-clock and is not frame-comparable — one
gcc -O2 build each, same-tree renderer):

| metric (whole run, all processes) | HEAD (no edits) | this change |
|---|---|---|
| snprintf | 22,164,596 | 3,542,449 (**−84%**) |
| snprintf_chk (fortified) | 123,150,494 | 104,526,435 (−15%) |
| strtoll (+`__isoc23_`) | 139,252,609 | 120,626,090 (−13%) |
| malloc / free / realloc | 359.6M / 392.9M / 4.60M | flat (copies were steady-state static-vbuf memcpys, not allocs) |
| wall time (400 frames) | 43.2 s (108 ms/f) | 37.9 s (94 ms/f) |

`rb_putrun`'s splice goes from 2 full-row subject copies + 2 index
snprintf+copy+atoll chains to
`_sh_substr(&_v909, (rbp_row ? rbp_row : ""), 0, rbp_o)` twice;
emitted C −4,437 bytes. Correctness: `--first-frame` +
`--first-frame-3d` PPMs byte-identical; gcc warning multiset identical;
demo stdout byte-identical (minus `#stats` timing lines); C corpus gate
**641/4/7 with the failure set byte-identical to a stashed-baseline run
of the same tree** (4 pre-existing); `c_backend` tests **161/10** (4 new:
`dollar_ref` shapes, `stable_store_read` vocabulary, `num_text_read`
verdicts, native-index emit) with the 10-failure set byte-identical to
baseline; full lib 1253/18 (the documented pre-existing 18).

Limit: only the C renderer consumes this. The shareable half is an
ingress transform lifting whole-`$ident` text args in text-op slots to
`Var` nodes (every backend's value path handles `Var` natively; the
parser hands them raw `Str` text today). Also still open: `rb_putrun`'s
own y/x0/n params cross the call as text (caller stringifies into the
callee's `char*` slots) — a numstr-style rule looking THROUGH
`num_temp` stringifications would close that round trip.

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

## Unreleased — uncapped arrays are vecs, not 1024-slot tables

The fixed/vec split had two mechanisms with opposite economics, and only
one of them paid. A **proven** cap is a real win — `MIME_NAMES[5]`,
`RBHEX[256]` are exact-size tables with no grower, no cap field and no
per-store capacity check. The **`ARR_CAP` fallback** for arrays whose
extent was never proven was a pessimisation: it reserved 1024 pointers of
`.bss` while still `_sh_xstrdup`-ing every element, so it saved no
allocation at all and only over-allocated the pointer table.

Measured on MIMEcroft_fb: 18,872 bytes of fixed string-array tables, of
which **16 of 18.4 KiB was the two unproven ones** (`RFB_ROWS` reserved
1024 slots for 240 rows, `lgi` 1024 for ≤12). After the change:
**10,680 bytes** (`lgi` is a vec; `RFB_ROWS` keeps its fixed table — see
below).

Uncapped arrays now take vec storage (`char **x = NULL`), growing to need.
Every use site already renders identically through the pointer, so the
only difference is how overflow is handled: `_sh_grow_str` instead of
exit-127. This collapses the split to "proven cap = fixed, everything else
= vec", which is what makes a single reset path possible.

Two shapes previously slipped past routing and fell into the fallback:

- **Unbounded fills** (`split` / `mapfile` / `read` — count known only at
  runtime). `record_bulk` left `defined` false on that path, so the array
  was never routed *and* the split/mapfile store sites emitted the fixed
  guard against a vec decl (`c=( $(...) )` still emitted `char *c[1024]`).
- **The `mapfile` store site hardcoded the `ARR_CAP` guard** while every
  other store site branches on `vec_arrays`, so a vec-routed array was
  written past a NULL pointer — a segfault on
  `012_process_substitution`.

Deliberately **not** routed:

- a **dynamic index write** (`arr[$k]=v`): sparse dynamic fills keep the
  documented fixed backstop (works up to the cap, exits 127 past it, never
  garbage). Routing those properly needs the dense-coverage proof that the
  `routed` set already collects. This is why `RFB_ROWS` stays fixed.
- an array whose name **escapes to an unknown call** (possible nameref
  aliasing): the callee would see a `char**` it did not grow. New
  `escaped` flag on the sizing `Info`.

Verified: C corpus gate **596 PASS / 652, verdicts byte-identical per file**
against a HEAD build of the same tree; `c_backend` unit tests at the
pre-existing 10-failure baseline; MIMEcroft_fb runs (`--first-frame`,
menu → game) and the `mapfile` example match bash.

### Known, not fixed here

- `RFB_ROWS` still reserves 1024 slots. It is written only through a
  runtime row index (`RFB_ROWS[$y]=`), whose store site resolves its
  capacity via `array_cap()` → `ARR_CAP`; routing such arrays needs the
  dense-coverage proof, since the sparse case must keep the backstop.

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
