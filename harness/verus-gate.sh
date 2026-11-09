#!/usr/bin/env bash
# verus-gate.sh — re-run every checked Verus model and the sync --check.
#
#   ./harness/verus-gate.sh                # verify all models + sync status
#   ./harness/verus-gate.sh --list         # show what would be checked
#
# Two things are checked, because the proofs have two failure modes:
#
#   1. MODELS — each standalone proof file re-verified with the pinned
#      binary, asserting the EXACT obligation count (`N verified, 0 errors`).
#      The count check is the point: a model that verifies fewer lemmas
#      than claimed (a weakened file) must fail even though Verus exits 0.
#      An entry is `file:expected:rlimit`; a `+` joins files verified as
#      one crate (the Tier-1 i32 pair: generated sync output + hand proof).
#
#   2. SYNC — for every registered extractor, regenerate to temp and diff
#      against the committed baseline. Two drivers: the legacy
#      regenerating extractor (`verus-sync.sh`, whose `--check` tail was
#      missing so the check lives here and the generator stays untouched)
#      and the coverage checker (`verus-sync-coverage.sh <model>`), which
#      re-derives each P3/P4/P5 model's pin<->test mapping and mirrored
#      guard predicates from the live source and emits a canonical
#      manifest. A missing baseline is a loud SKIP (Tier 1 pending),
#      never green-by-absence.
#
# Exit: 0 every model green and every registered sync clean;
#       1 any model count mismatch / Verus error / sync drift;
#       2 the Verus binary is absent (nothing was verified — do NOT read
#         that as green).
#
# Env: VERUS_BIN (default /opt/verus-0.2026.10.18.7d82994/verus),
#      RUSTUP_HOME/CARGO_HOME (defaults match the README), VERUS_TIMEOUT
#      (seconds per file, default 600).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PV="$root/sh2perl/proofs/verus"
VERUS_BIN="${VERUS_BIN:-/opt/verus-0.2026.10.18.7d82994/verus}"
export RUSTUP_HOME="${RUSTUP_HOME:-/root/.rustup}"
export CARGO_HOME="${CARGO_HOME:-/root/.cargo}"
TIMEOUT="${VERUS_TIMEOUT:-600}"
PIN="0.2026.10.18.7d82994"

