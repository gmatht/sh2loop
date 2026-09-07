#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>

/* shell-out runtime: build a command line, run it via bash -c */
static int _sh_rc = 0;
static int _sh_argc = 0; static char **_sh_argv = 0;
static char _sh_opts[] = "hB"; /* $- — option flags */
/* background jobs (fork-based) reaped by bare wait */
static pid_t _sh_bg_pids[512]; static size_t _sh_bg_n = 0;
#define SH2_ARENA_CAP (256 * 1024)
typedef struct { char buf[SH2_ARENA_CAP]; size_t used; } _sh_arena;
static char *_sh_adup(_sh_arena *a, const char *s) {
  size_t n = strlen(s) + 1;
  if (a->used + n > SH2_ARENA_CAP) return strdup(s);
  char *r = a->buf + a->used; memcpy(r, s, n); a->used += n; return r;
}
static void _sh_arena_reset(_sh_arena *a) { a->used = 0; }
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
char msg[6] = "";

static void f(void);
static void g(void);

static void f(void) {
    static char _s3[4096];
    snprintf(_s3, sizeof _s3, "inner");
    assert(strlen((char*)(_s3)) <= 5);
    strncpy(msg, (char*)(_s3), 5 + 1);
    msg[5] = '\0';
    (_sh_rc = 0, 1);
    (_sh_rc = 0, printf("%s\n", ((char*)(msg) ? (char*)(msg) : "")));
}
static void g(void) {
    static char _s4[4096];
    snprintf(_s4, sizeof _s4, "outer");
    assert(strlen((char*)(_s4)) <= 5);
    strncpy(msg, (char*)(_s4), 5 + 1);
    msg[5] = '\0';
    (_sh_rc = 0, 1);
    char *_sh_av5[2];
    _sh_av5[0] = "f";
    char **_sh_sv6 = _sh_argv; int _sh_sc7 = _sh_argc;
    _sh_argv = _sh_av5; _sh_argc = 1;
    (f(), _sh_argv = _sh_sv6, _sh_argc = _sh_sc7, _sh_rc == 0);
    (_sh_rc = 0, printf("%s\n", ((char*)(msg) ? (char*)(msg) : "")));
}

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { extern int gethostname(char *, size_t); static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  setenv("BASH_VERSION", "5.2.15(1)-release", 0);
    assert(strlen(msg) <= 5);

    char *_sh_av0[2];
    _sh_av0[0] = "g";
    char **_sh_sv1 = _sh_argv; int _sh_sc2 = _sh_argc;
    _sh_argv = _sh_av0; _sh_argc = 1;
    (g(), _sh_argv = _sh_sv1, _sh_argc = _sh_sc2, _sh_rc == 0);
    return 0;
}