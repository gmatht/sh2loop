#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <fnmatch.h>
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
static char *_sh_replace(char *d, size_t cap, const char *s, const char *pat, const char *repl) {
  size_t pn = strlen(pat), rn = strlen(repl), dn = 0;
  const char *p = s;
  if (!pn) { strncpy(d, s, cap - 1); d[cap - 1] = 0; return d; }
  while (*p) {
    const char *hit = strstr(p, pat);
    if (!hit) break;
    size_t pre = (size_t)(hit - p);
    while (pre-- && dn + 1 < cap) d[dn++] = *p++;
    for (size_t i = 0; i < rn && dn + 1 < cap; i++) d[dn++] = repl[i];
    p = hit + pn;
  }
  while (*p && dn + 1 < cap) d[dn++] = *p++;
  d[dn] = 0;
  return d;
}
/* FIRST match only â bash ${var/pat/repl} */
static char *_sh_strippre(char *d, size_t cap, const char *s, const char *pat, int greedy) {
  static char sc[65536];
  strncpy(sc, s, sizeof sc - 1); sc[sizeof sc - 1] = 0;
  size_t n = strlen(sc), best = 0;
  for (size_t i = 0; i <= n; i++) {
    char c = sc[i]; sc[i] = 0;
    if (fnmatch(pat, sc, 0) == 0) best = i;
    sc[i] = c;
    if (!greedy && best) break;
  }
  strncpy(d, sc + best, cap - 1); d[cap - 1] = 0;
  return d;
}
/* ${s%pat}/${s%%pat} suffix strip (the pattern matches a SUFFIX) */
static char *_sh_stripsuf(char *d, size_t cap, const char *s, const char *pat, int greedy) {
  static char sc[65536];
  strncpy(sc, s, sizeof sc - 1); sc[sizeof sc - 1] = 0;
  size_t n = strlen(sc), best = n;
  if (greedy) {
    for (size_t i = n; i > 0; i--) {
      if (fnmatch(pat, sc + (n - i), 0) == 0) { best = n - i; break; }
    }
  } else {
    for (size_t i = 1; i <= n; i++) {
      if (fnmatch(pat, sc + (n - i), 0) == 0) { best = n - i; break; }
    }
  }
  if (best > cap - 1) best = cap - 1;
  strncpy(d, sc, best); d[best] = 0;
  return d;
}

_sh_mstr maybe = {0};
const char name[6] = "world";
const char path[34] = "/tmp/013_param_expansion_file.txt";
const char s2[5] = "abba";
const char var[12] = "hello world";

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { extern int gethostname(char *, size_t); static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  setenv("BASH_VERSION", "5.2.15(1)-release", 0);
    assert(strlen(name) <= 5);
    assert(strlen(path) <= 33);
    assert(strlen(s2) <= 4);
    assert(strlen(var) <= 11);

    1;
    fputs("== Case modification in parameter expansion ==\n", stdout);
    static char _s0[4096];
    { char *_u = (name ? name : ""); size_t _i; for (_i = 0; _u[_i]; _i++) _s0[_i] = (char)toupper((unsigned char)_u[_i]); _s0[_i] = 0; }
    printf("%s\n", ((char*)(_s0) ? (char*)(_s0) : ""));
    static char _s1[4096];
    { char *_u = (name ? name : ""); size_t _i; for (_i = 0; _u[_i]; _i++) _s1[_i] = (char)tolower((unsigned char)_u[_i]); _s1[_i] = 0; }
    printf("%s\n", ((char*)(_s1) ? (char*)(_s1) : ""));
    static char _s2[4096];
    { char *_u = (name ? name : ""); strncpy(_s2, _u, 4095); _s2[4095] = 0; if (_s2[0]) _s2[0] = (char)toupper((unsigned char)_s2[0]); }
    printf("%s\n", ((char*)(_s2) ? (char*)(_s2) : ""));
    fputs("== Advanced parameter expansion ==\n", stdout);
    static char _s3[4096];
    { const char *_u = (path ? path : ""); const char *_s = strrchr(_u, '/'); strncpy(_s3, _s ? _s + 1 : _u, 4095); _s3[4095] = 0; }
    printf("%s\n", ((char*)(_s3) ? (char*)(_s3) : ""));
    static char _s4[4096];
    { const char *_u = (path ? path : ""); const char *_s = strrchr(_u, '/'); size_t _n = _s ? (size_t)(_s - _u) : 0; if (_n == 0 && _s) _n = 1; strncpy(_s4, _u, _n); _s4[_n] = 0; }
    printf("%s\n", ((char*)(_s4) ? (char*)(_s4) : ""));
    static char _s5[4096];
    _sh_replace(_s5, sizeof _s5, (s2 ? s2 : ""), "b", "X");
    printf("%s\n", ((char*)(_s5) ? (char*)(_s5) : ""));
    fputs("== More parameter expansion ==\n", stdout);
    static char _s6[4096];
    _sh_strippre(_s6, sizeof _s6, (var ? var : ""), "hello", 0);
    printf("%s\n", ((char*)(_s6) ? (char*)(_s6) : ""));
    static char _s7[4096];
    _sh_stripsuf(_s7, sizeof _s7, (var ? var : ""), "world", 0);
    printf("%s\n", ((char*)(_s7) ? (char*)(_s7) : ""));
    static char _s8[4096];
    _sh_replace(_s8, sizeof _s8, (var ? var : ""), "o", "0");
    printf("%s\n", ((char*)(_s8) ? (char*)(_s8) : ""));
    fputs("== Default values ==\n", stdout);
    maybe = "";
    1;
    printf("%s\n", ((char*)((((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : ("default"))) ? (char*)((((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : ("default"))) : ""));
    printf("%s\n", ((char*)((maybe = (((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : ("default")), (((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : ("default")))) ? (char*)((maybe = (((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : ("default")), (((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : ("default")))) : ""));
    printf("%s\n", ((char*)((((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : (fprintf(stderr, "%s\n", "error"), exit(1), (char*)0))) ? (char*)((((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : (fprintf(stderr, "%s\n", "error"), exit(1), (char*)0))) : ""));
    return 0;
}