# file(s):expected-verified:rlimit — `+` = verify as one crate.
# NOTE: `interval.rs` / `i32_bounds_exec.rs` are RETIRED (see VERUS.md §(a)
# correction and §(d) P0(iv)): their target `arith_bounds` never landed —
# the live estimator is `arith_abs_bound`, proved in Isabelle
# (`I32Provable.thy`). Kept in-tree as superseded-design records and listed
# in RETIRED_MODELS below: the gate VERIFIES them so they cannot rot, but they
# are counted separately and contribute to no Tier-1 total.
MODELS=(
  "optimize_stmts.rs:8:40"
  "dead_fn_elim.rs:25:40"
  "dead_store_elim.rs:45:40"
  "redundant_store_elim.rs:53:80"
  "array_len_fold.rs:10:40"
  "const_status_cond.rs:35:60"

  # CONDITIONAL, NOT TIER 1: background-decide. Subshell-vs-thread under `&`
  # relative to a stated model (the subshell inherits variable reads, discards
  # writes, shares stdout). `thread_equals_fork` proves the THREAD routing
  # prints exactly what bash's subshell prints for every body the ORDERED rule
  # accepts; `intended_implies_shipped` proves that rule refuses nothing the
  # pass accepts; `shipped_check_is_unsound` REFUTES the check that ships --
  # `collect` compares read/assign SETS with no order, so
  # `if [ -n "$x" ]; then x=1; echo 7; fi` is sent to a fresh runtime that
  # prints nothing where the sibling shell prints 7. Excluded from VERUS.md's
  # Tier-1 totals.
  "background_decide.rs:12:40"
  # CONDITIONAL, NOT TIER 1: process-subst (the fd-carrying `<( )` shapes).
  # The materialization lemma: the consumer's input is exactly the producer's
  # output, the temp path is unlinked, other temps are untouched, and the
  # negative control proves the fd/mode inversion the pass's own tests pin
  # yields an EMPTY consumer input. Excluded from the Tier-1 totals.
  "process_subst.rs:6:40"
  "copy_propagation.rs:27:40"
  "function_purity.rs:41:40"
  "test_lowering.rs:25:40"
  "string_folds.rs:11:40"
  "arith_folds.rs:11:40"
  "test_folds.rs:7:40"
  "capture_folds.rs:15:40"
  "list_folds.rs:12:40"
  "textop_folds.rs:15:40"
  "not_folds.rs:13:40"
  "const_cmp_folds.rs:14:40"
  "elim_trio.rs:22:40"
  "slice_identity.rs:10:40"
  "case_lowering.rs:29:40"
  "elseif_flatten.rs:22:40"
  "seq_range.rs:11:40"
  "ternary_desugar.rs:9:40"
  # P12 — the two VERDICT analyses with a stateable Tier-1 obligation
  # and a firing consumer. escape-classes: the census->class decision
  # (`class_of`) over the C renderer's local-vs-store predicate
  # (`c_backend.rs:9929`): Local implies unmarked (no dynamic key, no
  # whole-array position) and single-scope, so a native binding cannot
  # be defeated by an indexed access; any mark forbids Local. f32-narrow:
  # the exactness-preserving form table (`combine`'s non-literal arm) and
  # the `operand_exact` round-trip rule that decides `cdef float` /
  # `Math.fround` homes.
  "escape_classes.rs:14:40"
  "f32_narrow.rs:8:40"
  # The C generator's own Eq/Ne emission decision (c_backend.rs `expr()`
  # + `str_cmp_valued`) — the first model aimed at a RENDER decision
  # rather than a shared shIR->shIR pass. Proves the strcmp arm total,
  # the raw arm sound under both-int operands, and pins the measured
  # mixed pair (numeric-homed var vs string literal, the string-eq lift's
  # `[ "$i" = "2" ]`) as UB under the shipped two-armed decision.
  "c_eqne_emit.rs:11:40"
  # The C generator's checked i64 arithmetic tier — the overflow-flag
  # protocol of both fast arms (`__builtin_*_overflow` walk, the gated
  # commit, the spill/break escape hatches). This is C_UB_PROOF.md §2a's
  # named obligation verbatim: the ov flag is set exactly when an exact
  # result leaves i64, so the GMP escape hatch is taken only when needed
  # and whenever needed. Includes the MAX+1 negative controls (an
  # unguarded commit ships the wrapped -2^63).
  "c_checked_arith.rs:18:40"
  # The C generator's DECIMAL RENDERERS — the hand-rolled itoas it emits:
  # `_sh_ll2s` into num_temp's `static char _sN[32]`, and the inline
  # `size_t` itoa of FieldStrip/FieldStripEnd into str_temp(24). Proves
  # the two comment-claims C_UB_PROOF.md §2a/§2b name: byte-for-byte the
  # `%lld` spelling over the whole i64 domain (incl. LLONG_MIN), and the
  # write bound `strlen <= cap` for both destinations. Width theorem by
  # monotonicity + computed digit counts of 2^63 and 2^64-1. Four
  # one-token mutants, each killing a named obligation.
  "c_dec_str.rs:26:40"
  # The C generator's width-of-var / effective-widths store condition
  # (sh2perl/src/c_backend.rs `Width` + `width_of_var`/`effective_widths`
  # over `range_width_name` in sh2perl/src/shir.rs:16628). Proves the
  # store-side obligation T3 of P1_Narrowing.thy: under consistent
  # (value-covering) ranges the widen-fold admits the store; the TRUNC
  # direction (outside the declared interval is not admitted); the
  # fail-closed arms (unknown range -> I64, garbage name -> I64);
  # `arith_op_wide` fail-closed/fires; the walk skip shapes. Includes
  # the honest domain provisos (u64 arm unbounded above; else/I64 arm
  # fires past i64 — the analysis must not produce such ranges).
  "c_width_store.rs:20:40"
  # The C generator's fixed-buffer store decision
  # (sh2perl/src/c_backend.rs `buf_bound` + `emit_guarded_copy` over the
  # length analysis). Proves the store-side contract: the grown write
  # (strncpy cap=b+1 + dst[b]=0) always lands NUL-terminated in bounds
  # (exact when the source fits, truncating-but-defined otherwise); the
  # debug assert IS the fits predicate; the assert-free capture arm is
  # still never UB; the non-stringy arm never touches the pointer; all
  # three denials (numeric/capture/bigint) stay `char*`; the sha256sum
  # under-bound shape is detected (capture receiver with bound 64 still
  # renders `char*`).
  "c_buf_copy.rs:14:40"
  # The C generator's arith /% guard + num-temp/str-temp + num-spec
  # decisions (sh2perl/src/c_backend.rs `arith`'s `/`|`%` arm + `num_temp`
  # + `str_temp` + `num_spec`/`expr_type_matches` + `width_buf_len`, over
  # `arith_divisor_bounded_nonzero` in sh2perl/src/shir.rs:10914).
  # Proves: the guarded `({r} == 0 ? 0 : …)` form is total (no SIGFPE)
  # and dead exactly when the divisor is proven (positive literal or
  # bounded-nonzero); the unsigned strength-reduced arm equals the
  # signed truncating op on nonneg dividends (with the shipped -3
  # negative control); LLONG_MIN/-1 stays gated; `static char _sN[32]`
  # + `str_temp(cap)` + `width_buf_len` size every stringification
  # exactly; `num_spec`'s cast⟺%lld invariant holds with the type-match
  # rules and the 5 live unit assertions.
  "c_arith_guard.rs:15:40"
  # The C generator's operator/promotion rules
  # (sh2perl/src/c_backend.rs `const_arith_value` + LL-suffix widening +
  # `arith_bin_range_exceeds_i32` + the unsigned-gate premises
  # `arith_proven_nonneg`/`arith_fits_i64`). Proves the fold equals the
  # denotation (checked ops agree or bail -- never a wrapped constant),
  # Refuse never folds (abort preservation), LL is a pure type
  # promotion keyed on the range trigger (with the corrected 67108847
  # reading: operands fit i32, the PRODUCT range escapes it), and the
  # unsigned gate admits exactly the shapes the soundness needs
  # (untainted, known nonneg range, i64-fitting, non-u64 -- each
  # refusal arm pinned).
  "c_op_promote.rs:15:40"
  # The C generator's integer-math helpers it emits
  # (sh2perl/src/c_backend.rs `_sh_isint31` + `_sh_isqrt` + `_sh_i128_str`).
  # Proves the predicate contract (1 ==> |value| <= 2^31, each refusal arm
  # pinned, 10-digit fold exhibited step-by-step); the Newton descent
  # well-defined on the table range with exact small values by direct
  # unfolding (full floor stays open — needs the fixpoint invariant);
  # the i128 branch contract (emitted form vs identity per branch, step
  # stays in-domain, INT128_MIN refutation, 39-digit bound by generated
  # chain, sign/zero/digit contract). Honest provisos: `*` overflow is
  # the caller's gate, not 2^31 alone; the cross-branch magnitude
  # identity is solver-opaque (probed red even under nonlinear_arith).
  "c_int_helpers.rs:69:40"
  # The C generator's `_sh_*` string helpers it emits
  # (sh2perl/src/c_backend.rs `need_sh` runtime block).
  # Proves the shared b/e clamp total and in-bounds; substr byte-exact
  # with the bash sign conventions + edge arms; arr_slice element
  # semantics (same clamp over the word index) with the find/march
  # contract; replace-all first-hit splice + fuel-sufficient unfold +
  # empty-pat identity; strip pre/suf soundness (oracle consistency,
  # greedy/longest vs lazy/shortest) with the no-match identity;
  # argv slice/join soundness; split word spans + split_count. The
  # 2026-11-03 extension models the POSITIONAL JOIN'S FACE: `$*` joins
  # on IFS[0], `"$@"` always on a space (bash-measured), the empty-IFS
  # arm concatenates with no separator (induction), and the lone-$0
  # arm is empty — the source fix that gave `_sh_argv_join` its `sep`
  # argument (9 call sites) is pinned by the face-difference
  # obligation. The 2026-11-04 extension models the positional SLICE's
  # face (`_sh_argv_slice`): both `${*:o:l}` and `${@:o:l}` join on
  # IFS[0] and differ ONLY on an empty IFS (`*` concatenates, `@` falls
  # back to a space) — NOT the whole-`$@` rule, which stays space-joined
  # — pinned by s8-s15 plus m8 (the retired hard-coded space, invisible
  # on the default IFS). The second 2026-11-04 extension models FIELD
  # SPLITTING (`_sh_split`), which is the inverse face: IFS whitespace
  # runs are one delimiter stripped at both ends, each IFS non-whitespace
  # char delimits one field (`a::b` -> a,'',b), an empty IFS disables
  # splitting, and a char is IFS whitespace only if ' '/\t/\n AND IFS
  # lists it. `fields_fuel`/`ifs_fields` over `skip_ws`/`field_end`/
  # `unit_after`, with fuel saturation PROVED (exact, not approximate) and
  # pins f1-f11 + the `blank_runs` mutant (the retired space-only
  # splitter). All index inspection goes through the total `ws_at`/
  # `nw_at`/`delim_at` — a direct `s[i]` in a recursive spec makes the
  # term stuck and the spec never unfolds (bisected, one-file reduction).
  # f12/f13 pin the `$IFS` READ fix: the startup buffer is exactly three
  # chars (space, tab, newline), all IFS whitespace, and holds nothing
  # else — the value the splitter consumes is now the value the variable
  # face publishes (`_sh_env` answers "IFS" from the buffer instead of
  # getenv, which was never right since bash ignores an inherited IFS).
  # f14/f15 pin the EMPTY-word contract: an empty value splits to ZERO
  # fields, and the one-element list the C `for` lowering emits for an
  # empty UNQUOTED word is provably different from it. That renderer gap
  # cannot be closed here — the two programs lower to byte-identical shIR
  # because `StrStyle` has no "unquoted" value — so it is filed as
  # core-requests/c-20261104-unquoted-empty-word.md.
  # g1-g5 model the FALLBACK slice (`_sh_arr_slice`, sep-parameterised): a
  # join-then-split arm whose separator must match the JOIN's (IFS[0] for
  # `[*]`, a literal space for `[@]`). It is the INVERSE OF ITS OWN JOIN,
  # not bash's field splitting — `sep_fields` keeps every empty field
  # (the join only inserts between words) while `ifs_fields` does not.
  # Honest: vbuf growth assumed (P3); fnmatch engine is an oracle.
  "c_str_helpers.rs:103:40"
  # The C generator's capture/wrap quoting
  # (sh2perl/src/c_backend.rs `_sh_wrap_cmd` + `_sh_system_rc` +
  # `_sh_capture` + the word-quoting family). Proves injection-freedom
  # (every `'` becomes the 5-char splice; the wrapped command parses as
  # exactly `bash -c '<q(cmd)>'`), the splice shape, the word-quote
  # core, the newline gate, the status mapping (total + disjoint:
  # -1->127, exited->status, else 1), capture empty-arm + strip
  # semantics, `_sh_sc` NULL-safety, and the `"don't"`/exit-3/signal
  # pins (with the corrected length 9, found by the proof).
  # Honest: vbuf growth assumed; system/popen execution is the OS
  # contract; argv-tail gating unmodelled.
  "c_capture_wrap.rs:16:40"
  # The C generator's DECL-COVERAGE censuses — the three collect_*
  # walkers (hoist / file-scope inventory / read-routing) over
  # (sh2perl/src/c_backend.rs `collect_store_expr`, `collect_assigned_vars`,
  # `hoist_vars`), their VETO exactness, and the param/raw write bridge.
  # Proves the invariant this session's six source fixes restore: every
  # write a walker's arm-shape misses is caught by the others (coverage
  # is the union in practice and hoist alone after fixes (a)-(d)), the
  # const-lift veto set is exactly the param/raw write positions (sound
  # AND precise), and pins the measured corpus shapes (t04 params,
  # while-cond printf, elsif-cond-in-fn, return-collect, select-menu
  # param write, printf/let in fn scope). Three one-token mutants, each
  # killing a named obligation.
  #
  # PINNED DOWN 2026-11-09: the working copy verifies 54, the committed model
  # 51. The 54 belongs to an unlanded increment whose new pin
  # (`pin_assign_chain`) maps to `expr_position_assign_routes_to_the_variable`,
  # a source test that is also still uncommitted — so the extractor FATALs on
  # it at HEAD. Owner: when that test lands, commit the model + the
  # regenerated `c_decl_coverage_sync.txt` together and restore 54 here.
  "c_decl_coverage.rs:51:40"
  # The C generator's STRING-LITERAL ESCAPER (sh2perl/src/c_backend.rs
  # `cstr`, the single funnel for every emitted literal incl. printf
  # format strings). Models the C lexer as a finite-state machine over
  # one char per step (`run`/`flush`) and proves round-trip: decode of
  # the emitted literal equals the source bytes for every valid string,
  # via the per-char boundary-locality bridge. Pins the measured shapes
  # (\001a, \0019, \0017 digit followers, named escapes, marker
  # \263) and carries the SHIPPED \x hex divergences as `emit_old`
  # negative controls: 0x1a-for-2-bytes (t1), 0x19 (t5), the
  # out-of-range arm (t7). Three negative-control pins inside the file.
  "c_str_lit.rs:19:40"
  # The C generator's WRITE ARM — the `"=" | ":="` branch of the
  # `${...}` param renderer (c_backend.rs expansion emitter), with the
  # two gates that make it safe: `param_write_target` (census) and the
  # length-census supplement `supplement_write_lengths`. Extended
  # denotation: UNSET vs SET-EMPTY + provenance-carrying cells
  # (Static / Owned(word,id)). Proves the three rendered arms
  # value-correct against bash (`value_agrees`, `heap_sound`,
  # `buf_sound`, `num_sound`), the heap arm's OWNERSHIP (the xstrdup
  # adoption is what makes the scope-end free sound — mutant A drops
  # it), the bounds routing (`bump_never_shrinks` + `bound_routes`,
  # strcpy_fits under the 1024 CAP), and PINS the one known
  # normalization gap (`bare_setempty_gap`: bare `=` normalizes to
  # `:=` downstream — 0 corpus occurrences) rather than hiding it.
  # Two in-file mutants + six measured-shape pins; the source defects
  # fixed alongside (parser glue, length census, copy-prop RHS walk)
  # are C_UB_PROOF.md §24.
  "c_write_arm.rs:17:40"
  # The C backend's GROWTH-HELPER FAMILY — the emitted vbuf protocol
  # that §20/§21 listed as an assumption ("vbuf growth assumed"):
  # `_sh_grow` / `_sh_vgrow` (doubling) / `_sh_grow_str` (+zero-fill)
  # / `_sh_reserve_*` (guarded), the `_sh_add`/`_sh_addc`/`_sh_fa`
  # appends, the `snprintf_grow` loop, the vec-slot guard, and
  # `_sh_fgets_line`'s capacity/NUL discipline. Size_t arithmetic is
  # wrap-EXPLICIT (u64 = x mod 2^64), so every capacity theorem
  # carries its exact domain: fast-path identity, cap >= need after
  # growth, alloc <=> cap >= 1 <=> p non-null deref-safety,
  # byte-exact appends (the `+1` in the need), doubling termination
  # under need <= 2^63 with the amortization bound cap <= max(base,
  # 2*need), snprintf-loop termination over ANY int-typed return
  # sequence (within imax - cap + 2 calls), grow_str's zero-fill +
  # old-slot preservation, and reserve's guard=>no-wrap
  # UNCONDITIONALLY — the asymmetry A/B/C cannot claim. Pins the
  # exact wrap thresholds (2^63 stall / wrap-to-0) and carries three
  # mutants (drop the +1, drop the zero-fill, drop the reserve
  # guard) — C_UB_PROOF.md §25.
  "c_vbuf.rs:39:40"
  # +9 (2026-11-05): the NO-COLON SET-NESS faces on an ELEMENT. bash's
  # predicate is "index i is an element" = `slot.is_Some()` — a set-but-
  # EMPTY element IS set — so the three value faces resolve through
  # `presence_override` in `param_call` (in range AND `_sh_pres_arr[i]`,
  # or range alone for marker-less VALUE storage) and the `?` face aborts
  # on its negation. Proved exact under `pres_wf` (the marker byte is
  # `is_Some` for every real element) and under `value_wf` (range alone,
  # for `long long a[]` storage); four mutants kill the emptiness test
  # (`c_dash_empty`) that shipped before it.
  "c_sparse_array.rs:45:40"
  # The C generator's ASSOCIATIVE-ARRAY faces (c_backend.rs:
  # `_sh_assoc_set`/`_sh_assoc_get`/`_sh_assoc_unset`, the value join
  # `_sh_join_arr`, the `{id}_n` count arm, the `m[k]+=v` RMW — all
  # measured red before 2026-10-30's fixes). THE DENOTATIONAL
  # EXTENSION: a bash assoc array is a finite Map<Str,Str> over the
  # parallel (keys, vals) storage with wf = equal length AND pairwise
  # distinct keys; the theorems are the per-face correspondences:
  # get = map lookup ("" off the map), set = insert (first-match
  # replace / append), unset = remove with survivors in order, count
  # = keys.len() == bash's distinct count, the key set == dom, the
  # emitted fold == bash's space join (newline join retired as M1),
  # plus the int-attr arm at INTEGER level and the homing veto.
  # Set-level bridges (sset membership, distinct_cons,
  # insert/remove commute) carry the wf restoration in both mutation
  # frames. Pins the measured b1-b4 probe scenarios; four mutants
  # (newline join, no-op unset, concat-as-sum, veto miss) each kill
  # one obligation. Evaluation discipline is part of the model:
  # `by (compute)` over a LET-BOUND recursion result diverges — every
  # compute assert takes the full concrete call term, and counts are
  # stated on `.0.len()` (the emitted `{id}_n` arm), never on
  # `dom().len()` (uninterp for the evaluator).
  # +8 (2026-11-05): KEY PRESENCE for the same four faces on `${m[k]}`.
  # `_sh_assoc_get` returns a NON-NULL "" for a MISSING key, so the value
  # cannot answer set-ness; the new `_sh_assoc_has(k, n, key)` scans the
  # key list, which `has_is_dom` proves equals `dom(the_map)`. Mutants
  # pin the three measured rows (`m[k]=` present-empty, absent, `+`). +4
  # more (same day): the `=`/`:=` faces INSERT through `assoc_set`
  # (`assign_table`/`colon_assign_table`), so `{id}_n` grows exactly when
  # bash's key count does; m13 kills "yield without inserting".
  "c_assoc_array.rs:54:40"
  # The C generator's IFS JOINS (c_backend.rs: `_sh_join_arr_ifs`,
  # `_sh_join_arr_rng`, the `star` slice dispatch in `param_call`,
  # `_sh_join_arr` for the `[@]` face, and `emit_var_decl`'s const-lift
  # VETO for IFS — 064_07's `${config[*]}` fed `sort` one space-joined
  # line before the fix). THE DENOTATIONAL EXTENSION: ifs_sep = first
  # char of IFS, "" → NO separator, never-assigned = the decl's startup
  # space; present(slots) presence protocol (holes dropped, empty words
  # kept); rng_slice bounds count ELEMENTS (bash ground truth measured
  # 2026-10-30: `a=(a b c); a[5]=z; ${a[*]:1:3}` → `b c z`). The `[@]`
  # face of the WHOLE expansion provably never reads IFS; the whole-
  # slice short-circuit equals the range path (rng_whole_is_all). The
  # 2026-11-04 extension splits the slice face from it: an `[@]` SLICE
  # joins on IFS[0] with a space fallback (`slice_at_sep`), so under a
  # colon IFS `${a[@]}`=`x y z` but `${a[@]:1:2}`=`y:z` — c17 revised
  # (it had claimed a space), c33-c35 added, m7 = the retired hard-coded
  # space; ifs-probe case 21 was the xfail this retires. Pins the
  # 40-case probe battery (c01-c35). Six mutants each kill one
  # obligation: hardcoded space, join-then-space-split (the retired
  # `_sh_arr_slice` route), const-lift without the veto, `[@]` on IFS,
  # dense-index slicing, and the retired `[@]`-slice space.
  #
  # PLUS the DENSE-VALUE join (`declare -ia a=(1 2 3)`): `dense_face`
  # takes the densified ELEMENT LIST (value storage keeps no presence
  # marker) rather than `present(slots)`, sharing `join_sep`'s separator
  # invariant (d7), so d1/d2/d3 pin the three measured faces (startup
  # space, empty IFS concatenates, `[@]` always a space), d4 pins that
  # the dense list and the presence list of the same array DIFFER (the
  # value half of the C type confusion that SIGSEGVed: rc 139, fixed
  # 2026-11-04 by converting inline in the renderer), d5 the empty/one/
  # empty-IFS boundaries, d6 the k-1 separator count. Mutant: collapsing
  # the `[@]` arm into the IFS arm fails d3. Verus cannot see C types,
  # and cc does not catch this one either (GCC 13.3 only WARNS,
  # -Wincompatible-pointer-types; measured) — so the type side is the
  # probe battery's runtime diff (ifs-probe 54-54f), stated in the
  # model's SCOPE note.
  #
  # PLUS the PRESENCE MARKER (`{id}_set[]`, 2026-11-04): a fixed dense
  # int array now carries a byte-per-slot marker, so its element list is
  # `present(slots)` again and `dense_marked_face` is PROVABLY the char**
  # face for both faces and any IFS (e4) — nothing dense-specific is left
  # in the join semantics. e1 pins bash's sparse readings (count 2,
  # `7 9`, `${n[1]}` empty), e2 count=popcount vs extent, e3 the key set
  # `0 2`, e5 `unset` removing the element, e6 a real 0 being present
  # (why presence cannot be derived from the value), e7 the retired
  # extent protocol disagreeing on the same array. Mutant: routing
  # `dense_marked_join` back through `densify` fails e1/e4/e7.
  #
  # PLUS the APPEND base (2026-11-04): `arr+=(…)` lands one past the last
  # SET element (`append_base`), which is the extent for a dense array but
  # NOT for one emptied by `unset` (there `_len` is 1 and bash appends at 0).
  # f1 pins the three measured bases, f2 that the extent is not the base,
  # f3 the post-append count. Mutant: `append_base` replaced by
  # `slots.len()` fails f1/f2 (`1 == 0`).
  #
  # PLUS the SLICE WINDOW (`rng_slice` / `take_present`, 2026-11-05): an
  # (off, len) grid over four sparse shapes (476 measured rows) showed the
  # two bounds are of DIFFERENT KINDS — the OFFSET indexes SLOTS (negative
  # counts slots back from last_index+1, out of range is EMPTY, never a
  # clamp) while the LENGTH counts PRESENT ELEMENTS, scanned forward with
  # holes skipped and unspent. The retired `slot_window` (bounded by
  # `b + len` SLOTS) is kept in the model as the transcription of the
  # pre-fix helper, and mw1-mw6 are the measured rows where it and
  # `rng_slice` disagree: `a=(a b c); a[5]=z` `${a[*]:1:3}` = `b c z` (was
  # `b c`), `a[3]=x; a[7]=y` `${a[*]:0:2}` = `x y` (was EMPTY), `: -4:1` =
  # `c` (was `a`, an element-counted offset), `:6` EMPTY, and both faces
  # agreeing under IFS=: . This is the row the model LACKED while the
  # helper shipped — it stated the bounds as one slot window, so nothing
  # there could contradict the code.
  #
  # PLUS the ASSOC and KEY faces (2026-11-05). Three join rules, measured in
  # a ONE-WORD context (an assignment, so echo's own argument joining cannot
  # be mistaken for the expansion's): (a) the assoc VALUE `[*]` face is the
  # shared fold — IFS[0], concatenating on an empty IFS — and `[@]` is a
  # space join even under `IFS=:` (k2/k3); (b) the KEY face reads IFS[0] for
  # both faces and both storages, falling back to a space only for `[@]` on
  # an EMPTY IFS (k1a); (c) an ASSOC slice's positive offset is ONE-BASED —
  # `:0:1` and `:1:1` both take the first element, `:2:1` the second — an
  # offset past the end is EMPTY, a negative one CLAMPS at 0 (`: -9` on three
  # elements is the whole list), the length counts elements, and a negative
  # length errors only for an in-range offset (a1-a6). The retired newline
  # assoc join is kept as `nl_join`, with the proof that 064_07 — which sets
  # `IFS=$'\n'` — passed for the reason the code was wrong.
  #
  # PLUS the `!` FAMILY's COLLAPSE (k1b/k1c/k1d): `${!a[*]}`, `${!a[@]}`,
  # `${!a[*]:o:l}`, `${!a[@]:o:l}` and `${!a[1]}` all lower to
  # `param("slice", "!a", "@", "")` — face, bounds and subscript erased —
  # while bash gives four behaviours (whole join on IFS[0], ERROR for the
  # slice spellings, empty for the single-key one). So NO renderer of that
  # node is exact (k1c, witness = the `[@]` reading against the slice's
  # error) and k1d states the exactness DOMAIN that still holds: the shipped
  # rule is exact for `[@]` under every IFS and for `[*]` whenever IFS is
  # non-empty, leaving the empty-IFS `[*]` row as the erasure's only cost.
  # The fix is a contract change, so it is filed as an OFFER:
  # core-requests/c-20261105-keys-face-collapse.md.
  #
  # COUNT (measured 2026-11-09, the pinned binary): the COMMITTED model
  # verifies `73 verified, 0 errors` at `--rlimit 40`, not 104. The 104 was
  # recorded for the §6/§7 extension while it was still IN FLIGHT, and
  # neither state in the tree equals it: `git show HEAD:…/c_join_ifs.rs`
  # gives 73/0, and the uncommitted working copy gives
  # `108 verified, 1 errors` (`w3_hole_skip_is_load_bearing` fails its
  # `at_words(empty_word_first()).len() == 2` postcondition). The entry
  # therefore asserts what the COMMITTED model actually checks, so this
  # gate line reports the truth instead of a target it cannot verify. When
  # the extension lands, its author re-blesses this number WITH the
  # measurement in the same commit — an exact count is the point, so do not
  # round it back up to the old target.
  "c_join_ifs.rs:73:40"
  # The C generator's WORD-EXPANSION ORDER (c_backend.rs: `stmt` /
  # `stmt_inner` / `stmt_has_elem_assign` / `snap_elem` / `array_index_read`,
  # plus the `set --` arm's field splitting). THE DENOTATIONAL EXTENSION: a
  # command's word list is a LIST OF FACES expanded LEFT TO RIGHT, each
  # evaluated against the store as it stands at ITS position — bash shows a
  # `${a[i]:=w}` store to every LATER face and to no EARLIER one. MEASURED
  # 2026-11-05: `a=(''); echo "${a[0]}" "${a[0]:=z}"` printed `[z] [z]`
  # (the store's statements are emitted while the LATER word renders, so the
  # argument vector evaluated the inline read after the store); the fix
  # materialises plain element reads into statement temps, so the fold is
  # positional. Two carrier holes the first attempt left red — `printf`
  # folds to `IrStmt::Output` and a shell function's `echo` arrives as
  # `Return(Some(..))` — are proved, not narrated (`m2_narrow_walk`).
  # `set --` also gains the split it was dropping: `set -- $x` with
  # `x='a b'` is TWO positionals (`fields_two`), `x=''` is ZERO
  # (`fields_drop_empty`), `IFS=:; x='a::b'` is THREE with an empty middle
  # (`fields_ifs_colon`, and `m3_one_rule_for_both` proves the whitespace
  # rule is not a substitute). Pinned residual: an unquoted `${a[i]}` carries
  # NO `split` marker (`arrayindex_arrives_unsplit`) — a parser erasure, so no
  # renderer of that IR can split it.
  # §6 generalises that to the QUOTEDNESS bit, measured 2026-11-05 as
  # BYTE-IDENTICAL shIR: `z=""; set -- $z` and `z=""; set -- "$z"` both
  # lower to `["--", Str ""]` while bash counts 0 and 1 words; likewise
  # `x=""; set -- $x a` (1) and `set -- "" a` (2) are one `Str ""` word
  # (`same_ir_for_both_spellings`, `const_fold_is_the_same_erasure`).
  # `no_renderer_of_collapsed_words_is_exact` therefore proves the renderer
  # CANNOT be finished on this IR, and `kept_flag_makes_it_exact` proves the
  # contract change (a quotedness bit on the word node) IS sufficient — so
  # this is an OFFER per PLAN §11, not a C-arm patch. §7 records the LANDED
  # side: the collapse's author was the shared pass (`split_fold` folded on
  # whitespace-freedom ALONE, unsound exactly on the empty value), which now
  # keeps the marker unless the word is provably NON-EMPTY — so the marker IS
  # the quotedness bit and the existing C arms are exact
  # (`fix_is_exact_for_both_spellings`, `fold_is_sound_iff_nonempty`).
  # MEASURED after the fix: `x=""; set -- $x` → 0 words, `x=""; set -- "$x"`
  # → 1, `for w in $e` → 0 iterations; C gate 625/19/7 byte-identical,
  # ./fail 563/563, fail-estree 563/563.
  "c_expand_order.rs:36:40"
  # The C generator's STATIC-`eval` INLINING (c_backend.rs:
  # `static_eval_stmts` + `expand_static_evals`, called from `shir_to_c`
  # BEFORE every analysis). A literal `eval '<text>'` denotes the statements
  # of `<text>`; the pre-pass splices them into the IR so the ONE census
  # (decl inventory, type/lifetime analyses, read routing) sees them.
  # 063_12 emitted `_sh_sset(&result, …)` with `result` undeclared (cc) and
  # read it back as `_sh_env("result")`. The model flattens a program to its
  # in-order leaves tagged by enclosing-eval depth, so `expand` is a
  # per-leaf retag and every fold is a cursor recursion:
  # `expansion_preserves_meaning`/`assigned_invariant` (the rewrite moves
  # nothing), `census_is_exact` + `fixed_census_is_complete` (THE FIX, under
  # `dyn_free`), `opaque_never_over_declares` (the pre-fix census only ever
  # MISSES), `witness_063_12`/`route_var` (the measured before/after),
  # `dyn_eval_not_covered` (the honest scope) and `expand_idempotent`.
  "c_eval_inline.rs:20:40"
  # The C generator's `unset` on a SCALAR (c_backend.rs:
  # `demote_unset_scalars` + `unset_scalar_census`, run from `shir_to_c`
  # after the stringy demotion). bash's variable is a PARTIAL map — `None`
  # (unset) is not `Some("")` — and an INT decl can spell neither: `unset x`
  # emitted NOTHING, so `x=5; unset x` kept answering 5 (`${x:-gone}` → 5,
  # `$((x+1))` → 6, `$x` → 5; all measured 2026-11-04). A scalar the program
  # unsets is demoted to STRING storage, where the state exists. The model
  # calls the identification `quot` and proves which faces survive it
  # (`q_plain`/`q_len`/`q_arith`/`q_colon_default`/`q_colon_plus` — the
  # emptiness-testing ones, i.e. the fix's whole target), which half of the
  # no-colon faces it completes (`q_dash_*_unset`), why the REST is
  # impossible rather than unfinished (`no_face_separates` — no function of
  # the quotient can separate `None` from `Some("")`, while bash's `${x-w}`
  # does; witness `dash_gap_is_the_set_to_empty_case`), the pre-fix
  # divergence on the measured numbers (`pref_int_keeps_the_value`,
  # `pref_int_arith`), and the census itself (`demote_is_a_kind_change`,
  # `demote_hits_the_right_names`, `element_and_flag_are_not_scalar_unsets`).
  # §4 models the census WALK, because the decision is only as good as its
  # input: `demote_unset_scalars` demotes a var that an emptiness face reads
  # and no assignment to which is unconditional, and the face collector was a
  # hand-written `match` over `IrStmt` with a `_ => {}` tail and NO `Output`
  # arm — but `printf '%s' "${x:-}"` is `IrStmt::Output`, not `Expr(Call)`, so
  # the face was invisible and `r=$(echo hi) || { x=$?; }` plus
  # `printf "%s=%s" x "${x:-}"` printed `x=0` where bash prints `x=`
  # (MEASURED 2026-11-05; examples/parse-dollar-paren-or.sh, a corpus FAIL).
  # `narrow_walk_misses_the_output_face` is the bug (the SAME word seen
  # through `echo`, missed through `printf` — a carrier hole, not a semantic
  # one), `full_walk_sees_it_through_every_carrier` the fix (the exhaustive
  # `for_each_stmt_expr`, `_` arm gone so a new variant is a compile error),
  # `plain_read_is_not_a_face` the reason it stays a narrow census, and
  # `exhaustive_walk_is_what_makes_the_demotion_sound` the composition with §3
  # (demoted → exact face; Int-homed → the number `"0"`, which is not bash's
  # empty string).
  # §5 is the OTHER distinction bash makes, on the SAME storage: `-`/`+`/`=`
  # test SET-NESS while `:-`/`:+` test NON-EMPTINESS. MEASURED 2026-11-05:
  # `x=""; ${x-w}` → C `w` / bash ``, `x=""; ${x+w}` → C `` / bash `w`,
  # `unset x; ${x=w}` → C `` and no assignment / bash `w` then `w`. The data
  # is not the obstacle (a heap scalar's NULL IS a presence bit, and the `-`
  # arm already emits `(x ? x : w)`); the OPERATOR is — the parser folds
  # `${x-w}` into `param(":-", "x", "w")`, and `${x=w}` into `param("",
  # "x=w")`, a "variable" named `x=w`. So §5 proves BOTH halves:
  # `presence_renderings_are_exact` (a fix exists, for every state),
  # `emptiness_render_fails_on_set_empty` (the shipped arm is wrong, on the
  # measured inputs) plus `emptiness_is_right_on_the_unset_half` (why it
  # looked right), and then `collapse_loses_the_colon` +
  # `no_renderer_of_the_collapsed_ir_is_exact` — NO renderer of the collapsed
  # IR can be exact, because `${x-w}` and `${x:-w}` are the same input. That
  # made the residual an AST/contract change (a new operator spelling, an
  # OFFER across backends per PLAN §11), not a one-backend patch — and that
  # change LANDED: `every_spelling_is_exact` states the result, all fifteen
  # measured state × face combinations are byte-identical to bash, and
  # `${v=w}` now stores its default.
  # The FOURTH member is `?`: `${v?w}` errors only when v is UNSET while
  # `${v:?w}` also errors on set-to-empty (MEASURED 2026-11-05: `x="";
  # ${x?boom}` prints `[]` and exits 0 in bash; C aborted rc=1 because the
  # spelling had been folded into `:?`). `question_keeps_the_colon` states the
  # pre-fix collapse and the one state where the merged predicates disagree,
  # `question_spelling_is_exact` that the shipped NULL-pointer test IS bash's
  # condition; the arm also gained a `getenv`-presence case for env-only
  # names. All eight measured `?` cases match on stdout and exit status.
  "c_unset_scalar.rs:27:40"
  "c_printf_v.rs:22:40"
  # …plus the ERROR path (the div-by-zero abort, measured 2026-11-05):
  # `u=7; let u=u/0` → bash `[7] rc=1`, the renderer stored 0. The
  # divider is total BY DESIGN (`(r == 0 ? 0 : l/r)` — C would SIGFPE),
  # so the value 0 is a lie only the STORE can repair; the model carries
  # an `Outcome` (Val/Err) and proves the abort leaves the store alone
  # (`error_aborts_the_store`), that the detector is SOUND
  # (`detection_is_sound`) and NOT complete (`detection_is_incomplete` —
  # the pinned runtime-zero gap), that the error and the zero-value cases
  # agree on status 1 (`error_status_is_one`), and that the two sites
  # consult ONE predicate (`both_sites_share_one_predicate`).
  "c_let_scope.rs:38:40"
  # The C generator's FLATTENED SUBSCRIPT (c_backend.rs:
  # `subscript_explicit_arith` / `subscript_arith_inner`
  # / `has_arith_op` / the `collect_assoc_names` census arms / the arith
  # arm of `emit_array_assign` / `dyn_key_c` / `array_index_read`; plus
  # the DSE side, transforms/dead_store_elim.rs:
  # `subscript_read_names` + `arith_read_names`). ONE classifier drives
  # the declaration census and the store arm, so they cannot disagree —
  # the pre-fix pair had two independent predicates and is proved
  # divergent on the measured shapes (`prefix_diverges_on_ident`,
  # `prefix_calls_arith_assoc`). Pins k1-k16 are the measured bash truth
  # table (arith/numeral/dynvar/ident/arith-text/word, the index text, and
  # the assoc key text — explicit form = VALUE, bare form = LITERAL).
  # `subscript_closure` / `dead_needs_no_mention` are the LIVENESS
  # obligation the pre-fix read set broke (`fix_was_necessary`); mutants
  # m1-m3 are the retired behaviours. Measured by
  # `harness/ifs-probe.sh` 59/59b-59m.
  "c_subscript.rs:37:40"
  # The C generator's REDIRECT REORDER + word quoting
  # (c_backend.rs redirect arm + `_sh_word`): the fd-prefix parse round
  # trip, the `'`-splice quoter over the `run`/`esc` state machine
  # (structural `run_one`+`run_concat` chain — `by (compute)` over `run`
  # with a symbolic state diverges, same discipline as c_assoc_array),
  # the dup/close raw arm's quote-freedom, THEOREM `reorder_safe`
  # (`emit_order` preserves the fd table under `safe(rds)`) with
  # `n1_fd0_conflict` proving the side condition necessary (measured
  # 2026-11-01 /tmp/redprobe: bash FROM_FILE vs generated
  # FROM_HEREDOC), and the ps-flip monotonicity. Also carries the
  # `reads0` model fix (Wc|A widened to the mode set `written`
  # consults — `written_frame` was provably false without it).
  # Named mutants m1-m3+, each killing one obligation.
  "c_redirect.rs:46:40"
  # Store-forward sweep (Tier-1): counted-loop append -> indexed store
  # (append_to_store.rs 590 lines). Per-trip + whole-loop induction
  # under the guard-verdict oracles (exactly-one site, empty init, no
  # other write, counted +1 loop, known bound, 1:1, no escapes): each
  # rewritten store at counter k pushes the same value the append
  # would. 7 unit-test pins + multi-element structural refusal +
  # runtime agreement. Mutant (no-other-write dropped) red 18v/2e.
  "append_store.rs:20:40"
  # Store-forward sweep (Tier-1): set[int] -> small/big partitions
  # (split_set.rs 958 lines). isSmallInt routing preserves set
  # semantics: membership agreement (contains_push/insert_contains
  # lemmas) + sorted-join merge agreement. 4 unit-test pins + dedup +
  # runtime agreement. Mutant (gate dropped) red 12v/2e.
  "split_set.rs:14:40"
  # Store-forward sweep (Tier-1): echo-return passes 2-4 under an
  # eligible-set parameter (echo_return.rs 1556 lines). Body echo ->
  # Return + call-site echo(fnValue) preserve statement/capture/
  # last-stage bytes and status. 6 unit-test pins + bare-shape
  # negative control. Mutant (bare fnValue at stmt) red 10v/3e.
  # Pass 1 (SCC fixpoint) + pass 4 (case-pattern hoist) are
  # parameters — SCC soundness is the verdict-analyses sweep.
  "echo_return.rs:13:40"
  # Arith-lowering sweep (Tier-1): let-arg text -> Assign/IncDec
  # arith -> Assign stmt (arith_forms.rs 489 lines). The structured
  # Assign updates the store exactly like the let-exec's evaluation;
  # the compound read-modify-write keeps the old value. 15 unit-test
  # pins. Mutant (x+=E as x=E) red 14v/1e. Fires on ((..))/let
  # shapes (14+ corpus files).
  "arith_forms.rs:15:40"
  # Arith-lowering sweep (Tier-1): init + counter-while + trailing
  # step -> ForInit (counted_while_forinit.rs 547 lines). The ForInit
  # runs the same iteration trace under the guard conjunction
  # (adjacent init, nonzero-literal step both spellings, clean prefix
  # and cond). 7 unit-test pins + trace agreement + nonzero-gate
  # load-bearing. Mutant (zero step accepted) red 12v/1e. Fires
  # 9/563 in-pipeline.
  "counted_while_forinit.rs:13:40"
  # Verdict-analyses sweep (Tier-1): SCC contract over the call graph
  # (scc.rs 450 lines). Reported sets are strongly connected,
  # disjoint, covering, and maximal (no cross-set merge); the
  # condensation is acyclic (echo_return's fixpoint termination).
  # Collect-callees walk as oracle. 6 unit-test pins + pair lemmas.
  # Mutant (merged claim across acyclic edge) red 20v/1e.
  "scc.rs:21:40"
  # Verdict-analyses sweep (Tier-1): must-defined dataflow
  # (used_before_decl.rs 1497 lines). Meet soundness, def transfer,
  # flag soundness, loop-entry fallback. Census/traversal as
  # parameters. 10 pins mirror the 11 unit tests. Mutant (union meet)
  # red 13v/2e.
  "used_before_decl.rs:15:40"
  # Verdict-analyses sweep (Tier-1): mask_threshold soundness
  # (maskable.rs 430 lines). Square bracket by compute, linear
  # inversion via lemma_mul_inequality, divisor/pow2 gates; shape
  # classifiers and isqrt as oracles. 6 unit-test pins. Mutant
  # (le-arm off-by-one) red 10v/2e.
  "maskable.rs:12:40"
  # Verdict-analyses sweep (Tier-1): span coverage + consumption
  # liveness + escape-conservatism (lifetime.rs 1190 lines). Census
  # walk as oracle. 10 pins mirror the 12 unit tests. Mutant (shrunk
  # span) red 12v/2e.
  "lifetime.rs:14:40"
  # Verdict-analyses sweep (Tier-1): seed-table consistency
  # (numstr.rs 1180 lines). Pinned stability, var/position soundness
  # under earned sets, revalidate removal-only. Fixpoint and
  # classifiers as parameters. 6 pins mirror the 10 unit tests.
  # Mutant (verdict needs no justification) red 9v/2e.
  "numstr.rs:11:40"
  # Verdict-analyses sweep (Tier-1): marked ==> all-uses-numeric
  # (numeric_observed.rs 1155 lines). Chain-veto propagation,
  # per-slot contract. Census/fixpoint as parameters. 6 pins mirror
  # the 11 unit tests. Mutant (text-observed marked) red 8v/2e.
  "numeric_observed.rs:10:40"
  # String/cursor sweep (Tier-1): Interpolate -> StrSplice
  # denotation identity (str_splice_fold.rs 372 lines). Fold-gate
  # conjunction as premises; the join-unwrap; the repl middle.
  # 8 unit-test pins + value identity. Mutant (gates dropped) red
  # 9v/2e.
  "str_splice_fold.rs:11:40"
  # String/cursor sweep (Tier-1): grab/strip cursor dynamics
  # (str_chop_cursor.rs 2253 lines). Field identity, strict advance
  # past the delimiter, init-0 default; five read-law premises as
  # oracles. 11 unit-test pins. Mutant (cursor lands on delimiter)
  # red 16v/1e.
  "str_chop_cursor.rs:17:40"
  # Loop-hoist (Tier-1): leading invariant run -> prologue
  # (hoist_loop_invariants.rs 1167 lines). Pointwise store agreement
  # under the five gates; n >= 1 proviso (the proof found a REAL
  # 0-trip soundness hole — prologue runs while the original runs
  # nothing; see BUGS_FOUND.md 7, open). 8 unit-test pins. Mutant
  # (gate without invariant_reads) red 19v/3e.
  "hoist_loop_invariants.rs:22:40"
  # Suites-then-proofs trio (Tier-1): capture-of-pure-function ->
  # direct call (direct_calls.rs 255 lines); statement cat ->
  # ForEachLine (cat_read.rs 171 lines); grep -o shapes ->
  # grepMatches (grep_o.rs 237 lines). Unit suites were written first
  # (4/6/6 green, ed4b3184f). The three models below were RE-AUTHORED
  # on 2026-10-30 after the originals were lost from the working tree
  # with the rest of the sweep files: per-rewrite value models with the
  # purity / no-redefinition premises stated as lemmas (direct_calls,
  # 19), the argv parse + line-stream obligations over the plain and
  # numbered forms (cat_read, 18), and the argv table + match
  # enumeration rename (grep_o, 19). Load-bearing guards are refuted
  # in-file (direct_calls' two premise lemmas; cat_read's argv refusals;
  # grep_o's flag/operand refusals).
  "direct_calls.rs:19:40"
  "cat_read.rs:18:40"
  "grep_o.rs:19:40"
  # Carrier-canonicalization (Tier-1): payload-free Exec in a command
  # carrier -> canonical exec call (exec_call_fold.rs 384 lines).
  # Per-site payload preservation + idempotence; carrier flag as
  # parameter; 4 unit-test pins. Mutant (cleanup refusal dropped)
  # red 7v/1e.
  # PORTED 2026-11-09: the `mod exec_call_fold;` line was the whole gap — it
  # compiles against the current crate and its 4 unit tests pass, so the pins
  # execute and the sync entry now runs. Still NOT registered with any backend
  # (the offer is the marketplace's call), so this proves the pass, not a
  # pipeline that runs it.
  "exec_call_fold.rs:8:40"
  # Part-canonicalization (Tier-1): frozen-literal Expr part -> Lit +
  # adjacent-Lit merge (interp_lit_merge.rs 494 lines). Concat
  # denotation identity via whole-seq cons lemmas; style gate as data;
  # 6 unit-test pins. Mutant (Command style folds) red 23v/1e.
  # PORTED 2026-11-09: same as exec_call_fold — the missing `mod` was the only
  # gap; it compiles and its 7 unit tests pass, so the pins execute. Not
  # registered with any backend.
  "interp_lit_merge.rs:24:40"
  # ForInit-lowering (Tier-1): ForInit -> Block(init + While) with the
  # step spliced before every first-class continue (strip.rs).
  # Splice-shape identity over fuel-bounded loop combinators; 4
  # unit-test pins. The model was WRITTEN with a soundness fix for the
  # legacy `Expr(Call("continue"))` shape (leveled continue skipped the
  # step); commit 9928671cd deleted that arm and its unit test, so the
  # model is re-pinned WITHOUT it and the fix claim is withdrawn — see
  # the model's SOURCE DRIFT note. Mutant (step before Break) red 11v/2e
  # on the 13-obligation version. No *_sync.txt baseline.
  "strip.rs:12:40"
  # Arith-recovery (Tier-1): structured-Arith counted-while -> ForInit
  # (counted_arith_forinit.rs 383 lines). Trace identity; three +1
  # step spellings + Arith-cond gates; 6 unit-test pins. Mutant
  # (accepting +2) red 9v/3e.
  "counted_arith_forinit.rs:12:40"
  # Element-forward: single-def element load -> forwarded reads. RETIRED
  # 2026-11-09 — see RETIRED_MODELS below. Its target could not be ported:
  # `src/transforms/arr_load_fwd.rs` imported `super::READ_ONLY_CALLS` and
  # `string_accumulator::{callee_write_sets, Cw}`, none of which exist
  # anywhere outside that file, and called four helpers the crate has since
  # made private; declaring the module did not compile (E0432/E0603). The
  # source file is deleted and the model is kept as a superseded-design
  # record, verified but counted outside every total (same as `interval.rs`).
  # Temp-isolation (Tier-1): single-use pure temp -> inlined use
  # (isolate_accumulate.rs 1038 lines). Substitution agreement; 8
  # unit-test pins. Mutant (multi-use inlines) red 17v/1e.
  "isolate_accumulate.rs:18:40"
  # Lane-verdict (Tier-1): lane-nest classification soundness
  # (lane_private.rs 500 lines). Dominating-defs + tail + acc-clean;
  # 9 unit-test pins. Mutant (uninit write admitted) red 10v/2e.
  "lane_private.rs:12:40"
  # Footprint-verdict (Tier-1): RuntimeFootprint walk soundness
  # (analysis.rs 686 lines). False implies all-pure (the consumer's
  # licence for plain host code); true claims nothing. 8 pins, all
  # UNMIRRORED by design (no footprint unit test exists). Mutant
  # (redirect as pure) red 19v/2e.
  "analysis.rs:21:40"
  # Loop-hoist (Tier-1): leading maximal pure-invariant run ->
  # prologue (loop_opt.rs 1294 lines). Whole-loop induction,
  # pointwise agreement (n >= 1); twin of the proved
  # transforms/hoist_loop_invariants. 8 pins mirror the 7 unit
  # tests (8/8 PASS live). Mutant (invariant_reads dropped) red
  # 20v/1e. DEAD CODE: no pipeline caller (0/563 in-pipeline).
  "loop_opt.rs:21:40"
  # Goto-restructure (Tier-1 carve-out): per-shape structural
  # identities (restructure.rs 1372 lines). Span/branch/dead/skip/
  # flag-order sequence identities + jump elimination; full
  # run-preservation is Tier-3 (out of scope). 7 pins mirror 7 of
  # 8 unit tests (7/7 PASS live). Mutant (spurious skip flag) red
  # 19v/1e.
  "restructure.rs:20:40"
  # Optimize-delta (Tier-1): DCE census shapes + decl-guard +
  # const_prop gate + drop theorem (optimize.rs 2727 lines).
  # Unmarked-in-later implies unread-everywhere; fold/DCE/subst
  # cores not remodelled (proved elsewhere). 11 pins mirror 9 of
  # 12 tests (11/11 PASS live). Mutant (IFS dropped from [*]) red
  # 16v/1e.
  "optimize.rs:17:40"
  # Tier-1: type-query (transforms/type_query.rs) -- `type NAME...` is
  # answered from the program's functions and the 58-entry true-builtin
  # table, or refused. Proves the rewrite preserves the queried names and
  # their ORDER (so `type f | head -1` reports f), that every emitted line
  # has an answer (all_classified premise), and that a mixed known/unknown
  # list is refused WHOLE (no partial answer that would swallow bash's
  # not-found line). The table itself is pinned Rust-side
  # (`builtin_table_is_the_58_true_builtins`: count, dedup, `ls`/`head`
  # absent), since the model takes it as a parameter.
  "type_query.rs:17:40"
  # Terminator-binop (Tier-1): `break || exit 1` — a control call as the
  # LEFT operand of `&&`/`||` transfers control, so the right operand is
  # dead at statement position. bin_control_dead proves the BinOp
  # statement and the bare control call run identically (trace, status,
  # abort flag) for EITHER operator, ANY rhs, and ANY status the call
  # reports -- the operator is never consulted; the fold is thus
  # independent of `break 99`/`exit 3`/`return 2` statuses (measured:
  # `break 99` reports 0, `exit 3 && echo` never echoes). fold_list_sound
  # lifts it over a statement list; the transform's body recursion is
  # that theorem instantiated per body (a body is just another list).
  # capture_and_fold_unsound is the REFUSAL: inside `$( )` a control word
  # is the subshell's business and the RHS DOES run --
  # `x=$(break && echo RHS)` captures RHS (measured) -- so folding in
  # expression position would drop output; that is why only a
  # statement-position BinOp folds. Pins mirror 6 of the source's 7 unit
  # tests (the 7th, loop-body recursion, is the per-list instantiation).
  # Mutants red: a control call returning normally (5 errors) and the
  # subshell flag ignored (1 error); restored at 19 verified, 0 errors.
  # NOTE: the transform is PARKED -- `terminator_binop` has no `pub mod`
  # line in src/transforms.rs, so this proves a rule in the tree that
  # currently changes no emitted byte (the loop_opt `DEAD CODE` class).
  "terminator_binop.rs:19:40"
)

