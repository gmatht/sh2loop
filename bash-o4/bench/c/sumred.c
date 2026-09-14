/* handwritten reference: mod-2^32 accumulate of i*i (exact in 64-bit;
   matches bash `s=$(( (s + (i*i)%4294967296) % 4294967296 ))`). */
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  unsigned long long n = strtoull(argv[1], 0, 10), s = 0;
  for (unsigned long long i = 0; i < n; i++)
    s = (s + (i * i & 0xFFFFFFFFull)) & 0xFFFFFFFFull;
  printf("%llu\n", s);
  return 0;
}
