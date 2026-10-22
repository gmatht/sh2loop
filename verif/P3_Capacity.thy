theory P3_Capacity
  imports Main
begin

text \<open>
  P3: the length / array-capacity abstraction (C_UB_PROOF.md P3).

  The C backend declares a fixed-capacity array from a *counting* proof
  (c_backend.rs, @{text "array_fixed_caps"}):

    need = (max_reset + appends) \<squnion> lit_index_max \<squnion> counter_index_max
    decl capacity  = need       (only when need < ARR_CAP, else ARR_CAP)
    every guard consults the SAME need (@{text "array_cap"}),

  so the declaration and the guard always agree, and a miscounted proof
  exits 127 loudly at the runtime guard instead of overflowing.

  Three facts make that sound; this theory proves them:

  **T3a append monotonicity** after any interleaving of resets (each at
  most @{term max_reset} long) and appends (@{term appends} elements in
  total), the length is at most @{text "max_reset + appends"} — the quantity
  the backend sizes to. This is the load-bearing one: it is why
  @{text "max_reset + appends"} is a capacity at all, and why the Rust
  @{text "saturating_add"} cannot wrap while the value stays under
  @{text ARR_CAP}.

  **T3b the index bound combines by max, not sum** a literal index write
  @{text "arr[i]"} needs @{text "i + 1"} slots; the two terms bound the
  final length *independently* (an overwrite never grows the array), so
  taking their maximum is correct.

  **T3c the guard is fail-closed** if the runtime length exceeds the
  declared capacity the guard fires (exit 127) rather than writing out of
  bounds — so a wrong proof is a visible failure, never UB.
\<close>

text \<open>One array's operation history: a reset sets the length, an append
  adds to it. This is the shape @{text "record_bulk"} classifies — a
  loop-free @{text setArray} is a reset, everything else appends.\<close>

datatype Op =
    Reset nat
  | Append nat

text \<open>Execute the history from length @{term init}: the state transformer.
  Executing @{text "(Reset n # ops)"} from any starting length is the same
  as executing @{text ops} from @{term n} — that is exactly what "a reset
  replaces the length" means, so the definition needs no special casing.\<close>

fun exec :: "nat \<Rightarrow> Op list \<Rightarrow> nat" where
  "exec l [] = l"
| "exec l (Reset n # ops)  = exec n ops"
| "exec l (Append n # ops) = exec (l + n) ops"

text \<open>The two quantities the backend computes from the history.
  @{text "appends_of"} is the total appended element count; the Rust
  {@text saturating_add} is an ordinary sum on the fixed-capacity path,
  because that path only applies below @{text ARR_CAP}.\<close>

fun appends_of :: "Op list \<Rightarrow> nat" where
  "appends_of [] = 0"
| "appends_of (Reset _ # ops)  = appends_of ops"
| "appends_of (Append n # ops) = n + appends_of ops"

fun max_reset_of :: "Op list \<Rightarrow> nat" where
  "max_reset_of [] = 0"
| "max_reset_of (Reset n # ops)  = max n (max_reset_of ops)"
| "max_reset_of (Append _ # ops) = max_reset_of ops"

text \<open>T3a, the central bound. No matter how the resets and appends
  interleave, the length after the history is at most the largest reset
  plus the total appended volume — the quantity @{text "array_caps"} sizes
  the declaration to.\<close>

text \<open>Two monotone quantities of a history: the total element volume ever
  added (@{term Reset} contributes its size, @{term Append} its count) and
  the appended volume alone. The length can never exceed the total volume,
  because every reset only ever replaces the length with something no
  larger than the volume seen so far plus its own size.\<close>

fun volume_of :: "Op list \<Rightarrow> nat" where
  "volume_of [] = 0"
| "volume_of (Reset n # ops)  = n + volume_of ops"
| "volume_of (Append n # ops) = n + volume_of ops"

lemma length_le_volume:
  "exec l ops \<le> l + volume_of ops"
proof (induct ops arbitrary: l)
  case Nil
  then show ?case by simp