# RETIRED models: VERIFIED, never counted. `interval.rs` / `i32_bounds_exec.rs`
# model `arith_bounds`, which never landed (the live estimator is
# `arith_abs_bound`, proved in Isabelle), so their green obligations are
# evidence about a superseded design, not Tier-1 evidence — hence the separate
# list. They are still checked: a missing file or a drifted count is a FAIL,
# because removing or reshaping a retired artifact has to be a deliberate edit
# here rather than silent rot (the same failure mode as an absent model).
RETIRED_MODELS=(
  "interval.rs:5:40"
  "i32_bounds_exec.rs:7:40"
  # arr_load_fwd: source deleted 2026-11-09 — unportable against the current
  # API (see the note where it used to sit in MODELS). Verified as a record.
  "arr_load_fwd.rs:37:40"
)

# extractor:baseline — the generator script and the file it must reproduce.
# Three coverage extractors (one per P3/P4/P5 model) plus the deliberately
# empty i32 slot: `verus-sync.sh` targets `arith_bounds`, a function ABSENT
# from src/ (never landed in recorded history — see VERUS.md §(a): the i32
# interval estimator was superseded by `arith_abs_bound`, proved in
# Isabelle). It correctly FATALs on the live tree, and a permanently-red
# sync entry is noise, not signal, so it stays unregistered. The coverage
# checker instead verifies live correspondence: every model pin maps to a
# source test via a committed alias table, and every mirrored guard
# predicate still exists in the source. To register another model: add
# "harness/verus-sync-coverage.sh:<model>:sh2perl/proofs/verus/<model>_sync.txt"
# (the checker dispatches on $MODEL… see check_sync_cov below) AND commit
# the generated baseline; the gate regenerates and diffs.
# (The older models are deliberate reductions, not transcriptions —
# no mechanical extractor can bridge a shrunken calculus, except through
# the same pin<->test mapping this checker enforces. Their living tie
# remains the pin<->test mapping audited in VERUS.md §(b).)
SYNCS=(
  "harness/verus-sync-coverage.sh:copy_propagation:sh2perl/proofs/verus/copy_propagation_sync.txt"
  "harness/verus-sync-coverage.sh:function_purity:sh2perl/proofs/verus/function_purity_sync.txt"
  "harness/verus-sync-coverage.sh:test_lowering:sh2perl/proofs/verus/test_lowering_sync.txt"
  "harness/verus-sync-coverage.sh:string_folds:sh2perl/proofs/verus/string_folds_sync.txt"
  "harness/verus-sync-coverage.sh:arith_folds:sh2perl/proofs/verus/arith_folds_sync.txt"
  "harness/verus-sync-coverage.sh:test_folds:sh2perl/proofs/verus/test_folds_sync.txt"
  "harness/verus-sync-coverage.sh:capture_folds:sh2perl/proofs/verus/capture_folds_sync.txt"
  "harness/verus-sync-coverage.sh:list_folds:sh2perl/proofs/verus/list_folds_sync.txt"
  "harness/verus-sync-coverage.sh:textop_folds:sh2perl/proofs/verus/textop_folds_sync.txt"
  "harness/verus-sync-coverage.sh:not_folds:sh2perl/proofs/verus/not_folds_sync.txt"
  "harness/verus-sync-coverage.sh:const_cmp_folds:sh2perl/proofs/verus/const_cmp_folds_sync.txt"
  "harness/verus-sync-coverage.sh:elim_trio:sh2perl/proofs/verus/elim_trio_sync.txt"
  "harness/verus-sync-coverage.sh:slice_identity:sh2perl/proofs/verus/slice_identity_sync.txt"
  "harness/verus-sync-coverage.sh:case_lowering:sh2perl/proofs/verus/case_lowering_sync.txt"
  "harness/verus-sync-coverage.sh:elseif_flatten:sh2perl/proofs/verus/elseif_flatten_sync.txt"
  "harness/verus-sync-coverage.sh:seq_range:sh2perl/proofs/verus/seq_range_sync.txt"
  "harness/verus-sync-coverage.sh:ternary_desugar:sh2perl/proofs/verus/ternary_desugar_sync.txt"
  "harness/verus-sync-coverage.sh:escape_classes:sh2perl/proofs/verus/escape_classes_sync.txt"
  "harness/verus-sync-coverage.sh:f32_narrow:sh2perl/proofs/verus/f32_narrow_sync.txt"
  "harness/verus-sync-coverage.sh:append_store:sh2perl/proofs/verus/append_store_sync.txt"
  "harness/verus-sync-coverage.sh:split_set:sh2perl/proofs/verus/split_set_sync.txt"
  "harness/verus-sync-coverage.sh:echo_return:sh2perl/proofs/verus/echo_return_sync.txt"
  "harness/verus-sync-coverage.sh:arith_forms:sh2perl/proofs/verus/arith_forms_sync.txt"
  "harness/verus-sync-coverage.sh:counted_while_forinit:sh2perl/proofs/verus/counted_while_forinit_sync.txt"
  "harness/verus-sync-coverage.sh:scc:sh2perl/proofs/verus/scc_sync.txt"
  "harness/verus-sync-coverage.sh:used_before_decl:sh2perl/proofs/verus/used_before_decl_sync.txt"
  "harness/verus-sync-coverage.sh:maskable:sh2perl/proofs/verus/maskable_sync.txt"
  "harness/verus-sync-coverage.sh:lifetime:sh2perl/proofs/verus/lifetime_sync.txt"
  "harness/verus-sync-coverage.sh:numstr:sh2perl/proofs/verus/numstr_sync.txt"
  "harness/verus-sync-coverage.sh:numeric_observed:sh2perl/proofs/verus/numeric_observed_sync.txt"
  "harness/verus-sync-coverage.sh:str_splice_fold:sh2perl/proofs/verus/str_splice_fold_sync.txt"
  "harness/verus-sync-coverage.sh:str_chop_cursor:sh2perl/proofs/verus/str_chop_cursor_sync.txt"
  "harness/verus-sync-coverage.sh:hoist_loop_invariants:sh2perl/proofs/verus/hoist_loop_invariants_sync.txt"
  # (direct_calls / cat_read / grep_o have no sync baseline: their
  # sources are suites-less, and a baseline without an executed pin
  # would be green-by-absence. Their model pins are recorded UNMIRRORED
  # in VERUS.md §(b).4. Re-add the three entries when a unit suite lands.)
  "harness/verus-sync-coverage.sh:exec_call_fold:sh2perl/proofs/verus/exec_call_fold_sync.txt"
  "harness/verus-sync-coverage.sh:interp_lit_merge:sh2perl/proofs/verus/interp_lit_merge_sync.txt"
  "harness/verus-sync-coverage.sh:strip:sh2perl/proofs/verus/strip_sync.txt"
  "harness/verus-sync-coverage.sh:counted_arith_forinit:sh2perl/proofs/verus/counted_arith_forinit_sync.txt"
  "harness/verus-sync-coverage.sh:isolate_accumulate:sh2perl/proofs/verus/isolate_accumulate_sync.txt"
  "harness/verus-sync-coverage.sh:lane_private:sh2perl/proofs/verus/lane_private_sync.txt"
  "harness/verus-sync-coverage.sh:analysis:sh2perl/proofs/verus/analysis_sync.txt"
  "harness/verus-sync-coverage.sh:loop_opt:sh2perl/proofs/verus/loop_opt_sync.txt"
  "harness/verus-sync-coverage.sh:restructure:sh2perl/proofs/verus/restructure_sync.txt"
  "harness/verus-sync-coverage.sh:optimize:sh2perl/proofs/verus/optimize_sync.txt"
  # verus-sync.sh: the ONLY legacy (2-field) entry — it REGENERATES a synced
  # region from src/ and diffs against the committed copy, instead of pinning
  # guards. History worth keeping: it was written 2026-10-24, left unregistered
  # ("nothing to sync"), and its target (`arith_bounds` + `within_i32` +
  # I32_MIN/I32_MAX) was then DELETED from `transforms/i32_provable.rs` with
  # nobody noticing. RETARGETED 2026-11-08 at the live estimator —
  # `arith_abs_bound` / `arith_is_i32` plus their two hoisted bound consts — and
  # `proofs/verus/i32_bounds_sync.rs` is now committed, so the entry is green.
  # It emits a TRANSCRIPT (two mechanical rewrites; `?`, the `cap` closure and
  # `checked_*` verbatim), which is enough to catch the source moving under the
  # model, and check_sync compares the region rather than the sha line.
  "harness/verus-sync.sh:sh2perl/proofs/verus/i32_bounds_sync.rs"
  # c_decl_coverage: the FIRST TRANSCRIPTION model in this list — its
  # checker does not just pin guards, it EXTRACTS the modelled walker
  # arm chains (patterns + guards + callee sets) from c_backend.rs and
  # diffs them (harness/declcov-extract.py), closing §22's honest
  # proviso about unbridged transcriptions.
  "harness/verus-sync-coverage.sh:c_decl_coverage:sh2perl/proofs/verus/c_decl_coverage_sync.txt"
)

