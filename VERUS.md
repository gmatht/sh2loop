# Verus proofs of the transforms

Where the project stands on proving its shIR→shIR transforms correct with
[Verus](https://github.com/verus-lang/verus): what is proven, how much the
proofs are worth, what is not proven, and what to prove next.

The per-proof detail lives in `sh2perl/proofs/verus/README.md` (one section
per file: theorem, negative control, scope). This file is the overview: the
inventory, the rigor accounting, and the priority order. The sibling
framework is Isabelle (`sh2perl/proofs/README.md`, `proofs/ArithIdentity`,
`proofs/ForRecovery`, `sh2perl/docs/fm/`); §(c) marks Isabelle coverage so
the two are not double-counted. The tier language (Tier 1/2/3) comes from
`docs/transform-verification.md`.

Status snapshot (measured 2026-10-24; three C-generator rows added 2026-10-28; the write-arm and vbuf rows added 2026-10-29; on 2026-11-09 every model below was committed to the tree — the `local-only` badges meant "uncommitted working copy", so the gate could check none of them in a fresh checkout):

| proof file | target | obligations | status |
|---|---|---|---|
| `proofs/verus/interval.rs` | `transforms/i32_provable.rs` (`arith_bounds`) | 5 verified, 0 errors | **RETIRED** — target never landed, see P0(iv); gate-verified as a retired record, outside every total |
| `proofs/verus/i32_bounds_exec.rs` | same, exec-carrying full-enum form | 7 verified, 0 errors | **RETIRED** — target never landed, see P0(iv); gate-verified as a retired record, outside every total |
| `proofs/verus/escape_classes.rs` | **verdict analysis**: `transforms/escape_classes.rs` `class_of` over the C consumer (`c_backend.rs:9929`) | 14 verified, 0 errors | landed, gated — see P12 |
| `proofs/verus/f32_narrow.rs` | **verdict analysis**: `transforms/f32_narrow.rs` form table + `operand_exact` | 8 verified, 0 errors | landed, gated — see P12 |
| `proofs/verus/optimize_stmts.rs` | `src/ir.rs::optimize_stmts` Pass 1 | 8 verified, 0 errors | committed `84bb46cb7`, local-only |
| `proofs/verus/dead_fn_elim.rs` | `transforms/dead_fn_elim.rs` Passes 1–4 | 25 verified, 0 errors | committed `46ec35566`, local-only |
| `proofs/verus/dead_store_elim.rs` | `transforms/dead_store_elim.rs` core | 45 verified, 0 errors | committed `dbd0a5562`, local-only |
| `proofs/verus/redundant_store_elim.rs` | `transforms/redundant_store_elim.rs` (fixed) | 54 verified, 0 errors | landed, gated — see P1 |
| `proofs/verus/copy_propagation.rs` | `transforms/copy_propagation.rs` (substitution core) | 27 verified, 0 errors | in-tree 2026-11-09, gated — see P3 |
| `proofs/verus/function_purity.rs` | `transforms/function_purity.rs` (verdict) | 41 verified, 0 errors | in-tree 2026-11-09, gated — see P4 |
| `proofs/verus/test_lowering.rs` | `transforms/test_lowering.rs` (Tier-1 leaves) | 25 verified, 0 errors | in-tree 2026-11-09, gated — see P5 |
| `proofs/verus/string_folds.rs` | `interp_fold` + `default_empty_fold` (string folds) | 11 verified, 0 errors | in-tree 2026-11-09, gated — see P6 |
| `proofs/verus/arith_folds.rs` | `arith_normalize` + `bc_float_clean` (arith identities) | 11 verified, 0 errors | in-tree 2026-11-09, gated — see P6 |
| `proofs/verus/test_folds.rs` | `test_simplification` (self-comparison table) | 7 verified, 0 errors | in-tree 2026-11-09, gated — see P6 |
| `proofs/verus/capture_folds.rs` | `const_capture_fold` + `text_capture_fold` | 15 verified, 0 errors | in-tree 2026-11-09, gated — see P6 |
| `proofs/verus/list_folds.rs` | `brace_fold` + `affix_strip_fold` (list/affix) | 12 verified, 0 errors | in-tree 2026-11-09, gated — see P6 |
| `proofs/verus/textop_folds.rs` | `text_ops` pure literal arms | 15 verified, 0 errors | in-tree 2026-11-09, gated — see P6 |
| `proofs/verus/not_folds.rs` | `not_identity` (double-negation + rust-gated flip) | 13 verified, 0 errors | in-tree 2026-11-09, gated — see P7 |
| `proofs/verus/const_cmp_folds.rs` | `const_str_cmp_fold` (literal Eq/Ne + Not-wrapped + globMatch) | 14 verified, 0 errors | in-tree 2026-11-09, gated — see P8 |
| `proofs/verus/array_len_fold.rs` | `transforms/array_len_fold.rs` (`fold`) | 10 verified, 0 errors | landed, gated — see P2 |
| `proofs/verus/const_status_cond.rs` | `transforms/const_status_cond.rs` (7-row table) | 35 verified, 0 errors | landed, gated — see P2 |
| `proofs/verus/background_decide.rs` | `transforms/background_decide.rs` (THREAD/FORK verdict for `cmd &`) | 27 verified, 0 errors | **conditional, NOT Tier 1** -- subshell-vs-thread equivalence under a stated model (`&` inherits reads, discards writes, shares stdout). THE VERDICT (2026-11-09): `walk_ok_implies_intended` bridges the SHIPPED walk (`walk_self_contained`) to the proved-sound ordered rule -- its post-set keeps straight-line binds only, which is the monotonicity the `Seq` arm needs; `classify_thread_sound` then gives THREAD ⇒ identical bytes end to end over that walk, and `route_thread_is_sound` the same over the SHIPPED predicate (`is_thread_body`, body-text table), given only the insertion rule itself (`table_sound`). Refusal direction: `unclassified_stays_fork` / `absent_table_routes_fork` (no table or no entry ⇒ FORK -- the verdict never guesses) and `side_effect_stays_fork` (a file write or control transfer is never accepted, so it cannot enter the table). The refutation is kept as the pre-fix record: `shipped_check_is_unsound` proves the OLD `collect` set-comparison accepts `if [ -n \"$x\" ]; then x=1; echo 7; fi`, which prints 7 in the subshell and nothing on a fresh runtime; `intended_implies_shipped` proves the ordered rule refuses nothing that check accepts. `is_thread_body` still has zero call sites outside its own file, so this is a sound verdict ready to consume, not a live constraint: nothing miscompiles today, and the wiring is the remaining work. Excluded from the Tier-1 totals. |
| `proofs/verus/process_subst.rs` | `transforms/process_subst.rs` (fd-carrying `<( )` shapes) | 6 verified, 0 errors | **conditional, NOT Tier 1** -- the materialization lemma: the consumer's input is exactly the producer's output byte for byte, the temp path is unlinked, other temps are untouched, and the negative control proves the fd/mode inversion the pass's tests pin yields an empty consumer input (so the inversion is load-bearing). Excluded from the Tier-1 totals. |
| `proofs/verus/elim_trio.rs` | `const_condition_elim` + `unreachable_after_exit` + `merge_init_assignments` | 22 verified, 0 errors | landed, gated — see P9 |
| `proofs/verus/slice_identity.rs` | `transforms/slice_identity.rs` (zero-offset fold) | 10 verified, 0 errors | landed, gated — see P10 |
| `proofs/verus/case_lowering.rs` | `transforms/case_lowering.rs` (dispatch) | 29 verified, 0 errors | landed, gated — see P10 |
| `proofs/verus/elseif_flatten.rs` | `transforms/else_if_flatten.rs` (chain) | 22 verified, 0 errors | landed, gated — see P11 |
| `proofs/verus/seq_range.rs` | `transforms/seq_range_for.rs` (seq words) | 11 verified, 0 errors | landed, gated — see P11 |
| `proofs/verus/ternary_desugar.rs` | `transforms/ternary_desugar.rs` (cond normalize) | 9 verified, 0 errors | landed, gated — see P11 |
| `proofs/verus/escape_classes.rs` | **verdict analysis**: `transforms/escape_classes.rs` `class_of` over the C consumer (`c_backend.rs:9929`) | 14 verified, 0 errors | landed, gated — see P12 |
| `proofs/verus/f32_narrow.rs` | **verdict analysis**: `transforms/f32_narrow.rs` form table + `operand_exact` | 8 verified, 0 errors | landed, gated — see P12 |
| `proofs/verus/c_eqne_emit.rs` | **C generator**: `c_backend.rs` `expr()` Eq\|Ne arm (`str_cmp_valued` decision) | 11 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §14a |
| `proofs/verus/c_checked_arith.rs` | **C generator**: `c_backend.rs` checked i64 tier (`tiered_i64_expr` / `tiered_store_general` + spec arm) | 38 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §13 |
| `proofs/verus/c_arr_cap.rs` | **C generator**: `array_fixed_caps` / `array_cap()` sizing + the reset emitter's write guard | 13 verified, 0 errors | landed, gated — corpus scan `harness/c-arr-cap-scan.sh`: 555/563 examples rendered, 72 fixed tables, 0 bulk > cap, 0 at-cap above their bulk (see PLAN 2026-11-09) |
| `proofs/verus/i32_emit.rs` | **verdict → render decision**: `transforms/i32_provable.rs` `arith_abs_bound`/`exact_i32_bound` over the C tier's fast path (`c_backend.rs` `tiered_i64_expr` + `plain_i64_expr`) | 20 verified, 0 errors | landed, gated — **measured inert** (0/896 corpus files reach it; see PLAN 2026-11-09) |
| `proofs/verus/c_dec_str.rs` | **C generator**: `_sh_ll2s` + the inline `size_t` itoa it emits | 26 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §14b |
| `proofs/verus/c_width_store.rs` | **C generator**: `Width` + `width_of_var`/`effective_widths` store condition | 20 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §15 |
| `proofs/verus/c_buf_copy.rs` | **C generator**: `buf_bound` + `emit_guarded_copy` store contract | 14 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §16 |
| `proofs/verus/c_arith_guard.rs` | **C generator**: arith `/%` guard + `num_temp`/`str_temp` + `num_spec` | 15 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §17 |
| `proofs/verus/c_int_helpers.rs` | **C generator**: `_sh_isint31` + `_sh_isqrt` + `_sh_i128_str` | 69 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §18 |
| `proofs/verus/c_op_promote.rs` | **C generator**: const-fold + LL widening + unsigned-gate premises | 15 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §19 |
| `proofs/verus/c_str_helpers.rs` | **C generator**: `_sh_*` string helpers (substr/replace/arr_slice/strip/argv/split), plus the bash-measured slice ground truth (offset out of range -> EMPTY; `len<0` -> expansion error), the **positional join's face** (`$*` on IFS[0], `"$@"` on a space, empty IFS concatenates) and the **positional SLICE's face** (`${*:o:l}`/`${@:o:l}` both on IFS[0]; they differ only on an empty IFS — `*` concatenates, `@` falls back to a space; the slice is *not* the `$@` rule), and **field splitting** (`_sh_split`): IFS-whitespace runs are one stripped delimiter, each IFS non-whitespace char delimits one field, an empty IFS disables splitting, with fuel saturation proved (exact, not approximate) and the retired space-only splitter kept as the `blank_runs` mutant, and the `$IFS` READ — the startup buffer is exactly space+tab+newline and holds nothing else, i.e. the value the splitter consumes is the value the variable face publishes (it answered from getenv before, with a different value), plus the EMPTY-word contract: an empty value splits to ZERO fields, which the C `for` lowering's one-element list provably is not (filed to the core — `StrStyle` cannot say "unquoted"), and the FALLBACK slice `_sh_arr_slice` as the inverse of its own join (sep-parameterised; empty fields kept), which is where a non-default IFS made the word count wrong | 103 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §20/§20b and §28; fixes the positional slice's hard-coded space (`_sh_argv_slice` gained a `sep`; `IFS=:; v="${*:2:2}"` was `q r`, is `q:r`; `IFS=""; v="${*:2:2}"` was `q r`, is `qr`), and field splitting is now IFS-driven (the decl also gained bash's real startup IFS `" \t\n"`, which the old hard-coded splitter was silently supplying). Round check: battery `harness/ifs-probe.sh` 53 PASS / 0 FAIL / 6 XFAIL / 0 XPASS |
| `proofs/verus/c_capture_wrap.rs` | **C generator**: capture/wrap quoting (injection-freedom + status mapping) | 16 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §21 |
| `proofs/verus/c_decl_coverage.rs` | **C generator**: the three decl-census walkers + const-lift veto (`collect_store_expr` / `collect_assigned_vars` / `hoist_vars` / `collect_param_write_targets`) | 54 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §22; **registered sync**: `declcov-extract.py` diffs the live walker arm chains vs `c_decl_coverage_sync.txt` (v20 — the sync caught the new expr-position `assign` arm before the model had it, which is what a transcription checker is for). v20 adds `pin_assign_chain`: `true && x=v || y=w` writes inside a chain EXPRESSION (no `IrStmt::Assign`), and without the arm the read routed to `_sh_env("x")` while the write hit the C variable — measured, the echo printed an empty value. `base_of` takes the base before `[` (element writes hoist the array), `is_ident` refuses a phantom name, and the pin is fidelity-both-ways (INVENTORY/VETO still do NOT see it). Its unit test `expr_position_assign_routes_to_the_variable` is a proven TRIPWIRE — disabling the guard makes it fail with the `_sh_env("x")` read in the output |
| `proofs/verus/c_str_lit.rs` | **C generator**: `cstr` — the string-literal escaper (finite-state C lexer + round-trip vs the shipped `\x` spelling) | 19 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §23 |
| `proofs/verus/c_write_arm.rs` | **C generator**: `${name=word}` write arm + `param_write_target` census gate + `supplement_write_lengths` bounds | 17 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §24 |
| `proofs/verus/c_vbuf.rs` | **C generator**: the emitted growth-helper family (`_sh_grow` / `_sh_vgrow` / `_sh_grow_str` + zero-fill / `_sh_reserve_*` guard, plus the add/fa/snprintf-grow/vec-guard/fgets consumers) | 39 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §25; discharges §20/§21's "vbuf growth assumed" provisos |
| `proofs/verus/c_sparse_array.rs` | **C generator**: the sparse-array read faces over dense `char**` storage (`_sh_icount` count / `_sh_join_arr` separator / `_sh_join_ikind` keys / for-in hole-skip / free+NULL invariant / class-from-writes dispatch) | 45 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §26 (§26b/§26c: the `=`/`:=` faces write the word through `arr_set`, `assign_state`/`colon_assign_state`, +2 mutants) (and §26b, the no-colon SET-NESS faces on an element: `${a[i]-/+ /= / ?}` resolve through the store's presence answer, 4 mutants); fixes `${!arr[@]}`-on-indexed cc-red + the `${#arr[@]}`/`${arr[*]}`/for-in hole divergence |
| `proofs/verus/c_assoc_array.rs` | **C generator**: the associative-array faces — bash `declare -A` as a finite `Map<Str,Str>` over the parallel `m_k`/`m_v`/`m_n` storage under wf = equal length + pairwise-distinct keys; get/set/unset = lookup/insert/remove, count = keys.len(), key set = dom, the emitted fold = bash's space join, plus the int-attr arm and the homing veto; four measured probes + four mutants; §27b adds KEY PRESENCE (`_sh_assoc_has`, `has_is_dom`) for the same four set-ness faces, +3 mutants; §27c adds the `=`/`:=` INSERT (`assign_table`/`colon_assign_table`, `m13`) | 53 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §27; fixes the a3 for-iterator empty loop (split-`param` census + iter refs) and the a5 printf spread (quote-word arm extended to assoc storage) |
| `proofs/verus/c_join_ifs.rs` | **C generator**: the IFS joins — `${a[*]}` separator read (`_sh_join_arr_sep`), the store-based element slice `_sh_join_arr_rng` for both `[*]`/`[@]` faces, presence-order slice denotation (`rng_slice`: bounds of two DIFFERENT kinds — the OFFSET indexes SLOTS, negative counting slots back from last_index+1 and out-of-range being EMPTY, while the LENGTH counts PRESENT ELEMENTS scanned forward with holes skipped and unspent; `mw1`-`mw6` are the six measured rows where the retired `b + len` SLOT window disagrees, and `slot_window` keeps that retired window as an executable transcription), the `[@]` face's IFS-independence **for the whole expansion only** (an `[@]` SLICE joins on IFS[0] with a space fallback — `slice_at_sep`; under `IFS=:` `${a[@]}`=`x y z` but `${a[@]:1:2}`=`y:z`), and the `emit_var_decl` const-lift veto for IFS; **plus (2026-11-04) the DENSE-VALUE join** (`declare -ia`): the element list is the densified extent (value storage keeps no presence marker) while the separator discipline is the shared `join_sep` fold (d7), so the fix was a routing change, not a second join — with d4 pinning that the dense list and the presence list of the same array DIFFER, which is the value half of the type confusion that SIGSEGVed; **and (2026-11-04) the PRESENCE MARKER** (`{id}_set[]` for fixed dense int arrays): with it the dense element list IS `present(slots)`, so `dense_marked_face` is provably the char** face for both faces and any IFS (e4), plus `dense_count` = popcount (e2), `dense_get`/`dense_clear` (e5), `present_idx` keys `0 2` (e3), a real 0 being PRESENT (e6 — why presence cannot be derived from the value), the retired extent protocol provably disagreeing (e7); **plus (2026-11-04) the APPEND base**: `arr+=(…)` lands one past the last SET element (`last_set`/`append_base`), which is the extent for a dense array but NOT after an `unset` emptied the tail (f1), `_len` is provably not the base (f2 — the emptied case would leave a phantom slot), and the post-append count is popcount + k (f3); **plus (2026-11-04) the CHILD-SHELL reconstruction**: a child shell is a fresh shell, so the emitted literal `name=([i]=v …)` is a list of (index, value) PAIRS — `shell_pairs(slots, marker)` with `pair_idx`/`pair_vals`/`child_join`/`child_count` — and with the marker it IS the parent's view (`present`/`present_idx`) for every separator (g1), measured on the sparse array (g2), with the marker dropped as the mutant that invents an element (g3) and the hole-free case as the side condition that makes `pres == NULL` legitimate (g4a/g4); g5 is the sharp one: WITHOUT the marker parent and child AGREE (`7 0 9` on both sides) and both contradict bash (`7 9`), so consistency cannot be the obligation — the marker is owed to BASH; g6 pins the dispatch as a function of the STORAGE CLASS alone (`helper_for`: `char**` → `_sh_idx_init`, value → `_sh_idx_init_ll`) with the two reconstructions provably different on sparse storage; **and (2026-11-05) the ASSOC and KEY faces**, measured in a ONE-WORD context (an assignment — echo's own argument joining is what made the earlier readings look space-separated): the assoc VALUE `[*]` face is the shared fold (IFS[0], concatenating on an empty IFS) and `[@]` is a space join even under `IFS=:` (k2/k3, with `nl_join` keeping the retired hardcoded-newline join and the proof that 064_07 — `IFS=$'\n'` — passed for the reason the code was wrong); the KEY face reads IFS[0] for both faces and both storages, falling back to a space only for `[@]` under an EMPTY IFS (k1a); and an ASSOC slice's positive offset is ONE-BASED (`:0:1` and `:1:1` both take the first element, `:2:1` the second), out of range is EMPTY, a negative offset CLAMPS at 0, the length counts elements, and a negative length errors only in range (a1-a6); **plus the `!` FAMILY's COLLAPSE** (k1b/k1c/k1d): five spellings — `${!a[*]}`, `${!a[@]}`, both slice forms and `${!a[1]}` — lower to ONE node `param("slice", "!a", "@", "")`, so no renderer of it is exact (k1c) and k1d pins the exactness domain that still holds (the shipped rule is exact for `[@]` under every IFS and for `[*]` whenever IFS is non-empty; the empty-IFS `[*]` row is the erasure's only cost). The contract fix is filed as `core-requests/c-20261105-keys-face-collapse.md` | 104 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §28, §35 and §36; fixes 064_07 (`${config[*]}` IFS join → `sort` fed one line), the parser dropping `${a[*]:off:len}` (c10/c16 — the face now rides in the name, `a[*]`), and the `[@]` slice empty-lead/embedded-space divergences (c26/c27), and (2026-11-04) the `[@]`-**slice** join, whose face is IFS[0]-with-space-fallback rather than the whole form's fixed space (c17 revised, c33-c35, m7; ifs-probe case 21 was the xfail this retired). Round check: battery `harness/ifs-probe.sh` **87 PASS / 0 FAIL / 6 XFAIL / 0 XPASS** as re-measured 2026-11-05 (case 52, the empty-for-loop, RETIRED by the `split_fold` non-emptiness fix in `c_expand_order.rs` §7; case 10, `10_holes_slice` — a sparse `[*]:off:len` slice giving `[b c]` where bash gives `[b c z]` — RETIRED by the mixed-bounds window fix in `C_UB_PROOF.md` §35, which the `mw1`-`mw6` obligations above pin row by row; case 56, the `${!n[*]}` KEY face under `IFS=:` (`0:2`) — RETIRED by the key-separator fix in §36, which k1a-k1d state; a 136-row (off, len) probe over four sparse shapes × both faces is 136/136 and a 28-row assoc/key probe is 25/28 with the three remaining rows being the proved CORE erasure (two) and bash's `file: line N:` stderr prefix on the error rows). Retired xfails across the four 2026-11-04 rounds: 54 (the dense join SIGSEGV — 54b-54f added faces/extremes/fallback slice), 55 (dense sparse — the presence marker, §20e, with 55b-55e), 58 (dense append, §20f, with 58b-58d), 60 (an int array's printf-args ARGV face — one `idx_init_call` classifier for all three child-shell call sites plus `_sh_idx_init_ll`, §28c, with 60b-60d). Still pinned: 57 (a sparse `+=` routes the array to the growable VEC form, which `dense_presence` excludes), 58e (an EXPANDED append falls into a malformed `bash -c` emission, rc 2 — a CORE shape: `$((…))` inside an array literal already produces a stray `)` command). The arithmetic-subscript family (59/59b-59m) is FIXED — see `c_subscript.rs` §20g. Dense and append shapes ASAN+UBSAN clean. C corpus gate re-measured **PASS=625 FAIL=19 SKIP=7** on 2026-11-05 (the row's 613/31 was the 2026-11-04 subscript round; FAIL reasons unchanged), no corpus example using `declare -ia` — the probe battery, not the gate, is the instrument for that half of the family |
| `proofs/verus/c_subscript.rs` | **C generator**: the FLATTENED SUBSCRIPT — the core leaves an element write's subscript as TEXT inside the target name (`n[$((i*2))]=v` arrives with `indices` empty), so one text reached THREE consumers that disagreed in both directions. ONE classifier (`classify`: explicit-arith / numeral / bare `$var` / bare ident / operator text / word) now defines both the declaration census and the store arm, and `decl_and_store_agree` is the invariant (the retired pair had two independent predicates, proved divergent on `i` — census indexed, store assoc — and both-assoc on `i*2`). Pins k1-k16 are the measured bash truth table: the index an indexed array computes (`$((e))` → inner, `i*2` → itself, a bare ident → its value, `"1"` → 1), and the ASSOC key text where the EXPLICIT form is the arith VALUE and a bare operator text stays LITERAL (bash `2 [i*2 2]` from one script — no single-verdict implementation could produce it). Plus the LIVENESS half on the DSE side (`transforms/dead_store_elim.rs`): `subscript_read_names`/`arith_read_names` census the text as reads, `subscript_closure` is the closure obligation and `dead_needs_no_mention` the contrapositive the purge relies on, with `fix_was_necessary` showing the pre-fix read set is exactly `{n}` — which is why `i=3; n[$((i))]=9` dropped the store and the renderer named an undeclared var. Mutants m1-m3 are the retired behaviours; the one shape still divergent (`${i}`, the core keeps the braces) is proved as a divergence, not glossed | 37 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §20g; fixed 59 (arith subscript write → assoc storage, `n_k` undeclared), 59c-59f (bare text, `$i+1`, bare ident, quoted numeral), 59g/59h (paren/const arith), 59i (string array), 59j (the READ side evaluated `$((…))` as 0), 59k/59l (assoc explicit key was the empty-expansion `"0"`), 59m (the store the subscript names). Round check: battery **81 PASS / 0 FAIL / 9 XFAIL / 0 XPASS**, C corpus gate **PASS=613 FAIL=31 SKIP=7** — 7 examples fixed, zero new failures (063_09, 064_21, eq-string-num-var, func-after-or-assign, func-after-test-or, or-continue, param-expand-default-operator). New pin: 60 (an INT array's printf-args ARGV face passes `long long[]` to `_sh_idx_init`'s `char **`, SIGSEGV — pre-existing, found while probing) |
| `proofs/verus/c_expand_order.rs` | **C generator**: WORD-EXPANSION ORDER — a command's word list is a LIST OF FACES expanded LEFT TO RIGHT, each evaluated against the store as it stands at ITS position (`Read(i)` / `ColonStore(i,w)` / `AssignStore(i,w)`), so bash shows a `a[0]:=w` store to every LATER face and to no earlier one (`a=(''); echo "[${a[0]}] [${a[0]:=z}]"` is `[] [z]`, and the pre-fix `[z] [z]` is `m1_hoisted_store`); the store is a `Seq<Option<Str>>` because `by (compute)` over a `Map`-returning recursion diverges on this toolchain. Per-face theorems, the arity law (`words_len_is_faces_len`), the carrier walk (`narrow_walk_misses_output`/`_return` — `printf` folds to `IrStmt::Output` and a function's `echo` to `Return(Some(..))`, which is why two probes stayed red after the first fix), the `set --` SPLIT (`_sh_split` + a growable positional vector: `x='a b'` is TWO positionals, `x=' '` is ZERO, `IFS=:; x='a::b'` is THREE, `m3_one_rule_for_both` proving the whitespace rule is not a substitute). §5/§6 pin the two ERASURES: an unquoted `${a[i]}` arrives with no `split` marker, and — measured 2026-11-05 as byte-identical shIR — `set -- $z` and `set -- "$z"` (or `set -- $x a` and `set -- "" a`) collapse to the same word node while bash counts 0 and 1 (resp. 1 and 2), so `no_renderer_of_collapsed_words_is_exact` proves no word renderer can be exact and `kept_flag_makes_it_exact` proves a quotedness bit would suffice | 36 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §34; §7 records the FIX in the shared pass (`split_fold` now keeps the marker unless the word is provably NON-EMPTY): `marker_is_the_quotedness_bit` / `fix_is_exact_for_both_spellings` are the post-fix obligations, `fold_is_sound_iff_nonempty` the reason the second verdict is needed, `fold_retained_on_nonempty_constants` that the optimization survives on literals/Int reads/`${#x}`. Measured on the shipped binary: ordering battery **26 of 28** (the two misses are the pinned `arrayIndex` erasure and a pre-existing `$((i+1))` key CC failure), splitting battery **5 of 7** (the empty-expansion rows now pass: `x=""; set -- $x a` → 1, `x=""; set -- $x` → 0, `for w in $e` → 0 iterations; the two misses are the unquoted-`${a[i]}` erasure and the collapsed `${1-unset}` face), corpus gate **625 PASS / 19 FAIL / 7 SKIP** with a FAIL list byte-identical to the pre-round baseline. The quotedness residual is an AST/shIR word-node change — an OFFER across backends per PLAN §11, NOT a C-arm patch |
| `proofs/verus/c_eval_inline.rs` | **C generator**: STATIC-`eval` INLINING — a literal `eval '<text>'` denotes the statements of `<text>`, so `shir_to_c` splices them into the IR BEFORE every analysis (`static_eval_stmts` + `expand_static_evals`) instead of lowering the text at render time (that path stays for a dynamic argument or a text the core parser rejects). A program is modelled FLATTENED to the in-order leaf sequence the analyses fold over, each leaf tagged by how many literal-eval texts enclose it (`0` top level, `k` nested, `-1` opaque `eval "$x"`), so splicing is a per-leaf retag and every fold is a cursor recursion: `expansion_preserves_meaning`/`assigned_invariant` (the rewrite moves no effect and no store target), `census_is_exact` + `fixed_census_is_complete` — THE FIX, and the pre-fix census differs by exactly one clause; `opaque_never_over_declares` (the old census only ever MISSES, so it cannot hide a bug behind a false "declared"); `witness_063_12` + `route_var` (the measured before/after — and the read demotion `_sh_env("result")` is proved to come from the SAME fold, which is why a mid-body declaration could not have fixed it); `dyn_eval_not_covered` (the scope, proved rather than asserted); `expand_idempotent` (the depth bound is a valve, not a semantic) | 20 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §30; fixed 063_12 (`eval "result=$(( … ))"` emitted `_sh_sset(&result, …)` with `result` undeclared — gate `cc` → **PASS**, corpus gate **613/31/7 → 614/30/7**, the only moved entry). Proven non-invasive by `harness/render-all.sh` (a byte-diff of every corpus render through two builds): **649/651 identical**, both differing files are the aimed ones. New harness: `harness/render-all.sh` |
| `proofs/verus/c_unset_scalar.rs` | **C generator**: `unset` on a SCALAR — bash's variable is a PARTIAL map (`None` is `unset`, `Some("")` is `set-to-empty`, and bash tells them apart), while an INT decl can spell neither, so `unset x` emitted NOTHING and `x=5; unset x` kept answering 5 on every face. A scalar the program unsets is demoted to STRING storage (`demote_unset_scalars` + `unset_scalar_census`), where the state exists; the model calls the identification `quot` and proves exactly what it PRESERVES — `q_plain`/`q_len`/`q_arith`/`q_colon_default`/`q_colon_plus` (the emptiness-testing faces, i.e. the fix's whole target) — and what it CANNOT: `no_face_separates` shows no function of the quotient can separate `None` from `Some("")` while bash's `${x-w}` does, so the no-colon residual is an impossibility for string storage, not unfinished work (witness `dash_gap_is_the_set_to_empty_case`, measured `x=""; ${x-w}` → C `w` / bash empty, pre-existing). Plus the pre-fix divergence on the measured numbers (`pref_int_keeps_the_value`, `pref_int_arith`) and the census (`demote_is_a_kind_change`, `demote_hits_the_right_names` — the numeric-only-mutation exception is proved non-decorative, `element_and_flag_are_not_scalar_unsets`). §4 then models the census WALK, because the decision is only as good as its input: the face collector was a hand-written `match` over `IrStmt` whose `_ => {}` tail swallowed `Output`, and `printf '%s' "${x:-}"` IS an `Output` — so `r=$(echo hi) || { x=$?; }` plus `printf "%s=%s" x "${x:-}"` printed `x=0` where bash prints `x=` (measured 2026-11-05; `narrow_walk_misses_the_output_face` is the bug — the same word seen through `echo`, missed through `printf`, proved as an inequality — `full_walk_sees_it_through_every_carrier` the exhaustive `for_each_stmt_expr` that fixes it, `plain_read_is_not_a_face` why a `$x` read must not demote, `exhaustive_walk_is_what_makes_the_demotion_sound` the composition with §3; mutant — restoring the missing arm in the model gives 16v/3e). §5 is the OTHER distinction on the same storage: `-`/`+`/`=` test SET-NESS where `:-`/`:+` test NON-EMPTINESS (measured `x=""; ${x-w}` → C `w` / bash ``, `x=""; ${x+w}` → C `` / bash `w`, `unset x; ${x=w}` → C `` and no assignment / bash `w` then `w`). It proves the fix EXISTS (`presence_renderings_are_exact` — a heap scalar's NULL already is a presence bit, and the `-` arm already emits `(x ? x : w)`), that the shipped arm is wrong on exactly those inputs (`emptiness_render_fails_on_set_empty`, with `emptiness_is_right_on_the_unset_half` explaining why it looked right), and that NO C-side patch can finish it (`collapse_loses_the_colon` + `no_renderer_of_the_collapsed_ir_is_exact`: `${x-w}` and `${x:-w}` reach the renderer as the same `param(":-", …)`, so any renderer exact for one is wrong for the other on `Some("")`; `${x=w}` arrives as `param("", "x=w")`, a "variable" named `x=w`). The remaining work is therefore an AST/shIR operator spelling — an OFFER across backends per PLAN §11 — not a renderer edit; `collapse(Op::Plus) == Op::Plus` shows the `+` half is renderer-only. Mutant — `collapse(Op::Dash) → Op::Dash` gives 23v/2e). The spelling then LANDED: `ParameterExpansionOperator::{DefaultValueNoColon, AssignDefaultNoColon}` + a bare-`=` parser branch + distinct `-`/`=` shIR ops, the C `-`/`+`/`=` arms testing the raw heap pointer (and the missing `:+` store-var arm added — it fell through to a plain read: `x=v; ${x:+w}` printed `v`), and three storage vetoes so presence is representable (no fixed buffer, no `const` lift, no Int). `every_spelling_is_exact` is the result; all fifteen state × face combinations are byte-identical to bash, `${v=w}` stores its default, and the corpus gate is 625/19/7 with an identical FAIL list. The FOURTH member `?` is an ERROR face, so its denotation is a predicate: `${v?w}` errors only when v is UNSET whereas `${v:?w}` also errors on set-to-empty, and the fold turned a runnable program into an abort (`x=""; ${x?boom}` → bash `[]` rc 0, C rc 1). `question_keeps_the_colon` states the collapse + the one disagreeing state, `question_spelling_is_exact` that the NULL-pointer test IS bash's condition (plus a `getenv`-presence case for env-only names); all eight measured `?` cases match on stdout AND exit status | 27 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §31; fixed `t70_unset.sh` (`exec/diff` → **PASS**) plus `parse-dollar-paren-or.sh`/`-pipe.sh`. Blast radius MEASURED by instrumenting the pass (`SH2_DEBUG_DEMOTE`): the exhaustive walk fires on **34 of 651 corpus sources** (the narrow one fired on 3; 31 were silently mis-homed), and the corpus gate is **625/19/7** vs 623/21/7 — the two files above left the FAIL list and none joined it, so the extra demotions cost storage kind, not verdicts. Also fixed while proving it: `seq_write_str_var` aliased a STATIC snprintf buffer into a heap-owning `char*` (`let x=x+1` after an unset died at teardown with `free(): invalid pointer`) — now stored through `_sh_sset`. Still open, pinned: `printf -v x %d 9` is wrong on BOTH storages (measured: Int prints the old value, the string path truncates a pointer) |
| `proofs/verus/c_printf_v.rs` | **C generator**: `printf -v NAME fmt …` writes the FORMATTED OUTPUT — an arbitrary string, not a number. Three analyses disagreed and each produced its own measured divergence: the const census (no `-v` arm ⇒ `n=1; printf -v n '%d' 7; echo "$n"` emitted the CONSTANT `n=[1]`, bash `n=[7]`), the storage-kind verdict (Int/uint8 target received a `char*` — measured `176`, and a number cannot spell `"abc"` at all), and the length bound (`char n[2]` sized by `n=1` while `%s` can write 40 bytes). One classification fixes all three: a `-v` target is a partial-map, TEXT-valued name (the family `c_unset_scalar` demoted on ABSENCE). Model: `Str`/`atoll`/`canon`, storages `SStr`/`SInt`, `observed(k,t)`; proves string storage is faithful on the text face and inert on the arithmetic face, int storage is faithful EXACTLY on canonical spellings (`int_store_faithful_iff_canonical`, so no width helps), the formatted write has no static bound, and the census identity `sites_pre_fix + sites_true(filter -v) == sites_true` — with `pre_fix_fold_is_unsound` as the stale-value witness and `single_write_fold_is_sound` as the converse. Measured `176 ≠ 9` is pinned as a witness, NOT derived (no address space in the model) | 22 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §32. Fixes: the copy-propagation transform now counts the `-v` write (**a shared transform: this half is an OFFER to the other backends** — `./fail` 560/3 and `fail-estree` 562/1 unchanged), the C demotion census demotes the target, and its length bound is dropped (heap). Also fixed: the `strcpy(name, buf)` arm had no `;` (cc rejected the program the first time the arm became reachable). C gate 623/21/7 vs 622/22/7 before — `000__04h_complex_examples.sh` fixed, no file newly failing. Tripwire: `copy_propagation::tests::printf_v_is_a_write_site`, proven both ways |
| `proofs/verus/c_let_scope.rs` | **C generator**: `let` under a GLOB-MARKED word. The core prefixes any unquoted word that could pathname-expand with `\x01SH2GLOB\x01`, so `let u=u*2` reaches the renderer as `\x01…u=u*2` — not arithmetic — and both native paths declined it; the arm fell back to running `(( … ))` in a CHILD shell, which pushes the old value down, leaks the marker into the child's text, and has no write-back. Measured `u=7; let u=u*2; echo "[$u]"` → bash `[14]`, C `[7]`: silent data loss with rc 0. Model: a Store as a finite map, two Modes (`Native` writes the parent, `Child` writes a discarded fork), `after`/`visible`/`status`; proves `child_write_is_invisible` (the parent keeps its value whatever the child computed), `modes_disagree` (so a fallback across modes is a correctness choice, not a perf choice), `child_site_reports_success_without_effect` (why it was silent), `strip_recovers_the_text` + `marked_text_is_not_arithmetic` (the marker is a FLAG, not part of the value), `every_assignment_shape_is_native` (the licence for the fix) and `fallback_is_additive` (the native parse runs iff `let_render` declined, so no shape that rendered before changes) | 18 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §33. Fix: `strip_glob` before the arithmetic parse + the NATIVE-PARSE fallback for assignment text (`let u=u*2`, unspaced). **Plus the ERROR path (same round):** arithmetic is PARTIAL — `Outcome = Val/Err`, `ev_div` errors on a zero divisor while `rendered_div` is total (`(r == 0 ? 0 : l/r)`, C would SIGFPE), so the value 0 is a lie only the STORE can repair. `arith_static_zero_divisor` (a `/`/`%` whose divisor folds to constant zero) now suppresses the store at BOTH assignment sites — the `let` arith-assign arm and the statement hook before the speculative-shadow arm — measured `u=7; let u=u/0` → `[7] rc=1` (was `[0] rc=1`), `(( u=u/0 ))` likewise, `let u=u/2` control `[3]`. Proved: `semantics_errors_on_zero`, `render_is_total_where_semantics_errors`, `detection_is_sound`, `error_aborts_the_store` (both modes), `error_status_is_one` (Err and Val(0) agree on status 1), `detection_is_incomplete` (the honest limit), `both_sites_share_one_predicate`. C gate 623/21/7 — same totals as the previous round. **Plus the EXPANDED word (same round):** `let n=$x*2` arrives as `Interpolate([lit "n=", getVar(x), lit "*2"])`, not a `Str`, so the arm's `Str` pattern never matched and the builtin fell to the **no-op tail** — `x=4; x=5; let n=$x*2` → bash `[8]`, C `[0]` with rc 0 and no store emitted at all (measured; wider than the `${#a[@]}` case it was pinned for — the whole `let`-with-expansion family). Fix: `interp_let_text` reconstructs the arith text for the shapes with a faithful textual spelling (`getVar` → a BARE NAME, `${#a[@]}` → kept textual for `subst_array_counts`) and reuses the native route; a lookahead refuses `$x1` (a name followed by a name character is one word), and the route is gated on `store_read`'s own predicate (`store` / type-verdict membership) because the native store writes the C IDENT while a Str-homed var is READ through `_sh_env` — a different home (registering the var instead flipped reads onto a NULL decl and **aborted**, measured). Proved: `name_read_agrees_with_expansion` (the expansion's value and the bare-name arith read agree), `reconstruction_has_no_dollar` (the arith parser refuses `$` operands by design), `undelimited_name_is_refused` (the lookahead), `store_is_sound_when_homes_agree` / `native_store_requires_the_ident_home` (one predicate, so a store can never pick the other home) and `gate_is_conservative` (where it declines, the child site's write was already a parent no-op). Measured after: six-shape probe all matching (`${#a[@]}` → 3, `${#a[@]}+1` → 4, `$x` → 4, `$x*2` → 8, `${x}*2` → 8, `x-1` → 4). **Plus the multi-word LIST (same round):** `let` takes a list and reports the **last** word's truth; the arm rendered only `items.first()`, so the tail vanished and the status came from the wrong word — measured `let c=3 0` → bash `rc=1`, C `rc=0` (the `0` never evaluated) and `let d=0 4` → bash `rc=0`, C `rc=1`. (Pure-assignment lists like `let a=1 b=2` were already split by the core transform, which is why only the MIXED list was wrong.) Fix: the per-word renderer is factored into `let_word_c` and the multi-word call is rendered as a comma list, so each word's stores land in order and the LAST one leaves its verdict in `_sh_rc`; a word that needs the child site falls the whole call back to the single-word path (a site inside a comma list is a fork whose write never returns). Also closed: the `${#a[@]}` branch bypassed the HOME gate and emitted a store to an undeclared ident — a C COMPILE ERROR (`a=(1 2 3); let n=${#a[@]}` → `'n' undeclared`, measured); the gate now covers both branches, so that shape compiles and declines. Proved: `status_of_words` (the list's status is the last word's), `status_is_not_the_first_word` (a witness set where the first-word rule is wrong in BOTH directions), `status_is_the_last_word`, `words_compose_left_to_right` + `composed_store_reads_back` (`let e=5 e=e+1` → 6 requires the second word to see the first's write) and `empty_list_is_failure`. Measured after: `let a=1 b=2`, `let c=3 0`, `let d=0 4`, `let e=5 e=e+1`, `let f=1 g=7 h=9` all match bash. **Plus ARRAY names in arithmetic (same round):** bash's arith denotes ELEMENT 0 for an array name on BOTH sides; the generator wrote the C ident (`a = temp`, `error: assignment to expression with array type` — a COMPILE ERROR for int and word arrays alike) and read it as a decayed pointer (`a=(1 2 3); let b=a+1` → 1 where bash gives 3). Fix: the write goes to element 0 keeping the other elements and the length (`a=(1 2 3); let a=9` → `[9][3][3]`, `a=(); let a=5` → `[5][1]`), compound ops read element 0 first (`let a+=4` → 5), and the read is presence-guarded (`atoll` never sees a NULL word slot). The subtle part is OWNERSHIP: the statement path already has the documented subscript-0 rule, so the arith arm stores only under a `let_owns_store` flag and is otherwise value-only — emitting both double-evaluated the RHS and `let a+=4` printed `[9]` (measured). Proved: `name_ignores_every_other_element`, `read_is_the_element_not_the_array`, `store_writes_only_element_zero`, `double_store_compounds` (the `[9]` witness as arithmetic: `a0+2*rhs`), `one_owner_only`. The ASSOCIATIVE target is the same rule with the string key `"0"` (`declare -A m=([a]=1); let m=5` → `[1][5]`): value-only in the arith arm, since the statement path's element writer owns it and `m = …` on a k/v/n table is `'m' undeclared` (measured). STILL OPEN, pinned: an expanded `let` whose target is Str-homed still reaches the child site (`x=2; y=3; let n=$x+$y` → C `[]` where the var is env-homed); a divisor that is zero only at RUN time still stores 0 where bash aborts; `u=$(( u/0 ))` is FATALLY fatal in bash (the shell exits) which the total divider continues past; `${#a[@]}` in an unquoted `let` word (an Interpolate, not a `Str`) still reaches the child site |
| `proofs/verus/c_redirect.rs` | **C generator**: the redirect reorder + word quoting — fd-prefix parse round trip, the `'`-splice quoter (`run`/`esc` state machine), the dup/close raw arm's quote-freedom, `commute_here` + `reorder_safe` (emit_order preserves the fd table under `safe(rds)`) with `n1_fd0_conflict` proving the condition necessary, and the ps-flip monotonicity (`flip_safe_mono`); named mutants m1-m3 pin the escape/quoting/terminator claims | 46 verified, 0 errors | landed, gated — see `C_UB_PROOF.md` §29; measured 2026-11-01 `/tmp/redprobe` (bash FROM_FILE vs generated FROM_HEREDOC); model fix: `reads0` widened to `W|Wc|A|R|Rplus` to match `written`'s mode set (the frame rule was provably false) |
| `proofs/verus/append_store.rs` | `transforms/append_to_store.rs` (counted-loop append → indexed store, per-trip + whole-loop induction) | 20 verified, 0 errors | landed, gated — store-forward sweep |
| `proofs/verus/split_set.rs` | `transforms/split_set.rs` (isSmallInt routing partition soundness + merge agreement) | 14 verified, 0 errors | landed, gated — store-forward sweep |
| `proofs/verus/echo_return.rs` | `transforms/echo_return.rs` passes 2–4 (body echo → Return + call-site echo(fnValue)) | 13 verified, 0 errors | landed, gated — store-forward sweep |
| `proofs/verus/arith_forms.rs` | `transforms/arith_forms.rs` (let-arg text → Assign/IncDec arith → Assign stmt) | 15 verified, 0 errors | landed, gated — arith-lowering sweep |
| `proofs/verus/counted_while_forinit.rs` | `transforms/counted_while_forinit.rs` (init + counter-while + step → ForInit) | 13 verified, 0 errors | landed, gated — arith-lowering sweep |
| `proofs/verus/scc.rs` | `shir_passes/scc.rs` (SCC contract + condensation acyclicity) | 21 verified, 0 errors | landed, gated — verdict-analyses sweep |
| `proofs/verus/used_before_decl.rs` | `shir_passes/used_before_decl.rs` (must-defined dataflow) | 15 verified, 0 errors | landed, gated — verdict-analyses sweep |
| `proofs/verus/maskable.rs` | `shir_passes/maskable.rs` (mask_threshold soundness) | 12 verified, 0 errors | landed, gated — verdict-analyses sweep |
| `proofs/verus/lifetime.rs` | `shir_passes/lifetime.rs` (span coverage + escape conservatism) | 14 verified, 0 errors | landed, gated — verdict-analyses sweep |
| `proofs/verus/numstr.rs` | `shir_passes/numstr.rs` (seed-table consistency) | 11 verified, 0 errors | landed, gated — verdict-analyses sweep |
| `proofs/verus/numeric_observed.rs` | `shir_passes/numeric_observed.rs` (marked ==> all-uses-numeric) | 10 verified, 0 errors | landed, gated — verdict-analyses sweep |
| `proofs/verus/str_splice_fold.rs` | `transforms/str_splice_fold.rs` (Interpolate → StrSplice denotation identity) | 11 verified, 0 errors | landed, gated — string/cursor sweep |
| `proofs/verus/str_chop_cursor.rs` | `transforms/str_chop_cursor.rs` (grab/strip cursor dynamics + read law) | 17 verified, 0 errors | landed, gated — string/cursor sweep |
| `proofs/verus/hoist_loop_invariants.rs` | `transforms/hoist_loop_invariants.rs` (leading invariant run → prologue, n ≥ 1) | 22 verified, 0 errors | landed, gated — loop-hoist |
| `proofs/verus/direct_calls.rs` | `transforms/direct_calls.rs` (capture-of-pure-function → direct call) | 19 verified, 0 errors | landed, gated — suites-then-proofs trio, **re-authored 2026-10-30** (the originals were lost with the sweep files; see §(b).1 note) |
| `proofs/verus/cat_read.rs` | `transforms/cat_read.rs` (statement cat → ForEachLine) | 18 verified, 0 errors | landed, gated — suites-then-proofs trio, re-authored 2026-10-30 |
| `proofs/verus/grep_o.rs` | `transforms/grep_o.rs` (grep -o shapes → grepMatches) | 19 verified, 0 errors | landed, gated — suites-then-proofs trio, re-authored 2026-10-30 |
| `proofs/verus/exec_call_fold.rs` | `transforms/exec_call_fold.rs` (payload-free Exec in carrier → canonical exec call) | 8 verified, 0 errors | landed, gated — carrier-canonicalization |
| `proofs/verus/interp_lit_merge.rs` | `transforms/interp_lit_merge.rs` (frozen-literal Expr part → Lit + adjacent-Lit merge) | 24 verified, 0 errors | landed, gated — part-canonicalization |
| `proofs/verus/strip.rs` | `shir_passes/strip.rs` (ForInit → Block(init + While) + continue splice; first-class `Continue` ONLY — the legacy `Expr(Call("continue"))` arm was deleted upstream in `9928671cd`, so the model no longer claims that fix) | 12 verified, 0 errors | landed, gated — forinit-lowering, re-pinned 2026-11-08 |
| `proofs/verus/counted_arith_forinit.rs` | `transforms/counted_arith_forinit.rs` (structured-Arith counted-while → ForInit) | 12 verified, 0 errors | landed, gated — arith-recovery |
| `proofs/verus/arr_load_fwd.rs` | `transforms/arr_load_fwd.rs` (single-def element load → forwarded reads) | 37 verified, 0 errors | landed, gated — element-forward |
| `proofs/verus/isolate_accumulate.rs` | `transforms/isolate_accumulate.rs` (single-use pure temp → inlined use) | 18 verified, 0 errors | landed, gated — temp-isolation |
| `proofs/verus/lane_private.rs` | `shir_passes/lane_private.rs` (lane-nest classification verdict) | 12 verified, 0 errors | landed, gated — lane-verdict |
| `proofs/verus/analysis.rs` | `shir_passes/analysis.rs` (RuntimeFootprint verdict) | 21 verified, 0 errors | landed, gated — footprint-verdict |
| `proofs/verus/loop_opt.rs` | `shir_passes/loop_opt.rs` (leading-run hoist) | 21 verified, 0 errors | landed, gated — loop-hoist-shir |
| `proofs/verus/restructure.rs` | `shir_passes/restructure.rs` (goto-elimination shapes) | 20 verified, 0 errors | landed, gated — restructure-carveout |
| `proofs/verus/optimize.rs` | `shir_passes/optimize.rs` (census shapes + drop) | 17 verified, 0 errors | landed, gated — optimize-delta |
| `proofs/verus/type_query.rs` | `transforms/type_query.rs` (`type NAME...` -> `echo` of the answers) | 17 verified, 0 errors | landed, gated -- the unproven Tier-1 candidate: answers come from the program's functions and the true-builtin table (61 entries, measured), or the call is kept. Proves names+ORDER preserved (so `type f | head -1` reports f), every emitted line answered (`all_classified`), and a mixed known/unknown list refused WHOLE -- no partial answer swallowing bash's not-found line. Function beats builtin; an external is never answered. Table MEASURED Rust-side, since the model takes it as a parameter: `builtin_table_matches_compgen` asserts it equals `compgen -A builtin` on the bash that runs the suite (which is how `.`, `:`, `break` were found missing from a table that had been recited as 58), and `builtin_table_excludes_externals_and_has_no_copies` keeps `ls`/`head` out and the list duplicate-free |

