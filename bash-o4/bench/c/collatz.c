/* handwritten reference: branchy Collatz step counts (unvectorisable). */
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  long long n = atoll(argv[1]);
  long long total = 0;
  for (long long k = 0; k < n; k++) {
    long long v = (k * 37 + 3) % 251;
    long long s = 0;
    while (v > 1) { v = (v % 2 == 0) ? v / 2 : 3 * v + 1; s++; }
    total += s;
  }
  printf("%lld\n", total);
  return 0;
}