if [ "${1:-}" = "--list" ]; then
  echo "models:"; printf '  %s\n' "${MODELS[@]}"
  echo "syncs:"; printf '  %s\n' "${SYNCS[@]}"
  exit 0
fi
if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,/^$/p' "$0" | grep '^#' | sed 's/^# //;s/^#//'
  exit 0
fi

if [ ! -x "$VERUS_BIN" ]; then
  echo "verus-gate: no Verus binary at $VERUS_BIN (set VERUS_BIN) — nothing verified" >&2
  exit 2
fi
# Capture-then-match: a streamed `verus --version | grep -q` races SIGPIPE
# under load (grep exits at first match, verus dies writing the rest,
# pipefail turns that into a false negative).
verus_version=$("$VERUS_BIN" --version 2>&1 || true)
if [[ "$verus_version" != *"$PIN"* ]]; then
  echo "verus-gate: WARNING: binary is not the pinned $PIN — counts were measured with the pin" >&2
fi

pass=0; fail=0; skip=0; retired=0
check_model() { # $1=entry [$2=retired]
  # NOTE: one `local` per line — a single `local a=.. b=$a` expands every
  # word before binding anything, which trips `set -u` (bash 5.2).
  local entry="$1"
  local mode="${2:-active}"
  local filespec="${entry%%:*}"
  local rest="${entry#*:}"
  local expect="${rest%%:*}"
  local rl="${rest##*:}"
  local -a files=()
  local f
  IFS='+' read -ra parts <<< "$filespec"
  for f in "${parts[@]}"; do files+=("$PV/$f"); done
  local label="${filespec//+/, }"
  # Existence pre-check: without it a missing model is handed to Verus,
  # which reports `? verified, ? errors rc=1` — indistinguishable from a
  # real proof failure in a log skim. That is how two dozen models could
  # vanish from the tree unnoticed (the 2026-11 re-pin found three gone).
  local missing=""
  for f in "${files[@]}"; do
    [ -f "$f" ] || missing="${missing:+$missing, }$f"
  done
  if [ -n "$missing" ]; then
    echo "FAIL  $label — model file absent ($missing) — entry is not verifiable in this checkout" >&2
    fail=$((fail+1))
    return 0
  fi
  local out rc n e
  out=$(timeout "$TIMEOUT" "$VERUS_BIN" --triggers-mode silent --rlimit "$rl" "${files[@]}" 2>&1) || rc=$?
  rc=${rc:-0}
  n=$(printf '%s\n' "$out" | grep -Eo '^verification results:: [0-9]+ verified' | grep -Eo '[0-9]+' | tail -1 || true)
  e=$(printf '%s\n' "$out" | grep -Eo '^verification results:: [0-9]+ verified, [0-9]+ errors?' | grep -Eo '[0-9]+ errors?' | grep -Eo '^[0-9]+' || true)
  if [ "$rc" -eq 0 ] && [ "${n:-}" = "$expect" ] && [ "${e:-}" = "0" ]; then
    if [ "$mode" = retired ]; then
      echo "RETIRED  $label — $n verified, 0 errors (retired record, NOT Tier 1; not counted)"
      retired=$((retired+1))
    else
      echo "OK    $label — $n verified, 0 errors (expected $expect)"
      pass=$((pass+1))
    fi
  else
    echo "FAIL  $label — got '${n:-?} verified, ${e:-?} errors' rc=$rc (expected $expect verified, 0 errors)" >&2
    printf '%s\n' "$out" | tail -15 >&2
    fail=$((fail+1))
  fi
}

