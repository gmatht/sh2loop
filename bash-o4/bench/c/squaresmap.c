/* handwritten reference: materialise out[i]=i*i, then mod-2^32 checksum
   (the fair CPU counterpart to a GPU map+readback: same memory traffic). */
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  unsigned long long n = strtoull(argv[1], 0, 10);
  long long *out = malloc(n * sizeof *out);
  if (!out) { fprintf(stderr, "oom\n"); return 1; }
  for (unsigned long long i = 0; i < n; i++) out[i] = (long long)(i * i);
  unsigned long long s = 0;
  for (unsigned long long i = 0; i < n; i++)
    s = (s + (unsigned long long)out[i]) & 0xFFFFFFFFull;
  printf("%llu\n", s);
  free(out);
  return 0;
}
