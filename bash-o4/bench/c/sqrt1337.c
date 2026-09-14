/* handwritten reference: i in 1..10000 with "1337" in i*i (strstr). */
#include <stdio.h>
#include <string.h>
int main(void) {
  char buf[32];
  for (long long i = 1; i <= 10000; i++) {
    snprintf(buf, sizeof buf, "%lld", i * i);
    if (strstr(buf, "1337")) printf("%lld\n", i);
  }
  return 0;
}
