typedef long long i64;
typedef unsigned int u32;
i64 runLoopDep(u32 n, const i64* p) { i64 acc = 0; for (u32 i = 0; i < n; i++) acc = acc * p[i & 1023] + 1; return acc; }
i64 memSum(const i64* p, u32 count) { i64 acc = 0; for (u32 i = 0; i < count; i++) acc += p[i]; return acc; }
