#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

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
static char *arr[1024] = {0};
static size_t arr_len = 0;

_sh_mstr x = {0};

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { extern int gethostname(char *, size_t); static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  setenv("BASH_VERSION", "5.2.15(1)-release", 0);

    1;
    fputs("== Indexed arrays ==\n", stdout);
    size_t _ai0 = 0;
    arr[_ai0] = strdup((char*)("one"));
    arr_len = ++_ai0;
    arr[_ai0] = strdup((char*)("two"));
    arr_len = ++_ai0;
    arr[_ai0] = strdup((char*)("three"));
    arr_len = ++_ai0;
    printf("%s\n", ((char*)(((1 < arr_len && arr[1]) ? arr[1] : "")) ? (char*)(((1 < arr_len && arr[1]) ? arr[1] : "")) : ""));
    static char _s1[32];
    snprintf(_s1, sizeof _s1, "%lld", (long long)((long long)arr_len));
    printf("%s\n", ((char*)(_s1) ? (char*)(_s1) : ""));
    for (size_t _ai_arr = 0; _ai_arr < arr_len; _ai_arr++) {
        x = arr[_ai_arr];
        printf("%s ", _sh_mstr_get(&x));
    }
    fputs("\n", stdout);
    return 0;
}