#!/usr/bin/env bash
# verus-sync-coverage.sh — correspondence check for the P3/P4/P5 Verus models.
#
#   ./harness/verus-sync-coverage.sh <model>   # emit manifest to stdout (or $OUT_TMP)
#
# The P3/P4/P5 models are deliberate reductions (shrunken calculi), not
# transcriptions — no mechanical extractor can regenerate them. So "sync"
# here means CORRESPONDENCE: the generator re-derives, from the live
# source AND the live proof file, the exact facts the proof's fidelity
# section claims, and emits them as a canonical manifest. The gate diffs
# the manifest against the committed baseline
# (sh2perl/proofs/verus/<model>_sync.txt): any source change that moves
# a covered fact (renamed guard, new arm, dropped pin, renamed test)
# changes the manifest and fails loudly until the proof author re-blesses.
#
# Three correspondence classes per model:
#   pins:   every `proof fn pin_*` in the model maps to a source test via
#           the committed pin_map below (the living tie VERUS.md §(b).4
#           audits). A pin without a map entry, or an entry pointing at
#           a test that no longer exists, is drift. UNMIRRORED marks pins
#           with no source test by design (analysis-only, no unit suite).
#   guards: the source predicates the model claims to mirror still exist
#           with the same shape (exact-match lines). A guard edit is the
#           precise "model no longer matches the code" event.
#   counts: the model's obligation count (proof-fn total) — the gate
#           already asserts this via Verus, but recording it here ties
#           the manifest to the proof file revision.
#
# Exit: 0 manifest emitted; 1 a fact cannot be extracted (source outgrew
# the checker — extend the patterns, do not hand-edit the baseline).
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL="${1:-}"
OUT="${OUT_TMP:-/dev/stdout}"

fail() { echo "verus-sync-coverage($MODEL): FATAL: $*" >&2; exit 1; }

[ -n "$MODEL" ] || fail "usage: $0 <model>   # model: copy_propagation|function_purity|test_lowering|string_folds|arith_folds|test_folds|capture_folds|list_folds|textop_folds|not_folds|const_cmp_folds|elim_trio|slice_identity|case_lowering|elseif_flatten|seq_range|ternary_desugar|escape_classes|f32_narrow|append_store|split_set|echo_return|arith_forms|counted_while_forinit|scc|used_before_decl|maskable|lifetime|numstr|numeric_observed"
# A model may span several source files (the P6 sweep groups folds by
# family). model_srcs lists them; SRC is the first (legacy single-file
# uses keep working).
model_srcs() {
  case "$1" in
    copy_propagation|function_purity|test_lowering) echo "$1" ;;
    string_folds) echo "interp_fold default_empty_fold" ;;
    arith_folds) echo "arith_normalize bc_float_clean" ;;
    test_folds) echo "test_simplification" ;;
    capture_folds) echo "const_capture_fold text_capture_fold" ;;
    list_folds) echo "brace_fold affix_strip_fold" ;;
    textop_folds) echo "text_ops" ;;
    not_folds) echo "not_identity" ;;
    const_cmp_folds) echo "const_str_cmp_fold" ;;
    elim_trio) echo "const_condition_elim unreachable_after_exit merge_init_assignments" ;;
    slice_identity) echo "slice_identity" ;;
    case_lowering) echo "case_lowering" ;;
    elseif_flatten) echo "else_if_flatten" ;;
    seq_range) echo "seq_range_for" ;;
    ternary_desugar) echo "ternary_desugar" ;;
    escape_classes) echo "escape_classes" ;;
    f32_narrow) echo "f32_narrow" ;;
    append_store) echo "append_to_store" ;;
    split_set) echo "split_set" ;;
    echo_return) echo "echo_return" ;;
    arith_forms) echo "arith_forms" ;;
    counted_while_forinit) echo "counted_while_forinit" ;;
    scc) echo "scc" ;;
    used_before_decl) echo "used_before_decl" ;;
    maskable) echo "maskable" ;;
    lifetime) echo "lifetime" ;;
    numstr) echo "numstr" ;;
    numeric_observed) echo "numeric_observed" ;;
    *) fail "unknown model: $1" ;;
  esac
}
SRCS="$(model_srcs "$MODEL")"
# Source directory per model (most live in transforms/; the verdict
# analyses live in shir_passes/).
model_dir() {
  case "$1" in
    scc|used_before_decl|maskable|lifetime|numstr|numeric_observed) echo "shir_passes" ;;
    *) echo "transforms" ;;
  esac
}
SRCDIR="$(model_dir "$MODEL")"
SRC="$root/sh2perl/src/$SRCDIR/$(echo "$SRCS" | awk '{print $1}').rs"
PRF="$root/sh2perl/proofs/verus/$MODEL.rs"
[ -f "$SRC" ] || fail "no source: $SRC"
[ -f "$PRF" ] || fail "no proof: $PRF"

# sgrep: grep across ALL of the model's source files.
sgrep() { # sgrep <grep-args...>
  local f
  for f in $SRCS; do
    command grep "$@" "$root/sh2perl/src/$SRCDIR/$f.rs" && return 0
  done
  return 1
}

