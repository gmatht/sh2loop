#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

static int _sh_argc = 0; static char **_sh_argv = 0;
static char _sh_opts[] = "hB"; /* $- â option flags */
/* background jobs (fork-based) reaped by bare wait */
static pid_t _sh_bg_pids[512]; static size_t _sh_bg_n = 0;
static char *_sh_cmd = 0; static size_t _sh_cap = 0;
static char *_sh_wb = 0; static size_t _sh_wcap = 0;
static char *_sh_wrap = 0; static size_t _sh_wrapcap = 0;
static size_t _sh_split(char *buf, char **words, size_t max) {
  size_t n = 0; char *p = buf;
  while (*p) {
    while (*p == ' ' || *p == '\t' || *p == '\n') p++;
    if (!*p) break;
    if (n >= max) break;
    words[n++] = p;
    while (*p && *p != ' ' && *p != '\t' && *p != '\n') p++;
    if (*p) *p++ = 0;
  }
  return n;
}
/* export a var value so `$name` in a bash -c child sees it */
char* w = NULL;
const char y[17] = "alpha beta gamma";

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
    assert(strlen(y) <= 16);

    char *_ws_0[1024]; size_t _wc__ws_0 = _sh_split(y, _ws_0, 1024);
    for (size_t _wi__wl_1 = 0; _wi__wl_1 < _wc__ws_0; _wi__wl_1++) {
        w = _ws_0[_wi__wl_1];
        printf("w=%s\n", ((char*)(w) ? (char*)(w) : ""));
    }
    return 0;
}