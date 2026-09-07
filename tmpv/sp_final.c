#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>

static int _sh_argc = 0; static char **_sh_argv = 0;
static char _sh_opts[] = "hB"; /* $- â option flags */
/* background jobs (fork-based) reaped by bare wait */
static pid_t _sh_bg_pids[512]; static size_t _sh_bg_n = 0;
typedef struct { char *p; } _sh_mstr;
static void _sh_mstr_set(_sh_mstr *v, const char *val) {
  free(v->p);
  v->p = val ? strdup(val) : NULL;
}
static const char *_sh_mstr_get(const _sh_mstr *v) {
  return (v->p) ? v->p : "";
}
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
  if (!getenv("HOSTNAME")) { extern int gethostname(char *, size_t); static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  setenv("BASH_VERSION", "5.2.15(1)-release", 0);
    assert(strlen(y) <= 16);

    char _wn_0[65536]; strncpy(_wn_0, (y ? y : ""), 65535); _wn_0[65535] = 0; char *_ws_1[1024]; size_t _wc__wn_0 = _sh_split(_wn_0, _ws_1, 1024);
    for (size_t _wi__wn_0 = 0; _wi__wn_0 < _wc__wn_0; _wi__wn_0++) {
        w = _ws_1[_wi__wn_0];
        printf("w=%s\n", ((char*)(w) ? (char*)(w) : ""));
    }
    return 0;
}