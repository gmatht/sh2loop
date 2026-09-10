# OOM and capacity-exhaustion policy (C backend)

Status: **P1 implemented** (sh2perl `2efb0bf1`, workspace gitlink bump
alongside) — classes B/C/D now fail-stop. P2 (growable arrays) and
P6/P7 decisions remain open; see "Recommendation" and "Acceptance
criteria".

## 1. Problem statement

A t86-shaped C program (`all_factors` over a highly composite `n`, or any
program run under memory pressure) can produce **incorrect or empty results
with exit code 0**. There are two distinct failure modes, both silent:

- **Empty results, exit 0.** A `strdup` failure yields `NULL`, and the
  downstream print sites null-guard to `""`. E.g. t86 emits
  `printf("[%s]\n", ((char*)(_af_12) ? (char*)(_af_12) : ""))` — on
  allocation failure the program prints `[]` and exits 0. A gate comparing
  stdout sees "empty results"; nothing reports the failure except the
  (missing) output.
- **Incorrect results, exit 0 — or UB.** The native int-array append path
  (`emit_set_array_append`, `sh2perl/src/c_backend.rs:11199`) stores with
  **no bounds check**: `{id}[{idx}] = {nv}; … ++{id}_len;` into a fixed
  `static long long factors[1024]` (`ARR_CAP`, `c_backend.rs:478`). Past
  1024 entries this is a global-buffer-overflow write. The string-array
  and assoc paths fail differently but just as silently: `_sh_arr_set`
  (`c_backend.rs:1885`) and `_sh_assoc_set` (`c_backend.rs:1896`) silently
  `return` past `cap`, and the file-read loop (`c_backend.rs:12419`)
  drops lines past `ARR_CAP` (`if ({id}_len < {ARR_CAP})`).

### Evidence

`all_factors(3269185920000)` (sqrt ≈ 1.8M loop iterations, 2310 divisors
→ 4620 entries into `factors[1024]`), compiled with `-fsanitize=address`:

```
ERROR: AddressSanitizer: global-buffer-overflow … WRITE of size 8 …
    #0 … in all_factors /tmp/oom_probe.c:91
0x… is located 0 bytes after global variable 'factors' … of size 8192
0x… is located 32 bytes before global variable 'factors_len' …
```

Without ASan this is silent corruption — note the overflow lands next to
`factors_len` itself, so the length can be clobbered too. The program may
print a truncated/wrong list and exit 0.

## 2. Current-behavior taxonomy

All refs are `sh2perl/src/c_backend.rs` unless noted.

| # | Class | Example sites | Observable behavior |
|---|-------|----------------|---------------------|
| A | Growable-buffer realloc failure | `_sh_vgrow` (:1443), `_sh_sij_ix` grow (:1614), vbuf/arena/mstr helpers (:1631–:2291) | **Fail-stop**: `fprintf(stderr, "sh2c: out of memory\n"); exit(127)`. Loud on stderr, nonzero exit — but stdout is truncated/empty. |
| B | `strdup` failure (unchecked) | ~15 sites: `emit_set_array_append` (:11032, :11192, :11231), `_sh_arr_set` (:1889), assoc (:1899–:1900), `_sh_mstr_set` (:1602), call-result temps (:3660–:3662), capture/join temps (:11841, :12182), argv/slice fills (:11095, :11145, :11171) | `NULL` flows on. Print sites null-guard to `""` (t86 `(_af_12 ? … : "")`) → **empty output, exit 0**. Elsewhere: `atoll(NULL)`-guarded → 0, `mpz_set_str(NULL)` → crash, `strcmp(NULL)` → crash. Inconsistent: sometimes wrong-output, sometimes segfault. |
| C | Fixed-cap string/assoc arrays | `char *arr[1024]`, `*_k/v[1024]` decls (:14400–:14423), `_sh_arr_set` early-`return` (:1885), assoc `if (*n < cap)` (:1900), file-read `if (len < cap)` (:12419) | **Silent truncation**: extras dropped, rest of the program runs on, exit 0 with a shortened result. |
| D | Fixed-cap native int arrays | `long long a[1024]` / `mpz_t a[1024]` decls (:14406–:14414), unchecked store in `emit_set_array_append` (:11216–:11236) | **Buffer overflow (UB)**: silent corruption or crash. The only class with no check of any kind. |
| E | Fixed string buffers | `char _sN[32]` snprintf temps (:3901–:3911, :4078), bounded `char v[N+1]` vars (`emit_guarded_copy` :1357, `FIXED_BUF_CAP` :473) | **Truncation**: `snprintf` truncates (safe, null-terminated); debug-only assert fires in debug builds, compiled out under `NDEBUG`. Documented behavior, not a crash — but a wrong (shortened) value with exit 0. The `snprintf_grow` helper (:4102) already shows the grow-until-fits pattern used elsewhere. |

