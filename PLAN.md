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
> - v62: **transform verification, second pass — the laws made able to FAIL,
>   and the nested-subshell bug they found.** The v61 suite passed; a passing
>   suite is not evidence until you have seen it fail. Two gaps closed and
>   two findings:
>   (a) **Verdict resets.** Eight analysis-only transforms cache their verdict
>   in a `static Mutex` and return `false` from `run()` while a RENDERER
>   reads it, so a caller that runs one transform in ISOLATION (the law
>   harness, the `first-n` bisect replay) saw run 1's verdict on run 2 and the
>   determinism law was vacuously true. `transforms::reset_verdicts()` +
>   per-module `clear_verdicts()`.
>   (b) **The generator could not produce the shapes the law asserts on.**
>   proptest shrinking prefers short, leaf-heavy programs; measured, the
>   forbidden-shape law passed while a suppressed fold went unnoticed. The
>   generator now GUARANTEES a foldable `${v:0}` and a foldable `${#NAME[@]}`
>   in every program. The law's own predicate also had to stop re-testing the
>   transform's name guard (requiring a plain identifier made the mutation
>   probe pass).
>   (c) **Control run, reproducible 3/3 per transform:** with `run_one`
>   restoring the input after the call (pretend the fold did nothing),
>   `array-len-fold` and `slice-identity` each report "a foldable … call
>   survived". A law that cannot fail is not evidence.
>   (d) **Bug: `text-ops` nested subshells.** `( ( b=2 ) )` — the body was
>   copied verbatim into the snapshot/restore block, so a second call wrapped
>   the inner `Subshell` again with a fresh counter index and a different
>   variable ordering; the inner save no longer read the outer save's
>   restored value. `lower_stmt` now lowers the body in the same call.
>   Gate: `harness/transform-laws.sh` (per-law verdicts, the COVERAGE line —
>   currently 8–9 of 48 transforms actually rewrite something, and the idle
>   list is printed, not hidden — `--json`, and a distinct
>   `CARGO_TARGET_DIR` by default). Tier 1 is `checked` (Isabelle2025-2, with
>   a negative control); Tier 3 is stated as unreachable and replaced by the
>   `harness/transform-diff.sh` differential. Note to the box: the IR has no
>   depth guard — an `IrExpr` chain ~1500 deep overflows a 64 MiB stack
>   *while being dropped*, so the harness bounds its generator and every
>   recursive consumer of untrusted depth is a stack risk.
> - v61: **transform verification — a property suite + a differential gate,
>   and the two bugs they found.** PLAN §11.4 requires every transform to
>   declare its `invariant:` in prose; nothing checked it.
>   `sh2perl/tests/transform_laws.rs` (only a `proptest` dev-dependency)
>   checks determinism, idempotence, no-panic, the declared rewrite happening,
>   and Perl-render invariance where the transform claims it — reporting
>   coverage honestly (`COVERAGE 9/55`; the verdict-producing analyses and the
>   frontend-shape transforms do not fire on the generator yet).
>   `sh2perl/src/bin/transform_diff.rs` + `harness/transform-diff.sh` render
>   every corpus file with `transforms::apply` and without: baseline **511/562
>   text-identical, 45 cascade, 6 unlowered**. Findings: (a) the IR has no
>   depth guard — an `IrExpr` chain ~1500 deep overflows the stack while being
>   DROPPED, so every recursive consumer is a stack risk on deep input;
>   (b) `text-ops` was non-idempotent (a fold inside a subshell happened only
>   on a second pass) — fixed; (c) `copy-propagation` skipped reads carried in
>   flat `test`/`arith` TEXT, leaving declare+assign+never-read variables in
>   the Perl output — fixed, 506 → 511 text-identical. NOT verified by
>   `./fail`: `otranspilerl` does not build in this tree (`wasi.rs` calls
>   functions that exist only in an uncommitted working-tree state), so the
>   differential gate is the oracle that was available. The Tier-1 proof is
>   NOT prose: with Isabelle2025-2 installed (`/opt/Isabelle2025-2`, from the
>   Cambridge mirror — the tum.de host is unreachable here),
>   `core-requests/transforms/done/div-mod-pow2.rs/proof` now builds clean
>   with `quick_and_dirty = false` and proves `div_mod_pow2_sound`,
>   `pow2_pos`, `non_negative_bin_iff` and `shift_agrees`; a negative control
>   was run and FAILED, so the session is not vacuous. The first two attempts
>   did not check (the `AND` operator and the induction-hypothesis name) —
>   which is exactly what a `stated` proof is worth.
> - v60: **tty-cmdsub driven to bash-identical: the `[[ -r … ]]` class,
>   the redirect STDIN dup, the process-subst producer pipeline.** Three
>   independent wrong-answer bugs in one example. (1) `render_test_tokens`'
>   two-token arm covered only `-f/-d/-e/-s/-S/-h/-a/-z/-n/-t`, so
>   `[[ -r "$dev" ]]` (flattened `-r "$dev" [[`) fell to the historic
>   always-TRUE heuristic `my $t = "…"; $t =~ /-\w+/` — which matches the
>   test's OWN flag text — and tty-cmdsub picked a nonexistent /dev/pts/2
>   where bash picked a readable pts, then died on the redirect. The
>   unhandled two- and three-token shapes now hand the token list to the
>   shared recursive parser (`render_test_token_list`: `!`, parens, the
>   unary file tests, `-nt`/`-ef`) and fall back to the heuristic only when
>   it renders nothing; two unit tests pin the class. (2) The `while …; done
>   < FILE` and `$fn_call(…) < FILE` redirect arms emitted `local *STDIN` —
>   a localized typeglob is fd-less, so the open landed on the lowest free
>   fd (3) and every CHILD still inherited the original fd 0: `tty` printed
>   "not a tty" where bash printed the terminal. Both arms now dup fd 0
>   first and restore it at block exit (bash's `< FILE` puts the file ON
>   fd 0; nests still compose). (3) `process_subst`'s producer statements
>   are re-parsed shell text, so a pipeline producer reached the renderer
>   as a statement-position `pipeline(…)` CALL — the `system('bash','-c',…)`
>   shape — because `shir-pipeline-native` runs earlier in the registry and
>   never sees those statements; `producer_redirect` now re-applies it
>   (still `transform_enabled`-gated). Also removed the `DBG_RTE` debug
>   eprintln from `render_test_expr`. Verification of record: tty-cmdsub
>   bash-vs-perl stdout diff **0 lines, both rc 0** (same pts chosen);
>   `./fail` **562/562 rc=0**; `./fail-estree` **PERL 562/562 rc=0**
>   (ESTREE 558/562 — three of the four mismatches re-run PASS in an
>   isolated check on both binaries (gate-order flake) and the fourth
>   (`a.sh`) fails identically on the isolated-commit binary and on the
>   worktree binary, i.e. outside this change); `./fail-shir` rc=0
>   (545/562 bash-free); `./fail-coreutils` 1/5 — the four reds are the
>   documented parser-gap tests (case keyword collision, escaped case
>   paren, env-prefix-if, cmdsub-digit redirect). sh2perl `--lib` 1435
>   pass / 10 fail — the same pre-existing `c_backend::tests` set
>   (concurrent uncommitted `c_backend.rs` edit; hand-built IR →
>   `shir_to_c`, unreachable here). The commit also builds and passes the
>   tty check in an ISOLATED crate linked against c5a830bc9 alone.
>   Gitlink deliberately not bumped (the commit sits on the concurrent
>   c_backend/frontends commits and the worktree carries other
>   workstreams' uncommitted edits — same call as the entries below).
> - v59: **rust-emit idiom audit (whole corpus) → the two remaining
>   shared folds, written up as a marketplace spec.** Measured the
>   `--target rs` output for all 560 examples (2.73 MB): **0 `sh2.*`
>   callouts in bodies, 0 dead preamble helpers** (the helper gate is
>   fully effective), and the surviving cast surface (68 `as i64`, 441
>   `as usize`, 25 `as i32`; the v63 `as u32` purge holds) concentrates
>   in exactly two backend-local templates — the `${arr[@]:off:len}`
>   clamping block and index/len reads. The one structural sink left is
>   `__sh_fnmatch` (207 call sites / 54 files), which decomposes into
>   (a) genuine glob-engine patterns, (b) case-clause char-classes
>   (`[a-z]*` — the case_lowering refusal class), and (c) param-
>   expansion strips whose literal patterns still drag in the glob
>   engine because rust's helper table makes `strippre/stripsuf/replace`
>   all depend on `fnmatch`. Two shared folds are specified with corpus
>   numbers and per-backend arms in
>   `core-requests/rust-emit-idiom-analysis-and-globmatch-bundle.md`:
>   a shared `globMatch` predicate (so ONE class clause stops refusing
>   the whole `case`; patterns pass through verbatim, only the dispatch
>   is shared) and literal/affix strip identities (`${v#lit}`/
>   `${v#lit*}` → strip_prefix forms, each identity derived from glob
>   semantics, everything else refused). Also recorded ownership: the
>   `slice` off-slot `"@"` is the array-vs-string discriminator in
>   ir.rs/estree.rs/shir.rs/c/go/rust/java and must NOT be normalized
>   away; main's rust `slice_index_expr` just lacks the `@ → 0` arm the
>   rust WORKTREE already carries (rust-lane merge, not shared work),
>   and the constant-bounds slice short-form is a rust-template change
>   in the same lane. No code change this increment — analysis + spec.
> - v58: **core-worker gate made deterministic: the 19↔21 flake was
>   process-global test state, fixed three ways.** The core worker's
>   gate counts `cargo test --lib` failures against a baseline; the
>   same clean commit (823064a70) measured **19/20/21** across runs,
>   extras varying (`literal_literal_ops_are_widened`,
>   `const_string_test_folds_only_with_size_opt`,
>   `writefile_status_dead_drops_the_then_closure`), so the gate
>   flapped RED on a clean tree and rolled forward nothing. Root
>   causes, all shared-core (core worktree `backends/core`, landed on
>   main as d2ca28e49 through the worker's own GREEN finalize):
>   (1) `SIZE_OPT` (the `-Os` fold switch) was a process-global
>   `AtomicBool` flipped by tests mid-render of parallel tests — now a
>   `thread_local! Cell<bool>` (the CLI sets it in `main()` and renders
>   on that same thread, so production is bit-identical; per-thread in
>   tests). The pre-existing `SIZE_OPT_TEST_LOCK` stays as pooled-thread
>   belt-and-braces, and `literal_literal_ops_are_widened` now pins the
>   level its assertions were written for instead of trusting the
>   ambient flag. (2) Both `COMPILE_LOCK` sites take the lock
>   poison-tolerantly (`unwrap_or_else(|p| p.into_inner())`): one
>   panicking test used to cascade `PoisonError` into ~178 unrelated
>   reds in the main tree — the gate then measured the cascade, not
>   the defect. (3) The verdict statics (`LASTEXIT_DEAD`, `VAR_TYPES`,
>   the transforms' `VERDICTS`) are still populated by `ast_to_ir` and
>   consumed by `shir_to_estree` in SEPARATE lock acquisitions, so a
>   parallel test's `ast_to_ir` in the gap clobbers the first test's
>   verdicts; the full fix is the PassContext refactor AGENTS.md
>   already scopes, and until it lands the workspace now sets
>   `RUST_TEST_THREADS=1` via `.cargo/config.toml [env]` (`force=false`
>   so an explicit override still wins) — serial suite ~9s vs ~4s
>   parallel, and the failing set is now byte-identical run to run
>   (19, exactly the baseline). After: the worker went GREEN 11:44 and
>   12:14, advancing known-good to d2ca28e49. The separate,
>   pre-existing supervisor-SIGKILL storm (the "unidentified external
>   killer" repair-workers.sh documents) continued through all this —
>   a persistent /tmp/death-watch.sh now snapshots build-lock status,
>   waiters, kill-session sweeps and the full ps table 2s around each
>   core/estree supervisor death for the next diagnosis pass.
> - v57: **case-lowering: the shared Case→if/elif string-test lowering,
>   generalising estree's `try_native_case` to every code-generating
>   backend, and the one backend it forced into shape.** New transform
>   `transforms/case_lowering.rs`, registered and target-gated
>   (c/js/estree/perl/rs/rust/zig/java/python; the shell-family targets
>   render `case…esac` natively and an unset target/`shir` is the
>   byte-pinned embed path — refused per the split-in-place precedent).
>   All-static dispatch → if/elif over the shared primitives: exact →
>   `Not(Ne)` in test_lowering's both-sides `not_wrap` form, affix globs →
>   `contains`/`strHasPrefix`/`strHasSuffix`, catch-all → else, alternations
>   → ored conditions — with REFUSE>GUESS on volatile subjects
>   (`is_reserved_var`, seen through the optimizer's `getVar("name")`
>   lowering), impure discriminants (`pure_subject` recurses Interpolate
>   parts, so `"${v:-$(cmd)}"` refuses through its Capture), glob-class
>   patterns (the whole case stays fnmatch), leading catch-all,
>   dynamic/partial-quote patterns, a `nocasematch` mention anywhere in
>   the program, and non-code-gen targets. Two real-IR surprises cost the
>   first debug rounds: the optimizer lowers the dominant `case "$1"`
>   subject to `Call{getVar("1")}` — a DCE-safe read every backend renders
>   back as the variable itself (rust's var-tracking extractor sees
>   through it, perl renders `var_read`, so re-reading per condition is
>   the same value a single bound `$0` had) — and patterns arrive
>   quote-wrapped (`["\"start\""]`); without the getVar arm every corpus
>   case refused and 057's fnmatch count stayed at 20. (2) *java's
>   cond_bool grew the matching arms.* `Not` (render `!` over the inner
>   condition; operands that DIFFER cannot come from `not_wrap`, so Err
>   rather than pick a side) and the three substring primitives as
>   `String.contains/startsWith/endsWith` — booleans, because the existing
>   `shContains` helper returns long 1/0, wrong in a boolean context.
>   Measured: `057_case.sh --target java` was rc=1 `expr not in the java
>   subset (str ctx): BinOp{Not…}` with the transform on / rc=0 off; now
>   rc=0, `javac` clean, stdout matches bash modulo the pre-existing $0
>   convention (java's runtime prints `prog.sh`). Verified: 13 lib tests
>   (12 transform + a java end-to-end pin through
>   parse→ast_to_ir→shir_to_java); `./fail` full corpus **46/46 tokens,
>   560/560 examples** (coverage-proven substring set-cover, cron-ticked
>   resumable grind) → 7 distinct failing tests, **every one reproduced
>   with case-lowering disabled** (53-transform allow-list minus the new
>   name) or containing no `case` at all: 036_pattern_matching_basic,
>   double-bracket-pipeline, eq-string-num-var, func-after-or-assign,
>   func-after-test-or, or-continue, test-bracket-command-sub — all
>   belong to the in-flight test-lowering/typed-compare work
>   (`test_lowering.rs` mtime 2026-10-21 09:04, edited during the run;
>   resolved the same day — the completed statement-chain lowering's full
>   `./fail` is 560/560, see the 2026-10-21 revision entry below);
>   case-lowering regressions: **0**. `fail-estree`: `case` prefix 32/32
>   both arms; per-file sweep of all 53 case-content corpus files (a
>   no-`case` program is byte-identical with the transform on/off, so
>   those 53 are the entire risk surface) → 51/53 both arms, and the 2
>   estree-arm failures (062_hard_to_lex, 070_gnuisms_thorough) persist
>   with case-lowering off → not this transform. Rust arm: 057 fnmatch
>   call sites 20→5 (4 = the refused char-class clause + the runtime
>   preamble def/internals), rustc clean, old-vs-new baseline parity,
>   `./fail 057` PASS. *Operational attributions for the next session:*
>   (a) the CLI resolves the workspace root from CWD and exits 1
>   `cannot locate the workspace root (set OTRANSPILER_ROOT)` under cron
>   (cwd=/root) — measured 21 token-runs × 0 passed before the tick
>   script cd'd + exported it; (b) an external killer SIGKILLs
>   gate/tool-call trees every 5-30 min (the loop-repair supervisor
>   restarts) — background tool processes do not survive, cron-ticked
>   flock grinds with byte-offset completion checks do; (c) full
>   `cargo test --lib` currently shows ~195 failures as a POISON CASCADE
>   from another workstream's in-flight `Ext(ForEachLine)` (an estree
>   test's `unreachable!` fires while holding shir.rs's COMPILE_LOCK →
>   every later `ast_to_ir` unwrap dies PoisonError) — not this revision;
>   the stable pre-existing set remains the c_backend 9. Gitlink
>   deliberately not bumped: the worktree carries other workstreams'
>   uncommitted edits (same as v56).
> - v56: **interp-fold's assign-head refusal + the estree runner's missing
>   `int`/`lc`/`uc` — two gate regressions closed, one attribution pinned.**
>   (1) *interp-fold guard.* `interp-fold` canonicalises a never-wrapped
>   single-literal word `Interpolate([Lit(s)])` → `Str(s, DoubleQuoted)` so
>   every backend renders one plain literal and every `Str`-keyed fold
>   matches. But the rust `local`/`declare` value join reads the SHAPE of
>   the word directly AFTER a `…=`-ended head to tell the VALUE from the
>   NEXT declaration (parser lexes `local msg="hello"` as `msg=` +
>   Interpolate, `local a= b` as `name=` + bare `Str` — the quote is the
>   signal). Folding that piece to `Str` erased the distinction, so
>   `local x=+$(…)` / `local msg="hello"` folded to one `Str`, the join
>   refused, and the init rendered `""` (measured: 081_nested_functions
>   printed an empty `msg`). The fold now REFUSES in that position
>   (`prev_was_assign_head`, REFUSE > GUESS). Verified: rust equivalence
>   sweep **551 PASS / 0 STUB / 2 legacy MISMATCH**, sh2perl lib suite
>   **1405 pass / 9 pre-existing c_backend**, `./fail` chunked grind
>   **14/14 chunks, 0 failed** — output-neutral ON/OFF. (2) *estree runner
>   `int`/`lc`/`uc`.* The `typeset-attrs` transform emits `int(arith(…))`,
>   `lc(…)`, `uc(…)` as plain Call nodes; the estree backend renders them
>   as `sh2.int(…)`/`sh2.lc(…)`/`sh2.uc(…)`, but the reference executor's
>   `sh2` namespace (`harness/sh2-namespace.mjs`) only had `int` INSIDE
>   `evalArith` (`Math.trunc`, zsh mathfunc) — no top-level method — so the
>   estree arm of `typeset-cmdsub.sh` crashed `TypeError: sh2.int is not a
>   function` (runner exit 1, empty stdout). Added the three methods:
>   `int(v)` = truncate-toward-zero with non-numeric → 0 (bash `typeset -i`
>   / the arith evaluator's `int`), `lc`/`uc` = toLowerCase/toUpperCase.
>   `fail-estree typeset-cmdsub` → **ESTREE 1/1**; broad prefix spot-checks
>   (000__0/002/011 = 16 tests) **both arms 100%** — the methods are
>   net-new (no test could depend on their absence). *Attribution for the
>   next session:* `typeset-cmdsub`'s PERL arm still fails — that is the
>   PRE-EXISTING committed `typeset -f`/`-F` refusal
>   (`native_declare_typeset_stmt` keeps the exec call; `__sh_pipe_run
>   ('typeset -f f')` runs in a FRESH `bash -c` that never has the function
>   defined → empty display), not this revision. And `062_09_complex_function`
>   + `parse-heredoc-dollar-paren` fail ONLY the estree arm (stdout
>   mismatch; perl passes) — proven NOT interp-fold: a clean-HEAD build
>   with ONLY interp-fold registered renders both IDENTICAL to bash, so
>   the cause is another workstream's uncommitted estree param-expansion
>   lowering (`estree.rs` test rewrite for `store_var_read_no_fold`), not
>   this fold. Gitlink deliberately not bumped: the worktree carries other
>   workstreams' uncommitted edits.
> - v55: **brace-fold: a shared shIR→shIR expansion fold, `TOTAL` 2356 →
>   2302 (−54), and the descending-range bug it exposed.** All 52
>   `brace` callouts in the corpus are literal (prefix-Str + parsed JSON
>   groups/middles/suffix-Str — brace expansion is pure text), yet every
>   backend re-derived them AT RENDER TIME (ir.rs
>   `render_brace_word`/`render_brace_iter` plus per-backend
>   `brace_expand` copies), and the word-position rendering JOINS the
>   items into ONE word — bash-equivalent only for join-shaped
>   consumers. Probe (bash vs perl, /tmp/braceprobe): `echo A:{a,b}` and
>   for-iter were correct, but `printf 'P:%s|' {a,b}` printed
>   `P:a b|` (bash `P:a|P:b|`), `set -- {1,2}` gave `$#=1` (bash 2),
>   and `words=({p,q})` had `LEN:1` (bash 2) — latent because the
>   corpus only uses echo/for/iter shapes. New shared transform
>   `brace-fold` (`src/transforms/brace_fold.rs`, registered 3rd in
>   `transforms::all()` so it runs BEFORE `const-capture-fold`) splices
>   each literal brace call, through the CANONICAL now-pub(crate)
>   `ir::brace_expand`, into its word list — but ONLY in list positions
>   (Array / DeclareArray elements); bare scalar assignment,
>   conditions, redirect words, Interpolate embeddings, non-literal
>   args and empty `{}` all refuse (bash does NOT brace-expand
>   assignment values: `v=file_{a,b}.txt` stays literal — probed).
>   The fold cascades: `result=$(echo {1..5})` → splice → literal
>   words → const-capture-fold → const-prop kills the variable
>   (`011_brace_expansion.sh` TOTAL → **0**; −brace −exec −getVar in
>   one pass). The fold also EXPOSED and fixes (same revision, in the
>   canonical `ir::expand_range`): bash takes the step as a MAGNITUDE
>   with direction from endpoint order (`{5..1}` → 5 4 3 2 1,
>   `{1..5..-2}` → 1 3 5) — the old signed loop returned EMPTY for
>   every descending range, so `for i in {5..1}` rendered a
>   zero-ITERATION loop (measured: perl `(())` vs bash `5 4 3 2 1`),
>   and its 1024-item bound used the signed distance and never tripped
>   descending. Metric: **brace 52 → 0, exec 592 → 591, getVar 837 →
>   836, TOTAL 2356 → 2302**; every other class untouched. Verified:
>   lib suite 1388 pass / 9 fail (the 9 = pre-existing c_backend
>   baseline; brace_fold tests 13/13 stable ×6 runs), `fail-estree`
>   25/25 prefix runs green over exactly the affected examples (both
>   verdicts), full `./fail` corpus gate **560/560, 0 FAIL, 0 TIMEOUT
>   (14/14 chunks rc=0)** on the rebuilt binary, probe parity: p1 now
>   matches bash except the documented refused scalar-assign form
>   (0 corpus sites, pre-existing), p3 (descending/zero-pad) IDENTICAL.
>   Offered marketplace-style: `core-requests/transforms/offered/
>   brace-fold.rs/{transform.rs,register,manifest}` — scope: all
>   backends (output is plain Array-of-Str word lists, the parser's own
>   literal-word spelling; no new node types).
> - v54: **The `test` negation fix + glob-arm lifetime closure: `./fail`
>   560/560, `test` callouts −33.** `! [ … ]` used to lower to `!(0)` —
>   the negation dropped the operand's real decision and asserted the
>   constant false. It now wraps the actual predicate
>   (`!(strHasPrefix(…))`, …). Rendering that exposed a latent perl-only
>   crash path: the glob-arm primitives `strHasPrefix`/`strHasSuffix`
>   are emitted as bare calls with NO `sub` anywhere in generated perl
>   (c/rust/estree render them natively; perl had neither), so any
>   script reaching them died on `Undefined subroutine` — the corpus
>   never tripped it, the negation fix would have. Closed with the
>   gated-preamble house pattern in `perl_generator_fixed.rs`: the sub
>   is emitted only when its call site exists. Lift boundaries honored
>   (the renderer's in-flight glob-support pin): any `$` on the rhs
>   refuses the lift (equivalence-safe — the runtime path is a literal
>   compare for quoted rhs anyway), the unquoted-`$` refusal was
>   extended to the nonempty arm for POSIX word-split-error parity, and
>   `nocasematch` stays a runtime path. **Metric (post-pipeline, via
>   `plmetric`): `test` 192 → 159, TOTAL 2382 → 2349; every other
>   class untouched.** Verification: lib suite back at baseline
>   (1374 pass / 10 known), `fail-estree` 32/32 on the 16 changed
>   examples, behavioral probes confirm negation wraps the real
>   predicate and nocasematch still falls through to runtime. Full
>   corpus gate on the final binary: **`./fail` 560/560 PASS, 0 FAIL,
>   0 TIMEOUT** (14/14 chunks rc=0 + the one name the chunk partition
>   dropped). Harness addition: `fail` now honours
>   `OTRANSPILERL_SKIP_BUILD=1` (mirrors fail-estree's; binary-exists
>   check; default unchanged) — a no-op `cargo build` queues behind
>   peer core-role builds (>6 min measured under load) and was
>   starving the grind, not the transpiler.
> - v53: **The rust-frontend dogfoods the transpiler's own Rust source —
>   and the measurement says why that is hard.** The v0.2 goal of
>   `frontends/rust-frontend` is to lower ALL of `sh2perl/src` (208 `.rs`
>   files). New workspace scoreboard `harness/rust-dogfood.sh` measures
>   it reproducibly: run the frontend over every file from a
>   content-hashed snapshot, report the lowered/refused split plus a
>   first-blocker histogram, `--min` as a regression tripwire.
>   **Baseline 14/208 (6.7%) lower end-to-end; 194 refused.**
>   The decisive finding is structural, not a number: an instrumented
>   probe (catch_unwind at the per-function funnel) shows **~8460 blocked
>   functions across ~24 blocker classes, long-tailed** (match pattern
>   1821, nested item 795, unknown call 754, non-identifier `let` 704,
>   method-on-receiver 682, method-on-string 529, for-iterator 374, match
>   guard 322), and **each refused file carries 10–49 of them**.
>   Consequence: no single fix moves the whole-file count, so a fix must
>   be judged by the blocker CLASS it removes, not by files gained — the
>   histogram is the progress metric and `--min` is only a tripwire.
>   Measured on the four lowerings landed with this revision (v0.20):
>   `condition expression` fell **13 → 5** in the histogram while the
>   pass count stayed 14/208 and the function count stayed 693/9153.
>   Landed (each pinned t62–t65, each verified stdout-exact vs native
>   `rustc` by `harness/frontend-stdout.sh`): **`if let`**
>   (`Some(x)`/`None`/`_`, in statement, condition, else-if AND
>   value-returning-tail position — `if_value_node` gained an `out` slot
>   so the binding hoists where both branches see it), **`matches!(v, PAT)`**
>   in value AND condition position (sharing the match lowering's
>   `arm_cond`/`unit_variant_pat` so they cannot disagree), **`push` /
>   `push_str`** (setArrayAppend / str-concat), and **`Some(v)`/`None`
>   typing** in `infer_ty`. Two exactness bugs surfaced and were fixed:
>   bare `None` lowered to `getVar("None")` (reading an unrelated
>   variable by accident), and the `if-let` test was written UNQUOTED —
>   an unquoted empty expansion vanishes under word-splitting, so the
>   branch never fired; the oracle caught it, not inspection.
>   Refusal boundary kept (t64/t65): destructuring `Some(<non-name>)` and
>   `matches!` on a compound subject both refuse loudly.
> - v52: **Perl gate: seven examples fixed by root cause, zero regressions
>   (measured 472 → 479 / 560).** A perl-gate session triaged the failures
>   with an instrument that does not depend on the harness surviving the
>   box's external killer: `gate_chunk.sh` (per-example verdicts, resumable,
>   byte-equal stdout AND matching exit code, no bash-wrapper fallback,
>   perl compiles), run against a binary built from the PRISTINE `bc7a88028`
>   worktree versus one built from the fixed tree — the only honest way to
>   read a gate on a box at loadavg 26 where `./fail` dies every ~100
>   examples. Fixes, each with the root cause:
>   (a) **`__sh_fn_status` was injected before `our $CHILD_ERROR`** — the
>   injector walks past `use`/`my $main_exit_code`/`our $CHILD_ERROR`, but
>   the renderer emits `our @__sh_args` + `use feature` FIRST, so the helper's
>   bare `$CHILD_ERROR` was a `use strict` COMPILE error (051_primes emitted
>   nothing). The helper now re-declares the package global itself.
>   (b) **`fix_array_slice_bounds` never fired**: it gates on `array_var_pub`,
>   a thread-local census the shared renderer only populates during
>   `shir_to_perl` — AFTER our fixups. `${primes[@]: -10}` fell through to
>   `@primes[0..$#primes]` (051 primed every prime after "Last 10"). The
>   generator now populates the census from its own input first.
>   (c) **`local NAME=$(…)` dropped its value**: the glued
>   `Array([Str("name="), capture…])` word is skipped by the renderer's
>   `local` arm (`call_arg_str` is None on an Array). Split into the
>   `NAME=` + value shape the arm joins, and lower the one pipeline shape
>   that arm still drops (`echo … | sed …`, where every native path refuses
>   a stage reading caller variables) natively. Also covers `local -a`/`-A`
>   (`setArray` glued to a flag word).
>   (d) **Single quotes were invisible to `tokenize_test`** and unstripped by
>   `render_test_operand`, so `[[ -z '' ]]` became `!length('\'\'')` — a
>   TWO-character operand, inverting every emptiness test on a
>   single-quoted value (070's `empty: 0` printed `1`). Both now handle
>   both quote styles, and an empty quoted run still yields a token.
>   (e) **bc results were emitted as bare number literals**, so Perl numified
>   them: `scale=2; 5/2` printed `2.5` not `2.50`, and `0.5+0.25` printed
>   `0.75` not `.75`. Now quoted.
>   (f) **Interpolated `eval` payloads were refused**, falling to a `bash -c`
>   payload that names a command literally called `eval` (unesecutable) —
>   `075_eval_complex` printed nothing. The payload is now reconstructed as
>   shell text; `Arith` RHS admitted.
>   (g) **`while read … done < FILE | head -3` died on the redirect-in-pipeline
>   refusal** (091_while_pipe_var produced no output). The existing
>   capture-then-consume fold (sort) now also accepts `head`.
>   Filed `core-requests/pir-20261014-arith-nested-expansion-dropped.md` for
>   the one cluster that needs the parser: `$(( ${a:-0} + ${b[${i:-0}]:-0} ))`
>   loses its whole assignment silently (063_12).
> - v51: **The fb0 device NODE (the run-time half of the fb0 mechanism).**
>   bash-O4's fb0 "device" was a build artefact only — `src/devices.rs`
>   materialises the device's C *sources* into a content-addressed cache
>   dir for the linker's `-I` — so with no `/dev/fb0` on the box a shell
>   writing pixels, or a program opening the path, found nothing.
>   `bash-o4/src/fbnode.rs` publishes the node: ONE regular file at the
>   device path, `w*h*4` ARGB in the device mapping's layout (not the PPM
>   dump's), so `cat frame.raw > /dev/fb0` / `cat /dev/urandom > /dev/fb0`
>   / `cat /dev/zero > /dev/fb0` do what they say; `to_ppm`/`from_ppm`
>   bridge to `fb_dump_ppm`'s P6 layout, so a drawn frame can be written
>   into the node. Driver `--publish-fb0[=PATH]` / `--dump-fb0[=PATH]`,
>   `$FB0_GEOM`/`$FB0_NODE`/`$FB0_DEV`. **`/dev/fb0` has NO sub-files** —
>   the `/dev/fb0/blocks` lines in `MIMEcroft_fb.sh` are the pre-port
>   spelling the `fbdev-gpu` transform lifts and rewrites to an
>   in-process `fb_blocks(payload)` call; a per-verb node models
>   something that never runs (an earlier attempt did, and was stopped).
>   The boundary is asserted, not assumed: a userspace node serves pixel
>   writers but not `fb_try_dev`, which needs the fb ioctls + `mmap` and
>   correctly gets `ENOTTY` and falls back. Also fixed a real bug this
>   surfaced (`sh2perl` dacf1d585): `fb_clear 0xFF204060` lowered to
>   `(int)atoll("0xFF204060")` = 0, so all five `fb_clear 0xFF000000`
>   sites in `MIMEcroft_fb.sh` cleared to transparent black. See §11.14.
> - v50: **The fb0 port of MIMEcroft, and the fbdev fragment stage measured
>   as a GPU candidate.** The design: bash writes **structured text to
>   device files** and bash-O4 swaps the device. The WebGL device is
>   `sh2runtime/src/fs/webgldev.js:3` (Plan 9-style: every GPU resource a
>   file); the WebGL game is `sh2runtime/www/bin/mimecroft.sh` (4,990
>   lines, 92 `/dev/webgl` sites); the fb0 port is
>   `sh2runtime/tools/fb0/mimecroft-fb0.sh`, **generated** by
>   `sh2runtime/tools/fb_substitute.py`, which maps each `/dev/webgl/*`
>   write to an `fb_*` call of the same shape (re-run here: `72 writes,
>   11 reads`, output byte-identical to the committed port). **Two
>   orthogonal layers, and earlier revisions of this entry wrongly
>   collapsed them:** the *device swap* is implemented (drawing moved off
>   the GPU onto a CPU rasterizer); the *GPU leg* — `bash → ShIR → C →
>   tcc`, with hot loops → Vulkan compute (§4.4's `_sh_gpu_dispatch` host
>   split, §4.2 stage ⑤, and "gpu-prep passes" at stage ②) — is specified
>   but its emit half **"remains"** unimplemented, so `_sh_gpu_*` exists
>   nowhere in the tree. Candidacy's `body-redirect` veto
>   (`candidacy.rs:599`) excludes a loop whose *body* does device I/O; it
>   is **not** a prohibition on lifting a device write *into* a GPU
>   operation, which is the transform this entry's session was asked to
>   build and which has no home yet. Full mechanism:
>   **`sh2runtime/docs/fb0-port.md`** (new this revision); this repo's
>   §11.14 records only the bash-O4-side consequences. Positive findings:
>   a full range proof over `frag_pixel` (largest intermediate 255,000, so
>   the i64-in-two-ints pack is not a blocker; the `tr>255` clamp at
>   `fbdev.c:294` is load-bearing), and the real blocker is the `double`
>   texture UV in `frag_sample`, fixable with fixed-point ints — but
>   `tools/fbdev-frag.py` uses Python floats and would flag a correct
>   fixed-point rewrite as a regression, so a new oracle is required
>   first. Details in §11.14. No code changed.
> - v49: **A provider 429 no longer marks a worker TRAPPED, and a trap can no
>   longer sleep forever.** The perl worker produced nothing for 6.5 h on
>   2026-09-29 and looked dead; it was **asleep by design** behind
>   `core-requests/sleeping-perl`, and restarting it could not have helped
>   because it re-enters the same wait. Three independent bugs made a rate
>   limit look like a code problem. (a) `--run-backend-worker` escalated on
>   `fail_count >= 3` with no look at WHY the attempts failed, so three
>   `HTTP 429` retries — retriable in minutes — became a core-request and an
>   indefinite sleep, on a gate that never once failed to build; it now
>   detects the quota signal **in only the bytes the current attempt
>   appended** (a whole-log grep is poisoned by the 48 historical 429s
>   already in that log and by "rate limit" appearing inside a tool result)
>   and cools down instead. (b) A **rejected** core-request is filed to
>   `done/` without waking anyone, so the only exit is the `implemented`
>   branch — if nothing is ever implemented the wake is unreachable, and
>   `grep -c 'woke '` over the entire estree log is **0**; a lang is now
>   woken after `$SH2_REJECT_WAKE_GRACE` (default 2) rejections, and an
>   implementation clears the debt. (c) The trap sleep is now bounded by
>   `$WORKER_TRAP_SLEEP_MAX_S` (default 7200), after which the worker exits
>   so its supervisor restarts it and it re-gates. The log line still said
>   "backing off 30 min" long after that 30-minute loop had handed off to
>   the unbounded wait, so the message never said the wait was
>   open-ended. Diagnosis and the orphaned-`--worker-trapped` restart
>   caveat are in AGENTS.md §Worker traps.
> - v48: **Box-health: bound the page cache, the output bytes and the
>   process table — the WSL writeback wedge was never a transpiler bug.**
>   The incident looked catastrophic from inside: 1.4 TB written
>   cumulatively, io PSI 93–99%, loadavg 109 with 3 runnable, 58 of 75
>   D-state tasks in `__lock_buffer`, `init.scope/memory.peak` 47.07 GB of
>   47 GB total, and gates reporting "Can't fork". The measurement that
>   settled the diagnosis: `vm.dirty_bytes` was already 1.5 GiB, `Dirty` was
>   82 MB, and write rate 0 MB/s against a working 32 MB/s `io.max` cap. The
>   **IO path was working**; the hole was unbounded bytes and unbounded
>   page cache. Landed:
>   (a) **Byte caps in the gates** (`harness/cap-capture.pl`, wired into
>   `fail` (2 sites), `fail-estree` (4 sites), `harness/perl_gen_diffs.pl`).
>   `parse-error-block-in-pipeline.sh` mis-lowers a `while ! { :; }`
>   condition, so its translation never terminates: measured 1.0 GB of
>   "waiting" persisted FOUR times (a 1.0 GB `.pl` plus a 940 MB `.diff`).
>   `timeout 20` bounds wall time and did not help — the bound must be in
>   bytes. Two constraints shaped the design: RLIMIT_FSIZE does **not**
>   bound pipes (measured: 4 MB through a 512 KB `ulimit -f`), and the cap
>   must **drain to EOF** rather than truncate, because SIGPIPE is IGNORED on
>   this fleet (systemd `IgnoreSIGPIPE=yes`), so an early close manufactures
>   the `096_head_procsub.sh` orphan class. Cap 1 MiB vs a 7,470-byte
>   maximum legitimate corpus output, applied to BOTH sides of every
>   comparison. Also fixed a latent `perl_gen_diffs.pl` bug where a broken
>   diff reported `failing: 0 / 1`.
>   (b) **`memory.high` + `memory.reclaim`** (`harness/sh2-memory-reclaim.sh`,
>   3 units) on `init.scope`/`sh2workers`/`sh2gates` — the half
>   `sh2-contain.sh:31-40` explicitly declined to fake. This box is cgroup
>   v2 only; there is no per-cgroup async-writeback control, and
>   `memory.force_empty` is the wrong tool (it requires an EMPTY cgroup, so
>   it can never touch `init.scope`). Per-cgroup values, as built-in
>   defaults: they were originally env-only and the units silently inherited
>   a 9 GB generic fallback, pinning `init.scope` below its ~21 GB normal
>   floor for 75,616 high-crossings. Effect: Cached 34.9G→15.1G, io PSI
>   avg10 24.3%→1.3%, D-state 28→0, loadavg 28.5→5.7, zero `oom_kill`.
>   (c) **`init.scope/pids.max` 57795 → 8192** — the "Can't fork 551/555"
>   failure in AGENTS.md, on the cgroup where un-enrolled and
>   uninterceptable `shell_command` processes land.
>   (d) **`sh2-scratch-sweep.sh`** — `/usr/lib/sh2-tmp-sweep` only matches
>   `tmp.*`, so `tmp_run/perl-gen-diffs/` and `tmp_run/pg/` (the dirs that
>   actually grew) were never eligible at ANY age. Reclaimed 2.7 GB.
>   **One recommendation was investigated and REJECTED by measurement**: the
>   report's claim that agent scratch lived on the 98%-full 9p `/mnt/c` and
>   should be moved to a cappable device. It is 12 KB there, every harness
>   path is already on `/dev/sdd` (8:48), and open fds on any 9p mount = 0.
>   The 9p blind spot is real but unused. See AGENTS.md §Box-health guards.
> - v47: **Ext-node coverage for the workerless backends + a node-side
>   manifest gate (§11.12's "or lower to supported nodes" half).**
>   Measured first: isolating every Ext node `text-ops` emits and rendering
>   it per target showed python/java/sh render **zero** natively (python:
>   `mark_todo` on all 9; java/sh: a hard `Err`), c 2/9, zig 0/9 — while
>   perl/js/go were already 9/9. Landed (worktree `sh2perl/.ext-nodes`,
>   branch `ext-nodes`):
>   (a) **the shared registry now takes a per-backend child renderer**
>   (`ExprRenderCtx::with_child` + the `ChildExprRenderer` trait), so ONE
>   handler in `render_ext_expr/handlers/all_nodes.rs` builds a
>   target-language expression tree without re-implementing the backend;
>   (b) **python/java/sh gained `IrExpr::Ext` arms** that consult the
>   registry (`render_with`), plus python `need_re` detection from the
>   emitted text and 6 Java runtime helpers (shWcWords, shCutField,
>   shRegSub/shRegSubAll, shRegCount, shTakeLines/Bytes family, shTr*);
>   python went 0/9 → 21/22 nodes native, java 0/9 (all hard errors) →
>   21/22 + the helper preamble;
>   (c) **the core-side gate**: `transforms::transform_applies("text-ops")`
>   now consults `planner::node_manifest(target)`, so a backend that cannot
>   render the rich nodes keeps the ORIGINAL COMMAND (verified: `--target sh`
>   emits `cut`/`tr`/`wc` unchanged, byte-exact vs bash, while perl/js still
>   get the rich nodes). `planner::node_manifest` + `emits_renderable_nodes`
>   are the authoritative per-target node table, with unit tests asserting
>   every declared node HAS a handler and IS a real node type.
>   (d) **five latent bugs fixed in shared code** (all pre-existing, all now
>   caught by a cross-target bash verifier): perl `tr SET1 SET2` emitted
>   only three slashes (`tr/a/b;` — a perl SYNTAX error); perl `tr -d`/`-s`
>   interpolated a VARIABLE into `tr` (perl does not interpolate tr sets);
>   java `shBasename("/")` → `""` (bash: `/`); java `shDirname("a/b/")` →
>   `a/b` (bash: `a`); and the `substr_extract` handler file never matched
>   `snake(SubStrExtract)` = `sub_str_extract`, so that handler had NEVER
>   been dispatched (renamed; build.rs's warning was the only signal).
>   Verified: 42/48 byte-exact vs bash across perl/python/java/js in a new
>   targeted verifier (was 15/48); the 6 remaining failures reproduce
>   IDENTICALLY on the pristine main-tree binary (pre-existing `text-ops`
>   semantics gaps in `wc -c`/`wc -w` trailing-newline handling and one
>   python capture case), so zero regressions.
> - v46: **py2cy.js analysis moves into the Rust core.** `shir::analyze_declares`
>   computes final per-var declare decisions (int kinds, i64 containment,
>   vetoes incl. the cross-scope union veto, widths, `global`/`nonlocal`
>   exclusion); `--analyze` facts carry `declare` per var plus per-scope
>   `globals`/`nonlocals` (py-sh-go now emits `Global`/`Nonlocal` A1 nodes
>   and parses `nonlocal`; ingress validates and drops them, IrProgram
>   byte-identical). `harness/py2cy.js` renders decisions verbatim — no
>   policy, no source scan. 27/27 testdata outputs byte-identical across
>   the move; parity gate unchanged (25 pass, t102/t103 frontend refusals
>   pre-date it). Submodule 628b43a3.
> - v45: **Go stops misdeclaring module globals a function big-assigns.**
>   v44's known divergence is closed from the Go side: nested `global`
>   writes are module writes the module proof cannot see (interval env
>   and width stop at scope boundaries), so `x = 0` plus
>   `global x; x = 2**100` printed 0 under Cython. `vetGlobalWrites`
>   (frontends `autocython_ranges.go`, hooked in `AnnotateCython`)
>   keeps a module declaration only when every escaping write preserves
>   it — text RHS re-verified for storage width via `evalText`,
>   for-targets (missed by every kill-set, at both levels) prove elements
>   from range bounds and int/float-list literals, unmodellable forms
>   (`with`/`except`/`del`/`import`/`match`/def names) veto outright.
>   Narrow escapes keep working (`x = 5`, `for x in range(10)`);
>   function-level `nonlocal` never misdeclared and is untouched; zero
>   declare changes across 80 real-world files. Pinned by
>   `globalveto_test.go` (9 cases) and 8 `semantics-parity.sh` oracles
>   (3 failed before, 35 pass now). Submodule 99c2c1b4.
> - v44: **py2cy.js on Rust analysis + `otranspilerl --analyze` surface.**
>   New shared core analyses (all additive in `sh2perl/src/shir.rs`):
>   `arith_range_exact` (unbounded-int reading — overflow/div-zero/unknown
>   is unknown, floor `%`/`//`, comparisons `[0,1]`), `%`/`//` desugar
>   recognition (`((a%b)+b)%b`, `(a-pm)/b` evaluate with floor semantics),
>   `analyze_use_safety_stmts` (A1 port of Go `unsafeTypedNames`: unprovable
>   wrap-prone `+ - * **` and always-veto shifts/bitwise veto subtree vars;
>   comparisons/`%`/`//`/`/` never veto) plus the wrap-poison quarantine
>   (narrow claimed range over an inexactly-evaluable RHS vetoes —
>   `2**100` claims `[0,0]` under bash wrap), `analyze_widths` (i32 iff
>   value range AND every assigned-RHS subexpression fit — `h*31` forces
>   i64 while `h` stays mod-bounded), and per-scope facts
>   (`analyze_var_ranges_stmts`/`assigned_names`/`analyze_scopes`: fresh
>   walks so params stay unknown, module hull unions fn writes for the
>   invisible `global`, nested-loop-var fill python-gated). Shell-visible
>   behavior unchanged except the structured-Arith while-cond bound (never
>   fires on shell-lowered test/let-text conds). `otranspilerl --analyze`
>   dumps per-scope facts JSON (types, ranges, widths, vetoes, bigint,
>   assigned, params; A1 Function params re-read from raw JSON since
>   ingress drops the field). `harness/py2cy.js` annotates Python from
>   those facts (Go `--py` emission rules; no JS analysis) with
>   `harness/py2cy-parity.sh` (`cython --embed` oracle). Differential vs
>   Go: 92/100 byte-identical; 7 sound over-declares (Go text rules can't
>   see string-`+`/print-arg safety — all runtime-proven); t48 sound
>   decline (trip-counted accumulation stays with the lattice owner);
>   t102/t103 unlowerable by the A1 frontend. Known divergence (intended):
>   Go misdeclares module globals a function big-assigns (globig prints 0
>   under Cython); union vetoes refuse that shape here. Submodule 6aa24251.
> - v43: **6 pre-existing estree fails fixed (lib 622/0 green).** Real
>   miscompiles fixed: echo-split silently dropped folded literals
>   (`x=42` printed empty — now native field-split); cond_zero said
>   `false`/failing builtins/pipelines were zero (node exit 1 vs bash
>   0 — now trailing write kept). Aligned cond_zero Call arm with
>   expr_zero + pipeline-last-stage arm. Stale shapes updated with
>   execution proof (copy-prop folds to literals; dead program-value
>   flags dropped under live runner which reads exit via store+_finish;
>   provably-zero exits drop all writes): assignment (value+no-store
>   asserted), dead_flags_unwrap, loop_hoist_vetoed (veto still pinned),
>   sqrt1337 (zero writes optimal). Submodule 7c20bb6e.
> - v42: **isqrt range-seeding restored (`uint32_t` bounds back).**
>   `collect_isqrt_assigns` seeds structured `isqrt(Arith)` temps to
>   `[0, ISQRT_MAX]` (gated on the Arith arg; sound on fallback); the
>   existing `propagate_isqrt_derives` fixpoint folds the separate `+K`
>   temp. t86/t88 outputs regain `uint32_t` narrowing; stdout+ASan
>   match; `isqrt_temps_narrowed` guard (proven to fail without the arm).
>   Supersedes v40's dormant-seeding note. Submodule d20f2714.
> - v41: **Named function params — `all_factors(n)` everywhere it counts.**
>   IR `Function.params` (source names; empty = positional). py-sh-go
>   populates from `def`; materialization Assigns kept for positional
>   backends. C: named lifted signatures (`long long n`), `$N`→name via
>   `cur_params`, pure-copy + bare-Declare skips (single proto/definition
>   rule, `_p`/dup/collision fallbacks). estree: `function f(n)` +
>   entry `Number` coercion, `PARAM_NAMES` read mapping, bare-Declare
>   skip, reserved-name fallback (never `function f(let)`). Zig keeps
>   argv convention; python/go/rust/java/perl blocked on call machinery
>   (all red pre-existing); sh correctly excluded (no named params in
>   bash). Gates: 12/12 py def-tests C+estree match (decorators, varargs,
>   globals, bigints); C ASan/valgrind clean; tests/c_fn_params.rs.
>   Submodule 359fe738 (assistant-isqrt). NOTE for worker: range-seed
>   (`isqrt_text_max`) still text-based — Call-based seeding wanted.
> - v40: **Structured `isqrt` node kills the A1 arith-string detour.**
>   `int(Y**0.5)` (int-domain Y) now lowers to `Call{func:isqrt}` — no
>   `arith("int(sqrt(..))")` string, no string temp, no `+0`
>   re-numerify (t86 A1: zero strings; `_i_sqrt_nv: Int` single structured
>   bound temp pair). tryIsqrtIR/tryIsqrtHoist feed hoistFloatIR +
>   hoistIntOperand (two native temps, plain-Var cond — fold/cstyle only
>   handle Var/Num bound text). Native renders: C `_sh_isqrt` (exact
>   Newton), estree `Math.trunc(sqrt)` (CPython parity), zig/perl/python
>   /rust 1-liners; sh/java/go keep graceful fallbacks (red-preserving).
>   Caught+fixed latent `_sh_isqrt` init overflow at i64max (unsigned;
>   new exact-values test incl. boundaries). Bigint/float/general shapes
>   keep the legacy string path. Gates: t86/88 C+ASan+valgrind+estree
>   match; 91/91 estree unaffected (no isqrt nodes elsewhere); red
>   backends stay red. Submodule 1b0406f5 (assistant-isqrt merged with
>   worker main). NOTE: bound range-seeding (isqrt_text_max, u32 narrow)
>   went dormant with the strings — worker to add Call-based seeding.
> - v39: **py-sh-go int-domain function locals — t86 `n`/`i` are C/Zig
>   locals now, not file-scope globals.** Frontend emits bare
>   `Declare(local:true)` scope pins for int-domain params + range-loop
>   counters (initializing Assigns unchanged, so Assign-keyed analyses
>   see identical IR). C renders `long long` function locals, Zig renders
>   `var` locals; estree stays 91/91 (renders `local` builtin calls).
>   Two minimal backend exemptions (submodule f01b1fa3): lift_scan
>   Declare arm (bare = lift-neutral) + numeric_lift bare-Declare
>   writeless rule (no store write = no numeric exclusion). Bigint-domain
>   and top-level vars untouched (no Declare+mpz path yet; module-scope
>   leak keeps the hoist) — t89 keeps file-scope `mpz_t`. New
>   `sh2perl/tests/c_fn_locals.rs`: positive (locals, no col-0 decls) +
>   counter-test (post-call top-level read keeps the global). Gates: C
>   stdout+ASan+UBSan+valgrind clean on t86/87/89; shell→C byte-identical
>   on samples (c_gate_main 45 fails are pre-existing worker/env
>   breakage, proven innocent by revert-diff); 6 estree lib-test fails
>   likewise pre-existing.
> - v38: **Backend node manifests + a core solver (the "solve" idea) — first
>   slice landed.** Records the mechanism by which a backend declares the
>   shIR node types it renders natively (`backends/<lang>/nodes.txt`) and the
>   core reduces input nodes into exactly those types (candidate table +
>   BFS solver + `sh2.*` fallback). Full design: `sh2perl/docs/shir-primitives.md`
>   (also `s2p.rust/docs/shir-primitives.md`, `PLUGGABLE_NESTED_TRANSFORMS.md`);
>   PLAN §11.12. First-slice implementation: `sh2perl/src/transforms/planner.rs`
>   (`Capabilities` manifest loader, `candidates()` catalogue, `plan()`
>   solver; unit-tested against the JS/Perl/C three-manifest scenario).
>   NOT yet wired into `text_ops`/the pipeline — blocked on the §11 gating
>   note's missing per-backend transform selection (the shared crate runs
>   `transforms::apply()` for every backend). Also this round: c_backend
>   clang-analyzer fixes (sorted-join helpers) + `setArray` empty-literal
>   length reset (t86_factor output now matches python3).
>   **v47 UPDATE:** the NODE-side half is now wired (see v47 and §11.12):
>   `planner::node_manifest(target)` + `emits_renderable_nodes(target)`, and
>   `transform_applies("text-ops")` consults them, so the core keeps the
>   original command for a backend that cannot render the rich nodes. The
>   per-backend transform selection this entry was blocked on exists
>   (`transforms::target()`/`transform_applies`) — it is what the gate now
>   uses.
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
| sh2perl backends | Perl only. `src/ir.rs` = Perl-specific IR with `RawText` bridges; `pub mod mir` commented out. **ESTree emitter exists** (`sh2perl core::estree::ast_to_estree_json`, v0 `sh2.*` namespace) and passes the full corpus. Workspace layering: `sh2perl core` (core lib) ← `otranspilerl` (CLI lib, member `cli/`) ← `otranspilerl-cli` (3-line bin). WASI: `build-wasi.sh` → `otranspilerl-cli.wasm` (command, `_start`) + `sh2perl core.wasm` (library, `wasi-lib` feature, C-ABI `otranspilerl-cli_to_perl`/`otranspilerl-cli_to_estree`) + **`otranspilerl.wasm`** (library, `wasi-cli` feature, C-ABI `otranspilerl-cli_cli_run(_json/_with_input)` — the full CLI as a library call, "otranspilerl-cli in three lines of JS"; deployed with README + examples to `~/js/`). |
| Tests | `fail`: otranspilerl-cli → Perl → `check_qx.pl` gate → run vs `bash` → normalized stdout + side-effect compare. 516 examples, **PERL 432/84, ESTREE 516/516 (100%)**. `fail-estree`: perl + estree verdicts per example (Stage A); `--gate` Stage B (strict: a failing test is a bug — no failing-test allowlist; the M5 blessed-fail list was removed as a guardrail violation, see revision history); `--metric` sh2.* call-site tallies (improvement-mode awareness). |
| Box health (v48) | The failure mode is a **page-cache / writeback wedge**, never a CPU or RAM shortage. cgroup **v2 only** — no v1, no per-cgroup async-writeback control, and `memory.force_empty` is unusable (needs an empty cgroup; can never touch `init.scope`). Bounds now in force: `io.max` 32 MB/s (working, measured 18/32), `memory.high` per-cgroup (init.scope 24G, sh2workers 8G, sh2gates 9G) + `memory.reclaim` on a 60s tick, `init.scope/pids.max` 8192, per-example stdout capped at 1 MiB in both gates, and a 6-hourly scratch sweep. The **9p mounts are not a write hotspot** — every harness path is on `/dev/sdd` (8:48, the device `io.max` caps) and open fds on any 9p mount = 0. Full rationale and the rejected 9p recommendation: AGENTS.md §Box-health guards. |

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
  exports. New `wasi-cli` feature exports `otranspilerl-cli_cli_run(argc, argv)` /
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
- **2026-09-12 — pyjs stack merged, parked for worker.** Rounds 5–12
  (`pyjs-r5`…`pyjs-r12`: nested temp fold, coerce/string/bigint facts,
  append fusion, String/concat/join/template elision, let inline,
  `||0` elision) merged onto worker `a65d2475` as `merge-pyjs-r12`
  (`72cdb9f4`, clean merge) in `sh2perl`. Verified: lib 682/0 (1
  pre-existing C-aggregate failure), c_fn_* green, 93/93 estree valid.
  NOT bumped: `tests/c_isqrt.rs` is 3-red against worker's in-flight
  isqrt redesign (2 fail on clean base too) — worker updates the tests
  to the new `sh2_isqrt` design, then bumps the gitlink. Worker
  checkout dirt untouched.

- **2026-10-19 — text-capture-fold (shIR→shIR): raw-text command
  substitutions fold to literals.** The raw-text twins of
  const-capture-fold: `[ "$(echo hello)" = hello ]`, `case x in
  $(echo p*)…`, `${v:-$(echo dflt)}` and friends keep the substitution
  as TEXT (no Capture node exists in the A1), so every renderer
  re-derives it at render time — Perl spawns a
  `__sh_pipe_capture('echo …')` fork per operand, estree emits a
  `sh2.captureSync`. The new registry transform
  (`src/transforms/text_capture_fold.rs`, default-on) folds
  provably-constant substitutions (const-echo argv → its literal
  output, trailing-newline stripped) into the surrounding text,
  across Interpolate parts, Str operands, test/arith/case-pattern and
  `${var:-…}`/`${var#…}` slots; refuse>guess — any word splitting,
  glob risk, non-const argv or non-literal context stays verbatim (15
  unit tests incl. the unquoted-multi-word and quote-preservation
  refusals). Shared shIR→shIR: every backend benefits; nothing
  renderer-owned. Same-binary A/B over the corpus (SH2_TRANSFORMS
  gate, all 52 transforms except this one vs all): Perl `__sh_*`
  CALL SITES 939 → 902 (−37), all `__sh_*` mentions 4963 → 4808
  (−155, incl. now-unreferenced preamble helpers), JS `sh2.*` 6187 →
  6176 (−11). Verified: transform module 15/0; `./fail` 560/560. JS
  output changed for 63 examples → each gated through fail-estree
  individually (SKIP_BUILD pinned binary): 59/63 green; the 4 reds
  (062_09, 062_hard_to_lex, typeset-cmdsub + 064_hard_to_generate's
  perl arm) fail IDENTICALLY with the transform disabled — the first
  three are the documented pre-existing baseline reds, and 064's is a
  renderer gap independent of ALL 52 registry transforms
  (SH2_TRANSFORMS=__none__ reproduces): the `2> errors.log` redirect
  on line 88 is dropped (the generated perl never mentions it) and
  `glob('*.dat')` yields no iteration on an empty match where bash's
  `*.{txt,log,dat}` expands the literal — visible only in
  fail-estree's clean per-test cwd, since `./fail` runs both arms in
  the workspace root where errors.log / *.dat already exist. NOT
  committed: the tree is mixed-ownership (concurrent pyjs/isqrt/rust
  WIP in the same files; PLAN.md itself was rewritten mid-session).

- **2026-10-19 — const-capture-fold extended: quoted-echo /
  literal-printf / const-chains fold to Perl literals.** The capture
  twin of text-capture-fold: `x=$(echo "lit")`, `x=$(printf '%s' hi)`
  and `x=$(cmd1; cmd2)` with const-status stages kept a Capture node,
  so Perl emitted a `do { local *STDOUT; open(STDOUT,'>',\$__cap) …}`
  block per capture (plus a status-write litter per stage) even when
  the produced text was provably constant. Three new arms in
  `src/transforms/const_capture_fold.rs` (same registry entry,
  default-on): (a) echo whose Interpolate parts are all literal, (b)
  printf with a literal format and literal args, evaluated by its own
  evaluator (`%s`/`%d`/escapes; refusals rather than width/precision
  guessing), (c) `;`-chains / `&&` / `||` lists where every stage's
  status is const and the textual output is const — folded by walking
  the chain with an accumulating status, recursing into nested
  chains. refuse>guess throughout (env-dependent argv, glob risk,
  non-literal context). 13 unit tests. A/B against a binary rebuilt
  from the HEAD version of the transform file (old-vs-new code is not
  separable via SH2_TRANSFORMS — it is one registry unit, so the
  env-gate A/B can only measure the whole transform): corpus Perl
  capture do-blocks 962 → 939 (−23), external `__sh_uu_run` sites
  503 → 499 (−4); 13 PL / 12 JS examples changed, every changed JS
  example gated individually through fail-estree (12/12 green, both
  arms); `./fail` 560/560; module 13/13; lib suite single-threaded
  1360 pass with only the 9 pre-existing fold-independent c_backend
  WIP failures. One pinned c_backend test (p1_strdup) had its
  fixture switched from `x=$(echo hi)` (now a literal — no strdup
  site survives) to a dynamic capture, preserving the test's subject.

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

**A FAIL-BACKEND cell is not a core request.** By construction the cell
means: the estree REFERENCE matched native (so the frontend's A1 is
correct) and the backend did not (so the defect is in that backend's own
renderer). The signal is not lost — the row still lands in
`triage/verdicts.tsv`, which is where a backend's gate reads it — so
routing it into `core-requests/` only re-fed the core queue cells that
by definition the core cannot fix. Backends that later want a core
change still have the documented channels: a contract-gen spec, a
transform offer, a bundle, or an analysed-bug `.md`.

**A FAIL-BACKEND cell must not be filed on one backend's evidence
alone.** `triage.sh` derives "matches native" from a *run* that can be
empty for reasons that have nothing to do with the renderer: a missing
link flag (`-lgmp`, `--extern num_bigint`) fails at LINK time and yields
empty stdout, which diffs as "differs"; a wrong interpreter produces
garbage that reads the same way. The `096_head_procsub.sh` procsub leak
makes an entire run non-deterministic too. So a cell is evidence only
after the same A1 has been re-rendered on another backend: **if a second
backend reproduces native byte-for-byte on the identical A1, the ingress
and the IR are proven sound and the gap is the renderer arm.** That is
the check the core applies before rejecting, and it is cheap — the
core only has to render the A1 a second way, not fix anything.

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

### 11.10 otranspilerl-cli/otranspilerl deleted — otranspilerl is the only CLI (landed)

The two-crate ancient CLI layer (sh2perl `cli/`: `otranspilerl-cli` flag-level bin +
`otranspilerl` processor; the in-repo `otranspiler` bin that spawned a sibling
`otranspilerl-cli` for every stage) is deleted. Fold result:

- **otranspilerl-cli** (workspace crate) is the only user-facing CLI; the
  harness (`fail`, `fail-estree`, `fail-shir`, backend gates) runs it
  exclusively. Flags folded in: `--target estree` (otranspilerl-cli's direct
  `file --estree` path, byte-verified), `--true64`/`--bigint`.
- **`shir_render`** (src/bin/, core crate) — the generic A1→target
  renderer; the backend worktree gate's entry (`--target <lang>`, stdin
  `-`). The per-backend `*_backend` bins stay (workers' library-path).
- **Workspace harness migrated**: `otranspilerl-cli --shir` → `otranspilerl-cli
  --target shir`; `--shir-in-<lang>` → `shir_render --target <lang>`;
  `DEBASHC_TRANSFORMS` → `SH2_TRANSFORMS` (legacy name still read as an
  alias inside transforms::apply). Isolated-verify builds now compile
  otranspilerl-cli; fail-shir's override env is `OTRANSPILERL`.
- **Legacy deleted**: 19 dump/debug bins, the 36k-line legacy generator +
  `legacy-generator` feature (its one hook, `ir::generator_emulate_command`,
  is now the permanent None arm — emulation moves into the perl renderer
  proper), the wasi-cli/otranspilerl-cli_cli_run wasm layer (otranspilerl's
  `otranspilerl_cli` export supersedes it), build-wasi.sh rewritten to two
  artifacts (otranspilerl-cli.wasm + the core/unified ABI libs).
- sh2perl is now a library-only crate (lib + worker bins + convert_examples
  + shir_render). `otranspilerl-cli`/`otranspilerl` mentions purged from code, docs,
  scripts, and generated-code markers (`die "otranspilerl: ..."`).

Parity at the fold: estree byte-identical vs `file --estree` (547/552; the
5 parse-error cases improve — the old path leaked `Parse error:` onto
stdout mixed with the JSON); A1 and perl renders are otranspilerl's
already-gated forms (old path leaked DBG lines / banners / dropped
stmt_lines).

### 11.11 uu-ffi perl adoption = the auto-decide seam (landed)

The perl backend's external commands route through `__sh_uu_capture`/
`__sh_uu_run` (ir.rs `SH_RUN_EXT_PREAMBLE`): BEGIN probes for
`libcoreutils_ffi.so` (SH2_UU_LIB → workspace walk → soname) and
attaches `uu_run` via FFI::Platypus; absent ⇒ one stderr warning +
guarded fork/exec fallback. Capture = temp-file fd-1 redirect around
the in-process call (no pipe ⇒ no drain deadlock; no C wrapper .so for
perl). Renders carry both arms — byte-deterministic across boxes.
check_qx strips the marker block (guarded fallback ≠ the qx-cheat);
`fail` exports SH2_UU_LIB. Corpus: fail 277→291 (the date/capture
check_qx class cleared). Residue: `basename $(pwd)` (cmdsub-in-args —
complex path, honest), the .so FEATURES list (date/sha256sum/uname
exist in uutils, not yet built), and the both-mode parity gate.

### 11.13 Model rotation: A/B the two models, not the workers' reflexes

**Problem.** Manual, human-driven model sessions are consistently faster than
the autonomous workers, and it was not clear whether that was the models, the
prompts, or the harness. Without a controlled comparison, "the workers are
slow" is a guess. A second symptom made measurement impossible: a Laguna
daily-quota stall (`HTTP 429 … free-models-per-day`) made `pir` retry the same
request forever — 19 consecutive attempts, and 28 for C — sleeping an hour per
attempt with zero work done.

**Design.** Two models, two FIXED groups, swapping every 4 hours: group A =
rust + c, group B = perl + estree. Group membership never changes, so the swap
does not confound model with worker difficulty. Core is LLM-free and is never
assigned a model. Selection is a command-line argument (`cmd --model <id>`);
the only persistent state is one epoch timestamp, because a worker's
environment is frozen at process start and cannot implement a swap by itself.
Swaps land at **invocation boundaries** — a call that started before a
deadline finishes on its original model, and no worker is signalled, restarted
or killed. Scoring is NORMALIZED gate progress per wall-clock hour and per
token (raw fail counts are incomparable across corpora of 555/647/648), and the
ranking is withheld until every worker has a measured interval under both
models — one worker on one model is not a comparison.

**Two findings that changed the implementation.**

1. The Laguna model id was wrong in a way that looked like a broken worker.
   `cmd` rejects the OpenRouter colon form (`poolside/laguna-s-2.1:free`) as an
   unknown model; the catalog id is hyphen-separated. The id is now verified
   against the catalog and a live call, because a rejected id is
   indistinguishable from a stalled one.
2. `cmd`'s `run_end` frame embeds the ENTIRE workspace git status and the full
   message history — ~4.8 KB for a one-word reply, megabytes for an agentic
   session. Echoing it unbounded is the same log-blowup class as the
   2026-08-14/15 incident, so the wrapper strips `nextState`/`modState` (the
   usage block, which is what we log it for, is also in the `result` frame).

**Quota fallback is at the worker-script layer, not inside the CLI.** `pir`
retries a 429 internally forever, so a script cannot learn the quota from the
child's exit status — the child never exits. It reads the streamed retry notice
instead, and on the exact `free-models-per-day` marker (OpenRouter's own code,
absent from the corpus) retries the SAME prompt on
`ollama-cloud/deepseek-v4.1-flash`, one-way and at most once. Non-markers
(plain 429, weekly limit, billing, 5xx) keep the existing infinite retry. The
`pi`-specific quota gate was scoped to `WORKER_CLI=pi`, since a stale `pi` 429
marker was otherwise able to suppress a `cmd` invocation — and with it the
fallback.

**Files.** `harness/ai_invoke.py` (model-per-phase + wrapper + telemetry),
`harness/model_report.py` (init-rotation/record-gate/status/report),
`harness/ai_fallback.pm` (shared Perl-loop detection), `harness/MODEL_ROTATION.md`,
`tests/test_model_rotation.py` (25), `harness/test_worker_fallback.sh` (10).
Telemetry is `null`-not-zero: an unmeasured call is unknown, not cheap.

### 11.12 Backend node manifests + a core solver (the "solve" idea)

The §11 marketplace governs TRANSFORMS. This subsection records the
companion mechanism for NODES: how a backend declares which shIR node
types it renders natively, and how the core reduces input nodes into
exactly those types. Full design: `sh2perl/docs/shir-primitives.md`
(§"Backend node manifests + a core planner"; also mirrored in
`s2p.rust/docs/shir-primitives.md` and `PLUGGABLE_NESTED_TRANSFORMS.md`).

**The mechanism.** Each backend declares its native node set in a plain
`backends/<lang>/nodes.txt` (one node type per line; `#` comments;
`sh2.*` = the runtime fallback namespace). The core keeps a candidate
table per shell command (a priority list of compositions, each tagged
with the node types it requires) and SOLVES a reduction into the
backend's declared nodes: filter to candidates whose required nodes are
reachable, pick the lowest-priority one, recurse into composite nodes
(a typed directed reduction graph, solved by BFS/shortest-path), and
fall back to `sh2.*` / the original command when nothing is reachable.
Adding a backend = writing a text file; no code change.

**Why.** The core decides what `wc -l`/`cut`/`tr`/`sed` mean once;
backends implement only their declared leaves. A regex-fearing backend
gets a char-loop count, a regex-rich backend gets `RegCount` — the core
picks per manifest, no backend re-derives semantics or reinvents the
wheel. This is the shape `text_ops` grows into (a manifest-driven
planner instead of a single hard-coded lowering).

**Status.** Design doc + first-slice implementation landed
(`sh2perl/src/transforms/planner.rs`: `Capabilities` manifest loader,
`candidates()` catalogue, `plan()` solver, unit-tested against the
three-manifest JS/Perl/C scenario). **v47 wired the other half of the
mechanism — the NODE-side manifest** — into the pipeline:
`planner::node_manifest(target)` is the authoritative per-target table of
which rich Ext nodes a backend renders natively, and
`transforms::transform_applies("text-ops")` consults
`planner::emits_renderable_nodes(target)`, so the core DECLINES to emit a
node the target cannot render and keeps the ORIGINAL COMMAND instead (the
command form is exact on every backend). Verified: `--target sh` keeps
`cut`/`tr`/`wc` byte-exact while perl/js still receive the rich nodes.
`build_wc_l`/`plan()` remain reachable only through the opt-in
`text-ops-planner` transform. Unit tests assert every declared node has a
real handler file AND is a declared node type (so the table cannot drift
into naming a node nothing renders). Each candidate must still be
corpus-proven byte-exact per backend before it is offered (the doc's
extended guardrail; e.g. `wc -l → Split+ArrayLen` is off-by-one on the
trailing newline, so it is only offered to backends that accept it).

### 11.14 The fb0 port of MIMEcroft, and the fragment stage as a GPU candidate

Recorded 2026-10-09 after a session that began as "can we port fbwin to
bash?". **No code was changed to write this.** The port itself and its
full mechanism are documented in `sh2runtime/docs/fb0-port.md`, which owns
that description; this section records only what bears on the bash-O4
side.

**The design.** MIMEcroft never writes pixels. It writes **structured text
to device files** (`echo "$blk_p" > /dev/webgl/blocks`,
`echo "swap" > /dev/webgl/call`) and a device interprets them — Plan
9-style. The WebGL device is `sh2runtime/src/fs/webgldev.js:3`; the native
one is `sh2perl/runtime/fbdev.h:1` ("A native (no WebGL) sink for a shell
script's draw calls"), with **three surfaces in order of preference**:
a real `/dev/fb0` mmapped (`fbdev.c:958`, `fb_try_dev(dev ? dev :
"/dev/fb0", w, h)` with `FBIOGET_VSCREENINFO` + `mmap`), else an X11 window
(`fbwin.c`), else RAM dumped as a PPM.

**Two layers, and they are orthogonal — do not collapse them.**

*The device swap (implemented).* The fb0 port moves the drawing off the
GPU: a WebGL device replaced by a CPU rasterizer that mmaps a framebuffer.
`fbdev.c` has no GL/EGL/Vulkan call, by design. It is generated by
`sh2runtime/tools/fb_substitute.py`, a rule table mapping each
`/dev/webgl/*` write to the `fb_*` primitive of the same shape; re-run here
it reports `72 writes, 11 reads` and reproduces the committed port
byte-for-byte.

*The GPU leg (specified, emit-half unimplemented).* bash-O4 is a compiler
whose stated end state is `bash → ShIR → C → tcc → native binary`, with
"hot pure-compute loops → Vulkan compute shaders (SPIR-V)" hanging off it
(`docs/BASH-O4.md`, executive summary). **§4.4** ("Codegen: host split +
device shader") is where the C backend would emit an
`_sh_gpu_dispatch(...)` call site per candidate loop, SPIR-V blob beside
it and the CPU loop always emitted as the correctness firewall; §4.2
stage ⑤ names the same emit, §4.2 stage ② names "gpu-prep passes (§4.3)"
as the transforms step, and the status note records that this dispatch
**"remains"** — designed, not built. `_sh_gpu_*` has no implementation in
the tree today.

**Where device writes sit in that.** Candidacy's rule 2 vetoes
`body-redirect` (`bash-o4/src/candidacy.rs:599`) — a loop whose *body
performs* device I/O cannot be offloaded as-is. That is a statement about
loop bodies, **not** a prohibition on a device write being *lifted into* a
GPU operation; those are different transformations, and conflating them
would wrongly rule out the lift. The loop-level shader axis is described
separately in `sh2runtime/WRITING_GPU_SHADERS_IN_BASH.md:23`: *"if your
bash needs a process, a file, or an external binary, it cannot run on a
GPU"* — precisely the constraint a device-write rewrite must work within,
since a device write *is* a file operation.

**Status of the port: do not overstate it.** Startup, the shader report,
all 16 block textures, the treasure labels, per-frame key reads, the render
loop and a clean `q` exit are verified by running it. A **scored
playthrough is not**, and there is **no byte-exact oracle yet**. The
equivalence suite that would supply one is
`sh2runtime/mimecroft-fb-equivalence.sh` (25 scripted walks, diffing real
bash + `fbrefr` against the bash-O4 build). At least three variants of the
program now exist across the two repos — the WebGL source, the generated
port, and the suite's oracle — so future work should name which one it
means; `wc -l` and a function count tell them apart, and the READMEs do
not (one size table in `sh2runtime/tools/fb0/README.md` had gone stale and
has been corrected).


**Why the fragment stage cannot be submitted as it stands.**
`candidacy::analyze` takes an `IrProgram` (`bash-o4/src/candidacy.rs:61`),
fed by `pipeline::parse_to_shir` (`cli.rs:184`) — it never sees C. The
fragment stage is `frag_pixel` in `sh2perl/runtime/fbdev.c:278`, which is
hand-written C compiled by tcc. The shell *does* drive the device (that
is the design — `fb_blocks`' payload), but the per-pixel arithmetic is on
the far side of the boundary, inside the C device, so there is no ShIR
loop for candidacy to see and no verdict is produced. `--check` reports
on the transpiled *script's* loops and never on the device's. The
script's own draw loops are no help
either: they are `while [ … ]` shapes, which `walk_stmts` explicitly
skips ("`While`/`DoWhile` are not counted shapes").

**The range proof, and what it settles.** Enumerated every intermediate
in `frag_pixel` (`fbdev.c:290-331`) against the input domains the code
actually establishes — `tr/tg/tb` 0..255 (`fb_texture:164` clamps),
`shade` 500..1000 (`fbdev.c:841`'s aShade table, ×1000),
`damage` 0..level (a `bhp` hit counter, `bhp_inc` adds 1), `ca` 0..255
(`uint8_t`), canvas ≤ 1920×1080:

| intermediate | max | fits i32 |
|---|---|---|
| `tr*shade` | 255,000 | ✓ |
| `r = tr*tex_r/128` | 508 | ✓ |
| `r*90/100` | 229 | ✓ |
| `mix = damage*ca/4` (damage ≤ 256 assumed) | 16,320 | ✓ |
| `(r-cr)*mix/128` | 32,385 | ✓ |
| `r*dim/256` (dim ≤ 30) | 29 | ✓ |
| `hash = px*7+py*13` | 27,480 | ✓ |
| vignette `vx+vy` | 1,500 | ✓ |

Largest intermediate **255,000** (≈8,400× inside i32). Note `tr` is
clamped to ≤255 at `fbdev.c:294` **before** `r = tr*tex_r/128` at
`:299`, so that product is at most 508 — NOT the ~508,000 a naive
`255000*255/128` would give. The clamp is load-bearing for the bound.

**The i64-in-two-ints pack is therefore NOT a prerequisite for
this candidate** — `docs/BASH-O4.md:108,143` lists it as the blocker for
GLSL integers generally, but `frag_pixel`'s values never leave i32, and
GLSL ES 3.00 `int` division truncates identically to C's on positive
operands. Recorded so nobody adds the pack later "for safety".

**The one real blocker: `u,v` are `double`.** Everything above is
integer; the sole non-integer is the texture UV in `frag_sample`
(`fbdev.c:224`): `u = u - (double)(long)u; iu = (int)(u * t->size);`.
Under GLSL that is two behaviour changes — `(double)(long)u` truncates
toward zero while `fract()` is `x - floor(x)` (differ by 1.0 on the
negative UVs a clipped face interpolates), and a GPU float→int
conversion is implementation-defined where C's is not. Note the *overlay*
path already does this the integer way
(`fbdev.c:764-765`: `tu = (x - corners[0]) * t->size / (corners[2] - …)`),
so the fix is to make the world path match the overlay path: carry UV as
fixed-point `int`, removing the double from `frag_sample`, `tri_shaded`,
`frag_pixel` and `fb_frag_color` (~40 lines of C).

**The oracle problem, which must be resolved before the fix.**
`sh2perl/runtime/tools/fbdev-frag.py` is written from the shader in
Python **floats**; it would agree with today's double implementation and
**report a correct fixed-point rewrite as a regression** at exactly the
negative-UV and rounding edges. It is the wrong oracle for that step.
The right ones are `fbwin-oracle.c` (reads real pixels back through the
X server, a separate process — "agrees with itself proves nothing about
the blit") plus a *new* fixed-point reference written from the shader
independently, per that file's own "two programs that agree because they
share a bug is not a test".

**Sequencing, if this is picked up.** (1) add the fixed-point reference
oracle; (2) transcribe `frag_sample`/`tri_shaded`/`frag_pixel` to integer
UV and verify against `fbwin-oracle` readback; (3) inline or lift
`frag_sample` so candidacy rule 2 can see its body (it is pure and
affine-indexed, which rule 4 permits); (4) only then does the loop become
submittable — and it is then the *best* candidate in the tree: a bounded
2D loop of pure integer arithmetic, with an existing independent oracle
and a byte-exactness requirement that GPU integer semantics satisfy more
easily than C doubles do.

**The bash-port question that started this.** `MIMEcroft_fb.sh` as
shipped cannot run under plain bash: 95 call sites of `fb_*` primitives
that exist only as C in `sh2perl/runtime/{fbdev,fbwin,fbinput,fbsound}.c`,
and `sh2perl/src/c_backend.rs:19000` records that an unlowerable `fb_*`
call falls back to a `bash -c` site that "cannot work, since fb_* are
not executables, so the frame came out black".

**This does not contradict the original design — it is a consequence
of how it was realised.** The `fb_*` primitives ARE the `/dev/fb0`
write mechanism: `fb_open` mmaps the framebuffer (`fbdev.c:958`) and
`fb_present` writes the frame into it. The design decision was to put
that device in C and have the transpiler lower the shell's draw calls to
in-process calls, rather than have bash `printf` raw pixels. So
"MIMEcroft renders to /dev/fb0" is true, and "MIMEcroft_fb.sh runs under
plain bash" is false, for the same reason: the device is C.

The remaining obstacle to a pure-shell variant is `fbwin.c`'s
`dlopen("libX11.so.6")`, which bash cannot do at all; the `/dev/fb0`
surface itself needs no such thing, so a bash-only path would have to
target fb0 (or the `$FB_DUMP` PPM) and give up the window. The only
non-rewrite path for the full program is to compile the device once and
drive it from bash via `$FB_DUMP`/`$FB_KEYS` or a FIFO.

**The node half of that mechanism (implemented 2026-10-10).** The last
paragraph's "compile the device once and drive it" leaves one gap: on a
box with no `/dev/fb0` the path does not exist at all, so a shell that
writes pixels — or a program that opens the path before falling back —
finds nothing there. The fb0 "device" in bash-O4 was only a BUILD
artefact (`src/devices.rs` materialises the device's C SOURCES into a
content-addressed cache dir for the linker's `-I`); there was no run-time
node.

`bash-o4/src/fbnode.rs` adds one:
`publish(PATH)` creates a single regular file at the device path, sized
`w*h*4` and holding ARGB pixels in the device mapping's own layout (not
the PPM dump's), so `cat frame.raw > /dev/fb0`, `cat /dev/urandom >
/dev/fb0` and `cat /dev/zero > /dev/fb0` all do what they say.
`to_ppm`/`from_ppm` bridge to the P6 layout `fb_dump_ppm` produces, so a
drawn frame can be written into the node and the two are interchangeable
at the file level. Geometry comes from `$FB0_GEOM` (default 320x240); the
path from `$FB0_NODE` > `$FB0_DEV` (the C device's own override) >
`/dev/fb0`. Driver: `--publish-fb0[=PATH]` and `--dump-fb0[=PATH]`, with
a JIT run publishing best-effort when the path is absent.

**`/dev/fb0` has NO sub-files.** The `/dev/fb0/blocks` and
`/dev/fb0/overlay` lines in `MIMEcroft_fb.sh` are the pre-port SPELLING:
the `fbdev-gpu` transforms (`sh2perl/src/transforms/fbdev_gpu.rs`) lift
those writes into `GpuOp` nodes and rewrite them back to one in-process
`fb_blocks(payload)` call, "the Plan 9 spelling at direct-call speed"
(`MIMEcroft_fb.sh:24`). They are not a filesystem contract, and a node
that served a verb per path segment would be modelling something that
never runs. An earlier attempt in this session did exactly that and was
stopped.

**The boundary, asserted rather than assumed.** A userspace node serves
pixel writers but NOT `fb_try_dev`, which requires
`FBIOGET_FSCREENINFO`/`FBIOGET_VSCREENINFO` and then `mmap`: a regular
file — and even `/dev/null` — answers `ENOTTY`, and the device correctly
falls back to its RAM surface. That rejection is load-bearing, because a
device that mmapped an ordinary file would mis-stride every row that is
not `line_length`-padded. This WSL2 box cannot have a kernel-backed node
(no `/proc/fb`, no framebuffer resource, and only `hyperv_fb`, which
registers but makes no node), so the userspace node is the whole of what
"a device node" can mean here. `node_is_not_a_kernel_framebuffer` is the
tripwire.

**A real bug this surfaced (fixed).** Probing the node end to end showed
`fb_clear 0xFF204060` clearing to black: the `'i'` coercion in
`c_backend.rs`'s `fb_call_opt` routes a string word through `value_num`,
whose fallback is `(int)atoll(...)`, and `atoll` stops at the `x` and
returns 0. All five `fb_clear 0xFF000000` sites in `MIMEcroft_fb.sh` were
affected. It survived because opaque black and black-under-a-blit-that-
ignores-alpha are the same frame; a colour with a nonzero low byte is
visibly wrong. Hex literals now parse as hex
(`sh2perl` dacf1d585), pinned by
`fb_clear_hex_literal_lowers_as_a_number`, which fails without the hunk.

**Offer (2026-10-14, fb0 workstream → §11 marketplace): int-element
array homing in the C backend.** The transpiled-C game ran
462ms/frame against the JS oracle's ~7ms; gprof showed the `rb_tri`
per-pixel loop dominated (`atoll`/`strdup`/`_sh_capture`/`_sh_vgrow`
per pixel). Root cause: `analyze_int_arrays` marks EVERY `arrayIndex`
read as a string read, so polygon/texture buffers stayed `char*` and
every corner/reader var stayed a string. New C-local pass
(`sh2perl` 22e354c33, `SH2_NO_INT_ELEM=1` kills it, C backend only —
other backends keep the shared verdict exactly): arrays with all-int
stores, dense init (literal cover + guarded/bounded keys, or
append-only growth) and no whole-array string reads home as native
`long long[]`; element-readers and pure-arith temps seed `Int`
(`demote_stringy_ints` re-validates every seed). Measured on
`MIMEcroft_fb --demo`: 287ms/frame → **194ms/frame (scene 170ms)**;
frame pixels 99.9987% identical (1 adjacent-texel edge pixel).
Unit tests: zero new failures (11 pre-existing tree-state failures
fail identically with and without; `p1_array_append_capacity_checked`
now passes). The workspace gitlink is deliberately NOT bumped here —
the submodule worktree sits ahead of the pinned `fae7274bb` on other
workstreams' commits; the pin move is the owning session's call.
Still open toward parity (in order): int-param call ABI (per-pixel
argv marshal remains), RBTEX texel-parse modeling + LICM of the
per-triangle slot loads, row-buffer accumulation for the splice.



**Numeric-test lowering (2026-10-19, rust-idiomaticity workstream →
shared shIR transform).** `test-lowering` gains a numeric-compare arm:
a `test` call whose text is `A -op B` (op ∈ `-eq -ne -gt -ge -lt -le`)
with plain-var and/or signed-integer-literal operands lowers to a
typed `BinOp` over **`Arith`-wrapped** operands. The Arith wrap is
load-bearing: a bare `Var`/`Var` BinOp renders LEXICOGRAPHICALLY in
rust (`i < len` compares `"2" < "10"` false → 010_substring_loop
printed `HE`), while `-lt` is arithmetic in bash; `Arith` is the node
every backend already renders numerically. Guards reuse the existing
rules — `is_pure_test_chain` (extended to typed comparison leaves with
Var/Int/Str/pure-Arith operands) and the unobservable-status condition,
since a `test` call records a status write and a bare BinOp leaf does
not; `=`/`!=`, `$((…))`, float/hex literals and multi-operator texts
are refused (refuse > guess). Effect: every plain-operand numeric test
in the corpus leaves the runtime test-string re-parse path — **0
numeric-op test callouts remain across the 560-example corpus**; rust
renders `while !(i >= 3)` where it used to emit a test-string parse
plus a status block; js renders `i >= 3` with zero `sh2.test`
dispatch; C/go/zig/python get the same typed node for free. This is the
generalisation of the C backend's local `test_numeric_cmp` lift (which
never left `src/c_backend.rs`) into the shared pipeline. Verified:
rust equivalence gate **645/645** (rt_gate_verbose, worktree renderer),
`test_lowering` unit tests 8/8 (4 new: lowering, refusals, live-status
refusal), 010/011/051/064* green through the worktree renderer. The
downstream gates are green on the affected set: the perl corpus gate
559/560 (the one miss, parse-double-semicolon, renders rc=0 on 4/4
isolated retries — a load-timeout flake, not a render failure), and
fail-estree run per-prefix over exactly the 16 examples whose shIR the
lowering rewrites — 43/43 green on both the perl and estree sides
(bench-* excluded from the prefix sweep as a family: 13 files each
long-running by design, so the whole family exceeds a single window;
bench-increment and bench-count run green individually, and the rust
gate's 645/645 already covers the rest). Full-corpus fail-estree runs
could not be kept alive to completion — the box's known external
killer reaps them mid-run (the same force repair-workers.sh exists
for), so the per-prefix sweep is the verification of record here.
Main-tree lib suite shows **no new failures** — the 10 c_backend + 1
rust test failures pre-exist at the committed state (measured against
a HEAD worktree: HEAD fails 20; the C worktree `backend/c` tip fails
only 2, so merging backend/c → main clears most of them — C-worker
lane, not done here). Also fixed pre-crash in main's rust renderer:
`[[ ]]` conds never take the arith parse (expr_bool ordering —
`$release=~a|b` used to parse as an assignment), and `${3//\"/\\\"}`
consumes the shell escape exactly once (unescape_operand, mirroring
perl's repl_for_regex). Fleet note: the box crash (19:17 I/O wedge,
emergency-remount-ro on /dev/sdd) killed all six fleet supervisors;
the repair cron revived core/triage/c/perl/go/estree at 21:10 and the
core worker is verified iterating (correctly rolls back a red
transform offer). The 058/064 gate flakes seen during the runs trace
to load-dependent example output (`find .` counts, `who`), not the
renderer: 058 passes 3/3 in prefix mode and under exact gate
replication, and `.cached_test_summary` recorded PASS at 10:49
pre-change. Note for the next session: `LastExitLiveness` /
`LoopStatusDeadness` in shir_passes/analysis.rs are still registered
STUBS — the real liveness machinery is `install_unread_status_writes`
(shir.rs), consumed by the rust renderer (while sites gated, DoWhile
still unconditional) and by C only through its post-hoc `_went` text
pass; wiring the verdict into C's emission sites and rust's DoWhile is
the next shared win.

**Loop-status bookkeeping generalised + verdict race fixed (2026-10-20,
rust-idiomaticity workstream, follow-up).** The status-liveness verdict
now covers the two loop paths that were still unconditional. (1)
`DoWhile` rendering gates its `__sh_dw_last` capture/restore on the
per-statement verdict (`stmt_status_write_is_unread`) exactly like
`While` — no corpus example lowers to DoWhile (it arrives from other
frontends), so the behaviour is pinned by a new unit test
`do_while_status_bookkeeping_follows_liveness` in both trees (dead twin:
bookkeeping gone; live twin: `$?` read immediately after the loop keeps
it — the backward scan is def-use precise, and a trailing loop that
defines the program's exit code is correctly LIVE). (2) The
expression-position `whileLoop` path (no statement pointer to key on)
is gated on a new **source-language verdict accessor**
`source_status_unobservable()` — recorded in `install_unread_status_writes`
(the same `exit_status_is_unobservable` shortcut), conservative-unset;
it only fires for non-shell frontends, which is where the shortcut was
already sound. (3) **Render-verdict race fixed**: the verdict statics
are process-global, so two in-process renders interleaving (concurrent
test threads; any embedder) can overwrite each other's verdicts
mid-render — observed as an order-dependent render-test flake
(`do_while_…` failed2/5 full-suite runs before the fix). A
`render_verdict_lock()` guard is now held across each renderer's
install+render pair (rust `shir_to_rust` entry before `rc_disabled`,
estree `shir_to_estree` entry before the clone); leaf-order safe, never
nested. (4) The crashed rust-worker WIP's `repl_for_regex` rework in
the worktree was half-landed (its own pinned test red): completed to
the test's MEASURED table — `\$`/`` \` ``/`\@`/`\/` unchanged, `\"` →
`\\"`, `\\` → `\\\\`, other `\X` → `X`, trailing lone `\` → `\\`. After:
worktree lib suite **1238/1238 green twice** (was1237+1 flake), main
lib suite stable at **1360 pass / the same10 pre-existing C-backend
reds** (unchanged; still the backend/c-merge lane), worktree rust
equivalence gate **645/645** before and after the loop-gating, and the
main renderer re-verified on the whileLoop corpus cases (088/091
PASS). Perl/estree gates unchanged by this increment (no emit-path or
perl-renderer change since their last green).

**Native file-args pipeline + capture composition (2026-10-20,
corpus-gate lowering → shared shIR).** The perl corpus gate's remaining
outer shell-outs were dominated by file-argument commands (`grep PAT
FILE`, `ls`, `sed -e`, `head/tail -n`, `wc`, `rm`…) reaching the runtime
as generic shell-outs. The statement channel in `ir.rs`
(`render_call_stmt`) now routes a whole `x=$(…)` / bare statement
pipeline through `pipeline_native::native_dispatch` — capability leaf or
uu-ffi seam — refusing shell-state builtins and outer shell-outs, and
`pipeline_native/capabilities/` gained the matching leaves (ls literal
args + non-literal `echo` fallback, grep's condition/chain/here-string
forms, etc.). Two cross-cutting bugs were found by the gate and fixed:
(1) **gate on the COMMAND NAME, not `func`**: the CLI purity pass labels
emulable whitelist commands (`ls`, `grep`, …) `func:"builtin"`, so a
`func == "exec" | "builtin"` gate written against the library's own
lowering (which emits `exec`) silently refused every CLI-produced site —
the unit tests parsed them as `exec` and hid it (name-based
`is_shell_builtin` is the correct key); (2) **command-substitution
captures compose NESTED, and neither stock capture idiom is sound in a
nested position**. A scalar-backed `local *STDOUT; open(STDOUT,'>',\$cap)`
only catches prints routed to the STDOUT glob and has no real fd 1 for a
forked `__sh_uu_run` child to inherit (measured: 017_grep_context's
`$(grep -l … | sort)` section gained a stray blank line from an
empty-content consumer), and under an outer `select($__fh)` scalar
capture — the wrapper every `x=$(…)` renders under — a bare `print`
defaults to the OUTER handle, so the fd-file variant alone is wrong too
(measured: parse-complex-pipeline-quotes captured `data` instead of
awk's empty field; 018_grep_params got grep's lines instead of `wc -l`'s
count). New `capture_do_nested` (ir.rs) does both channels at once:
fd 1 dup/close/reopen onto a `sh2_cap_<site>_<pid>` scratch file (a
spawning body's children inherit fd 1) **and** `select(STDOUT)` (bare
prints), with the previous default handle and the STDOUT glob both saved
and restored so captures nest in either order; the plain
`capture_do_perl` keeps its proven behaviour at its existing sites.
Effect (final binary, fresh corpus generation): outer shell-out sites
(`system(` in generated perl) **274 → 265**, native uu seams **+7
(43 → 50)**, 0 generation failures across 560 examples; 14 generated
files changed vs the pre-capture-fix build (wrapper text only).
Verification of record: full `./fail` chunked gate **560/560 green on
the final binary** with fresh (no stale-seed) results — the box's
external killer reaped both background drivers mid-run, so c0–c4 landed
under the on-disk supervisor (`/tmp/fail_supervise.sh`) and c5–c13 as
foreground `FAIL_CORPUS` batches; lib suite **1369 pass / 10 failed** =
the pre-existing 9 c_backend reds + 1 rust_backend test belonging to
another workstream's in-flight `rust_backend.rs` (passes in isolation;
not touched here); targeted byte-exact checks: 017 (20=20 lines), 018
(25=25), 062_10, typeset-cmdsub (76=76), parse-complex-pipeline-quotes,
and an ad-hoc 3-stage battery (pure-perl mid, spawning producer,
spawning mid, echo|tr — 11=11). Caveat for the next session: the
tests/pipeline-native t5/t8 scratch tests used mid-session no longer
exist anywhere on disk (swept) — their coverage lives in the corpus
cases above, not in files. Gitlink deliberately not bumped here: the
worktree carries other workstreams' uncommitted edits; the commit/bump
is the owning session's call.

**test-lowering braced-operand update (2026-10-20, perl-idiomaticity
workstream).** `./fail` was green at session start (the prior session's
final chunked gate: 14/14 chunks rc=0, 0 FAIL/TIMEOUT), so the work went
to the metric. The shared `operand()` reader in
transforms/test_lowering.rs refused `${name}` (braced) reads while the
numeric arm (`numeric_operand`) has always accepted both spellings — so
the corpus's `[ -n "${VAR}" ]` family stayed on the runtime `sh2.test`
string path (re-tokenized per evaluation) where its unbraced twin
lifted. Braces are now stripped before the same plain-identifier gate,
so `${v:0:1}` / `${#v}` / `${v:-x}` / positional `$3` still refuse
(pinned by the existing refusal test plus two new ones); the string-eq
arm's own `{`/`}` glob-metachar guard still refuses braced operands in
`==`/`=`/`!=` shapes (the guard runs before `operand()` — pinned by a
new test), and the status-liveness guard is untouched, so
`[ -n "${VAR}" ] || VAR=x` keeps its test call (the `||` chain reads the
exit status — refuse > guess; measured: 2 of the 10 candidate corpus
sites correctly stay). Effect: metric TOTAL **2302 → 2294** (test 166 →
158), and the lifted sites render the directly-lowered leaf in perl
(`if ($so ne "")` where the test-string path emitted
`if (length($so) ne 0)`). Corpus-wide shIR byte-diff vs the pre-update
binary: **exactly 5 of 560 examples changed** (dqs-nested-awk-sed,
heredoc-binary-data, id-cmdsub, readonly-cmdsub, tty-cmdsub); the other
555 are byte-identical. Verification of record: lib suite 1391 pass /
10 fail — the 10 are the pre-existing c_backend baseline (failure set
diffed IDENTICAL with and without the change — stash-and-rerun);
test_lowering module 14/14 (13 existing + 1 new
`braced_var_operands_lower_like_plain_ones`); check_qx green on all 7
touched/refused renders; `./fail` + `./fail-estree` prefix runs 7/7
green over exactly the 5 changed + 2 refused files (both verdicts);
full `./fail` chunked corpus gate **14/14 chunks rc=0, CHUNKED-DONE,
zero FAIL/TIMEOUT** on the post-update binary (fresh grind under
/tmp/fail_supervise2.sh — progress file cleared before launch, 560
seeded examples, 687 recorded runs, all green; the supervisor
self-exited on the terminal state). Offered per §11 at
core-requests/transforms/offered/test-lowering.rs/ (manifest +
transform.rs + register note — the transforms.rs registration is
unchanged; this is an update to the accepted canonical set). Gitlink
deliberately not bumped: the worktree carries other workstreams'
uncommitted edits (rust_backend.rs, c_backend.rs, shir.rs, the
pipeline_native capability leaves); the commit/bump is the owning
session's call.

Redundancy pass on the shared lowering: constant `printf`, typed-attribute
const-folds, and `int`/`lc`/`uc` rendering (2026-10-21). Three
redundancy clusters the emit census identified, all fixed core-side:
(1) **constant printf** — EchoFold (shir_passes/echo_fold.rs) gained a
`constant_printf` fold next to the echo one: a single-word, zero-spec,
glob-sentinel-free, non-`-v` `printf "…"` becomes `IrStmt::Output`
(`newline:false`) using the SAME `echo_esc` state machine the runtime
`__sh_printf` body carries line-for-line (lockstep, not a second
implementation); refusals keep every other printf on the helper path
(`%` conversions, multi-word format-reuse rounds, `-v var fmt`). Effect:
the 70 measured zero-arg sites fold, and the `__sh_printf`/`__sh_q_printf`/
`__sh_atoi` polyfill cluster now appears in only 76 of 560 emitted files
(only genuinely dynamic printfs) instead of every printf user.
(2) **typeset-attrs const-fold** (transforms/typeset_attrs.rs) —
`int(arith(T))` with T a canonical signed decimal folds to `IrExpr::Int`
(strict_int refuses `042` — octal 34 in bash arithmetic vs Rust 42 —
plus hex/underscore/overflow forms; REFUSE > GUESS), and `lc`/`uc` over
constant ASCII text folds to the lowered literal at transform time
(non-ASCII keeps the Call: a Unicode fold is locale/backend-dependent).
(3) **rust_backend renders `int`/`lc`/`uc`** — `int(arith(…))` passes
through to the already-i64 operand (truncation is identity; kills the
`(x + 1).to_string().trim().parse::<i64>().unwrap_or(0)` string
roundtrip on every `typeset -i` assignment), `lc`/`uc` stacked over the
int coercion is identity in num context (the guard only accepts the
integer-typed shapes — a string fold must run BEFORE its parse), and
plain `lc`/`uc` render `to_lowercase`/`to_uppercase` in str context.
Together these clear the last rust STUB: **typeset-cmdsub.sh goes
10 `TODO(unsupported)` callouts → 0, STUB → runs → full EQUIV PASS vs
bash**, and the corpus is at 0 STUBs / 0 TODO(unsupported) overall.
typeset_attrs tests 15/15 (two pins moved to the stronger folded-literal
shape; four added: decimal fold, octal refusal, non-ASCII refusal,
estored coercion shape). Verification of record: lib suite 1398 pass /
9 fail — the 9 are the pre-existing c_backend set, diffed IDENTICAL in a
detached HEAD worktree (baseline actually fails 10, so the tree state
fixes one); full `./fail` **560/560**; full rust equivalence sweep
**551 PASS / 0 STUB / 2 MISMATCH** — the two are test-glob-rhs-fallback
and utf8-non-utf8-content, present as MISMATCH in
backends/rust/.gate/corpus-fail.latest.txt since 2026-09-29 (pre-existing
rust-gate gaps, not regressions) — / 7 `bash -n` parse-error skips.
`harness/check_ast.pl` could not run: it still builds the `dump_ast`
bin that commit 4d5d2d2c6 deleted (pre-existing harness gap — the CLI
has no raw-AST dump target yet). Both transforms are core-owned updates
to the canonical set, so no §11 offer is needed. Gitlink deliberately
not bumped, for the same reason as above: the worktree carries other
workstreams' uncommitted edits.

**Statement-position test-chain lowering + perl render widening (2026-10-21,
perl-idiomaticity workstream; completes the same-day typed-compare
series).** The cond-position lowering never sees a STATEMENT chain:
`[[ … ]] && cmd` / `[[ … ]] || cmd` desugar to `Expr(And/Or(test, cmd))`
and `stmt_pass` had no `IrStmt::Expr` arm, so all 21 corpus chain sites
kept their `test` callout. The arm now runs `rewrite_stmt_chain`: it
walks only And/Or/Not combinators and lowers every reachable `test` leaf
through the SAME `lower_test_leaf` the cond path uses (glob affix →
`strHasPrefix`/`strHasSuffix`/`contains`, numeric/string eq → typed
`BinOp`, compound `-a`/`-o` → nested And/Or), guarded by the cond path's
liveness contract (`self_live` — the statement's own status must be
dead — plus the inline `ir_expr_reads_status` refusal, so
`[[ t ]] && echo "$?"` keeps its call).

The lowering is shared IR, so the perl renderer's four `test`-gated
gates were widened on a new shared predicate `shir::is_pure_bool`
(`is_pure_test_chain` ∪ the value primitives, with pure operands and
And/Or/Not recursion): `native_if_test_cond`'s chain arm,
`test_and_to_if`/`test_chain_to_if`, `control_chain_to_perl`'s lead
gate, `chain_operand_body`, and two new bare-value statement arms in
`emit_stmt` (a statement-position primitive/comparison writes 0/1 status
exactly like the old `test` arm). The load-bearing one is
**`native_if_test_cond`**: it emits the chain as RawText with the
explicit `$CHILD_ERROR = (cond) ? 0 : 1` BEFORE the `if`, and its
test-word extraction no longer matches a lowered leaf — without the
widening, `eq-string-num-var` fell into `test_and_to_if`'s form-1 If
(no false-path write: the loop's failed `[ … ] && echo` left `$?` = 0
and the post-loop `[ "$?" = 0 ]` printed a `status-zero` bash does not
print — measured, then fixed by routing pure-bool conds through the same
RawText arm).

Also in this step, the estree renderer had TWO `IrStmt::Ext` arms in
`stmt_to_estree`: the newer fbdev-gpu GpuOp arm matched every Ext node
first and `unreachable!()`ed the rest — hidden from rustc by
`#![allow(unreachable_patterns)]` — so `cat <<EOF`'s ForEachLine
(cat_read) panicked, poisoned a shared mutex, and cascaded **207
PoisonError collateral failures** across the suite. The GpuOp arm is now
tag-guarded (`IrStmt::Ext(n) if n.tag() == "GpuOp"`) so the committed
ForEachLine/WalkDir renderings and the loud unknown-tag refusal stay
reachable; the `cat <<EOF` estree runner probe is green again.

Verification of record: full `./fail` **560/560** (14/14 chunks rc=0;
the driver was externally SIGKILLed twice mid-chunk and the on-disk
supervisor's append-only resume completed the run — the design case
fired); lib suite **1420 pass / 9 fail / 0 poison** — the 9 are the
pre-existing c_backend set, present identically in a detached HEAD
worktree, and `estree::tests::json_writer_matches_serde` (the poison
source) now passes; metric (plmetric A/B over the 560-example corpus,
statement arm disabled vs enabled): **TOTAL 2290 → 2283, `test` 154 →
147** — the other callout lines are byte-identical, so the delta is
exactly the lowered chain leaves; a `chain.sh` probe diff-clean vs bash
on perl (`if (strHasSuffix($s, ".txt"))` + guarded `do { … }` chains),
estree (sequence + `lastExit` write, through `estree-runner.mjs`) and C
(`strlen`/`fnmatch`), plus `cat <<EOF` on estree post-GpuOp-fix.
Cross-backend note: the transform is shared, every backend's unit
fixtures pass at 1420, and the other lanes' full corpus gates are theirs
to run from their worktrees. Core-owned update to the canonical
`test_lowering` set — no §11 offer needed (same call as the
braced-operand update). Gitlink deliberately not bumped: the worktree
carries other workstreams' uncommitted edits.

**Case lowering: shared `sh2.globMatch` primitive + rust cond truthiness
fix (2026-10-21, rust-idiomity).** The case-lowering transform now
groups char-class / `?` / mid-star clauses behind ONE shared shIR
primitive, `globMatch(value, pattern)`, rendered per backend (rust
`__sh_fnmatch`, estree `sh2.globMatch` — registered in the
`estree_gate.pl` whitelist and both runtime namespaces, java
`shFnmatch`); affix shapes keep the string-op specials. This removed
the per-backend case dispatch duplication and turned the mid-star
condition into one renderer-visible op every backend can specialise.

Two follow-on defects surfaced and were fixed. (1) The estree runtime
method was stashed-as-worker-WIP five times before it stuck: the loop's
operator-edit guard `snapshot_fix_surface` used `git diff --name-only`
(unstaged only), so a `git checkout <stash> -- <file>` restore (staged)
was invisible to it; it now diffs HEAD, and `harness/.operator-fix-surface`
lists operator-owned paths re-read on every call. (2) rust
`expr_bool` had no `strHasSuffix`/`strHasPrefix` arms, so the affix
case conds fell to the string-truthiness default — the value form is
the "1"/"0" status string and `"0"` is never empty, i.e. the false
arm could not fire (`bench-case` matched `*llo` against `abc`). Both
now render as native `.ends_with`/`.starts_with` conditions, which
also deleted the `if/else {"1"}/{"0"} + .to_string() + .is_empty()`
boilerplate from every such cond.

Verification of record: `case_lowering` tests 15/15; full `./fail`
**560/560**; full `./fail-estree` **rc=0, zero failures**; `case`
prefix 32/32 estree + 32/32 perl; fail-rs **547→549 pass, 6→4 fail**
(bench-case and 064_19_complex_pattern_matching_extended_globs fixed;
the 4 remaining reds are emit-proven pre-existing, list updated in
`harness/fail-rs`). Core worker healthy — 10 consecutive GREEN gates
(anchors advancing; the two 10:17/11:20 REDs rolled back correctly).
Gitlink deliberately not bumped (worktree carries other workstreams'
uncommitted edits — same call as the test-lowering entry above).

**Statement-chain status + test-`=` quoting gate (2026-10-21, round 2,
rust-idiomity):** two more fail-rs reds fixed at the RENDER layer. (1)
`eq-string-num-var`: a statement-position `A && B` renders `if A { B }`with no status record anywhere — bash's list `$?` after a failed `[ … ]`
is 1, but the rhs body's success write (0) plus the dropped wrapper lostit. The And/Or statement arms now carry exactly one `__SH_RC.store` forthe lhs (via `unwrap_cond` folding any per-operand wrappers), gated onthe shared liveness (`stmt_status_write_is_unread`) and `rc_disabled` —the same shape the estree renderer already produced as a sequencerespression. (2) `test-glob-rhs-fallback` + 070_gnuisms: rust's test`=` arm globbed a QUOTED rhs (runtime `__sh_glob_like` probe /unconditional `[[ ]]` fnmatch), diverging from the runtime reader's`rQuoted` rule; the arm now takes `rhs_quoted` from the test text (thequoting survives tokenization), a quoted rhs compares literally (with`nocasematch` folding both sides, style-independently as the runtimedoes), an unquoted rhs keeps the go-sh glob probe, and the const-literalshortcuts yield to the case-folding path when nocasematch is on. Thepinned unit test was renamed `glob_rhs_probe_is_quoting_gated` to makethe contract explicit.

Verification of record: fail-rs **541→551 pass, 12→2 fail**(064_hard_to_generate, utf8-non-utf8-content remain — both pre-existing,emit-proven untouched); rust_backend 113 / test_lowering 17 /case_lowering 15 unit tests green; full lib 1429 pass / 9 fail (thepre-existing c_backend set); `case` prefix 32/32 + 32/32; estree loop555/555 on the shared tree; core worker GREEN. Known non-red issue:harness/py-idiom-gate.sh t37/t69 fail against uncommitted `println!`-collapse WIP inherited in rust_backend.rs (outside this work's edits;
the gate's expectations predate that WIP).

- **2026-10-21 — capture-node-fold (shIR→shIR): `Call { "capture",
  [Arrow] }` → the first-class `IrExpr::Capture` node.** The A1 emits
  the node for a scalar `$(…)`, but transform authors (process_subst's
  mktemp helper, grep-o, grep-to-case's lowercase lift) spelled the same
  thing as the contract call — and the two spellings render through
  different arms. The NODE arm is the strong one everywhere: Perl's
  `ir_expr_to_perl` carries the native pipeline capability, the UU-FFI
  in-process capture, the `echo | tr` fold and the fd-1 buffer there
  (the call arm falls straight to the `bash -c` rebuild); sh's node arm
  is documented "same `"$(…)"` rendering as the capture call arm" plus
  a POSIX idiom lift; est (`expr_to_estree`) and c (its in-process
  lowering) convert the node BACK to the call form, so their output is
  byte-identical either way. Registered on the shared `ast_to_ir`
  channel (codegen targets only — unset/`shir` is the byte-pinned
  A1-export path, case-lowering precedent) AND called at the end of
  otranspilerl's `ingest` (else-if-flatten precedent): `process_subst`
  builds the call spelling INSIDE ingest, after the registry ran.
  Refusals: `captureWords` (the word-split spelling — `basename $(pwd)`
  needs its IFS split), a non-Arrow payload, and any body that reads
  `$?`. Verification of record: plmetric `capture` **45 → 0**, TOTAL
  **2283 → 2238**, no other callee moved; full `./fail` **560/560
  rc=0**; full `./fail-estree` **PERL+ESTREE 560/560 rc=0**; `fail-go`
  **124/124 rc=0**; `fail-shir` exit 0 (547/560 bash-free; its tracked
  baseline is a 6-week-old snapshot, so no delta is claimed from it);
  mini core-path rust gate over the 14 emission-changed files **13
  pass / 1 fail**, the failure (064_hard_to_generate, extra
  `Text file: out.txt` line) byte-identical to its pre-change record on
  the fail-rs known-reds list; new transform tests 6/6; full sh2perl
  `--lib` 1429 pass / 9 fail — all 9 in `c_backend::tests`, unreachable
  from this change (hand-built IR → `shir_to_c`, no apply/ingest on the
  path, target unset) and attributable to the concurrent C worker's
  uncommitted 1072-line `c_backend.rs` edit. Perl emission delta: 39
  lines across 14 files, all the double-wrapped `$(mktemp)` capture
  collapsing to the single native `File::Temp` form. fail-coreutils not
  run: its required binary `sh2perl/target/debug/debashc` does not exist
  in this checkout (built from a backend worktree) and its documented
  reds are the unrelated `source`-inlining gap. Gitlink deliberately not
  bumped (worktree carries other workstreams' uncommitted edits).

- **2026-10-21 — pipeline_native: N-stage chains + `cut`/`awk` leaves.**
  The capability tree's parent lowered 2- and 3-stage pipelines only, so
  every 4–5-stage corpus pipeline (`grep | tail | grep -Eo | sed`, `dpkg |
  tail | awk | cut`) bailed to the `bash -c` rebuild even though each
  stage already had a leaf. The 3-stage special case generalized to
  `stages.len() >= 3`: stage 1 is the producer, each mid (2..N-1)
  dispatches natively with its stdout captured into a distinct chaining
  scalar (`__sh_pv`, `__sh_pv2`, …) via the same `capture_do_nested`
  idiom the 3-stage arm used, and the final stage reads the last scalar.
  One refusing stage still bails the whole chain (all-or-nothing — no
  half-native emission). Two new leaves: **`cut`** (`-d D -f N` only —
  single char, single 1-based field; ranges/lists, `-s`/`-o`, FILE args
  and unknowns refuse; cut(1) semantics: no-delimiter line unchanged,
  missing field empty) and **`awk`** (`{print $N}` only — whitespace-
  tolerant program parse; `split(' ', …)` IS awk's default-FS split;
  flags/FILE args refuse). Both emit the sed capability's exact per-line
  loop shape so leaves compose in a chain. The
  `unsupported_consumer_still_refuses` fixture moved from `cut` (now a
  leaf) to `od`, keeping the refusal test honest. Output effect: bash -c
  pipe-helper call sites in program bodies **116 → 111**, native
  per-line capability loops 17 → 23, 8 files' bodies changed; the
  sh2.* IR Metric is unchanged (2238) — this is render-side
  idiomaticity, the bash -c rebuild the metric cannot see. Verification
  of record: `./fail` **560/560 rc=0** (byte stdout + exit codes vs
  bash, covering the new chains: grep_p, 018_grep_params,
  multiple-awk-in-dqs, parse-complex-pipeline-quotes …); full
  `./fail-estree` **PERL+ESTREE 560/560 rc=0**; `fail-shir` rc=0
  (547/560 bash-free, its 13 remaining sites are the unrelated
  echo/paste/ps family); `fail-go` **124/124 rc=0**; `pipeline_native`
  tests **26/26** (4 new leaf parse tests + the moved refusal fixture).
  Full sh2perl `--lib`: 1433 pass / 9 fail — the same 9
  `c_backend::tests` as before this change (concurrent uncommitted
  `c_backend.rs` edit; c has its own `native_pipeline` and its tests
  hand-build IR → `shir_to_c`, unreachable here). Deliberately not
  covered: redirect-tailed consumers (`| sort > tmp`, the 53
  `__sh_pipe_run` sites) need fd threading through the parent — a
  follow-up, refused today by `pipe_consumer`'s single-Expr shape.
  Gitlink not bumped (worktree carries other workstreams' edits).

### 2026-10-21 — zig backend: equivalence failures driven to zero

The zig backend gate (`setup_backends.sh --backend-gate zig`) started this
session at **353/652 render OK, 232 stubs, 60 equiv** and now reads
**409/652 render OK, 234 stubs, 2 equiv**, where both remaining "equiv"
entries pass when re-run against the gate's own conventions
(`SH2_ARGV0` set to the source path; 048 is a background-output race in
the ad-hoc probe, 6/6 clean on re-run). Every remaining failure is an
unimplemented lowering (a `sh2.*` stub), not a wrong answer — the stub
workstream is separate.

Classes fixed (each was a real wrong-answer, not a cosmetic diff):

- **FFI capture.** `shUuRun` (in-process `uu_run`) returns a STATUS and
  writes fd 1, so `x=$(uname -s)` lowered through it evaluated to `""`.
  Capture position now always uses the fork/exec `shRun`. `grep` left the
  FFI whitelist: the pinned `libcoreutils_ffi.so` rejects `-q`/`-w`
  ("grep: unsupported flag"), turning `grep -q` into rc 2.
- **printf.** One part per literal CHARACTER made a 39-arg print, past
  zig's 32-argument cap → literal runs coalesce and wide arg lists chunk
  (24 per call). Format-text escapes (`\n`, `\t`, …) decode at render
  time; `%b` expands the ARGUMENT (`shBEscape`); `%d` over a string-model
  value prints as text; `-v NAME` assigns instead of printing; field
  width (`%-10s`) pads (`shPadW`); a FIELD-SPLIT operand repeats the
  format once per word.
- **Arithmetic.** The hand-rolled `mf_*` chain read `i++` as `i`, so
  `(( j = i++ + ++i ))` lost a side effect — `parse_arith` (the core
  parser) now runs FIRST. Added `shShl`/`shShr` (u6 shift amount),
  `shPow` (error-union-free), `shDiv`/`shRem` (a zero divisor sets
  `sh_arith_err` instead of PANICKING; the enclosing assignment is
  abandoned, bash's behaviour), and inc/dec in expression position
  (string homes round-trip through `shToInt`/`shIntStr`). The statement
  form sets `$?` from the expression VALUE (old for postfix).
- **Specials.** `$-` (`hB`), `$#` (arg count, 0 at top level), `$0`
  (`shArgv0` ← `SH2_ARGV0`), `$@`/`$*` inside functions
  (`shJoinSp(__args)`, and `for a in "$@"` iterates `__args`
  individually), top-level `for a in "$@"` = zero iterations.
- **Pattern matching.** `[[ $x == PAT ]]` matches with `* ? [set]` and
  the extglob groups (incl. negated `!(…)`); a PATTERN only in `[[ ]]`
  with an UNQUOTED RHS — `[ ]` and quoted RHS stay literal compares.
  `shopt -s nocasematch` folds both sides (`shGlobPatI`/`shEqI`).
- **Globs.** `\x01SH2GLOB\x01`-marked words expand against the
  filesystem (`shGlobExpand`, directory + basename); an argv word that
  must glob runs the command through `sh -c` (the word count is only
  known at run time), and a for-list expands then re-splits on 0x1f.
  Brace expansion of 54 words works via the printf chunking above.
- **Arrays.** `arr[i]=X` (including the core's literal-name form
  `var: "arr[1]"`), `unset`, `arr=($x)` field-splits, `+=` appends, and
  a SCALAR read of an array is element 0 (`${LIST:-}`), not a
  `[1024][]const u8` that fails to typecheck.
- **Scoping.** A fn-local name leaked into the module `written` set
  through `var_types`/`prog.var_types`, so a top-level read of a never-
  called fn's local emitted a BARE undeclared identifier. Capture
  promotion now covers only top-level vars a function reads (it used to
  promote every name read anywhere, turning `$HOME` into an
  uninitialised declaration).
- **Flow.** `eval "NAME=payload"` binds in-process (a `sh -c` child lost
  the assignment); `.`/`source` splices at render time when the file
  exists, else `shSource` dispatches the file's `NAME=value` lines onto
  the declared homes; `cd … || echo` leaves `$?` at the RHS side's
  status; `&` jobs really FORK (concurrency + copy semantics), `wait`
  reaps natively (there is no `wait` binary), and the script-end reaps
  outstanding jobs before exiting.
- **Bytes.** Non-UTF-8 source bytes arrive as U+F800+byte markers; the
  renderer maps them back to raw bytes in string literals (it was
  re-encoding them as UTF-8).
