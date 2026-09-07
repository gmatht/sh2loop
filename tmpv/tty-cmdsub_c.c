#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
#include <sys/stat.h>
#include <time.h>

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
/* [ -f/-d/-e/-s/... ] file tests */
static long long _sh_mtime(const char *p) { struct stat st; return stat(p, &st) == 0 ? (long long)st.st_mtime : -1; }
static int _sh_is_f(const char *p) { struct stat st; return stat(p, &st) == 0 && S_ISREG(st.st_mode); }
static int _sh_is_d(const char *p) { struct stat st; return stat(p, &st) == 0 && S_ISDIR(st.st_mode); }
static int _sh_is_e(const char *p) { struct stat st; return stat(p, &st) == 0; }
static int _sh_is_s(const char *p) { struct stat st; return stat(p, &st) == 0 && st.st_size > 0; }
static int _sh_is_l(const char *p) { struct stat st; return lstat(p, &st) == 0 && S_ISLNK(st.st_mode); }
static int _sh_is_h(const char *p) { struct stat st; return lstat(p, &st) == 0 && S_ISLNK(st.st_mode); }
static int _sh_is_S(const char *p) { struct stat st; return stat(p, &st) == 0 && S_ISSOCK(st.st_mode); }
static int _sh_is_p(const char *p) { struct stat st; return stat(p, &st) == 0 && S_ISFIFO(st.st_mode); }
static int _sh_is_b(const char *p) { struct stat st; return stat(p, &st) == 0 && S_ISBLK(st.st_mode); }
static int _sh_is_c(const char *p) { struct stat st; return stat(p, &st) == 0 && S_ISCHR(st.st_mode); }
static int _sh_is_g(const char *p) { struct stat st; return stat(p, &st) == 0 && (st.st_mode & S_ISGID); }
static int _sh_is_k(const char *p) { struct stat st; return stat(p, &st) == 0 && (st.st_mode & S_ISVTX); }
static int _sh_is_u(const char *p) { struct stat st; return stat(p, &st) == 0 && (st.st_mode & S_ISUID); }
static int _sh_is_t(const char *p) { return isatty(atoi(p)); }
static int _sh_is_G(const char *p) { struct stat st; return stat(p, &st) == 0 && st.st_gid == getgid(); }
static int _sh_is_O(const char *p) { struct stat st; return stat(p, &st) == 0 && st.st_uid == getuid(); }
static int _sh_is_N(const char *p) { struct stat st; return stat(p, &st) == 0 && st.st_mtime > time(0); }
static int _sh_is_r(const char *p) { return access(p, R_OK) == 0; }
static int _sh_is_w(const char *p) { return access(p, W_OK) == 0; }
static int _sh_is_x(const char *p) { return access(p, X_OK) == 0; }
char* TTY_DEV = NULL;
char* dev = NULL;
char* ec = NULL;
char* label = NULL;
char* tmp_stderr = NULL;
char* tmp_stdout = NULL;

static char *_cap_10(void);
static char *_cap_11(void);
static char *_cap_13(void);
static char *_cap_14(void);
static int _sh_site_1(void);
static int _sh_site_2(void);
static int _sh_site_3(void);
static int _sh_site_4(void);
static int _sh_site_5(void);
static int _sh_site_6(void);
static int _sh_site_7(void);
static int _sh_site_8(void);
static int _sh_site_9(void);
static int _sh_site_12(void);
static int _sh_site_15(void);

static char *_cap_10(void) {
  static char buf[65536];
  static char *_c10_cmd = 0; static size_t _c10_cap = 0;
  static char *_c10_wb = 0; static size_t _c10_wcap = 0;
_sh_bres(&_c10_cmd, &_c10_cap);
_sh_bword(&_c10_cmd, &_c10_cap, "mktemp");
_sh_bword(&_c10_cmd, &_c10_cap, "/tmp/tty_demo_stdout_XXXXXX");
_sh_capture(buf, sizeof buf, _c10_cmd);
return buf;
}

static char *_cap_11(void) {
  static char buf[65536];
  static char *_c11_cmd = 0; static size_t _c11_cap = 0;
  static char *_c11_wb = 0; static size_t _c11_wcap = 0;
_sh_bres(&_c11_cmd, &_c11_cap);
_sh_bword(&_c11_cmd, &_c11_cap, "mktemp");
_sh_bword(&_c11_cmd, &_c11_cap, "/tmp/tty_demo_stderr_XXXXXX");
_sh_capture(buf, sizeof buf, _c11_cmd);
return buf;
}

static char *_cap_13(void) {
  static char buf[65536];
  static char *_c13_cmd = 0; static size_t _c13_cap = 0;
  static char *_c13_wb = 0; static size_t _c13_wcap = 0;
_sh_bres(&_c13_cmd, &_c13_cap);
_sh_bword(&_c13_cmd, &_c13_cap, "cat");
_sh_export("tmp_stdout", (tmp_stdout ? tmp_stdout : ""));
_sh_badd(&_c13_cmd, &_c13_cap, " \"$tmp_stdout\"");
_sh_capture(buf, sizeof buf, _c13_cmd);
return buf;
}

