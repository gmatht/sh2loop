typedef long long i64;
typedef unsigned long long u64;
typedef unsigned int u32;

i64 f_add(u64 a, u64 b) { return a + b; }
i64 f_sub(u64 a, u64 b) { return a - b; }
i64 f_mul(u64 a, u64 b) { return a * b; }
i64 f_sll(u64 a, u32 s) { return a << s; }
i64 f_srl(u64 a, u32 s) { return a >> s; }      /* unsigned */
i64 f_sra(i64 a, u32 s) { return a >> s; }      /* signed */
i64 f_and(u64 a, u64 b) { return a & b; }
i64 f_or(u64 a, u64 b) { return a | b; }
i64 f_xor(u64 a, u64 b) { return a ^ b; }
i64 f_neg(i64 a) { return -a; }
i64 f_not(i64 a) { return ~a; }
i64 f_mixed(u64 a, u64 b, u32 s) { return (a + b) * 3 - (a << s) ^ (b >> (s & 31)); }
u32 f_lt(u64 a, u64 b) { return a < b; }
u32 f_ge(i64 a, i64 b) { return a >= b; }
u32 f_eq(u64 a, u64 b) { return a == b; }
i64 f_loop_mul(u32 n) { i64 r = 1; for (u32 i = 0; i < n; i++) r = r * 7 - 3; return r; }
i64 f_loop_mixed(u32 n) { i64 s = 0; for (u32 i = 0; i < n; i++) { if (i & 1) s += i * i; else s -= i * 2; } return s; }
i64 f_carry_add(u32 n) { u64 acc = 0xFFFFFFFF00000000ull; for (u32 i = 0; i < n; i++) acc += 1; return acc; }
i64 f_borrow_sub(u32 n) { i64 acc = -0x7FFFFFFFFFFFFFFFll - 1; for (u32 i = 0; i < n; i++) acc -= 1; return acc; }
i64 f_while(i64 n) { i64 s = 0, i = 0; while (i < n) { s += i; i++; } return s; }