**Obligation accounting for THIS checkout** (measured 2026-11-08 against
`harness/verus-gate.sh`'s `MODELS` list — the only authority for what the gate
actually verifies — split with `git -C sh2perl ls-files proofs/verus`, i.e. by
whether a fresh clone of the branch receives the file):

| | models | obligations |
|---|---|---|
| `c_*` (C generator), committed on the branch | 18 | 685 |
| `c_*`, untracked here — branch-only | 6 | 180 |
| transform/shIR, committed on the branch | 20 | 382 |
| transform/shIR, untracked here — branch-only | 33 | 558 |
| conditional trio, committed on the branch | 3 | 53 |
| **committed on the branch — what a clone verifies** | **41** | **1120** |
| **untracked here — verified by this checkout only** | **39** | **738** |
| gate total (every `MODELS` entry) | 80 | 1858 |
| retired i32 pair — verified, never counted (`RETIRED_MODELS`) | 2 | 12 |

Of the 1858 obligations the gate runs here, **738 across 39 models come
from files that are not on the branch**: they exist only as untracked files in
`sh2perl/proofs/verus/`. Quote **1120** as the number the branch proves, and quote
738 only as "present in this checkout, absent from the branch" — never as
verified by CI or by a clone, which fails those 39 entries. The
Tier-1-only view is **1067** in-tree against 738 branch-only: the conditional
trio's 53 obligations are committed but sit outside the Tier-1 totals (they
have their own paragraph below). Until 2026-11-08 the
gate reported them as `? verified, ? errors`: an absent file was handed to
Verus, so a missing model was indistinguishable from a failing proof in a log
skim. `check_model` now has an existence pre-check that names the missing file.

