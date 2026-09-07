#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

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
static void _sh_addraw(const char *s) { _sh_add(" "); _sh_add(s); }
/* buffer-parameterized variants (capture sites' private buffers) */
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
static void _sh_export(const char *name, const char *val) {
  setenv(name, val ? val : "", 1);
}
/* `read` builtin: one line from stdin into a static buffer */
_sh_mstr gid = {0};
char* home = NULL;
_sh_mstr info = {0};
_sh_mstr pass = {0};
_sh_mstr shell = {0};
char* uid = NULL;
char* user = NULL;

static int _sh_site_0(void);

static int _sh_site_0(void) {
_sh_reset();
_sh_addraw("while");
_sh_add(" IFS=:");
_sh_word("read");
_sh_word("-r");
_sh_word("user");
_sh_word("pass");
_sh_word("uid");
_sh_word("gid");
_sh_word("info");
_sh_word("home");
_sh_word("shell");
_sh_addraw("; do");
_sh_addraw("if");
_sh_export("uid", (uid ? uid : ""));
_sh_export("uid", (uid ? uid : ""));
_sh_addraw("[ \"$uid\" -gt 1000 ]");
_sh_addraw("&&");
_sh_export("shell", _sh_mstr_get(&shell));
_sh_export("shell", _sh_mstr_get(&shell));
_sh_addraw("[ \"$shell\" != \"/bin/false\" ]");
_sh_addraw("; then");
_sh_addraw("if");
_sh_export("home", (home ? home : ""));
_sh_export("home", (home ? home : ""));
_sh_export("home", (home ? home : ""));
_sh_addraw("[ \"$home\" = ~^/home/ ]");
_sh_addraw("; then");
_sh_word("echo");
_sh_word("User: ");
_sh_export("user", (user ? user : ""));
_sh_add("\"$user\"");
_sh_add("' (UID: '");
_sh_export("uid", (uid ? uid : ""));
_sh_add("\"$uid\"");
_sh_add("') - '");
_sh_export("home", (home ? home : ""));
_sh_add("\"$home\"");
_sh_addraw("; fi");
_sh_addraw("; fi");
_sh_addraw("; done");
_sh_addraw("0<");
_sh_word("/etc/passwd");
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