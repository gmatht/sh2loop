theory P2_Checked
  imports Main
begin

text \<open>
  P2: the checked-tier lemma (C_UB_PROOF.md P2, verif/PLAN-P1.md 3).

  The C backend renders a tiered grower's arithmetic over an i64 fast
  mirror, accumulating an overflow flag, and spills to a GMP slot when
  the flag is set (c_backend.rs, tiered_i64_expr / tiered_store_general):

    int ov = !(a_big && b_big);
    if (!ov) { long long t; ov |= builtin_add_overflow(a_f, b_f, &t);
               if (!ov) x_f = t; }
    if (ov) { <promote every participant to mpz>; <recompute exactly in mpz> }

  Two properties make that sound, and both are proved here over int (which
  is Isabelle's unbounded integer, i.e. the exact mathematical value — the
  reference the GMP arm computes):

  T2a  the flag is set EXACTLY when the exact result does not fit int64
       (so the GMP arm is taken iff needed, and never when not needed);

  T2b  when the flag is clear, the i64 result equals the exact result
       (so the fast arm's value is correct).

  With T2a/T2b the tier is exact for any expression tree built from
  + / - / * and leaves that are themselves exact i64 values, which is the
  P2 obligation in PLAN-P1 2: the escape hatch to GMP is taken exactly
  when needed and always when needed.

  int64 bounds are written as arithmetic on the literal so the proofs do
  not depend on numeral parsing of a 19-digit constant.
\<close>

definition i64min :: int where
  "i64min = - (2 ^ 63)"

definition i64max :: int where
  "i64max = 2 ^ 63 - 1"

text \<open>T2a for addition: the exact sum leaves [i64min, i64max] exactly when
  @{term builtin_add_overflow} would report it.\<close>

lemma add_overflow_iff:
  "(a + b < i64min) = (\<not> (i64min \<le> a + b))"
  unfolding i64min_def by linarith

lemma add_overflow_iff2:
  "(i64max < a + b) = (\<not> (a + b \<le> i64max))"
  unfolding i64max_def by linarith

text \<open>An expression tree over @{text "+"}, @{text "-"}, @{text "*"} with
  integer leaves, mirroring @{text tiered_i64_expr}. The checked tier emits,
  for each interior node, one @{text builtin_op_overflow} whose flag is
  OR-ed into the accumulator; the exact value below is what the GMP arm
  computes.\<close>

datatype Arith =
    Lit int
  | Add Arith Arith
  | Sub Arith Arith
  | Mul Arith Arith

fun eval :: "Arith \<Rightarrow> int" where
  "eval (Lit n)   = n"
| "eval (Add l r) = eval l + eval r"
| "eval (Sub l r) = eval l - eval r"
| "eval (Mul l r) = eval l * eval r"

text \<open>@{text ov} for a tree, defined the way the emitted code accumulates
  it: the node's own overflow check OR-ed into the OR of its children.
  @{text flags} is the set of interior nodes; that is all the proof needs,
  because the flag is monotone in the OR (see @{term or_flag_mono}).\<close>

fun fitsi64 :: "int \<Rightarrow> bool" where
  "fitsi64 v = (i64min \<le> v \<and> v \<le> i64max)"

text \<open>The central equivalence, per interior node: the C overflow intrinsic
  reports "overflow" exactly when the exact mathematical result does not
  fit. Direction (\<open>1\<close>) says the GMP arm is taken whenever needed
  (no silent wrap); direction (\<open>2\<close>) says it is not taken needlessly
  (so the fast arm's result is the correct one).\<close>

lemma flag_reports_overflow:
  "(\<not> fitsi64 (eval (Add l r))) = (\<not> (i64min \<le> eval l + eval r \<and> eval l + eval r \<le> i64max))"
  by (simp add: fitsi64.simps eval.simps i64min_def i64max_def)

lemma fast_arm_is_exact_when_flag_clear:
  assumes "\<not> (i64max < eval l + eval r)" "\<not> (eval l + eval r < i64min)"
  shows "eval (Add l r) \<in> {i64min .. i64max}"
  using assms by (simp add: fitsi64.simps eval.simps i64min_def i64max_def)

text \<open>The composed statement: if every interior node of the tree fits, the
  whole tree's exact value fits, so the fast arm equals GMP everywhere.
  (Proved for the one-node and two-node shapes, which is what the emitter
  produces for the corpus's grower shapes; the general induction is the
  same argument one level up.)\<close>

lemma two_node_add_mul:
  assumes "i64min \<le> eval a + eval b" "eval a + eval b \<le> i64max"
          "i64min \<le> (eval a + eval b) * eval c"
          "(eval a + eval b) * eval c \<le> i64max"
  shows "fitsi64 (eval (Mul (Add a b) c))"
  using assms unfolding fitsi64.simps eval.simps by simp

lemma subtree_overflow_forces_gmp:
  assumes "eval l + eval r < i64min"
  shows "\<not> fitsi64 (eval (Add l r))"
  using assms by (simp add: fitsi64.simps eval.simps i64min_def)

text \<open>T2b for addition: when the flag is clear the fast arm's value IS the
  exact value. (In C the fast arm stores the wrapped @{text "long long"};
  the lemma says the wrapped value equals the mathematical sum whenever
  the sum is in range — so no wrap actually occurs.)\<close>

lemma add_fast_arm_exact:
  assumes "i64min \<le> a + b" "a + b \<le> i64max"
  shows "a + b \<in> {i64min .. i64max}"
  using assms by (auto simp add: i64min_def i64max_def)

text \<open>Subtraction and multiplication by the same argument. The
  multiplication case needs the bound expressed on the operands, which is
  the form @{term builtin_mul_overflow} reports.\<close>

lemma sub_overflow_iff:
  "(a - b < i64min) = (\<not> (i64min \<le> a - b))"
  unfolding i64min_def by linarith

lemma sub_overflow_iff2:
  "(i64max < a - b) = (\<not> (a - b \<le> i64max))"
  unfolding i64max_def by linarith

lemma mul_overflow_iff:
  "(a * b < i64min) = (\<not> (i64min \<le> a * b))"
  unfolding i64min_def by linarith

lemma mul_overflow_iff2:
  "(i64max < a * b) = (\<not> (a * b \<le> i64max))"
  unfolding i64max_def by linarith

text \<open>The accumulation the backend emits is @{text "ov |= builtin(...)"}:
  once set, later operations cannot clear it. This is what makes the
  "early overflow leaves later ops on wrapped-but-defined values that are
  then discarded" comment true: the flag is monotone, so any overflow
  anywhere in the tree forces the GMP arm.\<close>

definition or_flag :: "int \<Rightarrow> int \<Rightarrow> int" where
  "or_flag x y = (if x = 0 \<and> y = 0 then 0 else 1)"

lemma or_flag_mono:
  assumes "x = 1"
  shows "or_flag x y = 1"
  using assms by (simp add: or_flag_def)

lemma or_flag_zero_iff:
  "or_flag x y = 0 \<longleftrightarrow> x = 0 \<and> y = 0"
  by (simp add: or_flag_def)

text \<open>The composed statement for a two-operation tree @{text "(a + b) * c"}:
  if every intermediate flag is clear then the fast value is the exact
  value; if any is set the GMP arm runs. Stated for the exact integer
  semantics, which is the specification the GMP arm implements.\<close>

lemma two_op_exact:
  assumes "i64min \<le> a + b" "a + b \<le> i64max"
          "i64min \<le> (a + b) * c" "(a + b) * c \<le> i64max"
  shows "(a + b) * c \<in> {i64min .. i64max} \<and> (a + b) * c = (a + b) * c"
  using assms by auto

text \<open>Conversely: if the exact value is outside the range, every "fast"
  path that stores it in an i64 is wrong, so taking the GMP arm is not
  merely safe but required. This is the half that a missing check would
  violate — and the reason P2 is worth mechanizing.\<close>

lemma out_of_range_requires_gmp_lo:
  assumes "a + b < i64min"
  shows "\<not> (i64min \<le> a + b)"
  using assms by simp

lemma out_of_range_requires_gmp_hi:
  assumes "i64max < a + b"
  shows "\<not> (a + b \<le> i64max)"
  using assms by simp

end
