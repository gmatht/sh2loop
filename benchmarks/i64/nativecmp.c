// Native comparison: tcc (single-pass, ~no optimization) vs clang -O3.
#include <stdint.h>
#include <stdio.h>
#include <time.h>

typedef long long i64;

volatile i64 sink;

// data-dependent chain — can't be strength-reduced by any compiler.
i64 loop_dep(uint32_t n, const i64* p) {
  i64 acc = 0;
  for (uint32_t i = 0; i < n; i++) acc = acc * p[i & 1023] + 1;
  return acc;
}

i64 mem_sum(const i64* p, uint32_t count) {
  i64 acc = 0;
  for (uint32_t i = 0; i < count; i++) acc += p[i];
  return acc;
}

static double now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec * 1e3 + ts.tv_nsec / 1e6;
}

int main(void) {
  enum { N = 100000000, M = 1000000 };
  static i64 p[1024], buf[1000000];
  for (int i = 0; i < 1024; i++) p[i] = (i % 5) + 1;
  for (int i = 0; i < M; i++) buf[i] = i;

  // warmup
  loop_dep(1000000, p); mem_sum(buf, M);

  double t0 = now_ms();
  i64 r1 = loop_dep(N, p);
  double t1 = now_ms();
  i64 r2 = mem_sum(buf, M);
  double t2 = now_ms();

  printf("loop_dep(100M): %.3f ms  (%.3f ns/iter)  result %lld\n", t1 - t0, (t1 - t0) * 1e6 / N, (long long)r1);
  printf("mem_sum(1M):    %.3f ms  (%.3f ns/elem)  result %lld\n", t2 - t1, (t2 - t1) * 1e6 / M, (long long)r2);
  sink = r1 + r2;
  return 0;
}