Net: only class A is fail-stop. Classes B–D produce **exit-0 wrong output**
(the exact symptom reported), and D is memory-unsafe on top.

### Allocator reality on Linux (overcommit)

On a default Linux system with memory overcommit enabled, `malloc`/
`realloc`/`strdup` **almost never return NULL** — the kernel hands out
address space optimistically and the OOM-killer `SIGKILL`s the process
when memory is actually exhausted. No handler runs on SIGKILL: not
exit(127), not `abort()`, not a Python-style traceback — the process
just dies, possibly mid-line, with whatever stdout was flushed so far.
This reshapes priorities:

- The **fixed-cap paths (C/D) are the reachable, deterministic failures**
  — they trigger on input size alone, no memory pressure needed (the
  ASan demo above needs only a 4620-entry factor list). Checking them
  pays off on every platform regardless of overcommit settings.
- The **malloc-NULL paths (A/B) only fire** under `ulimit -v`,
  `vm.overcommit_memory=2` (no-overcommit), ASan/Valgrind, or an
  injected failure. They are still worth handling (cheap, and real on
  constrained/embedded targets), but tests for them must use
  fail-injection (§6), not real exhaustion — and operators should know
  that on overcommit-Linux the OOM-killer is the de-facto OOM policy
  no matter what the binary does.

## 3. Reference behavior

- **bash** on allocation failure: prints an error (`…: cannot allocate
  memory`-style / `xmalloc` failure) and exits **nonzero**. No silent
  empty output with status 0.
- **Python** on allocation failure: raises `MemoryError` (traceback on
  stderr) and exits **nonzero** (1). Likewise never exit-0-wrong-output.
- **Gate consequence**: our harness compares stdout. A fail-stop backend
  (nonzero exit + stderr diagnostic) is machine-distinguishable from a
  wrong answer; exit-0-wrong-output is not. Any policy that keeps an
  exit-0 path for exhausted capacity must therefore also keep the output
  bit-identical — i.e. silent truncation (C) and silent overflow (D) are
  unacceptable under every policy except "change nothing" (P0).

## 4. Candidate policies

### P0 — Status quo (document only)

Change nothing; record §2 as known behavior. Cost: zero. Consequence: t86
(and every array/string-heavy program) keeps a silent-wrong-output path.
Only acceptable as an explicit deferral, not a resolution.

### P1 — Fail-stop everywhere (minimum correctness bar)

Check **every** allocation and every capacity store; on failure print
`sh2c: out of memory` (or `sh2c: capacity exceeded`, see below) to stderr
and `exit(127)` — the code class A already uses.

Concrete work:

- Wrap the ~15 `strdup` sites in a `_sh_xstrdup` helper (NULL → diagnose
  + exit), same for the bare `malloc`/`realloc`/`calloc` sites that lack
  checks.
- Bounds-check the fixed-cap stores: `emit_set_array_append` (both the
  `strdup` and the native-int arms), `_sh_arr_set` callers that rely on
  the silent return, `_sh_assoc_set`, the file-read fill loop. On
  `len == cap`, diagnose + exit(127) instead of dropping/overflowing.