static char *_cap_14(void) {
  static char buf[65536];
  static char *_c14_cmd = 0; static size_t _c14_cap = 0;
  static char *_c14_wb = 0; static size_t _c14_wcap = 0;
_sh_bres(&_c14_cmd, &_c14_cap);
_sh_bword(&_c14_cmd, &_c14_cap, "cat");
_sh_export("tmp_stderr", (tmp_stderr ? tmp_stderr : ""));
_sh_badd(&_c14_cmd, &_c14_cap, " \"$tmp_stderr\"");
_sh_capture(buf, sizeof buf, _c14_cmd);
return buf;
}

static int _sh_site_1(void) {
_sh_reset();
_sh_word("capture");
_sh_word("01-default-terminal");
_sh_word("tty");
_sh_addraw("0<");
_sh_export("TTY_DEV", (TTY_DEV ? TTY_DEV : ""));
_sh_addraw("\"$TTY_DEV\"");
  return !_sh_system_rc();
}

static int _sh_site_2(void) {
_sh_reset();
_sh_word("capture");
_sh_word("02-not-a-tty");
_sh_word("tty");
_sh_addraw("0<");
_sh_word("/dev/null");
  return !_sh_system_rc();
}

static int _sh_site_3(void) {
_sh_reset();
_sh_word("capture");
_sh_word("04-silent-terminal");
_sh_word("tty");
_sh_word("-s");
_sh_addraw("0<");
_sh_export("TTY_DEV", (TTY_DEV ? TTY_DEV : ""));
_sh_addraw("\"$TTY_DEV\"");
  return !_sh_system_rc();
}

static int _sh_site_4(void) {
_sh_reset();
_sh_word("capture");
_sh_word("05-silent-notty");
_sh_word("tty");
_sh_word("-s");
_sh_addraw("0<");
_sh_word("/dev/null");
  return !_sh_system_rc();
}

static int _sh_site_5(void) {
_sh_reset();
_sh_word("capture");
_sh_word("07-long-silent");
_sh_word("tty");
_sh_word("--silent");
_sh_addraw("0<");
_sh_export("TTY_DEV", (TTY_DEV ? TTY_DEV : ""));
_sh_addraw("\"$TTY_DEV\"");
  return !_sh_system_rc();
}

static int _sh_site_6(void) {
_sh_reset();
_sh_word("capture");
_sh_word("08-long-quiet");
_sh_word("tty");
_sh_word("--quiet");
_sh_addraw("0<");
_sh_export("TTY_DEV", (TTY_DEV ? TTY_DEV : ""));
_sh_addraw("\"$TTY_DEV\"");
  return !_sh_system_rc();
}

static int _sh_site_7(void) {
_sh_reset();
_sh_word("capture");
_sh_word("09-long-silent-notty");
_sh_word("tty");
_sh_word("--silent");
_sh_addraw("0<");
_sh_word("/dev/null");
  return !_sh_system_rc();
}

static int _sh_site_8(void) {
_sh_reset();
_sh_word("capture");
_sh_word("10-long-quiet-notty");
_sh_word("tty");
_sh_word("--quiet");
_sh_addraw("0<");
_sh_word("/dev/null");
  return !_sh_system_rc();
}

static int _sh_site_9(void) {
_sh_reset();
_sh_word("capture");
_sh_word("13-double-silent");
_sh_word("tty");
_sh_word("-s");
_sh_word("-s");
_sh_addraw("0<");
_sh_export("TTY_DEV", (TTY_DEV ? TTY_DEV : ""));
_sh_addraw("\"$TTY_DEV\"");
  return !_sh_system_rc();
}

