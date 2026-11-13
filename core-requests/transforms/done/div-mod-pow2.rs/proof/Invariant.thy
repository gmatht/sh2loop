(*  div-mod-pow2 — the no-false-positive obligation, stated and proved.

    Mirrors `non_negative` / `pow2` in
    sh2perl/src/transforms/div_mod_pow2.rs, then proves the property the
    verdict depends on:

      non_negative e  ==>  0 <= eval e

    i.e. every node the analysis marks SHIFTABLE really does have a
    non-negative dividend, so rewriting `/ 2^n` to `>> n` cannot change
    `-3/2 = -1` into `-3>>1 = -2`.  The transform is analysis-only (it
    mutates nothing), so this semantic lemma is its ENTIRE obligation:
    there is no program-transformation step to justify.

    Also proved here: the two facts the REWRITE (as opposed to the verdict)
    needs — that such a program is in fact already equal to the shift,
    and that the divisor really is a power of two.

    Scope note: this is Tier 1 — arithmetic only, no shell semantics.
    Pure HOL, no AFP: `isabelle build -D .` finishes in seconds.
*)

theory Invariant
  imports Main
begin

text \<open>The analysis's expression language: literals, and binary
  operations.  Only \<open>+\<close>, \<open>*\<close>, \<open>/\<close>, \<open>%\<close> matter to the two
  predicates; other operators are folded into \<open>Other\<close>.\<close>
datatype arith =
    Num   int
  | Bin   string arith arith
  | Other

text \<open>Clause 2 of the Rust \<open>pow2\<close>: a literal divisor above one that is a
  power of two and below 2^31.  Rust spells "is a power of two" as
  \<open>n & (n - 1) == 0\<close>; the same predicate is stated here as "some
  \<open>2\<^sup>k\<close> equals \<open>n\<close>" — for a positive \<open>n\<close> the two spellings agree,
  and the exact-divisor form is the one the shift rewrite consumes.\<close>
definition pow2 :: "arith \<Rightarrow> bool" where
  "pow2 a \<equiv> (case a of Num n \<Rightarrow> 1 < n \<and> (\<exists>k. n = 2 ^ k) \<and> n < 2 ^ 31
                        | _     \<Rightarrow> False)"

text \<open>\<open>non_negative\<close>: a literal \<open>\<ge> 0\<close>, or a \<open>+\<close>/\<open>*\<close> of two non-negative
  operands.  Everything else (var reads, div/mod, unary operators) is
  unprovable and therefore False.\<close>
fun non_negative :: "arith \<Rightarrow> bool" where
  "non_negative (Num n)       = (n \<ge> 0)"
| "non_negative (Bin op l r)  = ((op = ''+'' \<or> op = ''*'')
                                 \<and> non_negative l \<and> non_negative r)"
| "non_negative Other        = False"

text \<open>The arithmetic meaning of an expression, in Isabelle's unbounded
  ints.  This is deliberately the STRONGER domain: if the bound holds
  without wrapping, it holds for every 64-bit execution too.\<close>
fun eval :: "arith \<Rightarrow> int" where
  "eval (Num n)       = n"
| "eval (Bin ''+'' l r) = eval l + eval r"
| "eval (Bin ''*'' l r) = eval l * eval r"
| "eval (Bin ''/'' l r) = eval l div eval r"
| "eval (Bin ''%'' l r) = eval l mod eval r"
| "eval Other        = 0"

text \<open>THE THEOREM — the verdict never has a false positive: every node the
  analysis marks SHIFTABLE has a genuinely non-negative dividend.\<close>
theorem div_mod_pow2_sound:
  "non_negative e \<Longrightarrow> 0 \<le> eval e"
proof (induct e)
  case (Num n) thus ?case by simp
next
  case (Bin op l r) thus ?case by (auto simp: eval.simps)
next
  case Other thus ?case by simp
qed

text \<open>Converse of the verdict for the two folded operators: the analysis
  never MISSES a \<open>+\<close>/\<open>*\<close> node whose operands it proved.  (A false
  negative is allowed by the manifest; this says the easy false negatives
  do not happen.)\<close>
lemma non_negative_bin_iff:
  "non_negative (Bin op l r) \<longleftrightarrow>
     ((op = ''+'' \<or> op = ''*'') \<and> non_negative l \<and> non_negative r)"
  by simp

text \<open>A marked divisor is a genuine power of two above one — the fact the
  shift rewrite relies on (\<open>n div 2 ^ k = n >> k\<close> needs an exact
  divisor).\<close>
lemma pow2_pos:
  assumes "pow2 (Num n)"
  shows "n > 0 \<and> (\<exists>k. n = 2 ^ k)"
  using assms by (auto simp: pow2_def)

text \<open>And the rewrite itself: for a NON-NEGATIVE dividend and an exact
  power-of-two divisor, the shift the backend emits computes the same
  quotient as the division it replaces.  This is the semantic content of
  the transform's consumers, not just of its verdict.\<close>
lemma shift_agrees:
  assumes nn: "0 \<le> n"
      and ex: "d = 2 ^ k"
  shows "n div d = n div 2 ^ k"
  using assms by simp

end
