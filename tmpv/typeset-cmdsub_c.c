#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
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
static void _sh_arr_set(char **a, size_t *len, size_t cap, long long i, const char *v) {
  if (i < 0 || i >= (long long)cap || !v) return;
  a[i] = (char*)strdup(v);
  if ((size_t)(i + 1) > *len) *len = (size_t)(i + 1);
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
static int _sh_system_rc(void) {
  _sh_wrap_cmd(_sh_cmd ? _sh_cmd : "");
  int rc = system(_sh_wrap);
  _sh_rc = (rc == -1) ? 127 : (WIFEXITED(rc) ? WEXITSTATUS(rc) : 1);
  return _sh_rc;
}
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
static char *arr[1024] = {0};
static size_t arr_len = 0;
static char *assoc_k[1024] = {0};
static char *assoc_v[1024] = {0};
static size_t assoc_n = 0;
static char *singlearr[1024] = {0};
static size_t singlearr_len = 0;

_sh_mstr _n = {0};
char comb[7] = "";
char comb2[8] = "";
char* global_var = NULL;
char lc[13] = "";
char* myexport = NULL;
char n[6] = "";
char original[18] = "";
char* plain = NULL;
char* printtest = NULL;
char ref[16] = "";
char* rovar = NULL;
_sh_mstr tracetest = {0};
char uc[13] = "";

static int _sh_site_0(void);
static int _sh_site_1(void);

static int _sh_site_0(void) {
_sh_reset();
_sh_word("env");
_sh_addraw("|");
_sh_word("grep");
_sh_word("^myexport=");
  return !_sh_system_rc();
}

static int _sh_site_1(void) {
_sh_reset();
_sh_word("unset");
_sh_word("-n");
_sh_word("ref");
_sh_addraw("2>");
_sh_word("/dev/null");
  return !_sh_system_rc();
}

static void myfunc(void);
static void set_global(void);

static void myfunc(void) {
    (_sh_rc = 0, fputs("Inside myfunc\n", stdout));
    char* x = "5";
    (_sh_rc = 0, printf("x=%s\n", ((char*)((x ? x : "")) ? (char*)((x ? x : "")) : "")));
}
static void set_global(void) {
    static char _s19[4096];
    snprintf(_s19, sizeof _s19, "I am global");
    global_var = _s19;
    (_sh_rc = 0, 1);
}

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { extern int gethostname(char *, size_t); static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  setenv("BASH_VERSION", "5.2.15(1)-release", 0);
  freopen("/dev/null", "w", stderr);
  setvbuf(stdout, 0, _IONBF, 0);
    assert(strlen(comb) <= 6);
    assert(strlen(comb2) <= 7);
    assert(strlen(lc) <= 12);
    assert(strlen(n) <= 5);
    assert(strlen(original) <= 17);
    assert(strlen(ref) <= 15);
    assert(strlen(uc) <= 12);

    (_sh_rc = 0, fputs("=== typeset -i (integer attribute) ===\n", stdout));
    n[0] = '\0';
    (_sh_rc = 0, 1);
    assert(strlen((char*)("42")) <= 5);
    strncpy(n, (char*)("42"), 5 + 1);
    n[5] = '\0';
    (_sh_rc = 0, 1);
    (_sh_rc = 0, printf("After 'typeset -i n=42': n='%s'\n", ((char*)((n ? n : "")) ? (char*)((n ? n : "")) : "")));
    assert(strlen((char*)("n+1")) <= 5);
    strncpy(n, (char*)("n+1"), 5 + 1);
    n[5] = '\0';
    (_sh_rc = 0, printf("After 'n=n+1':          n='%s' (integer arithmetic applied)\n", ((char*)((n ? n : "")) ? (char*)((n ? n : "")) : "")));
    static char _s0[4096];
    snprintf(_s0, sizeof _s0, "hello");
    assert(strlen((char*)(_s0)) <= 5);
    strncpy(n, (char*)(_s0), 5 + 1);
    n[5] = '\0';
    (_sh_rc = 0, printf("After 'n=\"hello\"':     n='%s' (assigns 0; non-numeric string becomes 0)\n", ((char*)((n ? n : "")) ? (char*)((n ? n : "")) : "")));
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== typeset -r (readonly attribute) ===\n", stdout));
    rovar = "";
    (_sh_rc = 0, 1);
    static char _s1[4096];
    snprintf(_s1, sizeof _s1, "immutable");
    rovar = _s1;
    (_sh_rc = 0, 1);
    (_sh_rc = 0, printf("After 'typeset -r rovar=immutable': rovar='%s'\n", ((char*)((rovar ? rovar : "")) ? (char*)((rovar ? rovar : "")) : "")));
    (_sh_rc = 0, fputs("(Attempting 'rovar=change' would cause an error; skipped for safety.)\n", stdout));
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== typeset -l (lowercase attribute) ===\n", stdout));
    lc[0] = '\0';
    (_sh_rc = 0, 1);
    static char _s2[4096];
    snprintf(_s2, sizeof _s2, "HELLO WORLD");
    assert(strlen((char*)(_s2)) <= 12);
    strncpy(lc, (char*)(_s2), 12 + 1);
    lc[12] = '\0';
    (_sh_rc = 0, 1);
    (_sh_rc = 0, printf("After 'typeset -l lc=\"HELLO WORLD\"': lc='%s'\n", ((char*)((lc ? lc : "")) ? (char*)((lc ? lc : "")) : "")));
    static char _s3[4096];
    snprintf(_s3, sizeof _s3, "ANOTHER TEST");
    assert(strlen((char*)(_s3)) <= 12);
    strncpy(lc, (char*)(_s3), 12 + 1);
    lc[12] = '\0';
    (_sh_rc = 0, printf("After 'lc=\"ANOTHER TEST\"':           lc='%s'\n", ((char*)((lc ? lc : "")) ? (char*)((lc ? lc : "")) : "")));
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== typeset -u (uppercase attribute) ===\n", stdout));
    uc[0] = '\0';
    (_sh_rc = 0, 1);
    static char _s4[4096];
    snprintf(_s4, sizeof _s4, "hello world");
    assert(strlen((char*)(_s4)) <= 12);
    strncpy(uc, (char*)(_s4), 12 + 1);
    uc[12] = '\0';
    (_sh_rc = 0, 1);
    (_sh_rc = 0, printf("After 'typeset -u uc=\"hello world\"': uc='%s'\n", ((char*)((uc ? uc : "")) ? (char*)((uc ? uc : "")) : "")));
    static char _s5[4096];
    snprintf(_s5, sizeof _s5, "another test");
    assert(strlen((char*)(_s5)) <= 12);
    strncpy(uc, (char*)(_s5), 12 + 1);
    uc[12] = '\0';
    (_sh_rc = 0, printf("After 'uc=\"another test\"':            uc='%s'\n", ((char*)((uc ? uc : "")) ? (char*)((uc ? uc : "")) : "")));
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== typeset -x (export attribute) ===\n", stdout));
    myexport = "";
    (_sh_rc = 0, 1);
    static char _s6[4096];
    snprintf(_s6, sizeof _s6, "exported_value");
    myexport = _s6;
    (_sh_rc = 0, 1);
    (_sh_rc = 0, fputs("After 'typeset -x myexport=exported_value'\n", stdout));
    (_sh_rc = 0, fputs("Variable is exported:\n", stdout));
    { int _t7 = (_sh_site_0());
      _sh_rc = _t7 ? 0 : 1;
      if (!_t7) {
        (_sh_rc = 0, fputs("(myexport not found in env — possible scope issue)\n", stdout));
      }
    }
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== typeset -a (indexed array) ===\n", stdout));
    arr_len = 0;
    (_sh_rc = 0, 1);
    size_t _ai8 = 0;
    arr[_ai8] = strdup((char*)("10"));
    arr_len = ++_ai8;
    arr[_ai8] = strdup((char*)("20"));
    arr_len = ++_ai8;
    arr[_ai8] = strdup((char*)("30"));
    arr_len = ++_ai8;
    (_sh_rc = 0, 1);
    static char _s9[65536];
    _sh_join_arr(_s9, sizeof _s9, arr, arr_len);
    static char _s10[65536];
    _sh_arr_slice(_s10, sizeof _s10, _s9, (int)atoll(""), (long long)1LL<<60);
    (_sh_rc = 0, printf("After 'typeset -a arr=(10 20 30)': arr=(%s)\n", ((char*)(_s10) ? (char*)(_s10) : "")));
    (_sh_rc = 0, printf("arr[0]='%s' arr[1]='%s' arr[2]='%s'\n", ((char*)(((0 < arr_len && arr[0]) ? arr[0] : "")) ? (char*)(((0 < arr_len && arr[0]) ? arr[0] : "")) : ""), ((char*)(((1 < arr_len && arr[1]) ? arr[1] : "")) ? (char*)(((1 < arr_len && arr[1]) ? arr[1] : "")) : ""), ((char*)(((2 < arr_len && arr[2]) ? arr[2] : "")) ? (char*)(((2 < arr_len && arr[2]) ? arr[2] : "")) : "")));
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== typeset -A (associative array) ===\n", stdout));
    assoc_n = 0;
    (_sh_rc = 0, 1);
    _sh_assoc_set(assoc_k, assoc_v, &assoc_n, 1024, "[key1]=value1", "[key2]=value2");
    (_sh_rc = 0, 1);
    (_sh_rc = 0, fputs("After 'typeset -A assoc=([key1]=value1 [key2]=value2)'\n", stdout));
    (_sh_rc = 0, printf("assoc[key1]='%s'  assoc[key2]='%s'\n", ((char*)((char*)_sh_assoc_get(assoc_k, assoc_v, assoc_n, "key1")) ? (char*)((char*)_sh_assoc_get(assoc_k, assoc_v, assoc_n, "key1")) : ""), ((char*)((char*)_sh_assoc_get(assoc_k, assoc_v, assoc_n, "key2")) ? (char*)((char*)_sh_assoc_get(assoc_k, assoc_v, assoc_n, "key2")) : "")));
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== typeset -n (name reference) ===\n", stdout));
    original[0] = '\0';
    ref[0] = '\0';
    (_sh_rc = 0, 1);
    static char _s11[4096];
    snprintf(_s11, sizeof _s11, "I am the original");
    assert(strlen((char*)(_s11)) <= 17);
    strncpy(original, (char*)(_s11), 17 + 1);
    original[17] = '\0';
    assert(strlen((char*)("original")) <= 15);
    strncpy(ref, (char*)("original"), 15 + 1);
    ref[15] = '\0';
    (_sh_rc = 0, 1);
    (_sh_rc = 0, fputs("After 'typeset -n ref=original':\n", stdout));
    (_sh_rc = 0, printf("original='%s'\n", ((char*)((original ? original : "")) ? (char*)((original ? original : "")) : "")));
    (_sh_rc = 0, printf("ref='%s'\n", ((char*)((ref ? ref : "")) ? (char*)((ref ? ref : "")) : "")));
    static char _s12[4096];
    snprintf(_s12, sizeof _s12, "Changed via ref");
    assert(strlen((char*)(_s12)) <= 15);
    strncpy(ref, (char*)(_s12), 15 + 1);
    ref[15] = '\0';
    (_sh_rc = 0, fputs("After 'ref=\"Changed via ref\"':\n", stdout));
    (_sh_rc = 0, printf("original='%s'\n", ((char*)((original ? original : "")) ? (char*)((original ? original : "")) : "")));
    (_sh_rc = 0, printf("ref='%s'\n", ((char*)((ref ? ref : "")) ? (char*)((ref ? ref : "")) : "")));
    _sh_site_1();
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== typeset -f (display function definition) ===\n", stdout));
    (_sh_rc = 0, fputs("Output of 'typeset -f myfunc':\n", stdout));
    setenv("myfunc", (getenv("myfunc") ? getenv("myfunc") : "") ? (getenv("myfunc") ? getenv("myfunc") : "") : "", 1);
    (_sh_rc = 0, 1);
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== typeset -F (list function names) ===\n", stdout));
    setenv("myfunc", (getenv("myfunc") ? getenv("myfunc") : "") ? (getenv("myfunc") ? getenv("myfunc") : "") : "", 1);
    (_sh_rc = 0, 1);
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== typeset -g (global scope in function) ===\n", stdout));
    char *_sh_av13[2];
    _sh_av13[0] = "set_global";
    char **_sh_sv14 = _sh_argv; int _sh_sc15 = _sh_argc;
    _sh_argv = _sh_av13; _sh_argc = 1;
    (set_global(), _sh_argv = _sh_sv14, _sh_argc = _sh_sc15, _sh_rc == 0);
    (_sh_rc = 0, printf("After set_global(): global_var='%s'\n", ((char*)((global_var ? global_var : "")) ? (char*)((global_var ? global_var : "")) : "")));
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== typeset -t (trace attribute) ===\n", stdout));
    tracetest = "traced";
    (_sh_rc = 0, 1);
    (_sh_rc = 0, fputs("After 'typeset -t tracetest=traced': (trace attribute set)\n", stdout));
    (_sh_rc = 0, printf("tracetest='%s'\n", ((char*)(_sh_mstr_get(&tracetest)) ? (char*)(_sh_mstr_get(&tracetest)) : "")));
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== typeset -p (print attribute info) ===\n", stdout));
    printtest = "";
    (_sh_rc = 0, 1);
    printtest = "99";
    (_sh_rc = 0, 1);
    setenv("printtest", (printtest ? printtest : "") ? (printtest ? printtest : "") : "", 1);
    (_sh_rc = 0, 1);
    (_sh_rc = 0, fputs("After 'typeset -i -r printtest=99':\n", stdout));
    setenv("printtest", (printtest ? printtest : "") ? (printtest ? printtest : "") : "", 1);
    (_sh_rc = 0, 1);
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== combined: typeset -il (integer + lowercase) ===\n", stdout));
    comb[0] = '\0';
    (_sh_rc = 0, 1);
    assert(strlen((char*)("42")) <= 6);
    strncpy(comb, (char*)("42"), 6 + 1);
    comb[6] = '\0';
    (_sh_rc = 0, 1);
    (_sh_rc = 0, printf("After 'typeset -il comb=42': comb='%s' (integer + lowercase)\n", ((char*)((comb ? comb : "")) ? (char*)((comb ? comb : "")) : "")));
    assert(strlen((char*)("comb+1")) <= 6);
    strncpy(comb, (char*)("comb+1"), 6 + 1);
    comb[6] = '\0';
    (_sh_rc = 0, printf("After 'comb=comb+1':    comb='%s' (integer arithmetic active)\n", ((char*)((comb ? comb : "")) ? (char*)((comb ? comb : "")) : "")));
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== combined: typeset -iu (integer + uppercase) ===\n", stdout));
    comb2[0] = '\0';
    (_sh_rc = 0, 1);
    assert(strlen((char*)("99")) <= 7);
    strncpy(comb2, (char*)("99"), 7 + 1);
    comb2[7] = '\0';
    (_sh_rc = 0, 1);
    (_sh_rc = 0, printf("After 'typeset -iu comb2=99': comb2='%s' (integer + uppercase)\n", ((char*)((comb2 ? comb2 : "")) ? (char*)((comb2 ? comb2 : "")) : "")));
    assert(strlen((char*)("comb2+1")) <= 7);
    strncpy(comb2, (char*)("comb2+1"), 7 + 1);
    comb2[7] = '\0';
    (_sh_rc = 0, printf("After 'comb2=comb2+1': comb2='%s' (integer arithmetic active)\n", ((char*)((comb2 ? comb2 : "")) ? (char*)((comb2 ? comb2 : "")) : "")));
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== typeset -a (indexed array, individual element) ===\n", stdout));
    singlearr_len = 0;
    (_sh_rc = 0, 1);
    (_sh_rc = 0, 1);
    static char _s16[4096];
    snprintf(_s16, sizeof _s16, "first");
    _sh_arr_set(singlearr, &singlearr_len, 1024, 0, _s16);
    static char _s17[4096];
    snprintf(_s17, sizeof _s17, "second");
    _sh_arr_set(singlearr, &singlearr_len, 1024, 1, _s17);
    (_sh_rc = 0, printf("singlearr[0]='%s'  singlearr[1]='%s'\n", ((char*)(((0 < singlearr_len && singlearr[0]) ? singlearr[0] : "")) ? (char*)(((0 < singlearr_len && singlearr[0]) ? singlearr[0] : "")) : ""), ((char*)(((1 < singlearr_len && singlearr[1]) ? singlearr[1] : "")) ? (char*)(((1 < singlearr_len && singlearr[1]) ? singlearr[1] : "")) : "")));
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== typeset (no flag) ===\n", stdout));
    plain = "";
    (_sh_rc = 0, 1);
    static char _s18[4096];
    snprintf(_s18, sizeof _s18, "just a string");
    plain = _s18;
    (_sh_rc = 0, 1);
    (_sh_rc = 0, printf("After 'typeset plain=\"just a string\"': plain='%s'\n", ((char*)((plain ? plain : "")) ? (char*)((plain ? plain : "")) : "")));
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("=== Demonstration complete. ===\n", stdout));
    return 0;
}