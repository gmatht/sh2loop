# bash-O4 — bash → C → Vulkan

> Status: **M1, M2, M4 (fetch/cache), and the M3 scaffolding are
> implemented** (`bash-o4/` crate, `sh2perl/src/vulkan_backend.rs`,
> `harness/gpu_gate.sh`; milestones §4.9, deviations §6). GPU *dispatch*
> from generated code (the `_sh_gpu_*` host split in `c_backend.rs`)
> remains. The original design below is kept intact; §6 records what
> landed, what moved, and what is still open.
>
> Original note (pre-implementation): this doc planned the binary. The `bash-O4`
> binary does not exist; `-O4` today (`otranspilerl/src/lib.rs`) is `-O3`
> plus a `set_shaderize_enabled(true)` flag with **no C/Vulkan effect**
> (`docs/opt-levels.md`: "Autoshaderization is not implemented — `-O4`
> currently behaves as `-O3`"). This doc plans the binary, evaluates the
> codebase it would build on, lists what must be fixed first, and gives a
> detailed design for later implementation.

## 1. Executive summary

**bash-O4** is a planned ahead-of-time / just-in-time compiler for bash:

```
foo.sh  ──parse──▶ ShIR (A1/A2/A3) ──lower──▶ C ──tcc──▶ native binary
                                          │
                                          └─hot pure-compute loops──▶ Vulkan
                                             compute shaders (SPIR-V) ──┘
```

Goals:

1. **Correctness first**: byte-identical stdout/exit vs `bash` on the
   corpus gate, at every opt level (the `opt-levels.md` firewall: levels
   change bytes and cycles, never observable behavior).
2. **Fast cold start + fast steady state**: statically-linked `tcc`
   (via `libtcc`) compiles the emitted C in-process in milliseconds —
   no `gcc` dependency at runtime, single-file `bash-O4` binary.
3. **Automatic GPU offload where it wins**: pure counted arithmetic
   loops (the `051_primes.sh` / factor / isqrt / checksum shapes) are
   *autoshaderised* into Vulkan compute shaders; everything else stays
   on CPU. A cost model + runtime fallback guarantees the GPU path is
   only taken when profitable *and* correct.
4. **Zero-toolchain install**: any library needed for max performance
   (Vulkan headers/loader, shaderc/glslang for SPIR-V, `volk`, CPU
   helpers like GMP/FFTW where proven) is auto-downloaded, hash-pinned,
   and cached — reproducibly, and only with user consent.

Non-goals (v1):

- General shell-on-GPU (pipelines, forks, redirects, `eval`, external
  commands can never run on a GPU — they stay on CPU by construction).
- Beating `bash` on fork/exec-heavy scripts (the win is compute loops;
  process-spawning scripts are latency-bound on `fork+exec`, not ALU).
- A new IR or a new language: bash-O4 reuses ShIR + the C backend + the
  GLSL sketch, extended — not rewritten.

## 2. Codebase evaluation — what we have to build on

### 2.1 Strengths (reuse directly)

| Asset | Location | Why it matters for bash-O4 |
|---|---|---|
| Shell→ShIR parser + A1 contract | `sh2perl/src/shir.rs`, `shir_json*.rs`, `frontends/shir-contract/` | Proven front end; 600+ corpus programs lower to typed IR. bash-O4's stage 1 is free. |
| C backend (native lowering) | `sh2perl/src/c_backend.rs` (~35k lines), gate `harness/c_gate_main.sh` 637/644 | The CPU codegen bash-O4 compiles with tcc. Already emits fork/pipe/pipeline machinery, width-narrowed ints (`range_width_name`), fixed buffers, dead-runtime trimmer. |
| GLSL sketch | `sh2perl/src/glsl_backend.rs` (~5k lines), `sh2perl/docs/backend-glsl.md` | Proves the *shape* of shell→shader lowering (string-table model, `parse_arith` reuse, refuse-over-guess). Autoshaderise starts here. |
| Transform marketplace + bisect | `sh2perl/src/transforms/`, `bisect-transforms.pl`, PLAN §11/§30 | New GPU-prep transforms (counted-loop recovery, arith-text parse, hoisting) can be offered/accepted per backend without breaking perl/estree gates. |
| Range / width / const analyses | `analyze_var_ranges`, `choose_width`, `escape_classes`, `numeric_lift`, `PassContext` in `shir.rs` / `shir_passes/` | The shader-candidacy and width proofs ride on these verdicts. |
| `-O3` dual-loop + slot machinery | `set_dual_loops`, `set_slots_enabled`, `set_split_sets` (`otranspilerl/src/lib.rs` ~L630) | The CPU-side hot-loop versioning bash-O4 extends with a third arm (GPU). |
| Opt-level firewall + corpus gates | `sh2perl/docs/opt-levels.md`, `./fail`, `fail-estree`, `harness/c_gate_main.sh` | The correctness contract and the perf gates already exist; bash-O4 adds GPU-differential gates, not new philosophy. |
| `tcc` on dev machines | `/usr/bin/tcc` present | Prototype JIT path can be exercised today; production needs `libtcc` vendored (see §5). |

### 2.2 Gaps (what is missing or wrong for bash-O4)

1. **`-O4` is a JS-only no-op.** `opt-levels.md` honest-limits: "no
   existing support anywhere in the tree … `-O4` currently behaves as
   `-O3`". The `sh2.shaderize` runtime helper, the candidacy pass, and
   any C-target emission do not exist.
2. **GLSL backend is the wrong shader target.** It emits whole-program
   *fragment* shaders (WebGL 2 / GLSL ES 3.00, `gl_FragColor` +
   `readPixels`), not per-loop *compute* shaders. Vulkan needs GLSL
   450 compute (`layout(local_size_x=…)`, SSBOs, barriers) → SPIR-V.
   It is also a sketch: i32-only (bash is i64-wrap), ASCII-only
   strings, `void` functions, no recursion guard, no argv, `$?`→0.
   None of that is acceptable for an auto-offload that must be
   bit-exact.
3. **C backend still shells out ~2.4×/file.** `docs/BASHC_OPT.md`
   baseline: 61 `bash -c` sites over 25 files; `001_simple.sh`'s echo
   loop runs ~5× slower than bash itself. Items 3 (split-free echo)
   and 6 (sh-source numeric homing via opaque `arith("…")` text) are
   DEFERRED — exactly the loops a GPU pass would most want native.
   Shaderising a loop whose body still forks per iteration is pointless.
4. **59 known C-gate reds** (`sh2perl/docs/c-backend-limitations.md`:
   578/644 at design time; **637/644 since**). The blocking classes for bash-O4: `eval`/`source` parent
   effects (unmarshallable — must veto GPU *and* stay child-bash on
   CPU), process-substitution ordering, assoc iteration order, quoted
   brace over-expansion (core parser bug, needs a §11 offer), `$0`/tty
   environmentals.
5. **No SPIR-V toolchain in-tree.** `glslangValidator` exists on this
   dev box but is not vendored, not hashed, not called by any backend.
   No `shaderc`, no `Vulkan-Headers`, no `volk`, no loader fallback.
6. **No link/JIT step.** `otranspilerl-cli` *prints* C/JS; `shir_to_c`
   prints C. Nothing invokes a C compiler, links a binary, caches
   artifacts, or JIT-runs — bash-O4's core loop is absent.
7. **No hotness / profitability signal.** Dual-versioning "needs the
   hotness signal … one shared query point" (`opt-levels.md`) — still
   open. GPU offload without trip-count + body-cost + transfer-cost
   modeling will *lose* on every small loop (PCIe + dispatch ≫ ALU).
8. **Width ladder stops at C types.** `choose_width` lists GLSL as a
   consumer but the i64-in-two-ints pack is unimplemented; shader
   integer semantics are undecided (wrap vs saturate vs bail).

## 3. What must be fixed and improved (ordered)

**P0 — correctness blockers (fix before any GPU work):**

1. `arith("…")` text opacity (BASHC_OPT item 6): parse shell arith
   texts into structured `Arith` at lowering so range/numeric lifts
   see sh-source loop vars. Without this, `j=$(($j*$i))` stays
   `char*`+`atoll` and neither CPU-narrowing nor GPU candidacy fires.
   *Related (done):* the dual-loop **versioning** plan had the mirror
   problem — it parsed only the shell's `builtin("let", ["i<n"])`
   text, so a frontend emitting structured `Arith(Bin{<, …})` (py-sh-go)
   never versioned. `counter_reserve_loop` now accepts both shapes, so
   the -O3/-O4 hot-loop versioning is frontend-agnostic
   (`docs/PYTHON-O4.md` §2.4; pinned by
   `counter_reserve_loop_accepts_structured_cond`).
2. Split-free native echo (BASHC_OPT item 3): unify the
   `echo $i` (shell-out) and `echo "Number: $i"` (native) paths on a
   proven split-freeness verdict. Per-iteration fork must die first.
3. `eval`/`source` veto plumbing: unknown-text eval must produce a
   hard `Refuse` verdict threaded through to *both* CPU-native claims
   and GPU candidacy (never "guess"). Known-text eval inlines; unknown
   stays child-bash with a comment marker.
4. Core brace bug (`{1..3,7..9}` over-expansion): file the §11 offer
   from `c-backend-limitations.md` §6; GPU range-loop detection depends
   on correct brace/range shapes.

**P1 — CPU backend must be GPU-ready:**

5. Per-loop purity verdicts (`PassContext`): side-effect-free +
   syscall-free + no-alloc-growth proof per counted loop, reusing
   `escape_classes`, `scc.rs`, `lifetime.rs`. This is *the* gate for
   candidacy (§4.3).
6. Width-exact shader integers: implement the i64 pack (two i32s or
   `uint64_t` under Vulkan `GL_EXT_shader_explicit_arithmetic_types`
   where available, else refuse-and-stay-on-CPU). Never silently wrap
   at 32 bits.
7. Compute-shader backend: new `vulkan_backend.rs` (not a fragment
   tweak) emitting GLSL 450 compute + SSBO layout + dispatch
   descriptor, reusing `glsl_backend.rs`'s `parse_arith`/test lowering
   but replacing the string-table/output-encoding chapters (SSBO byte
   buffer + length word, no `gl_FragColor`).
8. Host/device split in `c_backend.rs`: emit `_sh_gpu_*` call sites
   (map → dispatch → readback → fallback) instead of inlining shader
   text; the shader becomes a separate SPIR-V artifact (§4.4).

**P2 — binary, toolchain, distribution:**

9. `libtcc` static link + `tcc` fallback: build `bash-O4` with vendored
   `libtcc` (submodule or `cargo` sys-crate), plus `CC`/`gcc`/`clang`
   fallback when vendoring is disabled.
10. Hash-pinned auto-download cache (`~/.cache/bash-o4/`, see §5):
    Vulkan-Headers/loader, shaderc or glslang, volk; opt-in CPU libs.
    Consent flag, offline mode, `BASH_O4_OFFLINE=1`, audit log.
11. Artifact cache + differential gates: key on (ShIR hash, opt level,
    GPU present); CPU-vs-GPU stdout/exit diff gate; perf gate with
    trip-count floor so small loops never regress.

**P3 — performance ceiling (after correctness):**

12. Shared hotness query (trip-count × body-cost − transfer-cost),
    static heuristics first, PGO later.
13. Persistent mapped buffers / loop fusion for repeated dispatches;
    multi-loop batching; CPU/GPU overlap for pipeline-adjacent loops.

## 4. Detailed design

### 4.1 The binary

```
bash-O4 [options] program.sh [-o program] [-- args...]
bash-O4 --check program.sh        # parse + candidacy report, no codegen
bash-O4 --emit-c program.sh       # print CPU C (debug)
bash-O4 --emit-shader ID program.sh  # print compute GLSL/SPIR-V disasm
```

Single static binary. Subcommands mirror `otranspilerl-cli` flags where
sensible (`--target`, `-O0/-Og/-O2/-Os/-Oz/-O3/-O4`, `--true64`), plus:

| Flag | Meaning |
|---|---|
| `-O4` (default for `bash-O4`) | `-O3` CPU opts + autoshaderise |
| `--no-gpu` / `--cpu-only` | Force CPU path (also when no Vulkan ICD present) |
| `--gpu=auto\|force\|off` | `force` = fail if no candidate dispatches (for perf tests) |
| `--fetch-libs[=ask\|auto\|off]` | Auto-download policy (default `ask`; CI uses `auto`) |
| `--cache-dir PATH` | Override `~/.cache/bash-o4` |
| `--offline` | Never touch the network; missing libs = clean error |
| `-o FILE` | Write native executable (via tcc); without `-o`, JIT-run in-process |
| `--jobs N`, `--verbose`, `--dump-shir` | Diagnostics |

Exit codes: `0` success; `1` compile/lower error; `2` usage;
`3` GPU-only failure under `--gpu=force`; `4` network/fetch refusal
(offline or hash mismatch). On any GPU dispatch failure at runtime, the
program silently takes the CPU fallback and exits with the *program's*
exit code (GPU is an optimization, never a semantic).

### 4.2 Pipeline

```
 ① parse (bash→AST→A1)          existing: shir.rs + parser/
 ② transforms::apply(target=c)  existing marketplace; +gpu-prep passes (§4.3)
 ③ analyses (A2/A3)             range/width/purity/escape/lifetime/SCC
 ④ candidacy                    NEW: per-loop verdict {CPU-only, GPU-candidate(w, cost)}
 ⑤ CPU render                   c_backend::shir_to_c + _sh_gpu_* call sites
 ⑥ shader render                NEW vulkan_backend: candidate loops → GLSL450 compute
 ⑦ SPIR-V compile               shaderc/glslang (vendored or cached; cached by hash)
 ⑧ tcc link                     libtcc in-process: C + embedded SPIR-V blobs + volk/Vulkan link
 ⑨ run (JIT) or -o (AOT)        artifact cache keyed on (ShIR,Opts,GPUCaps)
```

Stages ①–③ are shared with every backend (no fork of core logic —
toolkit-purity rule: Vulkan specifics live in the new backend +
`bash-O4` driver, never in `rustxWidgets`/shared IR). Stage ④ is a new
`shir_passes` analysis (backend-agnostic verdicts) + a Vulkan-specific
renderer accept step (render-time verdict, per the §11 marketplace:
refuse > guess). Stages ⑥–⑧ are new crates beside `otranspilerl`.

Determinism: same input + same `--cache-dir` seed ⇒ byte-identical C,
identical GLSL, identical SPIR-V (pin shaderc flags, zero timestamps,
sorted descriptor sets). The corpus gate enforces stdout/exit identity
across `-O0…-O4` and `--cpu-only` vs `--gpu=auto`.

### 4.3 Autoshaderise: candidacy rules

A loop is a GPU candidate **iff all hold** (checked in order, first
failure vetoes with a logged reason visible under `--check`):

1. **Shape**: counted `for i in {a..b}` / `for ((i=a;i<b;i+=s))` /
   `seq`-recovered range, trip count statically bounded [lo,hi] or
   guarded (dual-version entry test, reusing the `-O3` dual-loop
   guard style: `if (trips < GPU_FLOOR) goto cpu;`).
2. **Purity**: body is integer arith + locals + array/SSBO-indexed
   reads/writes only. Veto on: function calls with unknown bodies,
   `exec`/pipeline/redirect/subshell/background/capture/file tests,
   `eval`/`source`, traps, assoc arrays (order + hashing), string
   ops beyond ASCII concat/itos, recursion, `exit`/`return`-in-loop
   (unless lifted by `loop_return_lift` first).
3. **Width**: every int var/operand proven in i64 (or narrower);
   i64 lowering selected per device capability, else veto (never
   silently narrow to i32 — the GLSL-sketch footgun).
4. **Memory**: affine or data-independent indexing into flat arrays;
   no aliasing (escape verdict), no growth (`realloc` in body vetoes);
   output size bounded (OUT_CAP-style length word, checked pre-dispatch).
5. **Profitability**: `trips × body_cost > dispatch_cost +
   2×transfer_cost + margin`. Static heuristic table first (per-device
   `dispatch_cost` measured once at install, cached); PGO counters
   later. Loops under the floor stay CPU with zero GPU code emitted
   (no dead SPIR-V in the binary).

Each accepted loop gets a stable ID (`sh_loop_<fn>_<n>`), recorded in
the A3 verdicts so `--check` can report `candidate / veto(reason)`.

### 4.4 Codegen: host split + device shader

Host (C backend emits, per candidate loop):

```c
/* auto-generated at _sh_site for loop sh_loop_f_0 */
static const unsigned char _sh_spv_f_0[] = { /* SPIR-V blob */ };
static const size_t _sh_spv_f_0_len = sizeof(_sh_spv_f_0);
if (_sh_gpu usable && trips >= _SH_GPU_FLOOR_F_0) {
    rc = _sh_gpu_dispatch(&_sh_gpu_ctx, _sh_spv_f_0, _sh_spv_f_0_len,
                          /*buffers*/ in, in_n, out, &out_n, trips);
    if (rc == _SH_GPU_OK) { /* use out/vars, skip CPU loop */ }
    else { /* fall through to CPU loop */ }
}
/* CPU loop (always emitted, always correct) */
for (...) { ... }
```

`_sh_gpu_*` runtime (new, small, vendored C in the prelude, trimmed by
the existing `trim_sh_runtime` reachability like every other helper):

- `_sh_gpu_init` (lazy, once): `dlopen`/link Vulkan loader (system ICD
  or cached), `vkCreateInstance` (no layers/validation in prod),
  pick physical device + compute queue, create device, allocator,
  command pool. Failure ⇒ `unusable`, permanently cached for the run.
- `_sh_gpu_dispatch`: create (or reuse from per-ID cache) shader
  module + pipeline, upload SSBOs (host-visible coherent first;
  device-local + staging later), dispatch
  `ceil(trips/local_size)`, barrier, read back length word + bytes,
  validate bounds, return status. Any Vulkan error ⇒ non-zero ⇒ host
  falls back to the CPU loop (correctness firewall).
- No GPU present / `--cpu-only` / `--offline`-missing-Vulkan ⇒ the
  call sites compile to the CPU loop only (preprocessor + trimmer
  remove the stubs; binary has no Vulkan dependency).

Device (new `vulkan_backend.rs`): GLSL 450 compute, one shader per
candidate loop:

```glsl
#version 450
layout(local_size_x = 256) in;
layout(set=0,binding=0) buffer InBuf  { long long in_data[]; };
layout(set=0,binding=1) buffer OutBuf { long long out_len; long long out_data[]; };
// loop body, index = gl_GlobalInvocationID.x, bounds-checked
void main(){ uint t = gl_GlobalInvocationID.x; if(t >= TRIPS) return; ... }
```

Strings (rare in candidates; usually vetoed): ASCII scratch region in
a third SSBO, same fresh-slot discipline as the GLSL sketch. i64 via
`GL_EXT_shader_explicit_arithmetic_types` / `int64` capability where
the device offers it, else the two-i32 pack, else veto at candidacy
(no silent precision change — the v40/v37 isqrt+bigint lessons).

### 4.5 Statically linking tcc

- `bash-O4` embeds **`libtcc`** (vendored submodule or `tcc-sys`
  crate, version-pinned): `tcc_new → tcc_set_output_type(MEMORY or
  EXE) → tcc_compile_string(cpu_c) → tcc_add_library("vulkan"/"m") →
  tcc_run` (JIT) or `tcc_output_file` (AOT with `-o`).
- Why tcc: millisecond compile of generated C (the corpus C is
  small; `gcc -O2` dominates runtime on short scripts), no external
  toolchain at install, tiny static footprint. `-O3`-class CPU
  micro-opts come from *our* lowering (narrow ints, native echo,
  folded tests), not from `gcc -O3` — tcc's weaker optimizer is
  acceptable because the IR arrives pre-optimized.
- Fallback chain: vendored libtcc → system `tcc` → `$CC`/`cc`/`gcc`/
  `clang` (for `-o` only; JIT requires libtcc or errors cleanly).
- Static-binary story: `bash-O4` itself builds with `musl`/`--static`
  where supported; generated programs link libc dynamically by
  default (Vulkan ICDs are dynamic by nature) with a `-static-lib`
  option for fully-hermetic CPU-only binaries.

### 4.6 Auto-downloading libraries for max performance

Principle: **reproducible, consented, cached, auditable.** bash-O4
never `curl | sh`s at runtime without being told to.

- Policy flag `--fetch-libs=ask|auto|off` (+ `BASH_O4_FETCH_LIBS`,
  `BASH_O4_OFFLINE=1` forces `off`). Default `ask`: print the exact
  URL + SHA-256 + size and prompt (no TTY ⇒ refuse, tell the user the
  `--fetch-libs=auto` incantation). CI/Docker use `auto`.
- Cache: `$XDG_CACHE_HOME/bash-o4/` (default `~/.cache/bash-o4/`),
  layout `<name>/<version>/<sha256>/…`, lockfile-guarded concurrent
  fetch, content-addressed verification (hash mismatch ⇒ delete +
  error 4, never fall forward). `bash-O4 --prefetch` warms the cache
  for image builders.
- Manifest (`bash-o4-manifest.toml`, shipped in the binary, overridable):
  each entry `{ url, sha256, size, kind: header|lib|toolchain, license }`.
  v1 entries: `Vulkan-Headers` (+ `volk` amalgamation preferred over a
  system loader dep), `shaderc` *or* `glslang` (SPIR-V compiler; pick
  one, pin it — shaderc bundles glslang), plus optional CPU-perf libs
  behind per-lib use-probes (measured, not assumed):
  - GPU path (required for `--gpu≠off`): Vulkan-Headers/volk,
    shaderc. Without them ⇒ clean error suggesting `--cpu-only` or
    `--fetch-libs=auto` (never a half-built GPU path).
  - CPU path (only if a gate proves ≥10% corpus-perf win vs Walters):
    e.g. GMP (bigint loops), FFTW (signal-ish scripts), mimalloc
    (alloc-heavy string scripts). Each is `dlopen`ed/weak-linked with
    a native fallback — a missing optional lib never breaks the build.
- Supply-chain hygiene: HTTPS only, SHA-256 pin, mirror list, license
  allowlist recorded in the manifest, `--audit-fetch` log (what was
  fetched, when, hash). Vendored sources (volk, miniz) preferred over
  binaries where feasible so `cargo audit`/repro builds see them.

### 4.7 Performance model (when Vulkan wins)

Back-of-envelope (measured once per device at install into
`gpu.costs.toml`): dispatch ~10–50 µs, PCIe transfer ~10 GB/s.
A 1M-iteration integer loop (~ns/iter on CPU ⇒ ~ms total) breaks even
around 10⁵–10⁶ trips; below ~10⁴ trips the GPU always loses. Hence:

- Default `GPU_FLOOR` per loop from §4.3(5); `--gpu=force` + perf
  gate verifies the model (a `force`d small loop must *demonstrate* a
  win or the floor is raised — never blessed as "fast anyway").
- Reported metric is wall-clock of the *program* (JIT + transfers +
  dispatch included), not kernel-only time — kernel-only numbers are
  banned from perf claims.
- CPU work stays competitive regardless: tcc-JIT + narrowed ints +
  native echo/tests already remove the 5× echo-loop tax; GPU is the
  second multiplier, not the first.

### 4.8 Testing and gates

1. **Correctness firewall** (existing + one new leg): `./fail`
   (perl), `fail-estree`, `harness/c_gate_main.sh` must stay green;
   new `harness/gpu_gate.sh` runs every GPU-candidate corpus program
   three ways (`--cpu-only`, `--gpu=auto`, `--gpu=force`) and diffs
   stdout+exit (stderr ordered separately). Any divergence = P0 bug in
   the GPU path (product wrong, never "fix the test").
2. **Structural render tests** (per repo testing policy): assert the
   host split emits the dispatch+fallback shape, the SPIR-V blob is
   present/absent as decided, veto reasons print under `--check`, and
   dismissal/fallback (e.g. `BASH_O4_DISABLE_GPU=1` at runtime) runs
   the CPU loop byte-identically.
3. **Perf gate**: tracked `bench/` programs (primes, factor, isqrt
   loops from `bench*.sh`) with floor assertions (GPU ≥ CPU×1.5 above
   floor, CPU-only never slower than current `c_backend` + `gcc`).
4. **Supply-chain tests**: offline build, hash-mismatch rejection,
   concurrent-fetch lock, `ask` on non-TTY refusal.

### 4.9 Milestones

- **M1 — CPU JIT (no GPU): LANDED.** `bash-O4 prog.sh` (JIT) and
  `bash-O4 -o prog prog.sh` (AOT); artifact cache; the full
  `harness/gpu_gate.sh` differential gate (bash vs `--cpu-only` vs
  `--gpu=auto`) is green over the whole corpus (545/0/7).
- **M2 — candidacy + `--check`: LANDED** (in the `bash-o4` crate, not
  `shir_passes/` — see §6): purity/width/shape verdicts with veto
  reasons, zero codegen change.
- **M3 — first dispatch: SCAFFOLDING + PROOF, host split remaining.**
  The one-loop-shape path is proven end to end on Lavapipe (GLSL450
  emission → `glslangValidator -V` → real dispatch, all lanes
  asserted); the `_sh_gpu_*` host split in generated C is open.
- **M4 — fetch/cache + static release: MECHANISM LANDED** (manifest,
  `ask/auto/off`, `--prefetch`, `--audit-fetch`, musl story open):
  volk amalgamation hash-pinned; shaderc still unpinned (refused,
  never half-fetched).
- **M5 — breadth:** open (more loop shapes, two-i32 pack fallback,
  string-scratch SSBO, PGO floors, optional CPU libs behind probes).

## 6. Implementation notes & deviations (2026-09-13)

1. **Candidacy lives in `bash-o4/src/candidacy.rs`, not
   `shir_passes/gpu_candidacy.rs`.** Zero changes to shared analysis
   infra (no blast radius on other backends' gates); port it into
   `shir_passes` when the host split needs in-core verdicts.
2. **JIT = compile+exec, not `tcc -run`.** Same stdio/exit/args
   contract with exact error attribution (a nonzero exit with no
   compiler diagnostics is always the program's verdict). `tcc -run`
   cannot distinguish toolchain failure from program failure.
3. **Loud CC fallback.** tcc cannot parse some glibc headers
   (`<regex.h>`); a tcc compile failure retries once via
   cc/gcc/clang with a one-line stderr note. Silent fallback and
   hard failure were both rejected (parity vs transparency).
4. **Safe arithmetic by default.** Unlike `otranspilerl-cli -O3`
   (true64 off), bash-O4 keeps true-64-bit mode on at every level;
   `false` is an unsafe optimisation (silently wrong past ±2^53 on
   consulting paths) and is opt-in only (`--no-true64` /
   `$SH2_TRUE64=0`). C output is unchanged today (the flag is
   ESTree-path machinery); the posture is for future width proofs.
5. **argv[0] emulation in the driver.** JIT temp exes run with
   argv[0] = script path (`Command::arg0`), performing the
   `c_gate_main.sh` `exec -a` convention driver-side, so `$0` tests
   measure the renderer with no `$1` pollution.
6. **Cache keys carry a renderer revision** (`RENDERER_REV`, bump on
   any render-affecting change): fixed renders can never hide behind
   stale entries (found live: a corrected render lost to a hit).
7. **Source reads are byte-preserving** (U+F800 PUA markers, mirroring
   `otranspilerl`'s private `read_source`): plain lossy reads
   corrupted `utf8-non-utf8-content.sh`.
8. **Loop-invariant bound hoist came free with benchmarking**
   (2026-09-13): the bench exposed `atoll(bound)` re-parsed per
   iteration (~85% of scalar loops). Narrow refuse-first LIC in the
   `While` arm (bare-ident bounds unwritten by the body, trap-free)
   plus three regression tests; bo4-gcc closed 7× → ~1.5× vs
   handwritten on bound-variable loops. Full story in
   `bash-o4/bench/README.md`.
9. **Three core soundness fixes came free with M1/M2 verification**
   (each found by a failing test, fixed in-product with regression
   tests): `hoist_loop_invariants` hoisted `For`-counter-dependent
   stores (`a[$i]=i+1` executed once); `emit_array_assign` wrote a
   literal `"$i"` assoc entry plus a poisoned read for dynamic keys;
   the shared `_SHSPLIT` temp printed `$2` twice in `echo $1 $2`.
   The C gate stayed 637/0/7 throughout (no corpus case covered those
   shapes — which is how they hid).

## 7. M5 + transpiled CUDA — deviations and honest limits (2026-09-14)

Ten more decisions, recorded because each trades generality for
something the design doc did not anticipate.

1. **Candidacy for the GPU is a *third* path, not the CPU one.**
   `cu_candidacy::{analyze,analyze_reduce,analyze_seq}` in `bash-o4/`
   (same zero-blast-radius rule as §6.1). The CPU map candidacy stayed
   as-is; the CUDA path accepts more (multi-store fills, array-reading
   reductions, sequential lane-nests) and is deliberately allowed to
   diverge, because it sizes arrays by trip count instead of the C
   backend's fixed `ARR_CAP` backstop.
2. **Map+reduce fuse only on identical iteration spaces.** Coverage
   must be exact or the reduce could read unwritten slots; the
   vehicle refuses (SKIP) rather than synthesising a bound.
3. **`mask_fast` is a *vehicle-side clone flag*, not a shIR verdict.**
   The emitter renders `% 2^k` as `& (2^k-1)` only when the driver
   passes a bound inside the proved threshold. Rationale: the mask
   identity needs both non-negativity *and* nowrap, and baking that
   into the module would make one PTX module bound-specific (no
   caching). The cost is that a shape whose bound exceeds the
   threshold silently gets the signed slow path — correct, slower.
4. **`mask_outer` demotion instead of all-or-nothing.** When a pow2
   *outer* accumulate modulo is unversionable but *inner* pow2 sites
   are covered, the outer stays `rem` and the inners mask. Emitting
   either both-or-neither would throw away a 2× win for a shape the
   analysis could almost prove.
5. **Sequential lane-nests are admitted via a shared *privatization*
   analysis, not a special case.** `shir_passes::lane_private` proves
   (ordered init dominance, chain writes dominated by inits,
   accumulate only in the tail, pure tests) that an outer iteration is
   independent, so one lane may run the whole chain. Collatz is the
   motivating shape; the analysis has no Collatz knowledge in it.
6. **The `CuArith::Shr` peephole is path-sensitive on purpose.** A
   guard `(v % 2) == 0` proves the dividend even, and *for even s64*
   truncation and floor agree — so the shift is exact without needing
   non-negativity. The `(v & 1) == 0` rewrite is *not* emitted
   unconditionally: it is only applied where a `v > 1` while-guard
   makes `v` provably non-negative. Both are refuse-first and
   documented at the emitter.
7. **All three `-O4` drivers share one flag surface and one dispatch
   vehicle.** `bash-O4 --gpu[=auto|force|off] --n N [--runs K]
   [--bind VAR=VAL]` now dispatches the same transpiled CUDA path as
   `python-O4 --gpu` and `cutranspile`, through `bash_o4::cu_run`. The
   shared parser and help block live in `bash-o4/src/flags.rs` because
   the two drivers had *drifted*: separate private `GpuMode` enums,
   `--gpu` meaning "policy, never dispatch" in bash-O4 and "dispatch" in
   python-O4, and `--n/--runs/--bind/--help` absent from bash-O4.
   `tests/flag_parity.rs` drives both real binaries so the surface cannot
   re-diverge. `--gpu` stays an explicit opt-in, so `--cpu-only` (and a
   bare run) keep the CPU path that `harness/gpu_gate.sh` compares
   against bash; the gate's GPU leg now asserts the dispatched checksum
   against bash's stdout, or requires CPU-equivalent output when the
   candidacy declines.

   Two product bugs fell out of adding that leg, both fixed in-product:
   - the CUDA candidacies descended into shell **function** bodies and
     accepted a loop whose bound is a function-local (`099`-class
     `local n=$1`), which the driver cannot supply — it dispatched with
     `trips=0` and reported `0` while bash printed `120720`. Function
     bodies are now out of scope (the same v1 rule `walk_seq` states).
   - the artifact cache used a **shared** `prog.c.tmp` and renamed it,
     so two concurrent drivers truncated the same temp file and the
     loser's `rename` failed with ENOENT — exit 1, no bad program
     involved. `gpu_gate`'s 8-way parallelism surfaced it as a single
     FAIL that moved between files each run. Temp names are now unique
     per writer and a loser reads the winner's committed file.
8. **The `cuda` and `cuda-tx` bench columns are checksum-anchored but
   only `cuda-tx` is transpiled.** `cudabench` dispatches handwritten
   PTX block templates; `cutranspile` runs the compiler pipeline. Both
   are gated against the *same* C checksum, so a `cuda-tx`/`cuda`
   divergence would be a compiler bug — not a re-tune of one side.
9. **The Vulkan column here is software.** The only presentable
   Vulkan device is Lavapipe; `gpuleg` therefore measures the scaffold
   (and loses ~6× on transfer-bound maps over shared RAM). Real
   hardware needs a discrete GPU with a working Vulkan ICD. Recorded
   so the `gpu` column is never read as a hardware claim.
10. **Bench methodology: minimum over repeated suite runs.** The
    reference box is a shared 8-CPU laptop that regularly sits at load
    average 7–10 from concurrent builds, and single CPU-leg timings
    varied up to ~4× run to run. Quoted figures are per-leg minima
    over 3 runs of 5 reps; the *within-run* ratios (bo4-gcc/gcc-O3,
    cuda-tx/cuda) are stable because both sides see the same
    interference. An earlier single-run table was discarded for this
    reason rather than published with error bars.

### What is provably *not* claimed

- `hash` runs on the transpiled CUDA leg, but has **no handwritten GPU
  kernel**, so its row is correct-and-fast, not proven-optimal.
- `./fail` (Perl corpus) is **not green** (pre-existing 260/552
  baseline owned by the ESTree/Perl workstream). The gates for this
  work are `c_gate_main.sh` (637/0/7) and `gpu_gate.sh` (545/0/7).
- The `ARR_CAP` (1024) backstop and the tcc `<regex.h>` fallback both
  remain; neither is a silent behaviour.

## 8. Appendix — file-level touch list (for the implementer, later)

- NEW `bash-o4/` crate (driver, fetch/cache, `gpu.costs.toml`
  calibration, `gpu_gate.sh`): does not touch shared code.
- NEW `sh2perl/src/vulkan_backend.rs` (compute render) + reuse of
  `glsl_backend.rs` arith/test lowering (extract shared helpers; no
  corro-logic-in-toolkit-style layering violations — PLAN §11:
  backend owns its constructs, core owns the IR).
- EDIT `sh2perl/src/c_backend.rs`: `_sh_gpu_*` prelude + call-site
  emission + trimmer entries only (no change to CPU lowering).
- EDIT `sh2perl/src/shir_passes/`: new `gpu_candidacy.rs` analysis
  (verdicts, not rendering).
- EDIT `otranspilerl/src/lib.rs`: `-O4` gains the C+Vulkan meaning
  alongside the JS `shaderize` flag (or a separate `--gpu` axis if the
  reviewer prefers orthogonality — open decision).
- EDIT `sh2perl/src/transforms/`: gpu-prep offers (arith-text parse,
  counted-loop recovery, return-lift) via the marketplace, bisected
  per backend.
- VENDOR: `libtcc` sys-crate, `volk`, manifest-pinned
  Vulkan-Headers/shaderc (cache, not tree, for binaries).

*End of design. No code was changed to write this doc.*
