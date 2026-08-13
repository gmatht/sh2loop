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
>   runs, matching bash except the documented $HOSTNAME line); (8) debashc
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
>   Both semantics are now SELECTABLE: `debashc --argv0-source <name>` bakes
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
>   Every file probe-verified through the core (`debashc --shir` emits valid
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
| sh2perl backends | Perl only. `src/ir.rs` = Perl-specific IR with `RawText` bridges; `pub mod mir` commented out. **ESTree emitter exists** (`debashl::estree::ast_to_estree_json`, v0 `sh2.*` namespace) and passes the full corpus. Workspace layering: `debashl` (core lib) ← `debashcl` (CLI lib, member `cli/`) ← `debashc` (3-line bin). WASI: `build-wasi.sh` → `debashc.wasm` (command, `_start`) + `debashl.wasm` (library, `wasi-lib` feature, C-ABI `debashc_to_perl`/`debashc_to_estree`) + **`debashcl.wasm`** (library, `wasi-cli` feature, C-ABI `debashc_cli_run(_json/_with_input)` — the full CLI as a library call, "debashc in three lines of JS"; deployed with README + examples to `~/js/`). |
| Tests | `fail`: debashc → Perl → `check_qx.pl` gate → run vs `bash` → normalized stdout + side-effect compare. 516 examples, **PERL 432/84, ESTREE 516/516 (100%)**. `fail-estree`: perl + estree verdicts per example (Stage A); `--gate` Stage B (strict: a failing test is a bug — no failing-test allowlist; the M5 blessed-fail list was removed as a guardrail violation, see revision history); `--metric` sh2.* call-site tallies (improvement-mode awareness). |

Key docs:
- `sh2perl/docs/ir-design.md` — Perl IR + "two-layer IR (future)" (ShIR between AST and language IRs).
- `sh2perl/docs/AST.md` — the shell AST that feeds everything.
- `sh2runtime/docs/architectural-considerations.md` — §3/§5 ESTree as leaf backend; §7 Common ShIR; §9 JS-first backend order.
- `sh2runtime/README.md` — virtual FS + tinysh JS-command model (`.js` files are the "compiled binaries").

---

## 1. Repo topology: sh2perl stays a submodule; sh2runtime does not

### 1.1 The dependency rule (one-way)

- **sh2loop → sh2perl:** the workspace depends on and *modifies* sh2perl (the
  harness drives debashc, blesses examples, bumps the gitlink). sh2perl is a
  **properly registered submodule** of sh2loop.
- **sh2perl → sh2loop: forbidden.** sh2perl must never reference or write into
  the workspace. Concretely: remove the **tracked `fail -> ../fail` symlink**
  from sh2perl (it dangles when sh2perl is cloned standalone); the workspace
  provides its own `fail`. sh2perl's CI stays self-contained (cargo tests).
- **sh2perl ⇄ sh2runtime: no code coupling.** The interface is ESTree JSON
  (1.2); sh2runtime is **not** a submodule. Test-time coupling is by commit SHA
  in CI (1.4).

### 1.2 The contract

- **sh2perl emits standard ESTree JSON** (`debashc --estree file.sh`). No JS
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
  debashc, runs `fail` + `fail-estree` (the corpus gate).
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
test.sh ── debashc ──► Perl ───────► perl <tmp/test.pl> ───────────► stdout ──► vs ──► bash
   │
   └── debashc --estree ──► test.estree.json
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

### 2.2 debashc side: `--estree` output mode

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

- `fail` gains `--estree` mode (or a sibling `fail-estree`): `debashc
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
  checks out the sh2perl submodule, builds debashc, runs `fail` + `fail-estree`:
  ```yaml
  - uses: actions/checkout@v4
    with: { submodules: true }
  - uses: actions/setup-node@v4
    with: { node-version: 22 }
  - run: cd sh2perl && cargo build --bin debashc
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
- Does `--estree` belong in the `debashc` binary or a separate
  `debashc-estree` bin? (Recommend: same binary, `--estree` flag, so CI and
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
   `debashc --estree`; `tests/estree-runner.mjs` (@babel/generator + node
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
   build/test commands (`cargo build --bin debashc`, `cargo test`), IR
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
  `debashc file --estree <file.sh>` emits standard ESTree JSON with an `sh2.*`
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
- **2026-08-01 — debashcl.wasm: the full CLI as a WASI library call.**
  debashc.wasm was command-only (`_start`; node:wasi has no fs preopens) and
  debashl.wasm skipped the CLI — the debashcl crate had zero `#[no_mangle]`
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