The retired i32 pair (`interval.rs` 5, `i32_bounds_exec.rs` 7 — target never
landed, §(d) P0(iv)) is 12 obligations that count toward no Tier-1 total — the gate still verifies
them (as `RETIRED_MODELS`), so they cannot rot silently, but a green count there
is evidence about a design that never shipped; the
postcondition on the retired exec form lives on its executable function
instead. Every active model has checked failing mutants (see §(b).3 — 38
mutants over 36 models).

The totals this section carried before 2026-11-08 (492 active, 504 with the
retired pair, 976 transform-side, 1841 gated) did not reproduce against either
the gate's `MODELS` list (which sums to 1858) or against the per-file table
(whose 84 rows sum to 1892: 12 from the retired i32 pair, which the gate no
longer runs, plus 22 from `escape_classes.rs` and `f32_narrow.rs` being listed
twice — netting to exactly 1858, the gate's own sum), so they are replaced by
the measured split above rather than re-derived. Every per-file count in the table
is the number the pinned binary reports for that file today, except `strip.rs`,
re-pinned 13 → 12 on 2026-11-08 when its target lost the legacy-continue splice
arm (see that model's SOURCE DRIFT note).

The **conditional models** (`const_status_cond.rs`, `background_decide.rs`,
`process_subst.rs`) are gated but excluded from those totals: each mentions the
denotation of a statement, so none is a Tier-1 verdict theorem. See
`docs/transform-verification.md` §"The middle rung".
 Their proofs, and why Verus rather than
Isabelle fits them (the target is Rust that *produces* the C), are in
`C_UB_PROOF.md` §13–§14.
(NOTE, 2026-11-05: a concurrent worker rolled the tracked tree back to
`1445f283b` mid-session, which reverted `src/c_backend.rs` and five model files;
the pre-rollback snapshot survived as a dangling commit and all six files were
restored from it, so `c_sparse_array` (45), `c_assoc_array` (54) and
`c_join_ifs` (104) verify at the counts listed here again. Ten models named in
`harness/verus-gate.sh` were still absent from `proofs/verus/` (another worker's
rows: `strip.rs`, `analysis.rs`, `loop_opt.rs`, `restructure.rs`,
`optimize.rs`, `counted_arith_forinit.rs`, `arr_load_fwd.rs`,
`isolate_accumulate.rs`, `lane_private.rs`). That is no longer the state: as of
2026-11-08 all 80 model files the gate names are present and every entry
verifies, but most of them are UNTRACKED — see the in-tree / branch-only split
above, which is the distinction absence used to stand in for. `C_UB_PROOF.md`'s closing "Tree state" subsection
carries the detail.) The eight pre-existing counts — and
their seven mutants — were independently reproduced on 2026-10-24 with the
pinned binary (see §(b).3); the three new counts (27/41/25) and their three
mutants were checked the same day in the same session; the P9 trio count
(22) and its mutant (19v/3e) were checked 2026-10-26 in the landing session,
and the three branch counts (53/10/35) were re-verified on the landed files
the same day — no re-proof, byte-identical to the pushed branches.

Correction (2026-10-24), retired 2026-10-26 — see §(d) P0(iv): the two i32
models' target, `arith_bounds`, is absent from `src/` — and from every commit
in recorded history. The live estimator is `arith_abs_bound`/`arith_is_i32`,
proved in Isabelle (`I32Provable.thy`). The two Verus files still verify
(12 green obligations about a superseded design — re-checked after the
retirement banner, still 5/7), but their fidelity premise is void, not stale —
and the sync extractor has no target (its FATAL on the live tree was
verified live: correct behavior, wrong reason to celebrate). They are out of
the gate (`harness/verus-gate.sh` MODELS) and out of the active totals above.
All eight were run under Verus `0.2026.10.18.7d82994` with
rust toolchain `1.99.1` (`--triggers-mode silent --rlimit 40`, `--rlimit 60`
for the exec form and const-status-cond, `--rlimit 80` for redundant-store-elim). The pinned binary lives at
`/opt/verus-0.2026.10.18.7d82994/verus` (re-fetch
`release/0.2026.10.18.7d82994` x86-linux if it ever goes missing). Still no gate runs
these files — re-running one is a manual command from the README, and a
`harness/verus-gate.sh` now exists and is green (Tier 0, landed 2026-10-24):
it re-runs the eight models with exact-count assertions (exit 1 on count
mismatch or Verus error, exit 2 if the binary is absent — never read
"not installed" as green) plus the sync registry described in P0(v). As of
2026-11-09 the gate checks every model and every baseline it names — 123
passed, 0 failed, 4 extractors refusing rather than skipping — and the one
thing still open is pushing the branch, because a fresh clone of `origin`
sees none of it (§(d) P0(v)).

## (a) Which transforms have been proven correct with Verus

Strictly speaking, none — §(b) explains why "proven" needs scare quotes
here. What exists is five checked soundness **models**, one per target:

**1. `i32_provable` — `arith_bounds` interval soundness (`interval.rs`, 5).**
The obligation the renderers need: a marked node's value lies in its
computed interval, and the interval is inside i32's `[-2^31, 2^31-1]`.
Covers the constructors the analysis touches with the exact operator rules
(`+`/`-`/`*`/unary `-`/ternary hull). Carve-outs: it says nothing about the
emitted C (see `C_UB_PROOF.md`), and `i32_provable` currently has no
renderer consumer — the verdict changes no emitted byte. This is also the
proof Isabelle could *not* do: the Isabelle version of the product corner
bound stalled on unfolding `min`/`max`, while Verus's `nonlinear_arith`
discharges it once the four-corner disjunction is supplied.

**2. Same obligation, exec-carrying full-enum form (`i32_bounds_exec.rs`, 7).**
Duplicates `arith_bounds` over the real `ArithAst` shape (all ten
constructors, including `Assign`/`IncDec`/`Index`/`Other`) with the
postcondition ON the executable function — `(found, lo, hi)` triple instead
of `Option`, explicit guards instead of `?`. Two mechanical rewrites
separate it from the source (match-on-`&str` → if-chains,
`then_some` → explicit if); 30 recorded probes found the working shape
(tuple postconditions over self-built values prove nothing; `checked_*`
crosses into `as int` via vstd specs). Strongest artifact of the five, and
still a duplicate, not an annotation (see §(b).1).

**3. `optimize_stmts` Pass 1 — self-assign + unused-`Declare` elim
(`optimize_stmts.rs`, 8).** Note the target is *not* in `transforms/` but
`src/ir.rs:15768`: the `is_self_assignment` filter and the init-less
`Declare` filter with the `collect_referenced_vars` census. Theorem:
elimination preserves the final store from any closed start state (every
referenced name bound). The model pins the census subtlety empirically —
the real census counts a `Declare`'s *own* names as references, so a lone
`Declare[x]` is KEPT — and Pass 0.5 folding is out of scope (separate
constant-fold obligation).

**4. `dead_fn_elim` (`dead_fn_elim.rs`, 25).** Passes 1–4 over def/call/other
statements with interned names: a def survives iff its name occurs as a
literal anywhere. Theorem: elimination preserves the call trace (externals
included) at every fuel bound — hence for unbounded runs. Worklist dispatch
with first-def-wins lookup; the `KEEP_VARIABLES` hatch is a parameter.
Known gap, flagged not proved: the real `collect_expr_strs` skips
`InterpPart::Lit` fragments, so a function referenced *only* through a
concatenated literal is dropped by the real code but kept by the model —
the model is conservative (superset keep-set), and the proof covers every
drop the model makes.

**5. `dead_store_elim` core (`dead_store_elim.rs`, 45).** Read/write census,
purity gate, and purge over store + observable-trace semantics. Theorem:
purging dead stores preserves the event trace and every live variable's
final value from any closed start store. Induction invariant is
live-agreement plus trace equality. Deliberate reductions: the Const guard
is modelled as single-write; dynamic writes make the dead set empty
(uniform outcome, no special case); the escapes set is not modelled
(checked arm-by-arm to be redundant with reads); indexed targets,
case-pattern/`Str`-embedded/`[*]`-IFS/`Ext` reads, and nested-statement
recursion are out of scope — the model covers exactly the droppable scalar
class over flat sequences. **This proof already paid for itself:** modelling
it exposed the soundness bugs in the sibling `redundant_store_elim.rs`
that item 6's effort fixed and proved (plus a third found during that
effort).

**6. `redundant_store_elim` (`redundant_store_elim.rs`, 53).** A scalar
store `x=A` at `i` drops iff a later scalar store to `x` overwrites it
with a clean middle and a clean justifier. Theorem: purging is
observationally exact — same trace, same value for every variable.
Proof is a shadow argument (dropped-then-overwritten vars are
unobservable; chains end at kept stores). Covers the FIXED pass: three
soundness holes repaired in the same effort (arith side effects,
index reads, Str-embedded reads — each with failing-first regression
tests), and both fix-mutants go red. Out of scope, all flagged:
`Ext`-node reads (another worker's uncommitted arm at time of writing),
case-pattern text, env-dump builtins in captures, nested-statement
recursion (same scan per function body), multi-target assigns. Seven
fidelity pins, all mirrored (3 in-module bug tests, cascade + observer
+ index-read in `pin_mirrors.rs`). Branch `verus-rse`, on GitHub,
unmerged pending the `Ext`-WIP owner's rebase (overlapping `expr_reads`
hunk, both keep-direction).

**7. `array_len_fold` (`array_len_fold.rs`, 10).** The `fold()` node
rewrite with refuse-on-doubt guards. Theorem: folding preserves the
evaluated value (element count of the same array binding) from any
store. Both spellings evaluate against the same binding, so the fold
is a renaming with identical denotation; the guards only ensure the
slice spelling MEANS element count. Guard order mirrors the code.
Identifier-ness is an oracle; traversal is out of scope (per-node
theorem). Eight pins, all shape-mirrored 1:1 in-module (dead_fn_elim
precedent — no `pin_mirrors.rs` addition needed).

**8. `const_status_cond` (`const_status_cond.rs`, 35).** The 7-row
restructuring table with refusals. Theorem: rewriting preserves the
(status, print-trace) run from any start status at every fuel bound.
Execution threads the header's bash exit-status rules (body-never-ran
reports 0, taken-body reports last status, untaken-if reports 0);
(fuel, size)-lexicographic induction with two general loop lemmas
covering entry and tails uniformly. Eleven pins: all 7 rows as
shapes, words/elsifs/non-const refusals, plus a fuel-2 behavior run.
Two mutants go red (dropped prepend 31/3, wrong collapse status
33/1). `do…while` omitted (refused in code, nothing to refuse);
StatusZero is observably `([], 0)`. All shape pins mirrored 1:1
in-module (11 tests); the behavior pin is model-internal.

