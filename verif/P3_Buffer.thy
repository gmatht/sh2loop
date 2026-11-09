theory P3_Buffer
  imports Main
begin

text \<open>
  P3, the `strlen \<le> N` half.

  `C_UB_PROOF.md` section 5 and `verif/PLAN-P1.md` section 3 split P3 in two:
  the capacity half (a growable array's declared size, proved in
  P3_Capacity.thy) and the *fixed-buffer* half proved here. The
  renderer's header states the contract (c_backend.rs:18-24):

    a Str var with a known bound N gets a FIXED buffer `char v[N+1]`,
    with DEBUG-ONLY length asserts (`assert()`, compiled out under NDEBUG)
    at the function boundary and BEFORE every copy into the buffer — the
    write that would overflow is UB, and the assert is the debug-mode
    tripwire; under NDEBUG `strncpy` truncates.

  So under NDEBUG the *assert* is gone and the safety of a write rests
  entirely on the bound N being right. That is the obligation mechanized
  here, over an abstract string model rather than a C parser (this Isabelle
  distribution ships no `C-Parser`/`AutoCorres`, so a deep embedding of the
  emitted text is not available — see the P4 note in `C_UB_PROOF.md`).
  The model is the one the emitted code actually uses: a
  destination buffer of capacity `cap`, source strings of bounded length,
  and the two copy idioms the renderer emits.
\<close>

text \<open>A string is its length (the character data is irrelevant to bounds).\<close>

type_synonym str = nat

text \<open>A destination buffer: a capacity and the length currently stored.\<close>

record buf =
  cap :: nat
  len :: nat

text \<open>@{term fits_buf} — the invariant every write must preserve. It is
  exactly what lets a trailing NUL be appended, so it is the predicate the
  fixed-buffer transform exists to establish.\<close>

definition fits_buf :: "buf \<Rightarrow> bool" where
  "fits_buf b \<longleftrightarrow> len b < cap b"

text \<open>The unbounded copy: `strcpy`-shaped. It is safe only when the source
  (plus its NUL) fits the destination. This is the UB the renderer's
  debug-only assert is a tripwire for.\<close>

definition copy_unbounded :: "buf \<Rightarrow> str \<Rightarrow> buf option" where
  "copy_unbounded (b :: buf) (s :: str) = (if s < cap b then Some (b\<lparr>len := s\<rparr>) else None)"

text \<open>The bounded copy the renderer emits under NDEBUG: `strncpy(dst, src,
  cap-1)` followed by the explicit terminator, i.e. truncate to `cap-1`
  characters. This never fails — but it can silently shorten the value,
  which is why the renderer prefers it only behind a correct bound.\<close>

definition copy_bounded :: "buf \<Rightarrow> str \<Rightarrow> buf" where
  "copy_bounded (b :: buf) (s :: str) = b\<lparr>len := min s (cap b - 1)\<rparr>"

text \<open>The safety property: the bounded copy always leaves a buffer that can
  still take its NUL. This is the lemma that makes "truncates under
  NDEBUG" a *wrong value* rather than UB.\<close>

lemma copy_bounded_preserves_fits:
  assumes "cap b \<ge> 1"
  shows "fits_buf (copy_bounded b s)"
  using assms unfolding fits_buf_def copy_bounded_def by simp

text \<open>And the unbounded copy is exact — no truncation — whenever it is safe
  at all. So the two idioms bracket the contract: exact-if-fits, else
  truncating-but-defined.\<close>

lemma copy_unbounded_exact:
  assumes "copy_unbounded b s = Some b'" "fits_buf b"
  shows "len b' = s"
  using assms unfolding copy_unbounded_def fits_buf_def by (auto split: if_splits)

text \<open>The theorem the backend's bound N must supply: if the analysis proves
  @{text "len(s) \<le> N"} and the buffer was declared with capacity
  @{text "N + 1"}, then the unbounded copy is safe. This is the `strlen \<le> N`
  obligation of `C_UB_PROOF.md` section 5, and it shows exactly what a
  wrong N costs: the copy returns @{term None}, i.e. the caller must not
  perform it.\<close>

theorem strlen_bound_justifies_copy:
  assumes "s \<le> n" "cap b = n + 1"
  shows "copy_unbounded b s \<noteq> None"
  using assms unfolding copy_unbounded_def by simp

text \<open>The converse, which is the failure mode the corpus does not exhibit
  but that a mis-analyzed bound would produce: a source longer than the
  declared buffer makes the unbounded copy unsafe. This is the direction a
  *missing* bound check violates — the same shape as P1's
  @{term outside_width_not_admitted_u8} and P2's
  @{term subtree_overflow_forces_gmp}.\<close>

lemma overlong_source_makes_copy_unsafe:
  assumes "cap b \<le> s"
  shows "copy_unbounded b s = None"
  using assms unfolding copy_unbounded_def by simp

text \<open>A truncating copy is never out of bounds, even from a buffer whose
  capacity is 1 (a single NUL). Stated separately because `cap - 1`
  underflows in @{typ nat} and the `\<ge> 1` hypothesis is what the renderer's
  `N + 1` declaration always provides.\<close>

lemma bounded_copy_never_overflows:
  assumes "cap b = n + 1"
  shows "len (copy_bounded b s) \<le> n"
  using assms unfolding copy_bounded_def by simp

text \<open>Composition with the renderer's debug-only assert: the assert checks
  exactly @{term fits_buf} (it is `assert(strlen(v) <= N)` against
  `char v[N+1]`). Under a debug build a violation aborts; under NDEBUG the
  call it guards is the bounded copy, which is defined but may truncate.
  Either way no write leaves the buffer — the property that matters for
  UB, and the reason the fixed-buffer transform's *value* risk (silent
  truncation) is a correctness question rather than a safety one.\<close>

theorem debug_assert_matches_contract:
  assumes "cap b = n + 1" "fits_buf b"
  shows "len b \<le> n"
  using assms unfolding fits_buf_def by simp

text \<open>The remaining gap, stated so it is not mistaken for proved: the
  analysis that *produces* N (@{text analyze_string_lengths} in
  `shir.rs`) is Rust code, and its soundness — that a variable's value
  really has length at most N wherever it is written — is a property of
  the shIR walk, not of the buffer arithmetic above. What is proved here
  is that a correct N suffices; that N is correct is the obligation a
  generator (the `--dump-widths` bridge of `PLAN-P1.md` section 4) would
  have to discharge by measurement against `analyze_string_lengths`.\<close>

end