static int _sh_site_12(void) {
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

static int _sh_site_15(void) {
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
    _sh_mstr_set(&tmp_stdout, _cap_10());
    _sh_mstr_set(&tmp_stderr, _cap_11());
    _sh_site_12();
    static char _s17[32];
    snprintf(_s17, sizeof _s17, "%lld", (long long)(_sh_rc));
    ec = _s17;
    (_sh_rc = 0, 1);
    char* so = NULL;
    _sh_mstr_set(&so, _cap_13());
    char* se = NULL;
    _sh_mstr_set(&se, _cap_14());
    _sh_site_15();
    (_sh_rc = 0, printf("--- [%s] ---\n", ((char*)((label ? label : "")) ? (char*)((label ? label : "")) : "")));
    static char _s18[4096];
    _sh_argv_join(_s18, sizeof _s18);
    (_sh_rc = 0, printf("  cmd     : %s\n", ((char*)(_s18) ? (char*)(_s18) : "")));
    (_sh_rc = 0, printf("  exitcode: %s\n", ((char*)((ec ? ec : "")) ? (char*)((ec ? ec : "")) : "")));
    if ((((so ? so : "")) && ((so ? so : ""))[0])) {
        (_sh_rc = 0, printf("  stdout  : %s\n", ((char*)((so ? so : "")) ? (char*)((so ? so : "")) : "")));
    } else {
        (_sh_rc = 0, fputs("  stdout  : (empty)\n", stdout));
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
    static char _s0[4096];
    snprintf(_s0, sizeof _s0, "");
    _sh_mstr_set(&TTY_DEV, _s0);
    static const char* _for_dev_0[] = {"/dev/pts/2", "/dev/pts/3", "/dev/pts/4"};
    for (size_t _i_dev = 0; _i_dev < 3; _i_dev++) {
        dev = (char*)_for_dev_0[_i_dev];
        if (_sh_is_r((dev ? dev : ""))) {
            _sh_mstr_set(&TTY_DEV, dev);
            break;
        }
    }
    (_sh_rc = 0, printf("Using terminal device: %s\n", ((char*)(((((TTY_DEV ? TTY_DEV : "")) && ((TTY_DEV ? TTY_DEV : ""))[0]) ? ((TTY_DEV ? TTY_DEV : "")) : ("NONE"))) ? (char*)(((((TTY_DEV ? TTY_DEV : "")) && ((TTY_DEV ? TTY_DEV : ""))[0]) ? ((TTY_DEV ? TTY_DEV : "")) : ("NONE"))) : "")));
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 1: tty (default) — with a real terminal\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    _sh_site_1();
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 2: tty (default) — stdin from /dev/null\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    _sh_site_2();
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 3: tty (default) — piped input\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av1[5];
    _sh_av1[0] = "capture";
    static char _s3[4096];
    snprintf(_s3, sizeof _s3, "03-pipe-notty");
    _sh_av1[1] = _s3;
    _sh_av1[2] = "bash";
    _sh_av1[3] = "-c";
    _sh_av1[4] = "echo \"dummy\" | tty";
    char **_sh_sv2 = _sh_argv; int _sh_sc4 = _sh_argc;
    _sh_argv = _sh_av1; _sh_argc = 5;
    (capture(), _sh_argv = _sh_sv2, _sh_argc = _sh_sc4, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 4: tty -s — with a real terminal (silent)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    _sh_site_3();
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 5: tty -s — stdin from /dev/null (silent, not a tty)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    _sh_site_4();
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 6: tty -s — piped input (silent, not a tty)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av5[5];
    _sh_av5[0] = "capture";
    static char _s7[4096];
    snprintf(_s7, sizeof _s7, "06-silent-pipe");
    _sh_av5[1] = _s7;
    _sh_av5[2] = "bash";
    _sh_av5[3] = "-c";
    _sh_av5[4] = "echo \"dummy\" | tty -s";
    char **_sh_sv6 = _sh_argv; int _sh_sc8 = _sh_argc;
    _sh_argv = _sh_av5; _sh_argc = 5;
    (capture(), _sh_argv = _sh_sv6, _sh_argc = _sh_sc8, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 7: tty --silent — long form, with a real terminal\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    _sh_site_5();
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 8: tty --quiet — long form, with a real terminal\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    _sh_site_6();
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 9: tty --silent — stdin from /dev/null (not a tty)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    _sh_site_7();
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 10: tty --quiet — stdin from /dev/null (not a tty)\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    _sh_site_8();
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 11: tty (default) — inheriting stdin from the script\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av9[3];
    _sh_av9[0] = "capture";
    static char _s11[4096];
    snprintf(_s11, sizeof _s11, "11-inherited");
    _sh_av9[1] = _s11;
    _sh_av9[2] = "tty";
    char **_sh_sv10 = _sh_argv; int _sh_sc12 = _sh_argc;
    _sh_argv = _sh_av9; _sh_argc = 3;
    (capture(), _sh_argv = _sh_sv10, _sh_argc = _sh_sc12, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 12: tty -s — inheriting stdin from the script\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    char *_sh_av13[4];
    _sh_av13[0] = "capture";
    static char _s15[4096];
    snprintf(_s15, sizeof _s15, "12-inherited-silent");
    _sh_av13[1] = _s15;
    _sh_av13[2] = "tty";
    _sh_av13[3] = "-s";
    char **_sh_sv14 = _sh_argv; int _sh_sc16 = _sh_argc;
    _sh_argv = _sh_av13; _sh_argc = 4;
    (capture(), _sh_argv = _sh_sv14, _sh_argc = _sh_sc16, _sh_rc == 0);
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    (_sh_rc = 0, fputs(" SECTION 13: tty -s -s — repeated silent flag\n", stdout));
    (_sh_rc = 0, fputs("============================================================\n", stdout));
    _sh_site_9();
    (_sh_rc = 0, fputs("\n", stdout));
    (_sh_rc = 0, fputs("All tty demo sections completed.\n", stdout));
    return 0;
}