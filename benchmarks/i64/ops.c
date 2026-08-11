// i64 ops compiled to wasm for the benchmark.
#include <stdint.h>

typedef long long i64;
typedef unsigned long long u64;

i64 add64(i64 a, i64 b) { return a + b; }
i64 mul64(i64 a, i64 b) { return a * b; }
i64 sub64(i64 a, i64 b) { return a - b; }

// acc = acc*3 + 1, n iterations, entirely inside wasm.
i64 runLoop(uint32_t n) {
  i64 acc = 0;
  for (uint32_t i = 0; i < n; i++) acc = acc * 3 + 1;
  return acc;
}

// sum `count` i64s at memory offset ptr (bytes).
i64 memSum(const i64* p, uint32_t count) {
  i64 acc = 0;
  for (uint32_t i = 0; i < count; i++) acc += p[i];
  return acc;
}

// add `addend` to each of `count` i64s in place.
void memAdd(i64* p, uint32_t count, i64 addend) {
  for (uint32_t i = 0; i < count; i++) p[i] += addend;
}

// hi/lo split add: out[0]=lo32, out[1]=hi32 of (a+b).
void addSplit(int32_t alo, int32_t ahi, int32_t blo, int32_t bhi, int32_t* out) {
  u64 a = (u64)(uint32_t)ahi << 32 | (uint32_t)alo;
  u64 b = (u64)(uint32_t)bhi << 32 | (uint32_t)blo;
  u64 r = a + b;
  out[0] = (int32_t)(uint32_t)(r & 0xFFFFFFFFull);
  out[1] = (int32_t)(uint32_t)(r >> 32);
}

// a single i64 add through memory (values at offsets, result at out).
void memAddAt(uint32_t ao, uint32_t bo, uint32_t out) {
  *(i64*)(out) = *(i64*)(ao) + *(i64*)(bo);
}

// hi/lo split mul: out[0]=lo32, out[1]=hi32 of (a*b).
void mulSplit(int32_t alo, int32_t ahi, int32_t blo, int32_t bhi, int32_t* out) {
  u64 a = (u64)(uint32_t)ahi << 32 | (uint32_t)alo;
  u64 b = (u64)(uint32_t)bhi << 32 | (uint32_t)blo;
  u64 r = a * b;
  out[0] = (int32_t)(uint32_t)(r & 0xFFFFFFFFull);
  out[1] = (int32_t)(uint32_t)(r >> 32);
}

// data-dependent variant: multiplier comes from memory, so no closed form.
i64 runLoopDep(uint32_t n, const i64* p) {
  i64 acc = 0;
  for (uint32_t i = 0; i < n; i++) acc = acc * p[i & 1023] + 1;
  return acc;
}