**9. `copy_propagation` (`copy_propagation.rs`, 27).** The substitution
core: single-def table (parameter, with a soundness precondition tying
each entry to the program's unique literal write), the def-before-read
gate, and the read-site fold. Theorem: folding preserves the run
(final store and event trace) from any closed start store. The
induction is single-store (both sides from the same store — full step
equality threads through, since pointwise store agreement cannot prove
`Map` `==`); the invariant is `prefix_ok` (every already-executed def
holds its literal value), and the two-write contradiction
(`count == 1` rules out the second writer) is the lemma that makes the
prefix survive a step. Six fidelity pins mirror the transform's own
tests (fold-after-def, refuse-before-def, multi-def count, copy-def
unfolded, opaque-statement refusal, both-reads fold). The gate-dropping
mutant goes red (25/2). Copy defs, arith/string-digit gates,
`param-const-fold`, `AffixStrip`, quoted-`Interpolate` defs: all out of
scope (the same core; the extensions reuse this gate).

**10. `function_purity` (`function_purity.rs`, 41).** The verdict
predicates and the call-graph fixpoint: purity as the meet over the
`Impure < Emulable < Pure` lattice, per-statement meets, calls as
callee-verdict meet arg-purities. Theorem: under a consistent table, a
Pure verdict means an empty event trace at every fuel and an Emulable
verdict means a capturable-only trace at every fuel. The fixpoint
iteration is not modelled; the theorem takes a consistent table as a
parameter (the real loop's limit satisfies it by construction), and
consistency has three load-bearing conjuncts (recomputation never
drops below the verdict, verdicts land in the lattice, keys are
defined names — dropping any one admits a concrete unsound table, all
found during the proof: the `v[f] = 5`-for-undefined-`f` class makes
`Call(f, [])` compute Pure yet dispatch a `RunCall`). Seven fidelity
pins mirror the verdict's behavior (pure-assign body, Output-is-Emulable,
Other-is-Impure, unknown-callee-Impure, pure-call, impure-arg taint,
pure-runs-silent). The Output-as-Pure mutant goes red (39/2). The
`inline_pure_fns` consumer is out of scope (Tier-3-flavored).

**11. `test_lowering` Tier-1 leaves (`test_lowering.rs`, 25).** The
per-leaf value preservation of the four lowering families — nonempty
(`-n`/`-z`), string equality (`==`/`=`/`!=` as `Not(Ne)`/`Ne`),
numeric comparison (six ops over i64-range ints), glob-affix
(`strHasPrefix`/`contains`/`strHasSuffix` + negations) — over
`Seq<char>` strings with var/literal operands. Theorem: each lowered
leaf evaluates to the same boolean as the source test text, from any
closed store (plus operand-level top lemmas). The full pass obligation
needs statement semantics; these leaves are the Tier-1 carve-out.
Eight fidelity pins mirror the transform's own tests. The
dropped-`Not` mutant goes red (24/1) — the perl-numeric-`==` bug the
`Not(Ne)` encoding exists to avoid. Status liveness, cond position,
nocasematch, compounds, self-recursion: all out of scope (Tier-3).

**12. P9 ELIM trio (`elim_trio.rs`, 22).** Three per-pass soundness
obligations over store + observable-trace semantics, proved 2026-10-26 and
gate-registered (`elim_trio.rs:22:40`): (a) `const_condition_elim`
pruning (constant-`If` to the taken branch, `While(false)` drop,
`DoWhile(false)` to its body) preserves the run; (b)
`unreachable_after_exit` truncation after a direct `Exit` preserves the run
(the abort flag makes the tail unobservable; nested exits never deaden the
outer list); (c) `merge_init_assignments` adjacent-pair folding under the
literal-default + pure-RHS + no-self-read gates preserves the run (the
default store is overwritten before any read observes it). Eight fidelity
pins (UNMIRRORED by design — suite-less sources); the inverted-branch
mutant goes red (19v/3e). `eval_cond` string parsing, the census gates as
parameters, and the `Exit`-producer firing gap (no shell-lowering producer
constructs `IrStmt::Exit`/`Return` today — same dead-path class as
`for_recovery`) are out of scope / flagged. Coverage sync registered
(`verus-sync-coverage.sh:elim_trio`).

**13. `slice_identity` (`slice_identity.rs`, 10).** The zero-offset fold:
`param("slice", NAME, OFF, LEN)` with a plain-identifier NAME, literal
`OFF` in `{"", "0"}` and absent/empty `LEN` folds to the plain read and
denotes the same string from any store. Eight fidelity pins mirror the
transform's own tests (three fold shapes, real-offset/length refusals
including the `"0"`-length-is-empty rule, non-identifier refusal,
no-change report); the dropped-identifier-gate mutant goes red (9v/1e)
while the value theorem holds — the pin, not the lemma, is load-bearing
(the array-len-fold offset-guard shape). Identifier-ness is an oracle;
traversal is per-node (array_len_fold precedent).