check_sync() { # $1=extractor $2=baseline(rel to root)
  local gen="$root/$1" base="$root/$2"
  local name="${1##*/}"
  [ -x "$gen" ] || { echo "SKIP  $name — generator not executable"; skip=$((skip+1)); return 0; }
  # Run the generator BEFORE consulting the baseline. The old order SKIPped on
  # a missing baseline without ever invoking the extractor, so a broken
  # extractor and an absent baseline were indistinguishable from "Tier 1
  # pending" — the state `verus-sync.sh` sat in for weeks while its target
  # function was deleted from the source. Now:
  #   generator errors                         -> FAIL (drift in the source)
  #   generator is clean but no baseline file  -> FAIL (nothing is compared, so
  #                                               the region is unchecked by
  #                                               construction; commit it or
  #                                               delete the entry on purpose)
  local tmp; tmp=$(mktemp)
  local rc=0
  OUT_TMP="$tmp" "$gen" >/dev/null 2>"$tmp.err" || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL  $name — generator errored (source outgrew the extractor?)" >&2
    tail -8 "$tmp.err" >&2; rm -f "$tmp" "$tmp.err"
    fail=$((fail+1)); return 0
  fi
  if [ ! -f "$base" ]; then
    echo "FAIL  $name — no baseline at $2: the extractor regenerates cleanly but its output was never committed, so drift from src/ is unchecked (commit the generated region, or delete this entry deliberately)" >&2
    echo "      generated $(wc -l < "$tmp") line(s); first facts:" >&2
    head -5 "$tmp" >&2
    rm -f "$tmp" "$tmp.err"
    fail=$((fail+1)); return 0
  fi
  # The provenance line carries the source's whole-file sha, so it moves on any
  # edit including a comment or a test. Compare the REGION it precedes, exactly
  # as check_sync_cov does: a fact change still fails loudly, a comment-only
  # edit does not.
  local filt='^// GENERATED from .* @ '
  if diff <(command grep -v "$filt" "$base") <(command grep -v "$filt" "$tmp") >/dev/null 2>&1; then
    echo "OK    $name — baseline reproduces the live source"
    pass=$((pass+1))
  else
    echo "FAIL  $name — baseline drifted from the live source:" >&2
    diff <(command grep -v "$filt" "$base") <(command grep -v "$filt" "$tmp") 2>&1 | head -20 >&2
    fail=$((fail+1))
  fi
  rm -f "$tmp" "$tmp.err"
}