# pins: model `proof fn pin_X` -> source test, via the committed map
# below. The map IS the living tie — a pin without an entry, or an entry
# pointing at a test that no longer exists, is drift and fails loudly.
# UNMIRRORED marks pins with no source test by design (function_purity:
# analysis-only, no unit suite — see VERUS.md §(b).4); an UNMIRRORED pin
# that GAINS a same-topic test stays UNMIRRORED until a proof author
# promotes the mapping (conservative: never auto-claim).
pin_map() { # $1=model $2=pin -> file:test, UNMIRRORED, or empty
  case "$1:$2" in
    copy_propagation:pin_fold_after_def) echo copy_propagation:folds_read_after_def ;;
    copy_propagation:pin_refuse_before_def) echo copy_propagation:refuses_read_before_def ;;
    copy_propagation:pin_refuse_multi_def) echo copy_propagation:refuses_multi_def ;;
    copy_propagation:pin_copy_def_not_folded) echo copy_propagation:folds_copy_rhs ;;
    copy_propagation:pin_other_opaque) echo copy_propagation:refuses_background_read ;;
    copy_propagation:pin_fold_both_reads) echo copy_propagation:folds_both_reads_in_one_stmt ;;
    function_purity:pin_*) echo UNMIRRORED ;;
    test_lowering:pin_nonempty_var) echo test_lowering:nonempty_tests_lower_to_string_ne ;;
    test_lowering:pin_nonempty_empty) echo test_lowering:nonempty_tests_lower_to_string_ne ;;
    test_lowering:pin_zero_negation) echo test_lowering:nonempty_tests_lower_to_string_ne ;;
    test_lowering:pin_string_eq_not_ne) echo test_lowering:string_eq_tests_lower_to_string_ne ;;
    test_lowering:pin_string_eq_true) echo test_lowering:string_eq_tests_lower_to_string_ne ;;
    test_lowering:pin_string_ne_direct) echo test_lowering:string_eq_tests_lower_to_string_ne ;;
    test_lowering:pin_numeric_ge) echo test_lowering:numeric_compare_tests_lower_to_binop ;;
    test_lowering:pin_affix_shapes) echo test_lowering:glob_affix_tests_lower_to_primitives ;;
    test_lowering:pin_affix_neg) echo test_lowering:negated_affix_not_carries_primitive_on_both_sides ;;
    string_folds:pin_single_literal_folds) echo interp_fold:single_literal_interpolate_folds_to_str ;;
    string_folds:pin_single_expr_refuses) echo interp_fold:single_expr_interpolate_is_refused ;;
    string_folds:pin_multi_part_stays) echo interp_fold:multi_part_interpolate_is_left_alone ;;
    string_folds:pin_fold_invisible_at_runtime) echo interp_fold:single_literal_interpolate_folds_to_str ;;
    string_folds:pin_gates_open_folds) echo default_empty_fold:empty_default_folds_to_plain_read ;;
    string_folds:pin_gates_refuse) echo default_empty_fold:array_homed_names_refuse ;;
    string_folds:pin_default_invisible_at_runtime) echo default_empty_fold:empty_default_folds_to_plain_read ;;
    arith_folds:pin_zero_minus_negates) echo UNMIRRORED ;;
    arith_folds:pin_zero_add_identity) echo UNMIRRORED ;;
    arith_folds:pin_one_mul_identity) echo UNMIRRORED ;;
    arith_folds:pin_zero_mul_div_refuse) echo UNMIRRORED ;;
    arith_folds:pin_nonzero_no_fold) echo UNMIRRORED ;;
    arith_folds:pin_norm_invisible_at_runtime) echo UNMIRRORED ;;
    arith_folds:pin_bc_strip_identity) echo UNMIRRORED ;;
    test_folds:pin_true_ops) echo UNMIRRORED ;;
    test_folds:pin_false_ops) echo UNMIRRORED ;;
    test_folds:pin_lt_false_at_runtime) echo UNMIRRORED ;;
    test_folds:pin_streq_true_at_runtime) echo UNMIRRORED ;;
    capture_folds:pin_echo_newline_stripped) echo const_capture_fold:frontend_constant_echo_capture_folds ;;
    capture_folds:pin_echo_joins_space) echo const_capture_fold:multi_word_echo_joins_with_a_space ;;
    capture_folds:pin_true_empty) echo const_capture_fold:folds_true_to_empty ;;
    capture_folds:pin_or_chain_reachable) echo const_capture_fold:or_chain_folds_to_reachable_arm ;;
    capture_folds:pin_and_chain_status_refuses) echo const_capture_fold:chain_status_loss_refuses ;;
    capture_folds:pin_unknown_refuses) echo const_capture_fold:other_command_refuses ;;
    list_folds:pin_brace_two_words) echo brace_fold:echo_arg_fans_out ;;
    list_folds:pin_brace_empty_group) echo brace_fold:empty_expansion_is_refused ;;
    list_folds:pin_splice_keeps_neighbours) echo brace_fold:array_literal_expands_elements ;;
    list_folds:pin_prefix_strips) echo affix_strip_fold:literal_prefix_strip_folds_on_rust ;;
    list_folds:pin_prefix_no_match_keeps) echo affix_strip_fold:glob_magic_pattern_is_kept ;;
    list_folds:pin_suffix_strips) echo affix_strip_fold:literal_suffix_strip_folds_on_java ;;
    textop_folds:pin_strlen_literal) echo text_ops:wc_c_is_strlen ;;
    textop_folds:pin_case_upper) echo text_ops:param_case_upper ;;
    textop_folds:pin_case_lower) echo text_ops:param_case_lower ;;
    textop_folds:pin_substr_slice) echo UNMIRRORED ;;
    textop_folds:pin_basename_trailing_slash) echo UNMIRRORED ;;
    textop_folds:pin_basename_interior_slashes) echo UNMIRRORED ;;
    not_folds:pin_double_not_folds) echo not_identity:folds_double_not ;;
    not_folds:pin_single_not_untouched) echo not_identity:single_not_is_untouched ;;
    not_folds:pin_inconsistent_inner_refuses) echo not_identity:unbalanced_inner_not_is_refused ;;
    not_folds:pin_inconsistent_outer_refuses) echo UNMIRRORED ;;
    not_folds:pin_flip_ne_to_eq) echo not_identity:flips_negated_comparison ;;
    not_folds:pin_flip_lt_to_ge) echo not_identity:flips_ordering_comparisons ;;
    not_folds:pin_flip_invisible_at_runtime) echo not_identity:flips_negated_comparison ;;
    not_folds:pin_fold_invisible_at_runtime) echo not_identity:folds_double_not ;;
    const_cmp_folds:pin_equal_literals) echo const_str_cmp_fold:folds_equal_literals ;;
    const_cmp_folds:pin_ne_literals) echo const_str_cmp_fold:folds_equal_literals ;;
    const_cmp_folds:pin_int_literals) echo const_str_cmp_fold:folds_int_literals ;;
    const_cmp_folds:pin_glob_rhs_refuses) echo const_str_cmp_fold:refuses_glob_rhs ;;
    const_cmp_folds:pin_command_style_refuses) echo const_str_cmp_fold:refuses_command_style ;;
    const_cmp_folds:pin_mixed_refuses) echo const_str_cmp_fold:refuses_dynamic_and_mixed_operands ;;
    const_cmp_folds:pin_dynamic_refuses) echo const_str_cmp_fold:refuses_dynamic_and_mixed_operands ;;
    const_cmp_folds:pin_wrapped_exact) echo const_str_cmp_fold:folds_wrapped_exact_cond ;;
    const_cmp_folds:pin_globmatch_literal) echo const_str_cmp_fold:folds_globmatch_with_literal_pattern ;;
    elim_trio:pin_cce_true_branch) echo UNMIRRORED ;;
    elim_trio:pin_cce_false_branch) echo UNMIRRORED ;;
    elim_trio:pin_cce_while_false_drops) echo UNMIRRORED ;;
    elim_trio:pin_cce_dowhile_once) echo UNMIRRORED ;;
    elim_trio:pin_uae_truncates) echo UNMIRRORED ;;
    elim_trio:pin_uae_keeps_clean) echo UNMIRRORED ;;
    elim_trio:pin_mia_merges) echo UNMIRRORED ;;
    elim_trio:pin_mia_pair_agrees) echo UNMIRRORED ;;
    slice_identity:pin_zero_offset_empty_length_folds) echo slice_identity:zero_offset_empty_length_folds_to_plain_read ;;
    slice_identity:pin_empty_offset_folds) echo slice_identity:empty_offset_means_zero_and_folds ;;
    slice_identity:pin_absent_length_folds) echo slice_identity:length_absent_to_end_folds_at_zero ;;
    slice_identity:pin_real_offset_kept) echo slice_identity:real_offset_is_kept ;;
    slice_identity:pin_real_length_kept) echo slice_identity:real_length_is_kept ;;
    slice_identity:pin_non_ident_kept) echo slice_identity:array_and_positional_names_are_kept ;;
    slice_identity:pin_plain_read_untouched) echo slice_identity:transform_reports_false_when_nothing_matches ;;
    slice_identity:pin_fold_invisible_at_runtime) echo slice_identity:zero_offset_empty_length_folds_to_plain_read ;;
    case_lowering:pin_pure_subject_lowers_unbound) echo case_lowering:optimizer_getvar_subject_lowers ;;
    case_lowering:pin_reserved_subject_binds) echo case_lowering:getvar_reserved_name_binds_once ;;
    case_lowering:pin_literal_affix_dispatch) echo case_lowering:literal_and_affix_clauses_lower_to_native_tests ;;
    case_lowering:pin_quoted_star_is_literal) echo case_lowering:quoted_star_is_a_literal_not_the_catchall ;;
    case_lowering:pin_glob_refuses_without_target) echo case_lowering:glob_class_refuses_whole_case ;;
    case_lowering:pin_glob_lowers_with_target) echo case_lowering:glob_clause_lowers_via_globmatch_on_accepting_target ;;
    case_lowering:pin_refused_pattern_refuses) echo case_lowering:dynamic_and_partial_quote_patterns_refuse ;;
    case_lowering:pin_impure_binds_once) echo case_lowering:impure_discriminant_binds_once ;;
    case_lowering:pin_arith_subject_binds) echo case_lowering:arith_subject_binds_text_form ;;
    case_lowering:pin_leading_catchall_refuses) echo case_lowering:leading_catchall_refuses ;;
    case_lowering:pin_alternations_or) echo case_lowering:alternations_split_into_ored_conditions ;;
    case_lowering:pin_nocasematch_refuses) echo case_lowering:nocasematch_mention_refuses_the_whole_program ;;
    case_lowering:pin_volatile_positional_binds) echo case_lowering:quoted_positional_subject_lowers_volatile_binds ;;
    case_lowering:pin_post_catchall_dropped) echo UNMIRRORED ;;
    elseif_flatten:pin_else_if_becomes_elsif) echo else_if_flatten:else_if_becomes_an_elsif ;;
    elseif_flatten:pin_chain_flattens_fully) echo else_if_flatten:a_bare_nested_if_chain_flattens_fully ;;
    elseif_flatten:pin_extra_statements_keep_nesting) echo else_if_flatten:an_else_with_extra_statements_keeps_its_nesting ;;
    elseif_flatten:pin_selection_preserved) echo else_if_flatten:else_if_becomes_an_elsif ;;
    seq_range:pin_two_arg_lifts) echo seq_range_for:two_arg_seq_lifts_to_range ;;
    seq_range:pin_one_arg_starts_at_one) echo seq_range_for:one_arg_seq_starts_at_one ;;
    seq_range:pin_descending_is_empty) echo seq_range_for:descending_seq_is_an_empty_range ;;
    seq_range:pin_step_keeps_runtime) echo seq_range_for:step_three_arg_seq_keeps_runtime_path ;;
    seq_range:pin_nonliteral_keeps_runtime) echo seq_range_for:float_and_leading_zero_args_keep_runtime_path ;;
    seq_range:pin_body_write_disqualifies) echo seq_range_for:body_write_disqualifies ;;
    seq_range:pin_setvar_write_disqualifies) echo seq_range_for:setvar_write_disqualifies ;;
    seq_range:pin_huge_span_disqualifies) echo seq_range_for:huge_range_disqualifies ;;
    ternary_desugar:pin_teststr_becomes_test) echo UNMIRRORED ;;
    ternary_desugar:pin_arithstr_becomes_arith) echo UNMIRRORED ;;
    ternary_desugar:pin_calls_pass_through) echo UNMIRRORED ;;
    ternary_desugar:pin_testarith_normalizes) echo UNMIRRORED ;;
    ternary_desugar:pin_other_refuses) echo UNMIRRORED ;;
    ternary_desugar:pin_branch_preserved) echo UNMIRRORED ;;
    # P12 — the two verdict analyses are ANALYSIS-ONLY (no unit suite in
    # either source), so every pin is UNMIRRORED by design; the living
    # tie is the guarded consumer/table below, not a mapped test.
    escape_classes:pin_*) echo UNMIRRORED ;;
    escape_classes:pin_local_accepted_without_store_ok) echo UNMIRRORED ;;
    escape_classes:pin_acc_ok_matches_consumer) echo UNMIRRORED ;;
    f32_narrow:pin_*) echo UNMIRRORED ;;
    f32_narrow:pin_mod_refused) echo UNMIRRORED ;;
    f32_narrow:pin_general_mul_not_form) echo UNMIRRORED ;;
    f32_narrow:pin_mul_one_form) echo UNMIRRORED ;;
    f32_narrow:pin_lit_pair_contract) echo UNMIRRORED ;;
    f32_narrow:pin_var_lattice) echo UNMIRRORED ;;
    f32_narrow:pin_unknown_not_exact) echo UNMIRRORED ;;
    f32_narrow:pin_int_operand_uses_roundtrip) echo UNMIRRORED ;;
    # Store-forward sweep: per-rewrite models over the transform's own
    # unit suite (mapped pins) plus model-internal runtime checks
    # (UNMIRRORED pins that execute the model, not the source).
    append_store:pin_counted_loop_rewrites) echo append_to_store:append_in_counted_loop_becomes_store ;;
    append_store:pin_all_guards_pass) echo append_to_store:append_in_counted_loop_becomes_store ;;
    append_store:pin_unknown_bound_refuses) echo append_to_store:append_with_unknown_bound_keeps_growable ;;
    append_store:pin_two_appends_refused) echo append_to_store:two_appends_veto ;;
    append_store:pin_nonempty_init_refused) echo append_to_store:nonempty_init_vetoes ;;
    append_store:pin_other_write_refused) echo append_to_store:other_write_vetoes ;;
    append_store:pin_break_refused) echo append_to_store:break_vetoes ;;
    append_store:pin_step2_refused) echo append_to_store:step2_vetoes ;;
    append_store:pin_multi_element_refused) echo UNMIRRORED ;;
    append_store:pin_rewritten_loop_agrees) echo UNMIRRORED ;;
    split_set:pin_routing_splits) echo split_set:splits_set_into_two_partitions ;;
    split_set:pin_iteration_out_of_scope) echo split_set:refuses_iterated_set ;;
    split_set:pin_nonempty_init_refused) echo split_set:refuses_nonempty_init ;;
    split_set:pin_gate_is_placement) echo split_set:disabled_by_default ;;
    split_set:pin_dedup_within_partition) echo split_set:splits_set_into_two_partitions ;;
    split_set:pin_runs_agree_on_membership) echo UNMIRRORED ;;
    echo_return:pin_single_echo_lifts) echo echo_return:simple_value_function_lifts ;;
    echo_return:pin_both_arms_return) echo echo_return:if_arms_lift ;;
    echo_return:pin_impure_refused) echo echo_return:impure_body_refuses ;;
    echo_return:pin_no_echo_refuses) echo echo_return:no_echo_path_refuses ;;
    echo_return:pin_multi_echo_refuses) echo echo_return:multi_echo_refuses ;;
    echo_return:pin_last_stage_echoes) echo echo_return:pipeline_last_stage_echoes_the_value ;;
    echo_return:pin_wrapped_prints_value) echo echo_return:simple_value_function_lifts ;;
    echo_return:pin_bare_is_not_echo) echo UNMIRRORED ;;
    # Arith-lowering sweep: per-rewrite models over the transform's own
    # unit suite (mapped pins) plus model-internal runtime checks.
    arith_forms:pin_plain_assign) echo arith_forms:let_simple_assign_becomes_structured_assign ;;
    arith_forms:pin_plus_equals) echo arith_forms:let_compound_assign_plus_equals ;;
    arith_forms:pin_postfix_inc) echo arith_forms:let_incdec_becomes_incdec_arith ;;
    arith_forms:pin_prefix_inc) echo arith_forms:let_prefix_incdec ;;
    arith_forms:pin_multi_arg) echo arith_forms:let_multiple_forms_emit_multiple_assigns ;;
    arith_forms:pin_var_rhs) echo arith_forms:let_arith_with_var_rhs ;;
    arith_forms:pin_non_let_untouched) echo arith_forms:non_let_exec_is_left_alone ;;
    arith_forms:pin_nested_rewrite) echo arith_forms:let_in_nested_block_rewrites_recursively ;;
    arith_forms:pin_non_arith_refuses) echo arith_forms:let_with_non_arith_arg_is_left_alone ;;
    arith_forms:pin_paren_compound) echo arith_forms:double_paren_compound_assign_is_not_glob_tagged ;;
    arith_forms:pin_paren_incdec) echo arith_forms:double_paren_incdec_is_lowered ;;
    arith_forms:pin_comma_list) echo arith_forms:double_paren_comma_list_lowered ;;
    counted_while_forinit:pin_arith_step_folds) echo counted_while_forinit:arith_wrapped_step_folds ;;
    counted_while_forinit:pin_binop_step_folds) echo counted_while_forinit:binop_step_still_folds ;;
    counted_while_forinit:pin_zero_step_refuses) echo counted_while_forinit:zero_arith_step_refuses ;;
    counted_while_forinit:pin_dynamic_step_refuses) echo counted_while_forinit:dynamic_arith_step_refuses ;;
    counted_while_forinit:pin_body_write_refuses) echo counted_while_forinit:body_write_refuses ;;
    counted_while_forinit:pin_plain_while_untouched) echo counted_while_forinit:plain_while_is_untouched ;;
    counted_while_forinit:pin_declare_refuses) echo counted_while_forinit:declare_in_body_refuses ;;
    counted_while_forinit:pin_trace_agrees) echo UNMIRRORED ;;
    counted_while_forinit:pin_step_gate_load_bearing) echo UNMIRRORED ;;
    # Verdict-analyses sweep: verdict-soundness over oracle censuses.
    scc:pin_mutual_pair) echo scc:mutual_recursion_is_one_scc ;;
    scc:pin_self_loop) echo scc:self_recursion_is_scc_of_one ;;
    scc:pin_leaf_singleton) echo scc:self_recursion_is_scc_of_one ;;
    scc:pin_chain_singletons) echo scc:acyclic_chain_is_singletons ;;
    scc:pin_matcher_triple) echo scc:matcher_cycle_is_one_scc ;;
    scc:pin_capture_edge) echo scc:capture_is_a_call_edge ;;
    scc:pin_parser_cluster) echo scc:test_parser_cluster_is_one_scc ;;
    scc:pin_singleton_leaf) echo UNMIRRORED ;;
    scc:pin_condensation_acyclic) echo UNMIRRORED ;;
    used_before_decl:pin_straight_def_no_warn) echo used_before_decl:defined_before_use_is_clean ;;
    used_before_decl:pin_read_before_def_warns) echo used_before_decl:straight_line_use_before_decl ;;
    used_before_decl:pin_branch_both_arms_no_warn) echo used_before_decl:branch_both_sides_define_is_clean ;;
    used_before_decl:pin_branch_one_arm_warns) echo used_before_decl:branch_meet_suppresses_when_one_side_undefs ;;
    used_before_decl:pin_loop_body_def_no_leak) echo used_before_decl:loop_body_def_does_not_propagate ;;
    used_before_decl:pin_subshell_no_propagate) echo UNMIRRORED ;;
    used_before_decl:pin_function_entry_union) echo used_before_decl:function_capture_of_top_level_is_clean ;;
    used_before_decl:pin_never_defined_warns) echo used_before_decl:function_body_read_of_never_assigned_warns ;;
    used_before_decl:pin_sequential_defs_accumulate) echo used_before_decl:defined_before_use_is_clean ;;
    used_before_decl:pin_if_without_else_falls_through) echo used_before_decl:branch_meet_suppresses_when_one_side_undefs ;;
    maskable:pin_bare_inf) echo maskable:bare_is_inf ;;
    maskable:pin_square_brackets) echo maskable:square_threshold_brackets_i64 ;;
    maskable:pin_linear_math) echo maskable:linear_threshold_math ;;
    maskable:pin_refusals) echo maskable:refuses ;;
    maskable:pin_const_folds) echo maskable:const_dividends ;;
    maskable:pin_pow2_table) echo maskable:pow2_lit ;;
    maskable:pin_bound_sound) echo UNMIRRORED ;;
    lifetime:pin_span_ordering) echo UNMIRRORED ;;
    lifetime:pin_single_access_degenerate) echo lifetime:live_span_covers_def_to_use ;;
    lifetime:pin_span_covers_all) echo lifetime:live_span_covers_def_to_use ;;
    lifetime:pin_escape_store) echo lifetime:array_element_write_escapes ;;
    lifetime:pin_escape_closure) echo lifetime:closure_capture_escapes ;;
    lifetime:pin_escape_return) echo lifetime:return_escapes ;;
    lifetime:pin_no_escape_exec) echo lifetime:exec_args_are_uses_not_escapes ;;
    lifetime:pin_use_needs_liveness) echo lifetime:live_span_covers_def_to_use ;;
    lifetime:pin_retained_needs_escape) echo lifetime:return_escapes ;;
    lifetime:pin_spurious_escape_ok) echo UNMIRRORED ;;
    numstr:pin_int_homed_canonical) echo numstr:noncanonical_literal_disqualifies ;;
    numstr:pin_position_promoted) echo numstr:anchored_cycle_admitted ;;
    numstr:pin_pinned_never_reproposed) echo numstr:pinned_verdicts_survive ;;
    numstr:pin_stringy_assign_demotes) echo numstr:revalidate_params_withdraws_demoted_chain ;;
    numstr:pin_revalidate_removes_only) echo numstr:revalidate_params_withdraws_demoted_chain ;;
    numstr:pin_params_positions) echo numstr:omitted_arg_disqualifies_param ;;
    numeric_observed:pin_scalar_all_numeric) echo numeric_observed:atoll_only_scalar_is_numeric ;;
    numeric_observed:pin_text_use_vetoes) echo numeric_observed:echo_observed_scalar_is_not_numeric ;;
    numeric_observed:pin_empty_uses_marked) echo UNMIRRORED ;;
    numeric_observed:pin_unmarked_no_claim) echo UNMIRRORED ;;
    numeric_observed:pin_array_chain_veto) echo numeric_observed:array_chain_reaches_downstream_scalars ;;
    numeric_observed:pin_param_slot_sound) echo numeric_observed:numeric_sink_param_is_numeric ;;
    *) echo "" ;;
  esac
}
model_pins=$(command grep -o "proof fn \(pin_[A-Za-z0-9_]*\)" "$PRF" | awk '{print $3}' | sort) \
  || fail "cannot list model pins"