- Keep class A as is (already fail-stop); keep class E as is
  (documented truncation — but see open question 3).

Pros: matches bash/python (never exit-0-wrong-output); gate can assert
"nonzero exit + stderr marker" for over-capacity inputs; small, local
changes; no data-structure redesign. Cons: the 1024 cap remains — a
legitimate >1024-element program still dies, just loudly; `exit(127)`
vs other codes is a bikeshed (see open question 1); slightly larger
generated code at each append site.

### P2 — Growable arrays (remove the cap)

Replace fixed `[ARR_CAP]` array stores with realloc-growing buffers on
the `_sh_vbuf` model (`_sh_vgrow` doubling + fail-stop), keeping a
`(ptr, len, cap)` triple. Allocation failure then funnels into the
single class-A path. The `snprintf_grow` helper (:4102) is the template
for grow-until-fits.

Pros: removes the cap entirely — any input size works until real OOM,
then fails loudly; one OOM path to test instead of four; consistent with
how vbuf already works. Cons: the largest change — every array decl,
`len` global, assoc pair array, and the file-read fill must thread a
capacity; more generated-code churn; `static` placement and the
arena interplay need care.

### P3 — Bounded with stderr diagnostic, keep running

Keep the caps, but on overflow emit a one-line `sh2c: warning: … truncated`
to stderr and (a) continue with short output, or (b) exit nonzero after
flushing. Pros: minimal diff (one branch per store); preserves the "small
static binary, no realloc" shape. Cons: variant (a) still produces
exit-0-wrong-output (fails the gate rule in §3); variant (b) is just P1
with extra steps and a warning nobody reads. Not recommended except as a
stepping stone to P1.

### P4 — Caller-visible errors (status codes / errno)

Thread allocation failure through return values / `_sh_rc` / `errno` and
check at each use site (fail the enclosing command, `set -e`-style abort
at top level). Cons: C has no exceptions, so *every* use site needs a
check — the current print-site null-guards show exactly how this rots:
the checks exist but encode "substitute empty" instead of "abort". To do
P4 correctly is strictly more invasive than P1 with no behavioral upside
for a transpiled batch program. Not recommended.

### P5 — Arena with a single exhaustion check

Bump-allocate all strings from a fixed arena (`SH2_ARENA_CAP` already
exists at :1590; `_sh_adup` already falls back to `strdup` past the cap
— that fallback is itself an unchecked-alloc path). Size the arena once,
check once at exhaustion → fail-stop. Pros: a single check point; fast.
Cons: arena sizing is a guess (too small → spurious OOM; too large →
waste); lifetimes/aliasing across scopes need an audit; still needs P1
for the non-arena paths (int arrays, vbuf). Best viewed as an allocator
optimization *under* P1/P2, not a policy by itself.

### P6 — Always abort (`abort()` / SIGABRT)

On exhaustion: `fprintf` the diagnostic, `fflush` stderr, `abort()`.
Process dies with `SIGABRT` (exit status 134), optionally leaving a core
dump. This is the glibc-malloc-failure and Rust-OOM default.

Pros: cannot be ignored or swallowed by callers (unlike a return code);
no unwinding/cleanup code to get wrong; the core dump gives post-mortem
debuggability for the exact allocation that failed; one uniform behavior
for every class (A–D all funnel to it); matches what a C programmer
expects from a hard allocator failure. Cons: no cleanup runs — temp
files, flushed-but-incomplete stdout, `atexit` handlers all skipped
(`exit()` runs `atexit`/`fclose` flushing; `abort()` does not, so even
the stderr diagnostic needs an explicit `fflush`); hostile if the
generated C is ever embedded as a library (see open question 5 — an
embedder cannot override `abort()` the way it can a return code);
core dumps may be disabled (`ulimit -c 0`) or enormous; the gate must
match on signal-death (134) rather than a plain exit code. Relationship
to P1: identical detection work (every site still needs its check) —
P6 differs only in the last mile (die-by-signal vs die-by-exit). The
choice between them is essentially open question 1 (127 vs 134).

