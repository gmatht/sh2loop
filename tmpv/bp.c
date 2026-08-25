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
static void _sh_grow(char **b, size_t *cap, size_t need) {
  if (need <= *cap) return;
  *cap = need * 2; *b = (char*)realloc(*b, *cap);
}
static void _sh_badd(char **b, size_t *cap, const char *s) {
  size_t l = *b ? strlen(*b) : 0, n = strlen(s);
  _sh_grow(b, cap, l + n + 1);
  memcpy(*b + l, s, n + 1);
}
static void _sh_baddc(char **b, size_t *cap, char c) {
  size_t l = *b ? strlen(*b) : 0;
  _sh_grow(b, cap, l + 2);
  (*b)[l] = c; (*b)[l + 1] = 0;
}
static void _sh_bres(char **b, size_t *cap) { _sh_grow(b, cap, 1); (*b)[0] = 0; }
static void _sh_bword(char **b, size_t *cap, const char *s) {
  _sh_badd(b, cap, " '");
  for (const char *p = s; *p; p++) {
    if (*p == '\'') _sh_badd(b, cap, "'\"'\"'"); else _sh_baddc(b, cap, *p);
  }
  _sh_baddc(b, cap, '\'');
}
static void _sh_wrap_cmd(const char *cmd) {
  size_t n = strlen(cmd), need = n * 2 + 16;
  _sh_grow(&_sh_wrap, &_sh_wrapcap, need);
  char *p = _sh_wrap; strcpy(p, "bash -c '"); p += 9;
  for (const char *c = cmd; *c; c++) {
    if (*c == '\'') { memcpy(p, "'\"'\"'", 5); p += 5; }
    else *p++ = *c;
  }
  *p++ = '\''; *p = 0;
}
static void _sh_capture(char *buf, size_t cap, const char *cmd) {
  if (!cmd || !*cmd) { buf[0] = 0; return; }
  _sh_wrap_cmd(cmd);
  FILE *p = popen(_sh_wrap, "r");
  if (!p) { buf[0] = 0; return; }
  size_t n = fread(buf, 1, cap - 1, p); buf[n] = 0;
  int rc = pclose(p);
  while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\r')) buf[--n] = 0;
}
/* string-var ++/-- â function-call boundaries are sequence
   points, so two mutations in one expression stay ordered */
char* r = NULL;

static char *_cap_0(void);

static char *_cap_0(void) {
  static char buf[65536];
  static char *_c0_cmd = 0; static size_t _c0_cap = 0;
  static char *_c0_wb = 0; static size_t _c0_wcap = 0;
_sh_bres(&_c0_cmd, &_c0_cap);
_sh_bword(&_c0_cmd, &_c0_cap, "getval");
_sh_bword(&_c0_cmd, &_c0_cap, "foo");
_sh_capture(buf, sizeof buf, _c0_cmd);
return buf;
}

static void getval(void);

static void getval(void) {
    printf("result=%s\n", ((char*)(((1 < _sh_argc && _sh_argv[1]) ? _sh_argv[1] : "")) ? (char*)(((1 < _sh_argc && _sh_argv[1]) ? _sh_argv[1] : "")) : ""));
}

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { extern int gethostname(char *, size_t); static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  setenv("BASH_VERSION", "5.2.15(1)-release", 0);
  freopen("/dev/null", "w", stderr);
  setvbuf(stdout, 0, _IONBF, 0);

    r = strdup(_cap_0());
    printf("%s\n", ((char*)(r) ? (char*)(r) : ""));
    return 0;
}