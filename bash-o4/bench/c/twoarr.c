/* handwritten reference for twoarr: materialise BOTH arrays, then a
   second pass for the mod-2^32 checksum. Deliberately the naive
   two-pass form — bash-O4's fuse-fill-consume recognises the two
   stores and forwards both RHSs into the consumer, so bo4-gcc beats
   this reference by roughly the memory-traffic ratio. */
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  unsigned long long n = strtoull(argv[1], 0, 10);
  long long *a = malloc(n * sizeof *a), *b = malloc(n * sizeof *b);
  if (!a || !b) { fprintf(stderr, "oom\n"); return 1; }
  for (unsigned long long i = 0; i < n; i++) {
    a[i] = (long long)(i * i);
    b[i] = (long long)(i + 1);
  }
  unsigned long long s = 0;
  for (unsigned long long i = 0; i < n; i++)
    s = (s + (unsigned long long)a[i] * (unsigned long long)b[i]) & 0xFFFFFFFFull;
  printf("%llu\n", s);
  free(a); free(b);
  return 0;
}