**14. `case_lowering` (`case_lowering.rs`, 29).** Per-pattern value
preservation (Exact as `Not(Ne)`, affixes as the shared primitives, Glob
via the shared-engine oracle called identically on both sides) plus the
dispatch theorem: the if/elif chain with catch-all-as-else and
dropped post-catch-all selects the same branch as the source case for
every subject. Fourteen fidelity pins mirror 13 of the transform's 16
unit tests (the dropped-tail shape is model-internal); the Prefix-lowered-
to-Suffix mutant goes red (27v/2e). Quote classification is parsing
(classified input, Refused = whole-case refusal); nocasematch is a
parameter; the impure-subject bind is identical-value substitution;
traversal is per-site. Firing: 38/563 on `--target rs` (0/563 on `--target
pl` by the `perl`-vs-`pl` gate naming — measured).

**15. `else_if_flatten` (`elseif_flatten.rs`, 22).** Collapsing
`else { if (no elsifs of its own) }` into the parent's `elsifs` —
repeatedly, so any depth lands in one vector — preserves the selected
body under every valuation. Conditions are opaque predicate ids (the
rule is structural; the source flattens through `BinOp(And)`
conditions). The chain loop is fuel-bounded (fuel = If count, strictly
dropping per firing step) with first-hit scan lemmas. Four fidelity
pins mirror the 4 unit tests; the dropped-else-body mutant goes red
(18v/4e). Status threading is out of scope (Tier-3).

**16. `seq_range_for` (`seq_range.rs`, 11).** Rewriting
`for v in $(seq …)` to bare `Range{start, end}` preserves the
iterated integer list (1-arg from 1, 2-arg as-is, descending = empty on
both sides). Eight fidelity pins mirror the 8 unit tests (two lift
shapes, descending-is-empty, step/float/leading-zero refusals,
body-write/setVar-write refusals, huge-span refusal); the accept-step-
forms mutant goes red (9v/2e). Literal parsing and the shape match are
inputs; the body-write scan is a parameter; backend Range consumption
is renderer contract.

**17. `ternary_desugar` (`ternary_desugar.rs`, 9).** Rewriting the C
frontend's `ternary(cond, a, b)` to `Ternary{cond, then, else}` with the
normalized `test`/`arith` condition — plus the standalone
`testArith(s)`-to-`arith(s)` normalization — preserves the selected
branch (the engines are shared-oracle calls, the case_lowering glob-arm
shape). Six fidelity pins record the mapping table; UNMIRRORED — the
transform has no unit suite (suite-less source, recorded). The
test-string-routed-to-arith mutant goes red (8v/1e). The `is_test_string`
split is parsing; the estree-path exemption is placement; traversal is
per-site. Ingress-only (fires on C-frontend input, 0/563 in-registry by
construction).

## (b) How rigorous this is, and how closely it matches the real code

**1. Every artifact is a hand-duplicated model, not a proof of the code.**
Verus cannot take a crate dependency on the 17k-line `sh2perl` crate, so
each file re-states the transform's logic (shrunk to a core calculus: three
statement shapes, interned names, structural purity) with the theorem on
top. Nothing in the toolchain ties the model to `src/` — the five files
and the five implementations can drift apart silently, which is exactly the
failure mode the exercise exists to catch.

**2. What ties exist are empirical or pending, not mechanical.**
Per file: *fidelity pins* — properties checked against the running code
before modelling (the `Declare`-keeps-itself census behavior, elim keep/drop
examples, six purge scenarios); see the `*_pins` lemmas. *Pending:*
`harness/verus-sync.sh` regenerates a SYNCED region from `i32_provable.rs` and
fails loudly when the source outgrows its extractor patterns. Since 2026-11-08
it is REGISTERED in the gate's `SYNCS` array (the only legacy 2-field entry, so
it regenerates and diffs rather than pinning guards), and it is retargeted at
the LIVE estimator: the two abs-bound consts (hoisted out of `arith_abs_bound`'s
body), `arith_abs_bound`, `arith_is_i32`, and the `ArithAst` constructor list.
`proofs/verus/i32_bounds_sync.rs` is committed, so the entry is green.

Its contract is a TRANSCRIPT, not paste-ready Verus: two mechanical rewrites
(match-on-&str -> if-chains, `(pred).then_some(e)` -> explicit if), everything
else verbatim — `?`, the `cap` closure and `checked_*` stay as the source writes
them, because translating those is proof work, not drift checking. For the
region it covers, "the model matches the code" is mechanical: change any of
those functions and the gate goes red until the baseline is regenerated.

