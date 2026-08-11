typedef long long i64;
typedef unsigned int u32;
i64 pow3(u32 n) { i64 r = 1; for (u32 i = 0; i < n; i++) r = r * 3; return r; }
i64 sumN(u32 n) { i64 s = 0; for (u32 i = 0; i < n; i++) s += i; return s; }
