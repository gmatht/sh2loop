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
static void _sh_capture(char *buf, size_t cap, const char *cmd) {
  if (!cmd || !*cmd) { buf[0] = 0; _sh_rc = 0; return; }
  _sh_wrap_cmd(cmd);
  FILE *p = popen(_sh_wrap, "r");
  if (!p) { buf[0] = 0; _sh_rc = 127; return; }
  size_t n = fread(buf, 1, cap - 1, p); buf[n] = 0;
  int rc = pclose(p);
  _sh_rc = (rc == -1) ? 127 : (WIFEXITED(rc) ? WEXITSTATUS(rc) : 1);
  while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\r')) buf[--n] = 0;
}
/* string-var ++/-- — function-call boundaries are sequence
   points, so two mutations in one expression stay ordered */
static void _sh_export(const char *name, const char *val) {
  setenv(name, val ? val : "", 1);
}
/* `read` builtin: one line from stdin into a static buffer */
const unsigned int RC = 0;
char* ec = NULL;
char* label = NULL;
char* tmp_stderr = NULL;
char* tmp_stdout = NULL;

static char *_cap_0(void);
static char *_cap_1(void);
static char *_cap_3(void);
static char *_cap_4(void);
static int _sh_site_2(void);
static int _sh_site_5(void);

static char *_cap_0(void) {
  static char buf[65536];
  static char *_c0_cmd = 0; static size_t _c0_cap = 0;
  static char *_c0_wb = 0; static size_t _c0_wcap = 0;
_sh_bres(&_c0_cmd, &_c0_cap);
_sh_bword(&_c0_cmd, &_c0_cap, "mktemp");
_sh_bword(&_c0_cmd, &_c0_cap, "/tmp/id_demo_stdout_XXXXXX");
_sh_capture(buf, sizeof buf, _c0_cmd);
return buf;
}

static char *_cap_1(void) {
  static char buf[65536];
  static char *_c1_cmd = 0; static size_t _c1_cap = 0;
  static char *_c1_wb = 0; static size_t _c1_wcap = 0;
_sh_bres(&_c1_cmd, &_c1_cap);
_sh_bword(&_c1_cmd, &_c1_cap, "mktemp");
_sh_bword(&_c1_cmd, &_c1_cap, "/tmp/id_demo_stderr_XXXXXX");
_sh_capture(buf, sizeof buf, _c1_cmd);
return buf;
}

static char *_cap_3(void) {
  static char buf[65536];
  static char *_c3_cmd = 0; static size_t _c3_cap = 0;
  static char *_c3_wb = 0; static size_t _c3_wcap = 0;
_sh_bres(&_c3_cmd, &_c3_cap);
_sh_bword(&_c3_cmd, &_c3_cap, "cat");
_sh_export("tmp_stdout", (tmp_stdout ? tmp_stdout : ""));
_sh_badd(&_c3_cmd, &_c3_cap, " \"$tmp_stdout\"");
_sh_capture(buf, sizeof buf, _c3_cmd);
return buf;
}

static char *_cap_4(void) {
  static char buf[65536];
  static char *_c4_cmd = 0; static size_t _c4_cap = 0;
  static char *_c4_wb = 0; static size_t _c4_wcap = 0;
_sh_bres(&_c4_cmd, &_c4_cap);
_sh_bword(&_c4_cmd, &_c4_cap, "cat");
_sh_export("tmp_stderr", (tmp_stderr ? tmp_stderr : ""));
_sh_badd(&_c4_cmd, &_c4_cap, " \"$tmp_stderr\"");
_sh_capture(buf, sizeof buf, _c4_cmd);
return buf;
}

static int _sh_site_2(void) {
_sh_reset();
{ for (int _qi = 1; _qi < _sh_argc; _qi++) { const char *_qa = _sh_argv[_qi] ? _sh_argv[_qi] : ""; _sh_add(" '"); for (const char *_qp = _qa; *_qp; _qp++) { if (*_qp == 39) _sh_add("'\"'\"'"); else _sh_addc(*_qp); } _sh_add("'"); } }
_sh_addraw(">");
_sh_export("tmp_stdout", (tmp_stdout ? tmp_stdout : ""));
_sh_addraw("\"$tmp_stdout\"");
_sh_addraw("2>");
_sh_export("tmp_stderr", (tmp_stderr ? tmp_stderr : ""));
_sh_addraw("\"$tmp_stderr\"");
  return !_sh_system_rc();
}