[ -n "$model_pins" ] || fail "no pins in model"
src_tests() {
  local f
  for f in $SRCS; do
    command grep -oE "(^|[[:space:]])fn [A-Za-z0-9_]+" "$root/sh2perl/src/$SRCDIR/$f.rs" | awk '{print $NF}' | sed 's/^fn //'
  done | sort -u
}

{
echo "# verus-sync-coverage manifest: $MODEL"
echo -n "# source sha:"
for f in $SRCS; do echo -n " $f=$(sha256sum "$root/sh2perl/src/transforms/$f.rs" | cut -c1-12)"; done
echo "  proof sha: $(sha256sum "$PRF" | cut -c1-12)"
echo
echo "[pins]"
ALL_TESTS="$(src_tests)"
while IFS= read -r pin; do
  entry="$(pin_map "$MODEL" "$pin")"
  if [ -z "$entry" ]; then
    fail "pin $pin has no pin_map entry (add one — even UNMIRRORED needs a conscious entry)"
  elif [ "$entry" = "UNMIRRORED" ]; then
    echo "pin $pin -> UNMIRRORED (by design — see VERUS.md §(b).4)"
  else
    mapped="${entry##*:}"
    if printf '%s\n' "$ALL_TESTS" | command grep -qx "$mapped"; then
      echo "pin $pin -> test $mapped: MAPPED"
    else
      fail "pin $pin maps to $mapped, which no longer exists in source"
    fi
  fi
done <<< "$model_pins"
echo
echo "[guards]"
case "$MODEL" in
  copy_propagation)
    # The def-before-read gate: a read at i folds iff its def index di < i.
    command grep -q "filter(|(_, &di)| di < i)" "$SRC" \
      || fail "def-before-read gate (di < i) not found in source"
    echo "guard def-before-read di<i: PRESENT"
    # Opaque statements (Subshell/Background) are never folded into: the
    # fold_stmt arm returning false (code, not the doc comment).
    command grep -q "IrStmt::Subshell(_) | IrStmt::Background(_) => false" "$SRC" \
      || fail "opaque-statement refusal arm not found in source"
    echo "guard opaque-kind Subshell/Background refusal: PRESENT"
    # Capture refusal: reads inside captures never fold.
    command grep -q "IrExpr::Capture" "$SRC" \
      || fail "Capture handling not found in source"
    echo "guard opaque-kind Capture: PRESENT"
    # Single-def criterion: the collect_defs/count_assigns census.
    command grep -q "fn collect_defs" "$SRC" \
      || fail "collect_defs census not found in source"
    echo "guard single-def census: PRESENT"
    ;;
  function_purity)
    # Lattice order: Impure < Emulable < Pure (deriving PartialOrd/Ord or explicit).
    command grep -q "Impure" "$SRC" && command grep -q "Emulable" "$SRC" && command grep -q "Pure" "$SRC" \
      || fail "Purity lattice variants not found in source"
    echo "guard lattice Impure/Emulable/Pure: PRESENT"
    # Output-of-pure-value is Emulable (the rule the 39/2 mutant guards):
    # the Output arm concluding `Purity::Emulable`.
    command grep -q "Purity::Emulable" "$SRC" \
      || fail "Output-is-Emulable verdict not found in source"
    echo "guard output-is-Emulable: PRESENT"
    # Unknown callee defaults to Impure (the exact default expression).
    command grep -q "unwrap_or(Purity::Impure)" "$SRC" \
      || fail "unknown-callee-Impure default not found in source"
    echo "guard unknown-callee-Impure default: PRESENT"
    # Meet over body: min() fixpoint.
    command grep -q "stmt_purity(s, &v)).min()" "$SRC" \
      || fail "body meet (.min()) not found in source"
    echo "guard body-meet min: PRESENT"
    ;;
  test_lowering)
    # Not(Ne) encoding for == (the rule the 24/1 mutant guards): the
    # DEFINITION plus both call sites (a comment mention is not a rule).
    command grep -q "fn not_wrap(inner: IrExpr) -> IrExpr" "$SRC" \
      || fail "not_wrap definition not found in source"
    echo "guard eq-as-Not(Ne) not_wrap def: PRESENT"
    for site in "not_wrap(ne)" "not_wrap(call)"; do
      command grep -qF "$site" "$SRC" \
        || fail "not_wrap call site $site not found in source"
      echo "guard eq-as-Not(Ne) site $site: PRESENT"
    done
    # Glob-affix primitives: the string literals the rewrite emits.
    for prim in '"strHasPrefix"' '"contains"' '"strHasSuffix"'; do
      command grep -qF -- "($prim," "$SRC" \
        || fail "primitive $prim not emitted in source"
      echo "guard primitive $prim: PRESENT"
    done
    # Numeric ops: all six comparisons (spelled with surrounding spaces
    # in the op-split table).
    for op in '" -eq "' '" -ne "' '" -gt "' '" -ge "' '" -lt "' '" -le "'; do
      command grep -qF -- "$op" "$SRC" \
        || fail "numeric op $op not found in source"
      echo "guard numeric-op $op: PRESENT"
    done
    # Empty/nonempty leaves.
    command grep -q '"-n ' "$SRC" && command grep -q '"-z ' "$SRC" \
      || fail "nonempty flags -n/-z not found in source"
    echo "guard nonempty -n/-z: PRESENT"
    ;;
  string_folds)
    # interp-fold's exact rule: only [Lit(s)] folds to Str.
    sgrep -q "InterpPart::Lit(s)" \
      || fail "interp single-literal rule not found in source"
    echo "guard interp single-lit rule: PRESENT"
    # The assign-head refusal (shape-preservation, not value).
    sgrep -q "prev_was_assign_head" \
      || fail "interp assign-head refusal not found in source"
    echo "guard interp assign-head refusal: PRESENT"
    # default-empty-fold: the op gate and the plain-ident gate.
    sgrep -q 'op != ":-" && op != "-"' \
      || fail "default-empty op gate not found in source"
    echo "guard default-empty op gate: PRESENT"
    sgrep -q "is_plain_ident" \
      || fail "default-empty plain-ident gate not found in source"
    echo "guard default-empty plain-ident gate: PRESENT"
    # The nounset program-wide gate.
    sgrep -q "may_enable_nounset" \
      || fail "default-empty nounset gate not found in source"
    echo "guard default-empty nounset gate: PRESENT"
    # The array-homed per-name gate.
    sgrep -q "ARRAY_HOMED\|array_homed\|collect_array_names" \
      || fail "default-empty array-homed gate not found in source"
    echo "guard default-empty array-homed gate: PRESENT"
    ;;
  arith_folds)
    # arith-normalize's canonical rules: the Num(0)/Num(1) matchers.
    for rule in "ArithAst::Num(0)" "ArithAst::Num(1)"; do
      sgrep -qF "$rule" \
        || fail "arith-normalize rule fragment $rule not found in source"
      echo "guard arith-normalize rule $rule: PRESENT"
    done
    # The negation construction (0 - X -> Un).
    sgrep -q "ArithAst::Un" \
      || fail "arith-normalize negation construction not found in source"
    echo "guard arith-normalize negation: PRESENT"
    # The refusals: 0*X never folds (forces error evaluation).
    sgrep -q "0 \* X\|0 \*\|multiplying by zero" \
      || fail "arith-normalize zero-mul refusal not found in source"
    echo "guard arith-normalize zero-mul refusal: PRESENT"
    # bc-float-clean: the +0.0 suffix gate.
    sgrep -q "+ 0.0\|+0.0" \
      || fail "bc-float-clean +0.0 gate not found in source"
    echo "guard bc-float-clean +0.0 gate: PRESENT"
    # The decimal-point requirement (float-typed remainder).
    sgrep -q "decimal" \
      || fail "bc-float-clean decimal requirement not found in source"
    echo "guard bc-float-clean decimal requirement: PRESENT"
    ;;
  test_folds)
    # The eight-op table: self-comparison folds per operator class.
    for op in '"-eq"\|"-le"\|"-ge"' '"-ne"\|"-lt"\|"-gt"'; do
      sgrep -q "$op" \
        || fail "test-simplification op class $op not found in source"
      echo "guard test-simplification op class: PRESENT"
    done
    # Textual-identity precondition (same token both sides).
    sgrep -q "identical\|same.*token\|X.*X" \
      || fail "test-simplification identity precondition not found in source"
    echo "guard test-simplification identity precondition: PRESENT"
    ;;
  capture_folds)
    # const-capture-fold: single-statement Output rule + trailing-newline strip.
    sgrep -q "strip_all_trailing_newlines\|trailing_newlines" \
      || fail "const-capture newline strip not found in source"
    echo "guard const-capture newline strip: PRESENT"
    # The status-0 chain requirement (echo a && false refuses).
    sgrep -q "chain_ok\|exit status" \
      || fail "const-capture chain-status requirement not found in source"
    echo "guard const-capture chain-status: PRESENT"
    # text-capture-fold: the TEXT_FUNCS gate (test/param/arith only).
    sgrep -q "TEXT_FUNCS" \
      || fail "text-capture TEXT_FUNCS gate not found in source"
    echo "guard text-capture TEXT_FUNCS gate: PRESENT"
    # Quote-safety predicate.
    sgrep -q "safe_repl" \
      || fail "text-capture safe_repl not found in source"
    echo "guard text-capture safe_repl: PRESENT"
    ;;
  list_folds)
    # brace-fold: list-position gate + literal-args requirement.
    sgrep -q "DeclareArray\|list position" \
      || fail "brace-fold list-position gate not found in source"
    echo "guard brace-fold list-position gate: PRESENT"
    # affix-strip-fold: magic-free literal patterns (shortest-identical).
    sgrep -q "is_literal_pattern\|magic-free\|shortest" \
      || fail "affix-strip literal-pattern gate not found in source"
    echo "guard affix-strip literal-pattern gate: PRESENT"
    ;;
  not_folds)
    # The duplication-consistency gate (both Nots must mirror not_wrap's shape).
    sgrep -q "ol.as_ref() != or.as_ref()" \
      || fail "not-identity consistency gate not found in source"
    echo "guard not-identity consistency gate: PRESENT"
    # The six-op flip table (Eq<->Ne, Lt<->Ge, Gt<->Le).
    for pair in "BinOpKind::Eq => Some(BinOpKind::Ne)" "BinOpKind::Lt => Some(BinOpKind::Ge)" "BinOpKind::Gt => Some(BinOpKind::Le)"; do
      sgrep -qF "$pair" \
        || fail "not-identity flip table entry $pair not found in source"
      echo "guard not-identity flip entry: PRESENT"
    done
    # Fold/flip are separate registrations (the Perl Eq/Ne firewall).
    sgrep -q "fn transform_flip" \
      || fail "not-identity-flip separate entry not found in source"
    echo "guard not-identity-flip separate entry: PRESENT"
    # And/Or are never flipped (no De Morgan).
    sgrep -q "_ => None" \
      || fail "not-identity non-comparison refusal not found in source"
    echo "guard not-identity non-comparison refusal: PRESENT"
    ;;
  const_cmp_folds)
    # Plain-quoting gate on both operands.
    sgrep -q "fn plain_style" \
      || fail "const-str-cmp plain-style gate not found in source"
    echo "guard const-str-cmp plain-style gate: PRESENT"
    # Glob-metachar refusal set on the RHS/pattern position.
    sgrep -q "fn has_glob_metachar" \
      || fail "const-str-cmp glob-metachar refusal not found in source"
    echo "guard const-str-cmp glob-metachar refusal: PRESENT"
    # Int/int folds unconditionally.
    sgrep -q "IrExpr::Int(a), IrExpr::Int(b)" \
      || fail "const-str-cmp int/int arm not found in source"
    echo "guard const-str-cmp int/int arm: PRESENT"
    # Mixed Int/Str refuses (coercion lives in the renderer).
    sgrep -q "mixed Int/Str" \
      || fail "const-str-cmp mixed refusal note not found in source"
    echo "guard const-str-cmp mixed refusal: PRESENT"
    # The wrapped exact_cond (Not(Ne) with frozen operands).
    sgrep -q "BinOpKind::Not" \
      || fail "const-str-cmp wrapped-Not arm not found in source"
    echo "guard const-str-cmp wrapped-Not arm: PRESENT"
    # globMatch literal-pattern arm ([value, pattern] order).
    sgrep -q '"globMatch"' \
      || fail "const-str-cmp globMatch arm not found in source"
    echo "guard const-str-cmp globMatch arm: PRESENT"
    # Claimed affix predicates are left alone.
    sgrep -q "strHasPrefix" \
      || fail "const-str-cmp affix leave-alone note not found in source"
    echo "guard const-str-cmp affix leave-alone: PRESENT"
    ;;
  textop_folds)
    # The literal-operand text nodes.
    for node in "StrLen" "CaseTransform" "SubStr" "PathName"; do
      sgrep -q "$node" \
        || fail "text-op node $node not found in source"
      echo "guard text-op node $node: PRESENT"
    done
    ;;
  elim_trio)
    # const-condition-elim: the const evaluator + bare-literal gate.
    sgrep -q "fn eval_cond" \
      || fail "const-condition-elim eval_cond not found in source"
    echo "guard const-condition-elim eval_cond: PRESENT"
    sgrep -q "fn is_bare_literal" \
      || fail "const-condition-elim is_bare_literal not found in source"
    echo "guard const-condition-elim is_bare_literal gate: PRESENT"
    # unreachable-after-exit: direct-Exit trigger + fn-gated Return + dead flag.
    sgrep -q "IrStmt::Exit" \
      || fail "unreachable-after-exit Exit trigger not found in source"
    echo "guard unreachable-after-exit Exit trigger: PRESENT"
    sgrep -q "IrStmt::Return" \
      || fail "unreachable-after-exit Return trigger not found in source"
    echo "guard unreachable-after-exit Return trigger: PRESENT"
    # merge-init-assignments: literal-default + pure-rhs + no-self-read gates.
    sgrep -q "fn is_literal" \
      || fail "merge-init is_literal gate not found in source"
    echo "guard merge-init is_literal gate: PRESENT"
    sgrep -q "fn pure" \
      || fail "merge-init pure gate not found in source"
    echo "guard merge-init pure gate: PRESENT"
    sgrep -q "fn reads_var" \
      || fail "merge-init reads_var gate not found in source"
    echo "guard merge-init reads_var gate: PRESENT"
    ;;
  slice_identity)
    # The exact gate conjunction: param call, 3..=4 args, slice op,
    # plain-ident name, 0/"" offset, ""/absent length.
    sgrep -q 'func != "param"' \
      || fail "slice-identity param-call gate not found in source"
    echo "guard slice-identity param-call gate: PRESENT"
    sgrep -qF '(3..=4).contains(&args.len())' \
      || fail "slice-identity arity gate not found in source"
    echo "guard slice-identity arity gate: PRESENT"
    sgrep -q "fn is_plain_ident" \
      || fail "slice-identity is_plain_ident gate not found in source"
    echo "guard slice-identity is_plain_ident gate: PRESENT"
    sgrep -qF 'off.is_empty() || off == "0"' \
      || fail "slice-identity offset gate not found in source"
    echo "guard slice-identity offset gate: PRESENT"
    sgrep -qF 'IrExpr::Str(l, _) if l.is_empty()' \
      || fail "slice-identity length gate not found in source"
    echo "guard slice-identity length gate: PRESENT"
    ;;
  case_lowering)
    # The lowering entry + classifier + purity + target gates.
    sgrep -q "fn lower_case" \
      || fail "case-lowering lower_case not found in source"
    echo "guard case-lowering lower_case: PRESENT"
    sgrep -q "fn classify_pattern" \
      || fail "case-lowering classify_pattern not found in source"
    echo "guard case-lowering classify_pattern: PRESENT"
    sgrep -q "fn pure_subject" \
      || fail "case-lowering pure_subject not found in source"
    echo "guard case-lowering pure_subject gate: PRESENT"
    sgrep -q "fn glob_target_ok" \
      || fail "case-lowering glob_target_ok not found in source"
    echo "guard case-lowering glob_target_ok gate: PRESENT"
    sgrep -q "fn fresh_subject_name" \
      || fail "case-lowering fresh_subject_name not found in source"
    echo "guard case-lowering fresh_subject_name: PRESENT"
    # Exact via Not(Ne) (the test_lowering encoding, shared).
    sgrep -q "not_wrap(" \
      || fail "case-lowering exact not_wrap encoding not found in source"
    echo "guard case-lowering exact not_wrap encoding: PRESENT"
    # Glob via the shared globMatch predicate, verbatim pattern.
    sgrep -q '"globMatch"' \
      || fail "case-lowering globMatch arm not found in source"
    echo "guard case-lowering globMatch arm: PRESENT"
    # Whole-program nocasematch probe (refuse = free, backend stays).
    sgrep -q 'contains("nocasematch")' \
      || fail "case-lowering nocasematch probe not found in source"
    echo "guard case-lowering nocasematch probe: PRESENT"
    ;;
  elseif_flatten)
    # The chain trigger: lone nested If with empty elsifs becomes an elsif.
    sgrep -q "fn flatten_chain" \
      || fail "elseif-flatten flatten_chain not found in source"
    echo "guard elseif-flatten flatten_chain: PRESENT"
    sgrep -q "inner_elsifs.is_empty()" \
      || fail "elseif-flatten empty-elsifs trigger not found in source"
    echo "guard elseif-flatten empty-elsifs trigger: PRESENT"
    sgrep -q "elsifs.push((c2, t2))" \
      || fail "elseif-flatten elsif push not found in source"
    echo "guard elseif-flatten elsif push: PRESENT"
    ;;
  seq_range)
    # The seq-shape recogniser + int/span gates + body-write scan.
    sgrep -q "fn seq_range_bounds" \
      || fail "seq-range seq_range_bounds not found in source"
    echo "guard seq-range seq_range_bounds: PRESENT"
    sgrep -q 'name != "seq"' \
      || fail "seq-range seq-name check not found in source"
    echo "guard seq-range seq-name check: PRESENT"
    sgrep -q "MAX_SAFE_INT" \
      || fail "seq-range exactness bound not found in source"
    echo "guard seq-range exactness bound MAX_SAFE_INT: PRESENT"
    sgrep -q "MAX_SPAN" \
      || fail "seq-range materialization bound not found in source"
    echo "guard seq-range materialization bound MAX_SPAN: PRESENT"
    sgrep -q "fn stmts_write_var" \
      || fail "seq-range body-write scan not found in source"
    echo "guard seq-range body-write scan: PRESENT"
    ;;
  ternary_desugar)
    # The ternary call match + cond classifier + testArith normalization.
    sgrep -q 'func == "ternary"' \
      || fail "ternary-desugar ternary match not found in source"
    echo "guard ternary-desugar ternary match: PRESENT"
    sgrep -q "fn is_test_string" \
      || fail "ternary-desugar is_test_string not found in source"
    echo "guard ternary-desugar is_test_string: PRESENT"
    sgrep -q "fn cond_args_clone" \
      || fail "ternary-desugar cond_args_clone not found in source"
    echo "guard ternary-desugar cond_args_clone: PRESENT"
    sgrep -q 'func == "testArith"' \
      || fail "ternary-desugar testArith normalization not found in source"
    echo "guard ternary-desugar testArith normalization: PRESENT"
    ;;
  escape_classes)
    # The classification itself (pass 2): multi-scope -> Store, array ->
    # Native/StoreArray, else Store/Local. The model's `class_of` is this
    # arm verbatim; an added class or a reordered precedence is drift.
    sgrep -q "let multi_scope = scope_set.len() > 1" \
      || fail "multi-scope criterion not found in source"
    echo "guard multi-scope criterion: PRESENT"
    for cls in "EscapeClass::StoreArray" "EscapeClass::NativeArray" "EscapeClass::Local"; do
      sgrep -qF "$cls" || fail "class $cls not found in source"
      echo "guard class $cls: PRESENT"
    done
    # Mark sources: a non-literal assign-target key and a non-literal
    # Index key both set dynkey (the model's `dynkey` map).
    sgrep -q "if !literal_key(k) {" || fail "assign-target dynamic-key mark not found in source"
    echo "guard dynkey mark (assign target): PRESENT"
    sgrep -q "if !literal_key(key) {" || fail "Index dynamic-key mark not found in source"
    echo "guard dynkey mark (Index): PRESENT"
    # The consumer the proof is about: the C renderer's Local/Store arm.
    command grep -q "escape_classes::EscapeClass::Local" "$root/sh2perl/src/c_backend.rs" \
      || fail "C consumer Local arm not found in c_backend.rs"
    echo "guard C consumer Local arm: PRESENT"
    command grep -q "escape_classes::EscapeClass::Store" "$root/sh2perl/src/c_backend.rs" \
      || fail "C consumer Store arm not found in c_backend.rs"
    echo "guard C consumer Store arm: PRESENT"
    ;;
  f32_narrow)
    # The exactness predicate the whole model rests on.
    sgrep -q "v.is_finite() && (v as f32) as f64 == v" \
      || fail "f32_exact round-trip predicate not found in source"
    echo "guard f32_exact round-trip: PRESENT"
    # The exactness-preserving form table (combine's non-literal arm):
    # +0/-0, *±1/±0, /±1. A dropped or added form is drift.
    sgrep -q '"+" => is_zero(l) || is_zero(r)' || fail "+0/-0 form not found in source"
    echo "guard form +0/-0: PRESENT"
    sgrep -q '"*" => is_one_or_zero(l) || is_one_or_zero(r)' || fail "*±1/*±0 form not found in source"
    echo "guard form *±1/*±0: PRESENT"
    sgrep -q '"/" => is_one(r)' || fail "/±1 form not found in source"
    echo "guard form /±1: PRESENT"
    sgrep -q '"-" => is_zero(r)' || fail "-0 form not found in source"
    echo "guard form -0: PRESENT"
    # operand_exact: Float needs `exact`, Int needs the cval round-trip,
    # Unknown never.
    sgrep -q "Dom::Int => v.cval.map(f32_exact).unwrap_or(false)" \
      || fail "operand_exact int round-trip rule not found in source"
    echo "guard operand_exact int round-trip: PRESENT"
    # The renderer hook the verdict feeds.
    sgrep -q "pub fn is_f32_var" || fail "is_f32_var hook not found in source"
    echo "guard is_f32_var hook: PRESENT"
    command grep -q "f32_narrow::is_f32_var" "$root/sh2perl/src/c_backend.rs" \
      || fail "C consumer f32 arm not found in c_backend.rs"
    echo "guard C consumer f32 arm: PRESENT"
    ;;
  append_store)
    # The counted-loop shape: ForInit header with 0-init and +1 step.
    sgrep -q "fn counted_forinit" \
      || fail "counted_forinit header matcher not found in source"
    echo "guard counted +1 header: PRESENT"
    sgrep -q "fn zero_init_of" \
      || fail "zero_init_of not found in source"
    echo "guard 0-init: PRESENT"
    # The escape veto (break/continue/return desync the counter).
    sgrep -q "fn escapes" \
      || fail "escapes veto not found in source"
    echo "guard no-escapes veto: PRESENT"
    # The append-site census (exactly-one site + empty init + no other).
    sgrep -q "appends == 1" \
      || fail "exactly-one-append filter not found in source"
    echo "guard exactly-one-append: PRESENT"
    sgrep -q "fn literal_bound" \
      || fail "literal_bound gate not found in source"
    echo "guard known-bound gate: PRESENT"
    ;;
  split_set)
    # The routing predicate (value decides the partition).
    sgrep -q '"isSmallInt"' \
      || fail "isSmallInt routing predicate not found in source"
    echo "guard isSmallInt routing: PRESENT"
    # The join merge (sortedJoinMerge of both partitions).
    sgrep -q '"sortedJoinMerge"' \
      || fail "sortedJoinMerge consumer not found in source"
    echo "guard join merge: PRESENT"
    # The append-only whitelist (indexed writes/deletes refuse).
    sgrep -q "fn scope_refs_ok" \
      || fail "scope_refs_ok whitelist not found in source"
    echo "guard append-only whitelist: PRESENT"
    ;;
  echo_return)
    # The per-path echo discipline (Need/Done/Dead machine).
    sgrep -q "enum EchoState" \
      || fail "EchoState machine not found in source"
    echo "guard echo-state machine: PRESENT"
    sgrep -q "fn body_echo_ok" \
      || fail "body_echo_ok recognition not found in source"
    echo "guard body recognition: PRESENT"
    # The call-site wrap (exec echo of fnValue).
    sgrep -q '"fnValue"' \
      || fail "fnValue wrap not found in source"
    echo "guard fnValue wrap: PRESENT"
    # The pipeline-last-stage rule (value position keeps its echo).
    sgrep -q "fn echo_pipeline_last_stage" \
      || fail "pipeline-last-stage rule not found in source"
    echo "guard last-stage echo: PRESENT"
    ;;
  scc)
    # The call-graph builder (exec/fnCall/capture edges, defined-only).
    sgrep -q "fn build_call_graph_stmts" \
      || fail "call-graph builder not found in source"
    echo "guard call-graph builder: PRESENT"
    sgrep -q "fn tarjan_sccs" \
      || fail "tarjan_sccs not found in source"
    echo "guard Tarjan SCC: PRESENT"
    # The consumer query (echo_return's fixpoint reads scc_of).
    sgrep -q "fn scc_of" \
      || fail "scc_of query not found in source"
    echo "guard scc_of query: PRESENT"
    ;;
  used_before_decl)
    # The must-defined analysis entry.
    sgrep -q "fn analyze_use_before_decl" \
      || fail "analyze_use_before_decl not found in source"
    echo "guard analysis entry: PRESENT"
    sgrep -q "must_def" \
      || fail "must_def set not found in source"
    echo "guard must-def set: PRESENT"
    # The finding shape (var + position).
    sgrep -q "struct UseBeforeDeclFinding" \
      || fail "finding struct not found in source"
    echo "guard finding shape: PRESENT"
    ;;
  maskable)
    # The threshold function + divisor gate + isqrt.
    sgrep -q "fn mask_threshold" \
      || fail "mask_threshold not found in source"
    echo "guard threshold fn: PRESENT"
    sgrep -q "fn is_pow2_lit" \
      || fail "is_pow2_lit gate not found in source"
    echo "guard pow2 gate: PRESENT"
    sgrep -q "VER_INF" \
      || fail "VER_INF not found in source"
    echo "guard INF bound: PRESENT"
    ;;
  lifetime)
    # The lifetime analysis entry.
    sgrep -q "fn analyze_var_lifetimes" \
      || fail "analyze_var_lifetimes not found in source"
    echo "guard analysis entry: PRESENT"
    ;;
  numstr)
    # The seed entry + revalidation discipline.
    sgrep -q "pub fn seed" \
      || fail "seed entry not found in source"
    echo "guard seed entry: PRESENT"
    sgrep -q "revalidate_params" \
      || fail "revalidate_params not found in source"
    echo "guard revalidation: PRESENT"
    ;;
  numeric_observed)
    # The analysis entry + numeric-use census.
    sgrep -q "pub fn analyze" \
      || fail "analyze entry not found in source"
    echo "guard analysis entry: PRESENT"
    sgrep -q "Use::Num" \
      || fail "Use::Num verdict not found in source"
    echo "guard numeric-use verdict: PRESENT"
    ;;
  arith_forms)
    # The let-arg gate: text extraction + parse_arith verdict.
    sgrep -q "fn let_arg_text" \
      || fail "let_arg_text gate not found in source"
    echo "guard let-arg text: PRESENT"
    sgrep -q "fn build_assigns" \
      || fail "build_assigns not found in source"
    echo "guard assign builder: PRESENT"
    # The two lowerings (exec-expr and exec-stmt shapes).
    sgrep -q "fn lower_let_expr" \
      || fail "lower_let_expr not found in source"
    echo "guard expr lowering: PRESENT"
    sgrep -q "fn lower_let_stmt" \
      || fail "lower_let_stmt not found in source"
    echo "guard stmt lowering: PRESENT"
    ;;
  counted_while_forinit)
    # The counter-step gate (both spellings, nonzero literal).
    sgrep -q "fn counter_step" \
      || fail "counter_step gate not found in source"
    echo "guard counter step: PRESENT"
    # The body veto (writes/escapes) and the status-read veto.
    sgrep -q "fn writes_or_escapes" \
      || fail "writes_or_escapes veto not found in source"
    echo "guard no-write veto: PRESENT"
    sgrep -q "fn contains_status_read" \
      || fail "contains_status_read veto not found in source"
    echo "guard no-status veto: PRESENT"
    ;;
  *) fail "unknown model: $MODEL" ;;