**3. The obligations are not vacuous — every transform model has a checked mutant (38 mutants over 36 models), plus the C-generator mutants.**
Interval with a wrong product corner: 4 verified, 1 error. `Assign` writing
a constant: 7 verified, 1 error. Inverted keep rule: 23 verified, 2 errors.
Dropped purity gate: 43 verified, 2 errors. Restored `Arith(_) => true`
purity lie: 51 verified, 2 errors. Restored index-blind `stmt_reads`:
51 verified, 2 errors. Dropped `"@"`-offset guard: 9 verified, 1 error.
Dropped command prepend: 31 verified, 3 errors. Wrong collapse status:
33 verified, 1 error. Dropped def-before-read gate: 25 verified, 2 errors.
Output-as-Pure verdict: 39 verified, 2 errors. Dropped `Not` on Eq:
24 verified, 1 error. Multi-part interpolate first-lit fold: 9 verified, 2 errors.
Dropped 0+X canonicalization: 10 verified, 1 error. `-le` folds false:
4 verified, 3 errors. `And` needs one status-0 arm: 13 verified, 2 errors.
Dropped brace prefix: 11 verified, 1 error. Flipped case direction:
14 verified, 1 error. Wrong Lt complement (Lt->Le): 11 verified, 2 errors. Inverted Eq fold:
12 verified, 2 errors. Inverted taken-branch selection (prune `if true` to else):
19 verified, 3 errors. Dropped plain-ident gate (fold any name):
9 verified, 1 error. Prefix lowered to suffix: 27 verified, 2 errors.
Dropped else-body in the splice: 18 verified, 4 errors. Accepted step form:
9 verified, 2 errors. Test-string routed to arith: 8 verified, 1 error.
Dropped multi-scope arm (Local for a two-scope name): 11 verified, 2 errors.
Dropped `*` from the f32 form table (exact product): 7 verified, 1 error. Flipped width order
(narrow (0,100) as I8): 19 verified, 1 error. Dropped capture denial
(bounded capture receiver as Fixed): 13 verified, 1 error.
Unsigned-reduction-on-negative (shipped -3 shape as equal):
14 verified, 1 error. Dropped >10-digit refusal (accept long text):
68 verified, 1 error. Allow-Refuse-to-fold (compile-time abort):
14 verified, 1 error. Flipped-clamp (e<b allowed): 39 verified, 1 error.
Bare-quote splice (injection hole): 13 verified, 3 errors.
Folded ps-tmp cleanup (cleanup loses its carrier): 7 verified, 1 error.
Command-style part folds (unrendered substitution merged): 23 verified, 1 error.
Step spliced before Break (wrong control effect): 11 verified, 2 errors.
Accepting a +2 step (one-gate dropped): 9 verified, 3 errors.
Folding without the clean-span gate (store-break dropped): 33 verified, 4 errors.
Inlining a multi-use temp (single-use gate dropped): 17 verified, 1 error.
Admitting an uninit chain write (dominating-defs gate dropped): 10 verified, 2 errors.
Treating a redirect as pure (redirect arm dropped): 19 verified, 2 errors.
Counter-dependent derived hoisted (invariant_reads dropped): 20 verified, 1 error.
Spurious flag on the skip shape (forward-skip over-instruments): 19 verified, 1 error.
IFS dropped from the [*] marks ([@]-rule applied to [*]): 16 verified, 1 error.
C-generator mutants are
recorded per-model in `C_UB_PROOF.md` §13–§21 (unguarded commit ships
wrap, intended-UB pair is UB, four one-token decimal mutants, flipped
width order), all restored and re-checked green under the pinned
binary. Every mutant was restored and
re-checked green — and the pre-existing reproductions were
re-run independently on 2026-10-24 with the pinned binary, matching the
documented numbers exactly (4v/1e, 7v/1e, 23v/2e, 43v/2e, 51v/2e, 51v/2e, 9v/1e, 31v/3e, 33v/1e against clean
baselines of 5/8/25/45/53/53/10/35/35); the P3/P4/P5 mutants were checked
the same day against clean baselines of 27/41/25, plus the six P6 mutants
against clean baselines of 11/11/7/15/12/15 and the P7 mutant against a
clean baseline of 13 and the P8 mutant against a clean baseline of 14,
plus the P9 trio mutant against a clean baseline of 22 (checked 2026-10-26),
plus the P10/P11 mutants against clean baselines of 10/29/22/11/9 (all checked
2026-10-26: slice non-ident gate 9v/1e, case Prefix-to-Suffix 27v/2e, elseif
dropped-else 18v/4e, seq-range step-accept 9v/2e, ternary engine-swap 8v/1e),
plus sabotage-tested coverage
syncs for all ten synced models (guard renamed / pin renamed / unknown
model all FATAL loudly; executed-test sabotage names the broken fragment
via `exec <pin>: FAIL`).
Executed-test totals in the committed baselines: copy_propagation 6/6
PASS, test_lowering 9/9 PASS, string_folds 7/7 PASS, capture_folds 6/6
PASS, list_folds 6/6 PASS, textop_folds 3/3 PASS, slice_identity 8/8
PASS, case_lowering 13/13 PASS, elseif_flatten 4/4 PASS, seq_range 8/8
PASS, function_purity /
arith_folds / test_folds / elim_trio / ternary_desugar pins UNMIRRORED-by-design (analysis-only or
suite-less sources — recorded, not claimed).
The retired file (`i32_bounds_exec.rs`) has no
recorded mutant; its anti-vacuity argument is structural instead — the postcondition
constrains the executable function's actual return triple over all ten
`ArithAst` constructors, a shape 30 failed probes showed is easy to get
vacuously wrong and hard to get right. There are no `admit()`s and no
`assume(...)`s in the three new files (the single trust axiom remains
`assume_specification[i128::checked_neg]` in the retired exec-form file — a stdlib
spec, standard vstd practice).

**4. The theorems are Tier-1 shaped, and the Tier-1 boundary is load-bearing.**
Each proof states verdict-soundness or trace/store-equality over IR-shaped
data with an explicit environment contract (`closed_for`, `env_sound`-style
premises) — no shell semantics anywhere, consistent with
`docs/transform-verification.md`'s Tier 1. None of them is Tier 3
(`⟦f(p)⟧ = ⟦p⟧` over real shell meaning); per that doc, Tier 3 is out of
reach until a statement semantics exists in-tree (Smoosh offers a reference
semantics and differential oracle, not a foundation — its 96
`target_rep`s are OCaml-only, so neither the Coq nor the Isabelle backend
emits anything). The 2026-10-24 pin audit scores the living tie per model
— pins are the empirical half of fidelity, real tests are what keeps them
honest after the modelling session ends:

| model | pins | mirrored in real tests? | cargo result |
|---|---|---|---|
| `optimize_stmts` | 4 scenarios (`declare_pins`) | **no** — one-time empirical check only | — |
| `dead_fn_elim` | 3 (`elim_pins`) | **yes, exactly** (`removes_uncalled_fn_keeps_called_and_indirect`) + ForInit extra | 3 green |
| `dead_store_elim` | 6 pins | **partial** — 5 keep-side boundary tests green; lone-drop, read-later, impure-RHS, multi-write, dyn-freeze unmirrored | 5 green |
| `redundant_store_elim` | 7 pins | **yes, all** — 3 bug scenarios in-module (side-effecting arith, index read, Str-embedded `$x` + scanner units); cascade + observer + index-read in `pin_mirrors.rs` | 3 + 3 green |
| `array_len_fold` | 8 pins | **yes, all, in-module** — 4-arg, 3-arg, plain-name, numeric-offset, non-empty-length, non-ident-base, bad-arity, folded-counts (15 in-module tests incl. traversal) | 8 green |
| `const_status_cond` | 11 pins | **yes, all shapes, in-module** — all 7 rows + words/elsifs/non-const refusals (11 in-module tests); fuel-2 behavior pin is model-internal (the theorem at f=2) | 10 green |
| i32 ×2 | n/a | **RETIRED** — target absent; gate-verified as a retired record, never counted (P0(iv)) | n/a |
| `elim_trio` | 8 pins (cce×4 / uae×2 / mia×2) | UNMIRRORED by design — none of the three sources has per-rule unit tests (const_condition_elim tests only the `eval_cond` refusals, never the pruning) | recorded, not claimed |
| `slice_identity` | 8 pins (3 folds / 4 refusals / runtime) | **yes, all** — each pin mirrors a named `slice_identity.rs` test (zero_offset…, empty_offset…, length_absent…, real_offset/length, array_and_positional, transform_reports_false) | 8/8 PASS in committed sync baseline |
| `case_lowering` | 14 pins (dispatch + bind + refusal shapes) | **yes, all-but-one** — 13 pins mirror named `case_lowering.rs` tests; post-catch-all-dropped is model-internal | 13/13 mapped PASS in committed sync baseline |
| `elseif_flatten` | 4 pins (flatten / chain / refusal / live value) | **yes, all** — each pin mirrors a named `else_if_flatten.rs` test | 4/4 PASS in committed sync baseline |
| `seq_range` | 8 pins (lift shapes + 5 refusals) | **yes, all** — each pin mirrors a named `seq_range_for.rs` test | 8/8 PASS in committed sync baseline |
| `ternary_desugar` | 6 pins (mapping table + branch) | UNMIRRORED by design — the transform has no unit suite | recorded, not claimed |
| `copy_propagation` | 6 pins (fold/keep/drop/opaque/multi) | **yes, all, in-module-adjacent** — each pin mirrors a named `copy_propagation.rs` test (folds_read_after_def, refuses_read_before_def, refuses_multi_def, folds_copy_rhs, refuses_background_read, folds_both_reads_in_one_stmt) | named tests green (in-module suite) |
| `function_purity` | 7 pins (body verdicts, call/arg rules, silent run) | **partial** — pins mirror verdict behavior described in prose (no per-verdict unit tests in `function_purity.rs`; the analysis is consumer-tested via `inline_pure_fns`) | n/a (analysis-only, no unit suite) |
| `test_lowering` | 8 pins (leaf shapes + negation + numeric) | **yes, all, in-module-adjacent** — each pin mirrors a named `test_lowering.rs` test (nonempty/string-eq/numeric-glob-affix families) | named tests green (in-module suite) |
| `string_folds` | 7 pins (single-lit/single-expr/multi/gates) | **yes, all** — each pin mirrors a named `interp_fold.rs` / `default_empty_fold.rs` test (single_literal…, single_expr…, multi_part…, empty_default…, array_homed…, nounset_gate…) | 7/7 PASS in committed sync baseline |
| `arith_folds` | 7 pins (three rules + refusals + bc) | UNMIRRORED by design — neither `arith_normalize.rs` nor `bc_float_clean.rs` has a unit suite | recorded, not claimed |
| `test_folds` | 4 pins (true/false ops + runtime) | UNMIRRORED by design — `test_simplification.rs` has no unit suite | recorded, not claimed |
| `capture_folds` | 6 pins (strip/join/empty/chains) | **yes, all** — each pin mirrors a named `const_capture_fold.rs` test (frontend_constant…, multi_word…, folds_true…, or_chain…, chain_status…, other_command…) | 6/6 PASS in committed sync baseline |
| `list_folds` | 6 pins (expand/splice/strip) | **yes, all** — each pin mirrors a named `brace_fold.rs` / `affix_strip_fold.rs` test | 6/6 PASS in committed sync baseline |
| `textop_folds` | 6 pins (strlen/case/substr/basename) | **partial** — strlen/case pins mirror named `text_ops.rs` tests; substr/basename pins are model-internal computations | 3/3 mapped PASS in committed sync baseline |
| `not_folds` | 8 pins (double/single/consistency/flips/runtime) | **yes, all-but-one** — 7 pins mirror named `not_identity.rs` tests (folds_double_not, single_not_is_untouched, unbalanced_inner_not_is_refused, flips_negated_comparison, flips_ordering_comparisons); outer-inconsistency is model-internal | 7/7 mapped PASS in committed sync baseline |
| `const_cmp_folds` | 9 pins (equal/ne/int/glob/style/mixed/dynamic/wrapped/globmatch) | **yes, all** — each pin mirrors a named `const_str_cmp_fold.rs` test (folds_equal_literals, folds_int_literals, refuses_glob_rhs, refuses_dynamic_and_mixed_operands, refuses_command_style, folds_globmatch_with_literal_pattern, folds_wrapped_exact_cond) | 9/9 mapped PASS in committed sync baseline |

**5. Compared with the Isabelle line, Verus is stronger per-lemma and weaker
as a gate.** Isabelle's mirrors are also hand-duplicates ("mirrored
VERBATIM"), but they are built by `harness/transform-proofs.sh` — 6
sessions green, sabotage-tested — while Verus, until 2026-10-24, had no
gate and no binary on the box (now: `harness/verus-gate.sh`, green on every
model in the tree as of 2026-11-09, and `/opt/verus-0.2026.10.18.7d82994`; still no
manifest `proof:` lines). The three branch-pending FAILs are landed in-tree
2026-10-26 (`redundant_store_elim`, `array_len_fold`, `const_status_cond`
re-verified at 53/10/35 on the landed files — no re-proof).
Conversely the retired Verus file `i32_bounds_exec.rs` carries
an executable function with a postcondition, and `interval.rs`
discharges nonlinear arithmetic the Isabelle automation needed hand-holding
for. The honest summary: 470 checked obligations over 23 active models whose
fidelity ranges from pinned-and-mirrored (`dead_fn_elim`,
`redundant_store_elim`, `array_len_fold`, `const_status_cond`,
`copy_propagation`, `test_lowering`, `string_folds`, `capture_folds`,
`list_folds`, `not_folds`, `const_cmp_folds`, `slice_identity`,
`case_lowering`, `elseif_flatten`, `seq_range`) through partially-pinned
(`dead_store_elim`, `optimize_stmts`, `function_purity`, `textop_folds`,
`arith_folds`, `test_folds`, `elim_trio` — all-UNMIRRORED by design,
suite-less sources — plus `ternary_desugar`, same)
— see the audit table in point 4. The two `i32` models (12 obligations)
are retired, out of the gate and the totals.

**6. What "verified" does not mean.** It does not mean the target has no UB
(`C_UB_PROOF.md` is a separate, still-open obligation, P4 blocked on the
absent C-Parser/AutoCorres toolchain). It does not mean the renderer honors
the verdict (`i32_provable` has no consumer — zero references outside its
own file, verified 2026-10-24). It does not mean the pass
fires — see the `for-recovery` lesson in §(d). It does not mean the
model's target exists: the i32 models verify green over a function absent
from every recorded commit (see the §(a) correction). And re-running does
not check the statement — Verus proves the lemma as written; whether the
lemma means what the README claims is human-audit territory, which is why
the pin-to-test mapping in P0(iii) matters more than another green run.

## (c) Which transforms have not been proven correct

Tier 3 (semantic preservation over real shell meaning): **nothing**, by
design — see §(b).4. What follows is the Tier-1 inventory: every transform
and analysis with a verdict-shaped obligation, marked V (Verus model),
I (Isabelle session), T2 (property laws + differential only). The laws in
`tests/transform_laws.rs` (determinism, idempotence, forbidden-shape,
render-invariance) cover every registered transform structurally — that is
the baseline everything below also has.