check_sync_cov() { # $1=script $2=model $3=baseline(rel to root)
  local gen="$root/$1" model="$2" base="$root/$3"
  local name="verus-sync-coverage.sh:$model"
  [ -x "$gen" ] || { echo "SKIP  $name — generator not executable"; skip=$((skip+1)); return 0; }
  local tmp; tmp=$(mktemp)
  local rc=0
  # Strip the volatile sha header (source/proof revisions are tracked by
  # git, not by the manifest) before diffing: only pin/guard/count facts
  # must reproduce. A fact change still fails loudly.
  OUT_TMP="$tmp" "$gen" "$model" >/dev/null 2>"$tmp.err" || rc=$?
  # A model whose source file is not a module of the crate cannot execute any
  # pin — that is a stated gap, not a drifted fact, so it is counted as a SKIP
  # with its reason on the line, the same way an absent baseline is. It must
  # never read as green: the summary keeps SKIPs separate from passes.
  if [ "$rc" -ne 0 ] && command grep -q "is not a module of the crate" "$tmp.err"; then
    echo "SKIP  $name — source module not wired into the crate (model cannot execute):"
    sed -n 's/.*FATAL: //p' "$tmp.err" | head -1
    skip=$((skip+1)); rm -f "$tmp" "$tmp.err"; return 0
  fi
  if [ "$rc" -ne 0 ]; then
    echo "FAIL  $name — generator errored (source outgrew the checker?)" >&2
    tail -8 "$tmp.err" >&2; rm -f "$tmp" "$tmp.err"
    fail=$((fail+1)); return 0
  fi
  # The baseline is consulted only AFTER the generator has run: skipping on a
  # missing file first made a dead extractor and an unwritten baseline
  # indistinguishable, and hid the three unwired models below behind "baseline
  # absent" long after the cause was nameable.
  if [ ! -f "$base" ]; then
    echo "SKIP  $name — generator clean but $3 absent (Tier 1 pending, NOT green-by-absence)"
    skip=$((skip+1)); rm -f "$tmp" "$tmp.err"; return 0
  fi
  if diff <(command grep -v "^# source sha:" "$base") <(command grep -v "^# source sha:" "$tmp") >/dev/null 2>&1; then
    echo "OK    $name — pin/guard facts reproduce the live source"
    pass=$((pass+1))
  else
    echo "FAIL  $name — correspondence drifted from the live source:" >&2
    diff <(command grep -v "^# source sha:" "$base") <(command grep -v "^# source sha:" "$tmp") 2>&1 | head -20 >&2
    fail=$((fail+1))
  fi
  rm -f "$tmp" "$tmp.err"
}

echo "== verus-gate: models =="
for m in "${MODELS[@]}"; do check_model "$m"; done
echo "== verus-gate: retired records (verified, never counted) =="
for m in "${RETIRED_MODELS[@]}"; do check_model "$m" retired; done
echo "== verus-gate: sync =="
if [ "${#SYNCS[@]}" -eq 0 ]; then
  echo "(no sync extractors registered)"
fi
for s in "${SYNCS[@]}"; do
  # three-field entries (script:model:baseline) go to the coverage driver;
  # two-field entries (script:baseline) to the legacy regenerating driver.
  rest="${s#*:}"
  if [[ "$rest" == *:* ]]; then
    check_sync_cov "${s%%:*}" "${rest%%:*}" "${rest##*:}"
  else
    check_sync "${s%%:*}" "$rest"
  fi
done
echo "verus-gate: $pass passed, $fail failed, $skip skipped, $retired retired-record checks (excluded from the pass count)"
[ "$fail" -eq 0 ]
