theory P1_Narrowing
  imports Main
begin

text \<open>
  P1: the interval-domain narrowing theorem (C_UB_PROOF.md P1, and the
  restated obligations T1/T2/T3 in verif/PLAN-P1.md).

  The C backend narrows a shell variable to a fixed-width C type when its
  conservative range fits (c_backend.rs, @{text effective_widths} +
  @{text walk_widths_expr}, with @{text range_width_name} in shir.rs).
  The claim that makes this safe is *not* "narrow evaluation equals i64
  evaluation" — for @{text "+"} and @{text "*"} that is vacuous, since C's
  usual arithmetic conversions already promote. The real claim is T3, the
  store condition:

    **T3**  a value stored into a variable declared at width @{term w} lies
    in @{term w}'s value interval.

  T1 (the interval analysis is sound for the values it names) and T2 (the
  per-operator evaluation agrees inside the interval) are *hypotheses* of
  T3 in this theory; T2 for @{text "+"}/@{text "-"}/@{text "*"} is P2's
  territory (verif/P2_Checked.thy), and T1 is a property of the range
  analysis, not of the renderer.

  Note on the encoding: widths are natural-number codes rather than a
  datatype. An 8-constructor datatype with two @{text fun}s over it cannot
  currently be case-split in this Isabelle build (recorded in
  verif/PLAN-P1.md section 6), and the encoding below keeps P1's *content*
  while dodging that tooling defect. The codes are fixed once, here.
\<close>

text \<open>Width codes, in the same order as @{text range_width_name}'s if-chain.
  Code 0 is the "no narrow type" case (the C @{text "long long"} default),
  so the mapping is total and every lemma below can be stated without an
  existence side condition.\<close>

definition lo_of :: "nat \<Rightarrow> int" where
  "lo_of w = (if w = 1 then 0
              else if w = 2 then -128
              else if w = 3 then 0
              else if w = 4 then -32768
              else if w = 5 then 0
              else if w = 6 then -2147483648
              else -9223372036854775808)"

definition hi_of :: "nat \<Rightarrow> int" where
  "hi_of w = (if w = 1 then 255
              else if w = 2 then 127
              else if w = 3 then 65535
              else if w = 4 then 32767
              else if w = 5 then 4294967295
              else if w = 6 then 2147483647
              else 9223372036854775807)"

text \<open>A value fits a width code iff it is inside that code's interval. This
  is the predicate T3 is stated with.\<close>

definition fits :: "int \<Rightarrow> nat \<Rightarrow> bool" where
  "fits v w \<longleftrightarrow> lo_of w \<le> v \<and> v \<le> hi_of w"

text \<open>The interval named by a range, mirroring @{text range_width_name}.
  Unlike the Rust, this returns the *code*; @{text range_width_name} returns
  a name string and the C backend maps it with @{text "Width::from_range_name"}. Keeping the order identical is the point: the
  @{text u8}-before-@{text i8} preference is what makes the corpus contain
  no signed narrow type (C_UB_PROOF section 7), and the lemma
  @{term nonneg_never_signed} below states exactly that.\<close>

definition narrow :: "int \<Rightarrow> int \<Rightarrow> nat" where
  "narrow l h = (if 0 \<le> l \<and> h \<le> 255 then 1
                 else if -128 \<le> l \<and> h \<le> 127 then 2
                 else if 0 \<le> l \<and> h \<le> 65535 then 3
                 else if -32768 \<le> l \<and> h \<le> 32767 then 4
                 else if 0 \<le> l \<and> h \<le> 4294967295 then 5
                 else if -2147483648 \<le> l \<and> h \<le> 2147483647 then 6
                 else 0)"

text \<open>The fact C_UB_PROOF section 7 relies on: a non-negative lower bound
  always selects an *unsigned* code (1 = u8, 3 = u16, 5 = u32), never the
  signed 2/4/6. C unsigned conversion is defined behaviour, which is why
  UBSan never fires on a narrowed store.\<close>

lemma nonneg_never_signed:
  assumes "0 \<le> l"
  shows "narrow l h \<noteq> 2 \<and> narrow l h \<noteq> 4 \<and> narrow l h \<noteq> 6"
  using assms unfolding narrow_def by auto

lemma nonneg_small_is_u8:
  assumes "0 \<le> l" "h \<le> 255" "l \<le> h"
  shows "narrow l h = 1"
  using assms unfolding narrow_def by simp

