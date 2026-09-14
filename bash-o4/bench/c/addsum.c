/* handwritten reference: scalar i64 accumulation (bash-faithful). */
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  long long n = atoll(argv[1]);
  long long s = 0;
  for (long long i = 0; i < n; i++) s += i;
  printf("%lld\n", s);
  return 0;
}
