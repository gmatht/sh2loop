#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <assert.h>

static int _sh_argc = 0; static char **_sh_argv = 0;
static char _sh_opts[] = "hB"; /* $- â option flags */
/* background jobs (fork-based) reaped by bare wait */
static pid_t _sh_bg_pids[512]; static size_t _sh_bg_n = 0;
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
  for (int i = 0; i < _sh_argc; i++) need += (_sh_argv[i] ? strlen(_sh_argv[i]) : 0) * 6 + 4;
  _sh_grow(&_sh_wrap, &_sh_wrapcap, need);
  char *p = _sh_wrap; strcpy(p, "bash -c '"); p += 9;
  for (const char *c = cmd; *c; c++) {
if (*c == '\'') { memcpy(p, "'\"'\"'", 5); p += 5; }
    else *p++ = *c;
  }
  *p++ = '\''; *p = 0;
  for (int i = 0; i < _sh_argc; i++) {
    if (!_sh_argv[i]) continue;
*p++ = ' '; *p++ = '\'';
    for (const char *a = _sh_argv[i]; *a; a++) {
if (*a == '\'') { memcpy(p, "'\"'\"'", 5); p += 5; }
      else *p++ = *a;
    }
*p++ = '\'';
  }
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
/* split a captured string on IFS whitespace into words */
static void _sh_export(const char *name, const char *val) {
  setenv(name, val ? val : "", 1);
}
/* `read` builtin: one line from stdin into a static buffer */
char* n = NULL;
const char text[10] = "a b  c\\nd";
char* w = NULL;

static char *_cap_0(void);
static char *_cap_1(void);

static char *_cap_0(void) {
  static char buf[65536];
  static char *_c0_cmd = 0; static size_t _c0_cap = 0;
  static char *_c0_wb = 0; static size_t _c0_wcap = 0;
_sh_bres(&_c0_cmd, &_c0_cap);
_sh_bword(&_c0_cmd, &_c0_cap, "printf");
_sh_bword(&_c0_cmd, &_c0_cap, "%s");
_sh_export("text", (text ? text : ""));
_sh_badd(&_c0_cmd, &_c0_cap, " \"$text\"");
_sh_badd(&_c0_cmd, &_c0_cap, " |");
_sh_bword(&_c0_cmd, &_c0_cap, "wc");
_sh_bword(&_c0_cmd, &_c0_cap, "-w");
_sh_capture(buf, sizeof buf, _c0_cmd);
return buf;
}

static char *_cap_1(void) {
  static char buf[65536];
  static char *_c1_cmd = 0; static size_t _c1_cap = 0;
  static char *_c1_wb = 0; static size_t _c1_wcap = 0;
_sh_bres(&_c1_cmd, &_c1_cap);
_sh_bword(&_c1_cmd, &_c1_cap, "wc");
_sh_bword(&_c1_cmd, &_c1_cap, "-w");
_sh_badd(&_c1_cmd, &_c1_cap, " <<<");
_sh_export("text", (text ? text : ""));
_sh_badd(&_c1_cmd, &_c1_cap, " \"$text\"");
_sh_capture(buf, sizeof buf, _c1_cmd);
return buf;
}

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  freopen("/dev/null", "w", stderr);
  setvbuf(stdout, 0, _IONBF, 0);
    assert(strlen(text) <= 9);

    n = strdup(_cap_0());
    printf("words=%s\n", ((char*)(n) ? (char*)(n) : ""));
    w = strdup(_cap_1());
    printf("direct=%s\n", ((char*)(w) ? (char*)(w) : ""));
    return 0;
}