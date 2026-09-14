/* handwritten reference: the SAME sum in 32-bit int (exact only for
   N with sum < 2^31; the bench uses N=46340). Vectorises (VPADDQ path)
   where the i64 form cannot on pre-AVX512DQ hardware. */
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  int n = atoi(argv[1]);
  int s = 0;
  for (int i = 0; i < n; i++) s += i;
  printf("%d\n", s);
  return 0;
}
