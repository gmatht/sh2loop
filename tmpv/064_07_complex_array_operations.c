#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int _sh_argc = 0; static char **_sh_argv = 0;
static char _sh_opts[] = "hB"; /* $- â option flags */
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
static void _sh_assoc_set(char **k, char **v, size_t *n, size_t cap, const char *key, const char *val) {
  if (!key) return;
  for (size_t i = 0; i < *n; i++)
    if (k[i] && strcmp(k[i], key) == 0) { v[i] = (char*)strdup(val ? val : ""); return; }
  if (*n < cap) { k[*n] = (char*)strdup(key); v[*n] = (char*)strdup(val ? val : ""); (*n)++; }
}
static void _sh_join_arr(char *d, size_t cap, char **a, size_t n) {
  size_t dn = 0;
  for (size_t i = 0; i < n; i++) {
    if (i > 0 && dn + 1 < cap) d[dn++] = ' ';
    if (!a[i]) continue;
    for (const char *s = a[i]; *s && dn + 1 < cap; s++) d[dn++] = *s;
  }
  d[dn] = 0;
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
static void _sh_arr_slice(char *d, size_t cap, const char *s, long long off, long long len) {
  const char *p = s; size_t n = 0;
  while (*p) { while (*p == ' ') p++; if (!*p) break; n++; while (*p && *p != ' ') p++; }
  long long b = off < 0 ? (long long)n + off : off;
  if (b < 0) b = 0; if (b > (long long)n) b = (long long)n;
  long long e = b + ((len < 0) ? (long long)n + len : len);
  if (e > (long long)n) e = (long long)n; if (e < b) e = b;
  size_t dn = 0, i = 0; p = s;
  while (*p && i < (size_t)e) {
    while (*p == ' ') p++;
    if (!*p) break;
    const char *w = p;
    while (*p && *p != ' ') p++;
    if (i >= (size_t)b) {
      if (dn && dn + 1 < cap) d[dn++] = ' ';
      size_t wl = (size_t)(p - w);
      if (dn + wl >= cap) wl = cap - dn - 1;
      memcpy(d + dn, w, wl); dn += wl;
    }
    i++;
  }
  d[dn] = 0;
}
static char *config_k[1024] = {0};
static char *config_v[1024] = {0};
static size_t config_n = 0;
static char *sorted[1024] = {0};
static size_t sorted_len = 0;


static char *_cap_0(void);

static char *_cap_0(void) {
  static char buf[65536];
  static char *_c0_cmd = 0; static size_t _c0_cap = 0;
  static char *_c0_wb = 0; static size_t _c0_wcap = 0;
_sh_bres(&_c0_cmd, &_c0_cap);
_sh_bword(&_c0_cmd, &_c0_cap, "sort");
_sh_badd(&_c0_cmd, &_c0_cap, " <<<");
static char _s4[65536];
_sh_join_arr(_s4, sizeof _s4, config_v, config_n);
_sh_bword(&_c0_cmd, &_c0_cap, _s4);
_sh_capture(buf, sizeof buf, _c0_cmd);
return buf;
}

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { extern int gethostname(char *, size_t); static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  setenv("BASH_VERSION", "5.2.15(1)-release", 0);
  freopen("/dev/null", "w", stderr);
  setvbuf(stdout, 0, _IONBF, 0);
    1;
    static char _s0[4096];
    snprintf(_s0, sizeof _s0, "admin");
    _sh_assoc_set(config_k, config_v, &config_n, 1024, "user", _s0);
    static char _s1[4096];
    snprintf(_s1, sizeof _s1, "localhost");
    _sh_assoc_set(config_k, config_v, &config_n, 1024, "host", _s1);
    static char _s2[4096];
    snprintf(_s2, sizeof _s2, "8080");
    _sh_assoc_set(config_k, config_v, &config_n, 1024, "port", _s2);
    {
        size_t _ai3 = 0;
        sorted[_ai3] = strdup((char*)(_cap_0()));
        sorted_len = ++_ai3;
    }
    static char _s5[65536];
    _sh_join_arr(_s5, sizeof _s5, sorted, sorted_len);
    static char _s6[65536];
    _sh_arr_slice(_s6, sizeof _s6, _s5, (int)atoll(""), (long long)1LL<<60);
    printf("Config: %s\n", ((char*)(_s6) ? (char*)(_s6) : ""));
    return 0;
}