| transform / analysis | class | status | note |
|---|---|---|---|
| `div_mod_pow2` | analysis (non-neg verdict) | **I** + manifest | `proof/` next to the offer; negative control kept |
| `arith_identity` | value folds + error guards | **I** | 29 lemmas; guards proved load-bearing by refutation |
| `for_recovery` | loop recovery | **I (trace only)** | iteration-trace identity; **proved path unreachable for shell input** (parser wraps operands in `Arith`) — true theorem, dead contract |
| `i32_provable` | analysis (`abs_bound` + `arith_bounds`) | **I** (`abs_bound`/`is_i32`) + **V-retired** (`arith_bounds`, 2 files) | Verus pair retired P0(iv) — target never landed; Isabelle `abs_bound` stands |
| `dead_fn_elim` | elimination | **V** (Passes 1–4) | Lit-fragment census gap flagged, not proved |
| `dead_store_elim` | elimination | **V** (core) | droppable scalar class only; found 2 real bugs next door |
| `optimize_stmts` (`ir.rs`) | elimination (Pass 1) | **V** | Pass 0.5 folding separate, unproved |
| `bigint_range` (`shir_passes`) | analysis | **I** | pre-fix twin refuted in-file (`v0_not_sound`) |
| `interval` (`shir_passes`) | analysis (floor walk) | **I** | imports BigIntRange; release-wrap `*` arm fixed with proof |
| `text_ops` (wc part) | node lowering | **I** (`docs/fm/TextOps`) | `lowered_wc_sound`; pre-fix emission recorded refuted |
| `maskable` (`shir_passes`) | analysis | uncommitted WIP | theory file untracked, session wired in an uncommitted `proofs/ROOT` edit (which the `proofs/` gate build would then attempt); build status unknown, not in the measured gate set |
| `redundant_store_elim` | elimination | **V** (fixed pass, 53) | landed in-tree, gated; 3 soundness fixes landed with it (source-level Ext-WIP rebase still pending) |
| `copy_propagation` | propagation | **V** (substitution core, 27) | same census/purge shape as the proved elims |
| `function_purity` | analysis (verdict) | **V** (verdict soundness, 41) | verdict gates `inline_pure_fns` — wrong verdict = miscompile |
| `inline_pure_fns` | inlining | T2 | needs purity + call preservation (Tier-3-flavored) |
| `const_status_cond` | const fold | **V** (7-row table, 35) | landed in-tree, gated; all shape pins mirrored in-module |
| `array_len_fold` | const fold | **V** (`fold`, 10) | landed in-tree, gated; all pins mirrored in-module |
| `test_lowering` | lowering | **V** (Tier-1 leaves, 25) + T2 (rest) | **fires most (42/563, re-measured 2026-10-30)**; full obligation needs statement semantics — leaves proved, rest Tier-2 |
| `const_condition_elim` | const fold | **V** (`elim_trio`, cce) + T2 (rest) | per-node pruning proved P9; `eval_cond` string parsing out of scope; 0/563 isolated, **3/563 in-pipeline** (measured 2026-10-26 — upstream passes mint the consts) |
| `counted_arith_forinit`, `counted_while_forinit` | loop recovery | T2 | `counted_arith` 0/563 (correct: shell conds are `test` calls); `counted_while` **9/563** since the 2026-10-26 `Arith`-wrap fix — no longer dead, still T2 (see the P12 row) |
| `slice_identity`, `affix_strip_fold` | folds | T2 (`affix` in **V** `list_folds`; `slice` below) | zeros verified as correct refusals, not bugs — see P10 |
| everything else in `src/transforms/` (40 files: `arith_forms`, `arith_normalize`, `background_decide`, `bc_float_clean`, `brace_fold`, `builtin*` (3), `capture_node_fold`, `const_capture_fold`, `default_empty_fold`, `echo_return`, `escape_classes`, `f32_narrow`, `fbdev_gpu*` (4), `fuse_fill_consume`, `grep_pcre`, `interp_fold`, `isolate_accumulate`, `loop_return_lift`, `process_subst`, `shir_native_stmt`, `shir_pipeline_native`, `split_set`, `str_chop_cursor`, `stray_reserved_word`, `string_accumulator`, `sub`, `sync_ok_loops`, `test_simplification`, `text_capture_fold`, `text_ops_planner`, `type_query`, `typeset_attrs`, `append_to_store`) | mixed | T2 | laws + differential only; most never fire in isolation on the corpus |

