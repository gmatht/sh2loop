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
static void _sh_baddq(char **b, size_t *cap, const char *s) {
  _sh_badd(b, cap, "'");
  for (const char *p = s; *p; p++) {
    if (*p == '\'') _sh_badd(b, cap, "'\"'\"'"); else _sh_baddc(b, cap, *p);
  }
  _sh_baddc(b, cap, '\'');
}
static void _sh_assoc_init(char **b, size_t *cap, const char *name, char **k, char **v, size_t n) {
  _sh_badd(b, cap, " "); _sh_badd(b, cap, name); _sh_badd(b, cap, "=(");
  for (size_t i = 0; i < n; i++) {
    if (!k[i]) continue;
    if (i > 0) _sh_badd(b, cap, " ");
    _sh_badd(b, cap, "["); _sh_baddq(b, cap, k[i]); _sh_badd(b, cap, "]=");
    _sh_baddq(b, cap, v[i] ? v[i] : "");
  }
  _sh_badd(b, cap, ")");
}
static void _sh_assoc_set(char **k, char **v, size_t *n, size_t cap, const char *key, const char *val) {
  if (!key) return;
  for (size_t i = 0; i < *n; i++)
    if (k[i] && strcmp(k[i], key) == 0) { v[i] = (char*)strdup(val ? val : ""); return; }
  if (*n < cap) { k[*n] = (char*)strdup(key); v[*n] = (char*)strdup(val ? val : ""); (*n)++; }
}
static const char *_sh_assoc_get(char **k, char **v, size_t n, const char *key) {
  if (!key) return "";
  for (size_t i = 0; i < n; i++)
    if (k[i] && strcmp(k[i], key) == 0) return v[i] ? v[i] : "";
  return "";
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
static char *arr[1024] = {0};
static size_t arr_len = 0;
static char *map_k[1024] = {0};
static char *map_v[1024] = {0};
static size_t map_n = 0;

_sh_mstr k = {0};
_sh_mstr x = {0};

static int _sh_site_0(void);

static int _sh_site_0(void) {
_sh_reset();
_sh_add("declare -A map;");
_sh_assoc_init(&_sh_cmd, &_sh_cap, "map", map_k, map_v, map_n);
_sh_add(";");
_sh_addraw("for");
_sh_addraw("k");
_sh_addraw("in");
_sh_addraw("${!map[@]}");
_sh_addraw("; do");
_sh_word("echo");
_sh_export("k", _sh_mstr_get(&k));
_sh_addraw(" \"$k\"");
_sh_add("' => '");
_sh_add("${map[$k]}");
_sh_addraw("; done");
_sh_addraw("|");
_sh_word("sort");
  return !_sh_system_rc();
}

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { extern int gethostname(char *, size_t); static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  setenv("BASH_VERSION", "5.2.15(1)-release", 0);
  freopen("/dev/null", "w", stderr);
  setvbuf(stdout, 0, _IONBF, 0);

    (_sh_rc = 0, 1);
    (_sh_rc = 0, fputs("== Indexed arrays ==\n", stdout));
    size_t _ai0 = 0;
    arr[_ai0] = strdup((char*)("one"));
    arr_len = ++_ai0;
    arr[_ai0] = strdup((char*)("two"));
    arr_len = ++_ai0;
    arr[_ai0] = strdup((char*)("three"));
    arr_len = ++_ai0;
    (_sh_rc = 0, printf("%s\n", ((char*)(((1 < arr_len && arr[1]) ? arr[1] : "")) ? (char*)(((1 < arr_len && arr[1]) ? arr[1] : "")) : "")));
    static char _s1[32];
    snprintf(_s1, sizeof _s1, "%lld", (long long)((long long)arr_len));
    (_sh_rc = 0, printf("%s\n", ((char*)(_s1) ? (char*)(_s1) : "")));
    for (size_t _ai_arr = 0; _ai_arr < arr_len; _ai_arr++) {
        x = arr[_ai_arr];
        (_sh_rc = 0, printf("%s ", _sh_mstr_get(&x)));
    }
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("== Associative arrays ==\n", stdout));
    (_sh_rc = 0, 1);
    _sh_assoc_set(map_k, map_v, &map_n, 1024, "foo", "bar");
    _sh_assoc_set(map_k, map_v, &map_n, 1024, "answer", "42");
    static char _s2[4096];
    snprintf(_s2, sizeof _s2, "1 + 1");
    _sh_assoc_set(map_k, map_v, &map_n, 1024, "two", _s2);
    (_sh_rc = 0, printf("%s\n", ((char*)((char*)_sh_assoc_get(map_k, map_v, map_n, "foo")) ? (char*)((char*)_sh_assoc_get(map_k, map_v, map_n, "foo")) : "")));
    (_sh_rc = 0, printf("%s\n", ((char*)((char*)_sh_assoc_get(map_k, map_v, map_n, "answer")) ? (char*)((char*)_sh_assoc_get(map_k, map_v, map_n, "answer")) : "")));
    _sh_site_0();
    return 0;
}