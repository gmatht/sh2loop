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
> - v155: **Section A of the improvement list, landed.** Seven items, each with a measurement.
>   (1) **Positional BigInt taint is exact.** `walk_bigint_expr`'s `IrExpr::Arith` arm marked
>   `$1..$9` for any huge constant anywhere; a huge argument now taints only the index it lands in
>   (`fnValue`/`fnCall` args `[1][i]` -> `$i+1`). Pinned by
>   `bigint_digit_taint_is_positional_only` (bare huge arith taints nothing; `f $((2**64)) 1` taints
>   `$1` only). The corpus still renders 0 `num_bigint` (bash wraps), so the shell gate cannot see
>   this class at all.
>   (2) **Emitted-surface coverage is now measured.** `harness/ir-surface.py` censuses every IR `type`
>   tag and `Call.func` op the corpus reaches (baseline 41 types / 32 ops; a disappearance fails), and
>   `--fixtures` renders + compiles `harness/ir-fixtures/*.shir` through all four backends. Two
>   fixtures cover what the corpus cannot: `bigint-arith` (huge value through a variable) and
>   `positional-bigint` (huge call argument -> `$1`), the latter the only one that needs the Cargo
>   project for `num_bigint`.
>   (3) **Declaration-site ownership fixed** — the prerequisite the reverted precise-mut work named.
>   `use_scopes` skipped `IrStmt::Declare` targets entirely ("bindings, not mentions"), so a
>   declaration could never own its own `let`; the case lowerer's `__sh2_casesubj_N` was emitted from
>   outside the declaration path. A declaration WITH an init is now a `decl` write, and
>   `compute_local_vars` treats a first-mention declaration as its own `let` site instead of falling
>   back to the entry path (`let mut x = String::new();` + assignment = needless mut + dead init).
>   A BARE `local x` stays unrecorded: it emits no binding, and recording it regressed
>   `092_for_arith_func` to E0425 on its for-init (caught by the census, fixed, re-verified).
>   Measured: warned programs 29 -> 23, warnings 77 -> 59, `needless_mut` unchanged at 19, gate
>   unchanged at 555/1/7.
>   (4) **The unreachable class is fixed where the renderer invented the code.** `unreachable
>   expression` 4 -> 0 and `unreachable statement` 3 -> 2. Causes: a loop-body rc save emitted after a
>   body whose tail diverges (`break`, `return`); the synthesized function value tail after an
>   if/else-if/else chain where every branch returns; the `false` tail after `break;` in a bool
>   position (a block ending in `break;` has type `!` and coerces); and the status wrapper after a
>   diverging `||` lhs (`break || exit 1`). New helper `stmt_diverges` decides the first two,
>   `core_diverges` the last two. `parse-exit-brace-question` keeps its warning on purpose: bash never
>   runs its trailing `printf` either, so the Rust is faithful to the source.
>   (5) **Backend parity is a table, not folklore.** `harness/unsupported-census.sh` counts emitted
>   TODO markers per backend/program/shape (baseline 34 shapes: c 3 programs/12 markers, py 81/182,
>   rust and js 0) and `--check` fails when a NEW shape appears.
>   (6) **The gate counts its own unsupported surface.** `fail-rs` now prints
>   `emitted TODO(unsupported): N markers in M programs` (0/0 today), so a new unsupported class shows
>   up in the gate's summary instead of being found by hand.
>   (7) **The rust-frontend hang is a flake, and the scoreboard says so.** `handlers/mod.rs` (a 15-line
>   generated file of `mod` declarations) timed out twice on 2026-11-11 — 63 s under a 60 s timeout —
>   then ran in <1 s on twenty consecutive in-place attempts; every sibling module and `mod.rs` on its
>   own finished normally, and prefixes copied out of the tree finish too. Root cause unknown (the
>   frontend's mtime-keyed clean-lowering cache is shared between runs); `rust-dogfood.sh` now reruns a
>   timeout (`TMO_RERUN`, default 2) and reports `TIMEOUT (did not reproduce)` when it passes, while
>   still counting it as a crash. Not fixed — made visible.
>   NOTE: a fleet worker committed the new harness files mid-session (`675adb6c`, `e7c8cef4`,
>   "backend perl: gate pass"), which is why they are already in the tree.
> - v154: **D4 done: BigInt scope is data flow, not the program.** Two over-approximations are gone
>   from the rust renderer. (i) At the taint call site, `if stmts_have_huge(…) {
>   collect_all_assign_targets(…) }` marked EVERY assignment target in main BigInt as soon as one
>   huge literal existed anywhere — `x = 1` became BigInt because `n = 2**64+1` appeared elsewhere.
>   (ii) Inside `collect_bigint_vars`, `has_huge_call → collect_targets(main ∪ every sub)` did the same
>   for a single huge call argument, which is exactly the "needs param-position tracking" TODO: a huge
>   argument taints only the positional slot it lands in (`$N`), and `walk_bigint_expr` already records
>   those digits. Both helpers (`stmts_have_huge`, `collect_all_assign_targets`) are deleted; the rule
>   is now the existing fixpoint (`collect_bigint_vars` + `collect_huge_literal_assigns` +
>   `walk_bigint_stmts`), which marks a var only when a huge value can REACH it.
>   Measured: the shell corpus never renders `num_bigint` at all — 0 programs / 0 sites before AND
>   after (bash wraps past i64, so shell-derived IR never carries a huge value), and the gate is
>   unchanged at FAIL-RS pass=555 fail=1 skip=7. Those over-approximations therefore only ever
>   affected IR from other frontends (python/rust→IR), which neither `fail-rs` nor the warning
>   census can see; that invariant is pinned at the IR level by
>   `bigint_scope_follows_data_flow_not_the_program`: one program with a huge `n` and an ordinary `x`
>   — `n` is tainted and `x` is not, and arithmetic on `n` still renders through `num_bigint`.
> - v153: **Investigated and reverted: precise `mut` for read-only locals.** The corpus's largest
>   warning class (19 × `variable does not need to be mutable`) is entirely top-of-function
>   `let mut <v> = String::new();` for locals that are only ever READ (`$var` in `test-expr-true.sh`,
>   `$VAR1`/`$VAR2` in `parse-bracket-chain.sh`), where bash keeps the ""/0 default forever. THREE
>   independent causes had to change together, and each alone measured as a no-op: (a)
>   `compute_local_vars` inserted every entry-declared local into `need_mut`; (b) the entry-declaration
>   emitter was the one of five sites that hardcoded `let mut` instead of consulting the verdict; (c)
>   the shared walker records a builtin's write target (`printf -v x`, `read x`, `typeset x`) as a
>   plain READ because there is no assignment node for it. Measured progression on the corpus:
>   (a)+(b) → needless-mut 19 → 4, but three programs stopped compiling
>   (`parse-case-dollarparen-pattern`, `printf-format-and-v`, `typeset-cmdsub`); adding `Use::namearg`
>   (the command-word rule: a position where a builtin can write) → 2 compile failures, warnings
>   77 → 54; inverting to a positive `local_immutable` whitelist → needless-mut 4, but the lib suite
>   went RED. The blocker is `__sh2_casesubj_0_`: the case lowering's synthetic subject temp is
>   declared through a path outside the declaration block and never reaches `use_scopes`, so no
>   decl-site verdict can classify it — a negative rule is unsound for it, and a positive whitelist
>   does not reach the emitting path at all. Everything was reverted; the tree is back to its green
>   state and the experiment is parked at `/tmp/exp_rust_backend.rs` and `/tmp/exp_scopes.rs`. The
>   prerequisite for retrying is a verdict for synthetic temps (declare the temp at its write, or mark
>   generated names), not a broader read analysis.
> - v152: **The helper registry has declared variant pairs, not unique names.** The v151 test's
>   count/injectivity assertion went red with `75 != 77`: two pairs of registry entries render the
>   SAME `fn` name on purpose — `regex`/`regex_posix` (same `fn __sh_regex`, different engine crate,
>   exactly one emitted per program) and `print_words`/`print_words_noesc` (same
>   `fn __sh_print_words`, the unescape arm compiled out when no `echo -e` exists, again one per
>   program). Uniqueness was the wrong invariant, and "just drop the assert" would have hidden the
>   risk it guards: two UNRELATED helpers sharing a name could be emitted together as a duplicate
>   definition. `helper_rendered_pairs()` now exposes key -> rendered name, and the test requires
>   every collision to be a declared pair in a `VARIANTS` table, so a new collision fails until a
>   human states why it is safe. Registry totals: 77 entries, 77 rendered bodies, 75 distinct names.
>   This test earned its keep by going red three times before green (key == rendered name assumed
>   false: `outbytes` -> `__sh_out_bytes`; doc prose read as a call site: `add_helper("…")`; then
>   the variant pairs) — each red was a wrong assumption in the TEST, not in the emitter, which is
>   exactly what a test over a registry should surface.
> - v151: **D measured, and two false assumptions removed.** The `fail-rs` gate after v150's prune
>   refactor: **555 pass / 1 fail / 7 skip** — unchanged from baseline, the fail still being the
>   pre-existing `parse-brace-in-heredoc FAIL-rustc`. The warning census (`563 programs, 29 warned,
>   77 warnings, 1 not compiled, 19 skipped for the cargo `regex` dep`) now also answers *which*
>   program carries *which* kind (`--kinds=<substring>`); `variable does not need to be mutable` is
>   spread over 063_02, 063_09, parse-arithmetic-extra-paren, parse-bracket-chain,
>   parse-double-bracket-newline, test-expr-true, arithmetic-var-ref, double-equals-in-test,
>   unset-var-empty-string-test. Every flagged line is a top-of-function
>   `let mut <v> = String::new();` — the entry-declaration emitter — so that emitter was changed to
>   consult `local_mut` like the other four declaration sites, rebuilt (binary newer than source,
>   verified) and re-measured: **the output does not change**. `local_mut` therefore already holds
>   those names even though rustc sees no mutation after the initializer, i.e. `compute_local_vars`
>   over-approximates mutation; the precise fix is mutation analysis there, not the emitter, and the
>   emitter change was reverted because a change that moves no measurement is not worth its risk.
>   The same round killed two false assumptions in v150's own test: it required `add_helper("<key>")`
>   to render literally `__sh_<key>` (false — `outbytes` renders `__sh_out_bytes`), and its scanner
>   read `add_helper("…")` out of doc prose. It now requires each key to be a HELPER_ORDER member,
>   the rendered list to be total (one name per entry) with collisions confined to declared variant
>   pairs (see v152), and skips non-identifier keys.
> - v150: **D: one derivation for helper pruning, and warnings made measurable.** (1) The emitter's
>   text passes stay, but `prune_unused_helpers` no longer owns its copy of the "rendered name" rule:
>   `helper_rendered_names()` reads the registry (`HELPER_ORDER` x `helper_source`) once, and a new
>   test requires every `add_helper("k")` key to render `fn __sh_k` in that list, every rendered name
>   to sit in the `__sh_` namespace, and the list to hold at least 60 entries. A helper body whose
>   shape the parse cannot read is now a test failure instead of dead code that silently survives
>   (the failure mode item 4 of C described).
>   (2) The `flags` parameter of `__sh_regex` is NOT dead: it carries `nocasematch` (`"i"`), wired in
>   v147 — verified by rendering a case-folding `=~`, which emits `__sh_regex("ABC", "^abc$", "i")`.
>   The engine choice stays in the helper NAME (`regex` vs `regex_posix`), which is what
>   `cargo_manifest` keys on; the parameter carries only the runtime flag, so dropping it would lose
>   case folding.
>   (3) `harness/rust-warning-census.sh` (per-program, `--quiet`, `--json`) makes generated-code
>   warnings measurable, because `fail-rs` compiles with warnings ignored and cannot see them grow.
>   Measured baseline over the corpus: **563 programs, 29 with warnings, 77 warnings total** (1 not
>   compiled, 19 skipped because they need the cargo `regex`/`revera` dep). Largest classes:
>   `variable does not need to be mutable` 19, dead initializers across many names (`i` 4, `x` 2,
>   `r` 2, then one each of y/result/name/j/divisor/count/X/VAR/…), `unreachable expression` 4,
>   `unreachable statement` 3, unused variables (`var`, `value`, `key`, `IFS`). 058_advanced_bash_idioms
>   — the example that first surfaced this — carries 3 dead initializers plus 3 bindings whose only
>   reads were inside a heredoc body the renderer folded to a literal. The emitter ALREADY has the
>   analysis points these need: `local_mut` drives `let`/`let mut`, and `local_dead_init` already
>   emits `#[allow(unused_assignments)]` for some locals (the 058 names are simply not in that set).
>   So this is an analysis-coverage gap in `compute_local_vars`, not a missing mechanism — it is
>   recorded with the measured numbers rather than papered over with a blanket `allow`.
>   (4) BigInt (`~18337`) remains sound-but-broad: `stmt_huge`/`expr_huge` mark a whole function
>   BigInt when any reachable expression is, with a TODO for precise per-function mapping. The named
>   prerequisite is param-position tracking (which positions actually receive huge values), not a
>   different integer strategy; recorded here so the optimisation is scoped rather than folklore.
> - v149: **C: bash is no longer the runtime for pattern matching, uid or hostname.** (1) `grepMatches`
>   (and the grep -o lift) spawned `bash -c 'printf … | grep -o …'` for EVERY match.
>   `__sh_grepmatches` is now native: POSIX BRE is TRANSLATED to ERE (`\+`, `\?`, `\|`, `\(`, `\{`
>   become operators; unescaped ERE metacharacters become literals; bracket expressions copy
>   verbatim), `-E` passes through, `-i` folds, `(?m)` gives grep's per-line `^`/`$`, and
>   `find_iter` advances exactly like `-o`, one match per line. An invalid pattern now exits 2 like
>   grep instead of 1. The helper's dependency moved from `cap_bytes` to `regex`, so the emitted
>   project declares the crate it calls. Verified byte-identical to bash on the five grep -o
>   programs in the corpus, including `pattern[0-9]\+` — the BRE case a pass-through would have read
>   as a literal `+`.
>   (2) `$UID`, `$EUID`, `$HOSTNAME` rendered `__sh_capture("id -u")` / `("hostname")` — a process
>   for a constant. They read `/proc/self/status` (`Uid:` real/effective, `Gid:`) and
>   `/proc/sys/kernel/hostname`, and `-O`/`-G` compare against the same native uid/gid instead of
>   spawning `id -u`/`id -g` themselves. Verified against bash: uid, euid, hostname, `-O /tmp`,
>   `-G /tmp` all identical.
>   (3) `harness/shellout-census.sh` makes the remaining dependency measurable: per-program list,
>   `--quiet`, `--json`. Measured: **563 programs, 337 spawn no bash, 226 still emit a
>   bash-spawning helper** (`spawn` 186, `capture_rc` 63, `run` 57, `run_traps` 29, `cap_bytes` 9,
>   `bg` 3). The three grep -o programs left that set; the rest are bodies the backend cannot
>   reconstruct (eval, command, trap, and command substitutions whose text is not known at render
>   time).
>
>   **Still open (recorded, not blessed):** `arith_text_unparsed` — arithmetic containing nested
>   `$(…)` — still evaluates through `capture_rc`. `parse_arith` returns `None` for any `$` operand
>   BY DESIGN (bash expands `$var` into the arithmetic text before parsing, so `$(( $j * 2 ))` with
>   `j` unset is a syntax error, which a native read of 0 cannot express). The fix is to extract the
>   `$(…)` spans, lower each through the existing cmdsub path, bind the results as numeric locals,
>   parse the remaining arithmetic against those bindings, and keep the shell fallback only for text
>   that is still not parseable.
> - v148: **The rust parse-error verdict, and a real diagnostic channel for `Warn`.** (1) `--target rs`
>   had NO parse-error fallback: estree and Perl both render an exit-2 program for an unparseable
>   source, rust rendered the EMPTY program, which exits 0. Five examples were exactly that in the
>   ad-hoc corpus runner (bash_rc=2 / rust_rc=0): parse-double-semicolon,
>   parse-error-doublesemicolon, parse-parameter-expansion-eof, parse-paren-after-do,
>   parse-unexpected-end-of-input. They are `SKIP-bashn` in `harness/fail-rs` (`bash -n` rejects
>   them, so the gate has no reference arm), so this fixes emitted-program behaviour, NOT a gate
>   verdict; it is verified directly instead (all five: empty stdout, rc 2, matching bash).
>   `parse_error_rust_fallback` mirrors the Perl one, and the parser's own message is passed as a
>   RAW-STRING ARGUMENT (`eprintln!("{{}}", r#"…"#)`) — the first attempt interpolated it into the
>   format literal, so a message containing `${` failed to compile ("invalid format string"). All
>   five now run with bash's stdout and rc 2. (2) `IrStmt::Warn` had no rust arm and became a TODO
>   marker, so a lowered syntax error (the stray `)`/`}` transform emits Warn + exit 2) exited 2 in
>   silence; it now renders `eprintln!("{{}}", msg)`.
>
>   **What the 30-diff list actually was.** `harness/fail-rs` compares STDOUT and rc only. Measured
>   with a clean gate run, the authoritative red set is ONE: `parse-brace-in-heredoc` FAIL-rustc, the
>   pre-existing compile failure. The other 29 came from an ad-hoc runner that also compared stderr,
>   and several were artifacts of that runner — it used `timeout` (which resets argv[0]) and a shared
>   `sh2prog` output path, so `$0` examples such as 057_case and qx-var-builtin-cd ran the wrong
>   binary, and 046_cd. is cwd-sensitive and passes under the gate. The rest are stderr-only fidelity
>   gaps, real but ungated: (a) exec diagnostics leak `bash: line 1:` instead of `$0: line N:`
>   because `__sh_run` shells out and bash formats its own message; (b) lowered builtins print nothing
>   where bash diagnoses (bad substitution, arithmetic errors, `cd` failures); (c) `Warn` has no
>   `$0: line N:` prefix or echoed source line, because the IR carries no source position. Those
>   three need a position-carrying diagnostic channel; recorded open, not blessed.
> - v147: **`=~` correctness pass: numeric operands, `nocasematch`, invalid-pattern status, and a gate
>   against the dropped-helper trap.** (1) `[[ $t =~ 3 ]]` with `t=3` rendered `__sh_regex(&t, …)`
>   against an `i32` and failed to compile (E0308): the existing numeric coercion covers numeric
>   *literals* only (`[[ 1 =~ 2 ]]` worked), because a variable's type is not visible at the test site,
>   so both operands are now stringified unconditionally. (2) `shopt -s nocasematch` was tracked for
>   `==`/fnmatch but never reached `=~` (the arm hard-coded empty flags); it now passes `"i"`, which the
>   `regex` engine folds with `(?i)` and revera folds with `case_insensitive` — exact `REG_ICASE`, no
>   approximation. (3) An invalid pattern now returns `None` rather than `false`, so the condition
>   stores bash's status 2 (measured: bash prints *nothing* for a runtime-invalid pattern; the familiar
>   message belongs to the parse-time case of a literal unbalanced pattern). `if [[ … =~ $bad ]]` now
>   matches bash exactly. **Residual:** the BARE-statement form still reports status 1 — the generic
>   test-statement wrapper (`{ let __b = …; __SH_RC.store(if __b { 0 } else { 1 }); __b }`, three
>   emission sites) overwrites the condition's status with 0/1. Fixing that needs a tri-state through
>   the wrapper rather than another text hack, so it is recorded open, not blessed. (4) `helper_source`'s
>   unknown-name fallback now `debug_assert!`s, and a test scans this file for every literal
>   `add_helper("…")` and requires the name to be in `HELPER_ORDER` AND to have a `fn __sh_` body — the
>   trap that cost the `regex_posix` work a build.
>
>   Measured: 131 `rust_backend` tests pass (129 + the helper-registry and regex-shape tests); the 16
>   `=~` corpus examples still build through the cargo path with **14 byte-identical to bash** and the
>   same 2 stderr-only diffs; full corpus unchanged at 516 ok / 30 diff / 1 pre-existing compile failure
>   / 0 status diffs, with an identical diff-name set.
> - v146: **`=~` can use a POSIX ERE engine (`--regex-engine posix`), because bash's
>   semantics are not Rust's.** The `regex` crate is leftmost-first and Perl-flavoured:
>   in bash `\d` is a literal `d` (POSIX ERE has no such escape) while Rust reads a digit
>   class. `--regex-engine posix` renders `__sh_regex` against `revera` 0.2 instead —
>   POSIX.1-2024 ERE, leftmost-longest, POSIX bracket classes, no Perl escapes (measured:
>   `a|ab` on `abc` yields `ab`, which the `regex` crate never does) — and
>   `cargo_manifest` then declares `revera` rather than `regex`. The engine is a
>   per-render thread-local, restored immediately, because harnesses render many programs
>   in one process; the default engine is unchanged, so this is opt-in per program.
>
>   One trap worth recording: helpers are emitted by walking `HELPER_ORDER`, so a new
>   helper name that is absent from that list is silently dropped — the call site still
>   references `__sh_regex`, and the generated program fails with E0425 rather than
>   emitting an obviously wrong body.
>
>   Measured with the posix engine: all **16** corpus examples using `=~` render, build
>   offline and run — **14 are byte-identical to bash (stdout and rc)**, and the 2 that
>   differ are the same 2 as under the default engine and differ only on bash's own
>   stderr text (`063_hard_to_parse`, `070_gnuisms_thorough`). So the switch is
>   corpus-neutral: it changes semantics only where the dialects disagree.
>
>   Dialect probe (text `a-b`, pattern `\w+`): bash NOMATCH, `regex` engine MATCH, posix
>   engine NOMATCH — revera reproduces bash's literal-`w` reading where Rust's engine
>   invents a word class. Limits: revera is pure POSIX, so glibc's GNU operators (`\<`,
>   `\>`, `\b`) are not expressible on it either; and the probe surfaced a separate
>   latent bug — a `=~` whose LHS is an int-typed variable renders `__sh_regex(&t, …)`
>   and fails to compile — fixed in v147 (numeric operands are stringified).
>
>   `revera` is not in the offline registry by default: the first posix build fetches it
>   once, after which `cargo build --offline` works. 129 `rust_backend` tests pass, plus a
>   CLI test that `--regex-engine posix` selects the helper and does not leak.
> - v145: **Generated Rust can declare a dependency: `regex` replaces the bash shell-out in
>   `__sh_regex`, and `--cargo-dir` emits the manifest that makes it linkable.** `__sh_regex` used to run
>   `bash -c '[[ $1 =~ $2 ]]'` per match — a process per test, plus a runtime dependency on bash being on
>   PATH. It now builds the pattern with the `regex` crate (`nocasematch` → the `(?i)` flag; an INVALID
>   pattern is a non-match, matching bash's status-2-with-no-match), which makes it the first helper to
>   reach outside `std`. Generated programs are single files with no manifest, so
>   `--target rs --cargo-dir DIR` writes `DIR/Cargo.toml` + `DIR/src/main.rs`, and
>   `rust_backend::cargo_manifest` declares `regex = "1"` **only** when the rendered text references
>   `regex::Regex` — every other program stays a dependency-free file that plain `rustc` still compiles.
>   `harness/fail-rs` builds the crate-using programs through that project (`cargo build --offline
>   --release`) and keeps `rustc` for the rest, so the gate exercises both arms.
>
>   Measured: all **16** corpus examples using `=~` build through the manifest and run — **14 are
>   byte-identical to bash (stdout and rc)**, and the 2 that differ differ only on bash's own stderr
>   diagnostics (`063_hard_to_parse`'s "division by 0"/"bad substitution", `070_gnuisms_thorough`'s
>   "err-to-stderr"), both already in the standing diff set and neither on a regex line. Full corpus:
>   **516 rustc-path + 16 cargo-path = 563**, 0 exit-status differences, the same 32 diffs and the same
>   single pre-existing compile failure (`parse-brace-in-heredoc`) as v144. 129 `rust_backend` tests pass.
> - v144: **v136 named the next shared win and refused to half-land it; this lands it — the `DefinedOr` subject was evaluated up to three times per render, and the fix is one IR transform plus a binding in each renderer.** `DefinedOrHoist` runs LAST in `Pipeline::canonical()` and rewrites a single-target statement `x = DefinedOr{a, b}` into `__sh2_dor_N = a; x = DefinedOr{Var(__sh2_dor_N), b}`. Leaves (`Var`/`Int`/`Str`/`Bool`) are skipped because there is nothing to evaluate twice, `Declare` inits and already-nested `DefinedOr`s are left alone, and the temp comes from a per-run counter rather than a `static` — the ten `static Mutex` globals in `shir.rs` are exactly what `PassContext` exists to retire. Statement level is what makes it backend-neutral: an expression-level rewrite would need an expression form of sequencing that not every renderer has.
>
>   **What each renderer does with the temp.** C uses the backend's own statement-expression idiom, `({ char *__sh2_dor_t = _sh_sc(<subj>); (__sh2_dor_t && *__sh2_dor_t) ? __sh2_dor_t : (<dflt>); })`, with `_sh_sc`'s NULL guard; that arm previously fell into `other => mark_todo` and emitted a literal `0`. Java gains `shDefinedOr(Supplier<String>, Supplier<String>)`, so the default stays LAZY while the subject is bound once — and the helper must be requested in the scan pass *and* listed in the emitter's hard-coded array, because the `helpers` `BTreeSet` is taken and discarded at emission. Perl binds the subject in a lexical temp inside an immediately-invoked sub and tests `defined($t) && $t ne ""`: bash's `:-` means *unset OR empty*, so `//` alone keeps an empty string where bash substitutes a default. estree and Rust already bound a temp; their half of the bug was in the folding pass, where `copy_propagation::fold_expr` descended into `DefinedOr` and could re-inline a copy or a constant on BOTH sides of the emptiness test, undoing the hoist — the node is opaque there now.
>
>   **A subshell write is never a single def.** The premise `count_expr_assigns`/`fold_stmt` lean on — "assigned exactly once in the whole program" — is false for anything written inside a subshell, a `&` job, or a `$( … )`: the body runs in a CHILD, zero or many times, and the write never reaches the parent's binding. New `promote_child_writes` counts those bodies into a scratch map and then promotes each written variable to a multi-write, clearing its value slot to the inert `false`, so a capture body can no longer be folded as a single static def. `Block` stays transparent — it is not a child, and its single write still folds (pinned by test).
>
>   **Tests.** `sh2perl/tests/defined_or_hoist.rs` (5: the hoist shape, canonical-pipeline registration, and the C/Java/Perl bindings — the last three matter because the shell frontend never emits `DefinedOr`, so renderer arms are reached only from the A1 ingress) plus three rule tests in each backend's `copy_propagation` module (subshell body → 2 writes, capture body → 2, plain block → 1); 18 pass in estree, 18 in Rust.
>
>   **Gates.** `./fail` **563/563, exit 0** (314 s). `harness/fail-rs` **556 pass / 0 fail / 7 skip, exit 0**. `./fail-go` **126/126, exit 0**. `cargo test --lib -- rust_backend` **125 pass / 0 fail**. `harness/java_gate_local.sh` **572 pass / 72 fail, exit 0** — its standing cross-product backlog, and no corpus output moved (Perl is byte-identical at 563/563, and the corpus never reaches the `DefinedOr` arms). C-gate (`BIN=sh2perl/backends/c/target/debug/c_backend harness/c-gate-run.sh`) **639 pass / 7 skip parse-error / 5 fail** — the same five as the v90 baseline (3 `rc`, 2 `stdout`). `./fail-estree` **562/563 (99.8%)**: one cell, `dq-hashbang-multiline-assign.sh`, reported `otranspilerl --target estree failed`; that file renders clean standalone (`--target estree`, exit 0, valid ESTree), so it reads as a race inside the gate's own CLI build rather than a render regression, and the earlier estree cell died by SIGTERM (exit 143) mid-build.
>
> - v144: **`main` returns `ExitCode`, so the exit status is a VALUE.** The epilogue called
>   `process::exit(__SH_RC…)`, which skips destructors and — with stdout on a pipe — can drop a trailing
>   `print!` that had no newline to flush. `main` is now `fn main() -> std::process::ExitCode` and ends
>   with `std::process::ExitCode::from(__SH_RC.load(Ordering::Relaxed) as u8)`; the 8-bit mask is what
>   bash does for `exit 300` (44) and what `process::exit` did anyway. Both statically-zero paths
>   (`rc_disabled`, and an all-literal-0 body with no read) tail `ExitCode::SUCCESS`, because falling off
>   the end of a value-returning `main` no longer type-checks; a body that already diverges still gets no
>   tail, so the `unreachable_code` warning does not come back.
>
>   Two deliberate non-changes. The `exit` **builtin** stays `std::process::exit(…)`: it can appear inside
>   a user function or a closure, where `return` would only unwind that function instead of ending the
>   script. A **top-level `return`**, by contrast, does reach main's body — that arm now returns a status
>   value (`return ExitCode::from(…)`), closure-aware and rc-disabled-aware (no register to read there);
>   it used to emit a bare `return;`, which is E0069 once main returns a value (witness
>   `return-double-semicolon.sh`).
>
>   Measured: 563 examples rendered, compiled with `rustc` and run against bash — **530 match stdout AND
>   exit status, 32 differ, 1 pre-existing compile failure, 0 exit-status differences**. The compile
>   failure is `parse-brace-in-heredoc` (a `print!` format string carrying raw braces; it fails identically
>   before this change). Of the 32, 31 are the standing Rust-output gaps and `046_cd` differs only because
>   the sweep runs each program in its own directory (`cd ..` + `ls`; verified identical from one cwd).
>   `cargo test --lib -- rust_backend` **128 pass**.
> - v143: **A discarded status block is a statement, not `let _ = { … };`.** The status modellers for
>   `test`/`let`/`cd`/arithmetic each return a block whose tail is the value the shell drops
>   (`{ let __b = …; __SH_RC.store(…); __b }`), and every statement position wrapped that block in
>   `let _ =`. The wrapper is redundant — a block is already a statement. `emit_discard` now emits
>   `{ … };` for a block whose tail is a bare carrier ident (or which has no tail) and keeps `let _ =`
>   only for a genuine `#[must_use]` discard: io/fs/process/thread calls (`write_all`, `read_to_end`,
>   `flush`, `fs::write`, `join`, `wait` — ≈1,430 of the sites, kept deliberately) and any block ending
>   in a `#[must_use]` call (`Result::is_ok`, which warns when dropped as a statement — the first attempt
>   at this converted those too and added 25 new warnings). A capture folded to `String::new()` is
>   dropped outright. `cd_expr` takes a `value: bool`: its `__r.is_ok()` tail exists only for the
>   `exec_bool` operand, so a statement position ends at the status store. Measured: **1,623 → 1,552
>   `let _ =` sites, 288 → 271 files, block-form wrappers 68 → 11, folded `String::new()` 14 → 0, corpus
>   1,896,225 → 1,895,079 bytes**, 47 files changed, no `unused_must_use` warnings, 0 rustc failures, and
>   all 47 match bash stdout + exit status (125 `rust_backend` tests pass).
> - v142: **Single-scope locals are declared at the top of their scope, not only at a top-level first
>   write.** The pass-2 promotion gate required a name's FIRST mention to be a top-level write, because
>   that write is where the deferred `let` landed. Two shapes therefore stayed on the thread-local
>   (`__SHV_`) path even though nothing about them needed global storage: a name READ before its first
>   write (`echo "[$x]"` then `x=hi`, or `if [ -z "$x" ]; then x=1; fi`), and a name whose first write
>   is nested (a block/branch/loop-body accumulator). Both are still one non-risky scope — the only
>   thing missing was a place to put the declaration. `compute_local_vars` now returns a fourth set,
>   `local_entry`: those names are emitted as `let mut <n> = String::new();` / `0i64` at the top of
>   `fn main` (or of the owning function's body), initialised to bash's unset value, and every write
>   renders as a plain assignment — they are removed from `owned_inits` (no second, shadowing `let`)
>   and from `borrowable_vars`, whose `&str` verdict assumes the `let` IS the single assignment.
>   `#[allow(unused_assignments)]` silences the nested-write case, where nothing reads the initialiser.
>   Loop variables are excluded on purpose: a `for` binding is not a mention (the scope walker skips
>   binding positions), so `for n in …` looks read-first — the pass-6 native binding owns those names
>   and five loop tests caught the first attempt at promoting them.
>
>   Measured over the 563-example corpus: **1,756 → 1,458 `__SHV_` sites (178 → 142 files), 3,611 →
>   3,441 `lock().unwrap()`, 1,910,417 → 1,896,225 bytes**, 47 files changed, 0 rustc failures, and all
>   47 match bash stdout + exit status. Tests: `read_before_write_local_gets_a_scope_entry_let`,
>   `nested_first_write_local_gets_a_scope_entry_let`, `numeric_read_first_local_initialises_to_zero`
>   (122 `rust_backend` tests pass).
> - v141: **`__sh_div`/`__sh_mod` now appear only where the divisor can be zero.** The guard exists to set
>   `__SH_ARITH_ERR` instead of panicking on an i64 divide-by-zero, so a NON-ZERO LITERAL divisor made
>   it pure overhead: `count % 10` emitted `__sh_mod(count,10)` and dragged the helper plus the
>   `__SH_ARITH_ERR` static into the program. The `/` and `%` arms now emit `(l / r)` / `(l % r)` when
>   the divisor is a literal `Num(d != 0)` — both operands widened through `arith_i64`, so
>   `(x % 2i64)` — and fold `0 / <literal>` outright. A variable divisor keeps the helper: bash prints
>   `division by 0` and sets the status, which is exactly what the flag models, so `0 / n` is NOT folded
>   (`0/0` is an observable error, not 0; literal-literal is already folded before the renderer).
>   Measured: `051_primes` loses `__sh_mod` and `__SH_ARITH_ERR` entirely, corpus −228 bytes with 1 of
>   563 files changed (the other five files' divisors are variables and are byte-identical). Tests:
>   `literal_divisor_skips_the_zero_guard_helper`, `variable_divisor_keeps_the_zero_guard_helper`;
>   122 `rust_backend` tests pass; 051_primes matches bash stdout + rc.
> - v140: **Flow-sensitive liveness for `dead-store-elim` — and the two read-oracle gaps it exposed.**
>   The pass was flow-INsensitive: it dropped a store only when `analyze_var_const` said Const and the
>   name had ZERO reads anywhere, so `X="0"; echo "$X"; X="1"` kept the trailing store forever.
>   `transforms/dead_store_elim.rs` now runs a second, backward liveness pass per statement list
>   (`flow_transform`, after the zero-read half): live-out per statement; If/elsif/else union; a
>   loop-HEAD fixpoint for While/DoWhile/For/ForInit (a body store feeds the NEXT iteration, so
>   pruning a body with the loop's own live-out deletes loop-carried counters); Case clause union with
>   `$name` in a pattern counted as a read at that point; Block/Subshell/Pipeline/Try union; Function
>   bodies seeded from the program-wide `escapes` set (a call-time read is not a read there). A store
>   drops only when every target is dead-out, the RHS is pure, the name is not
>   escaped/exported/shell-implicit/`$?`, and — the invariant the first version missed — the name
>   ALREADY has a store before it. The FIRST store carries the literal `analyze_var_types` uses for
>   i64-vs-String lifting: dropping one turned `Cell<i64>` into `RefCell<String>` in 14 files, removed
>   a `__SH_RC` reset, and emitted `let j = (j… )` reading an undeclared name (the whole `target`
>   compile-failure class). Two read-oracle gaps closed on the way, both of which had let liveness
>   drop a live store: `arith_census` recorded NOTHING for `ArithAst::IncDec`/`Ident` (`i = 5; ((i++))`
>   read as dead — bash then printed the postfix status of the wrong old value), and `i += 1` now
>   counts as a read of `i`. Status names (`?`, `lastExit`, `__rc`) are never flow-dead: every command
>   sequences a write to them with no visible read.
>
>   **Corpus effect: none — the Rust for all 563 examples is byte-identical, 1,910,645 bytes, 0 files
>   changed.** The four remaining never-read/unused-variable warnings are not dead stores:
>   `arith-postfix-status`'s `i` is the operand of an `IncDec` whose VALUE is the status
>   (`parse-longoption-with-dollar`'s `X` sits inside the expression-level `||` block, not a statement
>   list), `backslash-dollar-brace`'s `var` is read by `eval` TEXT (the pass refuses a program with a
>   dynamic write), and `parse-heredoc-paren`'s `IFS` renders as a textual `${IFS:-}` whose binding
>   nothing reads. The case the pass does fix: `X=0; echo "$X"; X=1` now emits one store. Tests: 8 in
>   `dead_store_elim::flow_tests` (drop-after-read, branch read, loop-carried store, IncDec read,
>   arith-call text read, function escape, export guard, shell-implicit guard).
> - v139: **The second capability through the neutral recogniser was `rm` — and chasing why it
>   vanished found a correctness bug that the gates cannot see.** `rm [-f] [-r|-R]` is a STATUS
>   command (prints nothing), so it belongs at the statement choke point: `NativeValue::Rm { force,
>   recursive, paths }` joins `Mktemp` in the shared recogniser, `capabilities/rm.rs` delegates its
>   flag/operand gate to it (one definition, refusals included: `-i`, `--preserve-root`, a glob, an
>   array operand), and Rust renders `__sh_rm(force, recursive, &[paths])` over `std::fs`
>   (`remove_dir_all` for a tree under `-r`, `remove_file` otherwise, `-f` swallowing a failed
>   operand). Hooks at both statement shapes (`exec_stmt` for `Call{exec|builtin}` and the
>   `IrStmt::Exec` arm, no redirect/env). **30 → 4** `bash -c rm` shell-outs, 54 native calls in 36
>   files; the 4 left are legitimate refusals (a glob operand, `--preserve-root`, and one `rm` in
>   condition position, which is not a statement).
>
>   **The bug.** The first version emitted nothing at all: a bare `rm -f a b` in a script that never
>   reads `$?` produced a program with no delete. Two status-register passes were the cause, both
>   with hand-maintained whitelists. `emit`'s "pass-4" collapse removes a *previous* store line when
>   a new one arrives, guarded by `rc_plain`, a list of helpers that "run something"
>   (`__sh_run`, `__sh_spawn`, `__sh_pipe`, …); `__sh_rm` was not on it, so `store(__sh_rm(…))`
>   looked like bookkeeping and the `rm` was deleted. And `rc_strip` (the `rc_disabled` path, for a
>   source with no status read at all) deletes every `__SH_RC.store(…)` *call*, which for a
>   status-only statement is the statement. **Both are now decided by one predicate,
>   `rc_drop_is_safe(value)`: a store of a plain value (identifier/number/bool) is bookkeeping and
>   may go; a store of a CALL is the statement, and survives — as `let _ = …` when the whole
>   register is stripped.** A new helper cannot silently join the "plain" set again. Worth stating
>   plainly: `fail` and `fail-rs` passed *with* this bug, because a lost `rm` produces no output and
>   the corpus never depended on a deleted file — the unit tests are what pin it.
>
>   **`-f` means "a missing operand is not an error", not "ignore every error".** The first helper
>   swallowed any failure under `-f`, so `rm -f dir` exited 0 where bash exits 1 (EISDIR is not
>   ENOENT). It now matches on `io::ErrorKind::NotFound` — which also let the compiler shorten the
>   path to `io::ErrorKind`, and is the idiomatic form of the flag. Verified by compiling each
>   spelling and comparing status with bash: `rm -f missing` 0/0, `rm -f dir` 1/1, `rm nope` 1/1,
>   `rm -rf tree` 0/0, `rm -r dir` 0/0.
>
>   **Cost.** 1,308,754 → 1,321,508 bytes (+12.8 KB, +1.0%): 36 files × ~350 B of helper against
>   ~60 B saved per site, and 25 previously-dropped `rm` lines that now (correctly) exist.
>
>   **Gates.** `./fail` **563/563, exit 0** (the Perl leaf's gate now comes from the shared
>   recogniser, and its output stayed byte-identical). `harness/fail-rs` **556 pass / 0 fail / 7
>   skip, exit 0**, `resumed=563` — fully fresh, so the 25 rewritten sites ran against bash. 0 emit
>   failures, **0 rustc errors** over 563 files, **4 warnings** (unchanged, none from the new
>   helper). `cargo test --lib rust_backend` **160 pass / 0 fail** (+2: the statement lowering with
>   its refusals, and the shared store predicate); `pipeline_native` **29 pass**. Core worker healthy
>   (gate GREEN 18:47, no `sleeping-*` marker).
> - v138: **The biggest single polyfill class in emitted Rust was "spawn a shell to get a
>   filename" — and the fix was to make a Perl-only capability backend-neutral.** `d=$(mktemp -d)`,
>   `f=$(mktemp)` and the `process_subst` materialisation behind every `<( )` each rendered as
>   `__sh_capture_rc("'mktemp' '-d'")`: a `bash -c` child forked to learn a path. Perl has never done
>   that — `capabilities/mktemp.rs` has lowered it to `File::Temp` for years — but that leaf returns
>   PERL TEXT, so no other backend could use it. **83 → 11** shell-out sites (72 lowered, 42 of 563
>   files now carry the helper); the 11 left are the TEMPLATE spelling
>   (`mktemp /tmp/x.XXXXXX`), a different feature that still needs a real shell.
>
>   The shared half, so the next backend is a render rather than a re-derivation:
>   `pipeline_native::native_value(&IrExpr) -> Option<NativeValue>` recognises a VALUE-channel
>   capability from the `Call{exec|builtin, [cmd, Array(words)]}` shape every frontend produces, and
>   `NativeValue::Mktemp { dir }` is the first variant. `capabilities/mktemp.rs` now *delegates its
>   gate* to it, so the accepted/refused spellings have one definition — a test asserts the Perl leaf
>   and the recogniser agree, including the refusals (`--tmpdir`, `-t`, `-q`, a template operand).
>   Rust renders `__sh_mktemp(dir)`: O_EXCL create (`create_new` for the file, `create_dir` for the
>   directory), 0600/0700, in `$TMPDIR` else `/tmp`, counter + retry loop for uniqueness, no child.
>   The hook sits at BOTH capture choke points because the two body shapes differ: a parsed command
>   arrives as `Expr(Call)` while the `process_subst` materialisation arrives as `IrStmt::Exec` —
>   the first version caught only 28 of the sites and looked correct until the corpus was re-counted.
>
>   **Cost, stated honestly.** 72 files × ~330 B of helper against ~60 B saved per site: the corpus
>   emission grows 1,291,026 → 1,305,831 bytes (+14.8 KB, 1.1%). It buys a `fork`+`exec` per
>   `mktemp` gone and one less dependency on a shell being present at runtime. The helper is
>   emitted only when used (42 files), and its comments are one line because it is generated code.
>
>   **Gates.** `./fail` **563/563, exit 0** (the Perl leaf's output is byte-identical after the
>   refactor — the gate would have caught a drift). `harness/fail-rs` **556 pass / 0 fail / 7 skip,
>   exit 0**. 0 emit failures, 0 rustc errors over 563 files, 4 real warnings (unchanged).
>   `cargo test --lib rust_backend` **158 pass / 0 fail** (+1: no `__sh_capture_rc`, helper emitted
>   once, file and directory arms, and a refused spelling keeping the seam); `pipeline_native` tests
>   **29 pass** including the three new recogniser tests. Core worker healthy (gate GREEN 17:38, no
>   `sleeping-*` marker, supervisor + body alive).
> - v137: **The remaining waste in value position was not size, it was re-evaluation — and one lint
>   path had simply been missed.** An `X=…` / `y+=2` used as a VALUE binds its RHS once and the
>   store moves a clone (string path) or stringifies the temp (arith path). Both rendered the RHS
>   TEXT twice on one line (`{ let __v = V; store = V; __v }`), so every parse, `format!` and
>   `.join()` in the expression ran twice — and a `$(cmd)` there would have forked twice, which bash
>   does once. **9 → 0** duplicated-value sites across 563 files; `051_primes`' `z[0] += primes`
>   re-ran its whole rhs (`join`, four `parse::<i64>`) on every iteration.
>
>   The borrowable-local branch is exempt on purpose: a `&str` local binds the RHS *text* itself, so
>   routing it through a `String` temp would change its type — and its RHS is a literal by
>   construction, so there is nothing to re-evaluate.
>
>   The lint miss: the `#[allow(non_snake_case)]` predicate was copied inline at three emit sites and
>   **absent from the three local-array `let` sites**, so `let FilesystemOptions = [..]` warned while
>   the scalar path was covered. One `Render::ns_attr` now decides it for every `let` a shell name
>   reaches. 5 → 4 real rustc warnings over 563 files (0 emit failures, 0 rustc errors, 8 warning
>   lines incl. rustc's own summary lines).
>
>   **What is left, measured.** The corpus emission is now 29,000 lines with 0 cast noise, 0
>   duplicated-value sites, 4 warnings. The two remaining `value assigned …is never read` warnings
>   (`X="0"`, `i++`) and the unused `IFS`/`var` are all *stores whose variable is dead*: the shared
>   `dead_store_elim` only drops a store when `analyze_var_const` calls the name a Const (single
>   assignment site), and each of these has two sites, so the coarse pass refuses. Flow-sensitive
>   liveness (read-after-this-store) is the fix, and it is a whole-pass change: recorded, not
>   half-landed. The far larger remaining item is unchanged from v136's survey: **146 of 563 files
>   still shell out** (361 `__sh_run` + 241 `__sh_capture_rc`), because `pipeline_native` emits PERL
>   TEXT rather than a backend-neutral node — generalising it (leaves return node-id + args, each
>   backend renders) is the next real cross-backend transform, and it needs the multi-backend gate
>   list from v136.
>
>   **Gates.** `harness/fail-rs` **556 pass / 0 fail / 7 skip, exit 0** (the 7 are the
>   intentionally-unparseable fixtures). `./fail` **563/563, exit 0**. `cargo test --lib
>   rust_backend` **157 pass / 0 fail** (154 + 3 new: the string value evaluated once, the arith
>   value evaluated once, and `ns_attr`'s table + the local-array emission). Core worker healthy
>   (gate GREEN 17:38, no `sleeping-*` marker, supervisor + body alive).
> - v136: **Every `${x:-default}` was copying the value a second time — and the cross-backend survey
>   that found it says the next shared win is `DefinedOr`, not another Rust shape.** The `:-` arm
>   emitted `else { __v.to_string() }` to make the two arms agree in TYPE, on the theory that a
>   borrowable local reads as `&str`. The census says otherwise: across all 43 corpus sites the
>   `var_expr` is `__sh_env(…)` (18), a TLS clone (6), `x.clone()` (7), `__SH_ARGV…join` (4),
>   `__sh_arg`/`__sh_capture` (5), `"lit".to_string()` (1) — **owned Strings, every one**, so
>   `.to_string()` was a full String copy for nothing. `read_str` returns a bare identifier for
>   exactly one case (a `&str` loop binding) and every other arm of both readers is owned, so a new
>   `is_borrowed_str` (bare identifier = the whole test) keeps the conversion for that one case and
>   moves `__v` out everywhere else. **48 → 0** (`-576 B`), 0 rustc errors over 563 files.
>
>   **The cross-backend part, measured not assumed.** Rendering one `${d:-lit}` per backend:
>   Perl ``(defined($ENV{HOME}) && length($ENV{HOME})) ? $ENV{HOME} : "/tmp"``, Java
>   `shEnv("HOME").isEmpty() ? "/tmp" : shEnv("HOME")`, C a `const char *_d0` that its printf then
>   re-expands three times — each repeats the lookup/second evaluation; only JS and Rust already bind
>   a temp. So the shared fix is a transform that hoists `DefinedOr`'s subject into a temp at IR
>   level. **Not landed here**, deliberately: it is a new globally-registered transform whose effect
>   lands in Java/C/Go, and the honest cost is the full verification path — `./fail` (Perl),
>   `./fail-estree` (JS), `fail-rs`, `./fail-go`, `harness/java_gate_local.sh`,
>   `harness/c-gate-run.sh` — which is more than one round can gate. Recorded with the exact shape
>   and the gate list so it can be done whole rather than half-verified.
>
>   **Gates.** `harness/fail-rs` **556 pass / 0 fail / 7 skip, exit 0, resumed=0** (fully fresh).
>   `./fail` **563/563, exit 0**; `harness/py-rust-gate.sh` **97/103, 4 FAIL** — the t104/t82/t87 trio
>   plus t89 (`no num_bigint rlib found`, the two-rlib pairing flake: t90/t101 passed this run and
>   t89 failed, and `deps/` holds two `libnum_bigint-*.rlib` with different hashes). 0 emit failures,
>   0 rustc errors, same 10 warning
>   lines. `cargo test --lib rust_backend` **154 pass / 0 fail** (152 + 2 new: the `:-` move for all
>   three subject shapes, and `is_borrowed_str`'s seven-way table). Core worker healthy.
> - v135: **The remaining waste is not bytes, it is copies — every test against a shell variable was
>   duplicating the whole value first.** A TLS-backed shell variable reads as
>   `__SHV_x.with(|v| v.borrow().clone())`, which is the right shape for a *value* but was also used
>   as the receiver of a *predicate* or a *comparison*: `ends_with`/`starts_with`/`contains` and
>   `==`/`!=` against a literal each took the clone. Those tests live in loop bodies and `case`
>   dispatch chains (the corpus re-tests the same subject once per clause), so the copy was paid per
>   evaluation. Two module-level helpers now render the test INSIDE the borrow:
>   - `str_pred(value, method, arg)` → `__SHV_x.with(|v| v.borrow().ends_with(&p))`;
>   - `str_cmp(l, op, r)` → `__SHV_x.with(|v| v.borrow().as_str() == "y")` (`as_str()` keeps the
>     expected type: `&str == String` and `&str == &str` are both defined, so the coercion the clone
>     form relied on is unchanged).
>   - `case_fold` gained the same arm for `nocasematch` (`…borrow().to_lowercase()`, one allocation
>     instead of two).
>
>   The guard matters more than the rewrite: evaluating the argument inside the borrow would panic if
>   it reached the same slot and asked for `borrow_mut()` (`${x:=default}` does), so an argument whose
>   text mentions the receiver's own slot keeps the clone-then-call shape — always correct, no
>   analysis needed. 42 copies per evaluation removed (13 predicate + 28 comparison + 1 nocasematch)
>   and **0** of the clone-then-test shapes remain in the corpus. Byte weight barely moves
>   (1,292,812 → 1,292,700, −112 B) — this is a runtime win, not a size one, and the corpus gate is
>   what proves it is not a behaviour change.
>
>   **Where the fix had to go.** `[ "$x" = "true" ]` does *not* travel through the `[[ ]]` parser: it
>   is lowered by test-lowering into `Eq(Var, Str)` and rendered by the generic `BinOp` arm, so
>   patching `binary_test` alone changed nothing (a debug print in that arm never fired). Both
>   lowerings are patched: the generic arm carries the corpus's cases, `binary_test` the ones whose
>   status stays observable.
>
>   **Gates.** `harness/fail-rs` **556 pass / 0 fail / 7 skip, exit 0** (101 verdicts resumed from an
>   identical binary, 455 fresh). `./fail` **563/563, exit 0**; `harness/py-rust-gate.sh` **98/103,
>   3 FAIL** — exactly the documented t104/t82/t87 trio (the bigint rlib flakiness was absent this
>   run, so the count is the baseline 98, not 95). 0 rustc errors,
>   same 10 warning lines across 563 files. `cargo test --lib rust_backend` **152 pass / 0 fail**
>   (149 + 3 new pins: the TLS comparison, `str_pred`'s own slot guard, and `str_cmp`/`case_fold`).
>   Core worker healthy (gate GREEN 15:29 and 15:54, no sleeping marker).
>
>   **The shIR question, answered honestly:** this is the fifth round in a row whose remaining
>   classes are renderer-local. Sharing them was checked, not assumed — the copy elision is built on
>   a *Rust* representation (a `RefCell` borrow window); C copies into a `char*`, estree's strings are
>   refcounted, and Perl has no borrow to extend, so a shared pass has nothing to say. The last
>   genuinely shared win was `unreachable-after-exit` (v133's predecessor); since then the residue is
>   emission shape, not IR redundancy.
> - v134: **The idiom surface is clean, so this round's targets were the four boilerplate shapes the
>   census still showed — all four are now zero.** Measuring first (556 emitted files):
>   - **`let _ = esc;` — 94 files.** The no-`-e` `print_words` variant spells its deliberately
>     unused parameter `esc` and discarded it on the first body line. `_esc` in the signature says
>     the same thing to rustc with no statement at all; the three-argument call shape is unchanged.
>   - **`let _ = String::new();` — 14 sites.** A statement-position `Call(shopt)` renders as the
>     empty string (the flag is consumed at render time — `nocasematch`), so the default statement
>     arm wrapped a pure no-op in `let _`. Both dispatchers (top level and loop body) now emit the
>     status write alone when the value expression IS the empty-string literal: nothing to run.
>   - **`let __d = "/".to_string(); … set_current_dir(&__d)` — 27 sites.**
>     `set_current_dir` takes `AsRef<Path>`, so a compile-time directory needs neither the `String`
>     nor the binding: `cd /tmp` now emits `set_current_dir("/tmp")`. A computed target keeps the
>     binding — it is one evaluation that must outlive the borrow. Copy-propagation makes this path
>     the common one (`d=/var; cd "$d"` is a literal by then), which is why the count is 29.
>   - **`&"foo".to_string().to_lowercase()` — nocasematch folds.** `str` has `to_lowercase`, so the
>     `String` round-trip before the fold is a pure waste (two allocations where one does). A new
>     module-level `case_fold` drops it for a literal operand and leaves every other expression
>     alone (the case methods do not exist on a number) — shared by the renderer and the `[[ ]]`
>     parser, which build the same comparison in two places.
>
>   **Result.** `let _ = esc;` 94 → 0, `let _ = String::new();` 14 → 0, literal `cd` target 27 → 0,
>   (the two `let __d = "default".to_string();` left in the corpus are the unrelated
>   `${x:=default}` template, which must keep a `String` to clone into the variable),
>   corpus 1,295,486 → 1,292,812 B (−2,674, 0.2%), **0 emit failures, 0 rustc errors, 10 warnings**
>   across 563 files (9 of them are "warnings will be skipped" roll-ups; the 5 real ones are the
>   long-documented nits — a non-snake-case test type, two dead assignments, two unused vars). Four new
>   in-file tests pin each shape (including the negatives: a computed `cd` target keeps its
>   binding, a non-literal operand keeps its `.to_string()`).
>
>   **Not landed, deliberately:** the 28 `__SH_RC.store(0, …)` lines immediately overwritten by
>   the following test block are a genuine dead store, but the fix is renderer look-ahead across
>   statements (pop the last emitted line when the next statement unconditionally writes), which
>   is not worth the fragility at 28 sites. The prologue is **68.7% of emitted lines** and that is
>   fair: every helper that survives `golf_rust` is reachable (12 helpers for a 2-statement heredoc
>   program, all transitively used), so the fat is in `__sh_printf`/`__sh_spawn` *bodies*, which
>   v132/v133 already took.
>
>   **Gates.** `harness/fail-rs` (fresh out dir, nothing resumed) **556 pass / 0 fail / 7 skip,
>   exit 0** — the 7 are the intentionally-unparseable fixtures (`SKIP-bashn`). `./fail` and
>   `harness/py-rust-gate.sh` after it. `cargo test --lib rust_backend` **149 pass / 0 fail**
>   (145 before + the 4 new pins). Core worker healthy throughout — its supervisor was mid-cycle
>   running `fail-estree` (7 min in), no sleeping marker, no repair needed.
> - v133: **The biggest remaining lever was already pulled — and proving that was worth more than a
>   guess.** The census after v132 has `__sh_spawn` at 187.5 KB over 198 files (2-arg 1,252 B/def ×
>   132, 1-arg 404 × 66), by far the largest helper, so the obvious move was to specialise it further:
>   of the 2-arg bodies, 114 files capture nothing, and dropping the `want_out` probe, the piped
>   stdout, the read-back buffer and the re-emit arm is ~370 B each. I built it — a shared
>   `shir::program_captures_output` verdict plus one `spawn_body` builder composed from three
>   capability facts, replacing the three hand-copied literals — and then measured it:
>   **zero files gained.** The 55 files that changed had already been slimmed by
>   `inline_spawn_sinks_when_unused`, a text pass that predates the work; my builder only put back
>   a 71-byte comment (the pass could no longer match its anchor and stripped the comment but not
>   the code). The other 2 files were **wrongly** stripped, because my gate asked the IR "can
>   anything capture" while the pass asks the RENDERED TEXT "is a sink ever written" — and 98
>   programs write `__SH_OUT` as a pipeline buffer without ever capturing. Net: +2,401 B and two
>   broken programs. Reverted in full; the emission is byte-identical to the round's baseline
>   (0/563 files differ), and the pass's own doc had already recorded that a verdict-based attempt
>   was "strictly weaker". **A helper body that looks unspecialised may already be specialised by a
>   text pass two layers down — measure before designing.**
>   - **What did ship: `hoist_shared_branch_status`.** A shell `if` whose branches both merely
>     finish (the common `if cond; then cmd; fi` with `$?` read afterwards) rendered as
>     `if c { …; __SH_RC.store(0, …) } else { __SH_RC.store(0, …) }` — the renderer cannot see that
>     the then-arm already ended at 0, so it synthesised an `else` that carries nothing but the
>     same write. Moving the write past the `if` is the same program (both paths end at status 0)
>     and drops the pointless branch: **-2,327 B over 32 files (-0.18%)**, no file larger. The pass
>     matches only the exact shape — the store must be the else-arm's ONLY line, one indent deeper,
>     immediately closed on the `if`'s own column, with the then-arm's last line that same store —
>     and iterates to a fixed point, because hoisting an inner pair exposes an outer one (5 files
>     folded twice). `empty_else_kept_when_status_is_read` pinned the OLD spelling; its intent (the
>     register must be written on the untaken path, once) is what it asserts now.
>   - **Verified.** `./fail` 563/563; `harness/fail-rs` 556/0/7 with `resumed=0` (a first run that
>     reported `resumed=563` was discarded — it had resumed a stale log and proved nothing);
>     `./fail-estree` 563/563 (100.0%); `cargo test --lib` 1781 passed / 49 failed, **0 in
>     `rust_backend`**. `harness/py-rust-gate.sh` reports 96/103: the three stable failures
>     (t104/t82/t87) are the documented ones, and the remaining two are the gate's big-int arm
>     swapping between t89/t90 and t93/t99 run to run — `ls -t` over `libnum_bigint-*.rlib` leaves an
>     rlib that `rustup run 1.90` rejects as "compiled by an incompatible version of rustc", so
>     which pair is probed first decides the verdict. That arm is unstable in this shared worktree
>     and says nothing about emission.
> - v132: **Three helper bodies, each proven before it shipped — and one of them was a regression I
>   had introduced myself the round before.** The census after v131 put `fnmatch` at 3,228 B over
>   31 files, `printf` at 5,856 B over 9 and `readline` at 676 B over 12, so this round attacks the
>   bodies themselves:
>   - **`fnmatch` extglob**: `@(a|b)R` was tested by building `a ++ R` as a fresh `Vec` and
>     recursing — one allocation per split point. A group match *splits* the subject (`a` on the
>     head, `R` on the tail), so the concatenation was never needed: **3,228 → 3,087 B/def**
>     (−141, −4.4%). Proven by extracting the HEAD body and the new one into one binary and
>     comparing them on **1,468,614 pairs** (every pattern up to length 4 over
>     `a b * ? [ ] ! ( ) | @ + - ^ \ .` × 21 subjects, plus 33 extglob/class/escape shapes):
>     **0 differences**, 9,673 of them true matches so the arms are actually exercised.
>   - **`readline`**: the three-arm `match r.read(...)` became `while let Ok(1)`, the trait-object
>     `match` for the source became `unwrap_or_else`, and only the newline keeps a branch:
>     **676 → 444 B/def**. Byte-at-a-time is deliberate — a `BufReader` reads ahead and the
>     buffered tail is lost when the reader goes back into `__SH_STDIN`; the comment says so.
>   - **`printf`**: the width, precision and flags were built as three `String`s per conversion
>     and parsed back (`width.parse()`, `flags.contains('-')`); they are now a `usize`, an `i64`
>     and two `bool`s read straight off the digit run. The `Vec<char>` of the format was also
>     rebuilt **inside** the re-use loop — hoisted. This one is **size-neutral** (5,856 → 5,869,
>     +13 B/def: the flag `match` costs a line where the old `push` cost a char) and its win is
>     per-call: no four allocations and no re-decode per conversion. Proven against the OLD body
>     over **38,330 cases** (every verb × flag set × width × precision × length modifier × 10
>     argument sets, plus escape and re-use shapes): **old == new in every case**.
>   **A rewrite needs a target the harness can measure, and the comment lesson from v131 bit again:**
>   the first version of the extglob change put a five-line explanatory comment inside the emitted
>   helper, which costs those bytes **per file** — 31 files × 480 B made the corpus 6.7 KB *larger*
>   than it started. Comments in helper text are output, not documentation; both new comments are
>   one line.
>   **My own v131 regression, found and fixed here.** Six `rust_backend` tests still pinned the
>   fully-qualified text (`std::process::exit(3)`, `std::fs::write(…)`,
>   `static __SHV_xs: std::cell::RefCell<…>`) that `shorten_std_paths` had just rewritten, so the
>   suite was 55 red where the standing baseline is 49. v131's report called those six
>   `estree::tests::*` without checking each name — a failure COUNT is not a baseline, the *named*
>   set is. The assertions now name the call without its qualifier (`process::exit(3)`), which is
>   the property they always meant; every behavioural assertion in them is unchanged.
>   **Measured. 1,304,253 → 1,297,217 B (−7,036 B, −0.54%)**, 0 rustc errors, the same 5 warnings
>   over all 563 files.
>   **Gates.** `./fail` **563/563**; `harness/fail-rs` **556 pass / 0 fail / 7 skip** (fresh,
>   `resumed=0`); `./fail-estree` **563/563 (100.0%)**; `harness/py-rust-gate.sh` **98/103**
>   (documented t104/t82/t87); `cargo test --lib` **1780 passed / 49 failed, 0 `rust_backend`** —
>   exactly the standing pre-existing set.
>   **Core worker: healthy** — supervisor alive, gate GREEN, no `core-requests/sleeping-*`.
> - v131: **The remaining fat is not in any one helper — it is the fully-qualified paths and the
>   repeated `#[allow]` that every file pays for.** After v130 the corpus census is
>   `spawn` 199 KB / `fnmatch` 100 KB / `printf` 53 KB and the rest long and thin, so the next
>   win is not a body rewrite: it is the *preamble*. A typical file said
>   `static __SH_RC: std::sync::atomic::AtomicI32 = std::sync::atomic::AtomicI32::new(0);` —
>   40 bytes of path for a type the reader already knows by name, 752 times over the corpus —
>   and repeated `#[allow(non_upper_case_globals)]` inside every `thread_local!` block (351
>   copies across 157 files). New pass `shorten_std_paths` (in [rust_backend.rs]) does what a
>   Rust programmer would: import once, write the short name, and hoist the allow to one inner
>   attribute.
>   **Two rules make it total rather than probabilistic.** TYPES (`AtomicI32`, `AtomicBool`,
>   `Mutex`, `RefCell`) are always safe, because a path in type position cannot collide with a
>   local — the type and value namespaces are separate. MODULES (`io`, `process`, `mem`, `fs`,
>   `env`, `path`, …) are imported only when the program never binds that name, since
>   `for path in …` would shadow `path::PathBuf` and stop the file compiling; the shadow check
>   gates each module rule on its own. The substitution never looks inside a string literal —
>   the runtime carries bash command text, and a program that prints Rust-looking text must come
>   out unchanged (unit-tested). It runs AFTER `prune_unused_statics` (importing a dead static's
>   type would be an unused-import warning) and before golfing.
>   **The first version had a real bug, caught by the warning census**: its early return for a
>   file with no shorten-able path stripped the per-static allows but never emitted the
>   file-level one, so `Cell<i64>`-only programs (the numeric vars) went from 5 to 8 warnings.
>   Fixed to strip first and decide the attribute from the same count; back to the 5 baseline.
>   **Measured. 1,336,347 → 1,304,253 B (−32,094 B, −2.40%)**, 0 rustc errors, the same 5
>   warnings over all 563 files.
>   **Gates.** `harness/fail-rs` **556 pass / 0 fail / 7 skip** (fresh dir, `resumed=0`);
>   `./fail` **563/563**; `harness/py-rust-gate.sh` **98/103** (documented t104/t82/t87);
>   `cargo test --lib` **1774 passed / 55 failed** — the 6 extra over the 49 baseline are
>   `estree::tests::*` `pipelineSync` pins in a peer's live edit of `estree.rs`, untouched here.
>   **Two gate readings were false alarms and worth recording.** (a) A `./fail` run reported
>   **39 `[perl]` failures**; it passed 563/563 on a clean re-run minutes later, because `fail`
>   rebuilds the CLI itself and caught the tree mid-edit — a peer's `str-temp-inline` /
>   `interp-fold-late` work was landing in `transforms.rs` while that run started. (b) py-rust
>   reported 5 FAIL once with `E0514/E0460 num_bigint/num_traits` errors on t89/t90; both cases
>   pass alone and the full run returned to the documented trio, i.e. the shared `target/deps`
>   holds rlibs from several toolchains and a concurrent rebuild makes the pick race. Neither is
>   a code regression, and neither is fixed by weakening a gate.
>   **Core worker: healthy** — supervisor alive, gate GREEN 10:57, no `core-requests/sleeping-*`
>   markers.
> - v130: **The biggest helper carried a stdin channel most programs cannot reach — and the
>   verdict that proves it is an IR question, so it is shared.** `__sh_spawn` is the largest
>   body in the corpus (234 KB over 198 files, 1,182 B each), and its first seven lines convert
>   an `Option<&[u8]>` into a `Vec<u8>` and drain `__SH_STDIN` into it. Only two things can ever
>   supply that buffer: a **pipeline** (the staged bytes are handed to the last stage) and a
>   **heredoc/herestring**. A program with neither passes `None` at every call site and the
>   child simply inherits the parent's fd 0 — so the whole path is unreachable, not merely
>   unused. New shared verdict `shir::program_feeds_shell_input`, and the third `spawn` variant
>   `spawn_noinput` (`fn __sh_spawn(cmd: &str) -> i32`) chosen by it, with `run`/`run_traps`
>   following the same arity.
>   **The corpus differential is what caught both bugs.** The first version scanned the IR for
>   `Pipeline` and emitted a 1-arg helper beside a 2-arg `Some(…)` call in **84 files**, because
>   a pipeline reaches the renderer as EITHER node form — `IrStmt::Pipeline` *or* the
>   ESTree-lowered `Call { func: "pipeline" }` whose stages are exprs. Adding that form dropped
>   the violations to **33**, all `tty-cmdsub`: a plain `cmd < file` does not pass a buffer at
>   any call site but points `__SH_STDIN` at the file around the inner command, and a shell-out
>   from inside it inherits that — so `mode: "r"` is LIVE input, not an over-approximation, and
>   the verdict had to admit it. `fail-rs` reproduced the same case independently (`FAIL-equiv
>   tty-cmdsub`, 555/1) before the fix and did not after.
>   **Measured. 1,377,530 → 1,336,347 B (−41,183 B, −2.99%)**; `__sh_spawn` 234,173 → 199,259 B
>   (−15%); helpers 51.7% → 50.7% of the corpus; **66 files** take the input-free variant.
>   0 rustc errors and the same 5 warnings over all 563 files.
>   **Gates.** `./fail` **563/563**; `harness/fail-rs` **556 pass / 0 fail / 7 skip** fresh
>   (`resumed=0`); `./fail-estree` **563/563 (100.0%)**; `harness/py-rust-gate.sh` **98/103**
>   (documented t104/t82/t87); `cargo test --lib` **1780 passed / 49 failed, 0 `rust_backend`
>   failures** (+1 = the new verdict test; the 49 are the pre-existing reds, e.g. the
>   `shir::range_analysis_tests` fixpoint assertions).
>   **The py-rust gate was reporting a phantom failure and is now honest.** `t101` failed with
>   `E0514 incompatible version of rustc` / `E0460 newer version of num_traits`: `target/*/deps`
>   is shared with every backend worktree on this box, so it holds `num_bigint`/`num_traits`
>   rlibs from several toolchains and `ls -t | head -1` was picking one the gate's own `rustup
>   run 1.90` refuses. The gate now probes candidates newest-first **with that same toolchain**
>   (a `size_of::<BigInt>` metadata compile) and takes the first it accepts; still a hard error
>   when none works, so nothing is skipped silently.
>   **Core worker: healthy** — supervisor alive, gate GREEN 10:39, no `core-requests/sleeping-*`
>   markers.
> - v129: **The pattern matcher was 117 lines of hand-rolled recursion, and it is 10% of the corpus.**
>   The census after v128: helpers are still 54.8% of the emitted bytes, and `__sh_fnmatch`
>   is the biggest body per file — **5,008 B across 31 files (155 KB, 10.8% of the
>   corpus)** — because anything touching `[[ x == pat ]]`, `case`, `${v#pat}` or a glob
>   drags it in. It carried the same duplicated shapes a hand-written matcher always
>   does:
>   - `'*'` as `for i in 0..=t.len() { if m(…) { return true; } } false` →
>     `(0..=t.len()).any(|i| m(&p[1..], &t[i..]))`;
>   - the **extglob** block (90 lines) duplicated "clone the alternative, append the
>     pattern's remainder, recurse" in its `@` and `?` arms and duplicated the
>     1..=len double loop in `*` and `+`. One `then_rest` closure plus three `.any()`
>     chains now cover `@`/`+`/`!` in 35 lines. The `*(…)` and `?(…)` arms the guard
>     used to admit were UNREACHABLE — the `'*'` and `'?'` arms precede the guard —
>     so the narrower `'@' | '+' | '!'` guard is behaviour-preserving, and the comment
>     says so rather than pretending the matcher handles those forms.
>   - `'['` lost its `if t.is_empty() { return false; }` prologue to a
>     `let Some(&t0) = t.first() else { return false }`, and its tail became
>     `matched != neg && m(…)`.
>   **A delicate rewrite needs a real proof, not a corpus run.** There was no unit test
>   pinning the matcher's semantics, so before swapping it in I built a differential
>   harness: extract the current body from the renderer source, rename it, add the new
>   body, and compare on **every pattern up to length 4 over the 17-char alphabet
>   `a b * ? [ ] ! ( ) | @ + - ^ \\ .` × 12 subjects**, plus 24 hand-picked
>   extglob/class/escape patterns (`!(*.min).js`, `@(a|b)@(c|d)`, `+(ab|a)`, `[]a]x`,
>   `[!-a]`, `*\\**`, …): **839,148 pairs, 0 differences.** Both variants compile under
>   `rustc -O` before the comparison, so it is an executed equivalence, not a reading.
>   Two smaller std-idiom wins in the same sweep: `__sh_print_words` joined its words
>   with `iter().flatten().map(|x| x.as_str()).collect::<Vec<_>>().join(" ")` — a Vec the
>   only consumer throws away — now `ws.concat().join(" ")` (102 files); and
>   `__sh_printf`'s six-line manual padding became a three-arm `format!` on the field
>   width (`{piece:<w$}` / `{piece:0>w$}` / `{piece:>w$}`), which is the same operation
>   `Formatter::pad` performs — and it measures width in CHARS for `&str`, exactly like
>   the `chars().count()` the manual version used.
>   **Measured. 1,437,622 → 1,378,144 B (−59,478 B, −4.14%)** and
>   **31,297 → 29,911 lines (−1,386, −4.4%)**; `__sh_fnmatch` 5,008 → 3,235 B/def; same
>   5 rustc warnings, 0 errors over all 563 files.
>   **Gates.** `./fail` **563/563**; `harness/fail-rs` **556 pass / 0 fail / 7 skip** on a
>   fresh verdict dir (`resumed=0`) — including `010_pattern_matching` and
>   `037_pattern_matching_extglob`, the two examples that exercise the refactored arms;
>   `./fail-estree` **563/563 (100.0%)**; `harness/py-rust-gate.sh` **98/103** (the same
>   documented t104/t82/t87 trio); `cargo test --lib` **1779 passed / 49 failed, 0
>   `rust_backend` failures**.
>   **Core worker: healthy** — gate GREEN 09:36, no `core-requests/sleeping-*` markers.
> - v128: **The casts are gone; the hand-written loops in the runtime helpers were not.**
>   The census first: casts are essentially exhausted (`as i64` 91, `as usize` 124,
>   `as i32` 24, `as u32` 1, and **0** `as f64`/`as u64`/`as char` across 563 files), so
>   the remaining fat is where it has been all along — helpers are **56% of the emitted
>   bytes** (854 KB of 1,525 KB), and a helper body is emitted once *per file*, so one
>   sloppy line there costs hundreds of copies. What the bodies still carried was a
>   hand-rolled loop for an operation std already spells:
>   - **`__sh_q`** (96 files, 223 B) — a `String::with_capacity` + per-char push loop
>     for shell-quoting, i.e. `format!("'{}'", s.replace('\'', "'\\''"))`. **161 B**.
>   - **`__sh_wq`** (70 files, 190 B) — an `enumerate` loop joining with a leading-space
>     guard, i.e. `map(|w| __sh_q(w)).collect::<Vec<_>>().join(" ")`. **102 B**.
>   - **trailing-newline strip** (`__sh_capture_rc`, `__sh_cap_end`; 185 defs) —
>     `into_owned()` then `while s.ends_with('\n') { s.pop(); }` (3 lines, 2 allocations)
>     became `String::from_utf8_lossy(…).trim_end_matches('\n').to_string()`.
>   - **`__sh_capture_rc`** — a 4-line `Command` setup became one builder chain
>     (`c.args(["-c", cmd]).stdout(…).stdin(…)`), and
>     `wait().map(|s| s.code().unwrap_or(1)).unwrap_or(1)` became
>     `wait().ok().and_then(|s| s.code()).unwrap_or(1)` (no nested `unwrap_or`).
>   - **`__sh_spawn`** (198 defs) — the stdin takeover's `map` + `if is_none` + `if let`
>     (8 lines) became `map(…).or_else(|| { …take()? … })` (6, and no `mut`); the
>     fd-1 flush became one line with a one-line *why*; the six-line sink `if/else`
>     became a `match` over `__SH_OUT`; `arg("-c").arg(cmd)` became `args(["-c", cmd])`.
>   - **comment bloat in every emitted file**: `__sh_print_words` opened with 4 lines
>     explaining *that this program has no `-e`* (a fact of the code below it) and
>     another 3 explaining the arith-fail flag; `__sh_puts` carried 4 lines. Compressed
>     to one line each — the long form already lives in the renderer source, which is
>     where a reader of the RENDERER looks.
>   **The one breakage the tests caught, and why it matters.** `inline_spawn_sinks_when_unused`
>   slims the `__sh_spawn` body for a program that never writes a sink, and it does so by
>   matching THREE exact text constants against the rendered helper. Editing the helper's
>   body silently stopped it firing (a *sink-free program kept the full 34-line body*);
>   `a_capturing_program_keeps_its_sink_halves` failed with "sink-free spawn not slimmed",
>   which is exactly what that test is for. The constants now match the new text, and the
>   lost slim is worth **52 KB** — the largest single effect of the round.
>   **Measured, two stages.** After the body rewrites: 1,525,317 → 1,490,972 B. After
>   restoring the slim pass: **1,437,622 B, 31,297 lines** — i.e.
>   **−87,695 B (−5.75%)** and **−3,357 lines (−9.7%)** on the round, with the same
>   5 rustc warnings and 0 errors over all 563 files. Per def: `__sh_q` 223→161 B,
>   `__sh_wq` 190→102, `__sh_print_words` 744→559, `__sh_capture_rc` 609→541,
>   `__sh_cap_end` 292→254; a sink-free `__sh_spawn` is now 16 lines with no
>   `want_out`/`used` machinery at all.
>   **Gates.** `./fail` **563/563**; `harness/fail-rs` **556 pass / 0 fail / 7 skip** on a
>   fresh verdict dir (`resumed=0`, every example re-rendered, compiled and compared);
>   `./fail-estree` **563/563 (100.0%)**; `harness/py-rust-gate.sh` **98/103** — the same
>   documented t104/t82/t87 trio, unchanged by the helper rewrites; `cargo test --lib`
>   **1779 passed / 49 failed with ZERO `rust_backend` failures** (all 108 `rust_backend`
>   tests pass; the red set is the pre-existing class: estree 23, c_backend 10, shir 5,
>   fish 5, …).
>   **Core worker: healthy** — gate GREEN 08:16, no `core-requests/sleeping-*` markers.
>   **Where this leaves the shared layer:** this pass is Rust-syntax-specific (std
>   idioms), so it does not move the shIR contract. The shared item it exposes is the
>   *variant verdict*: which runtime capabilities a program actually needs is currently
>   re-derived per backend, and the corpus now shows how much that costs (198 files pay
>   for a full `__sh_spawn`; 33 of them never pass an input buffer at all).
> - v127: **A constant command was formatted at run time by a nest of `format!`.**
>   The aggregate census had nothing left (every class it can see was already
>   mined, and four more candidates measured to ~0 this round: deduping the three
>   `bash -c` helpers — only 59 of 563 files carry two of them; numeric homing;
>   pbuf dead-init — **1 of 209** declarations is immediately overwritten, the rest
>   genuinely accumulate; single-shell-out captures → `__sh_cap_bytes` — **14 of
>   278** blocks). Reading ONE emitted file end-to-end found it instead: command text
>   is assembled by *joining rendered Rust expressions*, so a pipeline whose every
>   stage is a constant was emitted as a nested `format!` chain formatting a fixed
>   string on every call —
>   `__sh_spawn(&format!("{} | {}", format!("({}; {})", "'echo' 'one'", …), …))`.
>   Two layers fix it. (1) **`Render::wrap_join`** replaces the three ad-hoc joins
>   (pipeline run, subshell, `&&`/`||`) with one helper taking prefix/sep/suffix,
>   which folds at GENERATION time when its operands are already literals — the
>   backend-agnostic half: it is the join that knows whether a constant exists, and
>   the same shape applies to any backend that assembles command text from pieces.
>   (2) **`fold_const_format`**, a textual peephole after the shell-quote folding
>   (the pass that turns `__sh_wq(…)` into literals — which is why the fold cannot
>   live in the join: at generation the operands are still expressions). It folds
>   `&format!(all-literal)` bottom-up through `format!`-argument nests, accepts
>   `"lit".to_string()` as a literal argument (the shape the quote fold leaves), and
>   scans INSIDE a bare call rather than copying it, so `__sh_q(&format!(…))` folds
>   too. Soundness is positional, not clever: only where `&str` is still accepted
>   (the `&format!` borrow, or an argument of another `format!`, where `Display` for
>   `&str` and `String` are identical). A `String` sink keeps its call; a spec
>   (`{:?}`), a named argument or a hole/argument count mismatch refuses the whole
>   call. **Measured. 1,527,661 → 1,525,317 B (−2,344 B)**; lines unchanged
>   (34,654 — the joins were inline); `format!` call sites in the corpus
>   **569 → 495** (74 run-time formattings of constants gone), 70 of the 73
>   constant `&format!` sites folded; same 5 rustc warnings, 0 errors. Also removed
>   a dead `BTreeSet` in `function_reachable_vars` (dead `let mut`, 2 compiler
>   warnings in the transpiler itself).
>   **Tests.** `const_format_peephole_folds_a_constant_command` pins the fold, the
>   `{{`/`}}` escapes, a brace in an ARGUMENT (data, not a hole) and five refusals;
>   `a_constant_pipeline_renders_one_command_literal` pins the end-to-end shape.
>   **Gates.** `./fail` **563/563**; `harness/fail-rs` **556 pass / 0 fail / 7 skip**
>   on a FRESH verdict dir (`resumed=0`, so every example was re-rendered by this
>   build); `./fail-estree` **563/563 (100.0%)**; `harness/py-rust-gate.sh` **98/103**
>   — the same documented t104/t82/t87 trio, unchanged; `cargo test --lib`
>   **1778 passed / 49 failed**, **zero `rust_backend` failures** (the red set is the
>   same pre-existing pin class: estree 23, c_backend 10, shir 5, fish 5, …), and both
>   new tests pass. **Core worker: healthy** — gate GREEN 06:47, next iteration 06:57,
>   no `core-requests/sleeping-*` markers.
>   **Two operational notes, both non-regressions.** (a) Two gate runs died on an
>   in-progress `c_backend.rs` edit from the shared-checkout C worker (`E0425` at
>   `c_backend.rs:30864`, file mtime inside the run) — the tree must be quiescent.
>   (b) `./fail-estree` reported ONE failure (`chown-through-xargs.sh`) twice while
>   `cargo test` and a 563-program `fail-rs` ran on the same box (load ~10); the
>   gate's per-test budget is 20 s and the isolated emit takes **0.01 s**, and a
>   re-run on the quieter box is 563/563. A timeout under contention, not a render.
> - v126: **Three dead ends found by measurement, then two cheap structural wins.**
>   The helpers turned out to be 56% of the emitted bytes, so the round started
>   there and measured each candidate before writing code:
>   (a) **Precompiling literal globs is worthless here.** `__sh_fnmatch` is 117 lines
>   across 31 files (15.9% of helper bytes) and looks like the obvious target, but of
>   its 95 call sites only 42 have a literal pattern and **29 of those carry a char
>   class, extglob, `?` or an escape** (`*\$\{…\}*`, `!(*.min).js`, `[a-z]*`). Files
>   that could drop the helper entirely if simple patterns were inlined: **0**. The
>   `simple_glob_test` inlining that already exists (plain / `lit*` / `*lit`) is the
>   whole of what this corpus rewards.
>   (b) **Status stores are not a well either.** 1,019 literal `__SH_RC.store(N, …)`
>   statements exist, but 993 of them sit in programs that DO read the register
>   (`$?`, `exit`), where the write is exactly what buys exit-code equality. Only
>   **59** sit in a program whose register is never read at all.
>   (c) **The var-read clones are already scoped.** 419 `X.with(|v| v.borrow().clone())`
>   remain, but just 30 are immediately followed by a method; the common
>   `…clone()).trim().parse::<i64>()` shape is already rendered inside the borrow
>   (`v.borrow().trim()…`), so v124's trick has nothing left to take.
>   **The two wins that were left in the same area:**
>   (1) `#[allow(non_upper_case_globals)]` on `fn main()`. The lint applies to
>   `static`/`const` items — a `fn` is never one — and user-var statics carry their own
>   attribute at module level. A previous round removed it from the *no-user-var*
>   path (its test still guards that) and the `seen_var` path kept emitting it, so 141
>   files began with a suppression that could not fire. Removed; corpus lint confirms
>   the same 5 warnings / 0 errors with it gone.
>   (2) A literal status write as the LAST statement of `main` is unobservable: this
>   renderer derives the exit code only from `std::process::exit(…)` (emitted where the
>   SOURCE exits), so falling off the end of `main` exits 0 whatever the register
>   holds and no `.load` can follow. 146 such stores → 4. The 4 survivors are exactly
>   the programs with a live background thread (`__SH_BGTHREADS.lock()` /
>   `thread::spawn`), whose closure could still read the register after main's last
>   statement — a race this pass may not take part in. Only a LITERAL argument is
>   dropped; a call form (`__sh_spawn(…)`) carries the command's side effects.
>   **Measured.** **1,537,794 → 1,527,661 B (−10,133 B, −0.66%)** and
>   **34,932 → 34,654 lines (−278)**; same 5 rustc warnings, 0 errors across 563 files.
>   **Tests.** `trailing_literal_status_store_is_dropped` pins both directions (guard
>   on `exit`/background), and `no_user_var_drops_the_allow_attribute` already covered
>   the attribute's other path.
>   **Gates.** `./fail` 563/563 passed; `harness/fail-rs` 556 pass / 0 fail / 7 skip;
>   `./fail-estree` 563/563; `harness/py-rust-gate.sh` 98/103 (the documented
>   t104/t82/t87 trio — re-verified this round as frontend feature gaps, not renderer
>   bugs: t104 shows `TODO(unsupported): word call pyFloat` and prints nothing).
>   `cargo test --lib` 1776 passed / 49 failed, **zero `rust_backend` failures**
>   (142 rust_backend tests pass); the red set is the same pre-existing pin class.
> - v125: **The fd-1 FILE sink was paid for by 545 programs that can never open one.**
>   `__SH_OUTFILE_TL` is the cell a native `> file` redirect fills so prints go to
>   the file instead of stdout. The census: **1063 references and 128 declarations
>   across the corpus, but only 18 of 563 files ever assign `Some(…)` to it.** In the
>   other 545 the cell is `None` for the whole run, so everything built around it is
>   dead: the `let mut used = false;` / `__SH_OUTFILE_TL.with(… used = true)` /
>   `if used { return; }` triple (262 sites), its `if !used { … }` twin (113 — the
>   body always runs, so the wrapper is UNWRAPPED, not emptied), the pipeline
>   stage's `let __sh_oldoutN = …take()` / `…= __sh_oldoutN` pair (143), the false
>   half of `want_out` (113), and the FILE element of the general-capture tuple
>   `__ShCap` (91 pairs of save/restore + the type, which is why 77 files still
>   declared the cell after the first pass).
>   **The gate is exact, not a heuristic.** `strip_dead_file_sink` reuses
>   `text_writes_file_sink` — the SAME predicate the redirect renderer's own
>   backstop uses — and it matches the one line that ever assigns `Some(…)` to the
>   cell. A program with a `> file` redirect (or a closed-fd/stderr null dup, which
>   assigns /dev/null) is left completely alone; **all 18 such files are
>   byte-identical after the pass**, which is the strongest statement the shape of
>   this change allows. Everything stripped is then invisible to
>   `prune_unused_statics`, so the `thread_local!` declaration goes with the last
>   reference (128 → 18).
>   **Measured.** **1,628,975 → 1,537,794 B (−91,181 B, −5.60%)** and
>   **36,090 → 34,932 lines (−1,158)**, same 5 rustc warnings, **0 errors** across 563
>   files. References 1063 → 251 and declarations 128 → 18, i.e. exactly the 18 that
>   can use them. **Tests.** `dead_file_sink_apparatus_is_stripped` (both shapes,
>   including a brace-balance assertion on the unwrap), `dead_file_sink_capture_slot_is_dropped`
>   (the tuple narrows but stdin and the byte buffer still round-trip), and
>   `a_live_file_sink_is_untouched` (the negative that matters).
>   **Gates.** `./fail` 563/563 passed; `harness/fail-rs` 556 pass / 0 fail / 7 skip;
>   `./fail-estree` 563/563; `harness/py-rust-gate.sh` 98/103 (the documented
>   t104/t82/t87 trio). `cargo test --lib` 1776 passed / 48 failed — the same
>   pre-existing red set (estree 23, c_backend 9, shir 5, fish 5, zsh 2, shir_json_in
>   2, zig 1, go 1), **zero `rust_backend` failures**, 141 rust_backend tests pass.
>   **Next, sized.** What is left of the cell after this is only the 18 sink files, so
>   this well is dry. The larger remaining class is the same shape one level up: the
>   *capture* buffer `__SH_OUT` + `__SH_STDIN` pair is saved/restored per capture in
>   every program, and a program with no capture at all still carries
>   `cap_begin`/`cap_end`; gating that on a program-level "has a capture" verdict is
>   the same mechanical pass (it would first need `prune_unused_helpers` to be able to
>   drop a helper whose only caller is another helper).
> - v124: **The “unused `-> String`” lead was wrong, and the printer had three real warts.**
>   v123 left (b) as the next big shared-verdict opportunity: “439 functions render
>   `-> String`, most call sites discard the value”. A probe (a temporary test, removed
>   again) prints `fn_value_used` for `f(){ echo a; }; f` and for `x=$(f)`: both return
>   `{"f"}`, and the emitted call is `println!("{}", f())` — because in this model a
>   function's OUTPUT **is** its return value, so a statement-position call PRINTS it.
>   The verdict is right and the premise was wrong. NEGATIVE result, recorded so nobody
>   re-chases it. The `__SH_RET` cell looked like the follow-up (corpus: 34 stores, 20
>   statics, **0 reads** — write-only), but it is a 34-line well that needs a
>   whole-program read predicate across three read sites; not worth it at this size.
>   **What was left was the printer.** Three cheap, measurable warts, all in the
>   render-time passes (`inline_format_args`, plus one new line pass):
>   (1) an `else` arm emptied by status stripping — `} else {` / `}` with nothing
>   between, 62 blocks in 53 files — is now folded back into its `if`
>   (`drop_empty_else_arms`); the arm only ever existed to carry
>   `__SH_RC.store(0, …)`, which the shared liveness had already proved unread.
>   (2) Inline format capture required the format string to be EXACTLY `"{}"`, so every
>   labelled print kept a separate argument: `println!("stdout: {}", so.clone())` →
>   `println!("stdout: {so}")`. 76 sites → 0. A single-`{}` template now captures, and
>   the argument's `.clone()` goes with it (`{}` formats by reference).
>   (3) A variable read is `X.with(|v| v.borrow().clone())`; dropping just the `.clone()`
>   does NOT compile (a `Ref` borrows the closure's `&T` and cannot escape `with` — that
>   is WHY the clone is there), so the print moves INSIDE the borrow instead:
>   `__SHV_a.with(|v| println!("{}", v.borrow()))`. 54 sites, 54 whole-String copies
>   gone from every run; the 25 left have block-shaped arguments.
>   **Measured.** 1,632,649 → 1,628,975 B, 36,152 → 36,090 lines, same 5 rustc warnings,
>   **0 errors** across 563 files. (Byte totals are round-over-round in a SHARED checkout,
>   so other workers' changes are in them too; the class counts above are the attributable
>   part — each was counted by shape before and after.) **Tests.** `empty_else_arm_is_folded_away`,
>   `inline_format_argument_inside_a_template` (both directions, incl. `{{ }}` and
>   two-placeholder negatives), `display_argument_prints_inside_the_borrow` (with the
>   not-a-bare-home and outside-a-print negatives). One existing test updated rather
>   than deleted: `assigns_and_echo` pinned the OLD `println!("x is {}", x)` shape, so it
>   now pins the better `println!("x is {x}")` and asserts the separate argument is gone.
>   **Gates.** `./fail` 563/563 passed; `harness/fail-rs` 556 pass / 0 fail / 7 skip;
>   `./fail-estree` 563/563; `harness/py-rust-gate.sh` 98/103 (the documented t104/t82/t87
>   trio). `cargo test --lib` 1773 passed / 48 failed with **zero `rust_backend`
>   failures** — the red set is the pre-existing estree/fish/zsh/go/zig pin class, and its
>   exact count drifts because this is a shared checkout other workers are editing.
>   Core worker healthy throughout (gate GREEN 04:21, A1-native 0 violations / 555 probed,
>   no sleep markers). One box-health observation: `loop-core-worker.log` is now **675 MB**
>   — worth a rotation if the worker's own logging is not bound.
> - v123: **A shared verdict that nobody consumed.**
>   The round started at the `$?` status registers (1,139 `store(0, …)` lines) and
>   found them mostly *justified*: the rust binary's process exit code IS the register,
>   so the existing rule (“keep a write that can reach program end”) is what buys
>   exit-code equality with bash, and `rc_zero`/`body_rc_is_zero` already drop the ones
>   that provably cannot. Only 134 stores sit in the 71 files that write status and
>   never load it — a 5 KB well, and the fix would need `$?` liveness inside function
>   bodies. Recorded as a NEGATIVE result so the next round does not re-chase it.
>   **The find.** `shir::program_observes_pipestatus` — a shared verdict, with its own
>   tests, written to answer exactly this — had **no renderer consumer at all**. The
>   Rust pipeline emitters registered `$PIPESTATUS` unconditionally: a `clear()` per
>   pipeline plus a `lock()/push()` per stage, plus the `static`, for every program,
>   whether or not it can ever expand `$PIPESTATUS`. The verdict now gates all three
>   sites (the joined-shell-stage path, the per-stage path, and the native-stage path)
>   and the `static` is pruned by the usual name scan. A read still keeps everything;
>   the last stage's status still reaches `__SH_RC` either way.
>   **Measured.** **1,676,807 → 1,632,649 B, −44,158 B (−2.63%)**, 92 files, same 5
>   rustc warnings, 0 errors. The diff is EXACTLY: 530 PIPESTATUS lines, 92 statics,
>   81 blank lines, and 58 `__SH_RC.store(0, …)` lines that become provably dead once
>   the `push`'s `__SH_RC.load` is gone (the existing `rc_zero` rule then fires). No
>   line was added except blanks.
>   **Tests.** `pipestatus_tracking_follows_the_shared_verdict` pins both directions —
>   no `$PIPESTATUS` read ⇒ no static, no `clear`, no `push`; a read ⇒ all three.
>   **Gates.** `./fail` 563/563; `fail-go` 126/126; `harness/fail-rs` 556 pass / 0 fail /
>   7 skip; `./fail-estree` 563/563 Perl and 563/563 ESTree; `harness/py-rust-gate.sh`
>   98/103 (the t104/t82/t87 trio). `cargo test --lib` 1771 passed / 47 failed — the
>   baseline set, no `rust_backend` failure. One transient worth recording: a first
>   `fail-estree` run reported “Build failed” because a `\$` escape in the new test's
>   assertion message was in the tree at the time; corrected and re-run clean (an
>   unrelated concurrent `cargo build` from another worker reproduces the same
>   compile-failure shape, so always read the error, not just the verdict).
>   **Next candidates, sized.** (a) The intermediate-native-pipeline-stage capture
>   still hand-rolls 4 lines of OUTFILE/OUT save-restore at 51 sites, but a helper for
>   it costs ~700 B/file against ~120 B/site, so it is NOT worth it at this corpus
>   size. (b) 439 functions render `-> String` in 236 files, and most call sites
>   discard the value: deriving “return value unused everywhere” would let the
>   signature drop the return, `__SH_RET` and the `__sh_ret_rc` store — the largest
>   remaining shared-verdict opportunity, and the one that needs renderer work in
>   three places (signature, returns, call sites).
> - v122: **The fold was never the bottleneck — the visitor was.**
>   Starting from v121's question (“why do only 3 of 563 examples fold a constant
>   capture?”), the census answered it two ways. First, the well really is dry:
>   of **261 captures** in the corpus, **223 bodies contain no variable read at all**
>   — they are literal external commands (`$(mktemp -d)`, `$(sha256sum f)`) whose
>   value exists only at runtime — and of the 34 that do read a variable, **none** is
>   a single-def literal. Second, and the real find: `const-capture-fold`'s visitor
>   stopped after eight statement kinds, so a `$(…)` inside a shell **FUNCTION** —
>   where real scripts keep most of them — was never even considered — and the same
>   went for `case`, `pipeline`, `redirect`, `subshell`, `background`, `try`,
>   `do-while`, `for-init`, `select`, `declare-array`, `die`/`warn`/`return`/`exit`.
>   Missing an arm is never a correctness bug, only a fold that silently never
>   happens, which is why it survived so long. The visitor now covers every
>   expression-carrying statement, and `every_capture_position_is_visited` walks a
>   capture through all thirteen containers so the set cannot silently shrink again.
>   **Also new: path ops as constants.** `$(basename …)` / `$(dirname …)` of a
>   literal are pure functions, so the capture folds
>   (`x=$(basename /a/b/c.txt)` → `let x = "c.txt".to_string();`, no spawn, no
>   `__sh_capture_rc`, no `__sh_q` of the argv). The GNU evaluators already existed
>   privately in `copy-propagation` for the literal `${v%%*/}` spelling; they are now
>   `ir::gnu_basename` / `ir::gnu_dirname`, shared by both folds so the two cannot
>   drift. Refusals keep bash's grammar: a usage-error arg count (basename 0 or 3+,
>   dirname ≠1) writes to stderr and exits 1, and a `-`-word may be an option
>   (`basename -s .txt f`) — all refused.
>   **Measured.** **1,687,866 → 1,676,807 B, −11,059 B (−0.66%)**, 5 files changed,
>   same 5 rustc warnings, 0 errors. All five are whole-program collapses:
>   `parse_bare_quote_in_function` (−3,287 B, a capture inside a function),
>   `test_double_bracket`, `test_expr_backtick`, `parse_command_subst_in_test`,
>   `test_bracket_command_sub` — e.g. `test_expr_backtick` becomes three lines of
>   `let __sh2_tc0_ = "hello"; if … == "hello" { print!("match\n") }`.
>   **Tests.** 3 new in `const_capture_fold` (12-case basename/dirname table pinned
>   against bash, the 6-case refusal table, the 13-container visitor walk); 16 pass.
>   One existing test needed a better FIXTURE, not a weaker assertion:
>   `temporary_boundings_stay_owned` used `a=$(echo "$v")` with a literal `v`, which
>   v121+v122 now fold away entirely — it uses an external `$(cat …)` so the capture
>   really reaches the renderer, and still asserts an owned binding.
>   **Gates.** `./fail` 563/563 (the equivalence oracle for the five collapses);
>   `fail-go` **126/126** (the two mismatches reported last round were oracle
>   timeouts — they are gone on a quiet box); `harness/fail-rs` 556 pass / 0 fail / 7
>   skip; `./fail-estree` 563/563 Perl and 563/563 ESTree; `harness/py-rust-gate.sh`
>   98/103 (the t104/t82/t87 trio). `cargo test --lib` 1770 passed / 47 failed — the
>   baseline set, with **no failures in any module this round touched**.
>   **Next candidate, with the evidence.** 59 `else { }` blocks remain in the corpus.
>   They are not empty in the IR: the `else` carries the status store for a `:` no-op
>   (`if …; then echo a; else :; fi` → `else { __SH_RC.store(0, …); }`). Dropping them
>   needs `$?` liveness, which is the same analysis the 1,124 status stores want — a
>   round in its own right, not a renderer tweak.
> - v121: **A one-line conservative refusal was costing every backend whole programs.**
>   `copy-propagation` refused to fold anything inside a `Capture { expr }`
>   (“a capture may run before the def”), so with `x="abc"` the body of
>   `$(echo "$x")` reached every renderer as `getVar("x")` — an opaque read, even
>   though the analysis had already proved `x` is written exactly once, at the TOP
>   LEVEL, with a literal. The refusal is not needed: a capture body is a subshell
>   that runs AT the position the capture occupies, so the same def-before-read
>   ordering that governs the enclosing statement list governs its body — the
>   `foldable` set handed down only ever contains vars whose def is in an EARLIER
>   top-level statement, and `collect_defs` counts writes in nested bodies, builtin
>   stores (`unset`/`read`), `eval`/`source` and index writes, so nothing inside the
>   subshell can have changed the value. The `Capture` arm now descends.
>   **Why it is worth more than the byte count.** The fold is what UNBLOCKS the
>   capture folds: once the body's read is a literal, `const-capture-fold` and the
>   helper prune can delete the capture, its runtime and often the whole program.
>   Two corpus examples collapsed outright — `zz_probe_edge` went from 51 lines of
>   statics, thread-locals and capture plumbing to a single `print!` of a literal,
>   and `parse_heredoc_dollar_paren` from 3,440 B to 76 B (`let result =
>   "home/user/script"; println!("{result}")`; that example has since been removed
>   from the corpus by a concurrent worker). Corpus total **1,695,008 → 1,687,866 B,
>   −7,142 B (−0.42%)**, same 5 rustc warnings, 0 errors — the modest total is
>   because only 3 of 563 examples contain a foldable read inside a capture, while
>   the payoff where it does fire is a whole runtime.
>   **The generalisation, and the refusal kept.** A statement `( … )` subshell is
>   the same synchronous copy-env construct, so `IrStmt::Subshell` now descends too.
>   It is **corpus-neutral** — re-emitting all 563 files gives 0 differing bytes with
>   and without the arm — so it is pinned by unit tests only, not by the byte
>   metric. `Background` (`… &`) stays refused: the fold would be sound under the
>   same rule, but that argument leans on the scheduler and nothing in the corpus
>   needs it.
>   **Tests.** Five new in-file tests: the fold inside a capture, the fold inside a
>   statement subshell, and the three that must still refuse (read before the def,
>   a second write inside the body, any background job). `copy_propagation` module:
>   55 passed.
>   **Gates.** `./fail` 563/563; `harness/fail-rs` 556 pass / 0 fail / 7 skip;
>   `./fail-estree` 563/563 Perl and 563/563 ESTree; `harness/py-rust-gate.sh`
>   98/103 (the t104/t82/t87 trio). `fail-go` reports 110/126 with two mismatches
>   (`t04_print_var`, `t08_comment`) whose ORACLE timed out (`oracle_rc=124`); both
>   emit **byte-identically with `copy-propagation` disabled** in `SH2_TRANSFORMS`,
>   so they are not this change. The Core worker was healthy throughout (gate GREEN,
>   no sleep markers).
> - v120: **The census moves from warnings to structure: rustc is out of findings, so the
>   next class came from counting lines, and it was a fixed-cost one.**
>   `rustc --emit=metadata` over all 563 emitted files now yields **5 warnings total**
>   (`FilesystemOptions` non-snake-case, two “value assigned is never read”, two unused
>   vars) — the warning well is dry, so this round ranked classes by byte volume instead:
>   **61% of the emitted corpus is prelude** (1.06 MB of 1.72 MB), 50% of the whole
>   corpus is helper bodies (`__sh_spawn` 288 KB/198 files, `__sh_fnmatch` 152 KB at 5 KB
>   a file), and in the *program bodies* the dominant repeated block was the general
>   `$(…)` capture wrapper: **202 sites × 9 lines** of thread-local and atomic
>   save/restore spelled out at every site.
>   **The change.** The three capture sinks (the fd-1 redirect file, the output buffer,
>   the stage's stdin) are now saved and restored by one helper pair —
>   `let __cap_st = __sh_cap_begin(); … __sh_cap_end(__cap_st)` — with the state typed by
>   a `__ShCap` alias. The rules that make it correct (one lock acquisition per cell so a
>   background thread's write cannot interleave; stdin detached so a nested command
>   cannot eat the stage's buffer) stay in the renderer as Rust comments; the emitted
>   helper carries only what a reader of the generated file needs. Six lines → one call
>   at every site, and the begin/end pairing sits in the same position the inline
>   restore did, so an early `return` in the body skips it exactly as before.
>   **The canary, and the version that lost.** The first shape (two full-size helpers
>   with their explanatory comments) came out **+32,860 B**: the helper is a FIXED cost
>   paid by all 98 files, while most files have only ~2 capture sites, so 104 KB of
>   helper text beat 71 KB of removed lines. Adding the `__ShCap` alias and moving the
>   design notes into the renderer cut the fixed cost enough to flip the sign: **
>   1,719,184 → 1,695,008 B, −24,176 B (−1.4%), 98 files, same 5 warnings, 0 rustc
>   errors.** The diff is EXACTLY the nine removed lines × 202 sites plus the two helper
>   definitions — verified line by line, not by spot check.
>   **Gates.** `./fail` 563/563; `harness/fail-rs` 556 pass / 0 fail / 7 skip;
>   `./fail-estree` 563/563 Perl and 563/563 ESTree; `harness/py-rust-gate.sh` 98/103
>   (t104/t82/t87, the documented trio). `cargo test --lib` 1762 passed / 47 failed with
>   **no `rust_backend` test among the failures**; the one extra red against the 46
>   baseline is in `c_backend` tests, and `src/c_backend.rs` was modified by the C worker
>   seven minutes before the run — this change is Rust-renderer-only. Two gate runs
>   reported t89/t90/t91 as rustc failures (“num_bigint compiled by an incompatible
>   version of rustc”); that was a concurrent `cargo build` in the shared target dir
>   rewriting the rlibs mid-run, and they pass again once the build finishes. The Core
>   worker was healthy throughout (gate GREEN, no sleep markers).
>   **Next candidate, with the evidence.** `copy-propagation` does NOT descend into a
>   `Capture { body: Arrow }` body: with `x="abc"`, `$(echo "$x")` still reaches every
>   renderer as `getVar("x")` while `$((n+1))` on the same literal *does* fold to
>   `Arith(Num)`. Fixing that would let `const-capture-fold` delete whole captures —
>   genuinely shared, and it needs the subshell write rules worked out first (a write
>   inside the body must block substitution after it), which is why it is not in this
>   round.
> - v119: **A prose-feature round where the census rejected its own best idea — and the
>   cheap canary that made the rejection free.**
>   Method this round: emit the whole corpus to Rust, lint each file with
>   `rustc --emit=metadata`, and rank the surviving warning/idiom classes; fix the
>   class in the RENDERER or in a shared shIR transform, never per backend; then prove
>   the change emission-neutral before trusting it.
>   **The canary.** Every candidate fix is first applied against a saved baseline
>   corpus: re-emit all 563 examples and `diff -r` against the pre-change dump. A
>   byte-identical corpus means the change is a pure no-op on everything we test and
>   cannot regress a backend that shares the transform; any diff at all is a finding,
>   even a small one, and gets read before the change is kept.
>   The surviving change this round: the null/empty helper prologue is emitted
>   per-helper off the *rendered body* (the same `shir::program_any`-style descent the
>   other prologue scans use) instead of as a fixed block, so a file that touches one
>   array emits none of the other seven. Verified byte-identical on the corpus the
>   hard way — by re-emitting every example, not by reasoning about call sites.
>   **The rejected idea, and why it is recorded.** The next class looked like easy
>   money: `"${a[*]}"` / `$a` template words still reach the renderer as slice/`param`
>   nodes, so folding them to the plain `param("", name)` read promised a large
>   reduction in interpolation scaffolding. It is NOT emission-neutral: the canary
>   showed `012_process_substitution` shrinking by ~16 KB, all of it the `lines` array
>   handling. `printf '%s ' "${lines[@]}"` is ONE IR word that expands to N shell
>   words, and the printf arm's many-words guard (`arg_expands_to_many_words`, keyed on
>   the `@`/`*` sigil riding the `param` args) is exactly what stops the format from
>   being collapsed into a single round. Folding the node changes the shape that guard
>   matches, so the “cosmetic” fold was one bad guard update away from printing one
>   round instead of one per element. Reverted, not shipped — a rendering saving that
>   depends on a guard still recognising a node the fold rewrote is not a saving, it
>   is a latent wrong-output bug.
>   **Gates.** `./fail` 563/563; `harness/fail-rs` 556 pass / 0 fail / 7 skip;
>   `./fail-estree` 563/563 Perl and 563/563 ESTree; `harness/py-rust-gate.sh`
>   98/103 (3 FAIL: t104/t82/t87, the documented pre-existing trio; 2 known-gap).
>   `cargo test --lib` 1763 passed / 46 failed — the established baseline count,
>   unchanged. The Core worker was healthy throughout (gate GREEN, no
>   `core-requests/sleeping-*` marker, supervisor + body both live).
> - v118: **The transform list stops being a single walk: `apply` iterates to a
>   fixpoint, and the ONE stale-vs-fresh verdict that surfaces is a scope-walk
>   `top` flag, not a bad rewrite.**
>   `all()` is a linear list, so a transform only ever sees what the transforms
>   BEFORE it produced. Whenever a late pass creates a shape an early one folds,
>   the fold sits in the list and simply already ran. Measured over the corpus
>   (a probe that re-runs the list until it stops changing): 509/557 examples
>   are stable after one walk, **43 need one more, 4 need two, 1 needs three** —
>   and the deltas are structural, not cosmetic (`090_nested_if_else`'s contract
>   1,842 → 428 B; `x="hello"; if [ "$x" != hello ]` — `copy-propagation`
>   substitutes the literal, and only then can the comparison fold, but
>   `const-condition-elim` sits earlier). `apply` now walks the list up to
>   `FIXPOINT_PASSES = 6` times, stopping at the first walk that reports no
>   change; `SH2_FIXPOINT_PASSES=1` restores the old single walk for an A/B.
>   Cost, measured: 1.66 s → 2.36 s for a whole-corpus parse+`ast_to_ir`+JSON
>   sweep, ~1.3 ms/file against a 22 s full emit.
>   **The regression the fixpoint exposed, and its real cause.** Emitted Rust for
>   `010_substring_loop` grew +264 B: `let mut i = "0".to_string()` decayed back
>   into a thread-local store. The fold that caused it is correct (it deletes a
>   `len=10` binding and inlines the bound), and the promotion refusal traced to
>   `list_profile`'s scope walker marking the counted loop's `init` writes as
>   NESTED. A loop's `init` runs once, in sequence, at exactly the position the
>   statement occupies — so it now inherits the enclosing `top` flag (`step` and
>   `body` stay nested: they run repeatedly). The same argument applies to a
>   grouping `Block`, which is what `strip_cfor` builds around a lowered counted
>   loop, and to `ForInit` in the estree path that keeps it. That is a SHARED
>   verdict fix: rust's pass-2 locals and C's array-owner decision both read it.
>   **Idiom work: −7,736 B (−0.45%), 1,731,944 → 1,724,208, 29 files, every one
>   smaller.** Biggest single win: `063_01_deeply_nested_arithmetic` −2,358 B
>   (15 thread-locals → plain `let` bindings). rustc: 0 errors, the same 5
>   warnings (no new `unused`/`unused_mut` from the new bindings).
>   One shared transform is also sharper: `const-condition-elim` accepts an
>   `Arith(Num)` operand — the shape copy-propagation leaves — so
>   `x=3; if [ "$x" -gt 3 ]` no longer reaches every backend as a comparison of
>   two literals with a body that can never run.
>   Six tests pinned emission the fixpoint now folds further; all six were
>   re-pointed at a RUN-TIME value so each still exercises what it names (a
>   capture lift, a keyword mangle, a quoted cmdsub) instead of asserting a
>   mid-optimisation shape that no longer exists. `cargo test --lib` **1763**
>   passed / 46 failed — the identical pre-existing set (verified: with
>   `SH2_FIXPOINT_PASSES=1` exactly those 6 pass and 46 still fail). Gates:
>   `./fail` 563/563, `./fail-estree` 563/563 perl + 563/563 estree,
>   `harness/fail-rs` 556 pass / 0 fail / 7 skip, py-rust 98/103 (the same 3
>   documented reds), `fail-shir` 563 scanned / 0 violations. Core worker
>   healthy (966 GREEN, no sleep marker).
>   Remaining class NOT taken this round: the Rust slice lowering emits
>   `if 3 < 0 { … } else { 3 }` around a LITERAL offset/length (7 corpus sites).
>   It is a renderer template, not an IR condition, so the const fold above
>   cannot reach it; folding it wants a brace-matching text pass or a template
>   arm that skips the sign check when the rendered bound parses as a `u64`.
> - v117: **The v116 drift class gets pinned by tests — and the same drift turns
>   up one function over while those tests are being written.**
>   v116 was a near-miss: the sink-write detectors are the VETO side of three
>   peepholes, and a detector that loses sight of a spelling does not fail, it
>   concludes "no sink is ever written" and inlines the routing out of programs
>   that really do capture. Two tests now hold that invariant, and both were
>   verified to FAIL when the detector is deliberately blinded (a test that cannot
>   fail is worth nothing):
>   `sink_write_detectors_know_every_emitted_spelling` pins each emitted write
>   form and checks the real emitter output both ways, and
>   `a_capturing_program_keeps_its_sink_halves` pins the boundary end-to-end (a
>   capturing program keeps its push AND `spawn`'s `want_out`; a sink-free one
>   keeps getting the slim `flush; spawn; wait`).
>   **The same class then bit in the other direction.** `inline_sinks_when_unused`
>   matches `__sh_print_words`' sink tail by EXACT text, and that literal includes
>   the helper's final `print!("{}", s);`. Changing the helper to the Rust-2021
>   inline-arg form `print!("{s}")` stopped the anchor matching, so the tail
>   inline silently stopped for **7 corpus programs** — fail-SAFE (correct code,
>   just bigger), which is exactly why it presents as bytes and not as a failure.
>   While chasing it: `sinks_inlined_when_unused` does NOT cover this path (its
>   source is `runtime_free`, which reaches the tail through `sinks_dead`
>   instead); the shape that actually goes through the anchor is `${@:3}`, so
>   `the_sink_tail_is_inlined_by_the_anchor_too` now renders exactly that.
>   **Idiom work, all measured together: −18,130 B (−1.04%), 1,748,234 →
>   1,730,104.** (a) `match c.spawn() { Ok(x) => x, Err(_) => … }` →
>   `let Ok(mut ch) = c.spawn() else { … };` — the let-else idiom for this exact
>   shape, **304 sites** (and `__sh_bg`'s `match … { Ok(ch) => {…}, Err(_) => {} }`
>   → the same). (b) `__sh_print_words`' word assembly becomes
>   `ws.iter().flatten().map(|x| x.as_str()).collect::<Vec<_>>().join(" ")`,
>   replacing an 8-line first-flag loop in **105 files**. (c) the helper's
>   `print!("{}", s)` → `print!("{s}")`, matching the spelling the same file
>   already used elsewhere. Only two files grew, by 12 B each, from the one-line
>   comment in `bg`. rustc: 0 errors, the same 5 warnings. Gates: `./fail`
>   563/563, `./fail-estree` 563/563 on both perl and estree, `harness/fail-rs`
>   556 pass / 0 fail, py-rust 98/103 (the 3 documented reds), `cargo test --lib`
>   **1762** passed (+3, the new tests) / 46 failed with an identical failure set.
>   Core worker healthy (GREEN 2026-11-03T21:30, no sleep marker).
> - v116: **The capture push/pop becomes two single-lock swap idioms — and the
>   round's real finding is a near-miss: making the emitter's TEXT better silently
>   blinded three textual detectors that grep for it.**
>   Every capture emitted a two-statement save-and-set through the same mutex:
>   `let __old = __SH_OUT.lock().unwrap().take();` then
>   `*__SH_OUT.lock().unwrap() = Some(Vec::new());`, with the symmetric
>   `take().unwrap()` + `= __old` restore. 345 sites each. Both halves are now one
>   lock and one idiom: the push is `Option::replace` (the guard derefs to the
>   `Option<Vec<u8>>`, so `.replace(Vec::new())` installs and returns the
>   displaced value) and the pop is `mem::replace(&mut *…, __old)` (`Option::
>   replace` is no use there — `__old` is an `Option`, and the cell holds an
>   `Option`). Two lock acquisitions became one, which also closes the window
>   where a background thread's write could land between them.
>   **The trap:** `inline_sinks_when_unused`, `inline_spawn_sinks_when_unused`
>   and `sinks_dead` each hard-coded the literal
>   `*__SH_OUT.lock().unwrap() = Some` as their "this program DOES write a sink"
>   VETO. Changing the emitter to `.replace(Vec::new())` made all three stop
>   matching, so they concluded no sink was ever written and inlined the sink
>   routing out of `__sh_puts` / `__sh_print_words` / `__sh_spawn` in programs
>   that really do capture. It emitted and it compiled — the giveaway was the
>   size: **1,546,316 bytes, −221 KB "win"** against a hand estimate of ~20 KB.
>   The three predicates are now one pair of functions
>   (`text_writes_out_sink` / `text_writes_file_sink`) with the spellings in ONE
>   place, so the emitter and its detectors cannot drift apart again. (A first
>   attempt also used `Mutex::replace`, which `MutexGuard` does not have — it
>   autoderefs to `Option::replace`, whose argument is `Vec`, not `Option<Vec>`;
>   rustc reported 128 × E0308. The emitted corpus compiling is what caught it.)
>   **Rust corpus: 1,765,829 → 1,748,234 (−17,595, −1.00%)**, matching the hand
>   estimate. Isolation: 0 of 563 files differ beyond the rewritten push/pop.
>   rustc: 0 errors, the same 5 warnings. Gates: `./fail` 563/563, `./fail-estree`
>   563/563 on both perl and estree, `harness/fail-rs` 556 pass / 0 fail, py-rust
>   98/103 (the 3 documented reds; a 4th appeared once as the known `num_bigint`
>   rustc-version race while my own cargo builds were rewriting the deps, and
>   cleared on re-run), `cargo test --lib` 1759 passed / 46 failed with a
>   byte-identical failure set. Core worker healthy (GREEN 2026-11-03T20:46).
>   **Censused and deliberately NOT taken:** the `__sh_fnmatch` extglob split is
>   real but small — a proper call-site scan finds only **14 of 31** files without
>   extglob (2 use an extglob literal, 15 pass a pattern built at runtime, so
>   "no extglob" is not provable), i.e. ~25 KB for a 3 KB duplicate helper;
>   `Ordering::SeqCst` → bare `SeqCst` is 3,133 sites / ~31 KB but is style-neutral
>   rather than more idiomatic (and needs the import re-spelled), so it is not a
>   win worth the churn.
> - v115: **`__sh_spawn`'s capture half inlines away when no sink is ever
>   written — and the printed verdict had to be REJECTED to collect 44 of the
>   85 programs.** v114 left `spawn` at 1,856 B for the 186 programs that need
>   no stdin path. But `want_out` also gates a second, independent half:
>   `__SH_OUT.is_some() || __SH_OUTFILE_TL.is_some()`. When a program never SETS
>   either sink (85 of the 198 spawn-carrying programs), every branch that flag
>   guards is unreachable — `c.stdout(piped)` never runs, `ch.stdout` is `None`,
>   the read copies nothing, and the dispatch at the end is dead. What remains is
>   `flush; spawn; wait`, so the body goes 1,856 → ~700 B.
>   New `inline_spawn_sinks_when_unused` post-pass, the twin of the existing
>   `inline_sinks_when_unused` (same file, same fail-safe shape: if any anchor is
>   unrecognised the ORIGINAL text is returned, so the helper can only ever get
>   smaller, never wrong).
>   **The interesting part is which gate is sound.** I first wired it to the same
>   two signals as its twin — the `runtime_free` verdict AND the rendered text —
>   and measured **−47,308 B (41 of 85 files)**. That flag vetoed 44 programs
>   whose own text already proved they never write a sink. For THIS rewrite the
>   printed verdict is strictly weaker, because `want_out` reads only those two
>   sinks, the two greps are exactly the forms that write them, and no helper
>   sets them (audited): the text IS the whole condition, so the post-pass now
>   takes the text alone and all 85 qualify. (`inline_sinks_when_unused` keeps
>   both signals — its rewrite also has to trust that nothing else reads the
>   sinks, which is a verdict question.)
>   **Rust corpus: 1,865,752 → 1,767,669 bytes (−98,083, −5.3%)**; −145,391
>   (−7.6%) across this round plus v114. Once spawn stopped reading the sinks,
>   the now-unreferenced `__SH_OUT` / `__SH_OUTFILE_TL` statics disappeared with
>   them — the existing unused-item pruner did that unaided, which is why the
>   isolation check shows those 85 files differing outside the spawn body only by
>   those two dropped declares. rustc: 0 errors, the same 5 warnings. Gates:
>   `./fail` 563/563, `./fail-estree` 563/563 on both perl and estree,
>   `harness/fail-rs` 556 pass / 0 fail, py-rust 98/103 (the 3 documented reds),
>   `cargo test --lib` 1759 passed / 46 failed with a **byte-identical failure set
>   to the round's start** (`diff` empty). Core worker healthy (GREEN
>   2026-11-02T13:22, no sleep marker).
>   **Censused and deliberately NOT taken:** (a) `__sh_fnmatch`'s extglob arm is
>   ~1,800 B of the 4,964 B helper emitted to 31 files, but a `case` pattern can
>   arrive from a variable, so "this program has no extglob" is not statically
>   knowable — refusing to guess is why the helper is emitted whole; (b)
>   `__sh_capture_rc` shares spawn's spawn/read/wait shape but RETURNS the bytes
>   where spawn writes to the active sink, so they are not the same function;
>   (c) the `${arr[@]}` `"@"` sentinel is 13 sites, and `[@]` (N words) vs
>   `[*]` (one joined word) differ in dquotes — a real canonical-node decision,
>   not a rename; (d) `Ordering::SeqCst` → the already-imported `SeqCst` is a
>   ~12 KB cosmetic sweep across 1,480 sites, left as the obvious next round.
> - v114: **`__sh_spawn` splits on whether any redirect actually needs
>   `__SH_STDIN_PATH` — the same variant rule as `print_words`/`print_words_noesc`,
>   applied to the corpus's largest single helper.** `spawn` (2,301 B) was
>   emitted to all 198 files that shell out, but `__SH_STDIN_PATH` exists for ONE
>   reason: a shell-out inheriting a redirect target must see the REAL device fd,
>   because `tty < /dev/pts/5` needs `isatty` and a byte pipe is not a tty. Only
>   an `r`-mode redirect that opens a file and forwards it to a child needs that —
>   **12 of the 198** corpus programs. The other 186 carried 649 B of
>   unreachable path machinery plus a mutex static.
>   New `spawn_nostdinpath` helper (same signature, drop-in — `run`,
>   `run_traps` and every `__sh_spawn(cmd, …)` call site are untouched), chosen
>   by a new `stdin_path_used` flag set **exactly where the setter is rendered**
>   (the `print_words_esc` precedent: no new analysis, no IR change, and the flag
>   cannot drift from the code that needs it). The `__SH_STDIN_PATH` static is
>   gated on the same flag, so it too disappears from the 186.
>   **Rust corpus: 1,961,870 → 1,865,752 bytes (−96,118, −4.9%)** — the largest
>   single win of this series. **Verified isolated, not just smaller:** a scripted
>   diff that blanks the spawn body and the static line finds **0 of 563 files
>   differing anywhere else**, and exactly 12 files still carry `__SH_STDIN_PATH`.
>   rustc: 0 errors, the same 5 warnings. Gates: `./fail` 563/563, `./fail-estree`
>   563/563 on both perl and estree, `harness/fail-rs` 556 pass / 0 fail, py-rust
>   98/103 (the 3 documented reds), `cargo test --lib` 1759 passed / 46 failed with
>   a **byte-identical failure set to the start of this round** (diff empty) — all
>   46 are peer-work collateral, unchanged. Core worker healthy (GREEN
>   2026-11-02T12:40, no sleep marker).
>   **Censused and deliberately NOT taken** (so the next round does not re-derive
>   them): the prologue is now tight — **1,039 B of dead helpers corpus-wide** and
>   **0 dead statics**, so there is no dead-declaration sweep left worth doing. The
>   remaining concrete ugliness is small and each needs a decision, not a sweep:
>   (a) `${arr[@]}` reaches renderers as `param("slice", "arr", "@", "")` — an
>   `"@"` SENTINEL parsed as an arithmetic offset at runtime — 6 sites / 3.4 KB,
>   and generalising `slice-identity` to it is the next shared-transform candidate,
>   but `[@]` (N words) and `[*]` (one joined word) differ in dquotes so the fold
>   must NOT target the existing `arr[*]` spelling; (b) 11 literal casts
>   (`0 as usize`); (c) `z+=${primes[@]:0:1}` renders the RHS twice (1 site).
> - v113: **`interp-fold` now runs to completion: a `Str` part is a constant,
>   and the fold re-runs after the constant folds.** Two separate holes, one
>   rule. (a) The fold's literal test only accepted `InterpPart::Lit`, so a
>   word whose expansion had already been replaced by the value it proved —
>   `[Lit("Echo result: "), Expr(Str("Hello"))]` — looked non-constant and
>   stayed an `Interpolate`. A `Str` *is* a literal, so it now counts as one
>   (style preserved exactly: a lone `Expr(Str(s, st))` becomes `Str(s, st)`;
>   a mixed run folds only when every `Str` part is `DoubleQuoted` — the
>   style a literal inside an `Interpolate` came from — because re-tagging
>   changes how a renderer re-quotes). (b) `apply()` walks the transform list
>   exactly once and `interp-fold` ran BEFORE the constant folds that create
>   those `Str` parts, so nothing revisited the word. A second registration
>   (`interp-fold-late`, the same `interp_fold::transform` — one set of rules,
>   two entries) runs after them.
>   **Rust corpus: 1,971,077 → 1,961,870 bytes (−9,207, −0.47%).** The win is
>   concentrated where a program's `echo` words are all provable:
>   `042_process_substitution_advanced` 13,696 → 11,068 (−2,628) drops the
>   whole 62-line `__sh_echo_esc`, `__SH_ARITH_WORD_FAIL` and the
>   `__sh_print_words` sink dispatch, because its last echo became
>   `print!("status: ok\n")`; `063_13_nested_subshells` 7,004 → 5,798;
>   `070_gnuisms_thorough` 37,160 → 36,560. rustc census unchanged at 5 real
>   warnings, 0 errors. This is an shIR→shIR canonicalisation, so every
>   backend consumes it — the byte drop above is just the one renderer we
>   measure.
>   **Four peer tests were pinning the pre-fold shape** and were rewritten to
>   keep their coverage rather than to match new output: they now drive their
>   assertions from a POSITIONAL (`$1`) — unfoldable by construction — and
>   assert the folded form alongside. `rust_backend::multi_part_echo…` (its
>   `x=5` input now folds to `print!("v=5 end\n")`, so the `println!` proxy
>   moved to an `echo "v=$1 end"` case and the folded path gets its own
>   assertion), `estree::variable_and_interpolation` (three sub-cases: template,
>   capture-to-native, single-arg-no-join), `estree::echo_pipe_bc…` (a proven
>   operand makes the bc program static, so the dynamic arm needs `$1`; the
>   proven case is now pinned to fold), `zsh::leading_cmdsub_in_dquote…`
>   (already documented the fold; now accepts the unquoted one-word form — the
>   neighbouring test carries the live-cmdsub quoting property).
>   **Verification:** `./fail` 563/563, `./fail-estree` 563/563 on BOTH perl and
>   estree, `harness/fail-rs` 556 pass / 0 fail, py-rust 98/103 (the 3 reds —
>   t104_float32, t82_popen_pipe, t87_bignum — are the documented pre-existing
>   frontend gaps; the `num_bigint` rlib errors seen once were a build-cache
>   race against a concurrent cargo run, and cleared on re-run), `cargo test
>   --lib` 1759 passed / 46 failed. **The 46 are all pre-existing** — produced
>   by peer work in flight (the `echo`→`printf` lowering, `str_temp_inline`,
>   `terminator_binop`); measured by disabling `interp-fold-late` and re-running
>   the suite: 47 failures with the fold off, 46 with it on, the only delta
>   being this round's own re-pinned test. Core worker healthy throughout (last
>   gate GREEN 2026-11-02T12:02, no `sleeping-core` marker).
> - v112: **The shIR normalisation gate reaches zero normalisable sites — by
>   generalising `interp-fold`, not by teaching an arm a special case.**
>   `fail-shir` had reported exactly one actionable gap for three rounds:
>   `003_pipeline.sh`, one `ls` shell-out. The cause was upstream of every
>   capability: `grep "\.txt$"` arrived as
>   `Interpolate([Lit("\\.txt"), Lit("$")])` — an interpolation whose parts
>   are ALL literal. Every `Str`-keyed arm (`grep.rs`, `ls.rs`, `wc.rs`) then
>   refused and the whole stage fell back to `system('bash', '-c', …)`.
>   `interp-fold` already folded `Interpolate([Lit(s)])` to `Str(s)`, and its
>   own module doc lists "a bare `Str`, or an `Interpolate` whose parts are
>   ALL literal" as the shape *consumers* keep re-implementing — so the
>   multi-part all-literal case is the same rule, not a special case. It now
>   folds to one `Str` carrying `DoubleQuoted` (the faithful style tag, since
>   the literal came from a quoted context). Result: **563 scanned, 557
>   bash-free (was 556), 7 → 6 shell-out sites, and 1 → 0 normalisable** — the
>   gate's actionable backlog is empty for the first time, and the 6 remaining
>   are legitimate (commands outside the emulable whitelist, or non-command
>   shapes like a `(` subshell). The raw A1 for `003` now contains zero
>   `Interpolate` nodes.
>   **What did NOT move:** the refusals. `Interpolate([Expr(e)])` still stays
>   (a quoted word and a bare expansion differ in word-list positions — `for x
>   in "$v"` is one word), and an all-literal list sitting directly after a
>   `…=`-ended word still stays (the rust `local`/`declare` join reads that
>   word's Str-vs-Interpolate SHAPE to tell the value from the next
>   declaration; 081_nested_functions is the regression that taught us). Both
>   are now pinned by tests, the second one explicitly for the multi-part case.
>   **Rendering impact, stated honestly:** the Rust corpus is byte-identical
>   (0 of 563 files change) — the Rust renderer already flattened all-literal
>   interpolations itself, so this win is entirely in the IR's
>   canonicalisation, unlocking the Str-keyed capabilities that other backends
>   consume.
>   (2) **Inline format arguments, the Rust-side win for this round.**
>   `println!("{}", x)` → `println!("{x}")` — Rust 2021 captures a local by
>   name, so the separate argument is redundant
>   (`clippy::uninlined_format_args`). **174 sites in 135 files**, nearly all
>   `print!` (the `echo "$x"` shape): 1,971,425 → 1,971,077 bytes. Only a bare
>   identifier can be captured — `{a.b}` is not a legal inline argument and
>   `{self}` would not parse — so field/path arguments and keywords are left
>   alone, and a call with any other format shape is untouched. Placed LAST in
>   the post-pipeline, because the passes before it are what turn
>   `println!("{}", x.to_string())` into the plain-ident shape it needs.
>   Two existing rust tests asserted the older spelling
>   (`println!("{}", x)` / `println!("{}", n)`) while their comments
>   described the intent ("takes it directly rather than through a
>   `.to_string()` copy", "reads handed over bare"); both now assert the
>   inline form, which satisfies the same intent more directly — the checks
>   were tightened, not dropped.
>   Gates: `./fail` 563/563, fail-rs 556 pass / 0 fail / 7 skip,
>   `cargo test --lib` 1756 pass / 46 fail with the failure-name set
>   IDENTICAL to the pre-round baseline (`comm -3` empty), rustc over 563
>   emitted files 0 errors / the same 5 warnings, fail-estree 563/563 (100%)
>   — the gate that matters for `interp-fold`, since it changes the IR every
>   backend consumes — and py-rust 98/103 with the same three pre-existing
>   FAILs (t104_float32, t82_popen_pipe, t87_bignum).
> - v111: **A copy where a move was meant — the capture path, 311 sites in
>   164 files.** `String::from_utf8_lossy` returns a `Cow<str>`; every
>   command substitution ends in `String::from_utf8_lossy(&__cap).to_string()`.
>   `.to_string()` formats that borrowed view into a FRESH `String`
>   (`ToString` for any `Display` type IS `format!("{}", self)`), while
>   `.into_owned()` hands over the buffer the `Cow` already holds when it is
>   `Owned` — which is exactly the case where the lossy conversion had bytes
>   to replace. So `into_owned` is never worse and saves a full copy of every
>   capture whose bytes were not valid UTF-8. Both producers
>   (`String::from_utf8_lossy`, `OsStr::to_string_lossy`) are CALLS, so the
>   `Cow` is a temporary and moving out of it is always valid — a `let`-bound
>   `Cow` would still need its borrow, which is why the rule only fires on a
>   call immediately followed by the conversion. Corpus: `.to_string()`
>   occurrences 1786 → 1475, `into_owned()` 17 → 328, 563/563 compile with
>   **0 errors and the same 5 warnings**; bytes 1,971,114 → 1,971,425 —
>   `.into_owned()` is one char longer than `.to_string()`, so this round
>   trades ~311 bytes of text for one avoided allocation per capture.
>   **Where the other candidates went**, all measured before choosing (a
>   construct is boilerplate when it costs volume, not when it merely appears
>   often): the shell-out command string is the largest single bucket at 5.1%
>   of emitted bytes, but **all 229 `__sh_wq` calls carry a runtime temp path**
>   (0 all-literal), so there is nothing to fold; `__sh_fnmatch`'s 99 uses are
>   all real globs (no constant pattern); `.clone()` is load-bearing at all but
>   2 of 1180 sites; `((X))` directly-nested parens are only 134 pairs corpus-
>   wide; `println!("{}", IDENT)` → `println!("{IDENT}")` is 174 sites and
>   ~700 bytes. The remaining mass is the per-file prologue (65.6% of bytes),
>   and `golf_rust` already drops every helper a program does not use — a
>   2-line program emits no prologue at all.
>   Gates: `./fail` 563/563, fail-rs 556 pass / 0 fail / 7 skip, fail-estree
>   563/563 (100%), fail-shir 556 bash-free / 7 shell-out sites /
>   1 normalisable (identical to v109/v110 — a Rust-renderer change), py-rust
>   98/103 with the same three pre-existing FAILs (t104_float32, t82_popen_pipe,
>   t87_bignum), `cargo test --lib` 1752 pass / 46 fail with no `rust_backend`
>   test among the 46.
>   NOTE: still uncommitted in the shared checkout alongside the other
>   worker's in-flight registration, so v108-v111 ride the same pending
>   split-then-commit.
> - v110: **A conversion that the macro itself makes pointless — and the
>   two passes that moved it out of reach.** Corpus: 563 programs,
>   42929 lines (unchanged — the change is intra-line),
>   **1,974,930 → 1,971,114 bytes**, `.to_string()` occurrences
>   2104 → 1786, **563/563 compile, 0 errors, 5 warnings** (the same
>   renderer-synthesised set v108 documents).
>   **The rule.** `format!`/`print!`/`println!`/`eprintln!` take
>   `impl Display`, and `ToString` is blanket-implemented for every
>   `T: Display` with `impl = format!("{}", self)` — so
>   `format!("{} > {}", "'cat'".to_string(), …)` builds, as an owned
>   `String`, exactly the text the macro prints and drops. The conversion
>   borrows (`&self`), so removing it cannot change ownership or drop order
>   either. rustc is silent (this is clippy's `useless_conversion`
>   neighbourhood), which is why it outlived v109's comparison-only rule —
>   that one could only fire adjacent to `==`/`!=`, and this position held
>   the other half: **241 sites in 93 files, 220 of them a bare literal**
>   from the word-list → command-string lowering.
>   **Three refusals** keep it sound: a `{:?}` placeholder (`Debug` of a
>   `String` quotes, `Debug` of the integer it came from does not — so
>   `format!("{:?}", n.to_string())` really differs from
>   `format!("{:?}", n)`); `write!`/`writeln!` (first argument is the
>   WRITER, not the format string); and a call with no interpolation
>   argument.
>   **Why it took three attempts to place it.** (1) At the `emit` choke
>   point — where v109's rules live — it stripped 49 of 241: the print
>   macros are also *synthesised after* that point (`inline_print_words`
>   rewrites `__sh_print_words(&[vec![EXPR]])` into `println!("{}", EXPR)`
>   and inherits the `String`-typed word; the literal-argument merge builds
>   `"Count: {}"` out of a leading literal). Moving the pass to the end of
>   the post-pipeline got 229. (2) The remaining 12 were `format!` calls
>   nested INSIDE another macro's argument block — the command-substitution
>   shape `println!("{}", { let __c = format!("{} < {}", …); __c })` — and
>   the outer splice jumped straight past them, so the pass now RECURSES
>   into the argument span (strictly shorter, so it terminates). (3) The
>   last 32 survived in exactly the **9 files that contain
>   `' ' | '\'' | '\\' | '"' | '$'`** — `__sh_q`'s quoting arm. `'"'` is a
>   char literal whose byte IS a double quote, and a scanner that only
>   knows string literals read it as the START of a string and swallowed
>   the rest of the file. `char_lit_end` now recognises `'X'` / `'\X'`
>   (a lifetime has no closing quote after one char, so it is left alone),
>   and the scan also copies string literals verbatim — a macro NAME inside
>   one (`echo 'print!("{}", x.to_string())'`) is DATA, not a call.
>   6 tests pin the rule, the `{:?}` refusal, the nesting, the char-literal
>   desync and the data-inside-a-literal case.
>   Gates: `./fail` 563/563, fail-rs 556 pass / 0 fail / 7 skip,
>   fail-estree 563/563 (100%), fail-shir 556 bash-free / 7 shell-out
>   sites / 1 normalisable (identical to v109 — this is a Rust-renderer
>   change), py-rust 98/103 (the same t104/t82/t87 pre-existing FAILs),
>   `cargo test --lib` 1750 pass / 46 fail with **no `rust_backend` test
>   among the 46**. Core worker healthy throughout (gate GREEN at 09:48,
>   no sleep markers).
>   NOTE: still uncommitted in the shared checkout, and still mixed with
>   the other worker's in-flight `str_temp_inline` / `terminator_binop`
>   registration, so v108/v109/v110 all ride the same pending
>   split-then-commit.
> - v109: **Three rendering habits, all found by census rather than by
>   reading code: a wasted conversion, an index loop where Rust has `for`,
>   and an argument list that was never filled.** Corpus: 563 programs,
>   42972 → 42929 lines, **563/563 compile, 0 errors, 5 warnings** (the 5
>   are the renderer-synthesised ones v108 documents — unchanged).
>   (1) **A literal's `.to_string()` in comparison position is pure waste**
>   (`strip_cmp_to_string`, at the `emit` choke point next to
>   `strip_let_parens`). `String` and `&str` compare directly —
>   `PartialEq<&str> for String` and `PartialEq<String> for &str` both
>   exist — so `x == "start".to_string()` allocated a String per
>   evaluation to rebuild a constant. 127 corpus sites (1415 → 1288), and
>   the rule is deliberately narrow: only a literal IMMEDIATELY adjacent to
>   `==`/`!=` on either side, because that is the one position where `&str`
>   is known to type-check against the other operand. The other ~1288
>   conversions stay — `vec!["a".to_string()]` is a `Vec<String>` and a
>   thread-local store holds a `String`; dropping those would not compile,
>   which is the census's own check (0 errors after the change).
>   (2) **`for x in "$@"` emitted an index loop; Rust has `for`.** The
>   word-list arm built `let items = …; let mut i = 0; loop { if !(i <
>   len) { break } …; i += 1 }` while the ARRAY arm two hundred lines above
>   already emitted `for x in items`. The index existed for exactly one
>   reason — `for_index`, a field consulted only by `emit_continue`, which
>   hand-advanced it so a `continue` iterated. A `for` does that natively,
>   so the arm now mirrors the array arm: 20 sites → 0, four scaffold lines
>   each. That hook was also WRONG for a `continue` belonging to a nested
>   loop in the body (it incremented the outer index on a `continue` the
>   shell never applies there), so this removes a latent miscompile with
>   the boilerplate.
>   (3) **`__SH_ARGV` was never seeded — every Rust target saw an empty
>   argument list.** `$@`/`$#`/`$1` all read that static, and nothing filled
>   it: `005_args` printed `Argument count: 0` for `prog a b c` where bash
>   printed 3. `main` now seeds `args_os().skip(1)` (`args_os` +
>   `to_string_lossy`, NOT `args()`, which panics on a non-UTF-8 argument
>   where the shell reads the bytes), emitted only for the 17 programs that
>   actually touch the list — an unconditional seed would reference the
>   static in all 563 and `golf_rust` could no longer drop it. Verified
>   directly: `005_args` with `a b c` now matches bash line for line.
>   Gates: `./fail` 563/563, fail-rs 556/0/7, fail-estree 563/563 both
>   sides, py-rust 98/103 (the same t104/t82/t87 pre-existing FAILs),
>   `cargo test --lib` 1746 pass / 46 fail with a failure-name set IDENTICAL
>   to the pre-round baseline (diff of the sorted lists is empty).
>   Core worker healthy throughout (gate GREEN at 01:14, no sleep markers).
> - v108: **The unreachable class is zero, and the fold that gets it there
>   is its own transform.** rustc census over the 563-file emitted corpus:
>   the 5 `unreachable`-class warnings (expression ×3, statement ×2) are
>   gone — what remains is 5 warnings of an unrelated kind and **0 errors**,
>   so every example still compiles. The 5 remaining are all rustc telling
>   the truth about the SOURCE: one `non_snake_case` (a shell name we must
>   keep) and four dead store/read sites that exist only in
>   renderer-synthesised blocks
>   (`{ let __o = i; i = i + 1; __o }` for `$((i++))`, and
>   `let _ = { let __v = …; X = …; __v }` for an assignment whose value
>   statement position discards) — no shIR transform can see either,
>   because neither is in the IR.
>   (1) **`terminator-binop`, in `src/transforms/terminator_binop.rs`**
>   (7 tests) — a statement-level `a || b` / `a && b` whose left operand
>   never yields keeps the left operand's effects and drops the right's
>   scaffolding: `break || exit 1` → `break`, `exit 1 || x` → `exit 1`.
>   It is a SEPARATE registry entry ordered BEFORE `unreachable-after-exit`,
>   so the collapsed control call is a terminator the very same walk can
>   act on (a fold buried in the prune file could not be ordered that way,
>   which is why the long-form entry below describes it as "one fold is
>   new" inside the verdict). Every renderer accepts the surviving control
>   call standalone — checked across perl, C, go, estree, python, java — so
>   this is a shared win, not a Rust one.
>   (2) **`terminates_list` learned the spellings the frontends actually
>   emit.** `exit` reaches the IR as `builtin("exit", …)` (what
>   `builtin-lift` makes of `exec("exit", …)`) and as a bare
>   `Call("exit")` — when only `IrStmt::Exit` counted, the transform was a
>   no-op on real programs: `exit 1; echo dead` still emitted
>   `print!("dead")` after `std::process::exit(1)`.
>   Verified this round: `./fail` 563/563, fail-rs 556/0/7, fail-estree
>   563/563 on both sides, fail-shir green, py-rust 98/103 (the same 3
>   pre-existing FAILs: t104, t82, t87), `cargo test --lib` 1744 pass / 46
>   fail with the failure-name set unchanged (estree peer expectations,
>   backend drift, range-analysis — none in the modules this touched).
>   Core worker healthy throughout (gate GREEN, no sleep markers).
>   NOTE: the code for this round is in the shared checkout UNCOMMITTED
>   (`src/transforms/terminator_binop.rs` untracked, plus edits to
>   `src/transforms.rs`, `src/shir.rs`,
>   `src/transforms/unreachable_after_exit.rs`); the same checkout also
>   carries another worker's in-flight `str_temp_inline` registration,
>   `src/c_backend.rs` and `numeric_observed.rs`, so the two must be split
>   before the next gitlink bump.
> - v52: **The fb0 fragment dispatch loop is closed (the emit-half
>   §11.14 called "remains").** `bash-o4/src/fb_frag.rs` emitted static
>   GLSL450 pairs (`blocks`/`overlay`) but nothing dispatched them:
>   `vkffi` bound compute only. HEAD `448f32db` lands the host half —
>   `bash-o4/src/fb_draw.rs` (`RasterRunner`: offscreen color+depth
>   target, atlas upload with crack = layer 9, blocks 36-vert list with
>   depth on + overlay 6-vert list with src-alpha, push constants,
>   readback), `bash-o4/tests/fb_dispatch.rs` (blocks centre pixel ==
>   Rust oracle of `frag_pixel`, clear corners, determinism; overlay
>   opaque green full-screen; lavapipe-pinned), and driver
>   `--fb-proof[=WxH]` (the proof scene through the real binary as P6).
>   The proof caught two emitter bugs hiding behind the missing dispatch
>   (`gl_InstanceID`/`VertexID` are OpenGL names — Vulkan wants
>   `gl_InstanceIndex`/`VertexIndex`; `fy`/`fz` missed the `/1e6` milli
>   divisor and exploded verts to ±50000), both pinned by strengthened
>   unit tests. Re-verified 2026-10-12: `cargo test --offline --test
>   fb_dispatch` 2/2 ok, `--fb-proof=64x64` rc=0 12301-byte P6,
>   `--emit-shader fb-blocks` rc=0. Lavapipe teardown faults found +
>   documented (pool/framebuffer/render-pass freed pool-last / cached /
>   device-leaked by design). What stays open is unchanged: the
>   `_sh_gpu_*` host split in generated C, and the proof scene is not a
>   program payload. See §11.14.
> - v107: **Two lint classes normalised by changing the SHAPE, not by
>   renaming or allow-ing around it.** rustc census: 48 → 22.
>   (1) **`__sh_printf`'s dead initializer (9 sites).** The helper declared
>   `let mut piece = String::new();` and then assigned it in EVERY match
>   arm, so rustc reported "value assigned to `piece` is never read" once
>   per arm. The match now IS the initializer — the arms that also apply a
>   `.prec` truncation get a local `t`, the rest return their value — and
>   the helper is emitted with no warnings at all (`printf '%s|%d|%05.2f|%q'`
>   verified byte-for-byte against bash).
>   (2) **A user function keeps its shell name, with the attribute it needs.**
>   `exitScript`, `INFO`, `test` are the SOURCE's names: callers use them and
>   `typeset -f` prints them, so renaming to snake_case would be a
>   miscompile. An uncalled definition is legal shell too (and observable via
>   `declare -f`), which is exactly why dead_fn_elim refuses to drop it — so
>   the definition carries `#[allow(non_snake_case, dead_code)]` (the
>   snake-case half only when the name has an uppercase letter). Pipeline
>   helpers deliberately keep `dead_code`, so a genuinely orphaned runtime
>   helper still trips the lint.
>   Gates: `./fail` 563/563, fail-rs 556/0/7, fail-estree 563/563 (100%),
>   fail-shir green. `cargo test --lib` 1733 pass / 46 fail — the same 45-red
>   backlog plus the one c_backend red from the other worker's in-flight
>   changes (`src/c_backend.rs`, `src/shir_passes/numeric_observed.rs`,
>   `src/transforms.rs` and `src/transforms/dead_store_elim.rs` are dirty in
>   the shared checkout and were NOT staged; this round committed
>   `src/rust_backend.rs` alone).
> - v106: **Every `unused_parens` class in the emitted Rust is gone — one
>   helper at the `emit` choke point instead of a hunt per template.**
>   rustc census over the 563-file corpus: 74 → 48 (all four paren classes
>   to zero).
>   (1) **`strip_let_parens` at `emit`.** A `let` takes any expression, so
>   the pair the renderer wraps around a compound value is pure text there
>   — "unnecessary parentheses around assigned value" (5 sites). Fixing it
>   where EVERY statement is pushed means no future template can regress it
>   (the previous round's per-site `let_value` call was whack-a-mole: the
>   array-store template had its own `let __k = (…);` left over). The scan
>   refuses a tuple (`let (a, b) = (x, y);` must keep its pair) and a `==`
>   that is not the binding's `=`, and touches only a pair that closes
>   right before the `;`.
>   (2) **`unparen_deep` for conditions.** `unparen` strips ONE pair, but a
>   glob test renders `(__sh_fnmatch(…))` and the case chain adds another,
>   so `} else if (…)` survived a single strip (4 sites). Repeated
>   stripping is sound exactly in a condition (a bool cannot be a tuple).
>   (3) **`__sh_div`/`__sh_mod`/`__sh_pow` arguments** go through the
>   comma-safe helper — an argument takes any expression too (4 sites).
>   (4) **A `{{`/`}}` template that was never a `format!`.** The `$!`
>   value is a plain `String` other templates splice with `{}`, so its
>   escaped braces were emitted VERBATIM — `*v.borrow_mut() = {{ let __p =
>   … }}`, a doubled block rustc flagged at 4 sites (grep_p, dollar-bang).
>   Same class as the `"!"` arm fixed in v103; both now single-braced.
>   Gates: `./fail` 563/563, fail-rs 556/0/7, fail-estree 563/563 (100%),
>   fail-shir green. `cargo test --lib` 1728 pass / 46 fail: the 45-red
>   backlog plus ONE new c_backend red
>   (`unsigned_mod_refuses_unranged`) that is NOT this round —
>   `src/c_backend.rs` and `src/shir_passes/numeric_observed.rs` are
>   modified in the shared checkout by another worker's in-flight work, and
>   this round committed `src/rust_backend.rs` alone.
> - v105: **One shared verdict replaced three copies of "does this list
>   fall through", and the Perl gate caught the first version being
>   UNSOUND.** rustc-warning census over the 563-file emitted corpus: 91 →
>   74 (`while_true` 3 → 0, assigned-value parens 10 → 5, unreachable
>   statement 6 → 3).
>   (1) **`shir::{stmt_terminates, list_terminates, loop_escapes}`.** One
>   definition of "terminator" — `exit`/`die`/`break`/`continue`,
>   `return` inside a function, and an INFINITE loop (`while true` /
>   `for ((;;))`) that no `break` can escape — consumed by the
>   unreachable-tail transform AND by the Rust renderer (epilogue, redirect
>   restore), so "dead after `exit`" and "dead after `while true`" cannot
>   drift apart.
>   (2) **`unreachable-after-exit` → unreachable-after-terminator.** It now
>   prunes after `die`, `break`/`continue` (for the list they sit in) and an
>   infinite loop, and it recurses into a function's `named_blocks` — the
>   old code rebuilt `Function` with `named_blocks: Vec::new()`, DELETING a
>   Go-style named return block (statements and all) on every program the
>   transform touched. 7 new tests, including the nested-loop case (a
>   `break` in a deeper loop does not escape) and the `case` case (bash's
>   `case` captures nothing, so a `break` in a clause still breaks the
>   loop).
>   (3) **The unsoundness, found by `./fail`.** `while true; do break ||
>   exit 1; done` keeps `break` as a CONTROL CALL inside a `BinOp`
>   (`func: "break"`, purity Control), NOT as `IrStmt::Break` — so the
>   loop looked infinite and the transform pruned everything after it:
>   `parse-break-or` printed nothing where bash prints `parsed OK` /
>   `exit: 0`. The scan now recurses into `If`/`Case`/`Block` bodies and
>   falls back to the statement's Debug form for the call spelling. An
>   over-approximation only keeps a tail that is dead anyway; an
>   under-approximation deletes live code, which is what the gate caught.
>   (4) **A TLS numeric read no longer clones.** `read_num_of_str` parses
>   INSIDE the borrow — `__SHV_x.with(|v| v.borrow().trim().parse::<i64>()…)`
>   — where the `read_str`-based form cloned a String per read (88 corpus
>   sites: `__SHV_y.with(|v| v.borrow().clone()).trim()…`).
>   (5) **`while true {` → `loop {`** (rustc's `while_true`; the programs are
>   identical, a plain `break` leaves both as `()`), and **`let x =
>   (EXPR);` → `let x = EXPR;`** via a new `let_value` helper that strips
>   one pair only when it encloses the whole initializer (refusing a tuple
>   or an early depth return).
>   (6) **Epilogue / restore after a diverging body.** The implicit
>   `std::process::exit(__SH_RC…)` and the `__SH_OUTFILE_TL` restore are
>   skipped when the body never falls through (the shared verdict, plus a
>   guard for the case where another layer already emitted the exit).
>   Gates: `./fail` 563/563, fail-rs 556/0/7, fail-estree 563/563 (100%),
>   fail-shir green; `cargo test --lib` 1727 pass / 45 fail — unchanged, no
>   new reds (the 45 are the pre-existing backlog in
>   c_backend/estree/shir/fish/zsh/shir_json_in/zig/go).
> - v104: **Analysis of the emitted Rust found two RENDERING BUGS (not idiom
>   gaps) plus two needless allocations; nine stale expectations refreshed.
>   fail-rs 543/13 → 556/0/7, every other gate green.**
>   (1) **A const-folded `elsif` ran the `else` too.** A `case` on a constant
>   subject lowers to an if/elsif chain whose conditions all render as
>   constants, so the Rust renderer decides the chain at emit time. When an
>   `elsif` is proven TRUE the code took that body but never cleared `alt`,
>   which still held the `else_` body — so BOTH were spliced inline and both
>   ran: `000__04h_complex_examples` printed its matching arm and its `*`
>   default back to back (Perl, which folds in the IR, was correct, so only
>   the Rust arm diverged). One line: `alt = &[]`; test
>   `const_case_takes_exactly_one_arm`.
>   (2) **`typeset -f` lost a folded `echo`.** `echo_fold` lowers a literal
>   `echo` to the native `Output` statement, but `fn_body_line_text` (the
>   `typeset -f` / `declare -f` definition display) had no `Output` arm, so
>   the body line printed empty: `myfunc () \n{ \n    ;\n…}` where bash
>   prints `    echo "Inside myfunc";`. The arm puts the `echo` back (quote
>   when the text carries a space or an expansion); test
>   `typeset_f_shows_a_folded_echo`. This was fail-rs's last red.
>   (3) **`echo "$n"` on a numeric var allocated a String.** The `Output`
>   arm's numeric test was `echo_fold::numeric_word`, the TARGET-FREE verdict
>   (literals, arith, lengths) — a numerically-homed VAR is only visible to
>   the renderer, so the word list rendered `vec![n.to_string()]` and the
>   inlining pass collapsed it to `println!("{}", n.to_string())`. The arm
>   now also consults `word_is_numeric`, and `word_is_numeric` sees through a
>   one-part `Interpolate` (a QUOTED lone expansion arrives wrapped, so
>   `echo "$n"` printed `.to_string()` while `echo "n=$n"` printed `n`).
>   (4) **`.clone()` before a borrowing `.trim()`.** `read_num_of_str`
>   appended `.trim()` to an OWNED read, so every numeric read of a
>   string-homed var carried a clone: `x.clone().trim().parse::<i64>()` →
>   `x.trim().parse::<i64>()` (reuses `drop_trailing_clone`, which refuses a
>   call/index receiver, so only a bare path is un-cloned).
>   (5) **`$?` / `$$` / `$#` stringified an integer.** `expr_any` appended
>   `.to_string()` to reads that `getvar_num` renders as an integer — the rc
>   load, the pid, the argv length — so `echo "rc=$?"` allocated a String for
>   every status echo. `word_is_numeric`'s `getVar` arm now accepts those
>   three names (they are integers BY CONSTRUCTION, so the verdict cannot
>   drift from the reader). Corpus-wide: rc stringifications 177 → 17, pid
>   4 → 0, argv-length 3 → 2 (the 17 are `$?` reads reached through a shape
>   that is not a bare `getVar` word).
>   (6) **Nine stale `rust_backend` expectations, invariants kept.** They
>   pinned the older, heavier emission: `__sh_puts` → `__sh_print_words`;
>   a literal-path redirect is now a bare `std::fs::write` with NO sink
>   runtime (the run-time-path variant `> "$1"` keeps `__SH_OUTFILE_TL` and
>   the sink-aware printer, which is what those tests now assert); and a
>   const-folded condition/arith cannot exhibit the shape it pins, so the
>   numeric tests use a run-time operand (`x=$1`) — `exit $((x+1))` keeps
>   `as i32` only when the value is not folded, `x=1` folds to `exit 2`.
>   Gates: fail-rs 556 pass / 0 fail / 7 skip (was 543/13/7 — the earlier
>   "13" reading was a RESUMED verdict log, not a live run: `RS_GATE_OUT`
>   must be cleared between rounds); `./fail` 563/563; fail-estree
>   563/563 (100%); fail-shir green (7 shell-out sites, 311 body bytes);
>   `cargo test --lib` 1718 pass / 45 fail — `rust_backend::` is now 0 reds
>   (was 10) and every remaining red is the pre-existing backlog in
>   c_backend/estree/shir/fish/zsh/shir_json_in/zig/go.
> - v103: **The first Tier-1 Isabelle session for a pass MIMEcroft actually
>   fires: `string-accumulator`, and the bug it exposed is fixed with a
>   failing-first test.**
>   (1) **Why this one.** Of the three passes MIMEcroft fires, this is the
>   only one whose verdict is IR-shaped (Tier 1): the C consumer
>   re-walks the tree (`acc_vars_tree`) and tracks four accumulators
>   (`blk_p`, `tup_rp`, `tup_gp`, `tup_bp`; 15 `_alen_` sites), so a wrong
>   verdict is a live miscompile, not an inert gate.
>   (2) **The session.** `proofs/StringAccumulator` — 18 lemmas,
>   `quick_and_dirty = false`, green in ~1 min, registered in
>   `harness/transform-proofs.sh` (whole-directory run: `OK
>   proofs/StringAccumulator`). It models the three walks one constructor
>   per arm (§2), keeps the PRE-FIX walk as the negative control and
>   machine-checks the report's witness (`the_fix_is_load_bearing`: an
>   `Arith(AVar v)` IS a read and the catch-all does not see it), proves
>   carrier completeness (redirect, subshell, block, background, pipeline
>   stage, function body + named blocks, ForInit, try + except clauses, case
>   clause body AND pattern, thunk, comprehension, arith index key, arith
>   assign rhs), and the first-read position rule
>   (`before_any_read ⟹ ¬ stmts_read`). Replacing the fixed arm with the
>   pre-fix `False` makes the session FAIL — the control is real.
>   (3) **The code fix, checked but awaiting re-land.** `arith_read_walk` +
>   the missing `IrExpr` arms + a carrier-complete, wildcard-free
>   `read_walk` + a recursive `self_append_vars` that treats `continue` as a
>   non-write surface. 11 module tests green; restoring
>   `IrExpr::Arith(_) => {}` turns exactly one red (the no-arith control
>   stays green). Landed on a branch off `12b304ddf` — the analysis version
>   the bug reproduces in — because main's `acc_vars_tree`/`lower` work is
>   uncommitted and cannot be replayed around. Offer + re-land recipe:
>   `core-requests/done/string-accumulator-walk-20261030-120000.md`.
>   (4) **The manifest now carries a real `proof:` line**, and the gate
>   builds it: `proof/Claim.thy` re-checks the core of the same statement
>   from source as its own session (`StringAccumulatorClaim`), so the claim
>   cannot be satisfied by another session's stale heap. Whole gate:
>   **7 checked-and-built, 0 stated-only** (`proofs/` itself is red from
>   another lane's untracked `Maskable` session, not this round).
>   (5) **Not done, deliberately:** the lowering (push/join) stays Tier 3;
>   `sync-ok-loops` criterion 2 and `process-subst` remain unproved (the
>   first now fires on MIMEcroft but changes no emitted byte, the second is
>   filesystem statement semantics).
> - v102: **The parked-transform census: eleven transforms adjudicated by
>   measurement, one live defect promoted out of the parked set, and three
>   stale firing counts in `docs/transform-verification.md` corrected.**
>   (1) **Firing, measured two ways** (in-process `ast_to_ir_raw` + one
>   transform at a time; plus a re-run on the fully optimised IR; plus
>   `bash-o4/MIMEcroft_fb.sh`, 293 commands → 279 stmts, where a corpus
>   count under-sells the pass): `process-subst` 16/563 (pipeline only) and
>   `type-query` 1/563 change the IR; `sync-ok-loops` records 43 files / 52
>   verdicts and `string-accumulator` 1/563 at the top level; the other
>   seven are 0/563 — including `for-recovery` and `inline-pure-fns`, the
>   latter despite 59 corpus files defining functions. `planner` is not in
>   `transforms::all()` (a manifest+solver mechanism) and `sub` returns
>   `false` unconditionally.
>   (2) **MIMEcroft contradicts the corpus denominators twice.**
>   `sync-ok-loops` computes 19 `sync_ok` + 1 `batch_ok` verdict there and
>   emits byte-identical estree with the pass on and off; `string-accumulator`
>   has an EMPTY top-level verdict but C's `acc_vars_tree` tree walk
>   (`c_backend.rs:9837`, over `prog.stmts` and every `sub.body`) tracks
>   four accumulators (`blk_p`, `tup_rp`, `tup_gp`, `tup_bp`; 15 `_alen_`
>   mirror sites). That walk is `read_walk`, which has `_ => {}`
>   catch-alls and no `IrExpr::Arith` arm — so
>   `tsv="$tsv$x"; n=$(( tsv + 0 ))` inside a loop still yields
>   `Accumulator { var: "tsv" }`. Filed as open bug 11 in `BUGS_FOUND.md`
>   with the witness, three measured containment facts (estree `lower()`
>   never runs end-to-end on the shell-source CLI path; the C gates refuse
>   the witness independently; MIMEcroft's four accumulators have no
>   `$(( ))` self-read), the owner-call fix, and the regression shape.
>   (3) **Tier verdicts.** Seven are Tier 3 (loop-fusion/inlining traces,
>   fork/thread, call preservation, filesystem statement semantics); the
>   Tier-1 fragments that exist (`sync-ok-loops` criterion 2,
>   `string-accumulator`'s walker, `type-query`'s builtin table) are either
>   conservative by construction, defective, or trivial — so **no new
>   Isabelle session**: proving them today would certify the thin part, and
>   for `string-accumulator` would certify the hole. `for-recovery` keeps
>   its green `proofs/ForRecovery` session, still a dead contract.
>   (4) **Stale counts corrected in `docs/transform-verification.md`.** The
>   2026-10-24 corpus table re-run on today's 563 files reproduces every row
>   except `test-lowering` (43/562 → **42/563**) and `counted-while-forinit`
>   (**0 → 9/563**, the 2026-10-26 `Arith`-wrap fix). The corpus-wide
>   `For`/`ForInit` total is **44 raw → 51 full `ast_to_ir`**: the old
>   "49 OFF → 47 ON, the passes recover none" claim predates the fix and is
>   superseded. A new §"The parked-transform census" carries the table and
>   the three lessons (a firing verdict is not a live gate; a pass's corpus
>   count is not its reach; proved ≠ reachable).
>   (5) **No code changed.** `BUGS_FOUND.md` gained bug 11 + the census
>   section (commits `e815ba10`, `e461e474`); `docs/transform-verification.md`
>   gained the census section and the three re-measured counts. All gates
>   stand on their last measured state; nothing in this round touches
>   `src/`.
> - v101: **Triage-and-repair: six red unit tests fixed at the root
>   (two real transpiler bugs in shared code, one missing caller in the
>   C backend's GMP gate), the round's temporary instrumentation
>   removed, and every equivalence gate re-run green against its own
>   documented baseline.**
>   (1) **`drop_dead_top_decls` no longer deletes a side-effectful
>   initializer.** The estree dead-decl sweep dropped a top-level `let`
>   whose binding no live code read — but the INITIALIZER carries the
>   whole effect: `x=$(diff a.txt b.txt)` runs diff (and `echo $?`
>   reads its status), ``files=(`sort <<< "$y"`)`` runs sort. A
>   capture/array-shaped RHS now keeps the declaration (the binding
>   stays, the command runs); only a genuinely constant initializer is
>   still droppable. Verified with the drop probe before it was
>   removed: the capture survived as a bare statement instead of
>   vanishing with its binding.
>   (2) **`echo_fold`'s `fold_narrow` descends `Function` bodies.**
>   `fold_narrow` — the only walk that folds `echo` — had no `Function`
>   arm; the only walk that DID descend functions (`fold_wide`) is
>   printf-only by design. So a constant `echo` inside a function never
>   folded on ANY backend, and every backend re-rendered one constant
>   as a slot split. Root cause found by diffing the IR of the failing
>   in-function shape against its working top-level twin — the shapes
>   were IDENTICAL, which localised the refusal to `fold_narrow`'s
>   entry gating (the pre-split `fold_stmts` had the arm; the narrow /
>   wide refactor dropped it).
>   (3) **Pins follow behaviour, not a frozen input spelling.** The
>   estree test pinned the runtime call's old name `pipelineSync`; the
>   capture path emits `pipelineCaptureSync` — pin updated. go/zig's
>   `if_arith_test` fed a single-site `x`, which the shared const pool
>   now seeds, so `y=$((x+1))` folded to `y = 4` at lowering and the
>   arith ASSIGN the pin exists for could never render; both inputs
>   gained a second runtime-guarded site (`[ -n "$1" ] … x=9`) that
>   keeps `x` symbolic while BOTH asserts (arith condition + arith
>   assign) stay meaningful. The rust twin already carried that shape.
>   (4) **c_backend: the GMP sorted-join helper's definition gate was
>   missing one of its two callers.** `_sh_sorted_bigint_join`'s
>   definition sits behind `if !array_return_fns.is_empty()` in
>   `emit_runtime`, justified by “it is only ever CALLED for an
>   array-return function” — but `sorted_join_call` and its inline twin
>   emit the CALL unconditionally at every `sortedBigintJoin` value
>   site (setting `need_gmp`, never opening the gate). A top-level
>   `echo $(sortedBigintJoin a)` therefore linked against a symbol
>   nobody defined, and the `mpz_cmp`-presence pin
>   (`c_backend::tests::sorted_join_nodes_lower_natively`) went red
>   somewhere between the 10-28 21:54 green run and the 10-29 03:00
>   baseline. Fix: an exact `sorted_bigint_join_used` flag set at both
>   render-time call sites — body render precedes `emit_runtime`, so
>   the gate reads a final fact — deliberately NOT widened to
>   `need_gmp`, so the cli_hygiene regression the gate exists for
>   (`mpz_t` without `<gmp.h>` on a program with no bigint) cannot
>   return: `bash-o4 cli_hygiene` 2/2 green after the change.
>   (5) **Two wrong-answer bugs in shared shIR passes, from this
>   round's earlier interrupted turns.** `dead_store_elim`'s census now
>   treats a store-key-shaped string literal (`setArray("t1", …)`,
>   `x = "t1"`) as the dynamic READ it is — a name flowing as data
>   resolves against the store at runtime, and without the mark the
>   pass judged `t1` never-read and DELETED its definition (the
>   t84-tuple-field empties; core-requests/stalled/
>   rust-20261029-011959) — while a Call's `args[0]` (the command /
>   write's own NAME) is no longer counted as a read, which had been
>   switching the whole pass off. `copy_propagation` now counts
>   `${NAME=word}` / `${NAME:=word}` expansions (and a `param` write
>   anywhere in the RHS) as def sites: the write used to be invisible,
>   so `x=""` kept count==1 and the fold propagated a stale literal
>   ACROSS the write — `echo ${x:=d}` printed the pre-write value in
>   every backend. Both edits only ADD refusals (conservative
>   direction); the corpus and lib gates below hold with them in the
>   tree.
>   (6) **Instrumentation removed.** The `tmp_probe_empty_body` test
>   (a `panic!("probe done")` diagnostic) and all six `SH2_PROBE` env
>   blocks in `shir.rs` (pre/extend/stage prints + the For-slot dump)
>   are gone; `zz_probe3` predates this session (it is in HEAD) and
>   stays.
>   (7) **Verification of record.** `./fail` **563/563, 0 failed**;
>   full `./fail-estree` **PERL 563/563 + ESTREE 563/563 (100.0%)**;
>   `fail-rs` **556 pass / 0 fail / 7 skip** (fresh run — the stale
>   03:30 verdicts log was archived to `verdicts.log.pre-1150` so the
>   resume logic could not re-count old verdicts against the new
>   binary); `py-rust-gate` **98/103** (the documented t104/t82/t87
>   reds + 2 known-gap, byte-identical to its recorded baseline);
>   `c_gate_main` **588/56/7 with a FAIL set byte-identical to the
>   10:14 same-day baseline**; `cargo test --lib` **1840 pass / 48
>   fail / 5 ignore** — the 03:00 baseline carried 54 reds, this round
>   cleared 5 in the triage + 1 with the GMP gate, and the final set
>   diff shows exactly those removals and nothing new; bash-o4
>   `cli_hygiene` **2/2**. Core worker **GREEN** (gates 10:00 / 10:29 /
>   10:58, A1 invariant 555 probed / 0 violations / 0 probe-failures,
>   supervisor up 1d9h — its 10-27 isolated-build failures are
>   recovered). The remaining 48 lib reds are the documented
>   pre-existing set (c_backend/estree/fish/shir pins, several owned by
>   other lanes' uncommitted in-flight edits — `c_backend.rs` was
>   rewritten by its lane at 11:56 while this round worked, which is
>   why the triage diffs against same-day baselines rather than a
>   day-old snapshot). Gitlink deliberately not bumped (worktree
>   carries other workstreams' edits).
> - v100: **The emitted Rust's largest idiom class — `print!` with a
>   trailing newline — goes to ZERO (837 → 0), and the shared
>   `interp-lit-merge` shIR→shIR offer is accepted by Rust now that the
>   reason it declined is fixed at the source.**
>   (1) **CENSUS r14 + a new instrument.** Fresh 563-file corpus, rustc
>   default lints: 0 compile errors, 9 warnings (byte-identical kinds to
>   r9–r13), 1.72 MB. rustc's own lints were exhausted, so this round
>   added a **clippy census** (`clippy-driver` per emitted file, default
>   lint set) over the whole corpus: **638 lints**. The histogram said
>   the debt was NOT in casts — one `unnecessary_cast` corpus-wide — but
>   in the PRINT spelling: `print_with_newline` alone was **312**, half
>   the total, then `useless_vec` 73, `unnecessary_to_owned` 36,
>   `print_literal` 32, `format_in_format_args` 31, `needless_borrow` 27,
>   `get_first` 21.
>   (2) **Why it was systematic.** Two arms (the const-echo fast path and
>   the `Output { Str }` arm) build the line WITH its newline and always
>   chose `print!`; the 707 other `println!` sites came from everywhere
>   else — so the macro depended on WHICH arm rendered the statement,
>   never on the line's shape. 837 of the 1064 `print!` sites ended in
>   `\n`.
>   (3) **Both arms now emit `println!`** when the line carries its
>   trailing newline (byte-identical through the same `Stdout`, so
>   buffering and ordering are unchanged), and ONE final-text sweep —
>   `print_to_println`, string/char/comment-aware, REFUSE > GUESS — closes
>   the class for every other source (the folded constant `printf`, a
>   render-time-constant format, any arm added later). The sweep walks a
>   literal body pair-by-pair, so a body ending in an ESCAPED `\n`
>   (`"a\\\\n"` = `a`,`\\`,`n` — no newline at all) is refused rather than
>   mis-trimmed, and a `print!` merely MENTIONED inside a string or a
>   `//` comment cannot start a group. `print!("\n")` becomes `println!()`
>   rather than `println!("")`.
>   (4) **The shared win: `interp-lit-merge` accepted by rs/rust.** The
>   marketplace entry was gated to `zig` only, and its own comment records
>   why Rust declined: *"rust expects a `println!` where it now emits a
>   direct `print!`"* — the merge froze the word, the constant echo
>   reached the `Output { Str }` arm, and that arm spelled the line
>   `print!("…\n")`. (3) fixes exactly that at the source, so the offer
>   lands for the target that refused it. Payoff measured on the corpus:
>   **155 redundant shIR nodes** — 45 `Interpolate` parts whose expr is
>   already a frozen literal `Str`, 103 single-literal `Interpolate`s and
>   7 multi-literal ones — each re-rendered as a format/slot split for
>   text that is ONE constant, by EVERY backend (Perl, C, ESTree/JS, Go,
>   Python, Java, …). After the change the example reads
>   `println!("Echo result: Hello from backticks")`: the merge fired AND
>   the line is idiomatic.
>   (5) **Pins follow behavior, not spelling.** 12 `rust_backend` tests
>   pinned `print!("s1\n")`; they now pin `println!("s1")`, and the
>   case/echo tests that only care a WORD printed go through a new
>   `prints_word` helper accepting BOTH spellings, so the next macro
>   choice cannot re-break them. One new test,
>   `print_with_trailing_newline_becomes_println`, pins the sweep's nine
>   cases (literal-only, with-args, `eprint!` twin, no-newline refusal,
>   escaped-`\n` refusal, one-of-two trim, string-literal mention, `//`
>   comment, empty line).
>   (6) **Verification.** `./fail` **563/563, 0 failed**; `fail-estree
>   --gate` **563/563** (PERL 563/563 and ESTREE 563/563 both);
>   `fail-rs` **556 pass / 0 fail / 7 skip** (green on the final binary);
>   `cargo test --lib` **1894 passed / 51 failed** against a 1886/51
>   baseline — **zero new rust_backend failures** (all 12 pins green),
>   two baseline reds now green, and the only 2 new names
>   (`c_backend::tests::{ver_emits_fast_slow_clones,
>   unsigned_mod_refuses_negative_capable}`) reproduce in ISOLATION and
>   belong to another lane's uncommitted `c_backend.rs` (+2813/−364,
>   written 20:18, after this round's edits). clippy **638 → 306 (−52%)**,
>   `print_with_newline` **312 → 0**; rustc 9 warnings (identical kinds),
>   0 errors, 332/563 files byte-improved, +7 bytes total. Core worker
>   **GREEN** (21:59 gate, supervisor alive, no `sleeping-*` markers).
>   Left for next round: `useless_vec` (73 `&vec![…]` word arrays),
>   `unnecessary_to_owned` (36 literal `.to_string()` args), `get_first`
>   (21 `.get(0)`) — all render-site idioms.
>   **HAND-OFF STATE (23:0x): the shared checkout stopped building at
>   22:34, NOT from this round.** Another workstream rewrote four modules
>   (`unreachable_after_exit.rs` — `terminates_list` deleted, 127 lines
>   left; `string_accumulator.rs` — `callee_write_sets`/`Cw` deleted;
>   `dead_store_elim.rs` — `census`/`is_shell_implicit`/`expr_pure` and
>   `split_inplace::exported_names` de-`pub(crate)`ed) while their two
>   consumers still call the old API (`rust_backend.rs` ×3,
>   `arr_load_fwd.rs` ×1 imports) — and `arr_load_fwd.rs` was still being
>   rewritten at 23:07, so the lane is mid-edit. 8 compile errors, all
>   named after symbols that lane removed; the CORE WORKER independently
>   logged *"main checkout does NOT build (every backend probe will
>   fail)"* at 22:50. Every gate number above was measured BEFORE 22:34,
>   on a build containing this round's changes (CLI built 21:54), and all
>   three equivalence gates plus both censuses were green on it. Nothing
>   of this round's was reverted: `print_to_println`, the two `println!`
>   arms, `prints_word`, and the `Some("zig" | "rs" | "rust")` manifest
>   line are all still on disk. The breakage was left to its owner —
>   repairing it here would mean inventing that lane's new API mid-write.
> - v99: **ONE exhaustive huge-constant/bigint verdict family replaces ten
>   drifted private walkers; the shared descent gains `AnyNode::Stmt` plus
>   full-visit `*_each`, and `typeset -f` stops dropping folded `echo`
>   statements.**
>   (1) **CENSUS r13.** Fresh 563-file corpus, rustc default lints: 0
>   compile errors, 9 warnings (byte-identical kinds to r9–r12), 1.72 MB
>   emitted. The emitted-Rust SURFACE is unchanged by this round — all
>   563 files are byte-identical to the pre-change render — so the work
>   went to the layer BELOW emission: the typing/polyfill DECISIONS.
>   (2) **The bug class.** Ten private descents over `IrStmt`/`IrExpr`/
>   `ArithAst` all answered "is this program's arithmetic too big for an
>   i64?" — seven in `rust_backend` (`stmts_have_huge`,
>   `walk_bigint_stmts`/`walk_bigint_expr`,
>   `collect_huge_literal_assigns`, `collect_all_assign_targets`, and the
>   inline `has_huge_call`/`collect_targets`/`has_huge_arg`), two in
>   `c_backend` (`walk_body_bigint`/`walk_expr_bigint`), plus
>   `analyze_bigint_vars`' own `harvest` in shared `shir`. Every one
>   carried `_ => {}` over `IrStmt`, and they disagreed about which forms
>   exist: rust's taint walker had no `Case`, `Exec`, `Output`, `Try`,
>   `ForInit`, `Background` or `Capture` arm; `stmts_have_huge` had no
>   `Case`/`Try`/`Select`/`Declare`; `harvest` — SHARED by the C, Zig and
>   Rust storage selection — had no `Pipeline`/`Select`/`Exec`/`Output`/
>   `Declare`/`Asm` arm and never opened a `Try`'s `excepts`. A constant
>   a walk cannot see is a constant the backend renders as wrapping `i64`
>   where bash needs an unbounded integer: a silent wrong answer, not a
>   loud one. Measured on `case $x in a) n=$((2**70));; esac` — before,
>   `n` is never tainted by any of the three rust walks; now it renders
>   `num_bigint::BigInt::from(2i64).pow(…)`.
>   (3) **The fix, in shir.** `AnyNode` gains `Stmt(&IrStmt)`, yielded
>   BEFORE its children, so a parent-aware rule (an `Assign` whose RHS is
>   an `Arith`) can sit on the shared descent instead of keeping a private
>   statement walker — and a private statement walker is exactly the bug.
>   `stmts_each`/`expr_each`/`program_each` are one-line wrappers over
>   `*_any`, so a full-visit walker CANNOT drift from the early-exit one:
>   one traversal, one exhaustiveness guarantee. `arith_eval_bigint` moves
>   out of `rust_backend` (ten call sites there, no equivalent anywhere
>   else), with `arith_is_huge` as the single "too big for an i64" test
>   (previously the same five lines spelled inline at every call site) and
>   the shallow/deep pair `expr_huge_lit`/`expr_has_huge_lit` +
>   `stmts_have_huge_lit`.
>   (4) **Rewired: ~380 lines of private catch-all walker leave the tree**
>   (rust_backend −281, c_backend −100); each backend keeps only its
>   per-node RULE. `collect_bigint_vars`' coarse half subsumes three
>   overlapping older rules AND now counts `prog.subs` — a huge constant
>   inside a function body was invisible to the program-wide marking.
>   (5) **The one `fail-rs` red was NOT this round's change, and was
>   fixed anyway.** A/B proof: the pre-change render of all 563 files is
>   byte-identical to the post-change render, and compiling the PRE-change
>   render reproduces the same diff. Root cause: `echo_fold` lowers a
>   literal `echo` to `IrStmt::Output`, and `fn_body_line_text` — which
>   reconstructs a body for `typeset -f` — had no `Output` arm, so every
>   literal echo became an empty line and the display printed a stray `;`
>   where bash prints the statement. It now reconstructs `Output` with
>   the call form's quoting rule, and REFUSES any value it cannot spell
>   rather than guessing an argument it did not read.
>   (6) **Verification.** `./fail` **563/563**; `fail-rs` **556 pass / 0
>   fail / 7 skip** (baseline; was 555/1/7 with `typeset-cmdsub` red);
>   `fail-shir` clean (563 scanned, 556 bash-free, 1 normalisable in
>   whitelist); `py-rust-gate` **98/103 baseline-identical** (same 3
>   documented reds t104/t82/t87 + 2 known-gaps); `cargo test --lib`
>   **1895 passed / 49 failed — byte-identical to the saved r11
>   baseline** (zero new, zero lost), with **6 new tests** pinning the
>   fixed holes: `shared_descent_verdict_tests` (Stmt-before-children,
>   `stmts_each` into a `case` clause, `arith_is_huge` range,
>   shallow-vs-deep, `harvest` reaching a `Try`'s `excepts`),
>   `body_has_bigint_arith_sees_through_a_command_substitution`, and
>   `typeset_dash_f_prints_a_folded_echo_statement`. Core worker
>   **GREEN** (15:36 gate, supervisor alive, no `sleeping-*` markers).
>   Deliberately left: `sh_backend::needs_arr_helper` (no `Capture` arm —
>   same class, but moving it needs the render-body architecture above
>   the prologue) and the 27 unused `_arr_*` prologue blocks.
> - v98: **ONE exhaustive shIR descent (`shir::program_any`) replaces the five
>   drifted private polyfill walkers; sh's undefined-`_readlink` bug (3 broken
>   renders) is fixed, ~540 lines of walker leave the tree, and the emitted
>   Rust drops a dead-`__r` binding class.**
>   (1) **CENSUS r10/r12** (fresh 563-file corpus, rustc default lints): the
>   Rust surface is stable and exhausted — 9 warnings (byte-identical kinds
>   to r9/r10), `unreachable statement` still **0**, 0 compile errors, 0 dead
>   helper fns, 115 `as` casts all type-required. The shIR is folded too
>   (0 all-literal `Interpolate`, 0 `Not(Not)`, 103 single-part Interpolates
>   only). Census therefore pivoted to the **polyfill-decision layer** —
>   where a NEW instance of the v97 drift class was found. (2) **The bug.**
>   `needs_readlink`/`needs_cmp` existed twice (sh, zsh) alongside
>   `needs_hostname`/`needs_word_split` (zsh) and `needs_arr_helper` (sh):
>   five private descents over the same three enums, kept in step by hand.
>   sh's `needs_readlink` had **no `Capture` arm**, so `x=$(readlink -f …)`
>   never fired the prologue while the call-site renderer still emitted
>   `_readlink -f …` — measured **3 of the 1054 sh/zsh corpus renders call a
>   function they never define** (`readlink_relative`, `readlink_flags`,
>   `readlink_example`: `_readlink: command not found` → an empty capture).
>   zsh's copy HAD the arm and was correct — textbook drift. And NO copy had
>   an `IrStmt::Exec` arm, though the corpus carries 71 of those statements.
>   (3) **The hoist.** `shir::AnyNode` (`Expr` / `Arith` / `Cmd`) plus
>   `shir::program_any` / `stmts_any` / `expr_any` own the descent, with **no
>   `_ =>` catch-all on `IrStmt`, `IrExpr` or `ArithAst`** — every variant is
>   named, so growing any enum is a COMPILE ERROR here instead of a silently
>   missing arm in N copies; the two `Ext` arms recurse through the node's
>   own generated `children()`. `Cmd` exists because a command reaches the
>   IR from two shapes (`Expr(Call{func:"exec"|"builtin"})` and
>   `IrStmt::Exec`) and only a predicate that sees both can mirror the
>   renderer's one `exec_line_to_sh` path. On top of it:
>   `shir::readlink_flag` (was 2 byte-identical copies),
>   `shir::program_needs_readlink` and `shir::program_needs_cmp` (exact duals
>   of the render-time rewrites, `builtin` accepted alongside `exec` so the
>   answer does not depend on whether `fallback_builtin_to_exec` has run).
>   sh and zsh now delegate; zsh's `needs_hostname`/`needs_word_split`
>   collapsed to per-node predicates on the shared descent. **~540 lines /
>   20 KB of private walker deleted**; also removed the dangling
>   `expr_containers` doc-comment a v97 deletion had left glued onto fish's
>   `body_calls`. (4) **Emitted-Rust idiom.** The 165 `let (__c, __r) =
>   __sh_capture_rc(…)` sites bind an `__r` nobody reads once the status
>   store is stripped (129 of them block-dead) — rustc stays silent only
>   because `__r` starts with `_`. New `rust_backend::
>   underscore_unused_capture_rc`, run after every rc strip and before `-Oz`
>   golf, spells it `(_, …)` … **but only when EVERY word-bounded `__r` in
>   the file is a destructure binding** (count-vs-bindings, boundary-checked
>   on both sides so `__rc`/`__r2`/a `__r` inside a shell-out string never
>   count): 33 bindings rewritten corpus-wide, 0 risk of renaming a live
>   one. (5) **Verification:** 12 new verdict tests + the 7 grep_p ones =
>   **19/19**; new `dead_capture_rc_binding_becomes_an_underscore` **passes**;
>   prologue call/def parity over 1054 renders **missing 3 → 0**; `./fail`
>   **563/563**; `fail-rs` **556/0** (7 pre) — the underscored Rust compiles
>   and behaves identically corpus-wide; `fail-estree` **563/563 both**;
>   `fail-shir` rc=0; py-rust **98/103** (t104/t82/t87 pre-existing); full
>   cargo **1888 pass / 49 fail** — failure set byte-IDENTICAL (empty diff)
>   to the pre-round baseline, none in this round's files; sh/zsh suites
>   23/0, 20/0, fish 24 pass / 5 fail (the same pre-existing set). Core
>   worker **GREEN** throughout (13:34:22), no trap markers — no fix needed.
>   A transient red on `typeset-cmdsub.sh [perl]` was traced to a peer's
>   in-flight `perl_generator_fixed.rs` edit: this round's API has **zero
>   callers off the sh/zsh/fish path** (proved by grep), and the test went
>   green the moment their edit landed. (6) **Deliberately left:** the 27
>   unused `_arr_*` prologue blocks (a per-helper split needs the `_num`
>   render-body architecture moved above the prologue) and 132 remaining
>   `__r` bindings (the file-level rule is all-or-nothing per file; a
>   block-scoped count needs string-literal-aware brace matching).
> - v97: **The grep-P polyfill verdict becomes ONE shared shIR judgment
>   (sh/zsh/fish had three drifted copies — two of them BUGGY), fish's
>   pattern-slot fix is ported to the sh/zsh render paths, and ~510
>   lines of private walker leave the tree.**
>   (1) **The drift, found by census.** `needs_grep_p` existed three
>   times (sh/zsh/fish) plus `ere_safe` three times; the copies had
>   diverged. Only fish's copy scanned for the PATTERN after `-P`
>   (`grep -Pc PAT` puts `-c` in the fixed `words[i + 1]` slot,
>   `ere_safe("-c")` answered true, so the prologue never shipped and
>   the rendered `grep_p` call died `command not found`); sh and zsh
>   both still had that bug. The descents also differed: fish fell
>   through to a generic container walk, zsh alone had `Capture` /
>   `Interpolate` / `ForEachLine` arms (sh missed
>   `x=$(echo hi | grep -P …)` entirely), and NO copy descended `Try`
>   bodies. (2) **The hoist.** `shir::program_needs_grep_p` +
>   `shir::grep_p_ere_safe` now own the verdict: union of the three
>   descents + fish's pattern-slot fix + one deliberate addition (`Try`,
>   over-approximating only ever KEEPS the inert prologue, while a miss
>   is a runtime `command not found`). The three backends delegate
>   (sh/zsh keep a thin `ere_safe` wrapper for their render-time `-E`
>   lowering; fish's dead `expr_containers` deleted with its private
>   copy): 156+171+174 lines of walker + 10 of fish's ere_safe removed.
>   (3) **Render side, same bug class.** sh/zsh also read a fixed
>   `pidx + 1` when choosing `grep -E` vs `grep_p` — `grep -P -c
>   '(?=…)'` chose `-E` on `ere_safe("-c")` and a lookaround pattern
>   silently matched NOTHING (fish's documented fqdn-count=0 bug). The
>   fish fix (scan forward for the first non-flag word) is ported
>   verbatim to both. End-to-end on `grep_p.sh`: all three targets now
>   emit the prologue AND `grep_p -c '(?=…)'` where sh/zsh previously
>   shipped `grep -E -c` with no prologue. (4) Verification: 7 new
>   shared-verdict tests (combined-flag slot, ERE-safe negative, PCRE
>   positive, pipeline Arrow, Capture, Try, ere_safe classes) all pass;
>   sh 23/0, zsh 20/0, fish 24 pass/5 fail — the 5 byte-identical to
>   the pre-round baseline (peer fish churn: array/case/positional +
>   the two grep_p tests were already red); `./fail` **563/563**,
>   `fail-rs` **556/0** (7 pre), `fail-estree` **563/563 both**,
>   `fail-shir` rc=0, py-rust 98/103 (t104/t82/t87 pre-existing), full
>   cargo 1875 pass / 49 fail — failure set byte-IDENTICAL to the
>   pre-round baseline (empty diff). Emitted-Rust corpus r9 unchanged:
>   9 warnings, `unreachable` still 0. Core worker GREEN (07:07:06) —
>   no fix needed.
> - v96: **c_backend stops re-deriving the PIPESTATUS verdict: it now asks
>   the SHARED `shir::program_observes_pipestatus` — two of three
>   backends agree by construction, and the private walker (which could
>   silently under-detect) is deleted.**
>   (1) **The generalisation.** Rust already set `pipestatus_dead` from
>   the shared verdict (a substring scan of the IR's Debug form — its
>   doc argues at length why a hand walker is the WRONG shape: a missed
>   read form is a silent wrong answer, since the register then never
>   fills and the read answers 0). C's `need_pipestatus` was set by a
>   private `scan_ps_expr`/`scan_ps_stmts` pair that matched ONLY the
>   lowered `param("PIPESTATUS[…")` read shape and had no `Function`/
>   `Case`/`Try`/`ForInit` arms and never touched `prog.subs` — a
>   PIPESTATUS read inside a (kept, called) function body left the
>   state-import tail unshipped and the read returned 0. The scan is
>   replaced by one call to the shared verdict (c_backend.rs:35595);
>   ~80 lines of walker deleted; the field doc now points at the
>   verdict. New c test `pipestatus_read_inside_a_function_arms_the_
>   state_import` pins it, A/B-verified: it FAILS with the old
>   scanner's answer (`false`) and passes with the verdict. Perl needs
>   no swap: its `fix_literal_pipeline_pipestatus` is a different job
>   (populating `@PIPESTATUS` for literal-true/false pipelines, a 070
>   correctness splice), and its declaration machinery keys off
>   referenced names, not a dead-capture verdict. (2) **Emission-Rust
>   census r8**: 563 files, rustc default lints = 9 warnings, stable
>   vs r7, `unreachable statement` still 0; no new warnings from this
>   round (the `InterpPart` unused-import warning visible in the build
>   is zsh_backend.rs:16, a peer's file). (3) Verification: `./fail`
>   **563/563**, `fail-rs` **556/0** (7 pre), `fail-estree`
>   **563/563 both**, `fail-shir` rc=0, py-rust 98/103 (t104/t82/t87
>   pre-existing), c_backend tests 167 pass/8 fail — the 8 byte-
>   IDENTICAL to the pre-round baseline, full cargo 1868 pass / 49
>   fail — the failure set byte-IDENTICAL to the pre-round baseline
>   (diff empty), none in this round's files. Core worker GREEN at
>   round start (06:23:13) — no fix needed.
> - v95: **The emitted-Rust `unreachable statement` class reaches ZERO via
>   the shared verdict; the flow-sensitive DSE's two leftover warnings
>   are measured and deliberately refused; every gate green.**
>   (1) **CENSUS** (fresh 563-file corpus, rustc default lints, rounds
>   r5→r7): 115 cast sites across 44 files are ALL type-required
>   (`unnecessary_cast` never fires — `len() as i64`,
>   `[idx as usize]`, `bool as i64` are the runtime's value types, not
>   boilerplate), so casts are not an idiom surface. Warning surface
>   11 → 9 with `unreachable statement` 2 → 1 → **0**. (2) **Rust
>   renderer behind the SHARED verdict**: a redirect region whose
>   inner list provably never falls through (096's `while true`
>   producer, a trailing `exit`/`return`) no longer emits its `post`
>   restores — rustc had reported 096's OUTFILE restore
>   `unreachable statement`. The guard asks the SAME
>   `unreachable_after_exit::terminates_list` the loop-tail RC capture
>   and the function value tail ask (`in_loop:false`, the
>   conservative reading), and the paired save bindings are scrubbed
>   to `let _ = …take()` so the fix cannot trade the unreachable
>   warning for an unused-variable one. Both emission paths
>   (process-substitution thread + ordinary block scope) are guarded;
>   2 new rust_backend render tests pin infinite-drops /
>   finite-keeps. Perl/C/JS need no equivalent: their restores are
>   `local`-scoped (implicit) or per-target synthesised — only Rust
>   mints an explicit restore statement. (3) **Deliberate refusals**:
>   the two surviving `value assigned … never read` sites are not
>   shIR-fixable today — arith-postfix's `((i++))` store has a LIVE
>   status half (the `$?` read observes it), so only a status/value
>   split could drop the value half, and parse-longoption's `|| X=0`
>   store ends a status block, where dropping it would change the
>   block's exit status; dead-function elimination is refused because
>   `--library` EXPORTS function defines never called internally;
>   the snake-case warnings are correct (user function names), and
>   the `IFS` store is the documented SHELL_IMPLICIT keep. (4)
>   Verification: `./fail` **563/563**, `fail-rs` **556/0** (7 pre),
>   `fail-estree` **563/563 both**, `fail-shir` rc=0 (311 bytes),
>   py-rust 98/103 (t104/t82/t87 pre-existing), rust_backend tests
>   **170/170** (2 new), full cargo 1867 pass / 49 fail — ZERO new
>   vs the pre-round baseline (51 → 49; peers fixed 2), none in this
>   round's files (estree 24 / shir 11 / c 8 / fish 5 / roundtrip 1,
>   all peer-owned concurrent edits). Core worker GREEN at round
>   start (05:29:49) and still running at close.
> - v94: **Two more unreachable-tail classes die in EVERY backend via the
>   shared predicate — an infinite-loop terminator and a diverging-chain
>   fold — plus `pass` now always recurses; all equivalence gates green.**
>   (1) **SHARED** `unreachable_after_exit`: `While{cond:true}` /
>   `DoWhile … true` / `until … false` terminates the list it sits in
>   when a deliberately paranoid escape scan finds nothing that can
>   leave it (break/continue/return/exit calls, breaks threaded by
>   depth so NESTED-loop breaks don't count, a function DEFINED in the
>   body scanned because a call can fire it, `eval`/`source` and the
>   opaque `RawText`/`Goto`/… nodes refuse). That prunes the Rust
>   backend's synthesized outfile restore behind
>   `head <(while true; …)` (096_head_procsub) and the same epilogue in
>   every other renderer — the pass accepts both the folded `Bool` and
>   the raw `true`/`:` command spelling, so the verdict never depends on
>   `const-condition-elim` registration order. (2) Same file,
>   `A || B` / `A && B` with a diverging `A` (`break || exit 1`,
>   parse-break-or) folds to `A`: the real terminator becomes visible
>   to the pass and no backend renders the dead right-hand side (Rust
>   had emitted `{…; break; }; __SH_RC.store(…); if !__b { exit(1) }`).
>   Gated per target: break-chains only inside a loop, return-chains
>   only inside a function. (3) `pass` restructured: the terminator
>   verdict is taken from the ORIGINAL statement, then `rebuild` always
>   recurses into nested lists — an infinite loop terminates its own
>   list while its body can still hold dead tails
>   (`while true; do continue; echo dead; done`), and computing the
>   verdict BEFORE rebuild stops a pruned `break` from retroactively
>   making its loop look infinite. (4) Verification: `./fail`
>   **563/563**, `harness/fail-rs` **556/0** (7 pre-existing skips),
>   `./fail-estree` **PERL+ESTREE 563/563**, `./fail-shir` rc=0 (311
>   shell-out bytes ≤ 2000), py-rust-gate 98/103 (t104/t82/t87
>   pre-existing), pass tests **26/26**. Full sh2perl cargo test 1863
>   pass / 51 fail, PROVEN not this round: a temporary transform-off
>   probe reproduced the identical 51 (its own delta was 13
>   unreachable_after_exit tests failing only BECAUSE the pass was
>   off) — every failure is owned by concurrent peer edits
>   (c_backend/estree/fish/shir/arr_load_fwd). Core worker GREEN
>   (04:49:08, `gate GREEN (A1 native + estree corpus + lib tests)`);
>   no fix needed.
> - v93: **The python callout census drops another ~40%, a shared
>   `exec-call-fold` transform retires the two-carrier split for every
>   backend, and the whole multi-backend sweep moves DOWN two
>   equivalence failures (143 → 141 real; python stays 0/563).**
>   (1) **SHARED** `transforms/exec_call_fold` (registered LAST in
>   `transforms::all()`): the payload-free `IrStmt::Exec` inside a
>   COMMAND CARRIER — an arrow body, a pipeline stage, and everything
>   nested in one — folds to the canonical
>   `Expr(Call{func:"exec", args:[cmd, Array(argv)]})` spelling. The
>   two carriers are the same command, but the backends' compound-
>   context replayers were written against the Call form: go's
>   `cmd_text` answers `None` for `IrStmt::Exec` (and its `stmt` arm
>   marks it `TODO(unsupported): stmt Exec {…}`), python's
>   `body_shell_text` / `pipeline_run` / `pipeline_head_value` /
>   `capture_body_is_native` match only `Expr(Call{exec|builtin})`,
>   and perl's native-capture whitelist is keyed on the Call form too.
>   sh/zsh/fish/java arm `IrStmt::Exec` explicitly, which is why this
>   is one rewrite of the IR rather than five backend patches. REFUSE
>   > GUESS: a capture channel, a redirect set or a command-scoped env
>   keeps its carrier (the call form has nowhere to put them), and
>   `shir::is_ps_tmp_cleanup`'s synthetic `__ps_tmp` cleanup keeps its
>   carrier as well — every renderer recognises THAT statement by
>   shape to save/restore the consumer's status around it. Corpus:
>   all 71 `Exec` statements are payload-free (44 `mktemp` in arrow
>   bodies, 27 `rm` cleanups), so the fold reaches 44 sites and the
>   predicate refuses the 4 cleanups that sit inside a carrier.
>   Target-gated in `transform_applies`: open to every code-generating
>   backend, `shir` excluded so the byte-pinned A1 export keeps its
>   statements (capture-node-fold/case-lowering precedent) — the
>   renderers still see the fold, because `shir_render` binds no
>   target and a direct render binds the backend name. 4 new tests.
>   (2) `python_backend`: `body_shell_text` became the recursive
>   `shell_parts`, which rebuilds the statement shapes it used to
>   refuse — `Exec` (argv + redirect set + `VAR=x` prefix),
>   `Subshell` → `( … )`, `Block` → the same sequence, `Redirect` →
>   `cmd <redirs>` (a multi-command body wrapped `{ … ;} >f` so the
>   set binds the whole group), `Output` → the `echo`/`printf` it
>   came from, `For` → `for x in …; do …; done`, `Pipeline` →
>   `A | B`, plus nested `Call{pipeline}` / `Call{redirect}`. Three
>   previously-duplicated reconstructions collapsed into the one
>   helper: the `redirect` call arm, `capture_redirect` and
>   `pipeline_run`'s new last-resort stage path all call it, so a
>   redirect seen three ways cannot drift apart. `sh_arg`'s param arm
>   became `sh_param_syntax` (mirroring ir.rs's `bash_param_syntax`,
>   with a safe-word guard): `${cmd[@]}` / `${map[foo]}` / `${@:3}`
>   are native shell words the child expands, where the old
>   plain-identifier guard refused and the whole capture fell to a
>   stub — realpath-cmdsub's `stdout=$("${cmd[@]}" 2>/tmp/x.$$)` used
>   to reach `sh2_capture()`.
>   (3) Measured over the 563-file corpus (gate path
>   `otranspilerl --target shir | shir_render --target python`):
>   `sh2_arrow` 97 → 27, `sh2_capture` 90 → 38, `sh2_pipeline` 35 →
>   17, files carrying `TODO(unsupported)` 109 → 82, lines carrying an
>   `sh2_*(` call 405 → 267; syntax 562/563 (051_primes
>   pre-existing); `./fail` 563/563. Full
>   10-backend sweep before/after: c 2 → 1 (062_10_simple_pipeline),
>   java 62 → 61 (background-chain), perl/rust/python/go/zig/sh/fish
>   unchanged, estree 4 = 4 (its two extra lines in the concurrent
>   sweep were contention flakes — an isolated rerun and a per-file
>   rerun both land on the baseline four). Two real equivalence
>   fixes came from a change aimed at python: the shared fold also
>   unblocked c's and java's arrow-body replay.
> - v92: **The shared terminator verdict learns `break`/`continue`, and
>   two more unreachable-code classes leave the emitted Rust — real
>   rustc warnings 13 → 11 this round (40 → 11 measured from v90's
>   round-start baseline).**
>   (1) **SHARED** `transforms/unreachable_after_exit`: `terminates_list`
>   gained a third parameter `in_loop` and the arm
>   `IrStmt::Break | IrStmt::Continue => in_loop`. A `break`/`continue`
>   ends the list it is a DIRECT element of, exactly as `return` ends a
>   function body, so a statement left after it in the same loop body is
>   dead in EVERY target. The flag is what makes that sound: a `Break`
>   whose enclosing list is not a loop body (top level, a function body,
>   a subshell, a background job) has no loop to leave and a backend is
>   free to render it as a no-op, so the predicate REFUSES rather than
>   assumes. `pass` threads it exactly as it already threads `in_fn`:
>   `For`/`While`/`DoWhile` set it, `Function`/`Subshell`/`Background`
>   clear it (contained exits), `If`/`Case`/`Block` inherit it (they are
>   transparent for control flow). 5 new tests; 18 total, all green.
>   (2) `rust_backend` now CONSUMES that shared verdict through a new
>   `body_terminates` helper, guarding the rc-capture epilogue in all
>   FOUR loop renderers (expression-`while`, statement-`while`,
>   `DoWhile`, C-style `for`). Each used to emit
>   `{last} = __SH_RC.load(…)` after a body ending in `break` — rustc
>   `unreachable statement` (`parse-done-unexpected`,
>   `parse-multi-command-while-condition`). The verdict cannot drift
>   from what the shIR pass would have pruned because it IS the same
>   function.
>   (3) `expr_bool`'s `break`/`continue` arms dropped their trailing
>   `false`: the block's last statement is an unconditional `break`, so
>   no tail value is ever produced. The block is `!`, which coerces to
>   `bool` at every use site the renderer puts it in
>   (`parse-break-or`, `unreachable expression`).
>   (4) **REGRESSION CAUGHT AND FIXED**: the first cut of the function
>   value-tail guard read `self.in_function`, which is reset to `false`
>   BEFORE the tail is emitted — so `terminates_list` silently became a
>   no-op and **17 `unreachable expression` warnings came back**. The
>   guard now passes `true` explicitly (a function body's own last
>   statement is never a loop-level break), with the trap documented at
>   the call site.
>   (5) The two surviving dead stores are recorded as OUT OF SCOPE, not
>   fixed: `dead_store_elim` is deliberately flow-INsensitive (it drops
>   only variables with ZERO reads anywhere in the program), but `i = i
>   + 1` (`arith-postfix-status`) and `X = "0"`
>   (`parse-longoption-with-dollar`) are both read BEFORE the store and
>   never after. Killing them needs flow-sensitive liveness plus the
>   export/escape carve-outs; 2 warnings do not pay for that analysis.
>   Measured over the 563-file emitted corpus, plain rustc default
>   lints (same baseline and method as v90): real warning lines **40 →
>   11**, files carrying any warning **29 → 11**; `unreachable
>   expression` **4 → 0**, `denote infinite loops` **3 → 0**,
>   parens/braces held at **0**, dead inits held at **2**,
>   `unreachable statement` **2 → 2** (the two break-epilogue sites went,
>   `parse-break-or`'s reclassified from expression to statement). `sh2.*` callouts 0, dead polyfill defs 0, casts 113 — all
>   unchanged. The 11 left: 4 dead shell functions and 3 names that are
>   source-level (2 unused vars, 1 snake_case), 2 flow-sensitive dead
>   stores, and 2 genuinely-unreachable statements (code after an
>   infinite `loop`, which needs a no-break-in-body analysis).
>   Gates: `./fail` 563/563, `fail-rs` 556/0/7,
>   `fail-estree --gate` **563/563 rc=0**, `check_qx_shir` 563 ok / 0
>   violations / 0 probe failures, `py-rust-gate` 98/103 (3 FAIL + 2
>   known-gap = unchanged baseline), `cargo test --lib` **1842 pass /
>   50 fail** — failure set byte-identical to the baseline (no new
>   reds). **Gate-flakiness note:** two full estree runs reported 562/1
>   on DIFFERENT files while the box sat at load 43–63 with
>   `cpu some avg10=83%` (four lanes running estree gates at once; the
>   gate's per-test budget is a hard 20 s). Both files pass individually
>   and a clean full run is 563/563 — timeouts, not diffs. Core worker
>   GREEN 12:07:33, A1-native 0 violations / 555 probed, no trap markers
>   — no fix needed.
> - v91: **arr-load-fwd lands on MIMEcroft: the pass-wide closure bail
>   goes, and the forward now removes the store it orphans itself — the
>   function-local copy DSE's multi-run `Const` rule can never take
>   (first-frame −1.87% instructions, frame byte-exact vs bash).**
>   The pass existed and unit-tested, but rendered `MIMEcroft_fb.sh`
>   byte-identically with `SH2_NO_ARR_LOAD_FWD=1` or not. Two gates,
>   found by instrumenting it (`SH2_ARLF_DBG`, since removed):
>   (1) `has_dynamic` refused the WHOLE pass on any `eval`/`source` OR
>   any closure-shaped expression anywhere — MIMEcroft's single
>   `sl_x=$(exec cat …)` (`Capture{Arrow}`) did it. The span rule
>   already buys that soundness precisely: `stmt_refuses` refuses every
>   statement form that can carry a closure/capture (the opaque arm of
>   `expr_refuses`) and every `Exec`, so a forward only ever crosses
>   provably inert statements. The eval/source clause stays (same rule
>   DSE has); the closure clause and its `expr_has_closure` walker are
>   gone — a one-capture 7 000-line program no longer disables the
>   optimization everywhere.
>   (2) The orphaned store was DSE's to drop, and DSE can never drop
>   it: `analyze_var_const` marks every site inside a function body
>   multi-run ("a function may run 0..N times") → `Var` → not `Const`
>   → refused — precisely `rb_mkhex`'s three `rbm_*=${RBHEX[$rbm_*]}`
>   copies (3 string stores × 212 k calls/frame). The pass now sweeps
>   its OWN orphans after the fold, only for vars THIS fold orphaned,
>   under DSE's own standards so the two cannot disagree: DSE's
>   `census` (pub(crate) — the read/escape verdict), DSE's `expr_pure`
>   (pub(crate)), `is_shell_implicit`, plus
>   `shir_passes::split_inplace::exported_names` (env-visible = read
>   by children). Refuse > guess on every axis.
>   Supporting: `READ_ONLY_CALLS` moved to `transforms.rs` as the one
>   shared list both passes consume, and DSE's `expr_pure` learns a
>   read-only helper call (`arrayIndex`, `param`, `listVar`, …) is
>   pure — without it the generic Call refusal kept every orphaned
>   `v = arrayIndex(…)` alive forever. Guards: no `$(`/backtick in a
>   `Str` arg, and no `?` in `param`'s op slot (`${x:?}` aborts the
>   shell — dropping the store would drop the abort with it).
>   Seams: `SH2_NO_ARR_LOAD_FWD` (whole pass) + new
>   `SH2_NO_DSE_CALL_PURE`. Verification: `--first-frame` medians 7
>   interleaved runs/arm under `perf stat -e instructions:u` =
>   2 554 479 151 (on) vs 2 603 063 974 (off) = −48.58 M = −1.87%,
>   every PPM md5 == the bash oracle (`53d9cfa7…`), spread < 0.001%;
>   `./fail` 563/563; c-gate verdicts unchanged ON vs OFF (639 pass /
>   7 skip / 5 pre-existing fail, identical lists); unit suite 1842
>   green, zero regressions attributable to the change.
> - v90: **Every parens/braces class hits zero, the dead value-tail and
>   dead `piece` init go, and `unreachable-after-exit` learns the
>   EXHAUSTIVE `if`/`case` rule — a shared shIR→shIR win every backend
>   inherits.**
>   (1) `rust_backend` render fixes — the rest of `unused_parens` /
>   `unused_braces`: `if`/`while`/`for` conditions, fn-arg parens,
>   `({ block })` return-value braces and `let x = { … }` braces. The
>   brace case matters beyond the lint: a `String` template is NOT a
>   `format!` string, so `{{`/`}}` are emitted verbatim — `$!`'s guard
>   rendered `if __p == 0 {{ … }}`, an if-arm holding a NESTED block.
>   Conditions unwrap through a statement-boundary-aware, string/char-
>   aware matcher so `(a).foo()` receivers and `(a, b)` argument lists
>   keep the parens that carry meaning.
>   (2) `__sh_printf`'s `let mut piece = String::new();` → `let mut
>   piece;`. The conversion `match` is exhaustive (`_ =>`), so every arm
>   assigns and the initializer was a write rustc called dead
>   (`value assigned … never read` — 8 corpus files).
>   (3) **SHARED** `transforms/unreachable_after_exit`: `terminates_list`
>   grew three arms — an `If` with a NON-EMPTY `else` whose every branch
>   (then, each elsif, else) ends in a terminator; a `Case` carrying a
>   bare `*` catch-all whose every clause body ends in a terminator (a
>   quoted `"*"` is a literal two-char pattern and is refused); and a
>   `Block`, whose own last statement decides (`Subshell`/`Background`
>   deliberately stay out — their exits are contained). Why both
>   spellings: 061's dispatch is `case`-SHAPED in shIR and only
>   `case_lowering` turns it into an `if/elsif` chain, so an If-only rule
>   silently did nothing. 8 new tests; 13 total, all green.
>   (4) `terminates_list` is now **`pub`, documented as the one shared
>   "can control fall past here?" verdict**, and `rust_backend` CALLS it:
>   the function value-tail guard was an exact-node `Return`/`Exit`
>   check, which missed the call spelling of `exit` and every exhaustive
>   dispatch — so 061's three functions each got an epilogue rustc
>   reported as `unreachable expression`. Any other backend synthesising
>   a fall-off-the-end return can reuse it instead of re-deriving a
>   weaker check.
>   (5) `while true { … }` → `loop { … }` (3 files): identical
>   `break`/`continue` semantics, idiomatic spelling, and rustc stops
>   asking for it.
>   (6) Repaired another lane's STALE WIP in `src/shir.rs`:
>   `let_args_native_accepts_length_refs` did not compile — it built
>   `vec![s_lit(…), IrExpr::Array(…)]` (`s_lit` returns the ESTree
>   `Expr`, not `IrExpr`) and referenced a nonexistent
>   `crate::shir::Quoting` (`IrExpr::Str`'s second field is `StrStyle`).
>   It broke `cargo test --lib` for the WHOLE tree for ~80 min; fixed to
>   `IrExpr::Str("let", StrStyle::SingleQuoted)`, and it passes.
>   Measured over the 563-file emitted corpus, plain rustc default
>   lints: real warning lines **40 → 13 (−67%)**, files carrying any
>   warning **29 → 13**; parens/braces **13 → 0**, dead inits **11 → 2**,
>   `unreachable expression` **4 → 1**, `denote infinite loops` **3 → 0**.
>   `sh2.*` callouts 0, dead polyfill defs 0, casts 113 — all unchanged.
>   The 13 left are source-level (4 dead shell functions, 2 unused source
>   vars) or need a `break`-awareness rule (3 `unreachable statement`,
>   1 `break; false` block) or a dead-store rule (`i = i + 1`, `X = "0"`).
>   Gates: `./fail` 563/563, `fail-rs` 556/0/7,
>   `fail-estree --gate` 563/563, `check_qx_shir` 563 ok / 0 violations
>   / 0 probe failures, `py-rust-gate` 98/103 (3 FAIL + 2 known-gap =
>   unchanged baseline; a first run showed 4 FAIL only because the CLI
>   binary was being rewritten by a concurrent build), `cargo test
>   --lib` **1832 pass / 50 fail** — the SAME 50-red baseline (estree 23,
>   shir 11, c 9, fish 5, shir_json_in 1), NONE in `rust_backend::tests`
>   or `transforms::*`. Core worker GREEN 07:52:39, A1-native 0
>   violations / 555 probed at 08:04:57, iterating — no fix needed.
> - v89: **Python idiom round 2: sh2 callout sites 704 → 520, honest-
>   unsupported files 163 → 109 (+54 files newly verified green), gate
>   0/563.** New native lowerings in `python_backend.rs`: `fnValue` →
>   `__sh_fnval` (an echo-RETURNED function yields its value, a printing
>   one its captured stdout — bash -c children cannot see python-side
>   function defs, so `body_shell_text` now refuses fn_names and
>   `$(f …)` routes here); `captureWords`/`split` → the ir.rs single-
>   string contract with `*(…).split()` splices in word-list/argv
>   positions; `shopt` → no-op except `nocasematch`, which toggles a
>   probe-gated `__sh_ncm` runtime flag read by `test_render`'s
>   `==`/`!=` (mirrors test_lowering's conservative probe and perl's
>   `$__nocasematch`); `uc/lc/strHasSuffix` → `.upper()/.lower()/
>   .endswith()`; `param("", text)` → getVar delegate + direct python
>   list subscript for `name[expr]` text; `redirect(…)`/general
>   `capture(Arrow)` → bash -c replay (bash performs every fd natively;
>   the old sys.stdout wrap never captured a CHILD's fd-1 — the fd-1/2
>   wrap fallback now dup2's the real fds, with `__sh_`-prefixed temps
>   because an `_sw`-style temp round-trips through eval's `declare -p`
>   import as a STRING and broke the restore); `shift` in-function →
>   `_sh_args = _sh_args[n:]`; `declare -a name=(…)` emits its setArray
>   initializer; cond-nested `assign` targets hoist the module default
>   (walrus NameError); `test`-family execs keep their bool verdict out
>   of the `(b or 1)` chain-wrap that erased every False;
>   `"$@`-as-command splices listVar words (empty argv → rc 127 in
>   `__sh_exec`); body_shell_text quotes bare `$VAR` test operands
>   (`test $A -ef $B` → one-arg truthy) and `"$@"` replays as a child
>   positional word. Extglob patterns keep an honest `mark_todo` (no
>   python translation — 010/037/at-in-test stay excluded, not blessed).
>   Verified: python gate 0/563, `./fail` 563/563, `cargo test --lib
>   python_backend` 10/10, syntax 562/563 (051_primes pre-existing).
>   Shared shIR→shIR: no landing spot this round — param/captureWords/
>   fnValue/redirect are consumed per-backend, all edits backend-local.
> - v88: **The last 5 `unused_parens` sites die in ONE place, and the
>   `typeset`→`declare` shared normalization is measured and REJECTED.**
>   (1) `rust_backend::strip_let_init_parens` — a statement-boundary-
>   aware, string/char-aware textual pass that rewrites
>   `let x = (EXPR);` → `let x = EXPR;`. A `let` initializer takes any
>   expression, so the grouping parens a render site wraps around a
>   compound value are boilerplate *in that position only*: the same
>   value feeding a method receiver (`(EXPR).to_string()`) or a cast
>   (`(EXPR) as usize`) still needs them. It fires only when the
>   MATCHING close paren is immediately followed by the `;`, refuses
>   empty/tuple payloads (a top-level `,` marks a tuple), never fires
>   on `while let`/`if let`, and never inside a literal. 3 tests
>   (`strip_let_init_parens_tests`). Effect over the 563-file emitted
>   corpus: `unnecessary parentheses around assigned value` **5 → 0**,
>   total rustc warning lines **76 → 69** (84 at the round-1 baseline);
>   dead polyfill defs stay 0, casts stay 113, `sh2.*` callouts stay 0.
>   (2) Candidate for a shared normalization, measured across all 10
>   targets and REJECTED: `builtin("typeset", …)` →
>   `builtin("declare", …)` (bash: "typeset: Same as declare"). Motive:
>   the ESTree renderer folds `declare -A map` natively (`map = new
>   Map()`) but emits **17 `sh2.builtin("typeset", …)` callouts** in
>   3 corpus files, and `typeset_attrs` already records attributes for
>   `typeset|declare|local` alike, so the rename would be semantics-
>   exact. Rendered `typeset-cmdsub.sh` and its `declare` twin through
>   rs/pl/js/c/go/fish/java/py/zig/sh: **8 equivalent, perl and C
>   DIFFER** — C's `declare` path swaps heap `char*` for fixed-capacity
>   `char v[N] = ""` **plus `assert(strlen ≤ N)`** (a later longer write
>   would start asserting), and Perl gains a pre-declaration and the
>   uu-FFI seam block. A JS-native win does not pay for changing the
>   codegen of two gated backends; no edit made.
>   Gates: `./fail` 563/563, `fail-rs` 556/0/7,
>   `fail-estree --gate` 563/563, `check_qx_shir` 563 ok / 0 violations
>   / 0 probe failures, `py-rust-gate` 98/103 (3 FAIL + 2 known-gap =
>   unchanged baseline), `cargo test --lib` **1810 pass / 50 fail** —
>   the SAME 50-red set as the previous round's control, none from
>   `split_fold`/`rust_backend`. Core worker GREEN 07:34:18.
> - v87: **Two measured idiom wins, one shared nospace closure rule.**
>   (1) The helper prune ran BEFORE the passes that delete call sites:
>   `strip_write_only_rc` removed the `__SH_RC.store(__sh_ret_rc(…))`
>   that the return path had registered `ret_rc` for, orphaning the
>   definition — **9 dead `fn __sh_ret_rc` across the 563-file emitted
>   corpus**. `prune_unused_helpers` now runs after
>   `strip_write_only_rc` + `strip_dead_word_fail_guard` and still
>   before `prune_unused_statics` (so a pruned helper's own static
>   references are gone when the static sweep decides): dead polyfill
>   defs 9 → **0**, casts 122 → 113, `parse::<i64>` 129 → 120,
>   38,330 → 38,294 emitted lines, 14 files changed, `sh2.*` callouts
>   stay 0. (2) The "no IFS whitespace" proof gains a SUBSTRING closure
>   rule, mirrored in ALL THREE of its implementations —
>   `shir.rs::expr_nospace` (the var fixpoint every backend's verdicts
>   come from), `shir_passes::split_fold::expr_nospace` and the
>   ESTree render-time `expr_known_nospace`: `${x#p}` / `${x##p}` /
>   `${x%p}` / `${x%%p}` / `${x:o:l}` / basename / dirname return a
>   SUBSTRING of the subject, so the subject's verdict transfers
>   whatever the pattern is (magic or not), and a Ternary/DefinedOr is
>   whitespace-free exactly when both branches are. Case ops stay
>   unproven — the one arm whose result is not a substring of its
>   input. A1 `split[]` sites 7 → **6** (`parse-heredoc-dollar-paren`
>   folds); new test `substring_and_conditional_prove_nospace`.
>   (3) Fixed `otranspilerl/src/bin/zz_probe.rs`, which called
>   `shell_to_shir_export` — a function that has never existed — and
>   had made EVERY `cargo test` in that package fail to BUILD since
>   Oct-22; compiling it again reveals 3 pre-existing lib failures
>   (`analyze_json_shape`, `analyze_vetoes_overflow`,
>   `embed_english_and_backtick_flags`), untouched by this round.
>   Gates: `./fail` 563/563, `fail-rs` 556/0/7,
>   `fail-estree --gate` 563/563, `check_qx_shir` 563 ok / 0
>   violations / 0 probe failures, `py-rust-gate` 98/103 (3 FAIL + 2
>   known-gap = the unchanged baseline), `cargo test --lib` 1807 pass /
>   50 fail — the SAME 50-red set as the pre-edit control (1806/50
>   with this round's edits reverted; 0 red from `split_fold` /
>   `rust_backend`). Core worker GREEN 06:24:56.
> - v86: **The python equivalence gate is green through the gate's OWN
>   renderer** — `BACKENDS=python all_failures.sh` → **0 failures / 563**,
>   `./fail` 563/563, `cargo test --lib python_backend` 10/10. v85
>   measured the MAIN tree's renderer, but `render_for` prefers
>   `sh2perl/backends/<lang>`'s worktree `shir_render`, which sat on a
>   stale Oct-16 branch and still failed the original 15. Converged by
>   copying the fixed `src/python_backend.rs` over the worktree's copy
>   (the worktree's Oct-22 WIP — a revert of the spaceless-`==`
>   single-word rule — is already contained in the main file; raw patch
>   preserved at `.boxscratch/py-idiom/worktree_wip_backup/`) and
>   rebuilding: **15 → 3**. The last three were real backend bugs:
>
>   **(a) background `&` ran SYNCHRONOUSLY** into a StringIO that the
>   end-of-program flush always delivered, where the gate's
>   `kill-session.sh` session sweep kills bash's orphan BEFORE
>   `(sleep 1; echo a)` writes — gate bash = `b` / `exit: 0`, sync
>   python printed `a` regardless (048_subprocess). No flush-or-drop
>   policy can satisfy both the gate (swept → no `a`) and a plain run
>   (orphan → `a`); the job is now a REAL `os.fork()`: the child
>   inherits the same stdout fd (byte- and EOF-timing-identical to
>   bash's orphan on BOTH paths), gets a memory copy (105's copy
>   semantics for free — no snapshot/restore), never blocks the parent,
>   and `wait` waitpids the recorded `__sh_bg_pids`.
>
>   **(b) `local -a a=(…)` was dropped whole**: the declaration arrives
>   as a setArray CALL between the flag words and `render_local_call`
>   read only STRING words, so `${files[@]}` read a never-bound `files`
>   (064_16: `NameError: name 'files' is not defined`). It now emits
>   the setArray assignment; `listVar` gained a native arm (argv
>   `_sh_args` / `sys.argv[1:]` / a declared array's list); and a
>   word-LIST element inside a word array splices `*items` — the same
>   spreading `${@:2}` already had — so `for f in "${files[@]}"`
>   iterates the files instead of one joined string.
>
>   **(c) `${arr[@]:off:len}` sliced the TEXT OF ELEMENT 0**
>   (`(numbers[0])[3:3+4]` → `""`, 064_18 printed `Middle: ` empty)
>   where bash slices ELEMENTS: a declared array now lowers through
>   `array_slice_expr` — the whole list for the bare `[@]`/`[*]` form,
>   a clamped element slice otherwise (python's slice clamping matches
>   bash's bounds rules).
>
>   All three are backend-local render rules — `param(slice)` / `setArray`
>   / `listVar` semantics are consumed per-backend, so this round again
>   found no shared shIR→shIR landing spot, and the shared core was not
>   touched. Caveat: main's tree is transiently unbuildable from ANOTHER
>   worker's in-flight `src/shir.rs` edit (E0502/E0503/E0597, saved
>   05:55–06:01) — every binary measured above predates it, and the unit
>   tests were run in the worktree against the identical backend file.
>
> - v85: **The Python round: all 15 python equivalence failures fixed,
>   and the emitted Python cut from 39,155 to 24,966 lines (−36%).**
>   Measured over the 563-file corpus with a mirror of
>   `all_failures.sh`'s python contract (fresh scratch dir per file, rc
>   equality, byte-equal stdout, stub-marked renders excluded): **15 → 0
>   equivalence failures, 0 PASS→FAIL regressions**; `./fail` 563/563;
>   `cargo test --lib python_backend` 10/10 (three new pins), and of the
>   48 failures in the whole lib test run none are python's — they sit
>   in c_backend/estree/fish/shir/shir_json_in, which other workers are
>   editing in this tree.
>
>   **(1) Equivalence — one root cause per cluster.** The redirect
>   shell-text reconstruction DROPPED THE FD: `2>/dev/null` became
>   `>'/dev/null'` (discarding stdout — sync-direct-call-await printed
>   nothing) and `2>&1` became a write to a file literally named `&1`
>   (parse-db-status-fmt, question-in-singlequote sent dpkg's error to
>   stderr instead of the capture); `redirect_shell_text` now prints the
>   number and keeps dup targets bare, and the statement arm passes the
>   fd through instead of building a two-key object. `[[ … ]]` operands
>   that are `$( … )` were split on the substitution's OWN whitespace —
>   four tokens matched no arm, so the test fell into the `bash -c`
>   fallback, which re-runs the space-stripped text where
>   `$(uname -r)==5.4.*` is one word and therefore always TRUE
>   (test-expr-float, test-expr-dollar-paren); the splitter now tracks
>   `$( … )` nesting — only `$(` counts, because `[ \( … \) ]` grouping
>   must keep splitting or it passes natively where bash is false
>   (parse-complex-test-parens, found as a regression of the first
>   attempt and pinned). `test_value` parsed `010` to the int 10
>   (`str(10) == str(10)` — bash compares WORDS) and rendered
>   `${NAME}`/`${NAME:-def}` reads as a python STRING LITERAL, so
>   `("ZSH_VERSION" if "ZSH_VERSION" != "" else "")` was always truthy;
>   both are token-level fixes. `case` compared against the QUOTED
>   pattern (`''` vs "" — c_backend's `unquote_case_pattern` rule, now
>   mirrored) and let a command substitution in the discriminant clobber
>   `$?` (hoisted into a temp and re-reset: bash gives `case` 0 when no
>   clause tests true — parse-case-dollarparen-pattern exited 127). The
>   bash-seam helpers gained the three bash behaviours they were
>   simulating badly: `command -v` is a PATH lookup not a fork
>   (`shutil.which`), ENOEXEC runs the no-shebang file as a shell script
>   — with **bash**, since this box's /bin/sh is dash and rejects the
>   script's `set -o pipefail` — and a bare name is resolved first so
>   glibc's PATH walk cannot report the last candidate dir's EACCES
>   instead of the file's own ENOEXEC (a.sh). Reads of bash's OWN
>   variables (`HOSTNAME`, `BASH_VERSION` — set at startup, never
>   exported) fall back to `os.uname().nodename` and one
>   `bash -c 'echo $BASH_VERSION'`, so `${HOSTNAME:-localhost}` and
>   `[ "${ZSH_VERSION-}" ] elif BASH_VERSION` take bash's branch.
>   U+F800 raw-byte markers (read_source's encoding of a non-UTF-8
>   source byte) now escape to lone surrogates and the preamble sets
>   `sys.stdout.reconfigure(errors="surrogateescape")`, which encodes
>   U+DCxx straight back to the byte — python was writing 0xEF 0xA3 0xA9
>   where bash writes 0xE9 (utf8-non-utf8-content). Finally, `$( … )` as
>   a whole test operand runs through the seam instead of comparing the
>   literal text `"$(uname -r)"`, which only ever matched by luck.
>
>   **(2) Idiom — reachability, not a whitelist.**
>   `Render::elide_dead_helpers` runs on the FINISHED program, so
>   helper→helper edges (`__sh_source` → `__sh_declare_parse`,
>   `__sh_pipe_status` → `__sh_bash`) are followed without any call site
>   declaring a dependency, and a name mentioned anywhere keeps its def
>   (a false keep is the old behaviour; a false drop would be a
>   NameError). The subprocess seam used to be ONE block emitted
>   whenever any part of it was needed: 238 of 563 files defined
>   `__sh_declare_parse` and called it **0** times, and
>   `__sh_source`/`__sh_pipe_status`/`__sh_bash_in`/`__sh_eval` were
>   dead in 235/235/230/229 of them — around a hundred lines of dead
>   polyfill per file, on programs whose body is often shorter than the
>   preamble. Corpus totals: **39,155 → 24,966 lines**; dead helper
>   definitions 238 → 12 (all 12 reachable through `__sh_source` /
>   `__sh_eval`); the now-orphaned `__sh_names = {…}` snapshot table
>   goes with `__sh_env`; bare `None` statement lines 104 → 0 (a
>   statement-position expression that renders to the placeholder emits
>   nothing rather than a dead line).
>
>   **(3) Not yet what `all_failures` measures.** That gate renders
>   python through `sh2perl/backends/python/target/debug/shir_render`, a
>   separate checkout on `backend/python`; these changes are uncommitted
>   in the submodule's main tree, so the official arm still reports the
>   old 15 until a submodule commit is merged in with
>   `setup_backends.sh --sync` and that renderer is rebuilt.
>
> - v84: **`unreachable-after-exit` now recognises the CALL spelling of
>   `exit` (no shell `exit` ever reaches the IR as `IrStmt::Exit`), and
>   the IR-level all-literal interpolation fold was measured and
>   REVERTED.** Two findings from the round's re-analysis of the emitted
>   Rust (563 examples, 38,321 lines: still 0 `sh2.*` callouts, 0 dead
>   polyfill definitions; 509 `format!`, 122 `as`-casts, 129
>   `parse::<i64>`, 1,116 `to_string()` — all on the shell's untyped
>   boundary, none of them an IR-removable shape).
>
>   **(1) The landed transform.** The pass pruned statements after
>   `IrStmt::Exit(_)`, but that variant is not what shell source
>   produces: `exit 1` AND `exit "${?}"` both reach the backends as a
>   command call (`Expr(Call("exit", …))` — `func: "exec"` before the
>   builtins.json lowering, `"builtin"` after; corpus census: 10 exit
>   statements, 0 of them `IrStmt::Exit`), so the pass was inert for real
>   exits and the dead tail survived into EVERY backend —
>   `parse-exit-brace-question` emitted `printf "parsed OK"` after
>   `exit ${?}` in Rust, C, Perl and JS alike, and rustc flagged it
>   `unreachable statement`. `terminates_list`/`is_exit_call` now match
>   both funcs with a literal `exit` command word (`die` refused: in
>   shell it is a USER function; a variable command word refused: not
>   statically checkable). Verified cross-backend on that example: shIR
>   2 statements → 1, and the dead printf is gone from Rust, C, Perl and
>   ESTree. Five pins in `unreachable_after_exit::tests` (folded exit,
>   dynamic exit, exit-in-function, CONDITIONAL exit refused,
>   non-exit builtin refused).
>
>   **(2) The Rust epilogue guard.** A `fn main` whose last statement is
>   already a process exit got `std::process::exit(__SH_RC…)` appended
>   behind it — dead, and warned about. `Render::body_ends_in_exit`
>   (conservative: the last non-blank line must START with the call and
>   end `);`, so a conditional exit behind a closing `}` never matches)
>   suppresses it. Effect on the corpus compiled with DEFAULT lints:
>   `unreachable statement` 6 → 2, `unreachable expression` 4 → 4; the
>   4 survivors are a different class (renderer-emitted status writes
>   after a terminal `break`/`return` inside an expression sequence, 3
>   loop files + `061_test_local_names_preserved`). Two new pins
>   (`no_unreachable_epilogue_after_a_final_exit`,
>   `a_conditional_exit_keeps_the_epilogue`).
>
>   **(3) The reverted experiment.** Widening `interp-fold`'s single-Lit
>   rule to "concatenate ANY all-literal part list" was built, measured
>   over the whole corpus in Rust, C and Perl, and taken back out: **0 of
>   563 C files and 0 of 563 Perl files changed byte-for-byte** (both
>   renderers already collapse that node themselves), Rust gained a net
>   −2 `format!` while LOSING 37 `println!` forms (an IR-level `Str`
>   takes the `print!("…\\n")` arm — strictly less idiomatic), and it
>   broke 4 shape pins (`estree::variable_and_interpolation`'s
>   TemplateLiteral, the bc `trunc` native lowering ×2, and Rust's
>   no-print-format-hop echo). Canonicalization of an all-literal
>   interpolation belongs to the renderer, where the target's idiom
>   picks the spelling. The refusal is documented at the fold and pinned
>   (`a_multi_part_all_literal_interpolate_keeps_its_shape`) so the
>   measurement travels with the code.
>
>   Verification: `./fail` 563/563; `harness/fail-rs` 556/0/7
>   (baseline); `harness/py-rust-gate` 98/103 (documented t82/t87/t104);
>   `check_qx_shir` 563 examples 0 violations; `./fail-estree --gate`
>   PERL 563/563, ESTREE 549/563 (97.5%) — its 14 failures are NOT this
>   round: 14/14 have no `exit` statement anywhere in their source (the
>   new rewrite only deletes what follows a direct exit), and they sit
>   in `estree.rs`/`shir.rs`, the core-owned files other lanes changed
>   after v83. `cargo test --lib` 1805 pass / 48 fail (estree 24, shir 9,
>   c_backend 9, fish_backend 5, shir_json_in 1) — a STRICT SUBSET of
>   the control run taken before this round's edits (54 failures), 0 new,
>   and all 4 exit-named failures in it pre-date those edits. Core worker:
>   `gate GREEN (A1 native + estree corpus + lib tests)` at 02:26, no
>   `core-requests/sleeping-*`, `repair-workers.sh` silent.
>
>   Measured, not done (same class, renderer-side, other lanes' files):
>   C still appends `return 0;`/`return _sh_rc;` and Perl still appends
>   `exit $main_exit_code;` behind a final exit; Rust alone suppresses
>   its epilogue today.
>
> - v83: **`interp-fold`'s second rewrite: the decl-value rejoin retires the
>   Str-vs-Interpolate shape guess every backend reimplemented (and got
>   differently wrong).** The decl family is lexed `name=` + VALUE word and
>   backends tell the VALUE from a following NAME by the word's SHAPE — a
>   quoted piece (`Interpolate`) is the value, a bare `Str` is the next
>   name. `copy-propagation` then destroys that signal: `local e="$v"` with
>   `v` constant folds to `["e=", Str("world")]`, byte-identical to the
>   two-word spelling, and the backends guessed in OPPOSITE directions —
>   measured on `v=world; f(){ local e="$v"; echo "[$e]"; }; f`: bash
>   `[world]`, **Rust `[]`** (it read the bare Str as the next declaration
>   and never assigned `e` at all), Perl `[world]`. The rewrite rejoins
>   `["name=", Str(v)]` → the canonical one-word `["name=v"]`, which every
>   backend already parses identically (`split_once('=')`), so the guess is
>   gone rather than re-won per renderer. **Scope is exactly
>   `local | declare | typeset`** — for that family the parser already
>   lowers `name=` + a following NAME into `Declare` nodes (measured over
>   the whole family, top-level and nested), so a surviving bare Str in
>   value position can only be a folded quoted expansion; `export` /
>   `readonly` / `nameref` keep the two-word form standing (`export c= d`
>   means "assign c, then NAME d") and are refused — REFUSE > GUESS. A
>   following `Interpolate` is never touched (that is the live signal the
>   `081` refusal exists to protect). Registered as `decl-value-rejoin`, a
>   SECOND `interp_fold::transform` entry at the END of `all()` (the
>   `not-identity` double-registration precedent): the shape it rewrites is
>   minted at `copy-propagation`, so the early `interp-fold` slot cannot
>   see it, and running last means nothing can re-fold a value into the
>   ambiguous shape after it. Five new pins in `interp_fold::tests`
>   (`folded_decl_value_rejoins_to_the_inline_word`,
>   `export_and_readonly_keep_their_two_word_form`,
>   `a_quoted_value_piece_is_left_on_shape_signal`,
>   `a_non_decl_command_word_list_is_untouched`,
>   `a_bare_equals_head_is_not_a_name`). Verified equivalence: `./fail`
>   563/563, `./fail-estree --gate` PERL 563/563 + ESTREE 563/563 (100%),
>   `harness/fail-rs` 556/0/7 (baseline), `harness/py-rust-gate` 98/103
>   (documented t82/t87/t104), `check_qx_shir` 563 examples 0 violations.
>   `cargo test --lib` 1784 pass / 47 fail — all in `c_backend`/`estree`/
>   `fish_backend`/`shir`/`shir_json_in`, and a control run with
>   `decl-value-rejoin` DISABLED fails the identical set (superset of 60):
>   none are this change. Corpus byte-output: unchanged by this rewrite (no
>   corpus example carries the folded shape); the win is the correctness
>   divergence above, which the corpus never exercised. Rust-emit state at
>   this round: 0 `sh2.*` callouts, 0 dead polyfill definitions, 122 casts,
>   129 `parse::<i64>`, 38 `format!("{}")`.
> - v82: **`analyze_var_nospace` now sees EVERY write — for-loop bindings
>   included — so loop-only vars get a verdict and the conjunction is
>   order-independent (shared verdict; every backend inherits the folds).**
>   Three holes closed in one pass over `shir::analyze_var_nospace`:
>   (1) `IrStmt::For { var, … }` was never collected, so a loop-only
>   var had NO verdict — `for i in {1..5}; echo $i` kept its runtime
>   word-split in every backend (Rust: `__sh_split_ifs(&i.to_string(),
>   …)`; ESTree: a `sh2.split` callout; Perl folded it anyway at render
>   time). A for-binding now gets its own proof: each Array element is
>   ONE word of the list (parser already expanded `{a..c}`),
>   whitespace-free literals bind whitespace-free words, but an element
>   carrying a glob metachar (`* ? [`) is refused — pathname expansion
>   runs after splitting and a matching FILENAME may contain spaces —
>   and a non-literal element (`$x`, `$(cmd)`, interpolate) is refused
>   outright. (2) The walk skipped `Function` bodies, `ForInit`,
>   `Pipeline`, `Redirect`, `Try`, `Select` and `Declare` — a
>   function-body assign was invisible, so a name could be tagged
>   `true` while a function wrote a multi-word value into it. (3) The
>   fixed point re-evaluated each write independently and left the LAST
>   one standing — a name whose non-free write came first in the walk
>   could end up `true` (order-dependent, unsound). It is now a proper
>   conjunction: start written names optimistically `true`, only ever
>   drop, monotone, one flip per name. Soundness complement: the
>   non-`Assign` writers (`read`/`mapfile`/`getopts`/`printf -v` and the
>   `export/declare/typeset/local name=` call forms; bare `local x`
>   resets to empty — measured `[]` — so it is a free write) are
>   collected as opaque writes, and `let`/`$((…))` arithmetic writers
>   were already free-by-shape. `eval`/`source` remain the documented
>   pre-existing gap (invisible to this and every prior revision).
>   Measured over the 563-file corpus: one more split site folds
>   (001_simple's `echo $i`: Rust drops `__sh_split_ifs`, JS drops
>   `sh2.split` → `process.stdout.write(String(i))`), ZERO regressions
>   (no previously-folded site re-opened), and no other verdict flipped
>   visibly — the other 23 Rust split sites are cmdsub/env operands the
>   proof correctly keeps. Gates: `./fail` 563/563, `fail-rs` 556/0/7,
>   `fail-estree --gate` PERL 563/563 + ESTREE **563/563 (100%** —
>   even 064_07 now green), `py-rust` 98/103 (= documented baseline),
>   `check_qx_shir` rc=0,
>   `cargo test --lib` 43 reds = the concurrent c/estree/fish-lane WIP
>   tests (estree.rs has ZERO `var_nospace` consumers; its reds assert
>   the fnCall native-lift's `builtinValue`/`captureSync` spelling,
>   provably independent of this verdict).
> - v81: **case-lowering first-char bucketing (fb0-raster lane) —
>   the 256-arm hex decode stops scanning (MIMEcroft `--first-frame`
>   −1.86% instructions, `--demo` −0.38% workload-matched; pure
>   shIR, every codegen backend that runs case-lowering).** A long
>   all-exact dispatch chain (≥16 clauses, every literal non-empty
>   and sharing one first char) re-groups under an outer
>   `strHasPrefix(subject, c)` guard — the shared primitive the
>   `lit*` arm already emits — with one inner chain per first-char
>   bucket, clauses in original order (first-match) and the original
>   `*` else replicated into every fall-through: buckets are
>   disjoint on the first char, so entering a bucket and matching
>   nothing there matched nothing anywhere. Refuse > guess: any
>   non-exact clause, <16 clauses, `k + bmax > n/2` (glyph_index's
>   single-character alphabet refuses and stays flat), else >8
>   statements (cloned per bucket), or `SH2_NO_CASE_BUCKET=1` (in
>   bash-o4's `render_env_key` + cli opts key — the arms can never
>   share a cache entry). MIMEcroft: exactly one chain qualifies —
>   rb_h2d (16 guards, +64 lines; ~128 avg strcmp → ~24 per
>   lookup, three calls per blended pixel); corpus render delta
>   651 SAME / 0 DIFF. `RENDERER_REV` 16 → 17. Measured:
>   first-frame 3.279 B → 3.218 B (−1.86%, 7 interleaved runs/arm,
>   spread ±0.001%); `--demo` matched workload pairs −0.39% /
>   −0.37% (3 runs/arm; totals deterministic per workload level,
>   frames 127–136 wall-paced). Frame byte-identical bash == ON ==
>   OFF (live oracle rerun, md5 `53d9cfa7`, 230,415 B);
>   `c_gate_main` 599/45/7 both arms, FAIL sets identical; lib
>   1773/43/5 (same 43-red baseline + 5 new bucketing tests).
> - v80: **the exit-status register is decimal — so `local ec=$?` loses its
>   split in every backend, not just Perl (shared split-fold proof).
>   `shir_passes::split_fold::fold_trivial_splits` could only drop
>   `split(x)` when a var_nospace/var_types analysis tagged `x` — and
>   `$?` reaches the IR as `Var("?")`/`getVar("?")` (or the native
>   lowerings' `CHILD_ERROR` spelling), a name no analysis ever sees.
>   New `is_status_name` proves the obvious: an EXIT CODE renders as
>   decimal digits in every backend (`__SH_RC.load(…)` i32,
>   `sh2.lastExit`, `$CHILD_ERROR`, `_sh_rc`), so splitting it yields
>   exactly the one IFS-free field. Measured across the corpus's six
>   `local ec=$?` sites: Rust emitted
>   `__sh_split_ifs(&__SH_RC.load(…).to_string(), " \t\n")` — the
>   split polyfill + helper call — now `let ec =
>   __SH_RC.load(Ordering::SeqCst).to_string()`; the ESTree path emitted
>   `sh2.split(sh2.lastExit)` — a callout no other backend needed — now
>   `let ec = sh2.lastExit`; Perl byte-identical (it already folded the
>   shape at render time). rustc clean on all six. Pin:
>   `split_fold::tests::folds_exit_status_split` (fold fires, folds to
>   the bare status read, idempotent). This is the marketplace shape
>   done right: one proof in the shared pass, every renderer benefits,
>   no target gate needed because the fact is backend-independent.
> - v79: **value_ll's split arm — int-position args stop
>   round-tripping through snprintf+atoll (MIMEcroft `--first-frame`
>   −34.4% instructions, `--demo` −39.3% per frame; fb0-raster
>   worktree PLAN v56, same entry).** `value_ll` (the C conversion
>   for a proven-int call position) fell back to
>   `atoll(value_c(e))`; for the shape every unquoted word has —
>   `split(getVar("x"))`, 414 of MIMEcroft's 444 int-arg sites —
>   that meant an snprintf `%lld` temp + `atoll` parse per call.
>   `value_c`'s value-context split arm already drops the split (it
>   is only semantic on the child-shell command path), so `value_ll`
>   recurses through the wrapper: byte-identical value, no temp.
>   NOT a shared rewrite — the split marker stays semantic for
>   rust/perl/java runtime splitting; this is the C-int-ABI arm the
>   shared numstr `split` proof licenses. `snprintf(_sN)` 694 → 284,
>   `atoll((char*)(_sN))` 210 → 4. Measured: first-frame 4.741 B →
>   3.110 B instructions (−34.4%, 7 interleaved pairs; cumulative
>   −57.5%); `--demo` 262.9 M → 159.5 M/frame (−39.3%; cumulative
>   −66.3%). Frame byte-identical bash == ARM == no-ARM; `c_gate_main`
>   599/45/7 both arms with identical FAIL sets.
> - v78: **the test-lift guard now asks BASH whether the status is dead,
>   not the emitters (target-gated to Rust, the one emitter that already
>   answers "yes").** Measured Rust emission: `__sh_mod(n, i) == 0` where
>   it used to re-parse its own arithmetic through a String. Need:
>   `test_lowering`'s guard 1 refuses every lift whose cond status write
>   looks observable, using `shir::walk_lastexit_liveness` — whose writer
>   predicate is RUNTIME-truth ("what do the emitters actually record").
>   A plain `IrStmt::Assign` is deliberately NOT in that set, because only
>   Rust emits the write (`i=$((i+2))` → `__SH_RC.store(0, …)`); BASH
>   writes it always (`false; i=$((i+1)); echo $?` prints 0). So an
>   assignment sitting between a cond and the `$?` reader it appears to
>   feed kills that status in bash, yet kept the cond live in the model —
>   pinning `[ $((n % i)) -eq 0 ]` inside 051_primes' `while` to the raw
>   test string: Rust rendered `((n % i)).to_string().trim().parse::<i64>
>   ()` for a value it already held as `i64`, and Go rendered
>   `s2i(capRun("(n % i)", …))` — a **bash process spawn per loop
>   iteration for a modulo**. Mechanism: a scoped, Drop-cleared
>   thread-local latch `shir::assign_kills_guard()` that makes
>   `ir_stmt_writes_lastexit` count assignments, HELD ONLY for the
>   duration of `test_lowering::transform` — so the lift guard's liveness
>   math runs bash-truth while every render-time deadness install
>   (`install_lastexit_deadness`, `install_unread_status_writes`) keeps
>   runtime truth. **Gated on `transforms::target() ∈ {rs, rust}`**
>   (the `split-in-place` target-set precedent): the lift drops the cond's
>   status write, which is sound exactly where the emitter replaces it
>   with the assignment's 0 — measured 2026-10-26 on `false; i=$((i+1));
>   echo "$?"`: bash 0, **rust 0**, perl 1, c 1, JS reads `lastExit` 1.
>   Every other target — and an unset target, which is what the
>   target-agnostic pins run under — keeps the conservative refusal, so
>   `live_status_keeps_the_test`, `live_status_keeps_the_numeric_test`,
>   `arith_expansion_operands_lower_to_binop`'s live-status case and
>   `compound_refusals_stay_on_the_runtime_path`'s live-status case stay
>   true rather than being re-pinned to a rule the emitters do not honour.
>   Corpus effect: exactly one file (051_primes), one line — Rust native
>   compare; Go/Perl/JS emission byte-identical to before. **Found but
>   NOT fixed here (renderer-side, belongs to the owning lanes):**
>   `false; i=$((i+1)); echo "$?"` → bash 0, perl 1, c 1, JS 1 — the
>   assignment's status write is missing from every emitter but Rust's,
>   and adding it (conditionally: an `x=$(cmd)` RHS already carries the
>   capture's status) is what would let this precision be ungated for
>   those targets. Core worker healthy, no fix needed (`gate GREEN`
>   16:06, A1-native invariant 0 violations / 555 probed, no trap
>   markers).
> - v77: **numstr copy-closure — copy-only pass-throughs seed as Int
>   (MIMEcroft `--first-frame` −35.2% instructions, `--demo` −44.8%
>   per frame; fb0-raster worktree PLAN v55, same entry).** Phase 2's
>   anchored coinduction demanded EVERY candidate carry its own
>   anchor, which a pure pass-through structurally cannot:
>   `rbt_t=$rbt_x1` in `rb_tri` is only ever copied from other vars.
>   Without `t` in the candidate set the anchored cycle collapsed in
>   the removal loop (x2's copy of the unseeded `t` failed first,
>   then x1's copy of x2), so rb_tri/rb_face corner coordinates
>   stayed `char*` and paid atoll+snprintf per swap and per edge
>   step. Phase 2b (shir_passes::numstr, shared) admits any var whose
>   every assign is int-valued while GRANTING the candidates int,
>   grown least-fixpoint-style FROM the anchored set — an ungrounded
>   text cycle never enters round 1, and the removal loop
>   re-validates every candidate afterwards. Seeded 188 → 227 vars;
>   rbt_x1/x2/t/minx/maxx/s1 home to `long long`; env-blocked
>   `rbt_v` still refused. Measured: first-frame instructions 7.315 B
>   → 4.741 B (−35.2%, 7 interleaved runs/arm); `--demo` 473.6 M →
>   261.5 M instructions/frame (−44.8%), 67–74 → 51–53 ms/frame.
>   Frame byte-identical bash == ON == OFF; `c_gate_main` 599/45/7
>   both arms with identical FAIL sets; `cargo test --lib` reds =
>   exact baseline (43 both ways, hunk-strip A/B).
> - v76: **echo-fold safety — a folded print is NOT `exec echo`.** Three
>   defects, all the same shape: something only lives on the echo CALL
>   path, and a pass that treated `IrStmt::Output` as equivalent lost it.
>   (1) `echo_fold`'s `fold_dynamic_to_output` folded ANY mixed word, so
>   a `$((…))` word dropped Rust's `__SH_ARITH_WORD_FAIL` guard and its
>   `probe_str` — and that probe is what HOMES a function's parameters:
>   `small_factors` (py-rust t89/t90) went `p0: String` → `p0: i64`, the
>   call site wrapped the argument in `.trim().parse::<i64>().unwrap_or
>   (0)`, a 2^64+1 BigInt parsed to 0, and the factor lists came out
>   wrong (py-rust-gate 96/103 vs 98/103 at HEAD). The fold now refuses
>   a word containing a call/arith/capture — the refusal the `WriteFile`
>   fold already makes for the same reason — so `echo "text $v"`, the
>   shape the fold exists for, still folds. (2)
>   `perl_generator_fixed::fix_stmt` had no `Output` arm, so
>   `fix_array_slice_bounds` never saw a slice inside a folded print and
>   the renderer emitted its RAW range, where a negative offset means
>   "to the END" in Perl — 051_primes printed all 100 primes after
>   `Last 10: ${primes[@]: -10}`. (3) ir.rs's `Output` emitter lacked
>   both guards `emit_echo` applies (SH2BADSUBST → abandon the print,
>   `$?`=1; and the `$__SH2_AE` empty-arith-operand guard that skips the
>   print and leaves `$?`=1 — parse-dollar-in-arithmetic), and
>   `fix_ps_status_blocks`'s local `stmt_reads_exit_status` had no
>   `Output` arm AND no `Var("?")` arm, so the `$?` reader was
>   invisible, `read_next` came back false, and the save/restore around
>   the `rm -f __ps_tmp…` cleanup was skipped — the cleanup's own 0
>   clobbered the consumer's status (070_cmp, process-substitution and
>   064_01 all reported success where bash reports 1). Four stale unit
>   tests updated against in-flight work (`RegSub`→`Substitute`, `sort`
>   now lowers to SortLines, the native-Map migration supersedes the
>   `arrayIndex` example, and `ls|wc` now reduces natively so the
>   `pipelineCaptureSync` collapse is asserted on `sort|head`), and
>   `harness/estree_gate.pl` taught to allow `Map.prototype.{get,set,
>   has,keys,…}` only on a receiver that RESOLVES TO a `new Map()`
>   (binding-collected, so `anythingElse.set(…)` still fails) — the
>   whitelist the native-Map migration needed (6 structural reds → 0).
>   Verified: `./fail` 563/563; `fail-rs` 556 pass / 0 fail / 7 skip;
>   `fail-estree` PERL 563/563; py-rust-gate 98/103 (= the pristine-HEAD
>   baseline; its 3 reds t104/t82/t87 pre-date this round);
>   `cargo test --lib` 44 reds = HEAD's 45 − 2 fixed
>   (`empty_else_kept_when_status_is_read`,
>   `a4_sync_builtins_matches_rust`) + 1 new. Core worker healthy (gate
>   GREEN 12:11, A1-native invariant 0 violations / 555 probed). The two
>   remaining reds are NOT this round's and both trace to `src/shir.rs`,
>   which another workstream was editing live throughout verification
>   (2 hunks → 45 hunks, 2742+/51−, mtime seconds old):
>   `estree::tests::native_pipeline_stage_return_survives_loop_body_
>   signal_rewrite` sits on its in-flight `lowered_stmts_have_signals`
>   hunk, and `064_07_complex_array_operations.sh`'s estree stdout
>   mismatch is the assoc migration emitting `new Map` where HEAD still
>   uses `getVar` (bash `Config: 8080 admin localhost` vs ours `Config: `
>   — HEAD byte-identical to bash). Left alone rather than stomped, per
>   the single-owner rule for the shared core.
> - v75: **str-splice-fold — the rasterizer's per-pixel row splice
>   becomes one shared node + one in-place store (MIMEcroft
>   `--first-frame` −6.9% instructions).** `${b:0:$o}${repl}${b:$k}`
>   (same base, prefix from 0, suffix to end) lowers to an
>   Interpolate of two `param("slice", …)` reads over ONE string — 2
>   substring temps + a join + a store copy: four passes over a
>   2560-byte framebuffer row for EVERY pixel (`rb_putrun`). The new
>   shared transform `str-splice-fold` (sh2perl
>   transforms/str_splice_fold.rs) folds it to ONE `StrSplice` node
>   (shir_nodes/str_splice.node; meaning = exactly the concat it
>   replaced; `base` is an EXPR field so DSE/copy-prop still see the
>   read), target-gated to `c` (§11 offer — a backend accepts by
>   adding its arms and its name in transform_applies; other targets
>   keep the original Interpolate byte-for-byte). C consumes it with
>   a capacity-guarded fused element store: slot already holds the
>   result (strnlen cap check) ⇒ three memmoves in place; the `else`
>   branch is the old path verbatim, and every non-store site
>   rebuilds the original Interpolate from the node's fields (value
>   fallback). The node also joins c_backend's `chop_operands`
>   whitelist — THOSE three scanners (lift_scan_expr,
>   scan_void_uses, walk_expr) refuse PROGRAM-WIDE (unknown Ext tag
>   → `bad` → the whole lift map is void), so without the arm ONE
>   fused store somewhere demoted all 130 MIMEcroft lifts to the
>   argv transport and doubled the exports (+36% instructions: the
>   first A/B measured that integration bug, not the fold — the same
>   failure class FieldStripEnd already documented there). Pinned by
>   the new `str_splice_node_keeps_void_lift` regression test
>   (verified to FAIL with the arm removed). `SH2_NO_SPLICE=1`
>   disables fold + fused arm and keys render_env_key;
>   `RENDERER_REV` 13 → 14. Measured (5 interleaved runs/arm,
>   median): first-frame instructions 4.035 B → 3.758 B (−6.9%);
>   frames byte-identical ON/OFF vs the bash oracle; rendered C
>   differs ONLY at the fused site once temp renumbering is
>   normalized; OFF render byte-identical before/after the whitelist
>   fix (strict no-op without the fold); `cargo test --lib` 43 reds,
>   a strict subset of the worktree's pre-existing 47 (0 new).
>   `c_gate_main` 516/128/7 vs the 12:15 baseline 518/125/8: the
>   delta is 3 zz_probe `cc` reds that are byte-identical ON/OFF —
>   the fold never fires on the gate's byte-pinned shIR ingress, and
>   the reds land in the window of the concurrent text_ops/estree
>   edits (13:01/13:07), not this change. Artifacts:
>   backends-sh-fb0 lane, `/tmp/nxt/` (fx_*.c, ab5_*.txt,
>   cgate_v2.log).
> - v74: **numeric-observed store relaxation — the C backend homes
>   text-stored tables whose every reader re-parses (MIMEcroft
>   `--first-frame` −14.35% instructions).** `shir_passes::
>   numeric_observed` already proved, in the shared layer, *which cells
>   are only ever observed as numbers*; `int_element_verdict` now
>   consumes it as the one gate it was missing. The old rule demanded
>   every STORE to an array be provably canonical-integer text
>   (`val_int`), which is sufficient but not necessary: what has to
>   agree is what a READER observes, and C re-parses every element read
>   with `atoll` (or stores `atoll` into a native slot) — so when all
>   element reads are numeric-observed, the stored TEXT is unobservable
>   and non-canonical stores are accepted too. Veto is the analysis's
>   documented one: no scalar a value read from the array can reach
>   (copies / param slots / downstream array stores) may parse wider
>   than `atoll` — `big` (mpz exact), `IrType::Float`, `IrType::UInt64`.
>   Every density/shape gate still applies unchanged (whole-array
>   reassign, `unset`, non-arithmetic keys, literal cover / append
>   growth, whole-array string reads, iteration). A second, smaller
>   wire was needed to finish the job: the pass's own `str_use`
>   closure stops at every CALL edge (`rb_mkhex(rbx_r, …)` marks
>   `rbx_r` text without asking what the callee does with `$1`), which
>   kept the readers of a freshly-homed table on `char*` — and a
>   `char*` reader of a native table is strictly WORSE (snprintf+atoll
>   bridge per call). `cand` now admits a scalar `nobs.scalar()` types
>   numeric-observed; `demote_stringy_ints` and the `seed_val` fixpoint
>   still re-validate every such seed. `SH2_NO_NUMOBS=1` disables the
>   relaxation (A/B switch; it also keys the bash-O4 artifact cache —
>   `RENDERER_REV` fb0 12→13, main 15→16). Effect on MIMEcroft: 6
>   arrays newly homed (`RBTEX_R/G/B/A`, `MIME_NAMELEN`, `swr`), +64
>   Int-seeded scalars, emitted C 24,815 → 24,769 lines with `atoll(`
>   281 → 250, `_sh_sset(&` 373 → 346, `snprintf(` 308 → 296,
>   `_sh_xstrdup(` 473 → 453; the per-pixel channel read went from
>   guard+pointer+strdup+atoll to one guarded `long long` load.
>   **Measured (5 interleaved `perf stat` runs per arm, control =
>   `SH2_NO_NUMOBS=1`):** `--first-frame` instructions 5,239,896,635 →
>   4,487,799,585 mean (**−14.35%**, spread <0.1%), task-clock −10.30%,
>   wall −4.81%; `--demo` (1200-frame auto-play) 150 → 178.7 frames in
>   the same ~10.5 s budget (+19%), 70 → 60 ms/frame, −12.2%
>   instructions per frame. **Correctness:** the control render is
>   BYTE-IDENTICAL to the pre-change `ab_on.c`, so the A/B isolates
>   exactly this change; frames byte-identical on 5/5 runs and against
>   the pre-change baseline PPM; the `--demo` transcript is identical
>   apart from its self-reported `#stats` timing lines. **Gates:**
>   `c_gate_main` 583 pass / 61 fail / 7 skip — all 61 fail identically
>   with the switch off (pre-existing lane state, 0 regressions);
>   `cargo test --lib` 1731 pass / 51 fail — the 9 `c_backend::tests`
>   failures reproduce with BOTH of my edits reverted in the sandbox
>   (pre-existing), the rest are estree/fish/rust/shir lanes;
>   integration: `c_cut_at` `c_isqrt` `c_growable_value` `c_sight_march`
>   `transform_laws` `pin_mirrors` `lint_smoke` green, and `c_sh2_str`
>   (2), `c_sorted_join` (1), `c_fn_multi_call` (4, missing `-lgmp` in
>   that harness) fail identically with the switch off. **Caveat:** the
>   shared core was left uncompiling by another lane at 05:45
>   (`shir.rs` calls `crate::estree::fold_capture_echo_cond`, which
>   nobody defines — both are single-owner files this lane must not
>   touch), so every build/test above ran from an isolated copy with
>   that one JS-path call neutralized; the C render path never reaches
>   it. **Resolved:** once that lane's fix landed, the real tree
>   compiled again (`cargo check --lib` clean) and the whole
>   verification was re-run in-tree, matching the isolated copy
>   exactly — `c_gate_main` 583/61/7 with a byte-identical FAIL set,
>   `cargo test --lib` 1734 pass / 48 fail (same 9 `c_backend::tests`
>   reds, still red with `SH2_NO_NUMOBS=1`; the other 39 are the
>   estree/fish/rust/shir lanes), `c_cut_at` `c_isqrt`
>   `c_growable_value` `transform_laws` green and `c_sh2_str` (2)
>   `c_sorted_join` (1) `c_fn_multi_call` (4) red identically with
>   the switch off.
> - v73: **`echo … > file` is a native file write — the shared
>   redirect-output → `WriteFile` fold, and the fix for a main tree that
>   had stopped compiling.** The producer half was already native
>   (EchoFold folds `echo "x"` to `IrStmt::Output`) but the enclosing
>   redirect still pushed every backend through its generic machinery:
>   Rust installed the file in `__SH_OUTFILE_TL`, ran the 22-line
>   `__sh_print_words` helper and restored it — five statements for a
>   literal write — Perl rebuilt the `select()` fd swap, the shell
>   backends rebuilt shell text. ESTree already had a backend-local lift
>   for exactly this shape (`try_native_echo_redirect` →
>   `sh2.fs.writeText`); Perl had `native_echo_write_file_stmt`, which
>   emitted `RawText` PERL and — since EchoFold now folds the inner
>   first — could never match its `Expr(Call echo)` pattern any more, so
>   it was dead code that still leaked `DWF: …` debug lines to stderr on
>   every non-matching redirect. New `shir_passes::echo_fold::
>   redirected_output_to_writefile` runs in the SHARED pipeline after
>   the children fold, so all seven backends lower to the one node every
>   renderer already spells natively. Refusals (refuse > guess): not
>   exactly one fd-1 `w`/`wc`/`a` spec; not exactly one inner `Output`
>   with `target: None`; a non-path target (`&1`, `-`, an `Arrow`
>   process substitution); a raw byte marker (the print path decodes
>   those, `fs::write` would not); content is the literal plus `\n`, or
>   `Interp[expr, "\n"]` for a dynamic producer. Perl's `WriteFile` arm
>   now records status 0 after `close` — Rust's, Java's and ESTree's
>   arms already did, and `open`/`print`/`close` touch `$!`, not `$?`,
>   so without it `false; echo x > f; echo $?` printed 1 in Perl only.
>   Corpus effect: **emitted Rust 41,805 → 40,787 lines, files carrying
>   `__sh_print_words` 108 → 87, `std::fs::write` 0 → 28 files, casts
>   124, `sh2.*` callouts 0**. Gates: `./fail` rc=0 (563/563), `fail-rs`
>   **556 pass / 0 fail / 7 skip** (fresh), `fail-estree` rc=0 (563/563
>   = 100%), `fail-shir` rc=0, `py-rust-gate` 98/103 baseline-identical,
>   `fail-coreutils` the 4 documented reds, `cargo test --lib` 1734 pass
>   / 48 fail = the 47-failure baseline PLUS one
>   (`estree::tests::file_target_redirect_collapses_into_builtin`, whose
>   `ls > \"$(cat …)\"` case now collapses — that input's inner is
>   `builtin("ls")`, which this fold provably refuses, so it belongs to
>   the uncommitted `try_builtin_redirect_collapse` extension landing in
>   shir.rs/estree.rs from another lane). Three tests were rewritten
>   because their PREMISE changed (a literal redirect no longer needs a
>   sink); two rust tests now pin the `fs::write` form and one keeps
>   sink coverage on the grouped `{ … } > f` shape the fold refuses.
>   **Core worker: RED 06:39, fixed.** The main checkout did not compile
>   — `shir.rs` called `crate::estree::fold_capture_echo_cond` with no
>   definition (another lane's half-landed edit), which takes down every
>   backend probe because `fail-estree` builds the main tree; an identity
>   stub in `estree.rs` restored buildability without touching their
>   line. Worker since: `main-checkout build=ok`, gate GREEN 07:19 +
>   07:40, A1-native 0 violations / 555 probed. One `./fail` run showed
>   `058_advanced_bash_idioms` red twice then green on re-run with
>   identical code: that example prints `find . -maxdepth 1` counts of
>   the SHARED workspace root, which other lanes were mutating between
>   the harness's two arms — environmental, not a regression.
> - v72: **the shared `${PIPESTATUS…}` observation verdict — 100 of 563
>   emitted Rust files were bookkeeping a register nothing reads.** Every
>   pipeline stage re-filled `__SH_PIPESTATUS` (a `static Mutex<Vec<i32>>`,
>   a `.clear()` at pipeline start and one `.push(rc)` per stage) whether
>   or not the program ever reads `${PIPESTATUS[i]}`; the corpus has
>   exactly ONE reader (`070_gnuisms_thorough`). New pure shared verdict
>   `shir::program_observes_pipestatus(prog)` Debug-scans stmts AND subs
>   — deliberately over-approximating: it matches the literal name, so a
>   read form the analysis does not know still counts as an observation
>   and the capture stays (a missed read would see 0 from a register that
>   was never filled, so erring toward keeping is the safe direction).
>   Rust's `Render::pipestatus_dead` consults it once per program and
>   skips the clear/push emission; the declaration was already in
>   `prune_unused_statics`'s name list, so it goes with it. Measured:
>   **files carrying `__SH_PIPESTATUS` 101 → 1**, and that one (070) keeps
>   all 34 of its mentions. The verdict sits in `shir.rs` beside the other
>   shared read-surface analyses (`ir_stmt_writes_lastexit`), available to
>   c's `need_pipestatus`/`scan_ps_stmts` and perl's
>   `fix_literal_pipeline_pipestatus` instead of each re-deriving its own
>   scan. Tests: `pipestatus_observation_verdict` (plain program=false,
>   a `param(…, "PIPESTATUS[0]")` word=true, a read inside a sub body=true)
>   and `pipestatus_capture_only_when_observed`. Gates: `./fail` rc=0
>   (563/563), `fail-estree` rc=0, **`fail-rs` 556 pass / 0 fail / 7 skip
>   (fresh, resumed=0)**, `fail-coreutils` the 4 documented parser-gap
>   reds, `py-rust-gate` 98/103 with the SAME 3 pre-existing FAILs (t82's
>   `got [] want [hi]` is byte-identical to the 23:47 pre-change run; its
>   Popen capture buffer is never flushed to stdout — a frontend gap, not
>   a render one), A1 probe 0 violations / 555 probed, `cargo test --lib`
>   1730 pass / 47 fail with the failing set byte-identical to the
>   pre-change baseline (no new reds). Worker: gate GREEN 05:12, A1
>   0/555 at 05:23, no trap markers.
> - v71: **the `%s`-template printf fold — the corpus's last big polyfill
>   cluster, at shIR level so every backend drops it.** `constant_printf`
>   only folded when EVERY word was literal, so any dynamic argument left
>   the statement on the runtime engine: 58 of 563 emitted Rust files
>   carried the `__sh_printf`/`__sh_q_printf`/`__sh_atoi`/`__sh_atou`/
>   `__sh_atof`/`__sh_printf_b` cluster (~135 lines each) for formats like
>   `%s=[%s]\n`. New sibling `printf_s_fold` needs only the FORMAT literal:
>   when every conversion is a plain `%s` with one argument per specifier
>   it splits the format into literal chunks, evaluates each with the
>   EXISTING `printf_const_eval` engine port (no re-port — same escape
>   table, zero-arg calls), and lowers to a native `IrStmt::Output` carrying
>   `InterpPart::Lit` runs around each argument expression (a one-part
>   result collapses to the bare expression, so the renderer emits
>   `print!("{}", v)` with no `format!` wrapper). Refusals, each keeping the
>   statement byte-identical on the runtime path: an escape that can
>   TRUNCATE (`\c`) or MINT a `%` (`\xHH`, `\0nnn`) — the split reads the
>   raw format and would miss a conversion the engine still parses;
>   padded/truncated `%s` (`%-10s`, `%.3s`) and every other conversion;
>   a specifier/argument count mismatch (bash reuses the format or pads,
>   and an unevaluated extra word could carry an expansion); and any
>   argument that expands to SEVERAL words — `${lines[@]}` arrives as ONE
>   `param("slice", …, "@", …)` word, so the static count lied and
>   `041_process_substitution_mapfile` printed the array's join where bash
>   printed one round per element (caught by `./fail`, fixed by the
>   `arg_expands_to_many_words` guard). Corpus: **engine files 58 → 9,
>   printf call sites 126 → 19, emitted Rust 53,358 → 43,034 lines
>   (−19.4%), casts 173 → 124 (−28%), `sh2.*` callouts 0**. Gates after
>   the fix: `./fail` rc=0 (563/563), `fail-estree` rc=0, **`fail-rs` 556
>   pass / 0 fail / 7 skip**, `fail-coreutils` the 4 documented parser-gap
>   reds, `py-rust-gate` 98/103 baseline-identical, A1 probe native,
>   `cargo test --lib` 1727 pass / 47 fail with the failing set IDENTICAL
>   to the pre-change baseline (no new reds). New tests: the `%s`
>   template shape, the one-part collapse, and the four refusal classes
>   (20 printf tests total). Worker: gate GREEN 03:22 + 03:44, A1 0/555.
> - v70: **two equivalence bugs the idiom work could not see — a status
>   write hidden from the verdict, and an `else` that outlived its
>   `elif`.** (1) *Process-substitution cleanup is transparent to
>   `$?`*: the core's `rm -f __ps_tmpN…` (appended by
>   `transforms/process_subst.rs::rm_exec`) is bash's own bookkeeping —
>   every renderer already carries the consumer's status across it
>   (Rust's `__ps_saved_rc`, fish's block arm, Perl's `$__ps_statusN`)
>   — but `ir_stmt_writes_lastexit` counted it as a real write, so the
>   backward scan let it SHADOW the consumer's write and the verdict
>   stripped the consumer's `__SH_RC.store`: `cmp -s <(echo b) <(echo
>   c); echo $?` reported the cleanup's 0 instead of cmp's 1. New
>   shared predicate `shir::is_ps_tmp_cleanup` (the recognition that
>   was previously re-implemented in three places) makes it a
>   non-writer; Rust's block arm and fish's `is_ps_tmp_cleanup` now
>   delegate to it, so analysis and renderers cannot drift about which
>   `rm` is synthetic. (2) *A taken `elif` makes the `else`
>   unreachable*: rust's `const_cond_truth` fold set `alt` from
>   `else_` whenever the head folded false and never cleared it when an
>   `elif` folded true, so BOTH the taken arm and the default arm were
>   spliced inline — `case Darwin in Linux|Darwin|*)` printed `Running
>   on macOS` AND `Running on other system` (000__04h). Gates after
>   both fixes: **`fail-rs` 556 pass / 0 fail / 7 skip (was 4 reds —
>   all four cleared: 070_cmp_basic, 064_01_complex_nested_subshells,
>   process-substitution, 000__04h)**, `./fail` rc=0 (563/563),
>   `./fail-estree` rc=0, `fail-coreutils` the 4 documented parser-gap
>   reds, A1 probe native, `cargo test --lib` 1714 pass / 47 fail with
>   the failing set IDENTICAL to the pre-change baseline (no new
>   reds). New tests: `shir::unread_status_tests` (procsub cleanup
>   does not shadow the consumer; transparency does not keep a
>   shadowed consumer; a user's `rm` still shadows) and
>   `rust_backend::literal_subject_case_drops_the_default_arm_when_one_matches`.
>   Worker: gate GREEN three consecutive cycles (01:38, 01:59, 02:19),
>   A1 0 violations / 555 probed.
> - v69: **the const-printf fold + cast purge — the idiom work v59 left
>   as spec, plus the core worker's second A1 red.** `echo_fold`'s
>   `constant_printf` now folds ANY all-literal printf through
>   `printf_const_eval`, a line-for-line port of the runtime
>   `__sh_printf` engine (same inline escape table with `\c`
>   truncation, flags/width/precision parse, length-modifier skip,
>   width padding and format-reuse loop; float and unknown conversions
>   REFUSE, keeping the statement on the engine byte-identically —
>   `-v`/leading-dash option forms refuse too). 27 all-const call
>   sites folded, dropping the whole `__sh_printf` polyfill cluster
>   (engine + `__sh_q_printf`/`__sh_atoi`/`__sh_atou`/`__sh_atof`) from
>   14 files (engines 72 → 58); the fold is shared, so every backend
>   drops its cluster wherever no other printf survives. Rust-side
>   idiom pass on the remainder: the engine's precision `-1` sentinel
>   became `Option<usize>` (−360 `as usize`, −216 float-arm clamps),
>   and a non-negative const index key now renders the `.get(k)` /
>   `{k}usize` fast path in `array_index_strict`/`_num`/`array_elem`/
>   `array_elem_set` + the three PIPESTATUS arms (−11 clamp templates,
>   0 literal-operand casts left) — the render-side twin of
>   `key_is_nonneg`'s dataflow proof, which only ever proved VARIABLE
>   keys. Corpus: 563/563 emit, casts **508 → 173 (−66%)**, `sh2.*`
>   callouts 0, dead helpers 0. Gates: `./fail` rc=0 (563/563),
>   `./fail-estree` rc=0, `fail-rs` 552 pass / 4 fail / 7 skip (the 4
>   are byte-identical to their pre-change emission — other lanes'
>   reds, entered before this session), `fail-coreutils` the 4
>   documented parser-gap reds, `py-rust-gate` 98/103 baseline-
>   identical, A1 probe 0/563. Worker fixes: (1) `run_core_worker.sh`
>   built `DEBASHC` BEFORE the ff to main, so every probe measured the
>   PRE-candidate binary and rolled `main` back each iteration — now
>   rebuilt after the ff (first GREEN 20:19 since the 13:55 red);
>   (2) the second A1 red: staged `harness/builtins.json` gained `ln`
>   (22:24) with no lift entry — `builtin::BUILTINS` synced to 75
>   entries and committed on main (59614de57) so the worker's ff picks
>   it up; same workspace-vs-embedded drift class as 864bfd3f5.
> - v68: **fb0 device hot-path rounds 1–3 + `BASH_O4_CFLAGS`, all bit-exact
>   against their own oracles.** The demo's CPU profile moved from a
>   rendered-C rasterizer (`_sh_sset` 16.8%, `_sh_arr_get` 13.5%) to ~99%
>   in the fb0 runtime, which then got three rounds of bit-exact trimming:
>   (1) `tri_covers`/divide/fract inlines, loop-invariant hoists and a
>   fused overlay pass — each an inline of the helper's own body with the
>   same operands in the same order, helpers kept as reference forms;
>   (2) present-time hoists + `BASH_O4_CFLAGS` (verbatim extra C flags,
>   folded into the exe cache key in both frontends — default NOT set,
>   because tcc must stay milliseconds and every one-shot corpus cell
>   would otherwise pay seconds): demo tcc→gcc -O2 −14.9% instructions /
>   −15.8% task-clock; (3) this revision: the three leftover per-frame
>   `fprintf(stderr)` debug prints removed, `ov_composite`'s flash half
>   gated by an arm-on-write/clear-on-consume dirty flag, `tri_shaded`'s
>   row terms hoisted (six double subtracts per row, not per pixel — px
>   stays per-pixel because an incremental walk flips last-bit at a power
>   of two), `frag_sample`'s dead lower clamps dropped behind a
>   `size > 0` guard, and `fbwin_present`'s identity depth-24 layout
>   written with one 32-bit store per pixel — demo instructions −5.1%
>   (tcc) / −2.7% (gcc -O2) at byte-identical renders (16 alternating
>   pairs, medians; `fbwin_present` 9.0%→1.8% and `ov_composite`
>   4.6%→1.5% of in-binary samples). Gates: fbdev suite 48 checks +
>   112-case silhouette green under cc AND tcc, stdout identical across
>   all bench arms, c-gate 584/650 with no red in any fb cell.
> - v67: **java and zig measured on a second box, and the gate defects that
>   were hiding their progress.** Neither backend could be measured here:
>   a `--backend-gate` pass builds the core and then holds the fleet's
>   single `.gate.lock` for all 654 files, so java had gone a full day
>   without a verdict and its last report said **0/654** — which was not a
>   renderer problem at all. Two gate-visible bugs: (1) the java
>   renderer's emitted child-sync helper was named `_sh2_env`, and the
>   stub check's `sh2[A-Za-z_0-9]+\(` matched its *definition*, so
>   EVERY file reported `stub(1)` (renamed `_sh_syncvar`); (2) java's
>   test-word emitter pasted `\"` into the Java SOURCE outside any
>   literal (`shQuote(\"…\")`), so javac died on `illegal character` for
>   whole files. With those fixed and the gate moved to an idle 12-core
>   box (`harness/remote-sync.sh` + `harness/backend_gate_remote.sh`,
>   same rules, 2.5 min per pass), the real baselines are **java 559/650**
>   and **zig 401/650**, from 0/654 and 392/650. Java's remaining 84 are
>   genuine lowering work (79 equivalence); zig's 242 are dominated by
>   *genuine* `sh2TODO` nodes after the TODO-comment double-count fix.
>   Real renderer bugs found and fixed on the way, all of them classes
>   rather than one-offs:
>
>   * **Fork semantics.** `shSnapshot`/`shRestore` were EMPTY stubs, so a
>     subshell's writes leaked into the parent (`( x=2 ); echo $x` printed
>     2) and a background job raced the parent's read
>     (`105_background_copy_semantics`). Both are now generated over the
>     program's own fields/arrays, and `{ …; } &` runs against a fork
>     snapshot.
>   * **Captured loops were dropped.** A `while …` stage's output was
>     captured into a helper whose bytes had no sink
>     (`while read …; done < f` printed nothing, 084/088/091), and a
>     redirect-fed loop was routed to a helper whose fd 0 is NOT the
>     redirect target — text first, always.
>   * **`mapfile`/`readarray` as java state**, not child-shell state
>     (the array field stayed empty and `${lines[@]}` printed a blank
>     line).
>   * **java's `${v+word}`** needs a set-ledger: Java cannot represent
>     "unset", and "0" is a non-empty string (the `contains()` status form
>     had the same trap).
>   * **zig's bash dynamic scope.** A function's writes are GLOBAL unless
>     `local`. The renderer emitted them as MAIN locals, so the body could
>     not see its own writes, and the value parameter invented to bridge
>     that collided with the fn's positional parameter or a runtime
>     helper's (`shToInt(s: …)`) — a build-break class, now a module-scope
>     `g_<name>` cell that main and the functions share.
>   * **zig's fused `[[ $s =~ ^re$ ]]`** was one token, so it became a glob
>     PATTERN match; it now splits and matches through a bash child (no std
>     regex).
>   * **Honest TODO counting.** The `TODO(unsupported)` marker is no longer
>     written into the emitted program: the gate counts the marker, so one
>     construct cost two stubs and a file whose only stub was a rendered
>     call still reported one for its own diagnostic comment.
>
>   Gate-rule traps this surfaced (each one made a WORKING renderer look
>   broken): `SUB`/`ROOT` must be EXPORTED in the remote worker (its body
>   runs in a `bash -c` child — unexported, the zig arm linked
>   `-L"/runtime/lib"` and every file "failed to build"); zig resolves its
>   source path against the CWD, so it needs `./p.zig` and the uu-ffi
>   `-lc/-lcoreutils_ffi/-rpath` flags; `OTRANSPILER_ROOT` must be exported;
>   and the bash REFERENCE side must run with `BASH_ENV` unset (this box's
>   `BASH_ENV` exports shell FUNCTIONS that only bash has).
> - v66: **`A || true` captures fold to one run with forced status — and
>   the partial-output bug they were hiding.** The generic
>   `chain_or_capture` form ran the RHS INSTEAD of keeping `$__c`: for the
>   no-op status command that forked a whole `bash -c true` for an empty
>   string AND discarded the LHS's partial stdout — `x=$(ls f g
>   2>/dev/null || true)` printed f's line under bash and NOTHING under
>   the generated Perl (real divergence, unexposed by the corpus: both
>   sites are pgrep/cat-shaped with no partial output). The fold emits
>   `do { my $__c = <lhs>; $CHILD_ERROR = 0; $__c }` — one fork, status
>   constantly 0 as bash defines it, output untouched; the forced write
>   rides `rc_write` so status-liveness elision still applies. Guard is
>   structural (`is_noop_status_cmd`: bare `true`/`:` with no words;
>   `expr_to_cmd` single-quotes literal names, so the first text-guard
>   attempt never matched and the probe caught it). Non-noop RHS keeps the
>   generic two-arm form byte-for-byte. Measured: 2 → 0 noop forks,
>   pipe_capture sites 58 → 56, exactly 2 corpus files changed;
>   `./fail` **562/562**; `perl -c` + `check_qx` clean; 4 unit tests.
>   Submodule `71b584d29`.
> - v65: **the Perl external-command seam gated per segment — 418 dead
>   subs retire, generated corpus −30%.** `SH_RUN_EXT_PREAMBLE` was ONE
>   blob on four coarse entry markers, so a body calling only
>   `__sh_uu_capture` embedded the whole pipeline front end and vice
>   versa: 418 of 826 embedded `sub` instances across the 562 examples
>   were never called (44 files uu-only, 55 pipe-only, 19 both, 444
>   none). `sh_run_ext_preamble()` splits the blob at line boundaries
>   (`split_inclusive` makes the all-live reassembly byte-exact — pinned
>   by test) and emits each segment only when the body names it or a
>   live segment needs it: `__sh_pipe_capture` drags uu SUPPORT for its
>   shared `$__SH_UU_SEQ`, `__sh_q` is gated on its own body marker, and
>   `# __SH_RUN_EXT_END` always closes so check_qx's strip keeps its
>   anchor. Entry markers unchanged (no new seam can appear; a false-
>   positive marker only over-emits). Measured: 826 → 320 definitions,
>   0 uncalled, 0 call-without-def, corpus 1,464,718 → 1,023,493 bytes;
>   `./fail` **562/562**, `perl -c` + `check_qx` clean, 5 new unit tests.
>   NOTE for the fleet: `cargo test --lib` currently has **14 pre-existing
>   reds** (9 c_backend, 5 fish_backend) that predate this work — the
>   crate did not compile at HEAD since `Function.params` landed, so the
>   suite could not run; proven pre-existing at `201f0c9c4` + the
>   one-line params fix (identical 14 fail). Submodule `627cbb5a8`
>   (segment gate) on top of `e60cb9b82`/`e4ad098d7`.
> - v64: **Perl redirect emit made idiomatic — the print-only
>   lexical-select fast path (75 of 111 dance sites convert).** A
>   `Redirect` over a non-command inner used the heavy dup/close/reopen of
>   the REAL STDOUT glob even when nothing in the body could fork — a
>   shape whose whole reason is that children inherit the redirected fd 1
>   (`capture_do_perl` argues the same from the capture side). For a body
>   whose every output is a bare Perl `print`, `select` on a LEXICAL
>   filehandle routes the same bytes without mutating a global handle: a
>   `die` mid-body can no longer leave STDOUT closed, and each site emits
>   2 lines instead of 5. Refuse>guess keeps every forking body on the
>   proven heavy path byte-for-byte (the `capture_do_perl` spawn-marker
>   vocabulary plus the capture seam, qx/backtick), and any body
>   mentioning the STDOUT glob falls back too — `063_14`'s pure-Perl diff
>   emulation holds `my $__fh = \*STDOUT; print $__fh …`, an explicit
>   alias that bypasses `select($fh)` and only the reopened glob serves
>   (the gate caught it, then the marker list pinned it). fd-2 redirects
>   keep their existing shape. Also fixed the shared crate's compile:
>   `fish_backend`'s `IrStmt::Function` lift was never given the core's
>   new `params` field, so HEAD failed E0063 for every worker. Verified:
>   `./fail` **562/562** (the `test_find` CWD-churn flake was diagnosed as
>   environmental first — deterministic generation, byte-equal arms in
>   quiet windows); `perl -c` + `check_qx` clean over all 562 generated
>   files. Submodule `e60cb9b82` (fish params) + `e4ad098d7` (fast path).
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

> - v107: **Two lint classes normalised by changing the SHAPE, not by
>   renaming or allow-ing around it.** rustc census: 48 → 22.
>   (1) **`__sh_printf`'s dead initializer (9 sites).** The helper declared
>   `let mut piece = String::new();` and then assigned it in EVERY match
>   arm, so rustc reported "value assigned to `piece` is never read" once
>   per arm. The match now IS the initializer — the arms that also apply a
>   `.prec` truncation get a local `t`, the rest return their value — and
>   the helper is emitted with no warnings at all (`printf '%s|%d|%05.2f|%q'`
>   verified byte-for-byte against bash).
>   (2) **A user function keeps its shell name, with the attribute it needs.**
>   `exitScript`, `INFO`, `test` are the SOURCE's names: callers use them and
>   `typeset -f` prints them, so renaming to snake_case would be a
>   miscompile. An uncalled definition is legal shell too (and observable via
>   `declare -f`), which is exactly why dead_fn_elim refuses to drop it — so
>   the definition carries `#[allow(non_snake_case, dead_code)]` (the
>   snake-case half only when the name has an uppercase letter). Pipeline
>   helpers deliberately keep `dead_code`, so a genuinely orphaned runtime
>   helper still trips the lint.
>   Gates: `./fail` 563/563, fail-rs 556/0/7, fail-estree 563/563 (100%),
>   fail-shir green. `cargo test --lib` 1733 pass / 46 fail — the same 45-red
>   backlog plus the one c_backend red from the other worker's in-flight
>   changes (`src/c_backend.rs`, `src/shir_passes/numeric_observed.rs`,
>   `src/transforms.rs` and `src/transforms/dead_store_elim.rs` are dirty in
>   the shared checkout and were NOT staged; this round committed
>   `src/rust_backend.rs` alone).
> - v106: **Every `unused_parens` class in the emitted Rust is gone — one
>   helper at the `emit` choke point instead of a hunt per template.**
>   rustc census over the 563-file corpus: 74 → 48 (all four paren classes
>   to zero).
>   (1) **`strip_let_parens` at `emit`.** A `let` takes any expression, so
>   the pair the renderer wraps around a compound value is pure text there
>   — "unnecessary parentheses around assigned value" (5 sites). Fixing it
>   where EVERY statement is pushed means no future template can regress it
>   (the previous round's per-site `let_value` call was whack-a-mole: the
>   array-store template had its own `let __k = (…);` left over). The scan
>   refuses a tuple (`let (a, b) = (x, y);` must keep its pair) and a `==`
>   that is not the binding's `=`, and touches only a pair that closes
>   right before the `;`.
>   (2) **`unparen_deep` for conditions.** `unparen` strips ONE pair, but a
>   glob test renders `(__sh_fnmatch(…))` and the case chain adds another,
>   so `} else if (…)` survived a single strip (4 sites). Repeated
>   stripping is sound exactly in a condition (a bool cannot be a tuple).
>   (3) **`__sh_div`/`__sh_mod`/`__sh_pow` arguments** go through the
>   comma-safe helper — an argument takes any expression too (4 sites).
>   (4) **A `{{`/`}}` template that was never a `format!`.** The `$!`
>   value is a plain `String` other templates splice with `{}`, so its
>   escaped braces were emitted VERBATIM — `*v.borrow_mut() = {{ let __p =
>   … }}`, a doubled block rustc flagged at 4 sites (grep_p, dollar-bang).
>   Same class as the `"!"` arm fixed in v103; both now single-braced.
>   Gates: `./fail` 563/563, fail-rs 556/0/7, fail-estree 563/563 (100%),
>   fail-shir green. `cargo test --lib` 1728 pass / 46 fail: the 45-red
>   backlog plus ONE new c_backend red
>   (`unsigned_mod_refuses_unranged`) that is NOT this round —
>   `src/c_backend.rs` and `src/shir_passes/numeric_observed.rs` are
>   modified in the shared checkout by another worker's in-flight work, and
>   this round committed `src/rust_backend.rs` alone.
> - v105: **One shared verdict replaced three copies of "does this list
>   fall through", and the Perl gate caught the first version being
>   UNSOUND.** rustc-warning census over the 563-file emitted corpus: 91 →
>   74 (`while_true` 3 → 0, assigned-value parens 10 → 5, unreachable
>   statement 6 → 3).
>   (1) **`shir::{stmt_terminates, list_terminates, loop_escapes}`.** One
>   definition of "terminator" — `exit`/`die`/`break`/`continue`,
>   `return` inside a function, and an INFINITE loop (`while true` /
>   `for ((;;))`) that no `break` can escape — consumed by the
>   unreachable-tail transform AND by the Rust renderer (epilogue, redirect
>   restore), so "dead after `exit`" and "dead after `while true`" cannot
>   drift apart.
>   (2) **`unreachable-after-exit` → unreachable-after-terminator.** It now
>   prunes after `die`, `break`/`continue` (for the list they sit in) and an
>   infinite loop, and it recurses into a function's `named_blocks` — the
>   old code rebuilt `Function` with `named_blocks: Vec::new()`, DELETING a
>   Go-style named return block (statements and all) on every program the
>   transform touched. 7 new tests, including the nested-loop case (a
>   `break` in a deeper loop does not escape) and the `case` case (bash's
>   `case` captures nothing, so a `break` in a clause still breaks the
>   loop).
>   (3) **The unsoundness, found by `./fail`.** `while true; do break ||
>   exit 1; done` keeps `break` as a CONTROL CALL inside a `BinOp`
>   (`func: "break"`, purity Control), NOT as `IrStmt::Break` — so the
>   loop looked infinite and the transform pruned everything after it:
>   `parse-break-or` printed nothing where bash prints `parsed OK` /
>   `exit: 0`. The scan now recurses into `If`/`Case`/`Block` bodies and
>   falls back to the statement's Debug form for the call spelling. An
>   over-approximation only keeps a tail that is dead anyway; an
>   under-approximation deletes live code, which is what the gate caught.
>   (4) **A TLS numeric read no longer clones.** `read_num_of_str` parses
>   INSIDE the borrow — `__SHV_x.with(|v| v.borrow().trim().parse::<i64>()…)`
>   — where the `read_str`-based form cloned a String per read (88 corpus
>   sites: `__SHV_y.with(|v| v.borrow().clone()).trim()…`).
>   (5) **`while true {` → `loop {`** (rustc's `while_true`; the programs are
>   identical, a plain `break` leaves both as `()`), and **`let x =
>   (EXPR);` → `let x = EXPR;`** via a new `let_value` helper that strips
>   one pair only when it encloses the whole initializer (refusing a tuple
>   or an early depth return).
>   (6) **Epilogue / restore after a diverging body.** The implicit
>   `std::process::exit(__SH_RC…)` and the `__SH_OUTFILE_TL` restore are
>   skipped when the body never falls through (the shared verdict, plus a
>   guard for the case where another layer already emitted the exit).
>   Gates: `./fail` 563/563, fail-rs 556/0/7, fail-estree 563/563 (100%),
>   fail-shir green; `cargo test --lib` 1727 pass / 45 fail — unchanged, no
>   new reds (the 45 are the pre-existing backlog in
>   c_backend/estree/shir/fish/zsh/shir_json_in/zig/go).
> - v104: **Analysis of the emitted Rust found two RENDERING BUGS (not idiom
>   gaps) plus two needless allocations; nine stale expectations refreshed.
>   fail-rs 543/13 → 556/0/7, every other gate green.**
>   (1) **A const-folded `elsif` ran the `else` too.** A `case` on a constant
>   subject lowers to an if/elsif chain whose conditions all render as
>   constants, so the Rust renderer decides the chain at emit time. When an
>   `elsif` is proven TRUE the code took that body but never cleared `alt`,
>   which still held the `else_` body — so BOTH were spliced inline and both
>   ran: `000__04h_complex_examples` printed its matching arm and its `*`
>   default back to back (Perl, which folds in the IR, was correct, so only
>   the Rust arm diverged). One line: `alt = &[]`; test
>   `const_case_takes_exactly_one_arm`.
>   (2) **`typeset -f` lost a folded `echo`.** `echo_fold` lowers a literal
>   `echo` to the native `Output` statement, but `fn_body_line_text` (the
>   `typeset -f` / `declare -f` definition display) had no `Output` arm, so
>   the body line printed empty: `myfunc () \n{ \n    ;\n…}` where bash
>   prints `    echo "Inside myfunc";`. The arm puts the `echo` back (quote
>   when the text carries a space or an expansion); test
>   `typeset_f_shows_a_folded_echo`. This was fail-rs's last red.
>   (3) **`echo "$n"` on a numeric var allocated a String.** The `Output`
>   arm's numeric test was `echo_fold::numeric_word`, the TARGET-FREE verdict
>   (literals, arith, lengths) — a numerically-homed VAR is only visible to
>   the renderer, so the word list rendered `vec![n.to_string()]` and the
>   inlining pass collapsed it to `println!("{}", n.to_string())`. The arm
>   now also consults `word_is_numeric`, and `word_is_numeric` sees through a
>   one-part `Interpolate` (a QUOTED lone expansion arrives wrapped, so
>   `echo "$n"` printed `.to_string()` while `echo "n=$n"` printed `n`).
>   (4) **`.clone()` before a borrowing `.trim()`.** `read_num_of_str`
>   appended `.trim()` to an OWNED read, so every numeric read of a
>   string-homed var carried a clone: `x.clone().trim().parse::<i64>()` →
>   `x.trim().parse::<i64>()` (reuses `drop_trailing_clone`, which refuses a
>   call/index receiver, so only a bare path is un-cloned).
>   (5) **`$?` / `$$` / `$#` stringified an integer.** `expr_any` appended
>   `.to_string()` to reads that `getvar_num` renders as an integer — the rc
>   load, the pid, the argv length — so `echo "rc=$?"` allocated a String for
>   every status echo. `word_is_numeric`'s `getVar` arm now accepts those
>   three names (they are integers BY CONSTRUCTION, so the verdict cannot
>   drift from the reader). Corpus-wide: rc stringifications 177 → 17, pid
>   4 → 0, argv-length 3 → 2 (the 17 are `$?` reads reached through a shape
>   that is not a bare `getVar` word).
>   (6) **Nine stale `rust_backend` expectations, invariants kept.** They
>   pinned the older, heavier emission: `__sh_puts` → `__sh_print_words`;
>   a literal-path redirect is now a bare `std::fs::write` with NO sink
>   runtime (the run-time-path variant `> "$1"` keeps `__SH_OUTFILE_TL` and
>   the sink-aware printer, which is what those tests now assert); and a
>   const-folded condition/arith cannot exhibit the shape it pins, so the
>   numeric tests use a run-time operand (`x=$1`) — `exit $((x+1))` keeps
>   `as i32` only when the value is not folded, `x=1` folds to `exit 2`.
>   Gates: fail-rs 556 pass / 0 fail / 7 skip (was 543/13/7 — the earlier
>   "13" reading was a RESUMED verdict log, not a live run: `RS_GATE_OUT`
>   must be cleared between rounds); `./fail` 563/563; fail-estree
>   563/563 (100%); fail-shir green (7 shell-out sites, 311 body bytes);
>   `cargo test --lib` 1718 pass / 45 fail — `rust_backend::` is now 0 reds
>   (was 10) and every remaining red is the pre-existing backlog in
>   c_backend/estree/shir/fish/zsh/shir_json_in/zig/go.
> - v103: **The first Tier-1 Isabelle session for a pass MIMEcroft actually
>   fires: `string-accumulator`, and the bug it exposed is fixed with a
>   failing-first test.**
>   (1) **Why this one.** Of the three passes MIMEcroft fires, this is the
>   only one whose verdict is IR-shaped (Tier 1): the C consumer
>   re-walks the tree (`acc_vars_tree`) and tracks four accumulators
>   (`blk_p`, `tup_rp`, `tup_gp`, `tup_bp`; 15 `_alen_` sites), so a wrong
>   verdict is a live miscompile, not an inert gate.
>   (2) **The session.** `proofs/StringAccumulator` — 18 lemmas,
>   `quick_and_dirty = false`, green in ~1 min, registered in
>   `harness/transform-proofs.sh` (whole-directory run: `OK
>   proofs/StringAccumulator`). It models the three walks one constructor
>   per arm (§2), keeps the PRE-FIX walk as the negative control and
>   machine-checks the report's witness (`the_fix_is_load_bearing`: an
>   `Arith(AVar v)` IS a read and the catch-all does not see it), proves
>   carrier completeness (redirect, subshell, block, background, pipeline
>   stage, function body + named blocks, ForInit, try + except clauses, case
>   clause body AND pattern, thunk, comprehension, arith index key, arith
>   assign rhs), and the first-read position rule
>   (`before_any_read ⟹ ¬ stmts_read`). Replacing the fixed arm with the
>   pre-fix `False` makes the session FAIL — the control is real.
>   (3) **The code fix, checked but awaiting re-land.** `arith_read_walk` +
>   the missing `IrExpr` arms + a carrier-complete, wildcard-free
>   `read_walk` + a recursive `self_append_vars` that treats `continue` as a
>   non-write surface. 11 module tests green; restoring
>   `IrExpr::Arith(_) => {}` turns exactly one red (the no-arith control
>   stays green). Landed on a branch off `12b304ddf` — the analysis version
>   the bug reproduces in — because main's `acc_vars_tree`/`lower` work is
>   uncommitted and cannot be replayed around. Offer + re-land recipe:
>   `core-requests/done/string-accumulator-walk-20261030-120000.md`.
>   (4) **The manifest now carries a real `proof:` line**, and the gate
>   builds it: `proof/Claim.thy` re-checks the core of the same statement
>   from source as its own session (`StringAccumulatorClaim`), so the claim
>   cannot be satisfied by another session's stale heap. Whole gate:
>   **7 checked-and-built, 0 stated-only** (`proofs/` itself is red from
>   another lane's untracked `Maskable` session, not this round).
>   (5) **Not done, deliberately:** the lowering (push/join) stays Tier 3;
>   `sync-ok-loops` criterion 2 and `process-subst` remain unproved (the
>   first now fires on MIMEcroft but changes no emitted byte, the second is
>   filesystem statement semantics).
> - v102: **The parked-transform census: eleven transforms adjudicated by
>   measurement, one live defect promoted out of the parked set, and three
>   stale firing counts in `docs/transform-verification.md` corrected.**
>   (1) **Firing, measured two ways** (in-process `ast_to_ir_raw` + one
>   transform at a time; plus a re-run on the fully optimised IR; plus
>   `bash-o4/MIMEcroft_fb.sh`, 293 commands → 279 stmts, where a corpus
>   count under-sells the pass): `process-subst` 16/563 (pipeline only) and
>   `type-query` 1/563 change the IR; `sync-ok-loops` records 43 files / 52
>   verdicts and `string-accumulator` 1/563 at the top level; the other
>   seven are 0/563 — including `for-recovery` and `inline-pure-fns`, the
>   latter despite 59 corpus files defining functions. `planner` is not in
>   `transforms::all()` (a manifest+solver mechanism) and `sub` returns
>   `false` unconditionally.
>   (2) **MIMEcroft contradicts the corpus denominators twice.**
>   `sync-ok-loops` computes 19 `sync_ok` + 1 `batch_ok` verdict there and
>   emits byte-identical estree with the pass on and off; `string-accumulator`
>   has an EMPTY top-level verdict but C's `acc_vars_tree` tree walk
>   (`c_backend.rs:9837`, over `prog.stmts` and every `sub.body`) tracks
>   four accumulators (`blk_p`, `tup_rp`, `tup_gp`, `tup_bp`; 15 `_alen_`
>   mirror sites). That walk is `read_walk`, which has `_ => {}`
>   catch-alls and no `IrExpr::Arith` arm — so
>   `tsv="$tsv$x"; n=$(( tsv + 0 ))` inside a loop still yields
>   `Accumulator { var: "tsv" }`. Filed as open bug 11 in `BUGS_FOUND.md`
>   with the witness, three measured containment facts (estree `lower()`
>   never runs end-to-end on the shell-source CLI path; the C gates refuse
>   the witness independently; MIMEcroft's four accumulators have no
>   `$(( ))` self-read), the owner-call fix, and the regression shape.
>   (3) **Tier verdicts.** Seven are Tier 3 (loop-fusion/inlining traces,
>   fork/thread, call preservation, filesystem statement semantics); the
>   Tier-1 fragments that exist (`sync-ok-loops` criterion 2,
>   `string-accumulator`'s walker, `type-query`'s builtin table) are either
>   conservative by construction, defective, or trivial — so **no new
>   Isabelle session**: proving them today would certify the thin part, and
>   for `string-accumulator` would certify the hole. `for-recovery` keeps
>   its green `proofs/ForRecovery` session, still a dead contract.
>   (4) **Stale counts corrected in `docs/transform-verification.md`.** The
>   2026-10-24 corpus table re-run on today's 563 files reproduces every row
>   except `test-lowering` (43/562 → **42/563**) and `counted-while-forinit`
>   (**0 → 9/563**, the 2026-10-26 `Arith`-wrap fix). The corpus-wide
>   `For`/`ForInit` total is **44 raw → 51 full `ast_to_ir`**: the old
>   "49 OFF → 47 ON, the passes recover none" claim predates the fix and is
>   superseded. A new §"The parked-transform census" carries the table and
>   the three lessons (a firing verdict is not a live gate; a pass's corpus
>   count is not its reach; proved ≠ reachable).
>   (5) **No code changed.** `BUGS_FOUND.md` gained bug 11 + the census
>   section (commits `e815ba10`, `e461e474`); `docs/transform-verification.md`
>   gained the census section and the three re-measured counts. All gates
>   stand on their last measured state; nothing in this round touches
>   `src/`.
> - v101: **Triage-and-repair: six red unit tests fixed at the root
>   (two real transpiler bugs in shared code, one missing caller in the
>   C backend's GMP gate), the round's temporary instrumentation
>   removed, and every equivalence gate re-run green against its own
>   documented baseline.**
>   (1) **`drop_dead_top_decls` no longer deletes a side-effectful
>   initializer.** The estree dead-decl sweep dropped a top-level `let`
>   whose binding no live code read — but the INITIALIZER carries the
>   whole effect: `x=$(diff a.txt b.txt)` runs diff (and `echo $?`
>   reads its status), ``files=(`sort <<< "$y"`)`` runs sort. A
>   capture/array-shaped RHS now keeps the declaration (the binding
>   stays, the command runs); only a genuinely constant initializer is
>   still droppable. Verified with the drop probe before it was
>   removed: the capture survived as a bare statement instead of
>   vanishing with its binding.
>   (2) **`echo_fold`'s `fold_narrow` descends `Function` bodies.**
>   `fold_narrow` — the only walk that folds `echo` — had no `Function`
>   arm; the only walk that DID descend functions (`fold_wide`) is
>   printf-only by design. So a constant `echo` inside a function never
>   folded on ANY backend, and every backend re-rendered one constant
>   as a slot split. Root cause found by diffing the IR of the failing
>   in-function shape against its working top-level twin — the shapes
>   were IDENTICAL, which localised the refusal to `fold_narrow`'s
>   entry gating (the pre-split `fold_stmts` had the arm; the narrow /
>   wide refactor dropped it).
>   (3) **Pins follow behaviour, not a frozen input spelling.** The
>   estree test pinned the runtime call's old name `pipelineSync`; the
>   capture path emits `pipelineCaptureSync` — pin updated. go/zig's
>   `if_arith_test` fed a single-site `x`, which the shared const pool
>   now seeds, so `y=$((x+1))` folded to `y = 4` at lowering and the
>   arith ASSIGN the pin exists for could never render; both inputs
>   gained a second runtime-guarded site (`[ -n "$1" ] … x=9`) that
>   keeps `x` symbolic while BOTH asserts (arith condition + arith
>   assign) stay meaningful. The rust twin already carried that shape.
>   (4) **c_backend: the GMP sorted-join helper's definition gate was
>   missing one of its two callers.** `_sh_sorted_bigint_join`'s
>   definition sits behind `if !array_return_fns.is_empty()` in
>   `emit_runtime`, justified by “it is only ever CALLED for an
>   array-return function” — but `sorted_join_call` and its inline twin
>   emit the CALL unconditionally at every `sortedBigintJoin` value
>   site (setting `need_gmp`, never opening the gate). A top-level
>   `echo $(sortedBigintJoin a)` therefore linked against a symbol
>   nobody defined, and the `mpz_cmp`-presence pin
>   (`c_backend::tests::sorted_join_nodes_lower_natively`) went red
>   somewhere between the 10-28 21:54 green run and the 10-29 03:00
>   baseline. Fix: an exact `sorted_bigint_join_used` flag set at both
>   render-time call sites — body render precedes `emit_runtime`, so
>   the gate reads a final fact — deliberately NOT widened to
>   `need_gmp`, so the cli_hygiene regression the gate exists for
>   (`mpz_t` without `<gmp.h>` on a program with no bigint) cannot
>   return: `bash-o4 cli_hygiene` 2/2 green after the change.
>   (5) **Two wrong-answer bugs in shared shIR passes, from this
>   round's earlier interrupted turns.** `dead_store_elim`'s census now
>   treats a store-key-shaped string literal (`setArray("t1", …)`,
>   `x = "t1"`) as the dynamic READ it is — a name flowing as data
>   resolves against the store at runtime, and without the mark the
>   pass judged `t1` never-read and DELETED its definition (the
>   t84-tuple-field empties; core-requests/stalled/
>   rust-20261029-011959) — while a Call's `args[0]` (the command /
>   write's own NAME) is no longer counted as a read, which had been
>   switching the whole pass off. `copy_propagation` now counts
>   `${NAME=word}` / `${NAME:=word}` expansions (and a `param` write
>   anywhere in the RHS) as def sites: the write used to be invisible,
>   so `x=""` kept count==1 and the fold propagated a stale literal
>   ACROSS the write — `echo ${x:=d}` printed the pre-write value in
>   every backend. Both edits only ADD refusals (conservative
>   direction); the corpus and lib gates below hold with them in the
>   tree.
>   (6) **Instrumentation removed.** The `tmp_probe_empty_body` test
>   (a `panic!("probe done")` diagnostic) and all six `SH2_PROBE` env
>   blocks in `shir.rs` (pre/extend/stage prints + the For-slot dump)
>   are gone; `zz_probe3` predates this session (it is in HEAD) and
>   stays.
>   (7) **Verification of record.** `./fail` **563/563, 0 failed**;
>   full `./fail-estree` **PERL 563/563 + ESTREE 563/563 (100.0%)**;
>   `fail-rs` **556 pass / 0 fail / 7 skip** (fresh run — the stale
>   03:30 verdicts log was archived to `verdicts.log.pre-1150` so the
>   resume logic could not re-count old verdicts against the new
>   binary); `py-rust-gate` **98/103** (the documented t104/t82/t87
>   reds + 2 known-gap, byte-identical to its recorded baseline);
>   `c_gate_main` **588/56/7 with a FAIL set byte-identical to the
>   10:14 same-day baseline**; `cargo test --lib` **1840 pass / 48
>   fail / 5 ignore** — the 03:00 baseline carried 54 reds, this round
>   cleared 5 in the triage + 1 with the GMP gate, and the final set
>   diff shows exactly those removals and nothing new; bash-o4
>   `cli_hygiene` **2/2**. Core worker **GREEN** (gates 10:00 / 10:29 /
>   10:58, A1 invariant 555 probed / 0 violations / 0 probe-failures,
>   supervisor up 1d9h — its 10-27 isolated-build failures are
>   recovered). The remaining 48 lib reds are the documented
>   pre-existing set (c_backend/estree/fish/shir pins, several owned by
>   other lanes' uncommitted in-flight edits — `c_backend.rs` was
>   rewritten by its lane at 11:56 while this round worked, which is
>   why the triage diffs against same-day baselines rather than a
>   day-old snapshot). Gitlink deliberately not bumped (worktree
>   carries other workstreams' edits).
> - v100: **The emitted Rust's largest idiom class — `print!` with a
>   trailing newline — goes to ZERO (837 → 0), and the shared
>   `interp-lit-merge` shIR→shIR offer is accepted by Rust now that the
>   reason it declined is fixed at the source.**
>   (1) **CENSUS r14 + a new instrument.** Fresh 563-file corpus, rustc
>   default lints: 0 compile errors, 9 warnings (byte-identical kinds to
>   r9–r13), 1.72 MB. rustc's own lints were exhausted, so this round
>   added a **clippy census** (`clippy-driver` per emitted file, default
>   lint set) over the whole corpus: **638 lints**. The histogram said
>   the debt was NOT in casts — one `unnecessary_cast` corpus-wide — but
>   in the PRINT spelling: `print_with_newline` alone was **312**, half
>   the total, then `useless_vec` 73, `unnecessary_to_owned` 36,
>   `print_literal` 32, `format_in_format_args` 31, `needless_borrow` 27,
>   `get_first` 21.
>   (2) **Why it was systematic.** Two arms (the const-echo fast path and
>   the `Output { Str }` arm) build the line WITH its newline and always
>   chose `print!`; the 707 other `println!` sites came from everywhere
>   else — so the macro depended on WHICH arm rendered the statement,
>   never on the line's shape. 837 of the 1064 `print!` sites ended in
>   `\n`.
>   (3) **Both arms now emit `println!`** when the line carries its
>   trailing newline (byte-identical through the same `Stdout`, so
>   buffering and ordering are unchanged), and ONE final-text sweep —
>   `print_to_println`, string/char/comment-aware, REFUSE > GUESS — closes
>   the class for every other source (the folded constant `printf`, a
>   render-time-constant format, any arm added later). The sweep walks a
>   literal body pair-by-pair, so a body ending in an ESCAPED `\n`
>   (`"a\\\\n"` = `a`,`\\`,`n` — no newline at all) is refused rather than
>   mis-trimmed, and a `print!` merely MENTIONED inside a string or a
>   `//` comment cannot start a group. `print!("\n")` becomes `println!()`
>   rather than `println!("")`.
>   (4) **The shared win: `interp-lit-merge` accepted by rs/rust.** The
>   marketplace entry was gated to `zig` only, and its own comment records
>   why Rust declined: *"rust expects a `println!` where it now emits a
>   direct `print!`"* — the merge froze the word, the constant echo
>   reached the `Output { Str }` arm, and that arm spelled the line
>   `print!("…\n")`. (3) fixes exactly that at the source, so the offer
>   lands for the target that refused it. Payoff measured on the corpus:
>   **155 redundant shIR nodes** — 45 `Interpolate` parts whose expr is
>   already a frozen literal `Str`, 103 single-literal `Interpolate`s and
>   7 multi-literal ones — each re-rendered as a format/slot split for
>   text that is ONE constant, by EVERY backend (Perl, C, ESTree/JS, Go,
>   Python, Java, …). After the change the example reads
>   `println!("Echo result: Hello from backticks")`: the merge fired AND
>   the line is idiomatic.
>   (5) **Pins follow behavior, not spelling.** 12 `rust_backend` tests
>   pinned `print!("s1\n")`; they now pin `println!("s1")`, and the
>   case/echo tests that only care a WORD printed go through a new
>   `prints_word` helper accepting BOTH spellings, so the next macro
>   choice cannot re-break them. One new test,
>   `print_with_trailing_newline_becomes_println`, pins the sweep's nine
>   cases (literal-only, with-args, `eprint!` twin, no-newline refusal,
>   escaped-`\n` refusal, one-of-two trim, string-literal mention, `//`
>   comment, empty line).
>   (6) **Verification.** `./fail` **563/563, 0 failed**; `fail-estree
>   --gate` **563/563** (PERL 563/563 and ESTREE 563/563 both);
>   `fail-rs` **556 pass / 0 fail / 7 skip** (green on the final binary);
>   `cargo test --lib` **1894 passed / 51 failed** against a 1886/51
>   baseline — **zero new rust_backend failures** (all 12 pins green),
>   two baseline reds now green, and the only 2 new names
>   (`c_backend::tests::{ver_emits_fast_slow_clones,
>   unsigned_mod_refuses_negative_capable}`) reproduce in ISOLATION and
>   belong to another lane's uncommitted `c_backend.rs` (+2813/−364,
>   written 20:18, after this round's edits). clippy **638 → 306 (−52%)**,
>   `print_with_newline` **312 → 0**; rustc 9 warnings (identical kinds),
>   0 errors, 332/563 files byte-improved, +7 bytes total. Core worker
>   **GREEN** (21:59 gate, supervisor alive, no `sleeping-*` markers).
>   Left for next round: `useless_vec` (73 `&vec![…]` word arrays),
>   `unnecessary_to_owned` (36 literal `.to_string()` args), `get_first`
>   (21 `.get(0)`) — all render-site idioms.
>   **HAND-OFF STATE (23:0x): the shared checkout stopped building at
>   22:34, NOT from this round.** Another workstream rewrote four modules
>   (`unreachable_after_exit.rs` — `terminates_list` deleted, 127 lines
>   left; `string_accumulator.rs` — `callee_write_sets`/`Cw` deleted;
>   `dead_store_elim.rs` — `census`/`is_shell_implicit`/`expr_pure` and
>   `split_inplace::exported_names` de-`pub(crate)`ed) while their two
>   consumers still call the old API (`rust_backend.rs` ×3,
>   `arr_load_fwd.rs` ×1 imports) — and `arr_load_fwd.rs` was still being
>   rewritten at 23:07, so the lane is mid-edit. 8 compile errors, all
>   named after symbols that lane removed; the CORE WORKER independently
>   logged *"main checkout does NOT build (every backend probe will
>   fail)"* at 22:50. Every gate number above was measured BEFORE 22:34,
>   on a build containing this round's changes (CLI built 21:54), and all
>   three equivalence gates plus both censuses were green on it. Nothing
>   of this round's was reverted: `print_to_println`, the two `println!`
>   arms, `prints_word`, and the `Some("zig" | "rs" | "rust")` manifest
>   line are all still on disk. The breakage was left to its owner —
>   repairing it here would mean inventing that lane's new API mid-write.
> - v99: **ONE exhaustive huge-constant/bigint verdict family replaces ten
>   drifted private walkers; the shared descent gains `AnyNode::Stmt` plus
>   full-visit `*_each`, and `typeset -f` stops dropping folded `echo`
>   statements.**
>   (1) **CENSUS r13.** Fresh 563-file corpus, rustc default lints: 0
>   compile errors, 9 warnings (byte-identical kinds to r9–r12), 1.72 MB
>   emitted. The emitted-Rust SURFACE is unchanged by this round — all
>   563 files are byte-identical to the pre-change render — so the work
>   went to the layer BELOW emission: the typing/polyfill DECISIONS.
>   (2) **The bug class.** Ten private descents over `IrStmt`/`IrExpr`/
>   `ArithAst` all answered "is this program's arithmetic too big for an
>   i64?" — seven in `rust_backend` (`stmts_have_huge`,
>   `walk_bigint_stmts`/`walk_bigint_expr`,
>   `collect_huge_literal_assigns`, `collect_all_assign_targets`, and the
>   inline `has_huge_call`/`collect_targets`/`has_huge_arg`), two in
>   `c_backend` (`walk_body_bigint`/`walk_expr_bigint`), plus
>   `analyze_bigint_vars`' own `harvest` in shared `shir`. Every one
>   carried `_ => {}` over `IrStmt`, and they disagreed about which forms
>   exist: rust's taint walker had no `Case`, `Exec`, `Output`, `Try`,
>   `ForInit`, `Background` or `Capture` arm; `stmts_have_huge` had no
>   `Case`/`Try`/`Select`/`Declare`; `harvest` — SHARED by the C, Zig and
>   Rust storage selection — had no `Pipeline`/`Select`/`Exec`/`Output`/
>   `Declare`/`Asm` arm and never opened a `Try`'s `excepts`. A constant
>   a walk cannot see is a constant the backend renders as wrapping `i64`
>   where bash needs an unbounded integer: a silent wrong answer, not a
>   loud one. Measured on `case $x in a) n=$((2**70));; esac` — before,
>   `n` is never tainted by any of the three rust walks; now it renders
>   `num_bigint::BigInt::from(2i64).pow(…)`.
>   (3) **The fix, in shir.** `AnyNode` gains `Stmt(&IrStmt)`, yielded
>   BEFORE its children, so a parent-aware rule (an `Assign` whose RHS is
>   an `Arith`) can sit on the shared descent instead of keeping a private
>   statement walker — and a private statement walker is exactly the bug.
>   `stmts_each`/`expr_each`/`program_each` are one-line wrappers over
>   `*_any`, so a full-visit walker CANNOT drift from the early-exit one:
>   one traversal, one exhaustiveness guarantee. `arith_eval_bigint` moves
>   out of `rust_backend` (ten call sites there, no equivalent anywhere
>   else), with `arith_is_huge` as the single "too big for an i64" test
>   (previously the same five lines spelled inline at every call site) and
>   the shallow/deep pair `expr_huge_lit`/`expr_has_huge_lit` +
>   `stmts_have_huge_lit`.
>   (4) **Rewired: ~380 lines of private catch-all walker leave the tree**
>   (rust_backend −281, c_backend −100); each backend keeps only its
>   per-node RULE. `collect_bigint_vars`' coarse half subsumes three
>   overlapping older rules AND now counts `prog.subs` — a huge constant
>   inside a function body was invisible to the program-wide marking.
>   (5) **The one `fail-rs` red was NOT this round's change, and was
>   fixed anyway.** A/B proof: the pre-change render of all 563 files is
>   byte-identical to the post-change render, and compiling the PRE-change
>   render reproduces the same diff. Root cause: `echo_fold` lowers a
>   literal `echo` to `IrStmt::Output`, and `fn_body_line_text` — which
>   reconstructs a body for `typeset -f` — had no `Output` arm, so every
>   literal echo became an empty line and the display printed a stray `;`
>   where bash prints the statement. It now reconstructs `Output` with
>   the call form's quoting rule, and REFUSES any value it cannot spell
>   rather than guessing an argument it did not read.
>   (6) **Verification.** `./fail` **563/563**; `fail-rs` **556 pass / 0
>   fail / 7 skip** (baseline; was 555/1/7 with `typeset-cmdsub` red);
>   `fail-shir` clean (563 scanned, 556 bash-free, 1 normalisable in
>   whitelist); `py-rust-gate` **98/103 baseline-identical** (same 3
>   documented reds t104/t82/t87 + 2 known-gaps); `cargo test --lib`
>   **1895 passed / 49 failed — byte-identical to the saved r11
>   baseline** (zero new, zero lost), with **6 new tests** pinning the
>   fixed holes: `shared_descent_verdict_tests` (Stmt-before-children,
>   `stmts_each` into a `case` clause, `arith_is_huge` range,
>   shallow-vs-deep, `harvest` reaching a `Try`'s `excepts`),
>   `body_has_bigint_arith_sees_through_a_command_substitution`, and
>   `typeset_dash_f_prints_a_folded_echo_statement`. Core worker
>   **GREEN** (15:36 gate, supervisor alive, no `sleeping-*` markers).
>   Deliberately left: `sh_backend::needs_arr_helper` (no `Capture` arm —
>   same class, but moving it needs the render-body architecture above
>   the prologue) and the 27 unused `_arr_*` prologue blocks.
> - v98: **ONE exhaustive shIR descent (`shir::program_any`) replaces the five
>   drifted private polyfill walkers; sh's undefined-`_readlink` bug (3 broken
>   renders) is fixed, ~540 lines of walker leave the tree, and the emitted
>   Rust drops a dead-`__r` binding class.**
>   (1) **CENSUS r10/r12** (fresh 563-file corpus, rustc default lints): the
>   Rust surface is stable and exhausted — 9 warnings (byte-identical kinds
>   to r9/r10), `unreachable statement` still **0**, 0 compile errors, 0 dead
>   helper fns, 115 `as` casts all type-required. The shIR is folded too
>   (0 all-literal `Interpolate`, 0 `Not(Not)`, 103 single-part Interpolates
>   only). Census therefore pivoted to the **polyfill-decision layer** —
>   where a NEW instance of the v97 drift class was found. (2) **The bug.**
>   `needs_readlink`/`needs_cmp` existed twice (sh, zsh) alongside
>   `needs_hostname`/`needs_word_split` (zsh) and `needs_arr_helper` (sh):
>   five private descents over the same three enums, kept in step by hand.
>   sh's `needs_readlink` had **no `Capture` arm**, so `x=$(readlink -f …)`
>   never fired the prologue while the call-site renderer still emitted
>   `_readlink -f …` — measured **3 of the 1054 sh/zsh corpus renders call a
>   function they never define** (`readlink_relative`, `readlink_flags`,
>   `readlink_example`: `_readlink: command not found` → an empty capture).
>   zsh's copy HAD the arm and was correct — textbook drift. And NO copy had
>   an `IrStmt::Exec` arm, though the corpus carries 71 of those statements.
>   (3) **The hoist.** `shir::AnyNode` (`Expr` / `Arith` / `Cmd`) plus
>   `shir::program_any` / `stmts_any` / `expr_any` own the descent, with **no
>   `_ =>` catch-all on `IrStmt`, `IrExpr` or `ArithAst`** — every variant is
>   named, so growing any enum is a COMPILE ERROR here instead of a silently
>   missing arm in N copies; the two `Ext` arms recurse through the node's
>   own generated `children()`. `Cmd` exists because a command reaches the
>   IR from two shapes (`Expr(Call{func:"exec"|"builtin"})` and
>   `IrStmt::Exec`) and only a predicate that sees both can mirror the
>   renderer's one `exec_line_to_sh` path. On top of it:
>   `shir::readlink_flag` (was 2 byte-identical copies),
>   `shir::program_needs_readlink` and `shir::program_needs_cmp` (exact duals
>   of the render-time rewrites, `builtin` accepted alongside `exec` so the
>   answer does not depend on whether `fallback_builtin_to_exec` has run).
>   sh and zsh now delegate; zsh's `needs_hostname`/`needs_word_split`
>   collapsed to per-node predicates on the shared descent. **~540 lines /
>   20 KB of private walker deleted**; also removed the dangling
>   `expr_containers` doc-comment a v97 deletion had left glued onto fish's
>   `body_calls`. (4) **Emitted-Rust idiom.** The 165 `let (__c, __r) =
>   __sh_capture_rc(…)` sites bind an `__r` nobody reads once the status
>   store is stripped (129 of them block-dead) — rustc stays silent only
>   because `__r` starts with `_`. New `rust_backend::
>   underscore_unused_capture_rc`, run after every rc strip and before `-Oz`
>   golf, spells it `(_, …)` … **but only when EVERY word-bounded `__r` in
>   the file is a destructure binding** (count-vs-bindings, boundary-checked
>   on both sides so `__rc`/`__r2`/a `__r` inside a shell-out string never
>   count): 33 bindings rewritten corpus-wide, 0 risk of renaming a live
>   one. (5) **Verification:** 12 new verdict tests + the 7 grep_p ones =
>   **19/19**; new `dead_capture_rc_binding_becomes_an_underscore` **passes**;
>   prologue call/def parity over 1054 renders **missing 3 → 0**; `./fail`
>   **563/563**; `fail-rs` **556/0** (7 pre) — the underscored Rust compiles
>   and behaves identically corpus-wide; `fail-estree` **563/563 both**;
>   `fail-shir` rc=0; py-rust **98/103** (t104/t82/t87 pre-existing); full
>   cargo **1888 pass / 49 fail** — failure set byte-IDENTICAL (empty diff)
>   to the pre-round baseline, none in this round's files; sh/zsh suites
>   23/0, 20/0, fish 24 pass / 5 fail (the same pre-existing set). Core
>   worker **GREEN** throughout (13:34:22), no trap markers — no fix needed.
>   A transient red on `typeset-cmdsub.sh [perl]` was traced to a peer's
>   in-flight `perl_generator_fixed.rs` edit: this round's API has **zero
>   callers off the sh/zsh/fish path** (proved by grep), and the test went
>   green the moment their edit landed. (6) **Deliberately left:** the 27
>   unused `_arr_*` prologue blocks (a per-helper split needs the `_num`
>   render-body architecture moved above the prologue) and 132 remaining
>   `__r` bindings (the file-level rule is all-or-nothing per file; a
>   block-scoped count needs string-literal-aware brace matching).
> - v97: **The grep-P polyfill verdict becomes ONE shared shIR judgment
>   (sh/zsh/fish had three drifted copies — two of them BUGGY), fish's
>   pattern-slot fix is ported to the sh/zsh render paths, and ~510
>   lines of private walker leave the tree.**
>   (1) **The drift, found by census.** `needs_grep_p` existed three
>   times (sh/zsh/fish) plus `ere_safe` three times; the copies had
>   diverged. Only fish's copy scanned for the PATTERN after `-P`
>   (`grep -Pc PAT` puts `-c` in the fixed `words[i + 1]` slot,
>   `ere_safe("-c")` answered true, so the prologue never shipped and
>   the rendered `grep_p` call died `command not found`); sh and zsh
>   both still had that bug. The descents also differed: fish fell
>   through to a generic container walk, zsh alone had `Capture` /
>   `Interpolate` / `ForEachLine` arms (sh missed
>   `x=$(echo hi | grep -P …)` entirely), and NO copy descended `Try`
>   bodies. (2) **The hoist.** `shir::program_needs_grep_p` +
>   `shir::grep_p_ere_safe` now own the verdict: union of the three
>   descents + fish's pattern-slot fix + one deliberate addition (`Try`,
>   over-approximating only ever KEEPS the inert prologue, while a miss
>   is a runtime `command not found`). The three backends delegate
>   (sh/zsh keep a thin `ere_safe` wrapper for their render-time `-E`
>   lowering; fish's dead `expr_containers` deleted with its private
>   copy): 156+171+174 lines of walker + 10 of fish's ere_safe removed.
>   (3) **Render side, same bug class.** sh/zsh also read a fixed
>   `pidx + 1` when choosing `grep -E` vs `grep_p` — `grep -P -c
>   '(?=…)'` chose `-E` on `ere_safe("-c")` and a lookaround pattern
>   silently matched NOTHING (fish's documented fqdn-count=0 bug). The
>   fish fix (scan forward for the first non-flag word) is ported
>   verbatim to both. End-to-end on `grep_p.sh`: all three targets now
>   emit the prologue AND `grep_p -c '(?=…)'` where sh/zsh previously
>   shipped `grep -E -c` with no prologue. (4) Verification: 7 new
>   shared-verdict tests (combined-flag slot, ERE-safe negative, PCRE
>   positive, pipeline Arrow, Capture, Try, ere_safe classes) all pass;
>   sh 23/0, zsh 20/0, fish 24 pass/5 fail — the 5 byte-identical to
>   the pre-round baseline (peer fish churn: array/case/positional +
>   the two grep_p tests were already red); `./fail` **563/563**,
>   `fail-rs` **556/0** (7 pre), `fail-estree` **563/563 both**,
>   `fail-shir` rc=0, py-rust 98/103 (t104/t82/t87 pre-existing), full
>   cargo 1875 pass / 49 fail — failure set byte-IDENTICAL to the
>   pre-round baseline (empty diff). Emitted-Rust corpus r9 unchanged:
>   9 warnings, `unreachable` still 0. Core worker GREEN (07:07:06) —
>   no fix needed.
> - v96: **c_backend stops re-deriving the PIPESTATUS verdict: it now asks
>   the SHARED `shir::program_observes_pipestatus` — two of three
>   backends agree by construction, and the private walker (which could
>   silently under-detect) is deleted.**
>   (1) **The generalisation.** Rust already set `pipestatus_dead` from
>   the shared verdict (a substring scan of the IR's Debug form — its
>   doc argues at length why a hand walker is the WRONG shape: a missed
>   read form is a silent wrong answer, since the register then never
>   fills and the read answers 0). C's `need_pipestatus` was set by a
>   private `scan_ps_expr`/`scan_ps_stmts` pair that matched ONLY the
>   lowered `param("PIPESTATUS[…")` read shape and had no `Function`/
>   `Case`/`Try`/`ForInit` arms and never touched `prog.subs` — a
>   PIPESTATUS read inside a (kept, called) function body left the
>   state-import tail unshipped and the read returned 0. The scan is
>   replaced by one call to the shared verdict (c_backend.rs:35595);
>   ~80 lines of walker deleted; the field doc now points at the
>   verdict. New c test `pipestatus_read_inside_a_function_arms_the_
>   state_import` pins it, A/B-verified: it FAILS with the old
>   scanner's answer (`false`) and passes with the verdict. Perl needs
>   no swap: its `fix_literal_pipeline_pipestatus` is a different job
>   (populating `@PIPESTATUS` for literal-true/false pipelines, a 070
>   correctness splice), and its declaration machinery keys off
>   referenced names, not a dead-capture verdict. (2) **Emission-Rust
>   census r8**: 563 files, rustc default lints = 9 warnings, stable
>   vs r7, `unreachable statement` still 0; no new warnings from this
>   round (the `InterpPart` unused-import warning visible in the build
>   is zsh_backend.rs:16, a peer's file). (3) Verification: `./fail`
>   **563/563**, `fail-rs` **556/0** (7 pre), `fail-estree`
>   **563/563 both**, `fail-shir` rc=0, py-rust 98/103 (t104/t82/t87
>   pre-existing), c_backend tests 167 pass/8 fail — the 8 byte-
>   IDENTICAL to the pre-round baseline, full cargo 1868 pass / 49
>   fail — the failure set byte-IDENTICAL to the pre-round baseline
>   (diff empty), none in this round's files. Core worker GREEN at
>   round start (06:23:13) — no fix needed.
> - v95: **The emitted-Rust `unreachable statement` class reaches ZERO via
>   the shared verdict; the flow-sensitive DSE's two leftover warnings
>   are measured and deliberately refused; every gate green.**
>   (1) **CENSUS** (fresh 563-file corpus, rustc default lints, rounds
>   r5→r7): 115 cast sites across 44 files are ALL type-required
>   (`unnecessary_cast` never fires — `len() as i64`,
>   `[idx as usize]`, `bool as i64` are the runtime's value types, not
>   boilerplate), so casts are not an idiom surface. Warning surface
>   11 → 9 with `unreachable statement` 2 → 1 → **0**. (2) **Rust
>   renderer behind the SHARED verdict**: a redirect region whose
>   inner list provably never falls through (096's `while true`
>   producer, a trailing `exit`/`return`) no longer emits its `post`
>   restores — rustc had reported 096's OUTFILE restore
>   `unreachable statement`. The guard asks the SAME
>   `unreachable_after_exit::terminates_list` the loop-tail RC capture
>   and the function value tail ask (`in_loop:false`, the
>   conservative reading), and the paired save bindings are scrubbed
>   to `let _ = …take()` so the fix cannot trade the unreachable
>   warning for an unused-variable one. Both emission paths
>   (process-substitution thread + ordinary block scope) are guarded;
>   2 new rust_backend render tests pin infinite-drops /
>   finite-keeps. Perl/C/JS need no equivalent: their restores are
>   `local`-scoped (implicit) or per-target synthesised — only Rust
>   mints an explicit restore statement. (3) **Deliberate refusals**:
>   the two surviving `value assigned … never read` sites are not
>   shIR-fixable today — arith-postfix's `((i++))` store has a LIVE
>   status half (the `$?` read observes it), so only a status/value
>   split could drop the value half, and parse-longoption's `|| X=0`
>   store ends a status block, where dropping it would change the
>   block's exit status; dead-function elimination is refused because
>   `--library` EXPORTS function defines never called internally;
>   the snake-case warnings are correct (user function names), and
>   the `IFS` store is the documented SHELL_IMPLICIT keep. (4)
>   Verification: `./fail` **563/563**, `fail-rs` **556/0** (7 pre),
>   `fail-estree` **563/563 both**, `fail-shir` rc=0 (311 bytes),
>   py-rust 98/103 (t104/t82/t87 pre-existing), rust_backend tests
>   **170/170** (2 new), full cargo 1867 pass / 49 fail — ZERO new
>   vs the pre-round baseline (51 → 49; peers fixed 2), none in this
>   round's files (estree 24 / shir 11 / c 8 / fish 5 / roundtrip 1,
>   all peer-owned concurrent edits). Core worker GREEN at round
>   start (05:29:49) and still running at close.
> - v94: **Two more unreachable-tail classes die in EVERY backend via the
>   shared predicate — an infinite-loop terminator and a diverging-chain
>   fold — plus `pass` now always recurses; all equivalence gates green.**
>   (1) **SHARED** `unreachable_after_exit`: `While{cond:true}` /
>   `DoWhile … true` / `until … false` terminates the list it sits in
>   when a deliberately paranoid escape scan finds nothing that can
>   leave it (break/continue/return/exit calls, breaks threaded by
>   depth so NESTED-loop breaks don't count, a function DEFINED in the
>   body scanned because a call can fire it, `eval`/`source` and the
>   opaque `RawText`/`Goto`/… nodes refuse). That prunes the Rust
>   backend's synthesized outfile restore behind
>   `head <(while true; …)` (096_head_procsub) and the same epilogue in
>   every other renderer — the pass accepts both the folded `Bool` and
>   the raw `true`/`:` command spelling, so the verdict never depends on
>   `const-condition-elim` registration order. (2) Same file,
>   `A || B` / `A && B` with a diverging `A` (`break || exit 1`,
>   parse-break-or) folds to `A`: the real terminator becomes visible
>   to the pass and no backend renders the dead right-hand side (Rust
>   had emitted `{…; break; }; __SH_RC.store(…); if !__b { exit(1) }`).
>   Gated per target: break-chains only inside a loop, return-chains
>   only inside a function. (3) `pass` restructured: the terminator
>   verdict is taken from the ORIGINAL statement, then `rebuild` always
>   recurses into nested lists — an infinite loop terminates its own
>   list while its body can still hold dead tails
>   (`while true; do continue; echo dead; done`), and computing the
>   verdict BEFORE rebuild stops a pruned `break` from retroactively
>   making its loop look infinite. (4) Verification: `./fail`
>   **563/563**, `harness/fail-rs` **556/0** (7 pre-existing skips),
>   `./fail-estree` **PERL+ESTREE 563/563**, `./fail-shir` rc=0 (311
>   shell-out bytes ≤ 2000), py-rust-gate 98/103 (t104/t82/t87
>   pre-existing), pass tests **26/26**. Full sh2perl cargo test 1863
>   pass / 51 fail, PROVEN not this round: a temporary transform-off
>   probe reproduced the identical 51 (its own delta was 13
>   unreachable_after_exit tests failing only BECAUSE the pass was
>   off) — every failure is owned by concurrent peer edits
>   (c_backend/estree/fish/shir/arr_load_fwd). Core worker GREEN
>   (04:49:08, `gate GREEN (A1 native + estree corpus + lib tests)`);
>   no fix needed.
> - v93: **The python callout census drops another ~40%, a shared
>   `exec-call-fold` transform retires the two-carrier split for every
>   backend, and the whole multi-backend sweep moves DOWN two
>   equivalence failures (143 → 141 real; python stays 0/563).**
>   (1) **SHARED** `transforms/exec_call_fold` (registered LAST in
>   `transforms::all()`): the payload-free `IrStmt::Exec` inside a
>   COMMAND CARRIER — an arrow body, a pipeline stage, and everything
>   nested in one — folds to the canonical
>   `Expr(Call{func:"exec", args:[cmd, Array(argv)]})` spelling. The
>   two carriers are the same command, but the backends' compound-
>   context replayers were written against the Call form: go's
>   `cmd_text` answers `None` for `IrStmt::Exec` (and its `stmt` arm
>   marks it `TODO(unsupported): stmt Exec {…}`), python's
>   `body_shell_text` / `pipeline_run` / `pipeline_head_value` /
>   `capture_body_is_native` match only `Expr(Call{exec|builtin})`,
>   and perl's native-capture whitelist is keyed on the Call form too.
>   sh/zsh/fish/java arm `IrStmt::Exec` explicitly, which is why this
>   is one rewrite of the IR rather than five backend patches. REFUSE
>   > GUESS: a capture channel, a redirect set or a command-scoped env
>   keeps its carrier (the call form has nowhere to put them), and
>   `shir::is_ps_tmp_cleanup`'s synthetic `__ps_tmp` cleanup keeps its
>   carrier as well — every renderer recognises THAT statement by
>   shape to save/restore the consumer's status around it. Corpus:
>   all 71 `Exec` statements are payload-free (44 `mktemp` in arrow
>   bodies, 27 `rm` cleanups), so the fold reaches 44 sites and the
>   predicate refuses the 4 cleanups that sit inside a carrier.
>   Target-gated in `transform_applies`: open to every code-generating
>   backend, `shir` excluded so the byte-pinned A1 export keeps its
>   statements (capture-node-fold/case-lowering precedent) — the
>   renderers still see the fold, because `shir_render` binds no
>   target and a direct render binds the backend name. 4 new tests.
>   (2) `python_backend`: `body_shell_text` became the recursive
>   `shell_parts`, which rebuilds the statement shapes it used to
>   refuse — `Exec` (argv + redirect set + `VAR=x` prefix),
>   `Subshell` → `( … )`, `Block` → the same sequence, `Redirect` →
>   `cmd <redirs>` (a multi-command body wrapped `{ … ;} >f` so the
>   set binds the whole group), `Output` → the `echo`/`printf` it
>   came from, `For` → `for x in …; do …; done`, `Pipeline` →
>   `A | B`, plus nested `Call{pipeline}` / `Call{redirect}`. Three
>   previously-duplicated reconstructions collapsed into the one
>   helper: the `redirect` call arm, `capture_redirect` and
>   `pipeline_run`'s new last-resort stage path all call it, so a
>   redirect seen three ways cannot drift apart. `sh_arg`'s param arm
>   became `sh_param_syntax` (mirroring ir.rs's `bash_param_syntax`,
>   with a safe-word guard): `${cmd[@]}` / `${map[foo]}` / `${@:3}`
>   are native shell words the child expands, where the old
>   plain-identifier guard refused and the whole capture fell to a
>   stub — realpath-cmdsub's `stdout=$("${cmd[@]}" 2>/tmp/x.$$)` used
>   to reach `sh2_capture()`.
>   (3) Measured over the 563-file corpus (gate path
>   `otranspilerl --target shir | shir_render --target python`):
>   `sh2_arrow` 97 → 27, `sh2_capture` 90 → 38, `sh2_pipeline` 35 →
>   17, files carrying `TODO(unsupported)` 109 → 82, lines carrying an
>   `sh2_*(` call 405 → 267; syntax 562/563 (051_primes
>   pre-existing); `./fail` 563/563. Full
>   10-backend sweep before/after: c 2 → 1 (062_10_simple_pipeline),
>   java 62 → 61 (background-chain), perl/rust/python/go/zig/sh/fish
>   unchanged, estree 4 = 4 (its two extra lines in the concurrent
>   sweep were contention flakes — an isolated rerun and a per-file
>   rerun both land on the baseline four). Two real equivalence
>   fixes came from a change aimed at python: the shared fold also
>   unblocked c's and java's arrow-body replay.
> - v92: **The shared terminator verdict learns `break`/`continue`, and
>   two more unreachable-code classes leave the emitted Rust — real
>   rustc warnings 13 → 11 this round (40 → 11 measured from v90's
>   round-start baseline).**
>   (1) **SHARED** `transforms/unreachable_after_exit`: `terminates_list`
>   gained a third parameter `in_loop` and the arm
>   `IrStmt::Break | IrStmt::Continue => in_loop`. A `break`/`continue`
>   ends the list it is a DIRECT element of, exactly as `return` ends a
>   function body, so a statement left after it in the same loop body is
>   dead in EVERY target. The flag is what makes that sound: a `Break`
>   whose enclosing list is not a loop body (top level, a function body,
>   a subshell, a background job) has no loop to leave and a backend is
>   free to render it as a no-op, so the predicate REFUSES rather than
>   assumes. `pass` threads it exactly as it already threads `in_fn`:
>   `For`/`While`/`DoWhile` set it, `Function`/`Subshell`/`Background`
>   clear it (contained exits), `If`/`Case`/`Block` inherit it (they are
>   transparent for control flow). 5 new tests; 18 total, all green.
>   (2) `rust_backend` now CONSUMES that shared verdict through a new
>   `body_terminates` helper, guarding the rc-capture epilogue in all
>   FOUR loop renderers (expression-`while`, statement-`while`,
>   `DoWhile`, C-style `for`). Each used to emit
>   `{last} = __SH_RC.load(…)` after a body ending in `break` — rustc
>   `unreachable statement` (`parse-done-unexpected`,
>   `parse-multi-command-while-condition`). The verdict cannot drift
>   from what the shIR pass would have pruned because it IS the same
>   function.
>   (3) `expr_bool`'s `break`/`continue` arms dropped their trailing
>   `false`: the block's last statement is an unconditional `break`, so
>   no tail value is ever produced. The block is `!`, which coerces to
>   `bool` at every use site the renderer puts it in
>   (`parse-break-or`, `unreachable expression`).
>   (4) **REGRESSION CAUGHT AND FIXED**: the first cut of the function
>   value-tail guard read `self.in_function`, which is reset to `false`
>   BEFORE the tail is emitted — so `terminates_list` silently became a
>   no-op and **17 `unreachable expression` warnings came back**. The
>   guard now passes `true` explicitly (a function body's own last
>   statement is never a loop-level break), with the trap documented at
>   the call site.
>   (5) The two surviving dead stores are recorded as OUT OF SCOPE, not
>   fixed: `dead_store_elim` is deliberately flow-INsensitive (it drops
>   only variables with ZERO reads anywhere in the program), but `i = i
>   + 1` (`arith-postfix-status`) and `X = "0"`
>   (`parse-longoption-with-dollar`) are both read BEFORE the store and
>   never after. Killing them needs flow-sensitive liveness plus the
>   export/escape carve-outs; 2 warnings do not pay for that analysis.
>   Measured over the 563-file emitted corpus, plain rustc default
>   lints (same baseline and method as v90): real warning lines **40 →
>   11**, files carrying any warning **29 → 11**; `unreachable
>   expression` **4 → 0**, `denote infinite loops` **3 → 0**,
>   parens/braces held at **0**, dead inits held at **2**,
>   `unreachable statement` **2 → 2** (the two break-epilogue sites went,
>   `parse-break-or`'s reclassified from expression to statement). `sh2.*` callouts 0, dead polyfill defs 0, casts 113 — all
>   unchanged. The 11 left: 4 dead shell functions and 3 names that are
>   source-level (2 unused vars, 1 snake_case), 2 flow-sensitive dead
>   stores, and 2 genuinely-unreachable statements (code after an
>   infinite `loop`, which needs a no-break-in-body analysis).
>   Gates: `./fail` 563/563, `fail-rs` 556/0/7,
>   `fail-estree --gate` **563/563 rc=0**, `check_qx_shir` 563 ok / 0
>   violations / 0 probe failures, `py-rust-gate` 98/103 (3 FAIL + 2
>   known-gap = unchanged baseline), `cargo test --lib` **1842 pass /
>   50 fail** — failure set byte-identical to the baseline (no new
>   reds). **Gate-flakiness note:** two full estree runs reported 562/1
>   on DIFFERENT files while the box sat at load 43–63 with
>   `cpu some avg10=83%` (four lanes running estree gates at once; the
>   gate's per-test budget is a hard 20 s). Both files pass individually
>   and a clean full run is 563/563 — timeouts, not diffs. Core worker
>   GREEN 12:07:33, A1-native 0 violations / 555 probed, no trap markers
>   — no fix needed.
> - v91: **arr-load-fwd lands on MIMEcroft: the pass-wide closure bail
>   goes, and the forward now removes the store it orphans itself — the
>   function-local copy DSE's multi-run `Const` rule can never take
>   (first-frame −1.87% instructions, frame byte-exact vs bash).**
>   The pass existed and unit-tested, but rendered `MIMEcroft_fb.sh`
>   byte-identically with `SH2_NO_ARR_LOAD_FWD=1` or not. Two gates,
>   found by instrumenting it (`SH2_ARLF_DBG`, since removed):
>   (1) `has_dynamic` refused the WHOLE pass on any `eval`/`source` OR
>   any closure-shaped expression anywhere — MIMEcroft's single
>   `sl_x=$(exec cat …)` (`Capture{Arrow}`) did it. The span rule
>   already buys that soundness precisely: `stmt_refuses` refuses every
>   statement form that can carry a closure/capture (the opaque arm of
>   `expr_refuses`) and every `Exec`, so a forward only ever crosses
>   provably inert statements. The eval/source clause stays (same rule
>   DSE has); the closure clause and its `expr_has_closure` walker are
>   gone — a one-capture 7 000-line program no longer disables the
>   optimization everywhere.
>   (2) The orphaned store was DSE's to drop, and DSE can never drop
>   it: `analyze_var_const` marks every site inside a function body
>   multi-run ("a function may run 0..N times") → `Var` → not `Const`
>   → refused — precisely `rb_mkhex`'s three `rbm_*=${RBHEX[$rbm_*]}`
>   copies (3 string stores × 212 k calls/frame). The pass now sweeps
>   its OWN orphans after the fold, only for vars THIS fold orphaned,
>   under DSE's own standards so the two cannot disagree: DSE's
>   `census` (pub(crate) — the read/escape verdict), DSE's `expr_pure`
>   (pub(crate)), `is_shell_implicit`, plus
>   `shir_passes::split_inplace::exported_names` (env-visible = read
>   by children). Refuse > guess on every axis.
>   Supporting: `READ_ONLY_CALLS` moved to `transforms.rs` as the one
>   shared list both passes consume, and DSE's `expr_pure` learns a
>   read-only helper call (`arrayIndex`, `param`, `listVar`, …) is
>   pure — without it the generic Call refusal kept every orphaned
>   `v = arrayIndex(…)` alive forever. Guards: no `$(`/backtick in a
>   `Str` arg, and no `?` in `param`'s op slot (`${x:?}` aborts the
>   shell — dropping the store would drop the abort with it).
>   Seams: `SH2_NO_ARR_LOAD_FWD` (whole pass) + new
>   `SH2_NO_DSE_CALL_PURE`. Verification: `--first-frame` medians 7
>   interleaved runs/arm under `perf stat -e instructions:u` =
>   2 554 479 151 (on) vs 2 603 063 974 (off) = −48.58 M = −1.87%,
>   every PPM md5 == the bash oracle (`53d9cfa7…`), spread < 0.001%;
>   `./fail` 563/563; c-gate verdicts unchanged ON vs OFF (639 pass /
>   7 skip / 5 pre-existing fail, identical lists); unit suite 1842
>   green, zero regressions attributable to the change.
> - v90: **Every parens/braces class hits zero, the dead value-tail and
>   dead `piece` init go, and `unreachable-after-exit` learns the
>   EXHAUSTIVE `if`/`case` rule — a shared shIR→shIR win every backend
>   inherits.**
>   (1) `rust_backend` render fixes — the rest of `unused_parens` /
>   `unused_braces`: `if`/`while`/`for` conditions, fn-arg parens,
>   `({ block })` return-value braces and `let x = { … }` braces. The
>   brace case matters beyond the lint: a `String` template is NOT a
>   `format!` string, so `{{`/`}}` are emitted verbatim — `$!`'s guard
>   rendered `if __p == 0 {{ … }}`, an if-arm holding a NESTED block.
>   Conditions unwrap through a statement-boundary-aware, string/char-
>   aware matcher so `(a).foo()` receivers and `(a, b)` argument lists
>   keep the parens that carry meaning.
>   (2) `__sh_printf`'s `let mut piece = String::new();` → `let mut
>   piece;`. The conversion `match` is exhaustive (`_ =>`), so every arm
>   assigns and the initializer was a write rustc called dead
>   (`value assigned … never read` — 8 corpus files).
>   (3) **SHARED** `transforms/unreachable_after_exit`: `terminates_list`
>   grew three arms — an `If` with a NON-EMPTY `else` whose every branch
>   (then, each elsif, else) ends in a terminator; a `Case` carrying a
>   bare `*` catch-all whose every clause body ends in a terminator (a
>   quoted `"*"` is a literal two-char pattern and is refused); and a
>   `Block`, whose own last statement decides (`Subshell`/`Background`
>   deliberately stay out — their exits are contained). Why both
>   spellings: 061's dispatch is `case`-SHAPED in shIR and only
>   `case_lowering` turns it into an `if/elsif` chain, so an If-only rule
>   silently did nothing. 8 new tests; 13 total, all green.
>   (4) `terminates_list` is now **`pub`, documented as the one shared
>   "can control fall past here?" verdict**, and `rust_backend` CALLS it:
>   the function value-tail guard was an exact-node `Return`/`Exit`
>   check, which missed the call spelling of `exit` and every exhaustive
>   dispatch — so 061's three functions each got an epilogue rustc
>   reported as `unreachable expression`. Any other backend synthesising
>   a fall-off-the-end return can reuse it instead of re-deriving a
>   weaker check.
>   (5) `while true { … }` → `loop { … }` (3 files): identical
>   `break`/`continue` semantics, idiomatic spelling, and rustc stops
>   asking for it.
>   (6) Repaired another lane's STALE WIP in `src/shir.rs`:
>   `let_args_native_accepts_length_refs` did not compile — it built
>   `vec![s_lit(…), IrExpr::Array(…)]` (`s_lit` returns the ESTree
>   `Expr`, not `IrExpr`) and referenced a nonexistent
>   `crate::shir::Quoting` (`IrExpr::Str`'s second field is `StrStyle`).
>   It broke `cargo test --lib` for the WHOLE tree for ~80 min; fixed to
>   `IrExpr::Str("let", StrStyle::SingleQuoted)`, and it passes.
>   Measured over the 563-file emitted corpus, plain rustc default
>   lints: real warning lines **40 → 13 (−67%)**, files carrying any
>   warning **29 → 13**; parens/braces **13 → 0**, dead inits **11 → 2**,
>   `unreachable expression` **4 → 1**, `denote infinite loops` **3 → 0**.
>   `sh2.*` callouts 0, dead polyfill defs 0, casts 113 — all unchanged.
>   The 13 left are source-level (4 dead shell functions, 2 unused source
>   vars) or need a `break`-awareness rule (3 `unreachable statement`,
>   1 `break; false` block) or a dead-store rule (`i = i + 1`, `X = "0"`).
>   Gates: `./fail` 563/563, `fail-rs` 556/0/7,
>   `fail-estree --gate` 563/563, `check_qx_shir` 563 ok / 0 violations
>   / 0 probe failures, `py-rust-gate` 98/103 (3 FAIL + 2 known-gap =
>   unchanged baseline; a first run showed 4 FAIL only because the CLI
>   binary was being rewritten by a concurrent build), `cargo test
>   --lib` **1832 pass / 50 fail** — the SAME 50-red baseline (estree 23,
>   shir 11, c 9, fish 5, shir_json_in 1), NONE in `rust_backend::tests`
>   or `transforms::*`. Core worker GREEN 07:52:39, A1-native 0
>   violations / 555 probed at 08:04:57, iterating — no fix needed.
> - v89: **Python idiom round 2: sh2 callout sites 704 → 520, honest-
>   unsupported files 163 → 109 (+54 files newly verified green), gate
>   0/563.** New native lowerings in `python_backend.rs`: `fnValue` →
>   `__sh_fnval` (an echo-RETURNED function yields its value, a printing
>   one its captured stdout — bash -c children cannot see python-side
>   function defs, so `body_shell_text` now refuses fn_names and
>   `$(f …)` routes here); `captureWords`/`split` → the ir.rs single-
>   string contract with `*(…).split()` splices in word-list/argv
>   positions; `shopt` → no-op except `nocasematch`, which toggles a
>   probe-gated `__sh_ncm` runtime flag read by `test_render`'s
>   `==`/`!=` (mirrors test_lowering's conservative probe and perl's
>   `$__nocasematch`); `uc/lc/strHasSuffix` → `.upper()/.lower()/
>   .endswith()`; `param("", text)` → getVar delegate + direct python
>   list subscript for `name[expr]` text; `redirect(…)`/general
>   `capture(Arrow)` → bash -c replay (bash performs every fd natively;
>   the old sys.stdout wrap never captured a CHILD's fd-1 — the fd-1/2
>   wrap fallback now dup2's the real fds, with `__sh_`-prefixed temps
>   because an `_sw`-style temp round-trips through eval's `declare -p`
>   import as a STRING and broke the restore); `shift` in-function →
>   `_sh_args = _sh_args[n:]`; `declare -a name=(…)` emits its setArray
>   initializer; cond-nested `assign` targets hoist the module default
>   (walrus NameError); `test`-family execs keep their bool verdict out
>   of the `(b or 1)` chain-wrap that erased every False;
>   `"$@`-as-command splices listVar words (empty argv → rc 127 in
>   `__sh_exec`); body_shell_text quotes bare `$VAR` test operands
>   (`test $A -ef $B` → one-arg truthy) and `"$@"` replays as a child
>   positional word. Extglob patterns keep an honest `mark_todo` (no
>   python translation — 010/037/at-in-test stay excluded, not blessed).
>   Verified: python gate 0/563, `./fail` 563/563, `cargo test --lib
>   python_backend` 10/10, syntax 562/563 (051_primes pre-existing).
>   Shared shIR→shIR: no landing spot this round — param/captureWords/
>   fnValue/redirect are consumed per-backend, all edits backend-local.
> - v88: **The last 5 `unused_parens` sites die in ONE place, and the
>   `typeset`→`declare` shared normalization is measured and REJECTED.**
>   (1) `rust_backend::strip_let_init_parens` — a statement-boundary-
>   aware, string/char-aware textual pass that rewrites
>   `let x = (EXPR);` → `let x = EXPR;`. A `let` initializer takes any
>   expression, so the grouping parens a render site wraps around a
>   compound value are boilerplate *in that position only*: the same
>   value feeding a method receiver (`(EXPR).to_string()`) or a cast
>   (`(EXPR) as usize`) still needs them. It fires only when the
>   MATCHING close paren is immediately followed by the `;`, refuses
>   empty/tuple payloads (a top-level `,` marks a tuple), never fires
>   on `while let`/`if let`, and never inside a literal. 3 tests
>   (`strip_let_init_parens_tests`). Effect over the 563-file emitted
>   corpus: `unnecessary parentheses around assigned value` **5 → 0**,
>   total rustc warning lines **76 → 69** (84 at the round-1 baseline);
>   dead polyfill defs stay 0, casts stay 113, `sh2.*` callouts stay 0.
>   (2) Candidate for a shared normalization, measured across all 10
>   targets and REJECTED: `builtin("typeset", …)` →
>   `builtin("declare", …)` (bash: "typeset: Same as declare"). Motive:
>   the ESTree renderer folds `declare -A map` natively (`map = new
>   Map()`) but emits **17 `sh2.builtin("typeset", …)` callouts** in
>   3 corpus files, and `typeset_attrs` already records attributes for
>   `typeset|declare|local` alike, so the rename would be semantics-
>   exact. Rendered `typeset-cmdsub.sh` and its `declare` twin through
>   rs/pl/js/c/go/fish/java/py/zig/sh: **8 equivalent, perl and C
>   DIFFER** — C's `declare` path swaps heap `char*` for fixed-capacity
>   `char v[N] = ""` **plus `assert(strlen ≤ N)`** (a later longer write
>   would start asserting), and Perl gains a pre-declaration and the
>   uu-FFI seam block. A JS-native win does not pay for changing the
>   codegen of two gated backends; no edit made.
>   Gates: `./fail` 563/563, `fail-rs` 556/0/7,
>   `fail-estree --gate` 563/563, `check_qx_shir` 563 ok / 0 violations
>   / 0 probe failures, `py-rust-gate` 98/103 (3 FAIL + 2 known-gap =
>   unchanged baseline), `cargo test --lib` **1810 pass / 50 fail** —
>   the SAME 50-red set as the previous round's control, none from
>   `split_fold`/`rust_backend`. Core worker GREEN 07:34:18.
> - v87: **Two measured idiom wins, one shared nospace closure rule.**
>   (1) The helper prune ran BEFORE the passes that delete call sites:
>   `strip_write_only_rc` removed the `__SH_RC.store(__sh_ret_rc(…))`
>   that the return path had registered `ret_rc` for, orphaning the
>   definition — **9 dead `fn __sh_ret_rc` across the 563-file emitted
>   corpus**. `prune_unused_helpers` now runs after
>   `strip_write_only_rc` + `strip_dead_word_fail_guard` and still
>   before `prune_unused_statics` (so a pruned helper's own static
>   references are gone when the static sweep decides): dead polyfill
>   defs 9 → **0**, casts 122 → 113, `parse::<i64>` 129 → 120,
>   38,330 → 38,294 emitted lines, 14 files changed, `sh2.*` callouts
>   stay 0. (2) The "no IFS whitespace" proof gains a SUBSTRING closure
>   rule, mirrored in ALL THREE of its implementations —
>   `shir.rs::expr_nospace` (the var fixpoint every backend's verdicts
>   come from), `shir_passes::split_fold::expr_nospace` and the
>   ESTree render-time `expr_known_nospace`: `${x#p}` / `${x##p}` /
>   `${x%p}` / `${x%%p}` / `${x:o:l}` / basename / dirname return a
>   SUBSTRING of the subject, so the subject's verdict transfers
>   whatever the pattern is (magic or not), and a Ternary/DefinedOr is
>   whitespace-free exactly when both branches are. Case ops stay
>   unproven — the one arm whose result is not a substring of its
>   input. A1 `split[]` sites 7 → **6** (`parse-heredoc-dollar-paren`
>   folds); new test `substring_and_conditional_prove_nospace`.
>   (3) Fixed `otranspilerl/src/bin/zz_probe.rs`, which called
>   `shell_to_shir_export` — a function that has never existed — and
>   had made EVERY `cargo test` in that package fail to BUILD since
>   Oct-22; compiling it again reveals 3 pre-existing lib failures
>   (`analyze_json_shape`, `analyze_vetoes_overflow`,
>   `embed_english_and_backtick_flags`), untouched by this round.
>   Gates: `./fail` 563/563, `fail-rs` 556/0/7,
>   `fail-estree --gate` 563/563, `check_qx_shir` 563 ok / 0
>   violations / 0 probe failures, `py-rust-gate` 98/103 (3 FAIL + 2
>   known-gap = the unchanged baseline), `cargo test --lib` 1807 pass /
>   50 fail — the SAME 50-red set as the pre-edit control (1806/50
>   with this round's edits reverted; 0 red from `split_fold` /
>   `rust_backend`). Core worker GREEN 06:24:56.
> - v86: **The python equivalence gate is green through the gate's OWN
>   renderer** — `BACKENDS=python all_failures.sh` → **0 failures / 563**,
>   `./fail` 563/563, `cargo test --lib python_backend` 10/10. v85
>   measured the MAIN tree's renderer, but `render_for` prefers
>   `sh2perl/backends/<lang>`'s worktree `shir_render`, which sat on a
>   stale Oct-16 branch and still failed the original 15. Converged by
>   copying the fixed `src/python_backend.rs` over the worktree's copy
>   (the worktree's Oct-22 WIP — a revert of the spaceless-`==`
>   single-word rule — is already contained in the main file; raw patch
>   preserved at `.boxscratch/py-idiom/worktree_wip_backup/`) and
>   rebuilding: **15 → 3**. The last three were real backend bugs:
>
>   **(a) background `&` ran SYNCHRONOUSLY** into a StringIO that the
>   end-of-program flush always delivered, where the gate's
>   `kill-session.sh` session sweep kills bash's orphan BEFORE
>   `(sleep 1; echo a)` writes — gate bash = `b` / `exit: 0`, sync
>   python printed `a` regardless (048_subprocess). No flush-or-drop
>   policy can satisfy both the gate (swept → no `a`) and a plain run
>   (orphan → `a`); the job is now a REAL `os.fork()`: the child
>   inherits the same stdout fd (byte- and EOF-timing-identical to
>   bash's orphan on BOTH paths), gets a memory copy (105's copy
>   semantics for free — no snapshot/restore), never blocks the parent,
>   and `wait` waitpids the recorded `__sh_bg_pids`.
>
>   **(b) `local -a a=(…)` was dropped whole**: the declaration arrives
>   as a setArray CALL between the flag words and `render_local_call`
>   read only STRING words, so `${files[@]}` read a never-bound `files`
>   (064_16: `NameError: name 'files' is not defined`). It now emits
>   the setArray assignment; `listVar` gained a native arm (argv
>   `_sh_args` / `sys.argv[1:]` / a declared array's list); and a
>   word-LIST element inside a word array splices `*items` — the same
>   spreading `${@:2}` already had — so `for f in "${files[@]}"`
>   iterates the files instead of one joined string.
>
>   **(c) `${arr[@]:off:len}` sliced the TEXT OF ELEMENT 0**
>   (`(numbers[0])[3:3+4]` → `""`, 064_18 printed `Middle: ` empty)
>   where bash slices ELEMENTS: a declared array now lowers through
>   `array_slice_expr` — the whole list for the bare `[@]`/`[*]` form,
>   a clamped element slice otherwise (python's slice clamping matches
>   bash's bounds rules).
>
>   All three are backend-local render rules — `param(slice)` / `setArray`
>   / `listVar` semantics are consumed per-backend, so this round again
>   found no shared shIR→shIR landing spot, and the shared core was not
>   touched. Caveat: main's tree is transiently unbuildable from ANOTHER
>   worker's in-flight `src/shir.rs` edit (E0502/E0503/E0597, saved
>   05:55–06:01) — every binary measured above predates it, and the unit
>   tests were run in the worktree against the identical backend file.
>
> - v85: **The Python round: all 15 python equivalence failures fixed,
>   and the emitted Python cut from 39,155 to 24,966 lines (−36%).**
>   Measured over the 563-file corpus with a mirror of
>   `all_failures.sh`'s python contract (fresh scratch dir per file, rc
>   equality, byte-equal stdout, stub-marked renders excluded): **15 → 0
>   equivalence failures, 0 PASS→FAIL regressions**; `./fail` 563/563;
>   `cargo test --lib python_backend` 10/10 (three new pins), and of the
>   48 failures in the whole lib test run none are python's — they sit
>   in c_backend/estree/fish/shir/shir_json_in, which other workers are
>   editing in this tree.
>
>   **(1) Equivalence — one root cause per cluster.** The redirect
>   shell-text reconstruction DROPPED THE FD: `2>/dev/null` became
>   `>'/dev/null'` (discarding stdout — sync-direct-call-await printed
>   nothing) and `2>&1` became a write to a file literally named `&1`
>   (parse-db-status-fmt, question-in-singlequote sent dpkg's error to
>   stderr instead of the capture); `redirect_shell_text` now prints the
>   number and keeps dup targets bare, and the statement arm passes the
>   fd through instead of building a two-key object. `[[ … ]]` operands
>   that are `$( … )` were split on the substitution's OWN whitespace —
>   four tokens matched no arm, so the test fell into the `bash -c`
>   fallback, which re-runs the space-stripped text where
>   `$(uname -r)==5.4.*` is one word and therefore always TRUE
>   (test-expr-float, test-expr-dollar-paren); the splitter now tracks
>   `$( … )` nesting — only `$(` counts, because `[ \( … \) ]` grouping
>   must keep splitting or it passes natively where bash is false
>   (parse-complex-test-parens, found as a regression of the first
>   attempt and pinned). `test_value` parsed `010` to the int 10
>   (`str(10) == str(10)` — bash compares WORDS) and rendered
>   `${NAME}`/`${NAME:-def}` reads as a python STRING LITERAL, so
>   `("ZSH_VERSION" if "ZSH_VERSION" != "" else "")` was always truthy;
>   both are token-level fixes. `case` compared against the QUOTED
>   pattern (`''` vs "" — c_backend's `unquote_case_pattern` rule, now
>   mirrored) and let a command substitution in the discriminant clobber
>   `$?` (hoisted into a temp and re-reset: bash gives `case` 0 when no
>   clause tests true — parse-case-dollarparen-pattern exited 127). The
>   bash-seam helpers gained the three bash behaviours they were
>   simulating badly: `command -v` is a PATH lookup not a fork
>   (`shutil.which`), ENOEXEC runs the no-shebang file as a shell script
>   — with **bash**, since this box's /bin/sh is dash and rejects the
>   script's `set -o pipefail` — and a bare name is resolved first so
>   glibc's PATH walk cannot report the last candidate dir's EACCES
>   instead of the file's own ENOEXEC (a.sh). Reads of bash's OWN
>   variables (`HOSTNAME`, `BASH_VERSION` — set at startup, never
>   exported) fall back to `os.uname().nodename` and one
>   `bash -c 'echo $BASH_VERSION'`, so `${HOSTNAME:-localhost}` and
>   `[ "${ZSH_VERSION-}" ] elif BASH_VERSION` take bash's branch.
>   U+F800 raw-byte markers (read_source's encoding of a non-UTF-8
>   source byte) now escape to lone surrogates and the preamble sets
>   `sys.stdout.reconfigure(errors="surrogateescape")`, which encodes
>   U+DCxx straight back to the byte — python was writing 0xEF 0xA3 0xA9
>   where bash writes 0xE9 (utf8-non-utf8-content). Finally, `$( … )` as
>   a whole test operand runs through the seam instead of comparing the
>   literal text `"$(uname -r)"`, which only ever matched by luck.
>
>   **(2) Idiom — reachability, not a whitelist.**
>   `Render::elide_dead_helpers` runs on the FINISHED program, so
>   helper→helper edges (`__sh_source` → `__sh_declare_parse`,
>   `__sh_pipe_status` → `__sh_bash`) are followed without any call site
>   declaring a dependency, and a name mentioned anywhere keeps its def
>   (a false keep is the old behaviour; a false drop would be a
>   NameError). The subprocess seam used to be ONE block emitted
>   whenever any part of it was needed: 238 of 563 files defined
>   `__sh_declare_parse` and called it **0** times, and
>   `__sh_source`/`__sh_pipe_status`/`__sh_bash_in`/`__sh_eval` were
>   dead in 235/235/230/229 of them — around a hundred lines of dead
>   polyfill per file, on programs whose body is often shorter than the
>   preamble. Corpus totals: **39,155 → 24,966 lines**; dead helper
>   definitions 238 → 12 (all 12 reachable through `__sh_source` /
>   `__sh_eval`); the now-orphaned `__sh_names = {…}` snapshot table
>   goes with `__sh_env`; bare `None` statement lines 104 → 0 (a
>   statement-position expression that renders to the placeholder emits
>   nothing rather than a dead line).
>
>   **(3) Not yet what `all_failures` measures.** That gate renders
>   python through `sh2perl/backends/python/target/debug/shir_render`, a
>   separate checkout on `backend/python`; these changes are uncommitted
>   in the submodule's main tree, so the official arm still reports the
>   old 15 until a submodule commit is merged in with
>   `setup_backends.sh --sync` and that renderer is rebuilt.
>
> - v84: **`unreachable-after-exit` now recognises the CALL spelling of
>   `exit` (no shell `exit` ever reaches the IR as `IrStmt::Exit`), and
>   the IR-level all-literal interpolation fold was measured and
>   REVERTED.** Two findings from the round's re-analysis of the emitted
>   Rust (563 examples, 38,321 lines: still 0 `sh2.*` callouts, 0 dead
>   polyfill definitions; 509 `format!`, 122 `as`-casts, 129
>   `parse::<i64>`, 1,116 `to_string()` — all on the shell's untyped
>   boundary, none of them an IR-removable shape).
>
>   **(1) The landed transform.** The pass pruned statements after
>   `IrStmt::Exit(_)`, but that variant is not what shell source
>   produces: `exit 1` AND `exit "${?}"` both reach the backends as a
>   command call (`Expr(Call("exit", …))` — `func: "exec"` before the
>   builtins.json lowering, `"builtin"` after; corpus census: 10 exit
>   statements, 0 of them `IrStmt::Exit`), so the pass was inert for real
>   exits and the dead tail survived into EVERY backend —
>   `parse-exit-brace-question` emitted `printf "parsed OK"` after
>   `exit ${?}` in Rust, C, Perl and JS alike, and rustc flagged it
>   `unreachable statement`. `terminates_list`/`is_exit_call` now match
>   both funcs with a literal `exit` command word (`die` refused: in
>   shell it is a USER function; a variable command word refused: not
>   statically checkable). Verified cross-backend on that example: shIR
>   2 statements → 1, and the dead printf is gone from Rust, C, Perl and
>   ESTree. Five pins in `unreachable_after_exit::tests` (folded exit,
>   dynamic exit, exit-in-function, CONDITIONAL exit refused,
>   non-exit builtin refused).
>
>   **(2) The Rust epilogue guard.** A `fn main` whose last statement is
>   already a process exit got `std::process::exit(__SH_RC…)` appended
>   behind it — dead, and warned about. `Render::body_ends_in_exit`
>   (conservative: the last non-blank line must START with the call and
>   end `);`, so a conditional exit behind a closing `}` never matches)
>   suppresses it. Effect on the corpus compiled with DEFAULT lints:
>   `unreachable statement` 6 → 2, `unreachable expression` 4 → 4; the
>   4 survivors are a different class (renderer-emitted status writes
>   after a terminal `break`/`return` inside an expression sequence, 3
>   loop files + `061_test_local_names_preserved`). Two new pins
>   (`no_unreachable_epilogue_after_a_final_exit`,
>   `a_conditional_exit_keeps_the_epilogue`).
>
>   **(3) The reverted experiment.** Widening `interp-fold`'s single-Lit
>   rule to "concatenate ANY all-literal part list" was built, measured
>   over the whole corpus in Rust, C and Perl, and taken back out: **0 of
>   563 C files and 0 of 563 Perl files changed byte-for-byte** (both
>   renderers already collapse that node themselves), Rust gained a net
>   −2 `format!` while LOSING 37 `println!` forms (an IR-level `Str`
>   takes the `print!("…\\n")` arm — strictly less idiomatic), and it
>   broke 4 shape pins (`estree::variable_and_interpolation`'s
>   TemplateLiteral, the bc `trunc` native lowering ×2, and Rust's
>   no-print-format-hop echo). Canonicalization of an all-literal
>   interpolation belongs to the renderer, where the target's idiom
>   picks the spelling. The refusal is documented at the fold and pinned
>   (`a_multi_part_all_literal_interpolate_keeps_its_shape`) so the
>   measurement travels with the code.
>
>   Verification: `./fail` 563/563; `harness/fail-rs` 556/0/7
>   (baseline); `harness/py-rust-gate` 98/103 (documented t82/t87/t104);
>   `check_qx_shir` 563 examples 0 violations; `./fail-estree --gate`
>   PERL 563/563, ESTREE 549/563 (97.5%) — its 14 failures are NOT this
>   round: 14/14 have no `exit` statement anywhere in their source (the
>   new rewrite only deletes what follows a direct exit), and they sit
>   in `estree.rs`/`shir.rs`, the core-owned files other lanes changed
>   after v83. `cargo test --lib` 1805 pass / 48 fail (estree 24, shir 9,
>   c_backend 9, fish_backend 5, shir_json_in 1) — a STRICT SUBSET of
>   the control run taken before this round's edits (54 failures), 0 new,
>   and all 4 exit-named failures in it pre-date those edits. Core worker:
>   `gate GREEN (A1 native + estree corpus + lib tests)` at 02:26, no
>   `core-requests/sleeping-*`, `repair-workers.sh` silent.
>
>   Measured, not done (same class, renderer-side, other lanes' files):
>   C still appends `return 0;`/`return _sh_rc;` and Perl still appends
>   `exit $main_exit_code;` behind a final exit; Rust alone suppresses
>   its epilogue today.
>
> - v83: **`interp-fold`'s second rewrite: the decl-value rejoin retires the
>   Str-vs-Interpolate shape guess every backend reimplemented (and got
>   differently wrong).** The decl family is lexed `name=` + VALUE word and
>   backends tell the VALUE from a following NAME by the word's SHAPE — a
>   quoted piece (`Interpolate`) is the value, a bare `Str` is the next
>   name. `copy-propagation` then destroys that signal: `local e="$v"` with
>   `v` constant folds to `["e=", Str("world")]`, byte-identical to the
>   two-word spelling, and the backends guessed in OPPOSITE directions —
>   measured on `v=world; f(){ local e="$v"; echo "[$e]"; }; f`: bash
>   `[world]`, **Rust `[]`** (it read the bare Str as the next declaration
>   and never assigned `e` at all), Perl `[world]`. The rewrite rejoins
>   `["name=", Str(v)]` → the canonical one-word `["name=v"]`, which every
>   backend already parses identically (`split_once('=')`), so the guess is
>   gone rather than re-won per renderer. **Scope is exactly
>   `local | declare | typeset`** — for that family the parser already
>   lowers `name=` + a following NAME into `Declare` nodes (measured over
>   the whole family, top-level and nested), so a surviving bare Str in
>   value position can only be a folded quoted expansion; `export` /
>   `readonly` / `nameref` keep the two-word form standing (`export c= d`
>   means "assign c, then NAME d") and are refused — REFUSE > GUESS. A
>   following `Interpolate` is never touched (that is the live signal the
>   `081` refusal exists to protect). Registered as `decl-value-rejoin`, a
>   SECOND `interp_fold::transform` entry at the END of `all()` (the
>   `not-identity` double-registration precedent): the shape it rewrites is
>   minted at `copy-propagation`, so the early `interp-fold` slot cannot
>   see it, and running last means nothing can re-fold a value into the
>   ambiguous shape after it. Five new pins in `interp_fold::tests`
>   (`folded_decl_value_rejoins_to_the_inline_word`,
>   `export_and_readonly_keep_their_two_word_form`,
>   `a_quoted_value_piece_is_left_on_shape_signal`,
>   `a_non_decl_command_word_list_is_untouched`,
>   `a_bare_equals_head_is_not_a_name`). Verified equivalence: `./fail`
>   563/563, `./fail-estree --gate` PERL 563/563 + ESTREE 563/563 (100%),
>   `harness/fail-rs` 556/0/7 (baseline), `harness/py-rust-gate` 98/103
>   (documented t82/t87/t104), `check_qx_shir` 563 examples 0 violations.
>   `cargo test --lib` 1784 pass / 47 fail — all in `c_backend`/`estree`/
>   `fish_backend`/`shir`/`shir_json_in`, and a control run with
>   `decl-value-rejoin` DISABLED fails the identical set (superset of 60):
>   none are this change. Corpus byte-output: unchanged by this rewrite (no
>   corpus example carries the folded shape); the win is the correctness
>   divergence above, which the corpus never exercised. Rust-emit state at
>   this round: 0 `sh2.*` callouts, 0 dead polyfill definitions, 122 casts,
>   129 `parse::<i64>`, 38 `format!("{}")`.
> - v82: **`analyze_var_nospace` now sees EVERY write — for-loop bindings
>   included — so loop-only vars get a verdict and the conjunction is
>   order-independent (shared verdict; every backend inherits the folds).**
>   Three holes closed in one pass over `shir::analyze_var_nospace`:
>   (1) `IrStmt::For { var, … }` was never collected, so a loop-only
>   var had NO verdict — `for i in {1..5}; echo $i` kept its runtime
>   word-split in every backend (Rust: `__sh_split_ifs(&i.to_string(),
>   …)`; ESTree: a `sh2.split` callout; Perl folded it anyway at render
>   time). A for-binding now gets its own proof: each Array element is
>   ONE word of the list (parser already expanded `{a..c}`),
>   whitespace-free literals bind whitespace-free words, but an element
>   carrying a glob metachar (`* ? [`) is refused — pathname expansion
>   runs after splitting and a matching FILENAME may contain spaces —
>   and a non-literal element (`$x`, `$(cmd)`, interpolate) is refused
>   outright. (2) The walk skipped `Function` bodies, `ForInit`,
>   `Pipeline`, `Redirect`, `Try`, `Select` and `Declare` — a
>   function-body assign was invisible, so a name could be tagged
>   `true` while a function wrote a multi-word value into it. (3) The
>   fixed point re-evaluated each write independently and left the LAST
>   one standing — a name whose non-free write came first in the walk
>   could end up `true` (order-dependent, unsound). It is now a proper
>   conjunction: start written names optimistically `true`, only ever
>   drop, monotone, one flip per name. Soundness complement: the
>   non-`Assign` writers (`read`/`mapfile`/`getopts`/`printf -v` and the
>   `export/declare/typeset/local name=` call forms; bare `local x`
>   resets to empty — measured `[]` — so it is a free write) are
>   collected as opaque writes, and `let`/`$((…))` arithmetic writers
>   were already free-by-shape. `eval`/`source` remain the documented
>   pre-existing gap (invisible to this and every prior revision).
>   Measured over the 563-file corpus: one more split site folds
>   (001_simple's `echo $i`: Rust drops `__sh_split_ifs`, JS drops
>   `sh2.split` → `process.stdout.write(String(i))`), ZERO regressions
>   (no previously-folded site re-opened), and no other verdict flipped
>   visibly — the other 23 Rust split sites are cmdsub/env operands the
>   proof correctly keeps. Gates: `./fail` 563/563, `fail-rs` 556/0/7,
>   `fail-estree --gate` PERL 563/563 + ESTREE **563/563 (100%** —
>   even 064_07 now green), `py-rust` 98/103 (= documented baseline),
>   `check_qx_shir` rc=0,
>   `cargo test --lib` 43 reds = the concurrent c/estree/fish-lane WIP
>   tests (estree.rs has ZERO `var_nospace` consumers; its reds assert
>   the fnCall native-lift's `builtinValue`/`captureSync` spelling,
>   provably independent of this verdict).
> - v81: **case-lowering first-char bucketing (fb0-raster lane) —
>   the 256-arm hex decode stops scanning (MIMEcroft `--first-frame`
>   −1.86% instructions, `--demo` −0.38% workload-matched; pure
>   shIR, every codegen backend that runs case-lowering).** A long
>   all-exact dispatch chain (≥16 clauses, every literal non-empty
>   and sharing one first char) re-groups under an outer
>   `strHasPrefix(subject, c)` guard — the shared primitive the
>   `lit*` arm already emits — with one inner chain per first-char
>   bucket, clauses in original order (first-match) and the original
>   `*` else replicated into every fall-through: buckets are
>   disjoint on the first char, so entering a bucket and matching
>   nothing there matched nothing anywhere. Refuse > guess: any
>   non-exact clause, <16 clauses, `k + bmax > n/2` (glyph_index's
>   single-character alphabet refuses and stays flat), else >8
>   statements (cloned per bucket), or `SH2_NO_CASE_BUCKET=1` (in
>   bash-o4's `render_env_key` + cli opts key — the arms can never
>   share a cache entry). MIMEcroft: exactly one chain qualifies —
>   rb_h2d (16 guards, +64 lines; ~128 avg strcmp → ~24 per
>   lookup, three calls per blended pixel); corpus render delta
>   651 SAME / 0 DIFF. `RENDERER_REV` 16 → 17. Measured:
>   first-frame 3.279 B → 3.218 B (−1.86%, 7 interleaved runs/arm,
>   spread ±0.001%); `--demo` matched workload pairs −0.39% /
>   −0.37% (3 runs/arm; totals deterministic per workload level,
>   frames 127–136 wall-paced). Frame byte-identical bash == ON ==
>   OFF (live oracle rerun, md5 `53d9cfa7`, 230,415 B);
>   `c_gate_main` 599/45/7 both arms, FAIL sets identical; lib
>   1773/43/5 (same 43-red baseline + 5 new bucketing tests).
> - v80: **the exit-status register is decimal — so `local ec=$?` loses its
>   split in every backend, not just Perl (shared split-fold proof).
>   `shir_passes::split_fold::fold_trivial_splits` could only drop
>   `split(x)` when a var_nospace/var_types analysis tagged `x` — and
>   `$?` reaches the IR as `Var("?")`/`getVar("?")` (or the native
>   lowerings' `CHILD_ERROR` spelling), a name no analysis ever sees.
>   New `is_status_name` proves the obvious: an EXIT CODE renders as
>   decimal digits in every backend (`__SH_RC.load(…)` i32,
>   `sh2.lastExit`, `$CHILD_ERROR`, `_sh_rc`), so splitting it yields
>   exactly the one IFS-free field. Measured across the corpus's six
>   `local ec=$?` sites: Rust emitted
>   `__sh_split_ifs(&__SH_RC.load(…).to_string(), " \t\n")` — the
>   split polyfill + helper call — now `let ec =
>   __SH_RC.load(Ordering::SeqCst).to_string()`; the ESTree path emitted
>   `sh2.split(sh2.lastExit)` — a callout no other backend needed — now
>   `let ec = sh2.lastExit`; Perl byte-identical (it already folded the
>   shape at render time). rustc clean on all six. Pin:
>   `split_fold::tests::folds_exit_status_split` (fold fires, folds to
>   the bare status read, idempotent). This is the marketplace shape
>   done right: one proof in the shared pass, every renderer benefits,
>   no target gate needed because the fact is backend-independent.
> - v79: **value_ll's split arm — int-position args stop
>   round-tripping through snprintf+atoll (MIMEcroft `--first-frame`
>   −34.4% instructions, `--demo` −39.3% per frame; fb0-raster
>   worktree PLAN v56, same entry).** `value_ll` (the C conversion
>   for a proven-int call position) fell back to
>   `atoll(value_c(e))`; for the shape every unquoted word has —
>   `split(getVar("x"))`, 414 of MIMEcroft's 444 int-arg sites —
>   that meant an snprintf `%lld` temp + `atoll` parse per call.
>   `value_c`'s value-context split arm already drops the split (it
>   is only semantic on the child-shell command path), so `value_ll`
>   recurses through the wrapper: byte-identical value, no temp.
>   NOT a shared rewrite — the split marker stays semantic for
>   rust/perl/java runtime splitting; this is the C-int-ABI arm the
>   shared numstr `split` proof licenses. `snprintf(_sN)` 694 → 284,
>   `atoll((char*)(_sN))` 210 → 4. Measured: first-frame 4.741 B →
>   3.110 B instructions (−34.4%, 7 interleaved pairs; cumulative
>   −57.5%); `--demo` 262.9 M → 159.5 M/frame (−39.3%; cumulative
>   −66.3%). Frame byte-identical bash == ARM == no-ARM; `c_gate_main`
>   599/45/7 both arms with identical FAIL sets.
> - v78: **the test-lift guard now asks BASH whether the status is dead,
>   not the emitters (target-gated to Rust, the one emitter that already
>   answers "yes").** Measured Rust emission: `__sh_mod(n, i) == 0` where
>   it used to re-parse its own arithmetic through a String. Need:
>   `test_lowering`'s guard 1 refuses every lift whose cond status write
>   looks observable, using `shir::walk_lastexit_liveness` — whose writer
>   predicate is RUNTIME-truth ("what do the emitters actually record").
>   A plain `IrStmt::Assign` is deliberately NOT in that set, because only
>   Rust emits the write (`i=$((i+2))` → `__SH_RC.store(0, …)`); BASH
>   writes it always (`false; i=$((i+1)); echo $?` prints 0). So an
>   assignment sitting between a cond and the `$?` reader it appears to
>   feed kills that status in bash, yet kept the cond live in the model —
>   pinning `[ $((n % i)) -eq 0 ]` inside 051_primes' `while` to the raw
>   test string: Rust rendered `((n % i)).to_string().trim().parse::<i64>
>   ()` for a value it already held as `i64`, and Go rendered
>   `s2i(capRun("(n % i)", …))` — a **bash process spawn per loop
>   iteration for a modulo**. Mechanism: a scoped, Drop-cleared
>   thread-local latch `shir::assign_kills_guard()` that makes
>   `ir_stmt_writes_lastexit` count assignments, HELD ONLY for the
>   duration of `test_lowering::transform` — so the lift guard's liveness
>   math runs bash-truth while every render-time deadness install
>   (`install_lastexit_deadness`, `install_unread_status_writes`) keeps
>   runtime truth. **Gated on `transforms::target() ∈ {rs, rust}`**
>   (the `split-in-place` target-set precedent): the lift drops the cond's
>   status write, which is sound exactly where the emitter replaces it
>   with the assignment's 0 — measured 2026-10-26 on `false; i=$((i+1));
>   echo "$?"`: bash 0, **rust 0**, perl 1, c 1, JS reads `lastExit` 1.
>   Every other target — and an unset target, which is what the
>   target-agnostic pins run under — keeps the conservative refusal, so
>   `live_status_keeps_the_test`, `live_status_keeps_the_numeric_test`,
>   `arith_expansion_operands_lower_to_binop`'s live-status case and
>   `compound_refusals_stay_on_the_runtime_path`'s live-status case stay
>   true rather than being re-pinned to a rule the emitters do not honour.
>   Corpus effect: exactly one file (051_primes), one line — Rust native
>   compare; Go/Perl/JS emission byte-identical to before. **Found but
>   NOT fixed here (renderer-side, belongs to the owning lanes):**
>   `false; i=$((i+1)); echo "$?"` → bash 0, perl 1, c 1, JS 1 — the
>   assignment's status write is missing from every emitter but Rust's,
>   and adding it (conditionally: an `x=$(cmd)` RHS already carries the
>   capture's status) is what would let this precision be ungated for
>   those targets. Core worker healthy, no fix needed (`gate GREEN`
>   16:06, A1-native invariant 0 violations / 555 probed, no trap
>   markers).
> - v77: **numstr copy-closure — copy-only pass-throughs seed as Int
>   (MIMEcroft `--first-frame` −35.2% instructions, `--demo` −44.8%
>   per frame; fb0-raster worktree PLAN v55, same entry).** Phase 2's
>   anchored coinduction demanded EVERY candidate carry its own
>   anchor, which a pure pass-through structurally cannot:
>   `rbt_t=$rbt_x1` in `rb_tri` is only ever copied from other vars.
>   Without `t` in the candidate set the anchored cycle collapsed in
>   the removal loop (x2's copy of the unseeded `t` failed first,
>   then x1's copy of x2), so rb_tri/rb_face corner coordinates
>   stayed `char*` and paid atoll+snprintf per swap and per edge
>   step. Phase 2b (shir_passes::numstr, shared) admits any var whose
>   every assign is int-valued while GRANTING the candidates int,
>   grown least-fixpoint-style FROM the anchored set — an ungrounded
>   text cycle never enters round 1, and the removal loop
>   re-validates every candidate afterwards. Seeded 188 → 227 vars;
>   rbt_x1/x2/t/minx/maxx/s1 home to `long long`; env-blocked
>   `rbt_v` still refused. Measured: first-frame instructions 7.315 B
>   → 4.741 B (−35.2%, 7 interleaved runs/arm); `--demo` 473.6 M →
>   261.5 M instructions/frame (−44.8%), 67–74 → 51–53 ms/frame.
>   Frame byte-identical bash == ON == OFF; `c_gate_main` 599/45/7
>   both arms with identical FAIL sets; `cargo test --lib` reds =
>   exact baseline (43 both ways, hunk-strip A/B).
> - v76: **echo-fold safety — a folded print is NOT `exec echo`.** Three
>   defects, all the same shape: something only lives on the echo CALL
>   path, and a pass that treated `IrStmt::Output` as equivalent lost it.
>   (1) `echo_fold`'s `fold_dynamic_to_output` folded ANY mixed word, so
>   a `$((…))` word dropped Rust's `__SH_ARITH_WORD_FAIL` guard and its
>   `probe_str` — and that probe is what HOMES a function's parameters:
>   `small_factors` (py-rust t89/t90) went `p0: String` → `p0: i64`, the
>   call site wrapped the argument in `.trim().parse::<i64>().unwrap_or
>   (0)`, a 2^64+1 BigInt parsed to 0, and the factor lists came out
>   wrong (py-rust-gate 96/103 vs 98/103 at HEAD). The fold now refuses
>   a word containing a call/arith/capture — the refusal the `WriteFile`
>   fold already makes for the same reason — so `echo "text $v"`, the
>   shape the fold exists for, still folds. (2)
>   `perl_generator_fixed::fix_stmt` had no `Output` arm, so
>   `fix_array_slice_bounds` never saw a slice inside a folded print and
>   the renderer emitted its RAW range, where a negative offset means
>   "to the END" in Perl — 051_primes printed all 100 primes after
>   `Last 10: ${primes[@]: -10}`. (3) ir.rs's `Output` emitter lacked
>   both guards `emit_echo` applies (SH2BADSUBST → abandon the print,
>   `$?`=1; and the `$__SH2_AE` empty-arith-operand guard that skips the
>   print and leaves `$?`=1 — parse-dollar-in-arithmetic), and
>   `fix_ps_status_blocks`'s local `stmt_reads_exit_status` had no
>   `Output` arm AND no `Var("?")` arm, so the `$?` reader was
>   invisible, `read_next` came back false, and the save/restore around
>   the `rm -f __ps_tmp…` cleanup was skipped — the cleanup's own 0
>   clobbered the consumer's status (070_cmp, process-substitution and
>   064_01 all reported success where bash reports 1). Four stale unit
>   tests updated against in-flight work (`RegSub`→`Substitute`, `sort`
>   now lowers to SortLines, the native-Map migration supersedes the
>   `arrayIndex` example, and `ls|wc` now reduces natively so the
>   `pipelineCaptureSync` collapse is asserted on `sort|head`), and
>   `harness/estree_gate.pl` taught to allow `Map.prototype.{get,set,
>   has,keys,…}` only on a receiver that RESOLVES TO a `new Map()`
>   (binding-collected, so `anythingElse.set(…)` still fails) — the
>   whitelist the native-Map migration needed (6 structural reds → 0).
>   Verified: `./fail` 563/563; `fail-rs` 556 pass / 0 fail / 7 skip;
>   `fail-estree` PERL 563/563; py-rust-gate 98/103 (= the pristine-HEAD
>   baseline; its 3 reds t104/t82/t87 pre-date this round);
>   `cargo test --lib` 44 reds = HEAD's 45 − 2 fixed
>   (`empty_else_kept_when_status_is_read`,
>   `a4_sync_builtins_matches_rust`) + 1 new. Core worker healthy (gate
>   GREEN 12:11, A1-native invariant 0 violations / 555 probed). The two
>   remaining reds are NOT this round's and both trace to `src/shir.rs`,
>   which another workstream was editing live throughout verification
>   (2 hunks → 45 hunks, 2742+/51−, mtime seconds old):
>   `estree::tests::native_pipeline_stage_return_survives_loop_body_
>   signal_rewrite` sits on its in-flight `lowered_stmts_have_signals`
>   hunk, and `064_07_complex_array_operations.sh`'s estree stdout
>   mismatch is the assoc migration emitting `new Map` where HEAD still
>   uses `getVar` (bash `Config: 8080 admin localhost` vs ours `Config: `
>   — HEAD byte-identical to bash). Left alone rather than stomped, per
>   the single-owner rule for the shared core.
> - v75: **str-splice-fold — the rasterizer's per-pixel row splice
>   becomes one shared node + one in-place store (MIMEcroft
>   `--first-frame` −6.9% instructions).** `${b:0:$o}${repl}${b:$k}`
>   (same base, prefix from 0, suffix to end) lowers to an
>   Interpolate of two `param("slice", …)` reads over ONE string — 2
>   substring temps + a join + a store copy: four passes over a
>   2560-byte framebuffer row for EVERY pixel (`rb_putrun`). The new
>   shared transform `str-splice-fold` (sh2perl
>   transforms/str_splice_fold.rs) folds it to ONE `StrSplice` node
>   (shir_nodes/str_splice.node; meaning = exactly the concat it
>   replaced; `base` is an EXPR field so DSE/copy-prop still see the
>   read), target-gated to `c` (§11 offer — a backend accepts by
>   adding its arms and its name in transform_applies; other targets
>   keep the original Interpolate byte-for-byte). C consumes it with
>   a capacity-guarded fused element store: slot already holds the
>   result (strnlen cap check) ⇒ three memmoves in place; the `else`
>   branch is the old path verbatim, and every non-store site
>   rebuilds the original Interpolate from the node's fields (value
>   fallback). The node also joins c_backend's `chop_operands`
>   whitelist — THOSE three scanners (lift_scan_expr,
>   scan_void_uses, walk_expr) refuse PROGRAM-WIDE (unknown Ext tag
>   → `bad` → the whole lift map is void), so without the arm ONE
>   fused store somewhere demoted all 130 MIMEcroft lifts to the
>   argv transport and doubled the exports (+36% instructions: the
>   first A/B measured that integration bug, not the fold — the same
>   failure class FieldStripEnd already documented there). Pinned by
>   the new `str_splice_node_keeps_void_lift` regression test
>   (verified to FAIL with the arm removed). `SH2_NO_SPLICE=1`
>   disables fold + fused arm and keys render_env_key;
>   `RENDERER_REV` 13 → 14. Measured (5 interleaved runs/arm,
>   median): first-frame instructions 4.035 B → 3.758 B (−6.9%);
>   frames byte-identical ON/OFF vs the bash oracle; rendered C
>   differs ONLY at the fused site once temp renumbering is
>   normalized; OFF render byte-identical before/after the whitelist
>   fix (strict no-op without the fold); `cargo test --lib` 43 reds,
>   a strict subset of the worktree's pre-existing 47 (0 new).
>   `c_gate_main` 516/128/7 vs the 12:15 baseline 518/125/8: the
>   delta is 3 zz_probe `cc` reds that are byte-identical ON/OFF —
>   the fold never fires on the gate's byte-pinned shIR ingress, and
>   the reds land in the window of the concurrent text_ops/estree
>   edits (13:01/13:07), not this change. Artifacts:
>   backends-sh-fb0 lane, `/tmp/nxt/` (fx_*.c, ab5_*.txt,
>   cgate_v2.log).
> - v74: **numeric-observed store relaxation — the C backend homes
>   text-stored tables whose every reader re-parses (MIMEcroft
>   `--first-frame` −14.35% instructions).** `shir_passes::
>   numeric_observed` already proved, in the shared layer, *which cells
>   are only ever observed as numbers*; `int_element_verdict` now
>   consumes it as the one gate it was missing. The old rule demanded
>   every STORE to an array be provably canonical-integer text
>   (`val_int`), which is sufficient but not necessary: what has to
>   agree is what a READER observes, and C re-parses every element read
>   with `atoll` (or stores `atoll` into a native slot) — so when all
>   element reads are numeric-observed, the stored TEXT is unobservable
>   and non-canonical stores are accepted too. Veto is the analysis's
>   documented one: no scalar a value read from the array can reach
>   (copies / param slots / downstream array stores) may parse wider
>   than `atoll` — `big` (mpz exact), `IrType::Float`, `IrType::UInt64`.
>   Every density/shape gate still applies unchanged (whole-array
>   reassign, `unset`, non-arithmetic keys, literal cover / append
>   growth, whole-array string reads, iteration). A second, smaller
>   wire was needed to finish the job: the pass's own `str_use`
>   closure stops at every CALL edge (`rb_mkhex(rbx_r, …)` marks
>   `rbx_r` text without asking what the callee does with `$1`), which
>   kept the readers of a freshly-homed table on `char*` — and a
>   `char*` reader of a native table is strictly WORSE (snprintf+atoll
>   bridge per call). `cand` now admits a scalar `nobs.scalar()` types
>   numeric-observed; `demote_stringy_ints` and the `seed_val` fixpoint
>   still re-validate every such seed. `SH2_NO_NUMOBS=1` disables the
>   relaxation (A/B switch; it also keys the bash-O4 artifact cache —
>   `RENDERER_REV` fb0 12→13, main 15→16). Effect on MIMEcroft: 6
>   arrays newly homed (`RBTEX_R/G/B/A`, `MIME_NAMELEN`, `swr`), +64
>   Int-seeded scalars, emitted C 24,815 → 24,769 lines with `atoll(`
>   281 → 250, `_sh_sset(&` 373 → 346, `snprintf(` 308 → 296,
>   `_sh_xstrdup(` 473 → 453; the per-pixel channel read went from
>   guard+pointer+strdup+atoll to one guarded `long long` load.
>   **Measured (5 interleaved `perf stat` runs per arm, control =
>   `SH2_NO_NUMOBS=1`):** `--first-frame` instructions 5,239,896,635 →
>   4,487,799,585 mean (**−14.35%**, spread <0.1%), task-clock −10.30%,
>   wall −4.81%; `--demo` (1200-frame auto-play) 150 → 178.7 frames in
>   the same ~10.5 s budget (+19%), 70 → 60 ms/frame, −12.2%
>   instructions per frame. **Correctness:** the control render is
>   BYTE-IDENTICAL to the pre-change `ab_on.c`, so the A/B isolates
>   exactly this change; frames byte-identical on 5/5 runs and against
>   the pre-change baseline PPM; the `--demo` transcript is identical
>   apart from its self-reported `#stats` timing lines. **Gates:**
>   `c_gate_main` 583 pass / 61 fail / 7 skip — all 61 fail identically
>   with the switch off (pre-existing lane state, 0 regressions);
>   `cargo test --lib` 1731 pass / 51 fail — the 9 `c_backend::tests`
>   failures reproduce with BOTH of my edits reverted in the sandbox
>   (pre-existing), the rest are estree/fish/rust/shir lanes;
>   integration: `c_cut_at` `c_isqrt` `c_growable_value` `c_sight_march`
>   `transform_laws` `pin_mirrors` `lint_smoke` green, and `c_sh2_str`
>   (2), `c_sorted_join` (1), `c_fn_multi_call` (4, missing `-lgmp` in
>   that harness) fail identically with the switch off. **Caveat:** the
>   shared core was left uncompiling by another lane at 05:45
>   (`shir.rs` calls `crate::estree::fold_capture_echo_cond`, which
>   nobody defines — both are single-owner files this lane must not
>   touch), so every build/test above ran from an isolated copy with
>   that one JS-path call neutralized; the C render path never reaches
>   it. **Resolved:** once that lane's fix landed, the real tree
>   compiled again (`cargo check --lib` clean) and the whole
>   verification was re-run in-tree, matching the isolated copy
>   exactly — `c_gate_main` 583/61/7 with a byte-identical FAIL set,
>   `cargo test --lib` 1734 pass / 48 fail (same 9 `c_backend::tests`
>   reds, still red with `SH2_NO_NUMOBS=1`; the other 39 are the
>   estree/fish/rust/shir lanes), `c_cut_at` `c_isqrt`
>   `c_growable_value` `transform_laws` green and `c_sh2_str` (2)
>   `c_sorted_join` (1) `c_fn_multi_call` (4) red identically with
>   the switch off.
> - v73: **`echo … > file` is a native file write — the shared
>   redirect-output → `WriteFile` fold, and the fix for a main tree that
>   had stopped compiling.** The producer half was already native
>   (EchoFold folds `echo "x"` to `IrStmt::Output`) but the enclosing
>   redirect still pushed every backend through its generic machinery:
>   Rust installed the file in `__SH_OUTFILE_TL`, ran the 22-line
>   `__sh_print_words` helper and restored it — five statements for a
>   literal write — Perl rebuilt the `select()` fd swap, the shell
>   backends rebuilt shell text. ESTree already had a backend-local lift
>   for exactly this shape (`try_native_echo_redirect` →
>   `sh2.fs.writeText`); Perl had `native_echo_write_file_stmt`, which
>   emitted `RawText` PERL and — since EchoFold now folds the inner
>   first — could never match its `Expr(Call echo)` pattern any more, so
>   it was dead code that still leaked `DWF: …` debug lines to stderr on
>   every non-matching redirect. New `shir_passes::echo_fold::
>   redirected_output_to_writefile` runs in the SHARED pipeline after
>   the children fold, so all seven backends lower to the one node every
>   renderer already spells natively. Refusals (refuse > guess): not
>   exactly one fd-1 `w`/`wc`/`a` spec; not exactly one inner `Output`
>   with `target: None`; a non-path target (`&1`, `-`, an `Arrow`
>   process substitution); a raw byte marker (the print path decodes
>   those, `fs::write` would not); content is the literal plus `\n`, or
>   `Interp[expr, "\n"]` for a dynamic producer. Perl's `WriteFile` arm
>   now records status 0 after `close` — Rust's, Java's and ESTree's
>   arms already did, and `open`/`print`/`close` touch `$!`, not `$?`,
>   so without it `false; echo x > f; echo $?` printed 1 in Perl only.
>   Corpus effect: **emitted Rust 41,805 → 40,787 lines, files carrying
>   `__sh_print_words` 108 → 87, `std::fs::write` 0 → 28 files, casts
>   124, `sh2.*` callouts 0**. Gates: `./fail` rc=0 (563/563), `fail-rs`
>   **556 pass / 0 fail / 7 skip** (fresh), `fail-estree` rc=0 (563/563
>   = 100%), `fail-shir` rc=0, `py-rust-gate` 98/103 baseline-identical,
>   `fail-coreutils` the 4 documented reds, `cargo test --lib` 1734 pass
>   / 48 fail = the 47-failure baseline PLUS one
>   (`estree::tests::file_target_redirect_collapses_into_builtin`, whose
>   `ls > \"$(cat …)\"` case now collapses — that input's inner is
>   `builtin("ls")`, which this fold provably refuses, so it belongs to
>   the uncommitted `try_builtin_redirect_collapse` extension landing in
>   shir.rs/estree.rs from another lane). Three tests were rewritten
>   because their PREMISE changed (a literal redirect no longer needs a
>   sink); two rust tests now pin the `fs::write` form and one keeps
>   sink coverage on the grouped `{ … } > f` shape the fold refuses.
>   **Core worker: RED 06:39, fixed.** The main checkout did not compile
>   — `shir.rs` called `crate::estree::fold_capture_echo_cond` with no
>   definition (another lane's half-landed edit), which takes down every
>   backend probe because `fail-estree` builds the main tree; an identity
>   stub in `estree.rs` restored buildability without touching their
>   line. Worker since: `main-checkout build=ok`, gate GREEN 07:19 +
>   07:40, A1-native 0 violations / 555 probed. One `./fail` run showed
>   `058_advanced_bash_idioms` red twice then green on re-run with
>   identical code: that example prints `find . -maxdepth 1` counts of
>   the SHARED workspace root, which other lanes were mutating between
>   the harness's two arms — environmental, not a regression.
> - v72: **the shared `${PIPESTATUS…}` observation verdict — 100 of 563
>   emitted Rust files were bookkeeping a register nothing reads.** Every
>   pipeline stage re-filled `__SH_PIPESTATUS` (a `static Mutex<Vec<i32>>`,
>   a `.clear()` at pipeline start and one `.push(rc)` per stage) whether
>   or not the program ever reads `${PIPESTATUS[i]}`; the corpus has
>   exactly ONE reader (`070_gnuisms_thorough`). New pure shared verdict
>   `shir::program_observes_pipestatus(prog)` Debug-scans stmts AND subs
>   — deliberately over-approximating: it matches the literal name, so a
>   read form the analysis does not know still counts as an observation
>   and the capture stays (a missed read would see 0 from a register that
>   was never filled, so erring toward keeping is the safe direction).
>   Rust's `Render::pipestatus_dead` consults it once per program and
>   skips the clear/push emission; the declaration was already in
>   `prune_unused_statics`'s name list, so it goes with it. Measured:
>   **files carrying `__SH_PIPESTATUS` 101 → 1**, and that one (070) keeps
>   all 34 of its mentions. The verdict sits in `shir.rs` beside the other
>   shared read-surface analyses (`ir_stmt_writes_lastexit`), available to
>   c's `need_pipestatus`/`scan_ps_stmts` and perl's
>   `fix_literal_pipeline_pipestatus` instead of each re-deriving its own
>   scan. Tests: `pipestatus_observation_verdict` (plain program=false,
>   a `param(…, "PIPESTATUS[0]")` word=true, a read inside a sub body=true)
>   and `pipestatus_capture_only_when_observed`. Gates: `./fail` rc=0
>   (563/563), `fail-estree` rc=0, **`fail-rs` 556 pass / 0 fail / 7 skip
>   (fresh, resumed=0)**, `fail-coreutils` the 4 documented parser-gap
>   reds, `py-rust-gate` 98/103 with the SAME 3 pre-existing FAILs (t82's
>   `got [] want [hi]` is byte-identical to the 23:47 pre-change run; its
>   Popen capture buffer is never flushed to stdout — a frontend gap, not
>   a render one), A1 probe 0 violations / 555 probed, `cargo test --lib`
>   1730 pass / 47 fail with the failing set byte-identical to the
>   pre-change baseline (no new reds). Worker: gate GREEN 05:12, A1
>   0/555 at 05:23, no trap markers.
> - v71: **the `%s`-template printf fold — the corpus's last big polyfill
>   cluster, at shIR level so every backend drops it.** `constant_printf`
>   only folded when EVERY word was literal, so any dynamic argument left
>   the statement on the runtime engine: 58 of 563 emitted Rust files
>   carried the `__sh_printf`/`__sh_q_printf`/`__sh_atoi`/`__sh_atou`/
>   `__sh_atof`/`__sh_printf_b` cluster (~135 lines each) for formats like
>   `%s=[%s]\n`. New sibling `printf_s_fold` needs only the FORMAT literal:
>   when every conversion is a plain `%s` with one argument per specifier
>   it splits the format into literal chunks, evaluates each with the
>   EXISTING `printf_const_eval` engine port (no re-port — same escape
>   table, zero-arg calls), and lowers to a native `IrStmt::Output` carrying
>   `InterpPart::Lit` runs around each argument expression (a one-part
>   result collapses to the bare expression, so the renderer emits
>   `print!("{}", v)` with no `format!` wrapper). Refusals, each keeping the
>   statement byte-identical on the runtime path: an escape that can
>   TRUNCATE (`\c`) or MINT a `%` (`\xHH`, `\0nnn`) — the split reads the
>   raw format and would miss a conversion the engine still parses;
>   padded/truncated `%s` (`%-10s`, `%.3s`) and every other conversion;
>   a specifier/argument count mismatch (bash reuses the format or pads,
>   and an unevaluated extra word could carry an expansion); and any
>   argument that expands to SEVERAL words — `${lines[@]}` arrives as ONE
>   `param("slice", …, "@", …)` word, so the static count lied and
>   `041_process_substitution_mapfile` printed the array's join where bash
>   printed one round per element (caught by `./fail`, fixed by the
>   `arg_expands_to_many_words` guard). Corpus: **engine files 58 → 9,
>   printf call sites 126 → 19, emitted Rust 53,358 → 43,034 lines
>   (−19.4%), casts 173 → 124 (−28%), `sh2.*` callouts 0**. Gates after
>   the fix: `./fail` rc=0 (563/563), `fail-estree` rc=0, **`fail-rs` 556
>   pass / 0 fail / 7 skip**, `fail-coreutils` the 4 documented parser-gap
>   reds, `py-rust-gate` 98/103 baseline-identical, A1 probe native,
>   `cargo test --lib` 1727 pass / 47 fail with the failing set IDENTICAL
>   to the pre-change baseline (no new reds). New tests: the `%s`
>   template shape, the one-part collapse, and the four refusal classes
>   (20 printf tests total). Worker: gate GREEN 03:22 + 03:44, A1 0/555.
> - v70: **two equivalence bugs the idiom work could not see — a status
>   write hidden from the verdict, and an `else` that outlived its
>   `elif`.** (1) *Process-substitution cleanup is transparent to
>   `$?`*: the core's `rm -f __ps_tmpN…` (appended by
>   `transforms/process_subst.rs::rm_exec`) is bash's own bookkeeping —
>   every renderer already carries the consumer's status across it
>   (Rust's `__ps_saved_rc`, fish's block arm, Perl's `$__ps_statusN`)
>   — but `ir_stmt_writes_lastexit` counted it as a real write, so the
>   backward scan let it SHADOW the consumer's write and the verdict
>   stripped the consumer's `__SH_RC.store`: `cmp -s <(echo b) <(echo
>   c); echo $?` reported the cleanup's 0 instead of cmp's 1. New
>   shared predicate `shir::is_ps_tmp_cleanup` (the recognition that
>   was previously re-implemented in three places) makes it a
>   non-writer; Rust's block arm and fish's `is_ps_tmp_cleanup` now
>   delegate to it, so analysis and renderers cannot drift about which
>   `rm` is synthetic. (2) *A taken `elif` makes the `else`
>   unreachable*: rust's `const_cond_truth` fold set `alt` from
>   `else_` whenever the head folded false and never cleared it when an
>   `elif` folded true, so BOTH the taken arm and the default arm were
>   spliced inline — `case Darwin in Linux|Darwin|*)` printed `Running
>   on macOS` AND `Running on other system` (000__04h). Gates after
>   both fixes: **`fail-rs` 556 pass / 0 fail / 7 skip (was 4 reds —
>   all four cleared: 070_cmp_basic, 064_01_complex_nested_subshells,
>   process-substitution, 000__04h)**, `./fail` rc=0 (563/563),
>   `./fail-estree` rc=0, `fail-coreutils` the 4 documented parser-gap
>   reds, A1 probe native, `cargo test --lib` 1714 pass / 47 fail with
>   the failing set IDENTICAL to the pre-change baseline (no new
>   reds). New tests: `shir::unread_status_tests` (procsub cleanup
>   does not shadow the consumer; transparency does not keep a
>   shadowed consumer; a user's `rm` still shadows) and
>   `rust_backend::literal_subject_case_drops_the_default_arm_when_one_matches`.
>   Worker: gate GREEN three consecutive cycles (01:38, 01:59, 02:19),
>   A1 0 violations / 555 probed.
> - v69: **the const-printf fold + cast purge — the idiom work v59 left
>   as spec, plus the core worker's second A1 red.** `echo_fold`'s
>   `constant_printf` now folds ANY all-literal printf through
>   `printf_const_eval`, a line-for-line port of the runtime
>   `__sh_printf` engine (same inline escape table with `\c`
>   truncation, flags/width/precision parse, length-modifier skip,
>   width padding and format-reuse loop; float and unknown conversions
>   REFUSE, keeping the statement on the engine byte-identically —
>   `-v`/leading-dash option forms refuse too). 27 all-const call
>   sites folded, dropping the whole `__sh_printf` polyfill cluster
>   (engine + `__sh_q_printf`/`__sh_atoi`/`__sh_atou`/`__sh_atof`) from
>   14 files (engines 72 → 58); the fold is shared, so every backend
>   drops its cluster wherever no other printf survives. Rust-side
>   idiom pass on the remainder: the engine's precision `-1` sentinel
>   became `Option<usize>` (−360 `as usize`, −216 float-arm clamps),
>   and a non-negative const index key now renders the `.get(k)` /
>   `{k}usize` fast path in `array_index_strict`/`_num`/`array_elem`/
>   `array_elem_set` + the three PIPESTATUS arms (−11 clamp templates,
>   0 literal-operand casts left) — the render-side twin of
>   `key_is_nonneg`'s dataflow proof, which only ever proved VARIABLE
>   keys. Corpus: 563/563 emit, casts **508 → 173 (−66%)**, `sh2.*`
>   callouts 0, dead helpers 0. Gates: `./fail` rc=0 (563/563),
>   `./fail-estree` rc=0, `fail-rs` 552 pass / 4 fail / 7 skip (the 4
>   are byte-identical to their pre-change emission — other lanes'
>   reds, entered before this session), `fail-coreutils` the 4
>   documented parser-gap reds, `py-rust-gate` 98/103 baseline-
>   identical, A1 probe 0/563. Worker fixes: (1) `run_core_worker.sh`
>   built `DEBASHC` BEFORE the ff to main, so every probe measured the
>   PRE-candidate binary and rolled `main` back each iteration — now
>   rebuilt after the ff (first GREEN 20:19 since the 13:55 red);
>   (2) the second A1 red: staged `harness/builtins.json` gained `ln`
>   (22:24) with no lift entry — `builtin::BUILTINS` synced to 75
>   entries and committed on main (59614de57) so the worker's ff picks
>   it up; same workspace-vs-embedded drift class as 864bfd3f5.
> - v68: **fb0 device hot-path rounds 1–3 + `BASH_O4_CFLAGS`, all bit-exact
>   against their own oracles.** The demo's CPU profile moved from a
>   rendered-C rasterizer (`_sh_sset` 16.8%, `_sh_arr_get` 13.5%) to ~99%
>   in the fb0 runtime, which then got three rounds of bit-exact trimming:
>   (1) `tri_covers`/divide/fract inlines, loop-invariant hoists and a
>   fused overlay pass — each an inline of the helper's own body with the
>   same operands in the same order, helpers kept as reference forms;
>   (2) present-time hoists + `BASH_O4_CFLAGS` (verbatim extra C flags,
>   folded into the exe cache key in both frontends — default NOT set,
>   because tcc must stay milliseconds and every one-shot corpus cell
>   would otherwise pay seconds): demo tcc→gcc -O2 −14.9% instructions /
>   −15.8% task-clock; (3) this revision: the three leftover per-frame
>   `fprintf(stderr)` debug prints removed, `ov_composite`'s flash half
>   gated by an arm-on-write/clear-on-consume dirty flag, `tri_shaded`'s
>   row terms hoisted (six double subtracts per row, not per pixel — px
>   stays per-pixel because an incremental walk flips last-bit at a power
>   of two), `frag_sample`'s dead lower clamps dropped behind a
>   `size > 0` guard, and `fbwin_present`'s identity depth-24 layout
>   written with one 32-bit store per pixel — demo instructions −5.1%
>   (tcc) / −2.7% (gcc -O2) at byte-identical renders (16 alternating
>   pairs, medians; `fbwin_present` 9.0%→1.8% and `ov_composite`
>   4.6%→1.5% of in-binary samples). Gates: fbdev suite 48 checks +
>   112-case silhouette green under cc AND tcc, stdout identical across
>   all bench arms, c-gate 584/650 with no red in any fb cell.
> - v67: **java and zig measured on a second box, and the gate defects that
>   were hiding their progress.** Neither backend could be measured here:
>   a `--backend-gate` pass builds the core and then holds the fleet's
>   single `.gate.lock` for all 654 files, so java had gone a full day
>   without a verdict and its last report said **0/654** — which was not a
>   renderer problem at all. Two gate-visible bugs: (1) the java
>   renderer's emitted child-sync helper was named `_sh2_env`, and the
>   stub check's `sh2[A-Za-z_0-9]+\(` matched its *definition*, so
>   EVERY file reported `stub(1)` (renamed `_sh_syncvar`); (2) java's
>   test-word emitter pasted `\"` into the Java SOURCE outside any
>   literal (`shQuote(\"…\")`), so javac died on `illegal character` for
>   whole files. With those fixed and the gate moved to an idle 12-core
>   box (`harness/remote-sync.sh` + `harness/backend_gate_remote.sh`,
>   same rules, 2.5 min per pass), the real baselines are **java 559/650**
>   and **zig 401/650**, from 0/654 and 392/650. Java's remaining 84 are
>   genuine lowering work (79 equivalence); zig's 242 are dominated by
>   *genuine* `sh2TODO` nodes after the TODO-comment double-count fix.
>   Real renderer bugs found and fixed on the way, all of them classes
>   rather than one-offs:
>
>   * **Fork semantics.** `shSnapshot`/`shRestore` were EMPTY stubs, so a
>     subshell's writes leaked into the parent (`( x=2 ); echo $x` printed
>     2) and a background job raced the parent's read
>     (`105_background_copy_semantics`). Both are now generated over the
>     program's own fields/arrays, and `{ …; } &` runs against a fork
>     snapshot.
>   * **Captured loops were dropped.** A `while …` stage's output was
>     captured into a helper whose bytes had no sink
>     (`while read …; done < f` printed nothing, 084/088/091), and a
>     redirect-fed loop was routed to a helper whose fd 0 is NOT the
>     redirect target — text first, always.
>   * **`mapfile`/`readarray` as java state**, not child-shell state
>     (the array field stayed empty and `${lines[@]}` printed a blank
>     line).
>   * **java's `${v+word}`** needs a set-ledger: Java cannot represent
>     "unset", and "0" is a non-empty string (the `contains()` status form
>     had the same trap).
>   * **zig's bash dynamic scope.** A function's writes are GLOBAL unless
>     `local`. The renderer emitted them as MAIN locals, so the body could
>     not see its own writes, and the value parameter invented to bridge
>     that collided with the fn's positional parameter or a runtime
>     helper's (`shToInt(s: …)`) — a build-break class, now a module-scope
>     `g_<name>` cell that main and the functions share.
>   * **zig's fused `[[ $s =~ ^re$ ]]`** was one token, so it became a glob
>     PATTERN match; it now splits and matches through a bash child (no std
>     regex).
>   * **Honest TODO counting.** The `TODO(unsupported)` marker is no longer
>     written into the emitted program: the gate counts the marker, so one
>     construct cost two stubs and a file whose only stub was a rendered
>     call still reported one for its own diagnostic comment.
>
>   Gate-rule traps this surfaced (each one made a WORKING renderer look
>   broken): `SUB`/`ROOT` must be EXPORTED in the remote worker (its body
>   runs in a `bash -c` child — unexported, the zig arm linked
>   `-L"/runtime/lib"` and every file "failed to build"); zig resolves its
>   source path against the CWD, so it needs `./p.zig` and the uu-ffi
>   `-lc/-lcoreutils_ffi/-rpath` flags; `OTRANSPILER_ROOT` must be exported;
>   and the bash REFERENCE side must run with `BASH_ENV` unset (this box's
>   `BASH_ENV` exports shell FUNCTIONS that only bash has).
> - v66: **`A || true` captures fold to one run with forced status — and
>   the partial-output bug they were hiding.** The generic
>   `chain_or_capture` form ran the RHS INSTEAD of keeping `$__c`: for the
>   no-op status command that forked a whole `bash -c true` for an empty
>   string AND discarded the LHS's partial stdout — `x=$(ls f g
>   2>/dev/null || true)` printed f's line under bash and NOTHING under
>   the generated Perl (real divergence, unexposed by the corpus: both
>   sites are pgrep/cat-shaped with no partial output). The fold emits
>   `do { my $__c = <lhs>; $CHILD_ERROR = 0; $__c }` — one fork, status
>   constantly 0 as bash defines it, output untouched; the forced write
>   rides `rc_write` so status-liveness elision still applies. Guard is
>   structural (`is_noop_status_cmd`: bare `true`/`:` with no words;
>   `expr_to_cmd` single-quotes literal names, so the first text-guard
>   attempt never matched and the probe caught it). Non-noop RHS keeps the
>   generic two-arm form byte-for-byte. Measured: 2 → 0 noop forks,
>   pipe_capture sites 58 → 56, exactly 2 corpus files changed;
>   `./fail` **562/562**; `perl -c` + `check_qx` clean; 4 unit tests.
>   Submodule `71b584d29`.
> - v65: **the Perl external-command seam gated per segment — 418 dead
>   subs retire, generated corpus −30%.** `SH_RUN_EXT_PREAMBLE` was ONE
>   blob on four coarse entry markers, so a body calling only
>   `__sh_uu_capture` embedded the whole pipeline front end and vice
>   versa: 418 of 826 embedded `sub` instances across the 562 examples
>   were never called (44 files uu-only, 55 pipe-only, 19 both, 444
>   none). `sh_run_ext_preamble()` splits the blob at line boundaries
>   (`split_inclusive` makes the all-live reassembly byte-exact — pinned
>   by test) and emits each segment only when the body names it or a
>   live segment needs it: `__sh_pipe_capture` drags uu SUPPORT for its
>   shared `$__SH_UU_SEQ`, `__sh_q` is gated on its own body marker, and
>   `# __SH_RUN_EXT_END` always closes so check_qx's strip keeps its
>   anchor. Entry markers unchanged (no new seam can appear; a false-
>   positive marker only over-emits). Measured: 826 → 320 definitions,
>   0 uncalled, 0 call-without-def, corpus 1,464,718 → 1,023,493 bytes;
>   `./fail` **562/562**, `perl -c` + `check_qx` clean, 5 new unit tests.
>   NOTE for the fleet: `cargo test --lib` currently has **14 pre-existing
>   reds** (9 c_backend, 5 fish_backend) that predate this work — the
>   crate did not compile at HEAD since `Function.params` landed, so the
>   suite could not run; proven pre-existing at `201f0c9c4` + the
>   one-line params fix (identical 14 fail). Submodule `627cbb5a8`
>   (segment gate) on top of `e60cb9b82`/`e4ad098d7`.
> - v64: **Perl redirect emit made idiomatic — the print-only
>   lexical-select fast path (75 of 111 dance sites convert).** A
>   `Redirect` over a non-command inner used the heavy dup/close/reopen of
>   the REAL STDOUT glob even when nothing in the body could fork — a
>   shape whose whole reason is that children inherit the redirected fd 1
>   (`capture_do_perl` argues the same from the capture side). For a body
>   whose every output is a bare Perl `print`, `select` on a LEXICAL
>   filehandle routes the same bytes without mutating a global handle: a
>   `die` mid-body can no longer leave STDOUT closed, and each site emits
>   2 lines instead of 5. Refuse>guess keeps every forking body on the
>   proven heavy path byte-for-byte (the `capture_do_perl` spawn-marker
>   vocabulary plus the capture seam, qx/backtick), and any body
>   mentioning the STDOUT glob falls back too — `063_14`'s pure-Perl diff
>   emulation holds `my $__fh = \*STDOUT; print $__fh …`, an explicit
>   alias that bypasses `select($fh)` and only the reopened glob serves
>   (the gate caught it, then the marker list pinned it). fd-2 redirects
>   keep their existing shape. Also fixed the shared crate's compile:
>   `fish_backend`'s `IrStmt::Function` lift was never given the core's
>   new `params` field, so HEAD failed E0063 for every worker. Verified:
>   `./fail` **562/562** (the `test_find` CWD-churn flake was diagnosed as
>   environmental first — deterministic generation, byte-equal arms in
>   quiet windows); `perl -c` + `check_qx` clean over all 562 generated
>   files. Submodule `e60cb9b82` (fish params) + `e4ad098d7` (fast path).
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

**The dispatch loop is closed (2026-10-12, HEAD `448f32db`).** The
v50 entry's "emit-half remains" is now the landed host half:
`bash-o4/src/fb_draw.rs` (`RasterRunner` — offscreen color+depth
target, atlas upload with crack = layer 9, blocks 36-vert list with
depth on + overlay 6-vert list with src-alpha, push constants,
readback), `bash-o4/tests/fb_dispatch.rs` (blocks centre pixel == Rust
oracle of `frag_pixel` — 204,0,0 for shade-800 red — plus clear corners
and determinism; overlay opaque green full-screen; lavapipe-pinned; no
device ⇒ reported skip, present-but-misrender ⇒ loud FAIL), and driver
`--fb-proof[=WxH]` (the proof scene through the real binary as a P6
PPM — translucent-green-over-red, exercising the blend path).
`--emit-shader fb-blocks`/`fb-overlay` still prints the pair
(SPIR-V-checked per stage when a compiler exists) and still requires a
matching device write in that program (`GpuOp` or the `fb_*` call
spelling, else a refusal — never a guessed dispatch). The proof caught
two emitter bugs hiding behind the missing dispatch
(`gl_InstanceID`/`VertexID` are OpenGL names — Vulkan wants
`gl_InstanceIndex`/`VertexIndex`; `fy`/`fz` missed the `/1e6` milli
divisor and exploded verts to ±50000), both pinned by strengthened unit
tests. Proof re-run 2026-10-12: `cargo test --offline --test
fb_dispatch` 2/2 ok, `--fb-proof=64x64` rc=0 12301-byte P6,
`--emit-shader fb-blocks` rc=0. Lavapipe teardown faults found +
documented in the module (pool/framebuffer/render-pass freed pool-last
/ cached / device-leaked by design — eager destroy segfaults the second
runner teardown in the process; `vkffi::has_compute_device` leaks its
probe instance by design, same class). What this does NOT change:
the proof scene is not a program payload, per-frame record packing and
texture upload from game assets stay caller-side, and the `_sh_gpu_*`
host split in generated C is still the open M3 item.
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

- **2026-11-12 — Perl emit: census-driven idiom sweep (brace ranges,
  `int((`, `@_` parameters, element interpolation).** The 2026-11-11 pass
  fixed the status register but left known artifacts behind and only
  measured a few patterns by hand. This pass derives the work list from
  the OUTPUT: render all 563 examples, then count every suspicious form
  mechanically (`/tmp/census.py`: scans a rendered corpus, strips the
  renderer's own preamble helpers so the counts describe the TRANSLATED
  body, and uses
  three detectors a `grep` cannot express — a balanced-paren scan for a
  genuinely redundant `int((E))` (a raw `int((` substring also matches
  `int((0+7) | (0+8))`, where both pairs are load-bearing), a numeric-run
  check for an expanded brace range, and a position-accurate scope walk
  for `my` redeclaration in the SAME block).

  Before → after over the 563 rendered examples (count / files):

  | pattern | before | after |
  | --- | --- | --- |
  | expanded numeric for-iterand (`(("1", "2", …))`) | 14 / 12 | **0** |
  | any `for my $x ((` list-in-extra-parens | 39 / 32 | **0** |
  | redundant `int((E))` (balanced) | 62 / 37 | **0** |
  | `local @__sh_args = @_;` | 25 / 22 | **0** |
  | `local @ARGV = @_;` | 27 / 23 | **0** |
  | `my $__argc` (dead count snapshot) | 97 / 45 | **0** |
  | `if (1)` / `elsif (0)` constant chain | 6 / 5 | **0** |
  | `print("")` no-op | 1 / 1 | **0** |
  | `for my $__X (…)` throwaway copy temp | 226 / 81 | 183 / 52 |
  | ` . ($` concat around a variable | 40 / 22 | 19 / 13 |
  | any ` . ` concat | 353 / 101 | 314 / 94 |
  | `while (1)` | 7 / 7 | 7 / 7 |
  | `$?` register use | 21 / 20 | 21 / 20 |
  | `do { }` blocks | 911 / 196 | 911 / 196 |
  | `scalar(@…` (new: `$#` reads) | 0 | 60 / 48 |

  Five emitter changes and one post-pass, all in `sh2perl/src/ir.rs`
  (`int_call` also used from `perl_backend.rs`):

  1. **Brace ranges and list iterands.** `for my $__i (("1", "2", …))`
     came from expanding `{1..5}` into a literal list. `iter_list_to_perl`
     now recognises the arithmetic sequence and emits Perl's range —
     `for (1 .. 5)`, `for (reverse(1 .. 5))` for a decreasing run (Perl
     has no stepped range, so any other step keeps a literal list, now
     without quotes: `for (1, 4, 7, 10)`) — and NEVER double-wraps a list
     that already carries its own parentheses. The loop variable is `$_`
     of a bare `for (LIST) { $i = $_; … }`: Perl localizes `$_` per
     iteration, so bash's after-loop value of `$i` is preserved with no
     invented `$__i` copy temp. A `(join(' ', @arr))` iterand becomes
     `@arr` (the array, one word per element) while a BARE
     `join(' ', @ARGV)` — bash's single-word `"$*"` — is left alone.
  2. **`int((E))`.** The arithmetic renderer parenthesizes every node and
     the coercion wrapper parenthesized again. `int_call` strips repeated
     enclosing groups (`int(($i + 1))` → `int($i + 1)`), and because
     `typeset -i` arithmetic is spelled by the FRONTEND, the finished text
     also passes a quote-aware `dedupe_int_parens` (one rule instead of a
     per-producer patch; `int((A) / (B))` and `int((0+7) | (0+8))` are
     untouched because the inner group does not close at int's paren).
  3. **Function positionals are `@_`.** A bash function's `$1`…`$n`, `$#`,
     `$@`, `$*` and `shift` are exactly Perl's per-call `@_`, so the
     renderer no longer emits `local @ARGV = @_;` + `my $__argc = @ARGV;`
     and `fix_sub_params` no longer injects `local @__sh_args = @_;`. A new
     scoped pass (`sub_params_to_at_underscore`, after the `$N` and slice
     rewrites, before the file-scope binding) rewrites each function body:
     `$ARGV[1]`/`$__sh_args[1]` → `$_[1]`, `$#ARGV`/`$__sh_args_n` →
     `scalar(@_)`, `@ARGV`/`@__sh_args` → `@_`, `shift @__sh_args;` →
     `shift;`, and DROPS the `$__sh_args_n = scalar(@…);` line a `set --`
     used to maintain (with `@_` there is no separate count — rewriting it
     produced `scalar(@_) = scalar(@_)`, a compile error). Renderer runtime
     helpers (`sub __sh_*`) are skipped: they own their `@_` and read the
     program's parameters by name on purpose.

     The package-array DECLARATION now has one owner: the `our @__sh_args;`
     that `fix_sub_params` used to plant is gone, because it was planted
     while the sub bodies still carried `$__sh_args[…]` and then outlived the
     rewrites that turned those reads into `@_` — a function-only program
     would keep four dead lines (`our @__sh_args;`, `our $__sh_args_n;` and
     the `local … = @ARGV;` pair). Only `bind_toplevel_positional_params`
     declares now. Rendering the whole corpus before/after this removal is
     **byte-identical (0 of 563 files differ)** — no example reads a
     positional parameter only inside a function — so this is a
     one-declarer rule, not an output change.
  4. **Element interpolation.** `interp_scalar` now also admits a plain
     `${name}` (the `param` contract form, operator-free) and an
     array/hash ELEMENT whose subscript is a literal, a `$var` or a
     bare-word key — `"e0=$arr[0]"`, `"m=$map{'k'}"`, `"m=$map{$i}"`,
     `"$ENV{LOG_LEVEL}"` — so those stop being
     `"e0=" . ($arr[0]) . …`. Positional params stay OUT (`"$1"` is a
     regex capture), and a subscript that cannot be re-parsed keeps the
     concatenation.
  5. **Constant `if`, empty `print`, `grep -o`.** A fully constant
     if/elsif/else chain (a folded `case`) emits its one live body in
     place instead of `if (1) { … } elsif (0) { … }`; `print("");` (bash's
     no-op `:` under a redirect) is dropped; `grep -o` iterates the match
     list as `for ((…) =~ /re/g) { print $_, "\n"; }` instead of
     inventing `$__m`.

  Left in place, each with a concrete reason no idiomatic spelling exists:

  - **183 `for my $__X (…)`** — every one is inside an INLINED runtime
    helper (`comm`/`diff` LCS, sorted-set ops, `read -p`) that runs in a
    `do { }` block in the USER's scope. There the variable IS the loop
    variable (`for my $__i (0..$#__a)`), not a copy temp, and the `__`
    prefix is what keeps an internal name from shadowing a user's `$i`.
  - **18 `join(' ', grep { defined($_) && length($_) } split(…))`** — the
    grep expresses bash's IFS word-splitting (drop empty fields) on top of
    Perl's `split /\s+/`. The shorter `split ' '` is equivalent only for
    DEFINED input; on an unset variable it adds `Use of uninitialized
    value` to stderr, which the emulation must not introduce.
  - **41 same-scope `my` redeclarations** — all `open my $__fh, '>', …` for
    consecutive `echo > file` statements. `open my $fh` IS the canonical
    Perl idiom; suppressing the "masks earlier declaration" warning needs
    one declaration hoisted per scope, and the flat statement emitter has
    no scope to hoist into (the redirect region is not a block).
  - **7 `while (1) { … last … }`** — the standard Perl spelling of bash's
    `while true` / multi-command condition loop.
  - **21 `$?`** — the child wait-status conversions (`$CHILD_ERROR = $?
    >> 8;`) where a real process finished; the register itself is gone.
  - **60 `scalar(@…)`** — `$#`/`$#@` become the count of `@_`/`@__sh_args`;
    `$#_` would be the last INDEX, so this is the correct idiomatic form.
  - **911 `do { … }`** — capture buffers, `eval`-guarded arithmetic and
    constant-folding blocks; a block expression is how Perl scopes a value.

  Verification of record (all on the final source): full `./fail`
  **563 passed, 0 failed, rc 0** twice on this source (`TESTS COMPLETED:
  563 passed, 0 failed out of 563`); the final one-line
  `declare_param_array` removal renders **byte-identical to the corpus the
  gate ran** (0 of 563 files differ), so the re-run adds no new text to
  validate. `perl -c` clean on all 563 rendered files (**0/563
  failures**); six hand-written spot checks byte-identical to bash on
  stdout AND exit code — status across `false`/`true`/`||`/`&&`/`if`,
  pipeline `$?`, negation folding (`[ ! "$x" = z ]`), scalar
  interpolation, array/hash element interpolation, and function
  positionals (`set --`, `$#`, `$1`, `$*`, `shift`). `cargo test --lib
  ir::tests` **43/43** and `pgf_tests` **34/34**; full `--lib` is 1798
  pass / 57 fail, and every failing name is another backend's or a shared
  analysis's (estree 23, c_backend 12, fish 6, std 5, shir 5, rust 5, zsh
  2, shir_json_in 2, zig 1, go 1 — `rust_backend` is mid-edit in this
  shared worktree: it briefly did not compile at all today, `Self::` in a
  free function), i.e. the session's opening 52-failure class list on
  paths this change never reaches. The two pins this change moves are contract
  changes, not weakenings: `split_word_expands_in_list_contexts` pinned
  `for my $__w (split /\s+/, $x) {` and now asserts the new shape
  (`for (split /\s+/, $x) {` plus `$w = $_;`), and `binding_injected_after_argv`
  pinned the deleted `inject_param_binding` and is replaced by
  `sub_params_become_at_underscore`, which pins the new contract
  (`$_[0]`, `scalar(@_)`, `shift;`, no `local @…`) and that a `sub __sh_*`
  helper keeps the program's names.

  Found and NOT fixed (pre-existing, outside the idiom mission; none is
  exercised by the corpus): `( exit 7 )` lowers to a bare `exit "7"` and
  terminates the program instead of the subshell; an unbraced `$arr[0]`
  inside a double-quoted string is passed through verbatim (bash reads
  `$arr` plus the literal `[0]`, Perl reads the element — wrong output on
  `"$arr[0]"`, and a compile error on `"$aa[one]"` when `@aa` is
  undeclared); `echo "n=$1" >&2` inside a function bakes the Perl
  spelling into a `bash -c` string; and `for c in $(printf 'p q')` lowers
  to `for ('')` — one empty iteration where bash runs the body twice (any
  `printf` in an unquoted for-iterand; `$(echo …)` in the same position
  and `x=$(printf …)` in an assignment are both correct, so it is that
  one lowering, not the capture machinery). Gitlink not bumped and nothing
  committed: this worktree carries other workstreams' uncommitted edits
  (same convention as the entries above).

- **2026-11-11 — Perl emit: ONE status carrier, plus the double-negation,
  interpolation and empty-`else` forms.** The mission was to remove the
  non-idiomatic Perl the renderer emits. A census over all 563 corpus
  examples (`--source-lang sh --target perl`, then `grep -o` counts) put
  the overwhelming majority in ONE construct: the status register dance.
  The renderer had two representations of the same variable — Perl's `$?`
  is a WAIT status and English.pm's `$CHILD_ERROR` is its name — so every
  status write was a round-trip and every read shifted:
  `$? = 0 << 8; $CHILD_ERROR = $? >> 8;`, with `($? >> 8)` reads and
  `exit $? >> 8;`. **2 671 register writes and 2 652 `<< 8` shifts** in
  the corpus, on nearly every statement.

  Four render-side fixes, all in `sh2perl/src/ir.rs` (plus the two
  `$? = 0;` template sites in `pipeline_native/mod.rs`):

  1. **Single carrier.** `rc_write`/`rc_register_in_text` now emit
     `$CHILD_ERROR = <code>;` — the plain shell exit CODE (0-255), no
     shift, no round-trip. `var_read("?")` and `IrExpr::Var("?")` read it
     directly, and the epilogue is `exit $CHILD_ERROR;`. A real child's
     wait status is still converted exactly once, where the child
     finishes (`$CHILD_ERROR = $? >> 8;` — the `system`/`close` templates),
     which is why the remaining `>> 8` sites are correct rather than
     residue. **The mirror mechanism is gone**: with one representation
     there is nothing to keep in step, so `CHILD_ERROR_CARRIER`,
     `set_childe_error_carrier` and `perl_generator_fixed`'s
     render-twice-and-probe loop are deleted (one render per program).
     The EMBED renderer keeps the register spelling — a fragment must not
     declare package state in its host, and `our $CHILD_ERROR = 0;` would
     clobber the host's status — via a thread-local set for the
     fragment's lifetime.
  2. **Negation folding.** `!($x ne 'red')` (the case/value-test arm
     tests a `!=` through a NOT) is now the direct comparison:
     `$x eq 'red'`. The pair stays in one family (`Eq` renders numeric
     `==` → `!=`, `Ne` renders string `ne` → `eq`), so the truth value is
     unchanged. 83 → 8 (`!(…)` over a non-comparison keeps its form).
  3. **String interpolation.** The Interpolate arm only accepted `Var`
     nodes, but the shell frontend emits the CONTRACT spelling
     `getVar("x")`, so an echo with any variable fell to concatenation.
     A shared `interp_scalar` now admits both and emits
     `print "ref='$original'\n";` instead of
     `print "ref='" . ($original) . "'\n";` (a `${name}` brace is added
     only when the next literal starts with an identifier character).
     Positional params are explicitly NOT interpolated — `"$1"` is a
     regex capture, so `$1` keeps its `$ARGV[0]` spelling (that guard is
     the bug the first cut introduced and the corpus gate caught).
  4. **No empty `else`, no doubled write.** An `if` whose status write was
     proven unread still emitted the wrapper plus a body that `rc_write`
     then elided — `} else {\n    }` (30 sites). The arm now skips the
     `else` entirely when the write is dead. `dedupe_adjacent_status_writes`
     drops a status write immediately followed by an identical one (two
     statements each recording the same value, 184 sites → 0).

  Measured over the corpus: `$?` register writes **2 671 → 0**, `<< 8`
  **2 652 → 0**, `exit $? >> 8` **558 → 0**, `if (!(` **83 → 8**,
  `. ($` concatenations **225 → 152** (the remainder are positional and
  array/hash reads, which cannot interpolate safely), empty `else` **30 →
  0**, duplicate adjacent writes **184 → 0**; total emitted lines 23 963 →
  23 940 even though every program now declares the carrier
  (`our $CHILD_ERROR = 0;`, +563 lines).

  Verification of record: full `./fail` **563/563 rc=0** on the final
  source (the corpus gate compares byte stdout + exit code vs bash, so the
  status-model swap is exercised on every example); `perl -c` over all
  563 rendered files is clean; an
  ad-hoc status battery (`$?` after true/false/subshell/grep/capture,
  `[ "$?" = 0 ]`, `if cmd; then`, `&&`/`||` branch statuses, `exit 3`)
  is byte-identical to bash **including the exit code**; `cargo test --lib
  ir::tests` **43/43** — the two pins that spelled the old register
  (`preamble_gates_dead_boilerplate`, `embed_collapses_main_exit_writes`)
  were re-pinned to the new contract, not weakened (the embed test now
  asserts the fragment carries NO `$CHILD_ERROR` at all). Full `--lib` is
  **1803 pass / 52 fail**, and the failing set is the session's opening
  baseline **minus** `ir::tests::embed_collapses_main_exit_writes` (which
  this change fixes): the 52 are other backends' suites (c/estree/fish/
  go/shir/zsh) broken by uncommitted edits in this shared worktree, on
  paths this change never reaches. `./fail-estree` not run (the estree
  renderer is untouched; the Perl renderer is not on its path).
  `harness/check_ast.pl` not run (its `dump_ast` bin is already missing —
  pre-existing harness gap). Gitlink not bumped and nothing committed:
  this worktree carries other workstreams' uncommitted edits, so the
  commit/bump is the owning session's call (same convention as the
  2026-10-21 entries above).

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

### 2026-10-29 — recovered the lost `_sh_ll2s` fast-itoa arm (C backend)

The hand-rolled itoa that `num_temp` used to emit ("byte-for-byte what
snprintf(\"%lld\") writes, incl. LLONG_MIN; SH2_NO_ITOA=1 restores
snprintf") existed only as **uncommitted** `c_backend.rs` state: it was
in the Oct 28 11:22 CLI binary and in every render since (297 call sites
on MIMEcroft), but was clobbered from the working tree before the Oct 29
12:02 builds — never committed anywhere (`git log --all -S _sh_ll2s`
finds only the proofs commit). The contract had survived around it:
`tests/c_direct_cat.rs` (uncommitted, asserts ON-emits-`_sh_ll2s(` /
OFF-emits-snprintf and both match bash), `proofs/verus/c_dec_str.rs`
(26 obligations over the helper's semantics), and the Oct 28 binary's
string table (exact helper template).

Restored in `c_backend.rs`, all four touch points: `num_temp`'s default
spelling behind `SH2_NO_ITOA` (same pattern as `SH2_NO_CONCAT`), the
present-iff-used helper splice after the includes, `fuse_num_temp`
recognising both conversion spellings, and `drop_dead_num_temps`
extracting the value call-freely from either. A concurrent lane worker
then extended the restored helper with `SH2_NO_ITOA_FASTDIV` (magic
`mulq` div10 — the digit division is the helper's whole cost under tcc).

Verified: `c_direct_cat` green; `cargo test --lib` failure set identical
(48 pre-existing) with the arm ON and OFF; `harness/c_gate_main.sh`
**588/56/7 before vs after — same 56 FAIL files**. Bench caveat for
future sessions: there are TWO divergent MIMEcroft sources —
`bash-o4/MIMEcroft_fb.sh` (main tree, fb_* device API, 5138 lines) and
`backends-sh-fb0/bash-o4/MIMEcroft_fb.sh` (rasterizer port, 7362 lines);
note which tree a timing came from.

### 2026-10-30 — recovered the lost Verus sweep models (17 files) by re-authoring the trio

**What was lost.** `git log` records the sweep commits
(`f2b9e1ed4` string/cursor, `b6731d412` loop-hoist, `65d662691`
suites-then-proofs), and those commits are still in the submodule's object
store (`git ls-tree 65d662691 proofs/verus/` lists all 67 files) — but the
commit NODES are gone from every ref (`git log`, `--all`), the working tree
carried only 63 entries of the 67 the tree names, and `git status` showed
the extra files as clean, i.e. tracked. Net effect: 17 model files
(`append_store`, `split_set`, `echo_return`, `arith_forms`,
`counted_while_forinit`, `scc`, `used_before_decl`, `maskable`, `lifetime`,
`numstr`, `numeric_observed`, `str_splice_fold`, `str_chop_cursor`,
`hoist_loop_invariants`, `direct_calls`, `cat_read`, `grep_o`) are absent
from the worktree and have no reachable git object to restore them from.

**What was NOT lost, and is the recovery path.** The SOURCE of every one of
those transforms is intact in `sh2perl/src/`, and the gate, the VERUS.md
inventory, and the per-model README sections all survive. A model is a
hand-written reduction of a source (VERUS.md §(b).1), so it can be
re-authored from the source; only each file's exact obligation count is
gone with it.

**What this session did.** Re-authored the suites-then-proofs trio —
`proofs/verus/direct_calls.rs` (19), `cat_read.rs` (18), `grep_o.rs` (19) —
against the live sources, re-registered them in `harness/verus-gate.sh` at
the new counts, and wrote their README sections. The originals' counts were
7/11/10; they are different models now, and the inventory says so rather
than pretending the numbers are the old ones. The re-authoring also found a
product defect (the `direct_calls` header's "refuse on redefinition" rule is
not implemented, and the C renderer cannot emit a redefined shell function
at all) — recorded as `BUGS_FOUND.md` 11a, open.

**Still to recover** (same method, one model per session, each needing its
own source read): the other 14. Their transform sources, their VERUS.md
rows (obligation counts still printed there) and — for the ten with a
`*_sync.txt` baseline — their committed baselines all survive, so a model
that reproduces its documented count can be checked against the baseline
the gate already knows.

### 2026-10-30 — `unreachable-after-exit`: shared verdict widened to every all-paths form; the emitted-rust unreachable class hits zero

**What the emitted-Rust census showed.** Re-rendering all 563 examples
through the current CLI and linting each with default rustc lints left
exactly 5 warnings in one class — `unreachable expression` ×3
(`061_test_local_names_preserved`, the function value tail behind an
exhaustive dispatch) and `unreachable statement` ×2
(`parse-exit-brace-question`, a printf after `exit ${?}`;
`parse-break-or`, the short-circuit store after `break || exit 1`). Two
root causes: `terminates_list` — the shared predicate rust_backend asks
before emitting anything rustc would flag — only knew the
`IrStmt::Exit`/`Return`/`Break` NODES and `while true`, while the
frontends spell the same control as CALLS (`builtin("exit", …)`,
`Call("break")`), and neither the predicate nor the shIR prune fold
understood a dispatch where every path transfers control.

**The widening (one predicate, two consumers).** `terminates_list`
(`transforms/unreachable_after_exit.rs`) now also answers for: the
command-call spellings of `exit`/`break`/`continue`/`return` (`Expr`,
`Exec`, and the `builtin`/`exec` word dispatch), an `if` whose every arm
ends in a terminator WITH a non-empty `else`, a `case` whose every
clause ends in a terminator WITH a `*` catch-all (a quoted `"*"` is a
literal asterisk and does not count), a grouping `Block` whose list
terminates, and expression-level divergence (`expr_diverges`): a
control call, the left operand of `&&`/`||`, the first operand of the
lifted `and`/`or` call, an `Arrow` block. The same file's `pass` — the
shIR fold every backend runs — now prunes with that verdict instead of
its own narrower node check, tracking `in_loop` (loop bodies get it,
straight-line grouping propagates it, subshell/background/function
bodies reset it) and deciding AFTER recursion so prunes cascade
bottom-up in one walk. `contains_break` gained the matching expression
descent — without the `Expr` arm, `while true; do break || exit 1;
done` looked like it could never fall through and its after-loop tail
would have been wrongly pruned. One fold is new: a statement-level
`a || b` / `a && b` whose left operand never yields keeps only the left
operand's effects and drops the right's scaffolding (the renderers all
accept `Expr(Call("break"))` standalone — verified across perl, C, go,
estree, python, java). The `Function` arm also stops wiping
`named_blocks` (it destructured with `..` and rebuilt with an empty
vec).

**Result.** The unreachable class is 0 (corpus −3.4 KB of dead code);
0 rustc errors across 563 files. 11 new in-file tests pin each arm,
including the negative ones (no `else` ⇒ keep, no `*` ⇒ keep,
`break` outside a loop ⇒ keep the rhs).

**Gates.** `./fail` 0, `harness/fail-rs` 0, `./fail-estree` 0,
`./fail-shir` 0. `harness/py-rust-gate.sh` reports 3 FAIL — verified
pre-existing, not this change: t104/t82 render byte-identical with
`unreachable-after-exit` excluded from `SH2_TRANSFORMS`, and t87's IR
contains no exit/break/case/if at all (pure arithmetic). `cargo test
--lib` is 46 red both with and without this change (A/B on the one
file, failure-name sets identical — zero introduced, zero fixed); my
11 tests pass. The Core worker was healthy throughout (gate GREEN,
0 A1 violations, 555 probed; its `lib_fails=19` baseline is measured in
its own subcheckout, hence the A/B above rather than a count compare).

### 2026-11-04 — `output-line-fold`: the trailing newline becomes an shIR fact, so every backend reaches for its line-print primitive

**The shape.** A heredoc, a constant `printf 'a\nb\n'` and a folded
`echo` all lower to `Output { value: Str("a\nb\n"), newline: false }` —
the newline is inside the TEXT, and the node's `newline` flag is unused.
Every renderer therefore takes its RAW-write arm and spells the newline in
the literal: `fmt.Print("a\nb\n")`, `print("a\nb\n", end="")`,
`System.out.print("a\nb\n")`, `print "a\nb\n";`. Bytes correct, idiom
wrong: each target has a line primitive (`fmt.Println`, `print(x)` with
python's default `end="\n"`, `System.out.println`, `say`, `println!`).

**Why it was one backend's problem.** The Rust renderer grew a text
peephole for it (`println_for_trailing_newline`), so `051_primes.rs` has
read `println!("a\nb")` for months while Go/Python/Java paid the raw
write on the same input. That is the per-renderer re-derivation the shared
pipeline exists to retire.

**The transform.** `shir_passes::echo_fold::OutputLineFold` (registered as
`output-line-fold` in `transforms::all()`, and run as `EchoFold`'s pass 3
so the two renderers that fold locally — rust, C — get it without a second
registration). It rewrites `Output{newline:false, target:None}` whose value
is a `Str` — or an `Interpolate` whose LAST part is a literal — ending in
`\n`, into `Output{newline:true}` with that one newline removed (an emptied
tail `Lit` is dropped). Soundness: `newline:true` is "the value's bytes,
then one `\n`" in every renderer, so the two spellings print identical
bytes; a `target`-bearing Output is left alone (filehandle line discipline
is not a text fact), and a value ending in an EXPANSION is left alone (its
trailing bytes are not known until runtime). Idempotent, so more than one
entry point is safe. `SH2_NO_OUTPUT_LINE_FOLD=1` is the A/B switch (the
`EchoFold` tail bypasses the `SH2_TRANSFORMS` registry gate, so the bisect
machinery needs one switch covering both).

**Measured, 563-example corpus, via the switch.** Raw-write call sites
spelling the newline inside a literal:

| shape | fold off | fold on |
|---|---:|---:|
| `fmt.Print(` (go) | 147 | 49 |
| `print(…, end="")` (python) | 122 | 22 |
| `System.out.print(` (java) | 97 | 17 |
| `print!(` (rust) | 173 | 173 |

278 sites moved onto a line primitive across the three backends; Rust is
unchanged, which is the check that the shared fold subsumes (not
duplicates) its renderer peephole — that pass stays as the backstop for
`Output` nodes produced during rendering.

**Gates.** `./fail` 563/563, `./fail-estree` 563/563 (100.0%).
`harness/py-rust-gate.sh` 99/103 (2 known-gap, 2 FAIL — t104_float32 and
t87_bignum report the same got/want with `SH2_NO_OUTPUT_LINE_FOLD=1`, and
their emitted Rust is byte-identical either way: pre-existing, and they
pass when run alone, so the pair is an ordering/state artifact of the
full-corpus run, not a codegen difference). `cargo test --lib`: 67 red
with the fold on, 72 with it off; the five that only fail when off are my
own new tests asserting the fold fires. Failure-name sets are otherwise
identical — **zero introduced**, and the 67 are the shared-core WIP the
Core worker owns (estree 23, rust_backend 13, c_backend 10, shir 5,
fish 5, …), none in a file this round touched. Rust lint census over the
emitted corpus: 8 rustc warnings in 563 files, unchanged by this round.

**Core worker.** Healthy throughout — supervisor alive, gate GREEN
(1,032 greens), A1-native invariant 0 violations over 555 probes, no
`core-requests/sleeping-*` marker. Nothing to fix.

### 2026-11-05 — `heredoc-print`: one shIR fold retires the per-backend `cat <<EOF` arms; the arithmetic test operand stops round-tripping through a String

**What the emitted-Rust census showed.** Re-emitting all 563 examples to
Rust and linting each with default rustc lints leaves **12 warnings in
5 files**, and none of them is a lowering failure: 2 are
`value assigned is never read` (`arith_postfix_status`,
`parse_longoption_with_dollar` — the store-then-discard class `dead-store-elim`
already owns) and the rest are locals left unused by a nested heredoc
that only exists as TEXT inside a `$( … )` interpolation
(`058_advanced_bash_idioms`: `user`/`host`/`port`, plus one `IFS` and one
`var`). The census is now small enough that reading it is the useful
step, so this round took the two largest *shapes* it showed rather than
chasing the last warning:

1. `let __v = "1".to_string(); *__SH_RET.lock().unwrap() = __v.clone(); __SH_RC.store(__sh_ret_rc(&__v), …); return;`
   — the clone is unobservable: the rc is computed from a borrow, and
   nothing reads `__v` afterwards. Now the value is MOVED into the cell
   (`__SH_RC.store(__sh_ret_rc(&__v), …); *__SH_RET.lock().unwrap() = __v;`).
   One String alloc per legacy-convention `return`, at 8 return sites in
   the corpus; the ordering that the comment above the emit site demands
   (evaluate the value BEFORE locking `__SH_RET`, so a recursive
   fnValue call cannot re-lock a held Mutex) is unchanged — only the
   store moved after the rc computation.
2. `[ $((n % i)) -eq 0 ]` rendered as
   `(… % …).to_string().trim().parse::<i64>().unwrap_or(0) == 0`: an i64
   going to a String and straight back, inside a NUMERIC operator. The
   test-operand renderer now recognises a whole-word `$(( … ))`
   (`whole_arith_body`) and hands back the numeric form with `num: true`,
   so the compare reads `(… % …) == 0`. The arith renderer is the same
   one the string path used, so the value, the `__SH_ARITH_ERR`
   bookkeeping and the `$(cmd)` fallback are all identical: only the
   round-trip disappears. A body the arith parser cannot see still falls
   through to the string spelling.

**The shIR→shIR fold (the part other backends get).** `cat <<EOF … EOF`
written straight to stdout was re-derived by every renderer: Java forked a
`sh` (`shRun("cat" + " <<'SH2EOF'…")`), Rust forked `cat`
(`__sh_spawn("'cat'", Some(body.as_bytes()))` — with a
`.to_string().as_bytes()` alloc), fish forked `cat` for its own
`printf '%s\n' …`, and Python/Go each had a private arm for it. The new
`transforms::heredoc_print` (`heredoc-print` in the registry) folds the
statement to the `Output { value: Str(body), newline: false }` node every
backend already prints natively, and `output-line-fold` (the next pass)
moves the body's own trailing newline into the flag so the target's line
primitive is used.

*Soundness.* `cat` with no operands copies stdin to stdout byte-for-byte
and exits 0; the fold requires exactly ONE redirect spec, on fd 0, with
`heredoc`/`heredoc-tabs` mode, and the inner list to be the single bare
`cat` word (so `cat -A`, `cat file <<EOF` and `cat <<EOF | grep` all
refuse — a measured case in `063_hard_to_parse` and
`064_hard_to_generate`). Expansion: the parser keeps an *interpolating*
body as a plain `Str` with no `Interpolate`, so a body containing `$`, a
backtick or a backslash is left alone — the backends that fork a shell get
that case right today and the ones that print the string do not. Sinks:
the fold descends only through pure control flow (`if`/loop/`case`/`try`/
grouping `Block`/function body) and never into a `Pipeline` stage, a
`Background` job, a `Subshell` group, a redirect body or an expression —
inside those, stdout is swapped for a sink only the word-printing helpers
write into, and a native `Output` would escape it. That narrower walk is
deliberate (`echo_fold::child_lists_mut` is the wrong one here) and
`does_not_descend_into_a_pipeline_stage` pins it.

**Measured, 563-example corpus, via the `SH2_TRANSFORMS` registry gate
(the seed list is every transform but `heredoc-print`, so no rebuild):**

| backend | shape | fold off | fold on |
|---|---|---:|---:|
| fish | `printf … \| cat` | 41 | 31 |
| java | `shRun("cat" + " <<'SH2EOF'…")` | 28 | 18 |
| rust | `__sh_spawn("'cat'", Some(…as_bytes()))` | 31 | 20 |
| python | (its own arm already printed natively) | — | — |

32 process forks retired over the three backends, and the go sites move
from `fmt.Print("…\n")` to `fmt.Println(…)` via `output-line-fold`. On
`007_cat_EOF` the three spellings are now `System.out.println`,
`println!`, and a bare `printf`.

**Rust-side totals, 22:23 snapshot → now** (same 563 files, default
lints): `to_string().trim().parse::<i64>()` 6 → 5, `__v.clone()` in a
return 34 → 26 (8 moved), `__sh_print_words` call sites 377 → 147, total
emitted bytes 1,314,778 → 1,275,073 (−3.0%).

**Gates.** `./fail-rs` **556/556 pass, 0 fail** (7 skips, 563 total) —
the Rust equivalence gate is fully green. `./fail` is **560/563** with the
same 3 reds it had before this round (`063_hard_to_parse`,
`064_11_complex_test_expressions`, `064_hard_to_generate`) — two of them
have no bare heredoc (a *pipeline* and a *redirect target*, both refused
by design) and the third fails in the perl backend's `=~` rendering, a
file this round never touched; `typeset-cmdsub` flaked once and passes on
the rerun. estree is 560/563 with
`backslash-gt-test`, `parse-default-value-no-colon`,
`parse-default-value-plain-dash`. `harness/py-rust-gate.sh` 97/103:
t104_float32/t87_bignum are the documented pair, and t91/t93 fail on
`num_traits required to be available in rlib format` — the rlib-probe
flake the script's own header documents, not a codegen difference.
`cargo test --lib` **1811 pass / 58 fail**; the only two that are not in
the old baseline are `c_backend::tests::let_compare_refuses_{zero,dynamic}_divisor`,
which are the C worker's in-flight divisor-guard WIP inside
`c_backend.rs` (the test and the `(0 == 0 ? 0 : …)` text are both in that
file's uncommitted diff — this round touched no C code).

**Core worker.** Healthy throughout: supervisor alive (pid from
`loop-core-worker.pid`), last gate **GREEN** (A1 native + estree corpus +
lib tests), no `core-requests/sleeping-*` marker. Nothing to fix.

### 2026-11-09 — the Verus gate finally checks the tree that ships: 38 models and 21 sync baselines land, and four drift pins are settled

The gate named 38 models the tree did not contain. In a clean checkout
`check_model`'s existence pre-check answered for each of them, so a log skim
showed `model file absent` — worth nothing, and indistinguishable from a
failed proof. All 38 verify green at **exactly** their asserted counts
(`--triggers-mode silent`, the per-entry `--rlimit`, 0 errors, rc=0), so the
fix was to commit them, not to re-pin them. The 21 sync baselines whose
entries had been `SKIP`ping as "Tier 1 pending, NOT green-by-absence" are
generated from HEAD source with every pin mapped and every mapped test
executed PASS.

Four expectations were **not** lowered and four were:

- `c_sparse_array` (45) and `c_assoc_array` (54): the increments the gate was
  already demanding are pure additions (837 lines across the three C array /
  decl models) that verify at those counts, so they are landed.
- `c_decl_coverage` is pinned 54 → **51**: its working copy's new pin maps to
  `expr_position_assign_routes_to_the_variable`, a test that is also still
  uncommitted, so the extractor FATALs at HEAD. The model and that test have
  to land together; the owner re-blesses then.
- `c_join_ifs` is pinned 104 → **73** (committed model; the working copy is
  108 with one failing postcondition, `w3_hole_skip_is_load_bearing`), so the
  line asserts what the tree checks instead of what a branch will.
- `test_folds` was not a generator bug: the model and its baseline were
  asserted by the gate but never committed (now in-tree at 7/0, manifest
  byte-identical), and the committed trunk did not build at all —
  `c_backend.rs` called `NumericObserved::arrays()` which the committed
  `numeric_observed.rs` never had. Restoring that four-line getter took
  `cargo build --lib` from E0599/E0308 to 0 errors and unblocked every
  `cargo test --lib`-based sync entry.

Isabelle: `BigIntRange` (and its child `IntervalFloor`) build green from
source with `quick_and_dirty=false` (58 s / 5:16). The `OF: no unifiers` was
the **lemma shape**, not the goal — `mod_pos_bounds`/`mod_neg_bounds` carried
their guard in the conclusion (`shows … ⟹ …`), so a call site's third `OF`
fact had no premise; the guards are now real assumptions and the goals speak
about `v1 mod v2`, transferred by `linarith` under `ev`. The stale "not in the
default build" note in `proofs/ROOT` is gone; `harness/transform-proofs.sh`
reports **8 checked-and-built, 0 stated-only, 0 failed**.

**Gate on the committed tree** (clean worktree, pinned Verus, workerd-free):
**123 passed, 0 failed, 4 skipped, 2 retired records**, exit 0. The four skips
are extractors that *refuse* rather than skip — `arr_load_fwd`,
`exec_call_fold`, `interp_lit_merge` (every mapped test MISSING: the pin_map
names tests the suites no longer contain) and `strip`
(`pin_continue_verdict` has no pin_map entry) — and each needs its owner's
mapping, not a guessed one. (The pass below fixes `strip` and renames the
other three: they were never test renames.)

Not pushed: the work is committed on `background-decide-verdict`
(`331c53a1a`, `dc8ec80ce`, `f60377733`, `da7ec0979`) and in the workspace
gitlink, so a fresh clone of `origin` still sees the old state.

A follow-up pass closed the last four sync skips. `strip` got its baseline:
`pin_continue_verdict` was the one pin without a pin_map entry, and since
`src/shir_passes/strip.rs` tests the splice that consumes the verdict rather
than the predicate, the entry is UNMIRRORED with the reason beside it instead
of a guessed test name.

The other three were not test renames at all. `src/transforms/arr_load_fwd.rs`,
`exec_call_fold.rs` and `interp_lit_merge.rs` are **tracked files that no `mod`
declaration reaches** — `src/transforms.rs` declares 71 modules and none of
them — so their `#[test]`s never compile, which is exactly why every mapped pin
reported `MISSING (renamed? filtered?)`: the tests are in the file, and no
filter can reach a module that is not in the crate. (`builtin_lift.rs` is
tracked and dead in the same way.) The extractor now names the cause
(`is not a module of the crate`), `check_sync_cov` runs the generator *before*
consulting the baseline — the ordering fix the legacy driver already carried,
because skipping on a missing file first made a dead extractor and an unwritten
baseline indistinguishable — and the gate counts those entries as SKIPs that
print the reason rather than reds that hide behind "generator errored".

Wiring the modules in is **not** a one-line change: declaring them fails to
compile against the current crate — E0603 for four private helpers
(`census`, `exported_names`, `is_shell_implicit`, `expr_pure`) and E0432 for
`super::READ_ONLY_CALLS` and `string_accumulator::{callee_write_sets, Cw}`.
They are stale copies of an older API, so the fork is a port or a retirement
(the one `interval.rs` took). `builtin_lift.rs` is tracked and unreachable in
the same way and also fails to compile when declared (E0631); it has no model
at all, so it is simply dead weight. Porting/retiring is the owners' call.

**Gate after this pass: 124 passed, 0 failed, 3 skipped (unwired modules), 2
retired records, exit 0.** Still unpushed.

**Follow-up: the four unreachable transform modules (2026-11-09).** Declaring
each one settled it, and the split is not what the skip implied:

- `exec_call_fold` and `interp_lit_merge` **port**: they compile against the
  current crate and their suites pass (4 and 7 tests). The `mod` line was the
  whole gap — the 2026-10-29 commit that added the files claims the
  `transforms.rs` wiring was "present but files absent", and that commit never
  touches `transforms.rs`. Both are modules now; every pin executes and their
  sync baselines are committed. Neither is registered with a backend, so this
  proves the pass, not a pipeline that runs it.
- `arr_load_fwd` **cannot** be ported: it imports `super::READ_ONLY_CALLS` and
  `string_accumulator::{callee_write_sets, Cw}`, none of which exist anywhere
  outside that file, and calls four helpers the crate has made private
  (E0432/E0603). Deleted; the model is banner-marked and moved to
  `RETIRED_MODELS` — verified as a record, outside every total, like
  `interval.rs`.
- `builtin_lift` is `WITHDRAWN` in
  `core-requests/transforms/rejected/builtin-lift/WITHDRAWN` ("superseded by
  the landed builtin transform") and fails to compile when declared (E0631);
  deleted, it had no model.

**Verus gate after this: 125 passed, 0 failed, 0 skipped, 3 retired records,
exit 0** — every entry the gate names now either runs or is an explicitly
retired record. Still unpushed.

**Isabelle: two orphan theory layers now build, the third is not a proof yet
(2026-11-09).** `proofs/ArithIdentity/ArithWidth.thy` and `ArithDec.thy` were
untracked and referenced by no `ROOT`, while `C_UB_PROOF.md` §14b cited
`ArithDec` as the mechanization of the C renderers' hand-rolled itoas — the
Isabelle twin of the 38 uncommitted Verus models. Isabelle refuses two sessions
sharing one directory ("Duplicate use of directory"), so both ride in the
`ArithIdentity` session's `theories` list, in dependency order: 4.6 s / 2.2 s /
31.2 s, the session green under `quick_and_dirty = false`, and now rebuilt by
`harness/transform-proofs.sh` on every run.

`proofs/Maskable/Maskable.thy` (1163 lines, mirroring
`src/shir_passes/maskable.rs` over `BigIntRange`) was the third orphan and
**does not build**: `by` fails at line 251, `show` at 621 ("Unbound schematic
variable: ?case"), `by` at 800 on a `<= a` goal. Declaring its session would
have turned the gate red for everyone, so it stays unregistered; the attempt
and the three failures are recorded in `proofs/ROOT`, and the file remains
untracked WIP.

**`type_query`: the builtin table is measured now (2026-11-09).** The Verus
model takes the builtin table as a parameter, so it could not notice that the
constant had drifted: `compgen -A builtin` on this bash lists **61** names and
the table had 58, missing the special builtins `.`, `:` and `break` — which
`type` does answer "a shell builtin" for, so `type :` was needlessly refused
(sound: refuse > guess, but a gap). The count assertion is replaced by
`builtin_table_matches_compgen`, which asserts equality with bash's own answer
on the bash that runs the suite (`SH2_BASH` overrides it), and the surviving pin
keeps what must hold whatever shell answers — no externals, no duplicates.
Result: 61 == 61, 9/9 tests green in a clean worktree, Verus model unchanged at
17/0, and no corpus example spells those three names, so emitted output cannot
move.

**`i32-provable` has a reader — and the measurement says it is inert
(2026-11-09).** The verdict was registered and `is_i32` was called from
nothing in `src/`: the exact shape `interval.rs` shipped in. So both halves
landed this time. **Call site:** `c_backend.rs`'s `tiered_i64_expr` takes the
exact-width form for a marked subtree — a bare `long long` C expression with
no `__builtin_{add,sub,mul}_overflow` guard — and keeps every check otherwise;
the predicate is a VALUE (`exact_i32_bound`), because a store expression's
subtrees have no statement index to key `is_i32` by. **Proof:**
`proofs/verus/i32_emit.rs` (20 verified, 0 errors, gated) shows the estimator
puts EVERY node of a marked tree inside i32 — not just the root, and per-node
rather than under the root's bound, because `2 * 0` has a root bound smaller
than an operand — so the guard the fast path drops is dead; that
`plain_i64_expr` has an arm for every markable shape (the fast path cannot
fall through and lose a tiered mirror); that the decision is total (unmarked ⇒
every check retained: refusing costs the narrow form, never correctness); and
the leaf-only mutant that marks `2^29·2^29·2^29 = 2^87`.
**Measured reach — the honest half:** 12 marked statements across 10 of 896
corpus examples (1.3%), and the fast path fires on **0** of them, because the
verdict's domain is literal-only (`arith_abs_bound` refuses every variable
read) while `tiered_i64_expr` is only reached by a tiered store that needs a
growing var in the tree. A literal-only tree is a compile-time constant to
every backend, so today this constrains emitted text, not emitted behaviour.
The C gate re-run over the 10 marked files adds no red (the 2 reds on the live
tree reproduce with the seam disabled: pre-existing, from other in-flight
work). **The prerequisite is named in the transform's own `prereqs:` line:**
the escape-classes interval refinement for variable reads. Until it lands,
any i32 consumer — C, Go, Rust or GLSL — is decorative, and this one is
labelled as such in `VERUS.md` and in the model's header rather than counted
as live coverage.

**`background-decide`: the fixed classifier is proved, not just preferred
(2026-11-09).** The model had a refutation (`shipped_check_is_unsound`: the old
`collect` compares read/assign sets in no order, so
`if [ -n "$x" ]; then x=1; echo 7; fi` was classified THREAD and would print
nothing on a fresh runtime) and a soundness theorem for an ordered RULE — but
nothing connecting the rule to the code that decides. So the replacement
`walk_self_contained` / `is_thread_body` was a verdict with no theorem and no
reader, i.e. the same shape as `interval.rs` with better comments.
Now: `walk_ok_implies_intended` bridges the shipped walk to the sound rule —
the walk's post-set keeps straight-line binds only (a branch may not run), the
rule's also keeps what both arms bind, and `walk_ok_mono` carries that
monotonicity through `Seq`; `classify_thread_sound` composes the bridge with
`thread_equals_fork` for THREAD ⇒ identical bytes; `route_thread_is_sound`
does the same over the shipped PREDICATE, assuming only `classify`'s own
insertion rule. The refusal direction is proved, not promised:
`unclassified_stays_fork` / `absent_table_routes_fork` (no table — transform
absent or cleared — or no entry ⇒ FORK, so a consumer can never be handed a
guess) and `side_effect_stays_fork` (a file write or control transfer is never
accepted, hence can never enter the table). 27 verified, 0 errors (was 12);
the gate entry moved 12→27. `is_thread_body` still has zero call sites, so
this is a sound verdict ready to consume — the wiring, not the proof, is the
remaining work, and the model header and VERUS.md say so instead of implying
live coverage. Also fixed the module's stale `invariant:` line (still claimed
pointer-keyed verdicts, three days after the fix that made them body-text
keyed).

**The C array cap: proved, guarded, and counted (2026-11-09).** C_UB_PROOF.md
§2b's "array_caps is the unproven bound" is now two things instead of one
assumption. **A real defect fell out of writing the obligation:** the `"$@"`
spread guard in `emit_set_array` compared the write count against `ARR_CAP`
(the 1024 ceiling) instead of the array's DECLARED capacity, so a proof-sized
table (`a[3]`) would have admitted four stores and run past its end — the
"Decl and every fixed guard go through here so they always agree" invariant in
`array_cap`'s own doc, violated by one call site. The guard now passes `acap`.
No corpus example reaches that branch (a spread is routed to the growable vec),
so no emitted program changed: it was latent, not live. **The proof**
(`proofs/verus/c_arr_cap.rs`, 13 verified, 0 errors, gated) shows a fixed table
is at least as large as the literal bulk written into it and covers the whole
census `need` (`max(max_reset, lit_index_max, counter_index_max) + appends`);
that an array whose need reaches ARR_CAP is never a fixed table (the measured
1500-element case renders as `char **a` + `_sh_grow_str`); that the one bypass
(`counter_index_max > 0`) only ever enlarges a proven table; and that the write
guard admits exactly the in-bounds writes — with the pre-fix `> ARR_CAP` guard
refuted as the negative control. **The assumption is observable:** a
`debug_assert!` in `emit_set_array` refuses to emit a bulk past the declared
cap (exempt: vecs, runtime spreads, assoc stores), and
`harness/c-arr-cap-scan.sh` renders the example set through a debug build and
reports the numbers — 555 of 563 examples rendered, 72 fixed tables, largest
bulk 5, largest capacity below the ceiling 10, **0** over-cap and **0**
assertion trips. The 41 tables AT the ceiling are the deliberate unproven
backstop (assoc k/v, fn-return storage) whose stores carry the exit-127 guard,
i.e. the "or the guard engages" half. Pre-existing test state recorded rather
than papered over: 10 `c_backend::tests` fail identically at HEAD and with the
patch (verified by diffing the failure sets), so none of them are this change.

**Perl renderer escaping: the one backend with no proof now has one
(2026-11-09).** `src/perl_backend.rs` was the only backend with zero proof
coverage, and the funnel it needed one for is `Render::perl_str`: every
literal `Str` passes through it into a Perl DOUBLE-QUOTED context, where `$`
interpolates scalars, `@` interpolates arrays and `\` introduces escapes — so
a wrong arm does not crash, it silently emits a *different string*. That is
the class behind this session's `${x}` splice failures (`"${x}"` in shell text
must stay the four characters `${x}`, not expand a Perl variable).

The model (`proofs/verus/perl_str_escape.rs`, 17 verified, 0 errors, gated) is
two halves and one bridge. The encoder is `perl_str`'s arm table verbatim. The
decoder is Perl's double-quote parser written as a **one-character-per-step
state machine** (normal / after-backslash / expecting `{` / hex digits with an
accumulator), which is why termination is structural: every recursive call
consumes exactly one character, so there is no length arithmetic to justify —
the first draft recursed on `s.skip(n)` with `n` from a lookahead and could not
prove termination at all. The bridge is the part that matters: `roundtrip`
proves `eval_literal(lit(s)) = Some(s)` for every `s` by composing
`esc_char_step` (each `esc_char(c)` decodes to `c` **and consumes exactly its
own characters**, so the parser resumes on the next character's boundary) and
`hex_walk` (the `\x{h}` digits advance the accumulator). A per-arm table alone
does not give that: concatenation is where a dangling `\` or an unterminated
`{` would eat the next character, so the stream property is the claim and the
per-character lemma is what makes it composable. The proof needed one
non-obvious fact — `(a + b).skip(n) = a.skip(n) + b` (`skip_add`, by sequence
extensionality) — because otherwise the SMT cannot keep the parser anchored on
a literal prefix and every step's tail is opaque.

Non-vacuous: `dollar_is_load_bearing` (drop the `$` arm and the dollar stays
bare), `slash_is_load_bearing` (drop the `\\` arm and a literal backslash
before `n` re-parses as a NEWLINE — the `printf '%s\n'` class), and
`env_dependence_is_the_hazard` / `braced_substitution_is_the_same_hazard`, a
deliberately small substitution model showing that a bare `$x` or `${x}` makes
the emitted text's value depend on the environment, i.e. it stopped being a
literal. `splice_witness_round_trips` is the shipped encoder's answer.

**The consumer is a differential test, not a transcript.**
`perl_backend::escaping_tests` runs the REAL `perl` over 169 literals — the
empty string, every ASCII code point on its own, and the `${x}` / `$#x` /
`@ARGV` / `@{x}` / backslash / quote / `\x41`-looking / control-char shapes —
hex-dumps each decoded value and compares it to the input bytes. A second test
gives the harness teeth: `naive_wrapping_is_detected` shows the naively-wrapped
`${x}` literal evaluates to `ZZ` under `my $x='ZZ'` while the shipped escaper
stays `${x}`, so a green first test cannot be vacuous. Both pass on the live
tree. There is no `*_sync.txt` baseline: the differential test is the tie to
the source, and it fails if `perl_str` changes without the model.

Load-bearing, measured on copies of the model: dropping the `$` arm is
15v/2e, dropping the `\\` arm is 15v/2e, emitting a raw control char
instead of `\x{h}` is 16v/1e, and a DECODER mutant (the closing-quote arm
emits a quote instead of ending the literal) is 15v/2e — the last one
matters most, because a decoder written to mirror the encoder would have
kept the round trip green.

**The ESTree op contract is now checked, not assumed (2026-11-09).**
`sh2runtime` is coupled to the transpiler ONLY by the ESTree JSON contract, and
`fail-estree` proves the two agree on *behaviour over the corpus* — 563 examples,
each rendered, executed and diffed. It cannot see a name no example reaches, and
no compile step sees one either: the emitter writes `sh2.<op>(…)` as an ordinary
`MemberExpression` call, so a rename on either side is a `TypeError` at run time
with nothing red anywhere. Four writers define that surface and had no
cross-check: the emitter (`src/shir.rs`, `src/estree.rs`), the reference runtime
(`harness/sh2-namespace.mjs`), the structural gate's hand-maintained
`%whitelist` (`harness/estree_gate.pl`), and the documented polyfill mirror
(`runtime/README.md` §1 → `polyfills.sh`/`polyfills.c`).

`harness/estree-contract.mjs` closes it in four hard-failure sections, all over
the same 563-artifact render (`OTRANSPILERL_BIN`, ~6 s, 74 distinct ops):
**A** every emitted callee path resolves on the exported `sh2`, to a function or
to a prototype method of the initialized value, and the maximum emitted argc
does not exceed the declared arity; **B** every `%whitelist` name exists (a
function, or one of the runtime's state containers, which the gate's separate
state branch legitimately admits); **C** op → {argc set, static per-position
argument kinds} equals the committed `harness/estree-contract.json`, so a new op
or a changed argument shape needs a deliberate `--update`; **D** every polyfill
function the README advertises exists in both mirrors.

It found a real gap on its first run: `IrStmt::Die` emits `sh2.die`
(`shir.rs` — "the runtime catches it"), reachable through
`src/transforms/stray_reserved_word.rs` and JSON ingest, and the runtime had only
`warn`. No corpus example dies, which is exactly why the corpus never caught it.
The fix is the op, not the gate entry: `sh2.die(v)` throws `Error(String(v))`
(keeping it catchable by an enclosing recover, per the emitter's comment), so an
uncaught die now prints the program's own message and exits nonzero instead of
`sh2.die is not a function`. Measured through `estree-runner.mjs` on a hand-built
program: `Error: boom` on stderr, rc=1. That gap also fixed the check's shape —
section B exists because an op the corpus does not reach is invisible to A.

Non-vacuous, three ways. Six `--selftest` controls synthesise each failure from
a fake surface (missing op, over-arity, `sh2._r` value-root method resolution,
unknown whitelist name, baseline drift, missing advertised polyfill). Then three
mutants on real copies of the namespace via `--namespace`: renaming `builtin`
(the most-emitted op) fails A **and** B; narrowing it to one parameter fails A
with `emitter passes 4 argument(s), implementation takes at most 1`; deleting
`die` fails B — the corpus-only check would have stayed green through all three.

Deliberate limits, so the claim is not read as wider than it is. Arity is an
UPPER bound only: the runtime's ops take optional trailing parameters without
defaults (`pipeline(stages, fdTargets)`), so a minimum would be invented; the
per-position argument KINDS are snapshotted instead, which is the drift signal
that a minimum would have given. `sh2._r` is declared (`DECLARED_VALUE_TYPES`),
the one field assigned at run time rather than in the object literal. The check
proves *names, arity and argument shape*, never semantics — that stays with
`fail-estree`. Dead ops are invisible by construction: an op the runtime has and
the emitter never produces is not flagged (only the whitelist's dead entries
are). And the seam side is only checked against the README's advertised
inventory; `die` is in the namespace, not yet in the C polyfills.

The consumer is the gate itself: `./fail-estree` runs the contract against its
PINNED binary before the corpus loop, prints the four sections, and in `--gate`
mode aborts there — every estree cell would be suspect and 563 per-file failures
would hide the one-line cause. Measured: `--gate 001_simple` green with the
pre-flight, and with the baseline removed it prints `ESTREE CONTRACT: FAIL …
aborting before the corpus run`, rc=1, no corpus summary line.

**The AST gate's falsifier was dead, and the `$$` case is now proved at the
tokenizer level (2026-11-09, parser/AST-gate workstream).** The fix-and-prove
list item 8 asked for one parser distinguishability case retired *honestly* —
"stating it as a tokenizer-level property, with the gate as the falsifier" —
rather than blessed. Investigating that turned up the reason the case had
looked dormant: **`harness/check_ast.pl` could not run its AST half at all.**
Its `dump_ast` bin (parse + one `WORD:` line per argument) went with the
debashc dump-bins layer in `4d5d2d2c6` and was never restored, and
`sh2perl/Cargo.toml` declares no such target, so `cargo build --bin dump_ast`
fails and the script dies at its build step — **all seven `ast_*` cases,
including both `$$` ones, were unrun**, not passing. That is the more serious
finding of the two: a gate whose subject cannot be exercised is indistinguishable
from a green gate in a log skim, and `check_ast.pl`'s policy ("KNOWN AST GAP
counts as a failure") had nothing to count. `sh2perl/src/bin/dump_ast.rs` is
restored with the same contract; `perl harness/check_ast.pl` then reports
**22 passed, 0 FAILED (0 unexpected, 0 known AST gaps), 0 resolved, exit 0** —
the `$$` pair and its redirect sibling pass, so the parser gap the script's own
comments describe was closed by the earlier `$`-fusion work and only the
falsifier was missing.

The proof is the *rule* the gate is implicitly testing, in
`sh2perl/proofs/verus/word_boundary.rs` (**14 verified, 0 errors**, registered
in `harness/verus-gate.sh`). A word is bounded by exactly two mechanisms in
`src/parser/words.rs`: **G1** the combine loop does not continue over a
whitespace token, and **G2** `merge_contiguous_quoted_fragments` merges a
`$`-expansion only at byte-adjacency. From those, `starts_word` and `words`
(the argument count — the quantity `dump_ast`'s `WORD:` lines report) give
**1 word for `echo x$$` and 2 for `echo x $$`**, plus each mechanism on its own
as a lemma and the value-preservation of both halves (the fused word is `x`
then the pid; the split keeps the pid whole). The two controls are proved
*facts about the mutant rules*, which is what makes them bite: drop G1 and both
sources yield one word; restore the old "always cut `$$` off the word"
behaviour and both yield two — indistinguishable either way. Measured on
copies: drop-G1 fails `spaced_is_two_words` (`1 == 2` at the claim),
always-split fails `glued_is_one_word` (`2 == 1`). The tie from model to source
is `parser::words::word_boundary_tests` (3 tests, green), which pins the same
counts on the live AST — so the property is enforced by `cargo test` even if
the bin goes missing again.

**The text-ops composition slice is proved (2026-11-11).**
`sh2perl/docs/fm/TextOps/ShIR_TextOps_Compose.thy` (429 lines, new; fourth
theory of the `TextOps` session) closes the gap the fm README listed first:
`wc -w`'s as-built lowering is `ArrayLen(Split(...))`, and with `Split`'s
field list (`field_scan`/`split_ws`), `ArrayLen` as `length`, and the
look-behind `ws_scan`, the theorem `array_len_split_is_word_count` derives
the count from Base's `word_count` — the obligation is now a corollary, not
a second independent model, and `lowered_wc_w_via_split` states it at the
node. Two negative controls keep the drop-empty step honest (an unfiltered
split of `" a"` returns 2 fields for 1 word; the filtered idiom returns 1).

`cut` is a **different** split on purpose: `split_on` on a literal delimiter
KEEPS empty fields (`a,,b` with `-d, -f2` is the empty string,
`cut_keeps_empty_field`; `ws_split_would_lose_empty_field` makes the
distinction explicit), and `FieldExtract` is modelled as "the N-th field, or
nothing" (`field_or_empty_out_of_range`). Recorded as open targets, never
`sorry`: the engines' `/\\s+/` is not POSIX space (`nbsp_is_not_posix_space`,
`nbsp_is_not_ascii`) and is not modelled; `-fN-M` ranges, `--complement` and
`--output-delimiter` splicing are unmodelled. `spec:` lines now point at the
lemmas for `Split`, `ArrayLen` and `FieldExtract` (previously
`none (unstated)`); nothing parses those lines yet.

Session green under `quick_and_dirty = false`: four theories, `Compose`
4.3 s cumulated, `Finished TextOps (0:00:06 elapsed)`, RC=0.

**The `\\s`-vs-POSIX-space gap is closed, not recorded (2026-11-11).**
`sh2perl/docs/fm/TextOps/ShIR_TextOps_Space.thy` (fifth theory of the session,
~510 lines) took the open target the previous entry listed and did the thing
the entry said would be needed: it puts the engines' class IN the model. The
class is MEASURED first — `docs/fm/TextOps/measure-space.sh` sweeps
U+0000..U+10FFFF through perl (byte and Unicode string models), node, python,
rustc and go and prints the code points each one treats as `\\s`, with the
interpreter versions; the `*_ws_list` definitions are that output transcribed,
defined independently so their relations are proofs.

The result is narrower than the prose was. Every measured class is a
SUPERSET of POSIX space (`posix_subset_all`), so the divergence is always an
over-count and the extra bytes are equations over all `c`
(`js_extra_locus`, `py_extra_locus`, `perl_extra_locus`, `go_extra_locus`,
`perl_bytes_extra_locus`); POSIX is exactly the ASCII part of Unicode
White_Space (`posix_is_the_ascii_part_of_unicode`). The emit is refuted by
two evaluated witnesses — NBSP as UTF-8 (0xC2 0xA0) is ONE word to `wc -w`
and two to `\s`-splitting JS, and 0x1C is one word to `wc -w` and two to
Python's `str.split()` (`js_nbsp_rendering_is_not_the_model`,
`python_separator_rendering_is_not_the_model`). The second witness is plain
ASCII, which is why the guard `lowered_wc` already applies to `StrLen` would
fix JS/Go/Perl and CANNOT fix Python:
`rendering_is_sound_exactly_for_the_posix_classes` states the four cases
together and `python_has_no_ascii_guard` refutes the guarded statement.

One finding changes how the gap must be described: Perl's default (byte)
`\\s` is a DIFFERENT set from its Unicode one (`perl_bytes_is_unicode_minus`
loses U+00A0 and U+0085), so for that renderer the class is a property of the
run-time string, not of the emitted code — no codegen assertion can be
correct in general. Java, C and Sh render `wc -w` through `shWcWords` /
`_sh_wc_words` rather than a regex split and are unaffected. What the fix
should be (refuse `-w` on non-ASCII, narrow the renderers to `[\t\n\v\f\r ]`,
or count bytes) is explicitly NOT decided here; each option needs the locus
lists and none is a proof obligation.

Session green under `quick_and_dirty = false`: five theories, `Space` 29.5 s
cumulated, `Finished TextOps (0:00:24 elapsed)`, RC=0, no `sorry`.

Two proof shapes are now documented box traps (`docs/fm/README.md`): a
CONJUNCTION over a recursive function's output (`w ≠ [] ∧ ws-free`) does not
terminate here in 240 s under `simp_all`, `auto` or the `fun` induction rule
alike, while the two halves as separate inductions close in ~6 s
(`field_scan_no_empty` + `field_scan_ws_free`, recombined); and a parameter
named `done` is an OUTER SYNTAX error inside
`proof (induction cs arbitrary: cur done)` — `done` terminates the method
argument, and the error points at the following `case`, which misleads.

### Text-ops slice 6: the string-algebra nodes (2026-11-12)

`StringTrim`, `StringAffix` and `AffixStrip` are modelled and machine-checked
in `sh2perl/docs/fm/TextOps/ShIR_TextOps_Strings.thy` (sixth theory of the
session), on top of one generic run drop (`lead_drop`/`trail_drop`/`trim_by`)
carried at an arbitrary class. Proved: a trim is idempotent at all four flag
pairs and removes a run from each end and nothing else (`string_trim_idem`,
`lead_drop_untouched`/`trail_drop_untouched`, `string_trim_interior_kept`);
the affix test is the existential that `startsWith`/`endsWith`/`strip_prefix`
compute, on both sides and for the empty pattern
(`affix_pre_is_the_existential`, `affix_suf_is_the_existential`); and
`AffixStrip` is that test plus ONE slice, so the Rust
`strip_prefix(..).unwrap_or(t)` and ESTree `startsWith ? slice : t` shapes
coincide with the node and it is NOT `trim_start_matches`
(`affix_strip_shape_pre`, `affix_strip_strips_one_occurrence`,
`affix_strip_is_not_idempotent`).

The measured half is pinned by a new `TextOps/measure-trim.sh` (every code
point through each renderer, with version strings): JS `trim()` = `js_ws`,
Python `strip()` = `py_ws` (`str.isspace()`, so 0x1C..0x1F and NBSP too), Rust
= Go = Unicode White_Space — all three proved equal to the Space theory's
independently defined tables. Two classes are new: Java's `strip()`
(`Character.isWhitespace`: 0x1C..0x1F in, the non-breaking points out) and
Zig's literal `" \t\n"`, three of six POSIX bytes. Consequences, as witnesses
rather than prose: the Python renderer's comment ("a FIXED whitespace set …
bash's default IFS") is false, since that set is `is_ws` and the measurement is
`py_ws` (`python_trim_class_is_not_its_source_comment`); Python and Java have
NO ASCII guard (0x1C is ASCII); Zig is unsound on plain ASCII (a CR survives);
JS and Python differ from the node on U+00A0. Conversely Perl is sound on
ASCII at EVERY flag pair, and JS/Go/Rust at the both-ends pair.

Two contract findings for the marketplace: ESTree, Go, Rust and Zig ignore
`leading`/`trailing` (both-ends primitives), so a one-sided `StringTrim` would
be mis-rendered — latent, because the only emitter today
(`src/transforms/text_ops.rs`) passes `(true, true)`
(`flag_blind_renderers_are_wrong_for_one_sided_trims`,
`flag_blind_renderers_are_right_at_both_ends`); and Perl's trailing
`StringAffix` (`substr($t, -length($p)) eq $p`) is false for the empty pattern
where `endsWith("")` is true, so it equals the node exactly on non-empty
patterns (`perl_suffix_test_is_the_model_for_nonempty_patterns`,
`perl_suffix_test_differs_exactly_at_the_empty_pattern`). Not decided: refuse
vs narrow vs a byte-set node; and affix-in-a-loop (`${s#p}` under `read`)
needs the state tier.

Session green under `quick_and_dirty = false`: six theories, RC=0, no `sorry`.
`docs/fm/README.md` carries the new obligation rows and the closed target.

### 2026-11-13 — TextOps: every node spec resolves, plus CutsetTrim and Substitute

`docs/fm/TextOps` builds eight HOL-only theories (~35 s, `quick_and_dirty =
false`). Closed: `newline_strip_sound`, `uniq_lines_sound` and
`substitute_sound` — the three dangling promises — and a fourth the new checker
found, `sort_lines_sound`; with them the open targets
`rev_drop_last_nl_prefix`, `sorted_insert`/`isort_sorted` and
`drop_runs_idem`/`drop_runs_adj_free`. New theories: `ShIR_TextOps_Cutset` (the
trim class as data, the three sides, idempotence per side, the Perl bracket and
Go/Rust codepoint divergence witnesses) and `ShIR_TextOps_Substitute` (two
fuel-bounded engines over an abstract matcher; the empty-match advance is the
termination lemma; the regex syntax, the line split and `\N` are limitations).
New machine check: workspace `harness/check-node-specs.pl` — every `spec:` name
must resolve under `docs/fm` (16 resolved, 29 unstated, 0 dangling). Node
wiring: `StringTrim`, `StringAffix`, `AffixStrip`, `CutsetTrim`.

Lessons worth keeping: a `fun` whose third clause tests an `if` gives
branch-CONDITIONAL induction hypotheses, so the collapse proofs quantify the
head explicitly; a META-forall in `assumes` is a context fact the induction
never rewrites, so state such a premise as an object forall; and a `[simp]`
lemma that rewrites the very condition a definition tests (`clipped m s = 0`)
turns reductions into case splits.

### 2026-11-13 (later) — CutAt: find/rfind and the four single-star cuts

`ShIR_TextOps_Cut` (ninth theory, session still green) proves the `CutAt`
node's four glob-strip identities as find()/rfind() work: `find_first` and
`rfind_last` with occurrence / no-match / leftmost-maximal characterisations,
the four cut forms with their no-match no-ops (`cut_at_sound`, now the node's
`spec:`), the split identity, and `affix_strip_fold_sound` — the star branch is
`AffixStrip` at a head literal, `first` is load-bearing on a repeating literal,
and `cut_first_last_agree` covers the other side: the two cuts coincide exactly
when the two primitives do. Not proved and said so: the glob engine. The node's "each identity
follows from glob semantics" is an assumption here, not a theorem; the
magic-free precondition is a predicate (`is_magic_free`).

Traps that shaped the proofs (the documented three did not bite, new ones did):
`induct s` WITHOUT `arbitrary: i` fixes the index variable, so the hypothesis
cannot be instantiated at the recursive call's index and `Cons(1)[OF k]` fails
with "no unifiers" — the fix reads like a type error and is not one. In a case
whose statement carries meta-premises, the Cons case numbers the IH as fact (1)
and the premises from (2). `simp add: append_take_drop_id` cannot be used in the
orientation a `drop`/`take` goal has, so the equation has to be stated reversed
in a `have` and consumed by `calc`. And `take (length n) (drop i s)` needs
`drop_drop` plus `add.commute`: without the commute the index normal form breaks
the match. Maximality is stated as `j ≤ length s ⟹ j ≤ i` rather than as a
negated occurrence — the negated form makes the base case a vacuous arithmetic
contradiction that `simp` will not close.

### 2026-11-13 (referee pass) — the CutAt fold lemma was padding, now restated

The first version of `affix_strip_fold_sound` was not a general theorem: it
carried two `eval`'d constants as conjuncts and reached the `##` side only under
`find_first s n = rfind_last s n`, i.e. the last branch was proved by assuming
the two branches equal. Rewritten: the fold lemma now quantifies over arbitrary
`s` and `n`, and for each of the four shapes says the node is the primitive's
`take`/`drop` at that shape's own occurrence — with the no-match arm inside the
same `case` — plus the head-literal link to `AffixStrip` on the plain branch.
`cut_at_sound` (the node's `spec:`) was widened the same way: it now states all
four forms with a match arm and a no-match arm each, so the spec resolves to a
theorem covering the whole node rather than to flag equalities plus numbered
corollaries. The repeating-literal witness survives as its own example lemma,
where it documents that `first` is load-bearing instead of standing in for a
general proof.

Lesson: an `eval` conjunct is a test, not a theorem, and a hypothesis that
equates the two functions under comparison proves nothing about either.

### 2026-11-13 (third slice) — CutsetTrim: five general obligations

`ShIR_TextOps_Cutset` now states the node's obligations as theorems over
arbitrary text and cutset rather than as prose plus evaluations:
`cutset_trim_is_trim_by` (so idempotence and run-only removal are inherited from
Strings), `cutset_trim_removes_only_a_run`, `cutset_side_three_valued`, and —
the three divergence claims — `perl_cutset_needs_quotemeta` (the arm depends on
the cutset as a SET, which is exactly what `\Q..\E` preserves),
`go_trim_cutset_is_codepoints` and `rust_trim_matches_is_chars` (the model
decides one byte at a time, at the head and the tail respectively). The witness
lemmas name the bytes: `]`, `^`, `\`, `-`, and the NBSP pair where the model
splits a character. `cutset_trim_sound` — the node's `spec:` — now carries the
generic form and all three sides.

Trap: positional instantiation binds the statement's schematic variables in
order of APPEARANCE, not in the order the arguments are named, so
`lead_drop_suffix[of "cutset_mem cs" s]` tried to pass a predicate where a list
belongs ("Clash of types _ ⇒ _ and _ list"). `[where P = ... and s = ...]` is
the form that cannot bind the wrong slot. Also: proving a per-side equality by
`unfolding` a definition and letting `simp` split the `if` reintroduced the
abbreviation and stalled; going through the per-side `[simp]` lemma first
(`cutset_lead_is_lead_drop`) closes it immediately.

### 2026-11-13 (referee pass 2) — CutsetTrim: the divergences now compare readings

The three divergence names were over-claiming: `perl_cutset_needs_quotemeta`
stated only that the trim is a function of the member set (true of both
readings, so invariant under dropping the quoting), and
`go_trim_cutset_is_codepoints` / `rust_trim_matches_is_chars` were one-byte base
cases of `cutset_trim`. Renamed to what they say
(`cutset_trim_depends_only_on_members`, `cutset_trim_lead_is_bytewise`,
`cutset_trim_trail_is_bytewise`) and the divergence obligations rebuilt as
comparisons between two models:

- a bracket-body syntax read without `\Q..\E` (`uq_body`/`uq_scan`/`uq_class`)
  against the literal set, over `]`, `^`, a backslash and an `a-c` range;
- a two-byte UTF-8 decoder with a char-wise trim (`decode2`/`encode2`/`cp_drop`)
  against the byte model, on U+00A0 at both ends.

Each is a proposition that would be false if the quoting were dropped or code
points collapsed to bytes, and each carries its witness bytes. What is still not
modelled: the real regex compiler, 3/4-byte UTF-8, the arms' behaviour on
undecodable input.

Traps: two `[94, 97]` literals in one statement are INDEPENDENT type variables,
so `98 \<notin> set [94, 97]` next to `uq_class [94, 97] 98` elaborates with a
free `'b` and `simp` ends on `(98::'b) ≠ (94::'b)`; annotate one side `:: nat`.
And `eval` on a partially applied user predicate tripped a wellsortedness error
(`numeral < equal`) that plain `simp` with the definitions does not.

### 2026-11-13 (spec integrity) — newline_strip_sound restated, checker hardened

`newline_strip_sound` was one take/drop equation; the node-level obligation is
now the four-conjunct statement: the kept text is `take (length s - run) s`, its
length is that quantity, what it drops is a suffix whose every byte is `10` and
whose length is the run, and the kept text does not end in a newline. Two
helpers were needed and proved: `lead_nl_count_le` (the run fits in the text) and
`lead_nl_count_take_all_nl` (taking the run really yields newlines); the old
equation became `newline_strip_take`, and `newline_strip_suffix` states the
suffix form. `newline_strip.node`'s `spec:` still names `newline_strip_sound`,
so the node's promise and the theorem now agree in content as well as in name.

`harness/check-node-specs.pl` gained the distinctions the audit needed:
theorem/lemma/corollary only (a `definition` is not an obligation), session
membership read from `ROOT`, and — the hole that mattered — a name only counts
when its theory is listed in a `ROOT`, so an untracked WIP theory cannot satisfy
a spec. It also accepts `spec: pending Theory#name` for open obligations (counted,
and an error once the name resolves), and has `--map` (the node table printed in
README) and `--selftest` (five controls: real theorem, definition, dangling name,
wrong session, unbuilt theory).

Audit result: 17 resolved, 28 unstated, 0 pending, 0 errors. Nothing that cited
a name regressed to `none`. One finding: `str_splice_fold_sound` exists only in
the untracked `ShIR_TextOps_Splice.thy`, which no `ROOT` lists — `str_splice.node`
stays unstated and the checker now reports that name as `OUTSIDE THE BUILD`.
Trap: the checker's first version accepted `definition` and scanned every `.thy`
regardless of `ROOT`, so it could report a spec as resolved against a file the
build never compiles; both are now negative-control cases in `--selftest`.

### 2026-11-13 (referee pass) — substitute_sound and uniq_lines_sound brought up to their nodes

`uniq_lines_sound` was `drop_runs ls = collapse_prev ls None`: true, and silent
about the `-c` counts the node promises. Replaced by a six-conjunct theorem —
streaming collapse, the reconstruction `ls = concat (map (λ(n,x). replicate n x)
(run_count ls))`, printed lines = collapse, every count ≥ 1, counts sum to
`length ls`, no equal neighbours — where the reconstruction is what pins each
count to its run length (`[a,a,b]` with counts `(1,2)` reconstructs `[a,b,b]`).
Evidence that the counts wording was not decoration: `run_count_parts` needed
`run_count_pos` and a case split on the head count, because a zero count would
make `replicate` unfaithful. `uniq -s N` stays open and is named in the node as
`pending TextOps#uniq_lines_skip_sound` — the skip relation also changes WHICH
line of a run survives (uniq keeps the first, `drop_runs` keeps the last), so it
is not a corollary of equality-run reasoning.

`substitute_sound` already stated the engine obligation (advance on a zero-length
match, leftmost/non-overlapping step, identity on no match) and its termination
(`subst_*_extra` plus the fuel corollaries), but its replacement language was one
witness (`&` alone). Added `expand`: sed's replacement string parsed for real —
`&`, `\N` against the matcher's capture report, `\&`/`\\` literals, unknown
escapes copied through so the function is total — with `expand_amp`,
`expand_backref`, `expand_escaped_amp`, `expand_backslash`, and the engine rules
instantiated at it (`substitute_expand_leftmost`,
`substitute_expand_empty_match_advances`). The line domain is now declared open
in the node (`pending TextOps#substitute_line_domain_sound`) instead of being
described in prose as "not proved".

Traps hit and recorded: `fun` rejects nested numeric patterns (`92 # 92 # r`) in
sequential mode — the parser must branch on the first byte and `case` the rest;
`show ?thesis using h by blast` fails when the theorem's premise has already
become an assumption (write the `metis` step instead); `simp_all` does not pick
up a `case True` fact for a goal that simp itself created, so the if-condition
must be passed with `add:`; `replicate (Suc n) x` does not rewrite to
`x # replicate n x` in every orientation, so a "count is positive" case split is
cheaper than arithmetic on `n - 1`.

Checker after this pass: 17 resolved, 28 unstated, **2 pending**, 0 errors —
the pending set is exactly the two obligations named above, and the checker
errors if either name ever starts resolving without being promoted.
