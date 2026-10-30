theory Claim
  imports Main
begin

text \<open>string-accumulator — the manifest's claim, in self-contained shape:
  the verdict's read walk finds an arithmetic read of the accumulator, and
  the pre-fix walk (the catch-all arms) does not. Mirrors of the Rust
  \<open>arith_read_walk\<close> / \<open>expr_read_walk\<close>, reduced to the two shapes the
  bug report is about. The full walk — every `IrStmt`/`IrExpr` carrier — is
  checked in `proofs/StringAccumulator/StringAccumulator.thy`.\<close>

type_synonym nm = string

datatype arith = ANum | AVar nm | ABin arith arith
  | AIndex nm arith | AAssign nm arith | AIncDec nm

datatype expr = Lit | Read nm | Arith arith | Text nm | Call "expr list"

fun arith_reads :: "arith \<Rightarrow> nm \<Rightarrow> bool" and
    expr_reads :: "expr \<Rightarrow> nm \<Rightarrow> bool"
where
  "arith_reads ANum n = False"
| "arith_reads (AVar v) n = (v = n)"
| "arith_reads (ABin a b) n = (arith_reads a n \<or> arith_reads b n)"
| "arith_reads (AIndex v k) n = (v = n \<or> arith_reads k n)"
| "arith_reads (AAssign v r) n = (v = n \<or> arith_reads r n)"
| "arith_reads (AIncDec v) n = (v = n)"
| "expr_reads Lit n = False"
| "expr_reads (Read v) n = (v = n)"
| "expr_reads (Arith a) n = arith_reads a n"
| "expr_reads (Text _) n = False"
| "expr_reads (Call es) n = list_ex (\<lambda>e. expr_reads e n) es"

text \<open>The pre-fix walk: no Arith arm at all (the \<open>_ => {}\<close> catch-all).\<close>

fun v0_expr_reads :: "expr \<Rightarrow> nm \<Rightarrow> bool" where
  "v0_expr_reads Lit n = False"
| "v0_expr_reads (Read v) n = (v = n)"
| "v0_expr_reads (Arith a) n = False"
| "v0_expr_reads (Text _) n = False"
| "v0_expr_reads (Call es) n = list_ex (\<lambda>e. v0_expr_reads e n) es"

text \<open>The bug report's witness, on the shape `n=$(( tsv + 0 ))` lowers to:\<close>

lemma the_arith_read_is_a_read:
  "expr_reads (Arith (AVar ''tsv'')) ''tsv''"
  by simp

lemma the_pre_fix_walk_missed_it:
  "\<not> v0_expr_reads (Arith (AVar ''tsv'')) ''tsv''"
  by simp

lemma a_read_nested_in_the_arith_is_found:
  "expr_reads (Arith (ABin ANum (AVar ''tsv''))) ''tsv''"
  by simp

lemma an_incdec_target_is_a_mention:
  "arith_reads (AIncDec ''tsv'') ''tsv''"
  by simp

text \<open>A read inside a call's argv (the canonical `echo "$blk"`) is found on
  both walks — the pre-fix defect is confined to the expression forms the
  catch-all swallowed.\<close>

lemma a_read_in_a_call_is_found:
  "expr_reads (Call [Text ''echo'', Read ''tsv'']) ''tsv''"
  by simp

end
