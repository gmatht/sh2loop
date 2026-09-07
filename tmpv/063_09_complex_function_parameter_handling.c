#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
#include <fnmatch.h>

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
static void _sh_reset(void) { _sh_grow(&_sh_cmd, &_sh_cap, 1); _sh_cmd[0] = 0; }
static void _sh_addraw(const char *s) { _sh_add(" "); _sh_add(s); }
/* buffer-parameterized variants (capture sites' private buffers) */
static const char *_sh_arr_get(char **a, size_t len, long long i) {
  if (i < 0 || i >= (long long)len || !a[i]) return "";
  return a[i];
}
static void _sh_assoc_set(char **k, char **v, size_t *n, size_t cap, const char *key, const char *val) {
  if (!key) return;
  for (size_t i = 0; i < *n; i++)
    if (k[i] && strcmp(k[i], key) == 0) { v[i] = (char*)strdup(val ? val : ""); return; }
  if (*n < cap) { k[*n] = (char*)strdup(key); v[*n] = (char*)strdup(val ? val : ""); (*n)++; }
}
static char *_sh_argv_join(char *d, size_t cap) {
  d[0] = 0; size_t n = 0;
  for (int i = 1; i < _sh_argc; i++) {
    if (i > 1 && n + 1 < cap) d[n++] = ' ';
    const char *s = _sh_argv[i];
    while (s && *s && n + 1 < cap) d[n++] = *s++;
  }
  d[n] = 0; return d;
}
/* ${@:off:len} — positional-param slice (off is 1-based; off 0 includes $0) */
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
static char *args[1024] = {0};
static size_t args_len = 0;
static char *options_k[1024] = {0};
static char *options_v[1024] = {0};
static size_t options_n = 0;

char* flags = NULL;
char* j = NULL;
char* key = NULL;
char* value = NULL;
char* i = NULL;

static int _sh_site_1(void);
static int _sh_site_0(void);
static int _sh_site_3(void);
static int _sh_site_2(void);

static int _sh_site_1(void) {
_sh_export("i", (i ? i : ""));
_sh_reset();
_sh_addraw("(( i < ${#args[@]} ))");
  return !_sh_system_rc();
}

static int _sh_site_0(void) {
return (_sh_site_1());
  return !_sh_system_rc();
}

static int _sh_site_3(void) {
_sh_export("j", (j ? j : ""));
_sh_export("flags", (flags ? flags : ""));
_sh_reset();
_sh_addraw("(( j < ${#flags} ))");
  return !_sh_system_rc();
}

static int _sh_site_2(void) {
return (_sh_site_3());
  return !_sh_system_rc();
}

static void complex_function(void);

static void complex_function(void) {
    size_t _ai3 = 0;
    static char _s4[4096];
    _sh_argv_join(_s4, sizeof _s4);
    args[_ai3] = strdup((char*)(_s4));
    args_len = ++_ai3;
    (_sh_rc = 0, 1);
    (_sh_rc = 0, 1);
i = "0";
    { int _went = 0;
    while (_sh_site_0()) {
        _went = 1;
        if (fnmatch("--*", (char*)_sh_arr_get(args, args_len, (long long)atoll((i ? i : ""))), 0) == 0) {
            key = (char*)_sh_arr_get(args, args_len, (long long)atoll((i ? i : "")));
            (_sh_rc = 0, 1);
            value = (char*)_sh_arr_get(args, args_len, (long long)atoll((i ? i : ""))+1);
            (_sh_rc = 0, 1);
            _sh_assoc_set(options_k, options_v, &options_n, 1024, "$key", (value ? value : ""));
            {
                long long _sq5 = (atoll((i ? i : "")) + (2));
                { static char _wb6[32]; snprintf(_wb6, sizeof _wb6, "%lld", (long long)(_sq5)); i = _wb6; }
                _sh_rc = !((_sq5) != 0);
            }
        }
        else if (fnmatch("-*", (char*)_sh_arr_get(args, args_len, (long long)atoll((i ? i : ""))), 0) == 0) {
            flags = (char*)_sh_arr_get(args, args_len, (long long)atoll((i ? i : "")));
            (_sh_rc = 0, 1);
            j = strdup((char*)("0"));
            { int _went = 0;
            while (_sh_site_2()) {
                _went = 1;
                static char _s7[4096];
                snprintf(_s7, sizeof _s7, "true");
                _sh_assoc_set(options_k, options_v, &options_n, 1024, "${flags:j:1}", _s7);
                {
                    long long _sq8 = atoll((j ? j : ""));
                    { static char _wb9[32]; snprintf(_wb9, sizeof _wb9, "%lld", (long long)((_sq8 + 1))); j = _wb9; }
                    _sh_rc = !((_sq8) != 0);
                }
            }
            if (!_went) { _sh_rc = 0; }
            }
            {
                long long _sq10 = atoll((i ? i : ""));
                { static char _wb11[32]; snprintf(_wb11, sizeof _wb11, "%lld", (long long)((_sq10 + 1))); i = _wb11; }
                _sh_rc = !((_sq10) != 0);
            }
        }
        else if (fnmatch("*", (char*)_sh_arr_get(args, args_len, (long long)atoll((i ? i : ""))), 0) == 0) {
            break;
        }
        else {
            /* no default */
        }
    }
    if (!_went) { _sh_rc = 0; }
    }
    static char _s12[32];
    snprintf(_s12, sizeof _s12, "%lld", (long long)((long long)options_n));
    (_sh_rc = 0, printf("Processed %s options\n", ((char*)(_s12) ? (char*)(_s12) : "")));
}

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { extern int gethostname(char *, size_t); static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  setenv("BASH_VERSION", "5.2.15(1)-release", 0);
  freopen("/dev/null", "w", stderr);
  setvbuf(stdout, 0, _IONBF, 0);

    char *_sh_av0[4];
    _sh_av0[0] = "complex_function";
    _sh_av0[1] = "--flag1";
    _sh_av0[2] = "--option1=value1";
    _sh_av0[3] = "-abc";
    char **_sh_sv1 = _sh_argv; int _sh_sc2 = _sh_argc;
    _sh_argv = _sh_av0; _sh_argc = 4;
    (complex_function(), _sh_argv = _sh_sv1, _sh_argc = _sh_sc2, _sh_rc == 0);
    return 0;
}