static int _sh_site_5(void) {
_sh_reset();
_sh_word("rm");
_sh_word("-f");
_sh_export("tmp_stdout", (tmp_stdout ? tmp_stdout : ""));
_sh_addraw("\"$tmp_stdout\"");
_sh_export("tmp_stderr", (tmp_stderr ? tmp_stderr : ""));
_sh_addraw("\"$tmp_stderr\"");
  return !_sh_system_rc();
}

static void capture(void);

static void capture(void) {
    label = ((1 < _sh_argc && _sh_argv[1]) ? _sh_argv[1] : "");
    (_sh_rc = 0, 1);
    { long long _sn = 1; if (_sn < 0) _sn = 0; if (_sn > (long long)(_sh_argc - 1)) _sn = _sh_argc - 1; for (long long _si = 1; _si + _sn < _sh_argc; _si++) _sh_argv[_si] = _sh_argv[_si + _sn]; _sh_argc -= (int)_sn; _sh_rc = 0; (_sh_rc == 0); };
    {
        tmp_stdout = NULL;
        tmp_stderr = NULL;
    }
    _sh_mstr_set(&tmp_stdout, _cap_0());
    _sh_mstr_set(&tmp_stderr, _cap_1());
    _sh_site_2();
    static char _s105[32];
    snprintf(_s105, sizeof _s105, "%lld", (long long)(_sh_rc));
    ec = _s105;
    (_sh_rc = 0, 1);
    char* so = NULL;
    _sh_mstr_set(&so, _cap_3());
    char* se = NULL;
    _sh_mstr_set(&se, _cap_4());
    _sh_site_5();
    (_sh_rc = 0, printf("--- [%s] ---\n", ((char*)((label ? label : "")) ? (char*)((label ? label : "")) : "")));
    static char _s106[4096];
    _sh_argv_join(_s106, sizeof _s106);
    (_sh_rc = 0, printf("  cmd     : %s\n", ((char*)(_s106) ? (char*)(_s106) : "")));
    (_sh_rc = 0, printf("  exitcode: %s\n", ((char*)((ec ? ec : "")) ? (char*)((ec ? ec : "")) : "")));
    if ((((so ? so : "")) && ((so ? so : ""))[0])) {
        (_sh_rc = 0, printf("  stdout  : %s\n", ((char*)((so ? so : "")) ? (char*)((so ? so : "")) : "")));
    }
    if ((((se ? se : "")) && ((se ? se : ""))[0])) {
        (_sh_rc = 0, printf("  stderr  : %s\n", ((char*)((se ? se : "")) ? (char*)((se ? se : "")) : "")));
    }
    (_sh_rc = 0, fputs("\n", stdout));
    _sh_rc = (int)atoll((ec ? ec : ""));
    return;
}

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { extern int gethostname(char *, size_t); static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  setenv("BASH_VERSION", "5.2.15(1)-release", 0);
  freopen("/dev/null", "w", stderr);
  setvbuf(stdout, 0, _IONBF, 0);

    (_sh_rc = 0, 1);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 1: 'id' (default — current process)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av0[3];
    _sh_av0[0] = "capture";
    static char _s2[4096];
    snprintf(_s2, sizeof _s2, "01-default");
    _sh_av0[1] = _s2;
    _sh_av0[2] = "id";
    char **_sh_sv1 = _sh_argv; int _sh_sc3 = _sh_argc;
    _sh_argv = _sh_av0; _sh_argc = 3;
    (capture(), _sh_argv = _sh_sv1, _sh_argc = _sh_sc3, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 2: id -u  (effective user ID, numeric)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av4[4];
    _sh_av4[0] = "capture";
    static char _s6[4096];
    snprintf(_s6, sizeof _s6, "02-u");
    _sh_av4[1] = _s6;
    _sh_av4[2] = "id";
    _sh_av4[3] = "-u";
    char **_sh_sv5 = _sh_argv; int _sh_sc7 = _sh_argc;
    _sh_argv = _sh_av4; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv5, _sh_argc = _sh_sc7, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 3: id -g  (effective group ID, numeric)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av8[4];
    _sh_av8[0] = "capture";
    static char _s10[4096];
    snprintf(_s10, sizeof _s10, "03-g");
    _sh_av8[1] = _s10;
    _sh_av8[2] = "id";
    _sh_av8[3] = "-g";
    char **_sh_sv9 = _sh_argv; int _sh_sc11 = _sh_argc;
    _sh_argv = _sh_av8; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv9, _sh_argc = _sh_sc11, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 4: id -G  (all group IDs, numeric)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av12[4];
    _sh_av12[0] = "capture";
    static char _s14[4096];
    snprintf(_s14, sizeof _s14, "04-G");
    _sh_av12[1] = _s14;
    _sh_av12[2] = "id";
    _sh_av12[3] = "-G";
    char **_sh_sv13 = _sh_argv; int _sh_sc15 = _sh_argc;
    _sh_argv = _sh_av12; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv13, _sh_argc = _sh_sc15, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 5: id -un  (effective user name)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av16[4];
    _sh_av16[0] = "capture";
    static char _s18[4096];
    snprintf(_s18, sizeof _s18, "05-un");
    _sh_av16[1] = _s18;
    _sh_av16[2] = "id";
    _sh_av16[3] = "-un";
    char **_sh_sv17 = _sh_argv; int _sh_sc19 = _sh_argc;
    _sh_argv = _sh_av16; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv17, _sh_argc = _sh_sc19, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 6: id -gn  (effective group name)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av20[4];
    _sh_av20[0] = "capture";
    static char _s22[4096];
    snprintf(_s22, sizeof _s22, "06-gn");
    _sh_av20[1] = _s22;
    _sh_av20[2] = "id";
    _sh_av20[3] = "-gn";
    char **_sh_sv21 = _sh_argv; int _sh_sc23 = _sh_argc;
    _sh_argv = _sh_av20; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv21, _sh_argc = _sh_sc23, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 7: id -Gn  (all group names)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av24[4];
    _sh_av24[0] = "capture";
    static char _s26[4096];
    snprintf(_s26, sizeof _s26, "07-Gn");
    _sh_av24[1] = _s26;
    _sh_av24[2] = "id";
    _sh_av24[3] = "-Gn";
    char **_sh_sv25 = _sh_argv; int _sh_sc27 = _sh_argc;
    _sh_argv = _sh_av24; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv25, _sh_argc = _sh_sc27, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 8: id -ru  (real user ID, numeric)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av28[4];
    _sh_av28[0] = "capture";
    static char _s30[4096];
    snprintf(_s30, sizeof _s30, "08-ru");
    _sh_av28[1] = _s30;
    _sh_av28[2] = "id";
    _sh_av28[3] = "-ru";
    char **_sh_sv29 = _sh_argv; int _sh_sc31 = _sh_argc;
    _sh_argv = _sh_av28; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv29, _sh_argc = _sh_sc31, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 9: id -rg  (real group ID, numeric)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av32[4];
    _sh_av32[0] = "capture";
    static char _s34[4096];
    snprintf(_s34, sizeof _s34, "09-rg");
    _sh_av32[1] = _s34;
    _sh_av32[2] = "id";
    _sh_av32[3] = "-rg";
    char **_sh_sv33 = _sh_argv; int _sh_sc35 = _sh_argc;
    _sh_argv = _sh_av32; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv33, _sh_argc = _sh_sc35, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 10: id -rG  (real group IDs, numeric)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av36[4];
    _sh_av36[0] = "capture";
    static char _s38[4096];
    snprintf(_s38, sizeof _s38, "10-rG");
    _sh_av36[1] = _s38;
    _sh_av36[2] = "id";
    _sh_av36[3] = "-rG";
    char **_sh_sv37 = _sh_argv; int _sh_sc39 = _sh_argc;
    _sh_argv = _sh_av36; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv37, _sh_argc = _sh_sc39, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 11: id -run  (real user name)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av40[4];
    _sh_av40[0] = "capture";
    static char _s42[4096];
    snprintf(_s42, sizeof _s42, "11-run");
    _sh_av40[1] = _s42;
    _sh_av40[2] = "id";
    _sh_av40[3] = "-run";
    char **_sh_sv41 = _sh_argv; int _sh_sc43 = _sh_argc;
    _sh_argv = _sh_av40; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv41, _sh_argc = _sh_sc43, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 12: id -rgn  (real group name)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av44[4];
    _sh_av44[0] = "capture";
    static char _s46[4096];
    snprintf(_s46, sizeof _s46, "12-rgn");
    _sh_av44[1] = _s46;
    _sh_av44[2] = "id";
    _sh_av44[3] = "-rgn";
    char **_sh_sv45 = _sh_argv; int _sh_sc47 = _sh_argc;
    _sh_argv = _sh_av44; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv45, _sh_argc = _sh_sc47, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 13: id -rGn  (real group names)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av48[4];
    _sh_av48[0] = "capture";
    static char _s50[4096];
    snprintf(_s50, sizeof _s50, "13-rGn");
    _sh_av48[1] = _s50;
    _sh_av48[2] = "id";
    _sh_av48[3] = "-rGn";
    char **_sh_sv49 = _sh_argv; int _sh_sc51 = _sh_argc;
    _sh_argv = _sh_av48; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv49, _sh_argc = _sh_sc51, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 14: id -u -n  (separate options, equivalent to -un)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av52[5];
    _sh_av52[0] = "capture";
    static char _s54[4096];
    snprintf(_s54, sizeof _s54, "14-u-n");
    _sh_av52[1] = _s54;
    _sh_av52[2] = "id";
    _sh_av52[3] = "-u";
    _sh_av52[4] = "-n";
    char **_sh_sv53 = _sh_argv; int _sh_sc55 = _sh_argc;
    _sh_argv = _sh_av52; _sh_argc = 5;
    (capture(), _sh_argv = _sh_sv53, _sh_argc = _sh_sc55, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 15: id -r -u  (separate options, equivalent to -ru)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av56[5];
    _sh_av56[0] = "capture";
    static char _s58[4096];
    snprintf(_s58, sizeof _s58, "15-r-u");
    _sh_av56[1] = _s58;
    _sh_av56[2] = "id";
    _sh_av56[3] = "-r";
    _sh_av56[4] = "-u";
    char **_sh_sv57 = _sh_argv; int _sh_sc59 = _sh_argc;
    _sh_argv = _sh_av56; _sh_argc = 5;
    (capture(), _sh_argv = _sh_sv57, _sh_argc = _sh_sc59, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 16: id -G -z  (group IDs delimited by NUL)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av60[5];
    _sh_av60[0] = "capture";
    static char _s62[4096];
    snprintf(_s62, sizeof _s62, "16-Gz");
    _sh_av60[1] = _s62;
    _sh_av60[2] = "bash";
    _sh_av60[3] = "-c";
    _sh_av60[4] = "id -G -z | cat -v";
    char **_sh_sv61 = _sh_argv; int _sh_sc63 = _sh_argc;
    _sh_argv = _sh_av60; _sh_argc = 5;
    (capture(), _sh_argv = _sh_sv61, _sh_argc = _sh_sc63, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 17: id -Gn -z  (group names delimited by NUL)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av64[5];
    _sh_av64[0] = "capture";
    static char _s66[4096];
    snprintf(_s66, sizeof _s66, "17-Gnz");
    _sh_av64[1] = _s66;
    _sh_av64[2] = "bash";
    _sh_av64[3] = "-c";
    _sh_av64[4] = "id -Gn -z | cat -v";
    char **_sh_sv65 = _sh_argv; int _sh_sc67 = _sh_argc;
    _sh_argv = _sh_av64; _sh_argc = 5;
    (capture(), _sh_argv = _sh_sv65, _sh_argc = _sh_sc67, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 18: id -un -z  (user name with NUL terminator)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av68[5];
    _sh_av68[0] = "capture";
    static char _s70[4096];
    snprintf(_s70, sizeof _s70, "18-unz");
    _sh_av68[1] = _s70;
    _sh_av68[2] = "bash";
    _sh_av68[3] = "-c";
    _sh_av68[4] = "id -un -z | cat -v";
    char **_sh_sv69 = _sh_argv; int _sh_sc71 = _sh_argc;
    _sh_argv = _sh_av68; _sh_argc = 5;
    (capture(), _sh_argv = _sh_sv69, _sh_argc = _sh_sc71, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 19: id -Z  (security context — may not be available)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av72[4];
    _sh_av72[0] = "capture";
    static char _s74[4096];
    snprintf(_s74, sizeof _s74, "19-Z");
    _sh_av72[1] = _s74;
    _sh_av72[2] = "id";
    _sh_av72[3] = "-Z";
    char **_sh_sv73 = _sh_argv; int _sh_sc75 = _sh_argc;
    _sh_argv = _sh_av72; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv73, _sh_argc = _sh_sc75, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 20: id root  (default output for user 'root')\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av76[4];
    _sh_av76[0] = "capture";
    static char _s78[4096];
    snprintf(_s78, sizeof _s78, "20-root");
    _sh_av76[1] = _s78;
    _sh_av76[2] = "id";
    _sh_av76[3] = "root";
    char **_sh_sv77 = _sh_argv; int _sh_sc79 = _sh_argc;
    _sh_argv = _sh_av76; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv77, _sh_argc = _sh_sc79, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 21: id -u root  (numeric UID of root)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av80[5];
    _sh_av80[0] = "capture";
    static char _s82[4096];
    snprintf(_s82, sizeof _s82, "21-u-root");
    _sh_av80[1] = _s82;
    _sh_av80[2] = "id";
    _sh_av80[3] = "-u";
    _sh_av80[4] = "root";
    char **_sh_sv81 = _sh_argv; int _sh_sc83 = _sh_argc;
    _sh_argv = _sh_av80; _sh_argc = 5;
    (capture(), _sh_argv = _sh_sv81, _sh_argc = _sh_sc83, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 22: id -g root  (numeric GID of root)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av84[5];
    _sh_av84[0] = "capture";
    static char _s86[4096];
    snprintf(_s86, sizeof _s86, "22-g-root");
    _sh_av84[1] = _s86;
    _sh_av84[2] = "id";
    _sh_av84[3] = "-g";
    _sh_av84[4] = "root";
    char **_sh_sv85 = _sh_argv; int _sh_sc87 = _sh_argc;
    _sh_argv = _sh_av84; _sh_argc = 5;
    (capture(), _sh_argv = _sh_sv85, _sh_argc = _sh_sc87, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 23: id -G root  (all group IDs of root, numeric)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av88[5];
    _sh_av88[0] = "capture";
    static char _s90[4096];
    snprintf(_s90, sizeof _s90, "23-G-root");
    _sh_av88[1] = _s90;
    _sh_av88[2] = "id";
    _sh_av88[3] = "-G";
    _sh_av88[4] = "root";
    char **_sh_sv89 = _sh_argv; int _sh_sc91 = _sh_argc;
    _sh_argv = _sh_av88; _sh_argc = 5;
    (capture(), _sh_argv = _sh_sv89, _sh_argc = _sh_sc91, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 24: id -un root  (user name of root)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av92[5];
    _sh_av92[0] = "capture";
    static char _s94[4096];
    snprintf(_s94, sizeof _s94, "24-un-root");
    _sh_av92[1] = _s94;
    _sh_av92[2] = "id";
    _sh_av92[3] = "-un";
    _sh_av92[4] = "root";
    char **_sh_sv93 = _sh_argv; int _sh_sc95 = _sh_argc;
    _sh_argv = _sh_av92; _sh_argc = 5;
    (capture(), _sh_argv = _sh_sv93, _sh_argc = _sh_sc95, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 25: id -ru root  (real user ID of root, numeric)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av96[5];
    _sh_av96[0] = "capture";
    static char _s98[4096];
    snprintf(_s98, sizeof _s98, "25-ru-root");
    _sh_av96[1] = _s98;
    _sh_av96[2] = "id";
    _sh_av96[3] = "-ru";
    _sh_av96[4] = "root";
    char **_sh_sv97 = _sh_argv; int _sh_sc99 = _sh_argc;
    _sh_argv = _sh_av96; _sh_argc = 5;
    (capture(), _sh_argv = _sh_sv97, _sh_argc = _sh_sc99, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 26: id -a  (compatibility flag — same as default)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av100[4];
    _sh_av100[0] = "capture";
    static char _s102[4096];
    snprintf(_s102, sizeof _s102, "26-a");
    _sh_av100[1] = _s102;
    _sh_av100[2] = "id";
    _sh_av100[3] = "-a";
    char **_sh_sv101 = _sh_argv; int _sh_sc103 = _sh_argc;
    _sh_argv = _sh_av100; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv101, _sh_argc = _sh_sc103, _sh_rc == 0);
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("All id demo sections completed.\n", stdout));
    static char _s104[32];
    snprintf(_s104, sizeof _s104, "%lld", (long long)(RC));
    (exit((int)atoll(_s104)), 0);
    return 0;
}