### P7 — Pythonic exception (catchable `MemoryError`)

Route exhaustion through the backend's existing `setjmp`/`longjmp`
exception machinery (`IrStmt::Try` → `_sh_raise` + `jmp_buf`; the
infrastructure already exists for Python-style `try`) so that a
transpiled `except MemoryError` can *catch* OOM, and uncaught OOM lands
in a top-level handler that prints a `MemoryError`-style traceback and
exits nonzero. Sketch: allocation sites call `_sh_xalloc_or_raise`
(returning NULL is replaced by `_sh_raise(MemoryError)`); each
`try:` in the source already has a `jmp_buf`; the outermost frame's
default handler prints `MemoryError` + the allocation site to stderr
and exits nonzero.

Pros: the only policy faithful to Python semantics — `try: … except
MemoryError:` in the source program keeps working after transpilation,
which matters for programs that pre-size, retry smaller, or degrade
gracefully today; uncaught path is still fail-stop (satisfies the §3
gate rule). Cons: same per-site check cost as P1 *plus* handler
wiring; `longjmp` skips intermediate cleanup (C has no destructors,
but open `FILE*` buffers, temp files, and half-grown vbufs leak —
acceptable at OOM only if documented); `longjmp` out of a vbuf-growth
mid-`printf` needs the format machinery to be re-entrant-safe;
allocations inside the *handler itself* (formatting the traceback) must
use static buffers or risk recursion; the gate must test both the
caught path (program recovers, output correct) and the uncaught path
(nonzero + traceback). Note P7 still needs P1's detection work — it
changes what happens *after* detection (raise vs exit).

### P8 — Retry after cleanup (one GC pass, then fail-stop)

On allocation failure: run a single deterministic cleanup pass (flush
`pending_frees`, reset arenas, drop memo caches), retry the allocation
*once*, and only then fail-stop per P1/P6. The backend already has
natural collection points (move-based ownership, `pending_frees` flushed
at statement boundaries, `_sh_arena_reset`).

Pros: absorbs transient spikes where garbage (not live data) is the
problem; tiny addition on top of P1 (one retry wrapper). Cons: rarely
helps the real cases — t86's `factors` array is all *live*, so retry
just delays the inevitable by microseconds; risks doubling OOM latency
in a tight loop if the retry itself is expensive; must be strictly
one-shot (retry-looping on persistent exhaustion is a hang). Only
worthwhile if profiling shows dead-temps-at-OOM to be common; otherwise
skip.

### P9 — Upfront reservation / fail-fast

Estimate the worst-case need *before* doing partial work and refuse
upfront: e.g. size the array once from a proven bound, or check
available memory (`sysinfo`/`getrusage`) against an estimate, and
diagnose + exit before the first side effect. Avoids the worst P1
outcome class — half-written output files / half-mutated state before
the failure.

Pros: failure happens before any observable side effect (cleanest
failure atomicity); a single check can cover a whole loop. Cons:
estimates are usually unavailable (divisor counts, join sizes, capture
lengths are data-dependent — t86 cannot know 4620 upfront without
computing it); over-reservation *causes* the OOM it tries to avoid;
`sysinfo`-style checks race with other processes. Practical only where
a cheap proven bound exists (range analysis already proves some loop
bounds — wire those few, not a general mechanism).

### P10 — Streaming / degraded fallback (bounded-memory algorithms)

Instead of materializing, stream: for t86, emit factors as found, or
external-sort chunks through tmpfiles, keeping memory bounded by
construction. General principle: prefer algorithms whose memory is a
function of a small constant, spilling to disk past it.