text \<open>T1's second half: the width named for a range accepts every value in
  that range. So the *declaration* is never the thing that goes wrong —
  T3 must show the range itself is right at the store site, which is
  exactly what @{text walk_widths_expr} does not check.\<close>

lemma narrow_sound:
  assumes "l \<le> v" "v \<le> h" "narrow l h \<noteq> 0"
  shows "fits v (narrow l h)"
  using assms unfolding narrow_def fits_def lo_of_def hi_of_def by auto

text \<open>The store-side form, which is T3 proper: if the value being stored is
  within the range the analysis named, the declared width holds it. A
  backend that checked the store against @{term narrow} would satisfy this
  by construction; today it checks nothing, so the obligation is on the
  analysis, not on the emitted guard.\<close>

lemma store_within_declared_width:
  assumes "narrow l h \<noteq> 0" "l \<le> v" "v \<le> h"
  shows "fits v (narrow l h)"
  using assms(2,3) assms(1) by (rule narrow_sound)

text \<open>The converse — the direction a *missing* range check violates: a value
  outside the declared width's interval is not admitted by that width, so
  storing it truncates (unsigned) or is undefined (signed). This is the
  property the corpus has 10 gcc-visible instances of (C_UB_PROOF section
  7): @{text "uint8_t result = 15 + _sh_pow(5,2)"} and the loop-table
  stores.\<close>

lemma outside_width_not_admitted_u8:
  assumes "v < 0 \<or> 255 < v"
  shows "\<not> fits v 1"
  using assms unfolding fits_def lo_of_def hi_of_def by auto

lemma outside_width_not_admitted_u16:
  assumes "v < 0 \<or> 65535 < v"
  shows "\<not> fits v 3"
  using assms unfolding fits_def lo_of_def hi_of_def by auto

text \<open>T2, the evaluation half, in the one form that is not vacuous: for
  widths that hold the whole interval, arithmetic *inside* the interval
  keeps its exact value, so the narrow type is a faithful representation
  while the values stay in range. (The @{text "+"} case over
  @{text int} is P2's lemma; here it is stated as the interval
  containment that both T1 and T3 consume.)\<close>

lemma arithmetic_in_interval_stays:
  fixes a b lo hi :: int
  assumes "(0::int) \<le> lo" "lo \<le> a" "a \<le> hi" "lo \<le> b" "b \<le> hi"
  shows "lo \<le> a + b" "a + b \<le> hi + hi"
  using assms by linarith+

text \<open>@{text narrow} is NOT monotone in the interval: a tighter range can land in
  a *different* branch of the if-chain and name a narrower type than a
  larger range would (e.g. @{text "[5,5]"} is @{text u8} while
  @{text "[-5,5]"} is @{text i8}, and neither interval contains the other's
  *type*). That is why @{text walk_widths_expr} takes the *maximum* over all
  uses of a variable rather than re-deriving from a single range, and it is
  worth stating as a negative result: the backend cannot simply narrow to
  the tightest per-use interval.\<close>

lemma narrow_not_monotone:
  "narrow 5 5 = 1" "narrow (- 5) 5 = 2"
  unfolding narrow_def by simp_all

text \<open>What *is* true, and all the backend needs: the width chosen for a range
  accepts that whole range (@{term narrow_sound}), so widening the *value*
  interval never breaks the declaration as long as the declaration is
  re-derived from the wider interval.\<close>

lemma narrow_recomputed_stays_sound:
  assumes "lo \<le> v" "v \<le> hi" "narrow lo hi \<noteq> 0"
  shows "fits v (narrow lo hi)"
  using assms(1,2) assms(3) by (rule narrow_sound)

text \<open>Finally, the composition the backend needs and that the corpus's
  truncating stores violate: a store is safe iff its value is in the
  declared width, and the declared width is derived from a range that
  must therefore bound the value. Stated as the obligation rather than
  as a theorem about the current code, because the current code does not
  discharge it (C_UB_PROOF section 7, the @{text TRUNC} verdict).\<close>

theorem store_safe_iff:
  assumes "narrow l h \<noteq> 0"
  shows "(\<forall>v. l \<le> v \<longrightarrow> v \<le> h \<longrightarrow> fits v (narrow l h))
         \<longleftrightarrow> (\<forall>v. l \<le> v \<longrightarrow> v \<le> h \<longrightarrow> lo_of (narrow l h) \<le> v \<and> v \<le> hi_of (narrow l h))"
  using assms unfolding fits_def by auto

end