esac
echo
echo "[counts]"
echo "proof-fns: $(command grep -c "proof fn " "$PRF")"
echo "pins: $(printf '%s\n' "$model_pins" | wc -l)"
echo "# NOTE: proof-fns is a file-shape fact (change detector), NOT the"
echo "# Verus obligation count — the gate asserts N verified separately."
echo
echo "[exec]"
echo "# Each MAPPED test above, EXECUTED against the live source (one"
echo "# module-suite run per model; per-test verdicts grepped from output)."
echo "# A mapped test that fails or vanishes from the run is drift — FATAL."
echo "# The checker RUNS each mapped test (one module-suite cargo test per"
echo "# source file) and records the per-test PASS/FAIL verdict below."
{
# One module-suite run per SOURCE file. Two failure classes:
#   COMPILE-BLOCKED: the lib target does not build (often a concurrent
#     worker's mid-edit tree — NOT this model's verdict). Recorded as
#     BLOCKED per test; the checker still FAILs (loud, not green-by-
#     absence) with the build error attached, so a blocked sync can never
#     read as verified.
#   TEST-FAIL/MISSING: per-test verdicts below; the manifest names the
#     broken fragment.
test_out=""; suite_blocked=0
for src in $SRCS; do
  one="$(cargo test --manifest-path "$root/sh2perl/Cargo.toml" --lib "$SRCDIR::$src" 2>&1)"; rc=$?
  if printf '%s\n' "$one" | command grep -q "could not compile"; then
    suite_blocked=1
    test_out="$test_out
# --- $SRCDIR::$src: BUILD BLOCKED ---
$one"
  else
    test_out="$test_out
# --- $SRCDIR::$src exit: $rc ---
$one"
  fi
done
if [ "$suite_blocked" -eq 1 ]; then
  while IFS= read -r pin; do
    entry="$(pin_map "$MODEL" "$pin")"
    if [ "$entry" = "UNMIRRORED" ]; then
      echo "exec $pin: UNMIRRORED (not executed)"
    else
      echo "exec $pin: BLOCKED (lib target does not compile — see build log above)"
    fi
  done <<< "$model_pins"
  fail "lib target does not compile — sync cannot execute (foreign breakage? re-run when green)"
fi
echo "# all suites built; per-test verdicts below"
exec_fail=0
while IFS= read -r pin; do
  entry="$(pin_map "$MODEL" "$pin")"
  if [ -z "$entry" ]; then
    echo "exec $pin: UNMAPPED (no pin_map entry)"
    exec_fail=1
    continue
  elif [ "$entry" = "UNMIRRORED" ]; then
    echo "exec $pin: UNMIRRORED (not executed)"
    continue
  fi
  mapped="${entry##*:}"
  line="$(printf '%s\n' "$test_out" | command grep -F "::$mapped ..." | head -1 || true)"
  if [ -z "$line" ]; then
    echo "exec $pin ($mapped): MISSING (no test-result line — renamed? filtered?)"
    exec_fail=1
  elif printf '%s\n' "$line" | command grep -q " ok$"; then
    echo "exec $pin ($mapped): PASS"
  else
    echo "exec $pin ($mapped): FAIL :: $line"
    exec_fail=1
  fi
done <<< "$model_pins"
[ "$exec_fail" -eq 0 ] || fail "one or more mapped tests did not pass (see exec lines above)"
} >> "$OUT"
} > "$OUT"
