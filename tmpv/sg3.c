#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>

/* shell-out runtime: build a command line, run it via bash -c */
static int _sh_rc = 0;
static int _sh_argc = 0; static char **_sh_argv = 0;
static char _sh_opts[] = "hB"; /* $- — option flags */
/* background jobs (fork-based) reaped by bare wait */
static pid_t _sh_bg_pids[512]; static size_t _sh_bg_n = 0;
typedef struct { char *p; } sh2_str;
static const char *sh2_str_get(const sh2_str *v) {
  return (v->p) ? v->p : "";
}
static char *_sh_cmd = 0; static size_t _sh_cap = 0;
static char *_sh_wb = 0; static size_t _sh_wcap = 0;
static char *_sh_wrap = 0; static size_t _sh_wrapcap = 0;
static void _sh_grow(char **b, size_t *cap, size_t need) {
  if (need <= *cap) return;
  *cap = need * 2; *b = (char*)realloc(*b, *cap);
}
static void _sh_add(const char *s) {
  size_t l = _sh_cmd ? strlen(_sh_cmd) : 0, n = strlen(s);
  _sh_grow(&_sh_cmd, &_sh_cap, l + n + 1);
  memcpy(_sh_cmd + l, s, n + 1);
}
static void _sh_addc(char c) {
  size_t l = _sh_cmd ? strlen(_sh_cmd) : 0;
  _sh_grow(&_sh_cmd, &_sh_cap, l + 2);
  _sh_cmd[l] = c; _sh_cmd[l + 1] = 0;
}
static void _sh_reset(void) { _sh_grow(&_sh_cmd, &_sh_cap, 1); _sh_cmd[0] = 0; }
static void _sh_word(const char *s) {
  _sh_add(" '");
  for (const char *p = s; *p; p++) {
    if (*p == '\'') _sh_add("'\"'\"'"); else _sh_addc(*p);
  }
  _sh_addc('\'');
}
/* append raw text (no quoting) - for already-shell-safe pieces */
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
static int _sh_system_rc(void) {
  _sh_wrap_cmd(_sh_cmd ? _sh_cmd : "");
  int rc = system(_sh_wrap);
  _sh_rc = (rc == -1) ? 127 : (WIFEXITED(rc) ? WEXITSTATUS(rc) : 1);
  return _sh_rc;
}

static int _sh_site_0(void);

static int _sh_site_0(void) {
_sh_reset();
_sh_word("tmpv/sg.sh");
  return !_sh_system_rc();
}

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { extern int gethostname(char *, size_t); static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  setenv("BASH_VERSION", "5.2.15(1)-release", 0);
  freopen("/dev/null", "w", stderr);
  setvbuf(stdout, 0, _IONBF, 0);
    _sh_site_0();
    return 0;
}