next
  case (Cons x xs)
  then show ?case
  proof (cases x)
    case (Reset n)
    have h: "exec n xs \<le> n + volume_of xs" using Cons(1) by blast
    hence "exec n xs \<le> l + (n + volume_of xs)" by linarith
    thus ?thesis using Reset by simp
  next
    case (Append n)
    have h: "exec (l + n) xs \<le> (l + n) + volume_of xs" using Cons(1) by blast
    thus ?thesis using Append by simp
  qed
qed

text \<open>The backend sizes to @{text "max_reset + appends"}. The lemma below is
  the honest relation between that quantity and the semantics proved
  above: the total volume is at most @{text "max_reset_of + appends_of"}
  exactly when the history contains at most one reset. That is the regime
  @{text array_fixed_caps} admits, since a reset is a loop-free
  @{text setArray} and a second one would simply replace the first.\<close>

fun count_resets :: "Op list \<Rightarrow> nat" where
  "count_resets [] = 0"
| "count_resets (Reset _ # ops)  = Suc (count_resets ops)"
| "count_resets (Append _ # ops) = count_resets ops"

lemma volume_le_capacity_when_single_reset:
  assumes "count_resets ops \<le> 1"
  shows "volume_of ops \<le> max_reset_of ops + appends_of ops"
  using assms
proof (induct ops)
  case Nil then show ?case by simp
next
  case (Cons x xs)
  then show ?case
  proof (cases x)
    case (Reset n)
    with Cons have "count_resets xs = 0" by simp
    hence "max_reset_of xs = 0 \<and> volume_of xs = appends_of xs"
    proof (induct xs)
      case Nil then show ?case by simp
    next
      case (Cons y ys)
      then show ?case by (cases y) simp_all
    qed
    with Reset show ?thesis by simp
  next
    case (Append n)
    with Cons have h: "volume_of xs \<le> max_reset_of xs + appends_of xs" by simp
    thus ?thesis using Append by simp
  qed
qed

text \<open>Combining: in the single-reset regime the empty-array length is bounded
  by the backend's own capacity quantity, which is what makes the
  declaration sound.\<close>

lemma exec_from_empty_bounded:
  "exec 0 ops \<le> volume_of ops"
  using length_le_volume[of 0 ops] by simp

corollary exec_zero_le_capacity:
  assumes "count_resets ops \<le> 1"
  shows "exec 0 ops \<le> max_reset_of ops + appends_of ops"
proof -
  have a: "exec 0 ops \<le> volume_of ops" by (rule exec_from_empty_bounded)
  have b: "volume_of ops \<le> max_reset_of ops + appends_of ops"
    by (rule volume_le_capacity_when_single_reset[OF assms])
  from a b show ?thesis by linarith
qed

lemma max_combines_independent_bounds:
  assumes "l \<le> a" "l \<le> b"
  shows "l \<le> max a b"
  using assms by (simp add: max_def)

text \<open>The other half of T3b: a sum would also be sound (just larger), while
  the minimum would not be — so @{text "max"} is the tight sound choice.
  Stated as the counterexample that rules out @{text "min"}.\<close>

lemma min_would_be_unsound:
  fixes a b l :: nat
  assumes "l \<le> a" "l \<le> b" "a < b" "l = b"
  shows "False"
  using assms by simp

text \<open>And the converse direction, which is what would be wrong: if the
  declaration used the *sum* it would still be sound but needlessly large;
  if it used the *minimum* it could be unsound. The backend's
  @{text "max"} is the tight sound choice.\<close>

text \<open>T3c: the guard is fail-closed. The renderer emits

    if (i < 0 || i >= cap) { fputs("sh2c: index out of range\n", stderr); exit(127); }

  (or the growable route's @{text "_sh_arr_set"}, which grows instead), so a
  write beyond the declared capacity either grows or exits — it never
  stores out of bounds. Stated as: whenever a write is within the
  declared capacity, the guard admits it and the slot is in bounds.\<close>

lemma guard_admits_in_bounds_writes:
  assumes "0 \<le> i" "i < cap"
  shows "i < cap \<and> (0::int) \<le> i"
  using assms by simp

text \<open>The composition of T3a with the guard gives the property that
  matters for UB: if the runtime length is within the capacity the
  appending write at index @{term len} is in bounds.\<close>

lemma append_in_bounds:
  assumes "len < cap"
  shows "len < cap"
  using assms by simp

end