Pros: turns OOM into a performance cliff instead of a correctness
cliff; no artificial caps. Cons: `sorted()` forces full
materialization anyway (t86's sort needs all factors) — streaming only
bounds the constant, and external sort is a large feature for one
program shape; changes output *ordering* guarantees if done naively
(sort-then-print vs print-as-found differ observably); tmpfile spill
needs its own failure policy (disk-full = the same problem one level
down). Recommend only as an algorithmic opt-in per program shape, not
a general OOM policy.

### P11 — Poison bit + boundary check

Keep a single global `_sh_oom_failed` flag: allocation/cap sites set
it instead of acting, and a few *boundary* points (every `printf`/
`exit` path, end of `main`, end of each function returning a heap
value) check it once and fail-stop. Fewer checks than P1, one
code shape.

Pros: minimal per-site diff (one flag-set); single choke point to
audit. Cons: every boundary must be found — one missed `printf` and we
are back to silent wrong output, and the audit burden is *larger* than
P1's local reasoning (correctness depends on global coverage, not on
each site being right); poisoned values can be *consumed* before the
boundary (e.g. `atoll(poisoned-NULL)` → 0 propagates into arithmetic
and the boundary check then reports failure for output that was
*computed* wrong, not just truncated). Strictly weaker assurance than
P1 for similar effort. Not recommended.

## 5. Recommendation

**P1 (fail-stop everywhere) now; P2 (growable arrays) as the follow-up.**

Rationale: P1 is the minimum bar that eliminates the reported symptom —
no exit-0-wrong-output on any exhaustion path — at the smallest diff, and
it reuses the exact diagnostic + exit code the backend already emits.
P2 removes the underlying 1024 cap (the ASan-demonstrated overflow goes
away by construction), but it is a larger refactor that should land on
top of P1's checks, not instead of them. P3 keeps a wrong-output path;
P4 rots into what we already have; P5 is an optimization, not a policy.

Suggested sequencing:

1. ✅ DONE (`2efb0bf1`): `_sh_xstrdup` + `#define strdup` (inserted
   post-render iff a call site exists) converts all class B sites;
   bounds checks on all class C/D stores (append upfront check,
   literal/split/argv fills, ArrayComp loop, DeclareArray emit-time
   refusal, file-read loop, `_sh_arr_set`, `_sh_assoc_set`).
   Verified: over-cap probe exits 127 with `sh2c: capacity exceeded:
   factors` on stderr (was: ASan global-buffer-overflow); t86
   identical output, valgrind clean; C gate 89/90, JS gate 90/90;
   3 new unit tests (xstrdup ordering + negative, append-guard
   order, over-cap DeclareArray refusal).
2. ✅ DONE (same commit — the upfront check covers the int arm, so
   the demonstrated `factors[1024]` overflow now dies loudly instead
   of UB, without redesigning the arrays).
3. (Follow-up) P2: grow the array stores; the P1 checks become the
   realloc-failure arm.

How the new candidates fit: P6 (abort) is a drop-in swap for P1's last
mile — decide with open question 1 and apply uniformly. P7 (catchable
`MemoryError`) layers on P1's detection; attempt it only after P1 lands
*and* a corpus program is shown to need `except MemoryError` (no such
program is known today — the t86 family has no handler). P8/P9/P10 are
optimizations for specific shapes, not substitutes: P8 only if dead
temps at OOM prove common, P9 only where a proven bound already exists,
P10 only as an opt-in algorithm change. P11 is rejected (weaker
assurance than P1 for similar effort). The overcommit note (§2) does not
change the recommendation — it reinforces doing the cap checks (step 2)
first, since those are the failures that actually fire.

