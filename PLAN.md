# Plan: ESTree-JSON Contract, Test Gate, and a Universal ShIR

Covers three related work items:

1. **Decouple sh2perl and sh2runtime via an ESTree-JSON data contract** — no
   submodules, no code-level coupling. sh2perl emits ESTree JSON; sh2runtime
   consumes it against its virtual FS.
2. Extend sh2perl's test runner so a test only passes when the emitted ESTree,
   executed by the reference executor, passes the corpus vs `bash` (staged
   rollout; sh2runtime validates the same ESTree in its own repo).
3. Evolve toward a **language-neutral ShIR** between the shell AST and the
   per-language IRs (Perl IR, ESTree/JS IR).

> **Revision history**
> - v37: **py-sh-go bigint regime — t86_factor + t87_bignum (Python ints are
>   unbounded, so every integer whose value cannot be PROVEN within ±2^53
>   lowers to exact JS BigInt arithmetic; proven ones stay on the Number
>   fast path).** Frontend (frontends/py-sh-go): interval analysis (exact
>   big.Int constant folds + interprocedural param ranges from the folded
>   call sites); the domains emit — literals as Cast(Int64, Num) (exact
>   BigInt("N") literals; a >i64 literal as a Horner digit chain), proven-big
>   vars read raw from their lifted BigInt bindings, Python floor division /
>   modulo composed ((a − ((a%b)+b)%b) / b) when signs are unproven (plain
>   ops when proven-nonneg — JS truncation agrees), `**` native. Float math
>   (int(n**0.5), the t86 isqrt idiom) lowers to the runtime arith-string
>   (sh2.arith / evalArith — Math.sqrt is exactly rounded, matching glibc's
>   correctly-rounded pow(x, 0.5); other float pows REFUSE); the param
>   positional is referenced as $1 in the arith text so the param keeps its
>   lifted binding (a store-marked param re-parses per iteration). A param
>   materializes at function entry (p = $1 arith — fixes the pre-existing
>   unset-param-in-arith bug; string/unfoldable call sites keep the string
>   redirect). `set()/add()/sorted()/list()` lower set-semantics to the
>   shell surface: append now, `printf '%s\n' "${x[@]}" | sort -n -u | awk`
>   (real GNU sort, arbitrary precision; awk joins ", ") — print(list)
>   renders the Python repr. Computed-bound range()
>   (range(1, int(n**0.5)+1)) lowers to a While over an int counter with a
>   native arith comparison and a native IncDec step (67M-iteration
>   divisibility loop: 5.9 s vs native python3's 8.3 s). Core
>   (sh2perl/src/shir.rs): the ZERO-COMPARE pattern `X == 0` with div/mod in
>   X renders natively — a zero divisor's NaN fails `== 0` exactly like
>   bash's abort→false, so the per-iteration imod/idiv helper dispatch AND
>   the arithEval string-truthiness wrapper drop (the wrapper's "0" is
>   truthy — the second bug this fixed: bare arith If/While conds now
>   coerce numerically via cond_to_estree, Number("")=NaN falsy = the bash
>   abort semantics); the `/` lowering gains a bigint taint (any operand
>   with an Int64 cast or a var read — Math.trunc(BigInt) throws where the
>   runtime helper coerces; `%` stays native, it is BigInt-safe). Runtime
>   (harness/sh2-namespace.mjs + sh2-trace.mjs): idiv/imod are BigInt-aware
>   (coerce via BigInt(...), the native BigInt operators — bash Number
>   semantics identical). Gates: py-sh-go 84/84 (incl. t86 + t87), c-sh-go
>   105/105, estree corpus 552/552, lib tests unchanged (2 pre-existing
>   mid-WIP reds from the concurrent C-backend work).
> - v36: **Runtime optimization items 1–3 (CROSS_BACKEND_RUNTIME.md §8.4):
>   item 1 (return-in-loop → flag+break) landed earlier; item 2's SCC
>   recognition landed as a SHARED analysis (`shir_passes/scc.rs` —
>   call-graph Tarjan + `FunctionScc` PassContext wiring, the test-parser
>   cluster recognized as one SCC); item 3 (glob-matcher lift) LANDED via
>   SCC-based echo-return recognition — globMatch/ext_match/ext_alt_match/
>   param echo-return-lifted, polyfill self-test byte-identical, perl
>   corpus 268/283 (2 more passes), estree 545/551, lib 406/407 (the 1
>   red is the concurrent worker's in-flight sh_backend grep_p test).**
> - v35: **Session total: gate 541 → 605 peak → 599–604 (37 reds), 30+
>   commits of C backend improvements on backend/c.** Major features:
>   native while-read loops with IFS-aware `_sh_read_split()` field
>   splitting, Ext(ForEachLine) C getline rendering, eval/./source
>   state-import sites, runtime assoc keys for `$`-bearing subscripts,
>   `${#arr[@]}` native counts in let conds via `__SHCNT_` token
>   substitution + `apply_array_counts()` rewrite, printf `-v` native,
>   flow peeling from and/or chains, expanding param defaults, echo -e
>   text stages, bare export env sync, extglob test sites, case pattern
>   dequoting, word-separation fixes (env prefixes, assign values,
>   interpolated getVar), heredoc terminator ordering, DSE guard fix
>   offered per §11. Post-merge regression from main's StorageClass/
>   _sh_mstr landing fixed by reverting to raw char* declarations.
> - v34: **ForEachLine landed IN CORE; §11 marketplace status recorded.**
>   The three-layer completion (enc.rs Array round-trip, cat_read counter
>   zero-init + BinOp-typed increment, c_backend body-var hoisting +
>   Int typing) is committed on MAIN (d10cae04 + d327ddc7), not just the
>   backend/c branch — every backend's ingress and gate now benefits.
>   DSE guard for the A1 builtin-call export shape verified present in
>   core (convergent take of the §11 offer). Per-backend ForEachLine
>   acceptance: IMPLEMENTED c / perl / go / rust / java / zig; PENDING
>   python / js / sh / estree (estree needs a sh2.lines runtime member in
>   sh2runtime — cross-repo, out of scope here). Two new core requests
>   filed from C-gate evidence (core-requests/
>   core-bug-dse-guard-a1-export-shape.md incl. posix-sh-go A1 split-
>   marker gap). Gate through main's own binary: 603/643; lib 382/382.
> - v33a: **NATIVE while-read loops** (the top remaining red class).
>   `while IFS= read -r … && [ -n "$line" ] && (( … )); do … done < F |
>   < <(producer)` now lowers to a C streaming fgets loop: the AND-chain
>   head decomposes into one read builtin + natively-renderable condition
>   leaves (bails on Or / multi-read / exotic flags), IFS-aware field
>   splitting via `_sh_read_split()` (default whitespace with leading
>   trim / raw `IFS=` whole-line / single-char delimiter, last var keeps
>   remainder), remaining conditions evaluated per iteration, body
>   rendered natively so continue/break keep C-loop semantics. Producers:
>   fopen for files, popen for arbitrary pipelines (documented per-case
>   fork/exec; producer variables exported first). Gate fixes verified
>   byte-equal: 063_11, 064_17 (7-var `IFS=:` passwd fields), 071, 088,
>   091. Gate 602 → 605/643.
> - v33: **ForEachLine completion: ingress round-trip + body-var hoisting
>   + C render.** Audited the Ext(ForEachLine) family end-to-end and found
>   it unfinished in three layers: (1) `shir_nodes/enc.rs` could not
>   round-trip `IrExpr::Array` inside ext-node bodies — `cat -n F` failed
>   at JSON INGRESS before any backend rendered (Array arms added to both
>   enc directions; convergent with the sibling's uncommitted variant on
>   main); (2) body helper vars (`cat -n` counter __cnN) now hoist via
>   collect_store_names/collect_vars_full over fl.body, with
>   self-increment assigns typed Int (a char* counter printed garbage);
>   (3) the C render itself (C getline streaming loop, limit-aware, var
>   hoisted as Str). ForEachLine matrix 9/9 byte-equal vs bash: cat,
>   cat -n, multi-file cat, tr<, wc -l<, cut, sed s///, grep -c,
>   head-limit. Also this round: core DSE guard fix offered back per §11
>   (core-requests/core-bug-dse-guard-a1-export-shape.md —
>   collect_decl_guard missed the A1 builtin-call export shape, DSE
>   deleted 'X=…; export X' stores), shopt -u nocasematch clears fold +
>   nocasematch patterns dequote, BASH_VERSION seeding, native mapfile
>   from FILE with deferred natives past system(), $PIPESTATUS
>   state-import tail. Gate 597 → 602/643 across the rounds (one-cell
>   full-gate flake under sibling load; isolated reruns green). lib tests
>   378+4 passed / 0 failed.
> - v32: **backend/c convergence merge + gate 597 → 602/643 (34 reds),
>   lib tests 382/382.** Follow-up round on top of the convergence: native
>   `mapfile`/`readarray` from FILE (process-substitution arrays survive —
>   bash arrays cannot cross exec; natives inside and/or chains are
>   DEFERRED past the site's system() via pending_native_stmts so a FIFO
>   reader cannot deadlock its own writer), `$PIPESTATUS` through a
>   state-import tail (`__shps_j='1,0'`, ring-buffered `_sh_ps()` reads,
>   rc chained via trailing test), nested `${v:-${w:-$(cmd)}}` defaults,
>   `BASH_VERSION` seeding, capture-assign NAME= gluing. Post-convergence
>   regression fix: extglob shopt + operator spacing re-added to
>   test_shell_site. Merged the parallel backend/c lineage (22 commits:
>   heredoc render-time interpolation, eval/./source state-import sites,
>   `printf -v` native lowering, string-var ++/-- sequence-safe helpers
>   (`_sh_postinc`/`_sh_preinc` — the hoisted-temp strcpy form was
>   unsequenced C), flow-statement peeling out of and/or chains
>   (`test || continue` rendered `|| 1` and never flowed), nested-block
>   `local` hoisting (bash local is function-scoped; C block decls
>   vanished at the brace), first-match `${var/pat/repl}`, subshell
>   unset/read save-restore, `$?`/`$$`/`$#`/positional resolution inside
>   `[[ ]]`, IFS inline expansion (bash resets inherited IFS at startup),
>   bare-export env sync, echo -e escape interpretation in text stages)
>   with main's independent line (14 conflicts resolved toward main where
>   it superseded: arith_subst_specials/arith_sequenced, array-inits
>   materialization for test texts, assoc-aware param reads). Post-merge
>   regression fix: extglob shopt + operator spacing re-added to
>   test_shell_site. Remaining 44 reds: process-substitution state
>   backflow (mapfile arrays), PIPESTATUS, traps, background copy-at-fork,
>   $0/script-name, assoc iteration order — all catalogued as runtime-
>   limitation classes, none hidden.
> - v32: **Storage-class selection landed in core (cross-backend) + Phase 1–3
>   implementation.** StorageClass enum (Numeric/InlineBuffer/ManagedString/
>   CaptureResult/Escaped/ConstLiteral) added to core ir.rs; populated by
>   select_storage_classes in shir.rs from existing analyses; emit_var_decl
>   dispatches per class. escape_classes Store verdict wired into the C
>   renderer. output_type hints on all 30 ext nodes. Gate at 572/643
>   (89%) — fluctuates with sibling merges. REFERENCES_to_POINTERS.md and
>   FAT_POINTERS.md document the five-representation design, trust-boundary
>   model (CopyOnAssign vs PointerAliasing), and 66-site sh2_str integration
>   path. Phase 3 ptr-type tests added (4 unit tests). Remaining reds are
>   documented per-class in c-backend-limitations.md.
> - v31: **C-backend natural-node push: 538 → 580/643 corpus cells, zero
> compile errors, zero stub markers on corpus; limitations catalogued**
> (`sh2perl/docs/c-backend-limitations.md`). Native-codegen replacements
> for child-bash emulation: raw `((...))` texts evaluate via `parse_arith`
> with SEQUENCED statement rendering for side-effecting trees
> (`j = i++ + ++i` — ordered temps, no fork/exec); stderr-only redirects
> over natively-renderable inners skip the shell site (the assign must
> land in the parent: `n=$(($1+0)) 2>/dev/null`); unquoted-heredoc
> interpolation exports body vars and uses a bare delimiter; file
> redirects render BEFORE heredoc bodies with a terminator-alone-on-line
> guard. Soundness fixes: const-lift poisons vars named inside raw arith
> texts and type-checks lifted initializers (`const char i[21] = 2` was
> invalid C); statement-level `!cmd`/`A && B`/`A || B` publish the bash
> verdict in `$?`; env-prefix assignments render glued (`IFS= read`);
> `${#var}` length reads and `$var` slice indices resolve live values;
> first-segment expansions in private capture buffers keep their word
> separator (`-- "$d/f1"` was gluing into one word). Remaining 63 reds
> are catalogued per-class with root causes (assoc iteration order,
> background copy-at-fork, eval/source parent effects, quoted-brace
> alternation — the last is a CORE parser bug offered back per §11:
> brace alternatives containing `..` under a top-level comma must stay
> literal). Concurrent-worker note: this effort ran while sibling loops
> held in-flight edits on shir.rs/text_ops.rs; all C-backend diffs stayed
> inside src/c_backend.rs (+docs), verified by cargo test c_backend 6/6.
> - v30: **First core acceptance of worker-offered IR transforms via the
>   per-backend bisect.** 13 offers from `core-requests/transforms/offered/`
>   were staged into the shared crate (`src/transforms/`, *not* the marketplace
>   per-backend worktrees — see the note below), each given its IR-shape
>   compile fixes (`asm`/`named_blocks`/`var` fields added to patterns and
>   initializers vs the offers' older IR), and bisected per backend
>   (`bisect-transforms.pl`, `DEBASHC_TRANSFORMS`-gated, no rebuilds) over the
>   **estree** (`fail-estree --metric`, ESTREE failed), **perl** (`fail`,
>   TESTS COMPLETED failed), **shir** (`fail-shir`, total shell-outs) and
>   **go** (`fail-go`, js pass) gates.
>   **All 13 pass the intersection — no gate regressed**: arith-identity,
>   const-capture-fold, const-condition-elim, copy-propagation,
>   dead-store-elim, div-mod-pow2, hoist-loop-invariants, redundant-store-elim,
>   string-accumulator, test-simplification, unreachable-after-exit,
>   counted-while-forinit, merge-init-assignments. Committed in the submodule
>   (85e9807) + gitlink bump; now enabled by default in `all()`.
>   **Gating note:** there is NO live per-backend enable/disable of structural
>   transforms in the shared root crate — `transforms::apply()` runs the whole
>   `all()` once for every backend (shir.rs:3082); the only runtime gate is the
>   global `DEBASHC_TRANSFORMS` env allowlist (`transform_enabled`, used by
>   sync-ok-loops), and per-backend acceptance only exists as (a) render-time
>   contract-node refusal (`refuse > guess`, e.g. sh_backend refusing un-
>   stripped ForInit) and (b) the separate `backends/<lang>` worktree
>   registries. So an accepted transform must pass the intersection of the
>   kept backends' gates, which is what this bisect measured.
> - v29: **Transform marketplace — offered/accept/reject, core narrowed to
>   build + canonical bug-fix (proposal, §11).** The estree worker's
>   implement-and-mediate model is the bottleneck (serial mediation, blocking
>   sleeping-<lang> wakes, STALLED-FIRST starvation, a gate that can't see
>   frontend-emitted A1). Replace it: BACKENDS own transforms — a backend
>   implements new transforms, decides the sharing scope, offers them; other
>   backends accept or reject (compile-time for transforms, render-time
>   verdict-recorded for contract nodes). FIXES and UPDATES to existing
>   transforms are ALSO offered; when all acceptors land the new version, the
>   OLD one is pruned (no forks: a per-backend modification is a NEW
>   transform). The core keeps only: build CI over every backend tree, bug
>   fixes on the canonical set, the invariants (determinism, perl pass
>   count, round-trip), the A1 schema, and the bash→A1 parser. The
>   cross-product gate flips from an owner's gate to a SIGNAL feeding each
>   backend's accept/reject verdicts. Conditions: acceptance ≠ fork;
>   every transform ships a manifest (prereqs, invariant, intended scope);
>   the contract stays additive + round-trip-tested. Pilot: un-reject
>   bc-float-clean (GLSL backend owns it, offers to sh).
> - v28: **Embed profile — purify inside the transpiler (Stage 1 landed):**
>   the shIR renderer gains `shir_to_perl_embed` (`src/ir.rs`), rendering a
>   shell snippet as an embeddable Perl fragment — statements only, `do { … }`
>   wrapper (bash-subshell copy-in semantics; a same-scope `my $x = $x;` would
>   mask-REUSE the host lexical and leak writes — verified), host-scope reuse
>   via the `required_host_bindings ⊆ host_scope` gate, analysis-driven
>   refusals (exit/function/background/preamble-var deps) replacing
>   purify.pl's regex rejections. Verified 30/30 byte-deterministic (the
>   legacy `parse --inline` Generator is hash-order flaky) and byte-equal vs
>   bash on host-read/copy-in-non-leak/status-mirror probes. CLI hook
>   `parse --perl-embed` (`PURIFY_SCOPE` env). `cargo test --lib` 300/301
>   (glsl = pre-existing WIP). Spec: `sh2perl/docs/embed-contract.md`;
>   record schema `embed_block` in `frontends/shir-contract/schema.json`.
>   Remaining: otranspilerl `--embed-perl`, purify.pl backtick swap + Bug 3
>   marker protocol, PassContext verdict upgrade (escapes/lifts), generic
>   per-language profile + preservation gate. Full design: §10.
> - v27: **`&` background jobs get copy-at-fork semantics (JS backend); the
>   webworker path is designed but parked** (2026-08-15; submodule
>   5e56ff2/72b7c61, workspace commit below). Bash `cmd &` FORKS — the job
>   is a subshell with a copy of the shell state; the runtime's microtask
>   emulation ran the body on the LIVE shared state, so a background job's
>   mutations leaked into the parent (`x=1; { x=2; } & wait; echo $x` →
>   `x=2`; same for `if &`, `for &`; a backgrounded FUNCTION call leaked
>   too). Fix: the emitted body is now `sh2.background((sh2) => body)`
>   (shir.rs arrow param; estree-gen/astring prints it) and the runtime's
>   `background` runs it on `cloneShellForJob(this)` — an `Object.create`
>   clone shadowing every mutable container (vars/arrays/assoc/exported/
>   positional/fdTargets/shoptState/refVars/lifted-var stores; traps
>   RESET per bash's subshell rule; functions shared — see the limitation).
>   The parent never shares the clone; no feed-back (bash's no-arg `wait`
>   returns 0 and `$?` after `&` is the & command's own 0). Verified: the 7
>   existing `&` examples byte-identical vs bash, new corpus pin
>   `105_background_copy_semantics.sh` (was x=2 → x=1), determinism holds,
>   `cargo test --lib` 292/293 (the glsl failure is pre-existing in-flight
>   worker WIP). **Documented limitation:** USER-FUNCTION bodies (`f &`)
>   are shared closures whose internal `sh2` references bind the module
>   instance — a function's state writes still touch the parent; the
>   webworker path (a fresh module instance per job) fixes it.
>   **Webworker design (assessed, parked):** `&` as real `worker_threads`/
>   Web Workers gives true copy semantics (the demonstrated `f &` leak) and
>   real parallelism (browser; CPU-bound bodies), but the corpus pins
>   microtask stdout order and workers are the most expensive lowering — so
>   the heuristic is a fact/policy split: the EMITTER classifies the body
>   (`io` = has a subprocess → microtask clone; `cpu` = loops/arith only →
>   worker candidate, weighted by the existing range analysis) and the
>   RUNTIME owns the mechanism decision (capability + weight threshold),
>   carried as an annotation on `sh2.background(fn, kind[, weight])` — one
>   reference implementation (harness), spec-owned policy
>   (`estree-api.md`), never two bespoke heuristics. Corpus rule: background
>   examples must be order-deterministic (no unsynchronized parent↔job
>   write races — the `(echo hi)& echo there` / `((echo hi)& echo there)`
>   classes are banned; sleeps/wait pin ordering). Also fixed:
>   `fail-estree` prefix/solo runs no longer clobber `.estree_failures.tsv`
>   (the metric tsv had the same guard; a solo run used to wipe the
>   full-run failure list mid-investigation).
> - v26: **Worker allocation + cgroup enforcement for the gates**
>   (`harness/WorkerPool.pm`, wired into `fail` / `fail-estree`; the GNU
>   coreutils `gate` patch is staged for a root-owned apply). A gate's
>   worker budget is `min(int(nproc/2), 50%-of-RAM ceiling, loadavg room
>   (0.9·nproc − load1, dynamic), MemAvailable headroom, shared `.workers/`
>   slot capacity)` — floored at 1 — so N concurrent agent-loop gates can't
>   each spawn nproc/2 workers, and gates yield when the native windows
>   (pi agents, which stay outside the pool) are busy. Cgroup enforcement
>   on by default (best-effort; fails back to cooperative accounting when
>   cgroups aren't writable, e.g. unprivileged WSL): the `sh2gates` cgroup
>   caps memory at 50% of RAM (SH2_GATE_MEM_FRAC), pids at 1024
>   (SH2_GATE_PIDS_MAX, fork-bomb containment), and cpu.shares/weight at
>   512/50 (SH2_GATE_CPU_SHARES/WEIGHT — half the default, so agents win
>   contention automatically). A second, sibling `sh2workers` cgroup bounds
>   the long-running worker loops themselves (estree/perl/backend/frontend/
>   triage + their pi sessions): memory 50% (SH2_WORKER_MEM_FRAC), pids
>   2048 (SH2_WORKER_PIDS_MAX), DEFAULT cpu weight (1024/100 — the workers
>   stay the priority class; the gates yield to them). The loops
>   self-enroll at startup (`--enter-worker`); gates re-enroll into
>   sh2gates. Env: SH2_NO_CGROUPS=1 disables enforcement;
>   SH2_WORKER_RAM_MB (128), SH2_WORKER_CAP, SH2_TARGET_LOAD (0.9).
> - v25: **`named_blocks` on the A1 `Function` node** (core request
>   powershell-sh-go 20260813 — PowerShell begin/process/end blocks,
>   ESTree-path only). `IrStmt::Function` gained
>   `named_blocks: Vec<(String, Vec<IrStmt>)>`; serialized as
>   `"named_blocks": {"begin": [stmt], "process": [stmt], ...}`
>   (map key = `dynamicparam`/`begin`/`process`/`end`/`clean`; emitted
>   ONLY when non-empty, so all existing emits and the frontends'
>   byte-identical oracles stay byte-identical; unknown names REFUSE at
>   ingress). The estree lowering wraps the define arrow in PowerShell
>   execution order: dynamicparam → begin → process (once PER pipeline
>   input item — v1 text approximation: one run per line of stdin via
>   the new runtime helper `sh2.pipelineInputLines()`, gated in
>   estree_gate.pl + sh2-namespace.json) → end → body (PowerShell's
>   implicit end block) → clean. Named-block functions are excluded
>   from the sync-call fixpoint (their arrow is always async; callers
>   stay on the async path). Other backends render `body` and ignore
>   the field. Gates: estree 521/521 (0 failed), perl 319 (unchanged),
>   cargo test --lib 248.
> - v24: **`Try` statement node in the A1 contract** (core request
>   py-sh-go 20260813 — Python try/except/else/finally, ESTree-path
>   only). `IrStmt::Try { body, excepts, else_body, finally_body }` +
>   `TryExcept { match_expr, as_name, body }`; serialized as
>   `{"type":"Try", body, excepts:[{"type":"TryExcept", match:
>   <expr|null>, as: <string|null>, body}], else, finally}` (empty
>   arrays when absent; byte-identical round-trip through
>   `--shir-in-estree`). The estree lowering emits standard
>   TryStatement/CatchClause/ThrowStatement: except arms become an
>   `e instanceof <match>` if/else-if ladder inside the single catch
>   (bare except = terminal else, no match = rethrow), a signal guard
>   (`!(e instanceof Error)` → rethrow) lets runtime BREAK/CONTINUE/
>   RETURN control signals pass through a Try untouched, `as` binds via
>   `sh2.setVar`, `else` becomes a post-try completion-flag block
>   (`__sh2else` — Python else runs only when the try body completed
>   WITHOUT raising; a handled exception skips it, and else-body
>   exceptions are not caught by this statement's arms), `finally` the
>   JS finalizer. All IR analyses/walkers and every backend handle the
>   node (non-ESTree renderers refuse loudly). Gates: estree 521/521
>   (0 failed), perl 319 (unchanged), cargo test --lib 246.
> - v23: **`--true64` — bash arithmetic is true 64-bit, off by default**
>   (core). The default bash lowering keeps JS Numbers — silently wrong
>   past ±2^53 (verified: `x=9007199254740992; x=$((x+1))` prints
>   …992). `--true64` runs `analyze_true64` (per-var ranges from
>   `analyze_var_ranges`): provably inside ±2^53 → Number (~1 ns);
>   self-RMW accumulator chains in loops (written only via plain
>   single-target Assigns, no function-locals) → **BigInt64Array slots**
>   (`__t64[k]`, V8's native int64 element arithmetic — ~1.8 ns/op,
>   BinInt64.md §7); everything else out-of-range → **BigInt values**
>   (Int64, the C-path lowering: BigInt reads, asIntN(64) wrap on
>   assign). Arith leaf-wrapping (BigInt literals, non-slot BigInt
>   reads) applied to IR arith AND test-string `$(( ))` operands;
>   BigInt test operands use `Number()` for equality ops (`0n === 0` is
>   false) and raw BigInt for relational; zero-divisor guards on div/mod
>   (`BigInt % 0` throws where Number gives NaN). Verified: 2^53+1,
>   2^63-1 loop with `n*3` (bash-exact 16677181699666569 vs the
>   default's …668), accumulator loop with slots. Gate: c-sh-go 86/86,
>   core tests green; default path unchanged (statics empty by default).
> - v22: **typed integers in shIR — int / long long / unsigned / sizeof**
>   (core + c-sh-go). F1/F2 of `docs/frontend-c-core-needs.md`, partially
>   landed: `IrType` gains `Int32/Int64/UInt32/UInt64` (serialized as
>   `{"kind":"Int32"}` etc., additive — the Float precedent) and the Arith
>   AST gains `Sizeof(IrType)` + `Cast { ty, arg }` nodes (JSON round-trip
>   + unit tests; every backend handles them: sizeof folds to 4/8, casts
>   are identity for widthless backends). The C frontend (c-sh-go) parses
>   the full type-specifier sequence (`long long`, `unsigned [int]`,
>   `unsigned long long`, `signed`), emits `var_types`, casts, and sizeof
>   (integer-literal suffixes stripped at the lexer). The C-executed
>   ESTree path lowers Int32/UInt32 with `| 0` / `Math.imul` / `>>> 0` and
>   Int64/UInt64 with BigInt (`BigInt("N")` exact literals,
>   `BigInt.asIntN/asUintN(64, …)`) per the BinInt64 benchmarks
>   (`benchmarks/i64/BinInt64.md` — the typed-array i64 fast path is
>   RMW-only, so general i64 expressions lower to BigInt rather than
>   BigInt64Array element churn); the native printf fold gains `%lld`/
>   `%llu`/`%ld` + `%u` (BigInt args bypass parseInt). Gate: c-sh-go
>   79/79 → 80/80 (t31_types.c: sizeof, i64 beyond 2^32, %u/%llu, (int)
>   narrowing — gcc == A1→ESTree→JS bit-exact). Core lib tests 236 pass;
>   ESTree corpus unchanged (8 pre-existing failures; no new ones — no
>   corpus file exercises the changed printf path). Still refused: typed
>   pointers, i64 conditions, u32 division in conditions.
> - v21: **c-sh-go v4 — the last refused rung, gate 74/74 → 79/79** (workspace
>   only — no core changes; frontend main.go + harness/outparam_to_returns.py).
>   The five documented refusals from v3, each pinned by a stdout example
>   (t75–t79): (1) runtime VALUE reads in CONDITIONS (deref/index/call/
>   prefix-inc in if/while/for/switch conds) — hoisted to temps; an if
>   hoists once, a while/for/do-while gets the refresh-and-guard structure
>   `while (1) { temps; if (!cond) break; body }` (the cond must
>   re-evaluate per iteration). t75: array-max loop, `while (*q < 3)` walk,
>   call in cond. (2) prefix ++/-- in EXPRESSION position (the value is the
>   NEW value — increment statement + plain read hoisted at the statement
>   level). t76. (3) multi-char literals (GCC big-endian packing). t77.
>   (4) READ+WRITE out-params (`*x = *x + 1`) — arithOperand now recurses
>   into bins (only the read subtree temps), and the transform treats a
>   read+write write-param as IN-OUT (keeps its input position, caller
>   passes the current value, the new value returns via the echo channel;
>   only write-ONLY params shift later positions). t78: bump + addout(&v, 5).
>   (5) switch MID-ARM breaks — a guarded `if (c) break;` keeps its guard
>   with an empty then and wraps the remainder of the merged arm in the
>   guard's ELSE (true guard exits the switch, false falls through); the
>   Goto/Label route was tried first but the shared RestructureGoto handles
>   one goto per label and removes it — multiple break-gotos to one label
>   panic the renderer. t79. Also hardened the Makefile gate against
>   root-owned stale /tmp files (local .gate-tmp + clean). Still refused
>   (honest): char ordering comparisons, pointer advance on array-derived
>   pointers, pointer declarators in multi-declarator lists.
> - v20: **c-sh-go v3 — mem-slice-2, multi-return, and the next rung, gate 68/68 → 74/74**
>   (workspace + submodule). Implemented the two core requests directly.
>   (1) mem-slice-2 (c-mem-slice2): the arena was runtime-side; the missing
>   piece was the DYNAMIC position model — a pointer that is advanced or
>   comparison-used carries its position in a dedicated runtime handle var
>   (ptrNeedsDyn pre-scans at the declaration; the while-header cond is
>   emitted BEFORE the body's advance, so a compile-time offset could
>   never advance per-iteration). `p = p + n` / `p++` / `p += n` → runtime
>   memAdvance (new handle with the embedded element offset); `p < end` →
>   runtime memTest (position compare); reads/writes go through the
>   embedded offset; the root var keeps the base `:0` handle (pointer-copy
>   semantics). t69 walk-sum, t70 store-walk. (2) multi-return
>   (c-multi-return): the out-param transform handles MULTIPLE
>   write-targets — each write-param's last store becomes an echo (one
>   value per line), dropped write-params' bindings are removed with later
>   read-params renumbered, and the caller captures once and destructures
>   via the runtime `line` helper (the core renders `line` NATIVELY so the
>   destructure takes the native store-write path — a lifted destructured
>   var would desync from a runtime store write; also fixes the vacuous
>   string-lift of source-less vars). Mixed shapes work (write + read-only
>   non-pointer params, read-only pointer params). Statement-position user
>   calls now emit fnCall (they were silently DROPPED). The gate pipeline
>   runs the transform on every emitted A1 (identity without out-params).
>   (3) next rung: calls/ternaries inside ARITHMETIC are now hoisted to
>   temps automatically (printf args, decl inits, plain/compound assigns,
>   for headers — a compound RHS is an implicit arith operand), and switch
>   FALLTHROUGH lands (a case body without a trailing break merges the
>   next case's arm — shared-body `case 1: case 2:` and fallthrough into
>   default included; mid-arm breaks stay stripped — documented). Still
>   refused (honest): calls/ternary in test operands, prefix ++/-- in
>   expression position, multi-char literals, multi-return with read+write
>   params, switch mid-arm breaks. ESTree corpus unchanged (521/532 — the
>   pre-existing grepMatches WIP + env drift failures).
> - v19: **c-sh-go v2 — the fnCall-value fix + the v2 idiom set, gate 57/57 → 68/68**
>   (workspace + submodule). Fixed the SILENT-0 function-call corruption (a
>   runtime user call in a value position emitted A1 `fnCall` — the shell
>   STATUS channel — and printf got 0 while gcc got 10): the frontend now
>   emits `fnValue` for value-position calls, the runtime gains the
>   value-returning `fnValue` dispatch (same positional/RETURN-signal
>   handling as fnCall, the define-arrow's native return comes back), and
>   the perl backend already rendered the same A1 as a direct sub call.
>   Then landed the v2 idiom set, each pinned by an executed-stdout example
>   (t58–t68): runtime function calls (multi-param/multi-stmt/nested),
>   multi-declarator `int a, b;`, compound assignments `*= /= %= <<= >>=
>   &= |= ^=`, prefix `++i`/`--i` (statements + for headers), char
>   literals with STRING test semantics (`=`/`!=` — `-eq` would coerce
>   both sides to 0), bitwise `& | ^ ~ << >>` (native int32 JS ops;
>   `~x` → `x ^ -1`), bitwise/mod in CONDITIONS via the runtime `testArith`
>   (bash-arith truth — the test-string grammar is comparison-only),
>   ternary via the runtime `ternary` call (native-first cond), dynamic
>   array writes `a[i] = v` in loops via the runtime `arrayStore` call
>   (the baked `a[$i]` target would read a stale store for lifted index
>   vars), and dynamic heap indices `p[i]` read+write (mem-arena offsets
>   as runtime arith calls). Also fixed a per-run state leak in
>   `frontends/c-sh-go/main.go` (arrayVars/scalarAliases/ptrTargets/
>   charPtrVars/userFuncs were never reset for in-process parses) and
>   cleared the queue: the two c-sh-go regression requests
>   (c-sh-go-20260809-131354/134020) are RESOLVED — their fix landed as
>   sh2perl 5c717a7 — moved to done/ with OUTCOME markers, and the
>   sleeping-c-sh-go marker is removed. ESTree corpus gate A/B-verified:
>   identical 521/532 with and without the core changes (the 11 failures
>   are the estree worker's uncommitted grepMatches WIP + env drift —
>   pre-existing, not this work). Refused still (honest): calls/ternary/
>   bitwise inside ARITHMETIC or test operands (lower to a temp),
>   dynamic pointer advance, multi-out-param functions, switch
>   fallthrough, multi-char literals.
> - v19: **Perl corpus 459 → 472/532 — redirect order, set -e, native cmp,
>   echo|tr lift, process-sub fixes** (workspace, submodule 98df802/d11da89).
>   Follow-up to the v18 survey: (3) redirects now apply in SOURCE order —
>   a `2>&1` before `>file` dups the ORIGINAL stdout (the ESTree backend
>   already passed because it lowers redirects to an ordered spec list; the
>   Perl generator hardcoded stdout-then-stderr), and stderr dups use
>   explicit fd save/restore (`local *STDERR` rebinds the Perl handle
>   without dup-ing OS fd 2, so bash children ignored it); (7) `set -e`
>   top-level errexit (`exit $CHILD_ERROR if $__set_e && $CHILD_ERROR != 0`
>   after Simple/Test/Pipeline/Redirect statements, condition contexts
>   exempt); (9) native GNU-format `cmp` emulation (-s/-l/-b/-n/-i, octal
>   bytes, process-sub operands) — check_qx forbids system(cmp); (4)
>   `echo X | tr` in command substitution is now native Perl, so function
>   positional args map naturally (the function-body `$1`→`$_[0]` rewrite
>   is quote-aware, skipping shell-out literals); (1) process-sub shell-outs
>   now resolve the temp-file vars (exported to the child env, unescaped in
>   the reconstruction) — fixes the whole diff/comm-vs-`<(...)` class
>   (012/042/083/064_01/063_14/process-substitution); subshell env snapshots
>   use the @ sigil for indexed arrays (064_hard_to_generate compiles and
>   runs, matching bash except the documented $HOSTNAME line); (8) otranspilerl-cli
>   reads scripts lossily-with-PUA-markers and string literals re-emit
>   non-UTF-8 bytes as `\xNN` byte escapes (utf8-non-utf8-content passes —
>   bash treats scripts as byte streams); also `ls -A` shows dotfiles minus
>   . and .., `readlink -m/-f` canonicalizes missing paths.  Created
>   BASH_ENV_FAILURES.md documenting the deliberately-deferred bash-runtime
>   introspection class ($-, $BASH_VERSION, HOSTNAME, tty); `bash -n`
>   confirmed to reject all five parse-fallback files (they are genuinely
>   invalid bash — the harness FAIL is the parser-gap gate, not a
>   translation bug).
> - v18: **Perl corpus 420 → 459/532 (39 fixes, zero regressions)** (workspace,
>   submodule 2108602). One session of Perl-generator translation fixes:
>   parser — test-expression `\${var#pat}` no longer drops the closing `}` when
>   the `#` lexes as a Comment, and `--x="\${VAR}"` keeps the value as a real
>   interpolation; test-expression renderer — `\${var#pat}/\${var%pat}/...`
>   render to real Perl, numeric compares reproduce bash's empty-unquoted
>   expansion collapse (`[ -gt ]` single-arg → TRUE) for single-bracket tests,
>   `==`/`=~`/`!=` operands convert vars + strip pattern quotes, `\${var:?err}`
>   prints to stderr and exits 1 (plain `die` was swallowed by the harness's
>   `do`-wrapper); heredoc bodies — Perl single-quote escaping doubles
>   backslashes first (fixes `'\''` sequences), `\${#s}` → `length()`,
>   `\${s//p/r}` substitution + shortest-suffix reverse trick in the words
>   path; statements — top-level `[ ]` sets `$CHILD_ERROR`, `&&`/`||` chains
>   propagate status to `exit ($main_exit_code || $CHILD_ERROR)`, `exec cmd`
>   runs then exits, `true`/`false` set `$CHILD_ERROR`; pipelines — shell-outs
>   export referenced vars to the bash child, empty pipeline output prints
>   nothing, grep -c capture returns the result, grep -L exits per GNU
>   semantics, bare globs stay unquoted for bash expansion; `printf %q`
>   emulation; `-w` uses lookarounds not ``. Also synced SYNC_BUILTINS with
>   data/sh2-builtins.json (`.`, `source`) so the a4 sync test passes. The
>   commit also carries the pre-existing in-flight worker WIP (c-frontend Go
>   shir path, cfront.rs removal, var_nospace) already in the working tree.
>   ESTree backend unchanged (521/532, no regression).
> - v17: **c-sh-go fleet unblock — 26/31 → 30/31, t23 float arith filed**
>   (workspace). Killed the c-sh-go worker, made the non-estree-core
>   changes, restarted it. c-sh-go (Go) gate at 30/31: t23 float is the
>   one remaining failure (core-side float-arith path needed — see
>   `core-requests/c-sh-go-float-arith-20260807.md`). New
>   `frontends/c-sh-go/main.go` work in this session: float-literal
>   lexing (`1.5` → single num token), `double`/`float` type-keyword
>   handling, `testExpr` top-level-id `-ne 0` (C numeric truth vs bash
>   string-non-empty), `wrapForContinues` for `for`/`continue`
>   interaction (the trailing-update bug — the for-lowering puts the
>   update at the END of the body so a shell `continue` would skip the
>   update, infinite-looping the test; fix: wrap each top-level continue
>   in the for-body with `{update; continue}`), `Label`/`Goto`
>   parser emission (with flat list-return flattening in
>   `stmts()`/`stmtOrBlock()` so labels stay at the same level as the
>   surrounding stmts — `RestructureGoto` scans top-level labels only).
>   Shared-core fix in `sh2perl/src/shir_passes/restructure.rs`:
>   `RestructureGoto::handle_nested` was adding `if (flag) break` to the
>   parent at EVERY loop step including non-loop parents (Block-wrapped
>   for-bodies, like c-sh-go emits) — a `break` that escapes every
>   enclosing `whileLoopSync` and aborts the program. Added
>   `is_loop_stmt_at` to guard only real loops (While/For/DoWhile) and
>   added a regression test. ESTree corpus: **531/531 (100%)** (was
>   525/531) — the t30 nested-goto test in the ESTree corpus was
>   silently failing for the same reason; my fix improves the shared
>   library. shir_passes test count 55→56 (new
>   `nested_goto_through_block_wrapper_does_not_escape`).
> - v16: **`$0` = argv0 pass-through — the corpus stays stdout-pure; new
>   argv0 conformance suite** (workspace + submodule). Decision: a translated
>   script's `$0` is its own invocation path (like bash's), not a constant;
>   the stdout-match corpus can only bless ONE invocation, so `$0` semantics
>   are pinned by `harness/argv0-tests/` — every $0 script × 3 argv0s (full
>   path / basename-only / renamed) × {bash ref, sh, estree, perl} must
>   agree (72/72 green). Five incidental-`$0` examples (lexer/param-`##`
>   tests where `$0` was just a convenient variable) rewritten to
>   deterministic vars and stay in the corpus; the `$0`-centric ones
>   (057_case usage line, qx-var-builtin-cd self-location) stay in the
>   corpus AND are referenced from the suite. Perl: dropped the
>   `set_original_script_name` bake (`$0 = 'basename'` was an oracle-tuned
>   constant that broke `dirname "$0"` and ignored runtime argv0); `./fail`
>   + `./fail-estree` now run the generated Perl through a `do` wrapper that
>   sets argv0 = the source path (what `bash '$test_file'` sees) and empties
>   @ARGV. Old-generator echo fix: bare `$0`/`$1`/… in echo rendered as
>   `$ENV{0}`/`$ENV{1}` (never set) in four echo renderers — now `$0`/`$ARGV`.
>   Both semantics are now SELECTABLE: `otranspilerl-cli --argv0-source <name>` bakes
>   the source name into the output (Perl `$0 = '<name>'`; estree emits a
>   leading `sh2.argv0 = '<name>'` assignment) — the translation-product
>   semantic (the JS shell executing foo.sh should say "foo.sh", not the
>   temp JS file name) — while the default stays argv0 pass-through (the
>   harness supplies argv0 at run time). The argv0 suite tests BOTH:
>   108/108 (72 pass-through + 36 source-mode).
>   sh gate: the render now runs with argv0 = the source path
>   (`sh -c '. /dev/fd/3' "$f" 3< render`) so $0-examples stop failing (and
>   stop being flaky — the temp name varied per run). Corpus: PERL 401→414
>   (the $0-centric examples flip from FAIL to PASS), ESTREE unchanged
>   (the 1 tty-cmdsub flake is pre-existing environment drift).
> - v15: **renderer v3 — 304/531, env-export for shell-outs, var-export
>   correctness bug, function/case/param/subshell semantics** (workspace,
>   submodule 283→304: 12 commits). The `bash -c` shell-outs embedded Perl
>   vars as `"$var"` — unset in the child (silently broken: `grep -m 1` on
>   empty input, `rm` of literal names); `emit_shell_cmd` now scans the
>   command for `$name` and emits `$ENV{name} = $name;` first. Also:
>   `test || cmd` tail negation (regression from the chain rewrite),
>   `(( ))`/`let` arith conditions → native booleans, subshell copy
>   semantics (save/restore assigned vars), `local NAME=\$N` (positional
>   refs, split-word values, quotes), case patterns strip source quotes,
>   fn-call args flatten the Array, setArray skips the name arg, `#`/`##`
>   shortest/longest (non-greedy globs), `%/%%` with `C*` last/first
>   occurrence, shopt nocasematch runtime flag, `$longline`-style env
>   capture vars. Metric (stdout-only): 283 → 304/531 (57%). Corpus gate:
>   no regressions from this work (the 3 Generator-path failures are the
>   estree worker's uncommitted shir.rs WIP).
> - v14: **shir_to_perl renderer work continues — 283/531 vs bash
>   (stdout-only, matching the fail gate); bash-free for 20 commands**
>   (workspace, submodule 224→283: 9 commits). The Generator's per-command
>   in-Perl emulations are REUSED on the IR path for a verified whitelist
>   (seq/ls/wc/cat/tail/grep/tr/mkdir/rm/touch/basename/dirname/pwd/date/
>   hostname/paste/tee/which/yes): reconstruct shell text from IR words,
>   re-parse into a SimpleCommand, run the Generator's dispatcher — no bash
>   dependency for those; `DEBASHC_IR_NO_EMUL=1` A/B toggle (parity both
>   ways; cp/mv excluded — their emulations croak where bash errors).
>   Renderer additions: flat `[[ ]]` tests (glob/=~/extglob → Perl regex,
>   test tokenizer splits bare `=`/`!=`, `$arr[idx]` operands), param
>   basename/dirname/%.-strip/case-mods/substr/slice with raw patterns,
>   for-loop var aliasing (bash keeps the last value; Perl's for restores),
>   herestring/heredoc in captures, Case if/elsif braces, pseudo-multidim
>   `matrix[0,0]` → hash keys, `$@` defaults, subshells render in place,
>   test-chain if/else (`(t && c1) || c2`), `~` expansion, and the `$`
>   escaping fix in bash -c shell-outs (q{} doesn't interpolate — bash must
>   see `$var` unescaped). Corpus gate: no regressions from this work (the
>   3 new failures are the estree worker's uncommitted shir.rs WIP, verified
>   by stash).
> - v13: **shir_to_perl renders the modern IR — the ShIR→Perl path works
>   end-to-end** (workspace, commits 09029ae/8eb49a6/cf1d76d/7bc474b/
>   60e4165). `ir_to_perl` renamed `shir_to_perl` (sibling of
>   `shir_to_estree`; the ShIR-consumer wrapper of the Perl backend, not a
>   parallel renderer — header documents the Generator-owns-text layering
>   and the `from_raw_perl` migration bridge). Dead scaffolding removed:
>   `perl_generator_fixed.rs` (empty/uncompiled), `mir.rs`+`mir_new.rs`+
>   `mir_words.rs` (commented out of lib.rs), `commands/mkdir.rs.bak`;
>   `mir_simple.rs` KEPT (live via the cli `--mir` command). The renderer
>   then gained the modern-node lowering `ast_to_ir` emits — `--shir` →
>   `--shir-in-perl` went from `unreachable!` panics on the first word to
>   **223/531 examples (42%) whose Perl compiles and matches bash
>   stdout+exit**: Call funcs (exec/echo/printf/cd/export/… builtins,
>   getVar/split/param/arith/brace/capture/captureWords/listVar/arrayIndex/
>   arrayLen/setArray/test/redirect/block), Array/Interpolate/Arith/Arrow,
>   test-string parser (`[ … ]` text → Perl booleans), Redirect (incl.
>   heredoc/herestring/`2>&1` dups), `&&`/`||` chains, Case→if-elsif glob
>   chains, Function→`sub` with `local @ARGV = @_`, bash word/glob/capture
>   reconstruction for shell-outs (nested `$(…)`, SH2GLOB, braces), preamble
>   ($main_exit_code/$CHILD_ERROR/$__argc + hoisted `my` declarations incl.
>   test-string and array reads, `$1`→`$ARGV[n]`). External commands shell
>   out via `bash -c` (matching bash stdout by running the same tools — the
>   Generator's in-Perl emulations are not needed on the IR path).
>   Verification: `harness/ir-perl-metric.sh` (corpus metric); Perl corpus
>   gate unchanged (no new failures; the 97→96 delta is the known
>   /tmp-flaky `100_pipeline_failure_basic`).
> - v12: **frontend ladder t53–t61 + array-base design decision** (workspace).
>   New testdata across all six frontends (9 features × 6 languages): param
>   default, string substitution, array element write, array append, array
>   count, seq-range for, until loop, grep→contains idiom, while-read loop.
>   Every file probe-verified through the core (`otranspilerl-cli --shir` emits valid
>   A1 + estree-runner == native stdout) before landing; native oracles
>   confirmed for all 54. Go wrapper (`frontend-stdout.sh`) gains `strings`
>   import detection. **Decision — array base (0 vs 1): canonical 0-based in
>   shIR.** Frontends normalize subscripts at emit (zsh/fish `-1` on positive
>   literals AND dynamic indices and writes; bash identity; negative indices
>   are base-invariant — `a[-1]` means last everywhere; counts are
>   base-independent). No base annotation in the contract; executors/backends
>   stay language-blind. Rationale: shIR JSON is consumed by backends without
>   the source language (only the estree runner gets `--source`), so raw
>   subscripts would force every backend to reimplement the offset; the
>   runner's `lang === 'zsh'` branch is exactly that smell — and it already
>   misses the write path (zsh `a[2]=X` writes 0-based, breaking the
>   executed-stdout oracle). Fish already emits normalized subscripts (its
>   t21 works with zero runner support) — the proven pattern. Consequence:
>   drop the runner's zsh branches; zsh's byte-equality oracle waives array-
>   subscript files (byte-equality is a conformance net only where the core
>   parses faithfully; executed-stdout is the semantic anchor, per §8).

>   (`shir_to_c` bin over the `--shir` contract; `estree_to_c` retired —
>   ESTree JSON is the JS runtime's contract, "wrong shape for everyone
>   else") consumes `for i in $(seq A B)` as `Array([Range])` / bare
>   `Range` / pre-lift captureWords → native `for (<width> i = a; i <= b;
>   i++)`, wires `range_width_name` (u32/i32/i64 when the var AND every
>   arith expr mentioning it provably fit), inlines `contains` → strstr,
>   and emits no helper shims (hand-written idiom). Demo:
>   `show_sqrt_langs.sh` runs sqrt1337.sh through every backend, diffed vs
>   bash — today c/js/sh pass; perl blocked by a genuine seq-for bug, go/
>   rust/python by the unlanded `Array([Range])` unwrap + `contains`
>   inlining (core-requests: perl-20260806-sqrt1337-seq-for.md,
>   contract-20260806-array-range-iter.md; contract §5.6 documents the
>   iter shapes + per-language lowering).
> - v10: **const/var analysis + markup** (main 1c372fd/a85f46c/4065360/
>   cfb98fa; backend/c 2df5cf5). `shir::analyze_var_const` gives every
>   assigned variable a conservative `Const`/`Var` verdict: `Const` only
>   for a single static assignment site that runs at most once (outside
>   loops/function bodies) and is never a runtime-store write
>   (`read`/`readarray`/`mapfile`/`unset`), a `let`/`(( ))` statement,
>   native arith (`x++`, `((x=1))`), an array-element write (`arr[1]=z`
>   incl. the index-baked-into-name lowering), or a dynamic write
>   (`eval`/`source`/`.` anywhere → every var `Var`); everything else is
>   `Var` (over-conservatism is the safe direction). Markup:
>   `IrProgram.var_const: Vec<(String, VarKind)>` serialized in the ShIR
>   JSON (`var_const: [{name, kind}]`, sorted, round-trips through
>   `shir_json_in`, unknown kinds rejected) and carried on `PassContext`
>   (`const_vars`/`is_const`) by the first REAL shir_passes pair —
>   `analysis::ConstVar` + `transform::ConstMarkup` — wired into the
>   canonical pipeline (which now runs its transforms on a clone and
>   returns the post-pipeline program). shir_passes was an orphan module
>   (declared nowhere in lib.rs; its 24 stage-0 tests never ran) — now
>   compiled, 24 shir_passes + 11 const_analysis tests green. C backend:
>   `Const` vars whose single assignment is a top-level literal `Assign`
>   render as `const` declarations initialized from the literal (numeric
>   Str parsed per the lift's criterion), the Assign stmt dropped;
>   verified gcc-clean over the corpus (zero new failures) and
>   byte-equal vs bash. Corpus gates byte-identical vs the pre-work
>   baseline: PERL 436/95, ESTREE 525/6 at 531 examples.
> - v9: **Loop fixpoints in the length + range analyses** (`bf3d6b2`). The
>   range-analysis spike killed every loop-carried variable (loops → Any);
>   now a `while [ $i -lt 100 ]; do i=$((i+1)); done` counter lands in
>   [lo, 100] via a widened fixed-point (outward bounds → ±i64, bash's
>   wrap) pulled back by the cond's entry invariant (`until` flips, `let`
>   arith conds) and by trip counts for the other counters
>   (i ≤ pre_lo + trip·step); for-loops bound the loop var by the integer
>   items / Range. The length analysis tracks per-assignment max executions
>   (the product of enclosing loop trips): a single-execution
>   `s="$s$x"` is bounded by |x| (the flat fixpoint grew it to None), a
>   bounded loop gets v0 + trip·Δ, unbounded stays None; numeric
>   accumulators cap at the fixed number/capture width; the runtime
>   `assign` calls (`v+=k`) participate in both analyses. Corpus:
>   range_proven 40 → 51, files_with_narrow 20 → 26; length bounds
>   byte-identical (correctness tightening — the corpus has no
>   single-execution self-accumulations); Perl gate 436/95 unchanged.
>   Follow-up (`8690206`): ranges now store `(i128, i128)` over an
>   explicit frontend integer domain — bash's i64 wrap is a *parameter*
>   (`INT_DOMAIN`), not baked into the storage; the width table gains a
>   u64 bucket (fires only past i64::MAX, i.e. C-frontend unsigned
>   values); bash behavior byte-identical (50/0/1 tally). C-frontend
>   remainder: `IrExpr::Int` past i64, cfront literal parsing, per-var
>   domains from `var_types`.
> - v8: **lifetime analysis pass (`VarLifetimes`).** New
>   `shir_passes/lifetime.rs`: per-variable live spans `(first, last)`
>   in a pre-order statement walk + a conservative escape set
>   (array-element stores, closure captures, function returns;
>   subprocess boundaries are uses, not escapes — the kernel copies).
>   Wired into the canonical pipeline; `PassContext` gains
>   `var_live_ranges`/`var_escapes`; `IrProgram.var_lifetimes` +
>   ShIR JSON `var_lifetimes` serialization (beside `var_types`/
>   `var_lengths`/`var_const`; round-trip through `shir_json_in`). The
>   C backend's fixed-buffer transform (`char v[N+1]`) is only sound
>   with per-point knowledge — the seed analysis answers where a
>   buffer may live and how long it must survive; the full version
>   (per-point bounds, copy-vs-move, malloc/free placement, function-
>   return discipline) is backlog Task 2 for the estree worker.
>   Also: unblocked the build (is_variable_name call-site fix) and
>   completed the in-flight M9 const-migration compile (duplicate
>   test-struct fields, missing trait import). `cargo test --lib`
>   100 → 123.
> - v7: **C backend: length analysis + debug-only asserts.** The
>   `backend/c` worktree now consumes `var_lengths` (`analyze_string_lengths`,
>   fbedac4): bounded Str vars render as fixed `char v[N+1]` buffers, with
>   debug-only `assert(strlen(v) <= N)` at function boundaries and before
>   every buffer write (NDEBUG truncates). Core fix: `analyze_string_lengths`
>   infinite-recursed on single-stage filter captures (`$(basename $(pwd))` —
>   `capture_stages` returns the call itself) → stack overflow in `--shir`
>   blocked the C gate; fixed + depth-capped (resolves core-requests
>   c-20260806-102527.md). C gate completes: 25/539 render-clean + equiv-pass
>   vs bash, 506 stub-failures (draft's unfinished lowering), 4 equiv = core
>   gaps (`--shir` emits 0 stmts for double-quote-with-sed-inside.sh; parse-
>   error files can't reproduce bash's exit), 4 core-skip.
> - v1: ESTree → JS linked against a bespoke sh2runtime "compiled-script API".
> - v2: target C → wasm32-wasi. Rejected: C needs type inference + runtime lib;
>   WASI has no fork/exec (but see v3 note — fork isn't a semantic need);
>   sh2runtime's in-browser C compiler is unfinished.
> - v3: ESTree → JS; runtime surface = standard node `fs/promises` APIs +
>   one bespoke `exec`/`pipeline` seam; sh2runtime implements the seam over its
>   virtual FS. Fork/exec reframed: bash needs *copy semantics* (env/fd
>   snapshot, streams, exit code), not real processes — emulable everywhere.
> - v4: **the interface is ESTree JSON itself.** sh2perl emits JSON (standard
>   ESTree, shell semantics lowered to calls into a documented `sh2.*` runtime
>   namespace); executors do the rest. No submodule, no shared code.
> - v5 (current): **topology correction.** sh2perl *stays* a properly-registered
>   submodule of sh2loop (the workspace needs to modify it); sh2runtime is NOT a
>   submodule (ESTree JSON decouples it). One-way rule: sh2loop → sh2perl;
>   sh2perl never references sh2loop (e.g. its tracked `fail -> ../fail` symlink
>   must go).
> - v6: **native arithmetic in the ESTree.** `$((...))` lowers to standard
>   ESTree BinaryExpression/LogicalExpression/ConditionalExpression (rendered
>   as native JS) instead of a runtime string-eval `sh2.arith("i+1")`.
>   Decision (Q: "lower in the Generator rather than the ESTree?"): the ESTree
>   JSON is the cross-repo contract — standard nodes let sh2runtime execute
>   arithmetic without implementing a bash-arithmetic string parser, and the
>   printer stays a dumb syntax walker. Bash-faithful edges live in the
>   renderer: `Number(v)||0` coercion, `?1:0` for comparisons/logicals,
>   right-assoc `**`, `Math.trunc` integer division, and zero-divisor → whole
>   expansion aborts (`sh2.idiv`/`sh2.imod` throw inside `sh2.arithEval`).
>   Assignments (`x+=`, `x++`) still fall back to `sh2.arith` (setVar
>   semantics).

---

## 0. Current state (verified facts)

| Component | State |
|---|---|
| `/nvme/ai/sh2loop` (superproject) | Git repo, branch `master`, **no remotes**; hosts test infra (`fail`, `check_qx.pl`, `main_loop_rust.pl`) |
| `sh2perl` entry in superproject index | gitlink (mode `160000`) at `09f6a4f6`, **no `.gitmodules`** → broken/unofficial submodule |
| `sh2perl` (primary repo) | origin `git@github.com:gmatht/sh2perl.git`, own CI (`.github/workflows/test.yml`); working tree at `febb301`, dirty scratch files; **tracks a `fail -> ../fail` symlink** (violates the one-way rule — must be removed) |
| `sh2runtime` | exists at `gmatht/sh2runtime`; node v22 available; already runs async JS commands + `.js` files in `/commands/` against its virtual FS; WASI via `@wasmer/wasi` for third-party wasm tools |
| sh2perl backends | Perl only. `src/ir.rs` = Perl-specific IR with `RawText` bridges; `pub mod mir` commented out. **ESTree emitter exists** (`sh2perl core::estree::ast_to_estree_json`, v0 `sh2.*` namespace) and passes the full corpus. Workspace layering: `sh2perl core` (core lib) ← `otranspilerl` (CLI lib, member `cli/`) ← `otranspilerl-cli` (3-line bin). WASI: `build-wasi.sh` → `otranspilerl-cli.wasm` (command, `_start`) + `sh2perl core.wasm` (library, `wasi-lib` feature, C-ABI `debashc_to_perl`/`debashc_to_estree`) + **`otranspilerl.wasm`** (library, `wasi-cli` feature, C-ABI `debashc_cli_run(_json/_with_input)` — the full CLI as a library call, "otranspilerl-cli in three lines of JS"; deployed with README + examples to `~/js/`). |
| Tests | `fail`: otranspilerl-cli → Perl → `check_qx.pl` gate → run vs `bash` → normalized stdout + side-effect compare. 516 examples, **PERL 432/84, ESTREE 516/516 (100%)**. `fail-estree`: perl + estree verdicts per example (Stage A); `--gate` Stage B (strict: a failing test is a bug — no failing-test allowlist; the M5 blessed-fail list was removed as a guardrail violation, see revision history); `--metric` sh2.* call-site tallies (improvement-mode awareness). |

Key docs:
- `sh2perl/docs/ir-design.md` — Perl IR + "two-layer IR (future)" (ShIR between AST and language IRs).
- `sh2perl/docs/AST.md` — the shell AST that feeds everything.
- `sh2runtime/docs/architectural-considerations.md` — §3/§5 ESTree as leaf backend; §7 Common ShIR; §9 JS-first backend order.
- `sh2runtime/README.md` — virtual FS + tinysh JS-command model (`.js` files are the "compiled binaries").

---

## 1. Repo topology: sh2perl stays a submodule; sh2runtime does not

### 1.1 The dependency rule (one-way)

- **sh2loop → sh2perl:** the workspace depends on and *modifies* sh2perl (the
  harness drives otranspilerl-cli, blesses examples, bumps the gitlink). sh2perl is a
  **properly registered submodule** of sh2loop.
- **sh2perl → sh2loop: forbidden.** sh2perl must never reference or write into
  the workspace. Concretely: remove the **tracked `fail -> ../fail` symlink**
  from sh2perl (it dangles when sh2perl is cloned standalone); the workspace
  provides its own `fail`. sh2perl's CI stays self-contained (cargo tests).
- **sh2perl ⇄ sh2runtime: no code coupling.** The interface is ESTree JSON
  (1.2); sh2runtime is **not** a submodule. Test-time coupling is by commit SHA
  in CI (1.4).

### 1.2 The contract

- **sh2perl emits standard ESTree JSON** (`otranspilerl-cli --target estree file.sh`). No JS
  text, no `@babel/generator` inside sh2perl, no imports into sh2runtime — it's
  a pure data emitter.
- Shell semantics are expressed in the ESTree as calls into a **documented
  `sh2.*` runtime namespace** (the only non-standard part is the *name set*,
  not node types): `sh2.fs.readFile`, `sh2.fs.writeFile`, `sh2.fs.stat`,
  `sh2.exec`, `sh2.pipeline`, `sh2.redirect`, `sh2.capture`, `sh2.exit`,
  `sh2.getVar`/`sh2.setVar`... File tests lower to `try/catch` +
  `sh2.fs.stat`; pipelines lower to `sh2.pipeline([...closures])`; command
  substitution lowers to `await sh2.capture(...)`.
- **The consumer owns the spec.** sh2runtime's repo hosts `docs/estree-api.md`
  defining the namespace (names, signatures, semantics, error codes — node
  `.code` style: `ENOENT`, `EISDIR`). sh2perl targets that doc, pinned by SHA
  in CI (1.4). This is the same "consumer defines the API" pattern as any
  client/server split.

### 1.3 Register sh2perl as a proper submodule (workspace fix)

The gitlink exists but `.gitmodules` is missing — register it (from
`/nvme/ai/sh2loop`):

1. Settle sh2perl's working tree: commit/stash `.last_trusted_count`;
   gitignore or remove scratch files (`__tmp_run_*.pl`, `"$f"`, `001`, ...)
   so the submodule stays clean.
2. Remove the tracked `fail -> ../fail` symlink from sh2perl (commit the
   deletion there).
3. Add `.gitmodules`:
   ```ini
   [submodule "sh2perl"]
       path = sh2perl
       url = git@github.com:gmatht/sh2perl.git
   ```
4. Fast-forward the gitlink to the current HEAD (`febb301`, a descendant of the
   recorded `09f6a4f6`): `git add sh2perl .gitmodules`, commit.
5. `git submodule init`; confirm `git submodule status` clean.

No sh2runtime submodule is created anywhere.

### 1.4 Cross-repo CI pinning (replaces the missing sh2runtime submodule)

- **sh2perl CI** stays self-contained: cargo tests, purify, perl-critic — no
  external checkouts.
- **sh2loop CI** (needs a remote first): checks out the submodule, builds
  otranspilerl-cli, runs `fail` + `fail-estree` (the corpus gate).
- **sh2runtime CI**: checks out `gmatht/sh2perl@<sha>` to pull corpus fixtures
  + expected outputs; validates the ESTree it consumes is exactly what sh2perl
  emits (schema + round-trip), then runs it against the virtual FS.
- Optional once sh2runtime ships its executor: a sh2loop CI job checks out
  `gmatht/sh2runtime@<sha>` and runs the same corpus against the virtual FS.

---

## 2. Test gate: "passes only if the ESTree passes the corpus"

### 2.1 Target semantics

Two executors consume the same ESTree JSON; both must agree with `bash`:

```
test.sh ── otranspilerl-cli ──► Perl ───────► perl <tmp/test.pl> ───────────► stdout ──► vs ──► bash
   │
   └── otranspilerl-cli --target estree ──► test.estree.json
                              │
              ┌───────────────┴────────────────┐
              ▼                                ▼
   Reference executor (sh2perl CI)   sh2runtime executor (their CI/browser)
   ESTree→JS via @babel/generator    ESTree→JS (or direct tree-walk)
   + node fs/promises + child_process + sh2.* → virtual FS + command registry
              │                                │
              ▼                                ▼
          stdout ──► vs ──► bash          stdout ──► vs ──► bash
```

- **sh2loop CI** validates transpiler correctness with the reference executor
  (real node `fs`, real `child_process` — full process semantics, same coverage
  as the Perl backend).
- **sh2runtime repo** validates the browser path against the virtual FS. The
  "only pass if linked against sh2runtime" semantics is satisfied by *both*
  executors agreeing on the same ESTree; sh2perl doesn't block on sh2runtime.

Rollout (do **not** gate on the new backend on day one — it starts at ~0% vs
426/517 Perl):

- **Stage A — parallel metric:** `fail-estree` runner records
  `{file, perl: PASS/FAIL, estree: PASS/FAIL, reasons[]}`; no gating.
- **Stage B — per-test gate:** green only when `perl == PASS && estree ==
  PASS` — strict: a failing test is a bug. (The M5 `blessed-fail-estree.txt`
  failing-test allowlist was REMOVED — it hid 84 perl transpiler bugs behind
  "known limitations"; `--bless` is gone. "Bless" now means ONLY the examples
  snapshot pin, `update_blessed.sh` → `ensure_examples_snapshot.pl`.)
- **Stage C — hard gate:** remove the allowlist. End state.

### 2.2 otranspilerl-cli side: `--estree` output mode

1. New `src/estree.rs`: ESTree node structs with `#[derive(Serialize)]`
   (`Program`, `ExpressionStatement`, `CallExpression`, `TemplateLiteral`,
   `ArrowFunctionExpression`, ...). Emit **standard ESTree only** — all shell
   semantics lowered to `sh2.*` calls (1.1), never custom node types.
2. `shir_to_estree()`: `ShIR → ESTree` lowering per
   `architectural-considerations.md` §5/§9, with targetings:
   - `FileTest` → `try { await sh2.fs.stat(p) } catch (e) { e.code ===
     'ENOENT' }`
   - `Redirect` → `sh2.redirect(fd, mode, target)`
   - `CommandSubstitution` → `await sh2.capture(...)`
   - `Pipeline` → `sh2.pipeline([...])`
   - variables/arith/strings → `sh2.getVar`/`sh2.setVar`/standard literals+ops
3. **Structural gate (deterministic):** validate emitted JSON — (a) against an
   ESTree schema (any standard ESTree validator), (b) every callee is in the
   `sh2.*` whitelist, (c) no `eval`/`Function`/dynamic import, (d) no `*Sync`
   calls (browser can't block — async-only codegen with top-level `await`).
   Replaces `check_qx.pl` for the JS side.
4. **Determinism check:** same input → byte-identical ESTree (mirrors the
   existing example-blessing determinism workflow).

### 2.3 Reference executor (sh2loop's harness)

`harness/estree-runner.mjs` in the sh2loop workspace (alongside `fail` and
`check_qx.pl` — the harness belongs to the workspace, not to sh2perl):
- ESTree JSON → JS text via `@babel/generator` (pinned devDep).
- Provide the `sh2.*` namespace for node: `sh2.fs.*` → `node:fs/promises`,
  `sh2.exec`/`sh2.pipeline`/`sh2.capture` → `child_process`
  (spawnSync/execSync/pipe), `sh2.exit` → `process.exit`, `$?`/`$CHILD_ERROR`
  → tracked exit codes.
- Run under node with a temp cwd; capture stdout; compare vs `bash` with the
  same normalization + side-effect checks as `fail`.
- Doubles as the reference implementation of the `sh2.*` spec — testable in
  the sh2loop harness before sh2runtime ships anything.

### 2.4 sh2runtime side (their repo, out of scope for sh2perl CI)

- Publish `docs/estree-api.md` (the `sh2.*` namespace spec — 1.1).
- Consume ESTree: generate JS via `@babel/generator` (pure JS, fits their
  no-build-step style) or interpret directly; map `sh2.fs.*` → VirtualFS
  (node-compatible names + error `.code` semantics — their ramfs already
  throws `ENOENT: path`, needs the `code` property), `sh2.exec` → command
  registry (`.js` modules in `/commands/`), `sh2.pipeline` → async fd
  streaming, `sh2.capture` → async read.
- **Process model = emulation, not fork** (per v3 analysis): a "process" is
  `{env snapshot, fd table, cwd, args}` → run → streams + exit code → discard.
  Edge cases to handle explicitly: fd-table inheritance (`exec 3>file`),
  `trap`/`kill`/`wait`/`$!`, interleaved background output, synthetic
  `$$`/`$BASHPID`. Genuinely external tools (`ssh`, network) go on the blessed
  list until real wasm binaries exist (their `download-wasm-bins.js` covers
  grep/curl/etc.).
- WASI (`@wasmer/wasi` + wasmfs) stays for *third-party* binaries, not sh2perl
  output. (JS cannot call WASI directly — WASI is a wasm↔host interface and JS
  is the host; the only "JS on WASI" route is a JS engine compiled to
  wasm32-wasi, an optional future unifier.)

### 2.5 Harness changes (sh2loop workspace)

The reference executor and the gate runners live in **sh2loop**, alongside the
existing `fail`/`check_qx.pl` test scripts (sh2loop is the harness; it modifies
sh2perl — never the reverse):

- `fail` gains `--estree` mode (or a sibling `fail-estree`): `otranspilerl-cli
  --estree` → structural gate → `estree-runner.mjs` → compare vs `bash`.
- Stage B: `fail` returns PASS only when both verdicts pass; reasons tagged
  `[perl]` / `[estree]`.
- Parallel workers + timeouts identical to the current `fail`.
- `@babel/generator` is a pinned devDep of the sh2loop harness (or a `harness/`
  package), not of sh2perl.

### 2.6 CI

- **sh2perl CI** (`sh2perl/.github/workflows/test.yml`): unchanged — cargo
  tests, purify, perl-critic. Self-contained; no external checkouts.
- **sh2loop CI** (new workflow; requires adding a remote to the superproject):
  checks out the sh2perl submodule, builds otranspilerl-cli, runs `fail` + `fail-estree`:
  ```yaml
  - uses: actions/checkout@v4
    with: { submodules: true }
  - uses: actions/setup-node@v4
    with: { node-version: 22 }
  - run: cd sh2perl && cd otranspilerl && cargo build --bin otranspilerl-cli
  - run: ./fail                       # Perl baseline
  - run: ./fail-estree                # ESTree metric / gate
  ```
- Optional once sh2runtime ships: a job checking out `gmatht/sh2runtime@<sha>`
  and running the corpus against the virtual FS.

Badges mirror the existing perlcritic/purify pattern, adding `estree-tests`.

---

## 3. Universal IR: yes — evolve toward ShIR (not a third parallel IR)

### Recommendation

**Yes, move toward a language-neutral ShIR**, but by *generalizing the existing
`src/ir.rs`*, not by inventing a fresh IR alongside Perl-IR and the ESTree
emitter. Both existing docs already commit to this shape:

- `docs/ir-design.md` ("Two-layer IR (future)"): `Shell AST → ShIR → {Perl IR,
  Rust IR, ...}`.
- `sh2runtime/docs/architectural-considerations.md` §7/§9: Common ShIR with
  `Exec`, `Pipeline`, `If`, `Assign`, `Declare`, `Redirect`, `Read`, `Write`,
  abstract `FileTest`, no sigils, no per-language error handling.

With ESTree as the second consumer, the IR now feeds **two dynamically typed
backends** (Perl text, ESTree JSON) — no type inference pass needed (stays
parked until a statically-typed backend lands, per docs §8).

`src/ir.rs` is already ~80% language-neutral (`Output`, `Assign`, `Declare`,
`If`, `While`, `For`, `Pipeline`, `Return`). What is Perl-specific:

| Current (Perl IR) | ShIR change |
|---|---|
| `Sigil` on `Var`/`Decl` | drop from core; backends re-add (`VarSigil` optional annotation) |
| `StrStyle::{SingleQuoted, DoubleQuoted, Command, Heredoc}` | core = `{Literal, DoubleQuoted, Verbatim}`; `Command`/`Heredoc` become Perl-backend extensions (JS uses template literals) |
| `System { cmd, capture }` | `Exec { cmd, args, redirects, capture }` (language-agnostic) |
| `Index { var, key }`, `BinOp`, `Ternary`, `Call` | keep as-is (already neutral) |
| `RawText`/`RawExpr` | keep — explicitly designed as the migration bridge; it is *not* a defect |

### Sequencing

1. **Refactor-first:** generalize `ir.rs` → language-neutral ShIR. Perl backend
   becomes one consumer: `shir_to_perl()` (renamed `ir_to_perl`). All 517 Perl
   tests must stay green — pure refactor with `RawText` untouched.
2. **Add the second consumer:** `shir_to_estree()` + the reference executor
   (sections 1–2). The IR is only trustworthy once two backends consume it; do
   not build shared optimization passes before this.
3. **Shared passes (only after both backends exist):** constant folding, dead
   assignment elimination, unified import/require registry (replacing ad-hoc
   `needs_*()` booleans).
4. **ESTree stays a leaf backend** — a data emitter for JS consumers; never the
   universal IR (no ESTree→Perl/Rust/Python codegen exists).

### Open questions

- Separate `shir-rs` crate for future frontends (Batch/POSIX)? (Recommend: no,
  until a second frontend is real.)
- Does `--estree` belong in the `otranspilerl-cli` binary or a separate
  `otranspilerl-cli-estree` bin? (Recommend: same binary, `--estree` flag, so CI and
  users share one build.)

---

## 4. Milestones (dependency order)

1. **M1 — Register the sh2perl submodule:** settle sh2perl's working tree
   (gitignore/remove scratch files), **remove the tracked `fail -> ../fail`
   symlink from sh2perl**, add `.gitmodules`, fast-forward the gitlink to the
   current HEAD, `git submodule init`. No sh2runtime submodule — the ESTree
   JSON contract decouples it.
2. **M2 — Agent context (see §6):** `AGENTS.md` (sh2perl primary + workspace
   root pointer), `.pi/skills/sh2dev`, `.pi/prompts/` — future sessions inherit
   plan, status, conventions, guardrails.
3. **M3 — IR generalization (pure refactor):** `ir.rs` → language-neutral ShIR;
   Perl backend unchanged; 517 tests still pass; `RawText` intact.
4. **M4 — ESTree emitter + reference executor:** `shir_to_estree()` +
   `otranspilerl-cli --target estree`; `tests/estree-runner.mjs` (@babel/generator + node
   `sh2.*` namespace); structural gate (schema + callee whitelist + no `*Sync`);
   `fail-estree`. Stage A: parallel metric, zero gating.
5. **M5 — Gate:** per-test `perl && estree` verdicts. (A blessed-fail
   allowlist was added here and REMOVED as a guardrail violation — see the
   revision history. The gate is strict.)
   allowlist (Stage B), then hard gate (Stage C). CI badges.
6. **M6 — Shared passes:** constant folding / dead-code / import registry on
   ShIR once two backends are stable.
7. **M7 — sh2runtime consumes ESTree (their repo):** `docs/estree-api.md`
   spec, `sh2.*` → VirtualFS + command registry, run sh2perl corpus fixtures
   (pinned by SHA) against the virtual FS. Optional follow-on: engine-on-WASI
   (quickjs.wasm) as a unifying runtime layer.
8. **M8 — Worker improvement mode (post-Stage C):** when the ESTree corpus is
   green, `main_loop_estree.pl` stops idling and prompts the worker to find
   the **cheapest correct lowering** for every remaining `sh2.*` call site /
   spawn / async loop (the lowering ladder in §9). Metric (`fail-estree
   --metric`, total sh2.* call sites) is the commit signal; corpus green +
   determinism + gate are the gates. Success: total call sites decrease
   monotonically, corpus stays 516/516, `forLoopSync`/`cstyleForSync` and
   worker-invented native lowerings land.
9. **M9 — shir_passes shared library:** the sh2.\* boundary is the
   cut-down, not a per-backend shIR subset (kitchen-sink / cut-down /
   shared-library design decision). The sh2.\* namespace is the
   universal contract; the shared library is the locus of common
   lowerings (every backend benefits at once, the metric is the
   progress signal). Stage 0 = the new `src/shir_passes/` module
   scaffolded (`PassContext` struct replaces the ten `static
   Mutex<Option<…>>` globals in shir.rs; the `Analysis`/`Transform`/
   `PatternLift` traits and the `Pipeline` runner are real; the
   `Metric` tally is a first-class return value; the analysis/transform/
   lift implementations are stubs that return defaults; `cargo test
   --lib` 55 → 75). Stage 1 migrates the shir.rs analyses into the
   trait implementations (the M3 guardrail — Perl output is
   byte-identical — is the proof the migration is safe). Stage 2
   extracts the M8 pattern lifts from shir.rs into the new module.
   Design doc: `sh2perl/docs/ir-design.md` §"The sh2.* boundary".

---

## 5. Risks

- **Contract (format) drift:** the ESTree shape + `sh2.*` namespace must match
  between sh2perl and sh2runtime. Mitigate: consumer-owned spec doc; schema +
  whitelist validated on both sides; shared corpus fixtures; round-trip test in
  sh2runtime CI.
- **Sync vs async:** generated ESTree lowers to async-only code (`await`,
  top-level await, ESM). Enforce in the structural gate (reject `*Sync`
  callees). tinysh already runs async commands (`await fs.read(...)`).
- **Error semantics:** executors must throw node-compatible errors (`.code` =
  `ENOENT`/`EISDIR`/...) or `[ -f x ]` / `|| die`-style checks diverge between
  node CI and the browser. Their ramfs needs the `code` property added.
- **Reference executor ≠ sh2runtime:** node-CI and browser could disagree.
  Mitigate: the reference executor is the spec's reference implementation;
  shared fixtures; sh2runtime CI runs the same corpus.
- **Builtin/exec table is the real work:** `echo`, `ls`, `grep`, ... for the
  browser path (same logic the Perl backend encodes; tinysh's builtin object is
  the seed; ~30 builtins cover the corpus). Node CI side is free
  (`child_process`).
- **New backend starts at ~0%:** staged rollout + blessed-fail allowlist keeps
  CI honest.
- **Semantic drift between backends:** Perl and ESTree must match the *same
  normalized stdout contract*, not each other's output byte-for-byte.
- **IR refactor churn:** 90/517 failing Perl tests + stashed regressions — the
  refactor must be strictly output-preserving; keep `RawText` until proven.
- **`@babel/generator` dependency:** pinned devDep in sh2perl (reference
  executor) and sh2runtime (their executor).

---

## 6. Agent (pi) context — so future sessions know what's going on

A fresh pi session auto-loads only `AGENTS.md`/`CLAUDE.md` (global
`~/.pi/agent/AGENTS.md`, then parent dirs walking up from cwd, then cwd). It
will **not** read `PLAN.md` or `sh2perl/.cursorrules` (pi doesn't read Cursor
files). Today no `AGENTS.md`, `.pi/`, skill, or prompt template exists — every
session starts cold. This is a multi-session, multi-repo effort, so agent
context is part of M2.

Deliverables (primary at the sh2loop workspace root; sh2perl stays standalone):

1. **`/nvme/ai/sh2loop/AGENTS.md`** (workspace root — the primary doc for
   sessions working across the repos): the **one-way dependency rule** (sh2loop
   → sh2perl; sh2perl never references sh2loop), the submodule layout, "read
   PLAN.md first", current status (517 examples / 426 passing / gate stages
   A→C), harness commands (`./fail`, `./fail-estree`), and the guardrails
   (output-preserving refactors only, never bless a regression, check `git
   stash list`, never `git add .` — the tree is full of scratch files).
2. **`sh2perl/AGENTS.md`** (standalone — **no sh2loop paths or references**):
   build/test commands (`cd otranspilerl && cargo build --bin otranspilerl-cli`, `cargo test`), IR
   migration status (`src/ir.rs` → ShIR, `RawText` policy), `check_qx.pl` gate
   (external, invoked from the workspace), where the ESTree emitter lands
   (`src/estree.rs`), the `sh2.*` namespace contract.
3. **Skill** `.pi/skills/sh2dev/SKILL.md` (agentskills format): build → test →
   verify workflow (`cargo build`, `./fail`, `./fail-estree`, ESTree structural
   gate, submodule-free layout), loaded on demand.
4. **Prompt templates** `.pi/prompts/*.md` (optional): `/run-tests`,
   `/add-example`, `/bless-estree` (curate the allowlist).
5. **Migrate `.cursorrules`** still-relevant points into `AGENTS.md` so the
   knowledge isn't orphaned.
6. **sh2runtime side (their repo):** `docs/estree-api.md` referenced from a
   future `sh2runtime/AGENTS.md`.

---

## 7. Execution log

- **2026-07-31 — M1 done.** sh2perl registered as a proper submodule
  (`.gitmodules` + gitlink → `d18a506`); `fail -> ../fail` symlink removed from
  sh2perl (one-way rule); 65 tracked scratch artifacts removed + `.gitignore`
  patterns added; working-tree generator WIP (words.rs, pipeline_commands.rs,
  ir.rs, mod.rs, redirects.rs) committed as-is (compiles; full corpus 430/517
  passed, matching last committed baseline — no regressions).
- **2026-07-31 — M2 done.** `AGENTS.md` (workspace + standalone sh2perl),
  `.pi/skills/sh2dev`, `.pi/prompts/{run-tests,bless-estree}.md`.
- **Caveat:** a background `main_loop_rust.pl` is actively committing/editing
  sh2perl sources (repo moved febb301 → aa5df7a during M1). The gitlink will
  need re-bumping after that loop settles.
- **2026-07-31 — ESTree v0 emitter (M4 partial).** `sh2perl/src/estree.rs`
  (new; lowered from the raw AST to avoid the concurrently-edited `ir.rs`),
  `otranspilerl-cli --target estree <file.sh>` emits standard ESTree JSON with an `sh2.*`
  runtime namespace; unlowered constructs → `sh2.unsupported(...)` (valid,
  deterministic, gate-flagable). 8 unit tests pass. **Baseline metric
  (Stage A): 169/516 examples lower with zero unsupported calls.** Next:
  lower case/redirect/function/subshell/background, then the reference
  executor + structural gate + `fail-estree`.
- **2026-07-31 — ESTree lowering round 2 (M4).** `estree.rs` now lowers
  case (`SwitchStatement` + `sh2.caseMatch` glob dispatch), redirects
  (`sh2.redirect(() => cmd, [{fd,mode,target,interpolate?}])`, incl. heredoc/
  herestring/`2>` and redirects attached to simple/builtin commands),
  functions (`sh2.define`), subshell/background (closures), `shopt`,
  c-style `for`, command-scoped env vars (`VAR=x cmd` → optional third
  `sh2.exec` arg), top-level `[ test ]`, and compound commands in expression
  contexts (`&&`/`||` operands, pipeline stages, conditions — block-bodied
  arrows; `while` in conditions → `sh2.whileLoop`). Corpus metric (Stage A):
  **169 → 346/515 examples lower with zero `sh2.unsupported` calls; zero
  command-level unsupported constructs remain** (remaining unsupported is
  word-level: parameter expansion, arithmetic, brace expansion, arrays).
  22 lib tests pass. Next: word-level lowering, then reference executor +
  structural gate + `fail-estree`.
- **2026-07-31 — Security: strict allowlist (commit d84d84e).** External
  binaries are allowed ONLY when named in the source (source words minus
  builtins); exceptions can only further restrict. Removed the unconditional
  wrapper set (bash/sh/env/...) — it let the transpiler's parse-failure
  fallback (`sh2.exec("bash",[file])` on unparseable scripts) pass even when
  the source never mentions bash; those 5 cheat files are now blocked.
  `command` no longer bypasses the gate; JSON-derived fallback removed (no
  --source → empty allowlist). Verified: ESTREE 456/515 (88.5%), identical
  ×2, zero flaky. Known separate gap: arithmetic with empty operands
  (`$(( $1 * 100 ))` with unset positional args) — bash syntax-errors,
  evaluator returns 0.
- **2026-07-31 — Builtins centralized + native cmp/sort/uniq/comm, head/tail/
  wc, command (commit d485ee7).** `harness/builtins.json` is the single
  canonical list: the runtime's BUILTIN_NAMES and check_qx.pl both derive
  from it. The runtime now implements head/tail/wc/cmp/sort/uniq/comm natively
  (no spawn), and `command` is an escape-hatch builtin (exec allowlist
  bypassed — dynamic inner commands are unknowable). Wrapper commands
  (bash/sh/env/xargs/sudo/...) always allowed. Input redirects to missing
  files fail (bash semantics). Verified (stable emitter): ESTREE 406 →
  426/515 (82.7%), identical ×2, zero flaky, zero new failures. Caveat
  learned: the worker-pi's concurrent estree.rs edits confounded several
  measurements (376/276 readings); pause it for clean measurement.
- **2026-07-31 — Exec allowlist security gate (commit 72b8fec).** Entirely
  in the sh2loop harness (nothing in sh2perl — securing the transpiler from
  itself is pointless): the generated JS may only spawn external binaries
  whose names appear in the source .sh (ALL-words tokenization minus
  builtins, centralized `BUILTIN_NAMES` from the runtime; `set`/`declare`/`:`
  implemented natively). Verified clean: ESTREE 406/515 (78.8%), identical
  ×2, ZERO flaky tests (the run-to-run drift seen earlier was the worker-pi's
  concurrent estree.rs edits landing between runs — now stashed as
  worker-pi-wip, it regressed the corpus). PERL 426/89 ×2 stable. 051_primes
  is a deterministic clean-emitter gap (array-append `+=`), not flaky.
- **2026-07-31 — Flakiness eliminated + examples re-blessed (commit
  32cd1aa).** Repeated full-corpus runs (4×/harness with the worker paused)
  found the remaining flaky set — all CWD//tmp-dependent: 000__04b,
  test_system_builtin (ls/find of the shared CWD; ..=/tmp size fluctuates),
  104_pipeline_failure_var_capture (counted `ls /tmp`). Fixed hermetic
  (mktemp scratch + ls -A); blessed the earlier uncommitted rewrites
  (065/case-pattern-paren/cat-dash-stdin/heredoc-with-braces/pipeline-after-
  subshell) + 085 removal. Runtime: cd now process.chdir()s (relative
  redirect targets). Verified: estree flaky set EMPTY (372/143 ×2), perl
  stable (426/89 ×2, no new failures); fail timeout aligned 15→20s;
  blessed-fail-estree.txt re-blessed (176 tests).
- **2026-07-31 — M6 import registry landed (commit 2f70f9d).** Perl
  generator's `use` emissions are now table-driven (one Vec, one pass),
  preserving output byte-for-byte (verified: perl corpus 425/90 identical).
  M6 complete in-workspace: constant folding + dead-assignment (optimize_stmts,
  shared by both IR consumers) + import registry. Deeper IrProgram.imports-
  driven emission documented as future work.
- **2026-07-31 — M6 constant folding landed (commit 92f64bb).**
  `optimize_stmts` (shared by both IR consumers) folds constant `$((...))`
  arith → Int and Int BinOps, with a Rust evaluator (digits, + - * / %,
  parens; provably-constant only). Corpus: ESTREE 352 → 371/515 (72.0%),
  gate 7; PERL unchanged. Remaining M6: unified import/require registry
  (replacing the ad-hoc `needs_*()` booleans in the perl generator).
- **2026-07-31 — M3 DONE: estree.rs rerouted through the ShIR (commit
  3b956b6).** `shir.rs` (was the empty stub) now contains `ast_to_ir` +
  `shir_to_estree`; the raw-AST→ESTree lowering in `estree.rs` is DELETED
  (estree.rs keeps only the ESTree node model + sh2.* helpers). ir.rs gained
  ESTree-path neutral nodes (Arrow/Array/Bool/Json/Ident/Object exprs;
  Block/Expr stmts; Exec.env; IrRedirect.interpolate). The IR now has TWO
  consumers (ir_to_perl, shir_to_estree) — shared passes (M6) are enabled:
  optimize_stmts now runs for both backends. Verified: 23 lib tests; corpus
  ESTREE 343 → 352/515 (68.3%, slightly better than the old path); PERL
  unchanged. M4 word-level lowering (param/arith/brace/arrays) also landed
  (commits 248f9fe, 1e58663) — gate 21. M5 Stage B gate landed (2d0add8).
  Remaining: M4 runtime polish (worker), M6 shared passes (constant folding,
  import registry), M2 leftovers, M7 (sh2runtime repo).
- **2026-07-31 — M4 arrays + M5 Stage B gate.** Arrays lowered (`arr=(...)` →
  `sh2.setArray`, `${arr[i]}`/`arr[i]=x` → runtime array store, `${#arr[@]}`
  → set-index count, `${arr[@]}`/`${arr[*]}` → flatten/join, `${arr[@]:o:l}`
  slices, `$((arr[i]))` arithmetic; pure single-part interpolations lower to
  raw expressions so exec/forLoop flatten arrays like bash). ESTREE 338 →
  343/515 (66.6%); gate 21. **M5 Stage B**: `fail-estree --gate`/`--bless`
  with `blessed-fail-estree.txt` (201 tests allowlisted; gate exits 1 on any
  un-blessed failure — verified). Commits 1e58663, 2d0add8.
  Next: runtime polish (96 stdout + 55 runtime), then M3 estree-reroute
  through the IR, then M6 shared passes.
- **2026-07-31 — M4 word-level lowering: parameter expansion, arithmetic,
  brace expansion (commit 248f9fe).** `estree.rs` lowers `${var...}` (defaults,
  case mods, prefix/suffix removal, substitution, basename/dirname, slice) →
  `sh2.param`; `$((...))` → `sh2.arith`; `{a,b}`/`{1..5}` → `sh2.brace`
  (runtime cross-product; exec flattens array args). Corpus: **ESTREE 254 →
  338/515 (65.6%)**; gate bucket 184 → 41 (remaining gate = arrays). PERL
  unchanged. Newly-executing constructs add ~59 stdout/runtime failures to
  polish; bare-unquoted `\${x//p/r}` mis-parses upstream (matches perl).
  Next: arrays (`declare -a`, `arr[i]`, `${arr[@]}`, `${#arr[@]}`), then
  runtime polish, then M3 estree-reroute + M5 gating + M6 shared passes.
- **2026-07-31 — M3 shIR step 1: Sigil → optional backend annotation.** The IR
  core no longer requires a Perl sigil: `IrExpr::Var`/`AssignTarget`/`Decl`/
  `DeclareArray` carry `Option<Sigil>` (None renders as scalar for Perl; a
  non-Perl backend ignores it). Pure refactor — perl corpus identical
  (425/90, zero new failures), 22 lib tests, RawText untouched. Remaining
  M3 surface (documented in `ir.rs` header): neutralize `StrStyle`
  (Command/Heredoc → extensions), `Backtick`, `Regex`, `System`/`Pipeline`
  (→ `Exec`), `Require`, `SetChildError`; then reroute `estree.rs` through
  this IR. Commit b833c72.
- **2026-07-31 — Lexer/parser: combined short flags (`-rf`) lex as one word
  and canonicalize to `-x -y`.** Historical breakage: the test-operator tokens
  (`-f`, `-r`, `-eq`, ...) matched anywhere, so `-rf` lexed as `-r` + bare `f`,
  making `rm -rf x` parse identically to `rm -r f x` and forcing generator
  workarounds that conflated them (rm.rs treated a bare `f` after `-r` as the
  force flag, silently eating a real file named `f`). Fix: `parse_word`
  re-joins the tokens (`-rf` → one word; whitespace is the discriminator), and
  a new `parser/normalize.rs` getopt-style pass splits combined flags for a
  whitelist of flag commands (`rm -rf` → `['-r','-f']`) — conservative (no
  split = always safe), `--`/long-options/pure-numeric args untouched,
  value-taking flags split (`grep -A2` → `-A 2`). rm.rs workaround removed.
  Corpus: PERL 429/86, ESTREE 254/261 (49.3%). See commit 6af307d.
- **2026-07-31 — ESTree repair loop (`main_loop_estree.pl`).** Companion to
  `main_loop_rust.pl`: runs `./fail-estree`, diffs against a baseline
  (`.estree_prev_failures.tsv`, trusted counts `.estree_trusted_count` +
  `.estree_perl_trusted_count`), invokes pi (`opencode-go/deepseek-v4-flash`)
  with a failure-category prompt, re-runs, and keeps/commits improvements or
  auto-stashes regressions. Scoped staging ONLY (`src/estree.rs` in the
  submodule, `harness/*` in the root) — never `git add -A` — because the
  submodule carries the user's in-flight WIP; also never runs the examples
  restore (would clobber it). Corpus-size changes reseed the baseline.
  Run: `nohup perl main_loop_estree.pl > loop-estree.log 2>&1 &`,
  `./tmux_mon --session sh2estree -- perl main_loop_estree.pl`, or the
  `sh2estree.service` unit. `--dry-run` prints the pi prompt without
  invoking pi.
- **2026-07-31 — Reference executor + structural gate + `fail-estree` (M4).**
  New `harness/` in the workspace: `estree-gen.mjs` (deterministic
  ESTree→JS printer for the emitter's fixed node vocabulary — deviation:
  @babel/generator 7.x/8.x rejects plain JSON nodes, so we print ourselves,
  zero deps), `sh2-namespace.mjs` (node reference implementation of `sh2.*`:
  exec/redirect/pipeline/capture/test/caseMatch/define/subshell/background/
  loops/builtins (echo printf cd read export ...)/test-expression parser/
  glob + arithmetic evaluators), `estree-runner.mjs`, `estree_gate.pl`
  (callee whitelist, no unsupported, no *Sync, redirect-mode check),
  `fail-estree` (Stage A: perl + estree verdicts per example, parallel
  workers, no gating). Also fixed emitter semantics discovered while
  executing: await on async `sh2.*` calls, `sh2.forLoop`/`sh2.whileLoop`
  runtime loops with signal break/continue, `sh2.capture`/`whileLoop`
  closures, block-bodied compound stages, reserved-word-safe loop vars,
  `$@` list expansion. **Stage A metric: 255/515 (49.5%) examples match bash
  via the ESTree backend** (gate: 208 word-level unsupported, stdout
  mismatch: 46, runtime error: 24). Next: word-level lowering
  (parameter expansion, arithmetic words, brace expansion, arrays) to clear
  the gate bucket, then Stage B gating.
- **2026-08-01 — ESTree corpus 100% (516/516).** The estree-loop worker's
  accumulated fixes (numeric variable lift, `$(( ))` word arithmetic, parser
  word-boundary fixes) closed the last gaps; PERL steady 432/84. Two
  full-run stragglers (`100_pipeline_failure_basic`, `parse-dollar-paren-pipe`,
  `typeset-cmdsub`) are pre-existing /tmp-flaky and pass solo.
- **2026-08-01 — Sync while-loop fast path (`whileLoopSync`).** Provably-sync
  `while` loops (cond + body contain no AwaitExpression) lower to the runtime
  twin minus per-iteration promises: 10M-iter arithmetic loop 2.64s → 0.23s
  loop-only, e2e 2.90s → 0.27s (~210× vs bash's 56s). Same semantics
  (lastExit, BREAK/CONTINUE/RETURN signals, capture bound). Gate whitelists
  it as the one permitted *Sync call (pure CPU, no I/O by construction).
- **2026-08-01 — grep-test idiom → native substring compare.**
  `if/while echo X | grep P >/dev/null 2>/dev/null` (test position only)
  lifts in the ShIR to a `contains` call, inlined by the emitter to native
  `String(X).includes(P)` (worker's e2c312a complement). sqrt1337.sh
  (10k-iter grep-in-loop): JS 1m50s → 0.6s (~180× vs bash 1m23s), output
  identical. Conservative: literal BRE-free patterns, no flags, both fds
  discarded; statement/&&-position pipelines keep `$?` semantics.
- **2026-08-01 — otranspilerl.wasm: the full CLI as a WASI library call.**
  otranspilerl-cli.wasm was command-only (`_start`; node:wasi has no fs preopens) and
  sh2perl core.wasm skipped the CLI — the otranspilerl crate had zero `#[no_mangle]`
  exports. New `wasi-cli` feature exports `debashc_cli_run(argc, argv)` /
  `_run_json` / `_run_with_input` (file commands via the `-` stdin
  convention + virtual stdin, since node:wasi can't preopen files) over the
  real `main_with_args` dispatch; `file --estree -` byte-identical to native.
  Deployed with README + example scripts to `~/js/`.
- **2026-08-01 — M8 started: worker improvement mode.** See §9. Metric
  baseline (5,107 sh2.* call sites across 516 examples; ~1,200 lowerable:
  getVar 512, setVar 253, param 197, test 129, caseMatch 42, brace 40, arith
  family 41, async loops 44).
- **2026-08-04 — M9 stage 0: shir_passes shared library scaffolded.**
  New `sh2perl/src/shir_passes/` module (1,382 lines, 8 files): the
  `PassContext` struct (replaces the ten `static Mutex<Option<…>>`
  globals in shir.rs — the determinism-test race goes away as a side
  effect of the migration), the `Analysis`/`Transform`/`PatternLift`
  traits and the `Pipeline` runner, the `Metric` tally (sh2.* call-site
  count; the worker's commit signal promoted to a first-class return
  value), and the pattern-lift skeleton (`contains` family as the
  worked example). The analysis/transform/lift implementations are
  stubs that return defaults — the real implementations migrate in
  stage 1 (the M3 guardrail, "Perl output is byte-identical", is the
  proof the migration is safe). `cargo test --lib` 55 → 75 (+20 new
  in shir_passes, zero regressions). The design decision is documented
  in `sh2perl/docs/ir-design.md` §"The sh2.* boundary": the sh2.*
  namespace is the cut-down boundary, not a per-backend shIR subset.
  No existing code path changes — the ESTree and Perl backends still
  consume the existing shir.rs analyses.
- **2026-08-06 — `seq_range_for` transform: `for i in $(seq A B)` →
  native range loop (PLAN §9.1's `seq 1 N → native range` exemplar).**
  New worker-style transform (`sh2perl/src/transforms/seq_range_for.rs`,
  gated by `DEBASHC_TRANSFORMS` like the rest of the registry): rewrites
  the `$(seq …)` capture iterable (`Array([captureWords(exec("seq"))])`)
  to `Array([Range { A, B }])` in the shared IR, and the ESTree emitter
  lowers a Range-iterable For to a native JS `for (let i = A; i <= B;
  i++)` — no runtime call, no item list, no per-iteration coercion. The
  loop var then numeric-lifts through the EXISTING analysis
  (`iter_numeric(Range)`), so `$((i*i))` is native `i * i` and the
  emitted sqrt1337.sh loop is byte-identical in form to the hand-written
  one (`for (let i = 1; i <= 10000; i++)`), with ZERO sh2.* call sites
  (was: captureWords + builtin + per-iteration Number() coercions).
  New `Stmt::ForStatement` ESTree node + `harness/estree-gen.mjs`
  printer. Conservative: integer args only (no floats/flags/leading
  zeros — octal), |v| ≤ 2^53, span ≤ 1M (bounds the materialized-
  array fallback), body never WRITES the loop var (counter `i++` would
  read a body-written value); store-sync elimination keeps post-loop
  `$i` = last value. Tests: 3 estree.rs emission tests + 9 transform
  unit tests; `./fail-estree` 526/531 estree PASS (baseline 525/531,
  no regressions; Perl byte-identical — the AST generator never
  consumes this IR). Submodule main tip: `a85f46c` (seq_range_for via
  `6b31498` + the C worker's const/var analysis commits); the clean
  standalone commit is preserved on branch `seq-range-for` (`fae1ed1`).
- **2026-08-06 — sqrt1337 → hand-js equivalence (two emitter
  refinements).** (a) Echo single-arg collapse: `echo $i` emitted
  `[String(i)].join(" ")` — a one-element join never inserts the
  separator, so the echo_join_args general path now short-circuits the
  single non-literal arg to the bare value (`String(i) + "\n"`);
  array-valued single args (`$(...)` captureWords) still splice + join.
  (b) Plan 4 if-deadness: the empty-else `else { sh2.lastExit = 0; }`
  (false cond + no else → `$?` = 0) is dropped when the liveness scan
  proves the if's status unread (the backward scan already treats the
  If as a writer; mark_lastexit_dead + the if-lowering consult the
  verdict) — a plain `if (c) { ... }`, no else. sqrt1337's loop body is
  now exactly the hand-js form: `for (let i = 1; i <= 10000; i++) { if
  (String(i * i).includes("1337")) { process.stdout.write(String(i) +
  "\n"); } }` — zero sh2.* calls, zero dead status writes.
  fail-estree 526/531 (the 5 pre-existing flaky/env failures only).

---

## 8. ShIR philosophy (why not a mirror IR)

A ShIR that round-trips byte-identically to the Perl IR contains no
information the Perl IR lacks — it would be a rename, not an architecture.

- **Design:** lossy in the right direction. Keep what all backends need
  (exec, assignment, control flow, redirection, capture); drop what only one
  output language needs (sigils, Perl string styles, `$ENV` conventions).
- **Verification:** behavioral — the corpus gate (output vs `bash`), plus a
  regression watch on the currently-passing tests. Round-trip byte-equality
  is only a transient guardrail for the initial `RawText`-wrap step.
- **Payoff:** two diverging backends (`shir_to_perl`, `shir_to_estree`) from
  one tree, shared analyses, and the removal of `estree.rs`'s duplicated
  lowering once it reroutes through ShIR.

---

## 9. Worker improvement mode (M8)
Once the ESTree corpus is green, the fix loop has nothing to fix — so instead
of idling, `main_loop_estree.pl` prompts the worker to find the **cheapest
correct lowering** for every remaining `sh2.*` call site, subprocess spawn,
and async loop.

### 9.1 The lowering ladder (what "cheapest" means)

```
cheapest ──────────────────────────────────────────────────► most expensive
native JS expression         sync sh2.* call    async sh2.* call    subprocess spawn
String(x).includes(p)        sh2.test           sh2.exec            echo | grep
i < 100000, i = i + 1        sh2.contains       sh2.pipeline
String.slice/replace         (fallback)         (fallback)
```

Every call site is judged against this ladder; the corpus is the correctness
oracle. The worker generalizes **pattern families**, not instances: `grep
1337` is a substring test (`String(x).includes("1337")`), never a regex or a
generic grep translation. Same for `grep -q P file` → read + includes,
`case $x in *P*)` → includes, `seq 1 N` → native range, `[ "$x" = *P* ]` →
native glob-to-includes, `${x//p/r}` → replaceAll, `head/tail/wc` on known
producers → native counts.

**Exemplars already landed (the bar to match/beat):** numeric lift
(`i < 100000`, `i = i + 1`), `whileLoopSync` (sync runtime loop, no
per-iteration promises), `echo X | grep P >/dev/null 2>/dev/null` →
`String(X).includes(P)` (test-position IR lift).

### 9.2 Mechanics
- **Metric as awareness, not score:** `fail-estree --metric` tallies sh2.*
  call sites per callee across the corpus (baseline 5,107 total; ~1,200
  lowerable: getVar 512, setVar 253, param 197, test 129, caseMatch 42,
  brace 40, arith family 41, async loops 44). The table is context for the
  prompt; the **total count** is the progress signal for commit/no-progress.
- **Loop:** at the idle point (`estree_failed == 0`), diff the metric vs
  `.estree_metric_prev.tsv`:
  - total decreased AND corpus green → `scoped_commit`
  - total increased (tolerance +1 for flakiness) → `scoped_stash`
  - flat for 3 rounds → idle (sleep 300), recheck later
  - any failure count > 0 → back to fix mode (unchanged)
- **Backlog (`harness/improvement-backlog.md`):** curated candidate tasks
  appended verbatim to the improvement prompt (submission channel for
  ideas like the integer-range/BigInt task — see Task 1).
- **Prompt (`build_improvement_prompt`):** the ladder, the exemplars, the
  current metric table, and the directive — for each construct still on the
  runtime/spawn path, find the best lowering you can think of. Same scoped
  fix surface as fix mode (wide `src/*` + `harness/*` when the rust loop is
  absent; narrow `src/estree.rs` when it runs).
- **Guardrails:** corpus 516/516 is the hard gate for commits; one regressed
  example → auto-stash. Determinism (`cargo test --lib`) and the structural
  gate must stay green (new sh2.* names need whitelist entries; `*Sync` only
  for the pure-CPU loop exception). Never reduce the PERL pass count; no
  blocking I/O. When unsure of a lowering's correctness, keep the runtime
  call — a good idea that can't be proven on the corpus is dropped, not
  force-fit.

## 10. Embed profile: purify inside the transpiler (proposal + Stage 1)

Replace `system("")` / backtick-like constructs in a HOST program with
host-native fragments — purify, generalized to any language. The core never
parses the host text: a per-language **harvester** finds construct spans +
harvests context (scope names, imports, construct semantics), and the core
renders each shell snippet as a **fragment** given that context. Design
thread: (a) preservation = "output equals input with only the marked spans
replaced" (mechanically gated); (b) context = A1 shIR markup for the snippet
(read/write sets → v2: `var_lifetimes[].escapes` + lift sets) + a thin
host-side membership sidecar; (c) spec in `sh2perl/docs/embed-contract.md`,
record schema in `frontends/shir-contract/schema.json` (`embed_block`).

**Why:** purify.pl's live path is `otranspilerl-cli parse --inline` — the legacy
`Generator`, whose HashSet-ordered emission is **nondeterministic run-to-run**
(verified 30/30 differing outputs; purify output is nondeterministic and the
purify CI job exercises it). purify then applies ~10 regex/PPI patches to each
fragment and skips otranspilerl-cli entirely for backticks containing Perl vars
(FIX.md Bug 3). All of that is context the transpiler never received.

### Stage 1 (landed, this revision)

- `shir_to_perl_embed(prog, ctx) -> EmbedResult { fragment,
  required_host_bindings, refusals }` (`src/ir.rs`): statements only — no
  shebang/pragmas/imports/preamble/exit; `do { … }` wrapper (load-bearing:
  a same-scope `my $x = $x;` copy-in would mask-REUSE the host lexical and
  leak writes — verified; inside the block it's a fresh lexical, bash
  subshell semantics). Decl rules: read-only∧host → bare `$x` reuse;
  read-only∧¬host → `my $x = '';`; written∧host → `my $x = $x;` copy-in;
  written∧¬host → `my $x;`. Rewrites: `$main_exit_code = $CHILD_ERROR =
  X;` → `$CHILD_ERROR = X;`; drop `chomp $_r;` under backtick-newlines;
  English.pm names → `$/`/`$!`/`$@`; prepend `our $CHILD_ERROR = 0;` when
  referenced. Refusals (analysis-driven, replacing purify's regex
  rejections): `exit` (would kill the host), function defs, background
  jobs, `$__argc`/`$__nocasematch`/`$main_exit_code` residue, `say`.
- **Bindings gate:** `required_host_bindings ⊆ host_scope` — a bare `$x`
  for a name the caller didn't list is a hard failure.
- **Determinism:** 30/30 byte-identical across processes (Vec-based
  first-seen decl order, fixed-string rewrites).
- Verified vs bash: host-scope read (`hostval`), copy-in non-leak
  (`6` / `after: 5` — bash subshell semantics), external command status
  mirror, local-var case — all byte-equal; the legacy inline path was
  30/30 flaky on the same inputs.
- `cargo test --lib` 300/301 (the glsl failure is the pre-existing in-flight
  worker WIP). New tests: `embed_*` ×7 (determinism, bindings gate,
  copy-in, no-preamble, main_exit collapse, English normalization,
  refusals). CLI hook: `otranspilerl-cli parse --perl-embed` (`PURIFY_SCOPE` env =
  host membership list, manual testing).

### Stage 2 (landed, this revision)

- **otranspilerl `--embed-perl`**: `render_embed(a1, EmbedOpts)` +
  CLI flags `--embed-perl` / `--scope-vars a,b,c` / `--backtick` /
  `--english` (fragment on stdout; `REQUIRED`/`REFUSE` on stderr so stdout
  stays splice-clean — the future purify caller gates on them). 5 CLI tests
  in `otranspilerl/src/lib.rs`.
- **Carp injection**: command emulations call `carp`/`croak` on error
  paths; the embed renderer now prepends `use Carp;` when the fragment
  references them (the standalone preamble's import, owned by the renderer
  instead of purify's regex). +1 sh2perl test (`embed_injects_carp`).
- Verified end-to-end through `otranspilerl-cli`: 11/11 smoke matrix vs
  bash (host-scope reads, copy-in non-leak, `${s%?}` loop, pipelines,
  `${a}${b}`, `||` fallbacks) with the SAME scope list on both sides;
  out-of-scope names correctly render as bash-unset. `cargo test --lib`
  303/301 (glsl = pre-existing WIP; the concurrent agent's estree work is
  in the tree and compiles).
- **Known inherited limitation (not embed-specific)**: `$(…)` in the middle
  of a double-quoted string with an emulable inner command hits a
  pre-existing `shir_to_perl` capture-path bug (`bash -c 'sub { … }'`)
  that reproduces via standalone `file --perl`; documented in
  embed-contract.md §7.

### Stage 3 (landed, this revision)

- **purify.pl backtick swap (opt-in `PURIFY_EMBED=1`)** — the backtick
  path now prefers `otranspilerl-cli --embed-perl --backtick
  --scope-vars <file-wide my/our harvest>`; REFUSE degrades to the legacy
  path (or the exec fallback), so the swap is A/B-testable and safe to
  leave on.
- **The capture wrapper is load-bearing**: the fragment is print-oriented
  (statements); a backtick replacement must be an EXPRESSION evaluating to
  the captured stdout. purify wraps it in `__bt(do { … })` and runs it in a
  FORKED CHILD with stdout on a pipe (`open '-|'`) — external commands fork
  grandchildren that inherit the pipe fd 1 (a `local *STDOUT` scalar/file
  capture does NOT rebind fd 1; verified `wc -l` leaked to real stdout),
  and the fork gives true bash-subshell semantics (fragment writes can't
  touch the host). Fragment preamble (`our $CHILD_ERROR = 0;` / `use …;`)
  is extracted and injected at file level (a `use` inside the
  `__bt(do{…})` expression is a syntax error).
- **Corpus A/B (examples.impurl, 33 purify-relevant files): legacy 8/33 →
  embed 22/33.** The 11 remaining failures are INHERITED shIR renderer
  emulation gaps that reproduce via standalone `file --perl` (printf `\n`
  escapes, `mkdir -m`, env-assign echo) — not embed-profile bugs. Purified
  output byte-deterministic 3/3.
- **Corpus 33/33 (this revision).** The inherited gaps were fixed in the
  shared renderer, all verified against real GNU/coreutils behavior:
  capture fallback fed the emulated `sub { }` body to bash -c → rebuild the
  SHELL TEXT (`stmts_to_shell_cmd`) and refuse non-expressible closures;
  printf CYCLES the format (chunked by placeholder count, dynamic `%*d`
  width for wc); tail clamps to available lines and refuses `-c`;
  mkdir skips `-m MODE`; basename refuses extra suffixes; wc matches GNU
  width digits(max)+1 and multi-file → real bash; `2>&1` dup fixed in the
  bash-text rebuild AND the Perl select-fallback (no more `2>>&1` /
  file-named-`&1`); `>>` append no longer rebuilds as `>` (overwrite);
  subshell pipeline stages rebuild as `( … )` groups and join with `;`;
  env-prefix Object emits `$ENV{K}=V` only for the bash-child path (bash
  expands args BEFORE the assignment) and env-style names allow digits
  (`VAR1` → `$ENV{VAR1}`, not a local); `$ls_success`/`$main_exit_code`
  status writes dropped in fragments; purify's `__bt` wrapper reaps via
  `close` (not waitpid) so `$?` matches bash backtick semantics;
  otranspilerl gained `--literal` so single-word snippets aren't mistaken
  for filenames. All: `cargo test --lib` 303/301 (glsl pre-existing WIP),
  embed_* 8/8, otranspilerl 5/5, purify output byte-deterministic 3/3.

### Remaining (ordered)

1. purify.pl: flip `PURIFY_EMBED` to default-on once the inherited
   emulation gaps shrink further; per-site scope (PPI visibility instead
   of file-wide); Bug 3 (Perl vars in backticks) via the marker protocol;
   then retire the legacy `--inline` path's regex patches one at a time
   (each pinned by a fixture).
2. shIR verdict upgrade: `required_host_bindings` from
   `var_lifetimes[].escapes` + lift sets (PassContext) instead of the
   read/write sets.
3. Generic profile: per-host-language construct finders (scanner table →
   frontend scan mode) + the construct-shaped fragment API
   (`--embed=<lang> --construct=system|backtick|popen`); preservation gate
   per host language; purify-twice byte-identity gate (red today).

Open questions: status-tracker strategy (declare-local vs reuse-enclosing),
`__bt` wrapper home (renderer vs purify), scope-var precision (file-wide v1
vs per-site), function-def refusals v1 (vs render-as-host-sub), Int64
boundary conversion, per-fragment `#line`.

## 11. Transform marketplace: offered / accept / reject (proposal)

The estree worker's implement-and-mediate model is the bottleneck (serial
mediation of every escalation, blocking `sleeping-<lang>` wakes, STALLED-FIRST
starvation, and a gate that cannot see frontend-emitted A1). Replace it with
a **marketplace**: transforms are offered by the backend that needs them and
accepted or rejected by the backends they would affect. The core narrows to
build + canonical bug-fix.

### 11.1 The roles

- **A backend** implements new transforms, decides the sharing scope (which
  other backends should get them), and OFFERS them.
- **Other backends** ACCEPT or REJECT offers. Acceptance is compile-time for
  transforms (a per-backend manifest selects the compiled set); for CONTRACT
  NODES (the shared `estree::Stmt`/`Expr` enums) acceptance is render-time —
  every backend has the node compiled in and chooses to render or refuse it;
  `triage/verdicts.tsv` records the emergent contract map.
- **The core** only: build CI over every backend tree; bug-fix the canonical
  transform set; hold the invariants (determinism, perl pass count, A1
  round-trip); own the A1 schema; own the bash→A1 parser.

### 11.2 The offer / accept protocol

1. A backend writes a transform (or fixes/updates an existing one) in its
   worktree (`backend/<lang>`), with a MANIFEST header (see 11.4).
2. It drops the offer in `core-requests/transforms/offered/<name>.md` naming
   the intended sharing scope.
3. Target backends merge the candidate into their worktree and run their own
   gate: green → ACCEPT (the canonical copy lives in their tree); red →
   REJECT (stays out, verdict recorded; the offerer may fix and re-offer).
4. **Updates are offers too**: a fix or improvement to an accepted transform
   is offered the same way. When ALL acceptors land the new version, the
   OLD version is PRUNED from main (the canonical set). Partial acceptance
   keeps the old canonical + the new per-acceptor copy as a distinct
   transform (a fork is a NEW transform, never an edit of the accepted one —
   acceptance ≠ fork, so the core's bug-fix role stays well-defined).
5. Graduation: a transform accepted by all (or a quorum) moves to main's
   canonical `src/transforms/`; the core's CI builds it and the core fixes
   its bugs (propagating via the existing `--sync` merge discipline).

### 11.3 The cross-product gate flips from gate to signal

The `triage.sh` cross-product sweep is no longer the core's verification
gate — it is a SIGNAL: for each frontend×backend pair it records whether
the backend renders the frontend's A1 and matches native. Each backend uses
its own verdicts to decide accept/reject (a transform that makes many pairs
pass is de-facto shared; one that helps a single pair stays scoped).
"Out of scope" ceases to exist as a rejection category.

### 11.4 Transform manifest (required on every offer)

```text
name: <transform>
prereqs: [analyses it needs — var_lifetimes, const_vars, …]
invariant: <which A1 shapes it expects/normalizes, what must not change>
scope: <intended acceptors — e.g. c, sh, glsl>
updates: <if this replaces an accepted version, the old version's id>
```

The acceptance decision is "I'll run this + its prereqs, and my gate
passes." Prereq declaration is the guard against a transform silently
breaking a later acceptor.

### 11.5 Conditions (the anti-bottleneck guarantees)

- **Additive contract**: A1 schema additions are append-only + round-trip
  tested; nothing to mediate between conflicting requests if the contract is
  monotone.
- **Independent merge units**: one offer per cycle, scoped commits, merged
  independently (additivity makes them conflict-free).
- **Reject by default**: an offer that is not clearly small and additive is
  rejected/deferred; a stalled offer auto-escalates to the human core-owner
  after two cycles instead of being re-fed forever.
- **Cadence split if needed**: contract steward (schema + round-trip,
  frontend-facing) vs transform worker (cross-backend changes) if a single
  worker saturates.

### 11.6 Pilot: bc-float-clean

Un-reject `core-requests/transforms/rejected/bc-float-clean`: the GLSL
backend (backends/glsl) owns it, offers it to sh (sh also has a `bc` path),
the remaining backends reject. This exercises build (core), offer/accept
(worktrees), and verdict recording (cross-product gate) with one
self-contained transform before scaling the protocol.

### 11.7 Migration

The existing `src/transforms/*.rs` modules and `core-requests/transforms/`
done/rejected piles become the seed inventory: each transform gets a
manifest, each backend declares its accept set (default: the current
unconditional `pub mod transforms`), and the first re-offer cycle
re-baselines the canonical set. The estree worker's scope narrows to
`estree.rs` + the shell parser + canonical-transform bug-fixes — the
fix-surface contraction mechanism (triggered when other workers run)
applies unchanged.

### 11.8 Dependency sharing = our lock + shared core target (landed)

Implemented: `harness/build-lock.sh` — the single choke point for cargo
builds (PLAN §11.8): a mkdir-based priority lock in front of cargo. Cargo's
own target-dir lock is blocking FIFO with no policy; the wrapper adds
priority (core preempts the holder after its timeout via graceful SIGTERM +
grace), timeouts, stale-lock recovery, a status/waiters diagnostic trail,
and a re-entrancy guard. CORE builds (the estree loop + every backend
gate) share `sh2perl/target` — the dep + core crate compile once for all
of them (replacing the per-worktree `target-core` split that existed only
to dodge cargo's file-lock churn). WORKTREE builds keep `$g_wt/target`
(their `otranspilerl-cli` bin collides with the main checkout's). Rationale: the
workspace is CPU-bound more than lock-bound, so serialization is
acceptable; sccache stays a measured fallback (its stale-artifact
correctness risk and WSL2/overlay surface are documented risks, not
adopted). Wire-in: setup_backends.sh (gate core + worktree builds),
main_loop_estree.pl (commit-gate full build, role core, preempts backend
gates after 180s).

### 11.9 The core is LLM-free (landed)

The core's remaining jobs are mechanical: build every backend's tree
(`harness/build-lock.sh`), run the gates, and LOG verdicts the backends
read — no pi. Two new artifacts:

- **`harness/contract-gen`** — the semantic-patch generator: a frontend/
  backend writes a declarative node spec (name, kind, fields); contract-gen
  emits the ir.rs enum variant + the shir_json serializer arm + the
  shir_json_in deserializer arm + the schema entry + a round-trip fixture.
  Verified: the generated ForInit fixture round-trips through the current
  `--shir-in-perl` binary. Application precondition: the OPEN node model —
  renderers' node-model matches need `_ => refuse` fallbacks so a new
  variant compiles everywhere without touching the renderers (until that
  lands, patches apply to the shared core files and the fixture is the
  verification).
- **`harness/core-sweep.sh`** — the mechanical loop: shared core build +
  per-backend worktree build (via build-lock.sh), verdict lines appended
  to `core-requests/transforms/verdicts.log` (tsv: backend, transform-set
  hash, PASS/FAIL, detail, epoch). Acceptance = the gate verdict; the
  backend reads its FAIL lines and fixes its own transforms (PLAN §11.2).

The LLM's remaining role in the workspace moves to the PROPOSERS: the
backend that knows its transform writes it and reads its own verdicts.
The core is scheduled (cron/loop), not prompted.

### 11.10 debashc/debashcl deleted — otranspilerl is the only CLI (landed)

The two-crate ancient CLI layer (sh2perl `cli/`: `debashc` flag-level bin +
`debashcl` processor; the in-repo `otranspiler` bin that spawned a sibling
`debashc` for every stage) is deleted. Fold result:

- **otranspilerl-cli** (workspace crate) is the only user-facing CLI; the
  harness (`fail`, `fail-estree`, `fail-shir`, backend gates) runs it
  exclusively. Flags folded in: `--target estree` (debashc's direct
  `file --estree` path, byte-verified), `--true64`/`--bigint`.
- **`shir_render`** (src/bin/, core crate) — the generic A1→target
  renderer; the backend worktree gate's entry (`--target <lang>`, stdin
  `-`). The per-backend `*_backend` bins stay (workers' library-path).
- **Workspace harness migrated**: `debashc --shir` → `otranspilerl-cli
  --target shir`; `--shir-in-<lang>` → `shir_render --target <lang>`;
  `DEBASHC_TRANSFORMS` → `SH2_TRANSFORMS` (legacy name still read as an
  alias inside transforms::apply). Isolated-verify builds now compile
  otranspilerl-cli; fail-shir's override env is `OTRANSPILERL`.
- **Legacy deleted**: 19 dump/debug bins, the 36k-line legacy generator +
  `legacy-generator` feature (its one hook, `ir::generator_emulate_command`,
  is now the permanent None arm — emulation moves into the perl renderer
  proper), the wasi-cli/debashc_cli_run wasm layer (otranspilerl's
  `otranspilerl_cli` export supersedes it), build-wasi.sh rewritten to two
  artifacts (otranspilerl-cli.wasm + the core/unified ABI libs).
- sh2perl is now a library-only crate (lib + worker bins + convert_examples
  + shir_render). `debashc`/`debashcl` mentions purged from code, docs,
  scripts, and generated-code markers (`die "otranspilerl: ..."`).

Parity at the fold: estree byte-identical vs `file --estree` (547/552; the
5 parse-error cases improve — the old path leaked `Parse error:` onto
stdout mixed with the JSON); A1 and perl renders are otranspilerl's
already-gated forms (old path leaked DBG lines / banners / dropped
stmt_lines).