**The 2026-10-30 census** (`docs/transform-verification.md` §"The
parked-transform census") adjudicates the eleven that had never been tiered
— `fuse_fill_consume`, `isolate_accumulate`, `string_accumulator`,
`sync_ok_loops`, `background_decide`, `inline_pure_fns`, `process_subst`,
`for_recovery`, `planner`, `sub`, `type_query` — by measurement, not by
intent: seven are Tier 3, `planner` is a mechanism and `sub` a placeholder
(neither is a transform), `type_query`'s Tier-1 fragment is a 58-entry table
(fires 1/563), `for_recovery` keeps its green-but-dead session, and
`string_accumulator`'s C consumer walks code where a `_ => {}` in
`read_walk` hides `Arith` reads — open bug 11 in `BUGS_FOUND.md`. No new
Isabelle session: proving a walker that misfires would certify the hole,
and the remaining obligations are Tier 3.
| `hoist_loop_invariants` | loop-hoist (leading invariant run → prologue) | **V** (`hoist_loop_invariants`, 22) | n ≥ 1 proviso (0-trip hole found + pinned, BUGS_FOUND.md 7 open); 8 unit-test pins |
| `unreachable_after_exit` | elimination | **V** (`elim_trio`, uae) | per-node truncation proved P9; 0/563 both modes — only the BAT frontend constructs `Exit`/`Return` (shell `exit` lowers to a builtin call); starved by producer absence, not wiring |
| `exec_call_fold` | carrier canonicalization | **V** (`exec_call_fold`, 8) + T2 (rest) | per-site payload preservation; carrier flag as parameter, cleanup oracle + shir gate as placement; 4 unit-test pins |
| `merge_init_assignments` | elimination | **V** (`elim_trio`, mia) | adjacent-pair merge proved P9 under literal/pure/no-self-read gates; 0/563 both modes — FIRES on synthetic `declare x=0` + `x=6` input (mechanics verified live) |
| `slice_identity` | fold | **V** (`slice_identity`, 10) | zero-offset fold proved P10; fires 0/563 shell (synthetic witnesses) |
| `case_lowering` | lowering | **V** (dispatch, 29) + T2 (rest) | dispatch proved P10; full obligation needs statement semantics |
| `else_if_flatten` | restructuring | **V** (chain, 22) | branch-selection proved P11; structural rule |
| `seq_range_for` | loop recovery | **V** (word list, 11) | seq-words identity proved P11; fires on `for-in-seq` shapes |
| `ternary_desugar` | lowering | **V** (cond normalize, 9) | branch-selection proved P11; ingress-only (C frontend) |
| `shir_passes` analyses (`lifetime`, `loop_opt`, `numstr`, `numeric_observed`, `scc`, `strip`, `used_before_decl`, …) | analyses/passes | T2 (mostly) | no verdict-soundness theorems; obligations unexamined per-pass |

## (d) Priority order (importance × feasibility)

**P0 — land what is proven before proving anything new.** Status 2026-10-24:
`harness/verus-gate.sh` exists and is green (Tier 0: the five models
re-verified with exact-count checks, exit 0; sync registry empty by
design — see below). Landed 2026-10-24: (i) DONE — the three Verus
commits are on GitHub (pushed with `fm-wc-semantics2`, now at `b46a316e4`);
(iii) DONE — `sh2perl/tests/pin_mirrors.rs`, 9 regression tests mirroring
the previously-unmirrored pins (optimize 4 + DSE drop-side 5), all green,
committed and pushed in the same branch update. `dead_fn_elim`'s three
pins were already exactly mirrored and green. (ii) DONE — the
`.verus-rse` `redundant_store_elim` fix (now THREE soundness holes: the
two P1 named plus a `$name`-in-`Str` blind spot found during the work,
each with failing-first tests) with its proof (53 obligations, two
fix-mutants red) is committed on branch `verus-rse` (`7e317c61`, pushed),
merged with current main, registered in the gate (sixth entry,
`redundant_store_elim.rs:53:80`), and its 7 pins are all mirrored
(3 in-module + cascade/observer/index-read in `pin_mirrors.rs`, 12
green). LANDED 2026-10-26: the three proof files are copied in-tree
(`proofs/verus/redundant_store_elim.rs`, `array_len_fold.rs`,
`const_status_cond.rs`) and re-verified at 53/10/35 on the landed files —
no re-proof, byte-identical to branches `verus-rse` (`7e317c61`) and
`verus-p2` (`68d20941`); gate MODELS entries already present, now backed by
files. The main worktree holds another worker's uncommitted `IrExpr::Ext`
arm in the same `redundant_store_elim.rs` source file — overlapping
hunk, both keep-direction; the Ext owner rebases onto the gitlink bump
(source-level merge still pending, proof file unaffected).
(iv) DONE 2026-10-26 — the two i32 models are RETIRED: bannered in-file,
removed from `harness/verus-gate.sh` MODELS, excluded from the active totals
(still verify at 5/7 as superseded-design records, now as gate-verified
`RETIRED_MODELS`). `verus-sync.sh` was left unregistered here on the reasoning
"nothing to sync"; the reason this paragraph gave for staying out — a
permanently-red entry — turned out to BE the signal: the extractor's target had
already been deleted from the source. 2026-11-08 registered it, retargeted it at
the live `arith_abs_bound`, and committed the generated baseline, so it is
green and live instead of silent.

**(v) DONE 2026-11-09 — the gate now checks the tree that ships.** Thirty-eight
models were named in `harness/verus-gate.sh` and absent from the tree, so in a
clean checkout `check_model`'s existence pre-check answered for them: a pass
count of zero that reads exactly like a failed proof and is worth nothing
either way. All thirty-eight verify at exactly their asserted counts, so they
are committed rather than re-pinned. The twenty-one sync baselines whose
entries had been `SKIP`ping as "Tier 1 pending, NOT green-by-absence" are
generated from HEAD source (every pin mapped, every mapped test executed
PASS), and the `c_sparse_array` / `c_assoc_array` increments the gate was
already demanding (45 and 54) are landed. `c_decl_coverage` stays pinned at
HEAD's 51: its working copy's new pin maps to
`expr_position_assign_routes_to_the_variable`, a test that is also still
uncommitted, so the model and that test have to land together. Four
extractors still refuse instead of skipping — `arr_load_fwd`,
`exec_call_fold`, `interp_lit_merge` (every mapped test MISSING: the pin_map
names tests the suites no longer contain) and `strip`
(`pin_continue_verdict` has no pin_map entry) — and that needs the owner's
mapping, not a guessed one. Gate on the committed tree: **123 passed, 0
failed, 4 skipped, 2 retired records**. Unpushed, so a fresh clone of
`origin` still sees the old state.

**(vi) DONE 2026-11-09 — the last four skips.** `strip` generates now: its
`pin_continue_verdict` was the only pin without a pin_map entry, and because
`src/shir_passes/strip.rs` tests the splice that consumes the verdict rather
than the predicate, the entry is a conscious UNMIRRORED with that sentence
beside it instead of a guessed test name. The other three cannot execute at
all: `src/transforms/arr_load_fwd.rs`, `exec_call_fold.rs` and
`interp_lit_merge.rs` are tracked files that **no `mod` declaration reaches**
(`src/transforms.rs` declares 71 modules and none of them; `builtin_lift.rs`
is tracked and dead in the same way), so their `#[test]`s are never compiled.
That is why every pin reported `MISSING (renamed? filtered?)` — the tests ARE
in those files, and no filter can reach them because the module is not in the
crate. The extractor now says so in words ("is not a module of the crate"),
`check_sync_cov` runs it before consulting the baseline, and the gate counts
the entry as a SKIP that prints the reason instead of a red that hides behind
"generator errored". Gate after the pass: **124 passed, 0 failed, 3 skipped,
2 retired records**.

**(vii) DONE 2026-11-09 — ported two, retired two.** Declaring each module
settled it, and the split is not the one the SKIP suggested. Two were one
missing line, two were unsalvageable:

- `exec_call_fold` and `interp_lit_merge` compile against the current crate and
their suites pass (4 and 7 tests, all green). The `mod` line was the entire
gap — the 2026-10-29 commit that added the files claims the `transforms.rs`
wiring was "present but files absent"; it was neither, because that commit
does not touch `transforms.rs` at all. Both are modules now, every pin
executes, and their sync baselines are committed. **Neither is registered with
a backend**: a `mod` line proves the pass, it does not put it in the pipeline,
and registering stays the marketplace's call (PLAN §11).
- `arr_load_fwd` cannot be ported: it imports `super::READ_ONLY_CALLS` and
`string_accumulator::{callee_write_sets, Cw}`, none of which exist anywhere
outside that file, and calls four helpers the crate has since made private
(E0432/E0603). Its 1518 lines are deleted; the model keeps a banner and moves
to RETIRED_MODELS — verified as a superseded-design record, outside every
total, the treatment `interval.rs` got.
- `builtin_lift` is recorded WITHDRAWN in
`core-requests/transforms/rejected/builtin-lift/WITHDRAWN` ("superseded by the
landed builtin transform") and fails to compile when declared (E0631).
Deleted; it had no model.

Gate after this pass: **125 passed, 0 failed, 0 skipped, 3 retired records**,
exit 0 — the sync section now covers every entry the gate names.

**P1 — `redundant_store_elim`.** DONE — see P0(ii): the fixed version is
proved (shadow argument, observationally exact), with all three bug
scenarios as pins and both fix-mutants as negative controls. LANDED
2026-10-26 (file in-tree, gate green at 53). What remains
is the source-level mechanical merge once the Ext WIP lands, not another proof.

**P2 — `const_status_cond`, `array_len_fold`.** DONE — both proved on
branch `verus-p2` (`68d20941`, pushed): array-len-fold value
preservation (10 obligations, offset-guard mutant red at 9/1) and
const-status-cond restructuring preservation over fuel-bounded
trace/status (35 obligations, two mutants red at 31/3 and 33/1). All
shape pins mirrored 1:1 in-module (dead_fn_elim precedent — no
`pin_mirrors.rs` additions); both registered in the gate
(`array_len_fold.rs:10:40`, `const_status_cond.rs:35:60`). LANDED 2026-10-26
(files in-tree, re-verified at 10/35 — no conflicting WIP in either file).

**P2 — `const_status_cond`, `array_len_fold`.** They fire on the real corpus
(8 and 9 files of 562 — nearly the only ones that do), their obligations
are pure value-preservation over literals (no state, no census, no fuel),
and the proofs are small enough to be the first *new* gated Verus
proofs (the gate exists; it currently guards the five old models).
Feasibility is the point: bank two green,
gated proofs on live passes.

**P3 — `copy_propagation`.** DONE — proved 2026-10-24
(`copy_propagation.rs`, 27 obligations, gate-registered
`copy_propagation.rs:27:40`): substitution soundness over a
parameterized single-def table with the def-before-read gate, single-store
induction with `prefix_ok`, six fidelity pins mirroring the transform's
own tests, gate-dropping mutant red at 25/2. Coverage sync registered
(`verus-sync-coverage.sh:copy_propagation`, baseline
`copy_propagation_sync.txt`, sabotage-tested incl. executed tests:
inverting a mapped test's expectation yields `exec <pin>: FAIL` naming
the fragment). Copy defs, arith gates,
`param-const-fold`, `AffixStrip`, quoted-`Interpolate` defs out of scope
(same core; the extensions reuse this gate).

**P4 — `function_purity` verdict soundness.** DONE — proved 2026-10-24
(`function_purity.rs`, 41 obligations, gate-registered
`function_purity.rs:41:40`): Pure ⟹ empty trace, Emulable ⟹
capturable-only trace, at every fuel, under a consistent table (three
load-bearing conjuncts: recomputation floor, lattice bound, defined
keys — each guards a concrete unsound-table class found during the
proof). Seven fidelity pins; Output-as-Pure mutant red at 39/2. Coverage
sync registered (`verus-sync-coverage.sh:function_purity`, baseline
`function_purity_sync.txt`, sabotage-tested). Full
inline preservation stays out (Tier-3).

**P5 — Tier-1 sub-obligations out of `test_lowering`.** DONE — proved
2026-10-24 (`test_lowering.rs`, 25 obligations, gate-registered
`test_lowering.rs:25:40`): per-leaf value preservation for the four
lowering families (nonempty, string-eq as `Not(Ne)`/`Ne`, numeric six-op,
glob-affix + negations) over `Seq<char>` strings, from any closed store.
Eight fidelity pins; dropped-`Not` mutant red at 24/1 (the
perl-numeric-`==` bug). Coverage sync registered
(`verus-sync-coverage.sh:test_lowering`, baseline `test_lowering_sync.txt`,
sabotage-tested). Status liveness, cond position, nocasematch,
compounds stay out (Tier-3).

**P6 — VALUE-FOLD sweep.** DONE — six files proved 2026-10-25, all green
with checked mutants and gate-registered with exact counts:
`string_folds.rs` (interp-fold single-literal + default-empty-fold
empty-default identity, 11 obligations, multi-part mutant red at 9/2),
`arith_folds.rs` (arith-normalize three identities + bc-float-clean
finite strip, 11 obligations, dropped-canonicalization mutant red at
10/1), `test_folds.rs` (self-comparison eight-op table, 7 obligations,
wrong-collapse mutant red at 4/3), `capture_folds.rs` (newline strip +
echo join + status-0 chains + text spans, 15 obligations, loosened-And
mutant red at 13/2), `list_folds.rs` (brace splice + literal affix
strips, 12 obligations, dropped-prefix mutant red at 11/1),
`textop_folds.rs` (case map + substr + GNU basename, 15 obligations,
flipped-case mutant red at 14/1) — 71 new obligations (352 total).
Firing adjudicated per pass before proving: interp-fold 297/563,
brace-fold 25/563, const-capture-fold 13/563, default-empty-fold
28/563, text-capture-fold 2/563, text-ops 180/563 (C target) all fire;
test-simplification 0/562 but fires on synthetic self-comparison input
(mechanics verified live); arith-normalize runs at frontend ingress, not
the registry (0/562 is a probe artifact — rule + refusals proved);
bc-float-clean targets the mimecroft corpus (absent here — rule proved
for its documented target); affix-strip-fold 0/562 on shell (offered to
rs/java targets — target-gated); slice-identity zeros are correct
refusals (not proved); str-chop-cursor needs the cursor-window demo as
firing witness (deferred to P7/P8 scale); sub is a placeholder module.
Coverage syncs registered for all six (baselines committed, sabotage-
tested, mapped tests executed: 7+6+6+3 PASS, arith/test_folds pins
UNMIRRORED — suite-less sources, recorded).

**Explicitly deprioritized.** `for_recovery` / `counted_arith_forinit`: prove nothing until the firing defect is fixed —
the repo's own lesson is that a green proof over an unreachable path is a
true theorem about a dead contract. Backend emitters (`fbdev_gpu*`,
`shir_native_stmt`, …): no semantics to state preservation against, and
`text_ops`' provable fragment is already done. `process_subst` /
`background_decide`: process and exec semantics are Tier 3, no model will
make them Tier 1. New Isabelle-vs-Verus framework debates: the split is
settled empirically (nonlinear arithmetic → Verus; everything gated →
Isabelle); revisit only when a lemma resists both.

Rule for everything above, inherited from `docs/transform-verification.md`:
**check that a pass fires before proving it, ship the negative control with
the proof, and give every new model a sync story on day one.**

**P7 — `not_identity`.** DONE — proved 2026-10-25
(`not_folds.rs`, 13 obligations, gate-registered
`not_folds.rs:13:40`): double-negation fold (duplication-consistency
gated) + rust-gated six-op comparison flip under the exact-complement
hypothesis (the Perl Eq-numeric/Ne-string asymmetry is the documented
counterexample for why the flip needs scoping). Eight fidelity pins,
wrong-complement mutant red at 11/2. Coverage sync registered
(`verus-sync-coverage.sh:not_folds`, baseline committed, sabotage-
tested, 7/7 mapped tests PASS).

**P8 — `const_str_cmp_fold`.** DONE — proved 2026-10-25
(`const_cmp_folds.rs`, 14 obligations, gate-registered
`const_cmp_folds.rs:14:40`): literal `Eq`/`Ne` (plain styles,
glob-free RHS), unconditional int/int, the flip-free wrapped
`Not(Ne)` exact_cond (sound on every target — no operator renders),
and `globMatch` with a literal pattern, all folded to the denoting
`Bool`. Nine fidelity pins, inverted-Eq mutant red at 12/2. Coverage
sync registered (`verus-sync-coverage.sh:const_cmp_folds`, baseline
committed, sabotage-tested — a compiling-but-wrong glob check yields
3 named `exec FAIL`s — 9/9 mapped tests PASS).

**P9 — ELIM trio.** DONE — proved 2026-10-26 (`elim_trio.rs`, 22
obligations, gate-registered `elim_trio.rs:22:40`): `cce_sound` (taken-branch
pruning, while-false drop, dowhile-to-body), `uae_sound` (post-`Exit` tail
truncation under abort semantics), `mia_sound` (adjacent literal-default +
pure-RHS pair merge). Eight fidelity pins, all UNMIRRORED by design
(suite-less sources — recorded, not claimed); inverted-branch mutant red
at 19/3. Coverage sync registered (`verus-sync-coverage.sh:elim_trio`,
baseline committed). The file needed repair before registration (fourth
run_abort arg, stray `fuel` requires, misplaced `by` block, mutual-recursion
decreases) — fixed, re-verified 22/0, mutant re-checked.

**P10 — `slice_identity`, `case_lowering`.** DONE — proved 2026-10-26
(`slice_identity.rs`, 10 obligations, `case_lowering.rs`, 29
obligations; gate-registered `slice_identity.rs:10:40`,
`case_lowering.rs:29:40`): zero-offset fold denotation identity under
the exact gate conjunction (non-ident-gate mutant red at 9/1, pin-
load-bearing as in array_len_fold); case dispatch preservation
(per-pattern denotation + first-match-wins chain, Prefix-to-Suffix
mutant red at 27/2). Eight pins mirror the slice tests 1:1;
fourteen pins mirror 13 of the 16 case tests (dropped-tail shape is
model-internal). Coverage syncs registered for both (baselines
committed). Firing adjudicated before proving: slice 0/563 on shell
(synthetic unit witnesses only — the test_folds precedent);
case fires 38/563 on `--target rs` (measured sweep; 0/563 on `--target pl` by gating).

**P11 — `else_if_flatten`, `seq_range_for`, `ternary_desugar`.** DONE —
proved 2026-10-26 (`elseif_flatten.rs`, 22 obligations,
`seq_range.rs`, 11 obligations, `ternary_desugar.rs`, 9 obligations;
gate-registered `elseif_flatten.rs:22:40`, `seq_range.rs:11:40`,
`ternary_desugar.rs:9:40`): else-chain collapse preserves the selected
body under every valuation (fuel-bounded loop over the strictly
dropping If count, first-hit scan lemmas; dropped-else mutant red at
18/4); seq-to-Range preserves the iterated integer list (accept-step
mutant red at 9/2); ternary cond normalization preserves the selected
branch (engine-swap mutant red at 8/1). Four pins mirror the 4
else-if tests; eight pins mirror the 8 seq tests; six ternary pins
are UNMIRRORED (no unit suite — recorded). Coverage syncs registered
for all three (baselines committed). Firing adjudicated before
proving (measured sweep; ternary is ingress-only by construction).

**P12 — `shir_passes` + `counted_*`: obligations examined, firing
checked 2026-10-26.** Each pass below states its Tier-1 obligation as
examined (not proved): the `invariant:` one-liner a future model must
carry, plus the firing signal measured this session. Rule (unchanged):
no model until the invariant is written AND a firing witness exists.

| pass | Tier-1 obligation (examined) | firing signal |
|---|---|---|
| `lifetime` | live-span soundness: every read of `v` lies inside its computed span; the escape bit over-approximates retention (missed escape = aliased buffers) | analysis (verdict consumed by C fixed-buffer transform); 12 unit tests |
| `loop_opt` | hoist preservation: moving the leading maximal pure invariant run to the prologue preserves the iteration trace (leading-run, no-control-escape, invariance gates) | rewrite; 7 unit tests; corpus sweep: TBD (channel: shared A1 pipeline) |
| `numstr` | seeding soundness: the vars × params fixpoint marks exactly the numerically-seeded cells | analysis; 10 unit tests |
| `numeric_observed` | int-homing soundness: a numeric-observed cell is never text-observed (every read reaches output through numeric coercion) | analysis; 11 unit tests |
| `scc` | cluster soundness: the reported SCCs are exactly the call-graph cycles (eligibility fixpoint over mutual recursion) | analysis; 6 unit tests |
| `strip` | strip preservation: removing the stripped nodes preserves the run | rewrite; 1 unit test |
| `used_before_decl` | uninit soundness: a flagged read is definitely uninitialized on every path (conservative dataflow) | analysis; 11 unit tests |
| `counted_arith_forinit` | recovery preservation: structured-Arith counted-`while` + trailing `v+=1`/`v++` denotes the same iteration as `ForInit` (`$?`-read veto, no counter write/escape) | rewrite; 6 unit tests; shell-corpus sweep 2026-10-26: 0/563 (frontend-shape CONFIRMED for shell input — shell `[ $i -lt N ]` conds are `test` calls, never `Arith` (only `while ((…))` qualifies; the 2 corpus files with those refuse on body/step gates, correctly); 0/563 isolated AND in-pipeline) |
| `counted_while_forinit` | same for shell `BinOp`/text conds | rewrite; 0/563 isolated AND in-pipeline pre-fix (Arith-wrap defect, witnessed live on 031) — FIXED 2026-10-26: `counter_step` now also accepts `Arith(Bin{Var,+/- ,Num≠0})`, the exact shell lowering of `i=$((i±1))`, mirroring the BinOp arm (same purity, same nonzero gate); 7 new unit tests (failing-first verified); **9/563 fire** (IR-level ForInit gain, all ./fail-green); C backend consumes the ForInit in its standard scoped form |

**P12 — the provable VERDICT analyses.** DONE — proved 2026-10-28
(`escape_classes.rs`, 14 obligations, `f32_narrow.rs`, 8 obligations;
gate-registered `escape_classes.rs:14:40`, `f32_narrow.rs:8:40`, both
with coverage syncs). Of the five "VERDICT analyses" proposed for the P4 treatment, two are
proved here and the other three are recorded as out of Tier 1 (`background_decide` is process/exec, the
standing Tier-3 rule; `sync_ok_loops` criterion 1 is a wall-clock
heuristic and its real obligation is run preservation; `type_query`
needs bash function state at the eval splice point).
`escape_classes`: `local_is_plain`/`local_sound` (Local ⇒ no dynamic-key
mark, no whole-array mark ⇒ a native binding cannot be defeated by an
indexed access), `marked_not_local` + `multi_scope_store` (the verdict
is not vacuous), `pin_acc_ok_matches_consumer` (the model's acceptance
IS `c_backend.rs`'s `Local || (store_ok && Store)`). Seven pins,
UNMIRRORED by design (analysis-only source, no unit suite); mutant
(dropped multi-scope arm) red at 11/2. Firing measured with
`SH2_DBG_ACC=1` over `--target c` on the 563-file corpus: **1/563**
files (1 candidate line) — narrow by construction (arrays, `local`,
cross-scope names all refuse), so the proof's value is the decision
rule, not coverage.
`f32_narrow`: the exactness-preserving form table (`+0`/`-0`,
`*±1`/`*±0`, `/±1`) and `operand_exact`'s round-trip rule, with the
refusals pinned (`%` never; general `*` of two exact floats refused —
the `4097.0*4097.0` hazard; `16777217`-style int operands refused).
Seven pins UNMIRRORED; mutant (dropped `*` arm) red at 7/1. Firing: the
verdict set is empty on shell input by construction (Python-frontend
consumer) — the proof is for Cython/estree float homing.
Coverage syncs registered for both (`verus-sync-coverage.sh:` model
lists and guard sections extended; baselines committed).

Explicitly not Tier-1 and not attempted: `process_subst` /
`background_decide` (process/exec semantics are Tier-3), `fbdev_gpu*` /
`shir_native_stmt` emitters (no semantics to state preservation
against), `inline_pure_fns` (needs call preservation — Tier-3, see
P4). Firing-channel caveat found during the P10/P11 sweeps: the CLI
passes target `"pl"` for `--target pl`, but the registry gates name
`"perl"` (case-lowering, text-ops-planner, capture-node-fold, …) —
so those gates refuse in the `./fail` perl pipeline and firing must be
measured per accepting target (`--target rs` for case-lowering). No code
changed for this (fleet-wide naming; filed as an observation, not a
fix in this effort).