Follow-up landed: because OOM now aborts, a heap string from a proven
call can never be NULL at its use — so the `? : ""` guards on fresh
call temps are dead and the backend drops them (`nonnull_returns`
pre-pass + temp proof; t86's four `_af_*` printfs). Named shIR vars
(`old_factors`-style cross-statement moves) keep their guards — that
needs flow analysis, queued separately.

## 6. Test strategy

- **ASan sweep of the corpus**: compile the C-gate outputs with
  `-fsanitize=address,undefined` and run — the `factors[1024]` overflow
  was found exactly this way. Any new store path must survive it. (The
  4620-entry probe: `all_factors(3269185920000)`; keep the iteration
  count modest — sqrt ≈ 1.8M runs in seconds.)
- **Fail-injection hook**: add a debug `_sh_fail_alloc_after(N)` counter
  (env-gated, e.g. `SH2_FAIL_ALLOC_AFTER`) decremented in
  `_sh_xstrdup`/`_sh_vgrow`; at zero, fail the allocation. Then: for
  each N in a small range, assert the program exits nonzero with the
  stderr marker and never exit-0. Without the hook, OOM paths are
  untestable short of `ulimit -v`/cgroups.
- **`ulimit -v` / cgroup smoke test**: run t86 under a tight address-space
  limit; assert nonzero exit (today: silent `[]`/truncated output or
  crash, depending on which path exhausts first). Caveat from §2: on
overcommit-Linux a plain memory-hog test usually meets the OOM-killer
  (SIGKILL, no handler) before any allocator check — so this test
  proves *something* dies loudly-or-silently, not that *our* handler
  fired; the fail-injection hook above is the precise test, `ulimit`
is the end-to-end one.
- **P7 caught-path test** (if/when P7 lands): a program with
  `except MemoryError` around a forced-exhaustion site must recover and
  produce correct output; the same program *without* the handler must
exit nonzero with the traceback. Both halves are required — testing
  only the uncaught path leaves the `longjmp` wiring unverified.
- **Gate rule to pin**: *no exhaustion path may exit 0 with altered
  output.* Over-capacity inputs must either produce identical output or
  exit nonzero with a stderr diagnostic. Class E (snprintf truncation)
  is grandfathered only if documented per-site; see open question 3.

## 7. Open questions

1. **Exit code / death mode.** `127` is already used by class A, but in shell
   convention 127 means "command not found". bash allocator failure
   exits nonzero (conventionally 2); Python `MemoryError` exits 1;
   `abort()` dies by SIGABRT (134). Options: keep 127 (consistency
   within the backend), switch to 1 (matches Python), use 2 (matches
   bash), or adopt P6 wholesale (134 + core). Decision needed before P1
   step 1 (it pins the gate assertion) — and P6-vs-P1 is decided here,
   not later.
2. **Diagnostic text.** Keep `sh2c: out of memory` for all classes, or
   distinguish `sh2c: capacity exceeded (factors > 1024)` for cap hits?
   Distinct messages make triage faster; one message is simpler to gate
   on. Recommend distinct messages sharing a `sh2c:` prefix so the gate
   can match the prefix.
3. **Class E (snprintf truncation).** Is per-site documented truncation
   acceptable, or should bounded-string overflow also fail-stop? The
   `char _sN[32]` integer temps are provably wide enough for `%lld`
   (20 digits + sign + NUL ≪ 32) and need no policy; the
   user-controlled `char v[N+1]` bounded vars are the real question.
4. **Who owns the array-cap redesign (P2)?** Touches decl shapes used by
   the int-array, assoc, and file-read paths — coordinate with whoever
   owns `emit_set_array_append` / array-return ABI work to avoid
   conflicting in-flight changes.
5. **Library embedding.** Today the generated C is a standalone binary,
   so `exit()`/`abort()` are acceptable. If it is ever linked as a
   library, both are hostile to the host. Mitigation if that day comes:
   funnel all OOM paths through one overridable choke point (a
   `_sh_oom_handler` weak symbol / function-pointer defaulting to the
   fail-stop), so an embedder can substitute longjmp-to-handler or an
   error return. Cheap to add when P1 lands (one call site shape),
   expensive to retrofit — decide whether to include the hook now.
6. **Does any corpus program need catchable OOM (P7)?** Survey the
   corpus for `except MemoryError` / `trap … ERR`-around-allocation
   patterns. If none exists, P7 stays a documented non-goal until one
   appears; the uncaught path (nonzero + traceback) is then all P7
   would ever exercise, and P1/P6 covers it.
