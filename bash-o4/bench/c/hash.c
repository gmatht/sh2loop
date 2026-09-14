/* handwritten reference: per-record mix, accumulator mod 256.
   All values stay small; i64 keeps it bash-faithful. */
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  long long n = atoll(argv[1]);
  long long s = 0;
  for (long long i = 0; i < n; i++) {
    long long a = (i * 53) % 256, b = (i * 89) % 256;
    s = (s + a * 31 + b * 17) % 256;
  }
  printf("%lld\n", s);
  return 0;
}
