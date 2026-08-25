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
/* split a captured string on IFS whitespace into words */
static void _sh_export(const char *name, const char *val) {
  setenv(name, val ? val : "", 1);
}
/* `read` builtin: one line from stdin into a static buffer */
char* d = NULL;
char* echo_result = NULL;
char* perl_result = NULL;
char* printf_result = NULL;
char* sha256_result = NULL;
char* sha512_result = NULL;
char* strings_result = NULL;
char* tee_result = NULL;

static char *_cap_0(void);
static char *_cap_1(void);
static char *_cap_2(void);
static char *_cap_4(void);
static char *_cap_5(void);
static char *_cap_6(void);
static char *_cap_7(void);
static char *_cap_8(void);
static int _sh_site_3(void);
static int _sh_site_9(void);
static int _sh_site_10(void);

static char *_cap_0(void) {
  static char buf[65536];
  static char *_c0_cmd = 0; static size_t _c0_cap = 0;
  static char *_c0_wb = 0; static size_t _c0_wcap = 0;
_sh_bres(&_c0_cmd, &_c0_cap);
_sh_bword(&_c0_cmd, &_c0_cap, "echo");
_sh_bword(&_c0_cmd, &_c0_cap, "Hello from backticks");
_sh_capture(buf, sizeof buf, _c0_cmd);
return buf;
}

static char *_cap_1(void) {
  static char buf[65536];
  static char *_c1_cmd = 0; static size_t _c1_cap = 0;
  static char *_c1_wb = 0; static size_t _c1_wcap = 0;
_sh_bres(&_c1_cmd, &_c1_cap);
_sh_bword(&_c1_cmd, &_c1_cap, "printf");
_sh_bword(&_c1_cmd, &_c1_cap, "Number: %d, String: %s\\n");
_sh_bword(&_c1_cmd, &_c1_cap, "42");
_sh_bword(&_c1_cmd, &_c1_cap, "test");
_sh_capture(buf, sizeof buf, _c1_cmd);
return buf;
}

static char *_cap_2(void) {
  static char buf[65536];
  static char *_c2_cmd = 0; static size_t _c2_cap = 0;
  static char *_c2_wb = 0; static size_t _c2_wcap = 0;
_sh_bres(&_c2_cmd, &_c2_cap);
_sh_bword(&_c2_cmd, &_c2_cap, "mktemp");
_sh_bword(&_c2_cmd, &_c2_cap, "-d");
_sh_capture(buf, sizeof buf, _c2_cmd);
return buf;
}

static char *_cap_4(void) {
  static char buf[65536];
  static char *_c4_cmd = 0; static size_t _c4_cap = 0;
  static char *_c4_wb = 0; static size_t _c4_wcap = 0;
_sh_bres(&_c4_cmd, &_c4_cap);
_sh_bword(&_c4_cmd, &_c4_cap, "sha256sum");
_sh_bword(&_c4_cmd, &_c4_cap, "test_checksum.txt");
fprintf(stdout,"C4CMD:[%s]\n",_c4_cmd); _sh_capture(buf, sizeof buf, _c4_cmd); fprintf(stdout,"C4OUT:[%s]\n",buf);
return buf;
}

static char *_cap_5(void) {
  static char buf[65536];
  static char *_c5_cmd = 0; static size_t _c5_cap = 0;
  static char *_c5_wb = 0; static size_t _c5_wcap = 0;
_sh_bres(&_c5_cmd, &_c5_cap);
_sh_bword(&_c5_cmd, &_c5_cap, "sha512sum");
_sh_bword(&_c5_cmd, &_c5_cap, "test_checksum.txt");
_sh_capture(buf, sizeof buf, _c5_cmd);
return buf;
}

static char *_cap_6(void) {
  static char buf[65536];
  static char *_c6_cmd = 0; static size_t _c6_cap = 0;
  static char *_c6_wb = 0; static size_t _c6_wcap = 0;
_sh_bres(&_c6_cmd, &_c6_cap);
_sh_bword(&_c6_cmd, &_c6_cap, "strings");
_sh_bword(&_c6_cmd, &_c6_cap, "test_binary.txt");
_sh_badd(&_c6_cmd, &_c6_cap, " |");
_sh_bword(&_c6_cmd, &_c6_cap, "head");
_sh_bword(&_c6_cmd, &_c6_cap, "-3");
_sh_capture(buf, sizeof buf, _c6_cmd);
return buf;
}

static char *_cap_7(void) {
  static char buf[65536];
  static char *_c7_cmd = 0; static size_t _c7_cap = 0;
  static char *_c7_wb = 0; static size_t _c7_wcap = 0;
_sh_bres(&_c7_cmd, &_c7_cap);
_sh_bword(&_c7_cmd, &_c7_cap, "echo");
_sh_bword(&_c7_cmd, &_c7_cap, "test output");
_sh_badd(&_c7_cmd, &_c7_cap, " |");
_sh_bword(&_c7_cmd, &_c7_cap, "tee");
_sh_bword(&_c7_cmd, &_c7_cap, "test_tee.txt");
_sh_capture(buf, sizeof buf, _c7_cmd);
return buf;
}

static char *_cap_8(void) {
  static char buf[65536];
  static char *_c8_cmd = 0; static size_t _c8_cap = 0;
  static char *_c8_wb = 0; static size_t _c8_wcap = 0;
_sh_bres(&_c8_cmd, &_c8_cap);
_sh_bword(&_c8_cmd, &_c8_cap, "perl");
_sh_bword(&_c8_cmd, &_c8_cap, "-e");
_sh_bword(&_c8_cmd, &_c8_cap, "print \"Hello from Perl\\n\"");
_sh_capture(buf, sizeof buf, _c8_cmd);
return buf;
}

static int _sh_site_3(void) {
_sh_reset();
_sh_word("echo");
_sh_word("test content");
_sh_addraw(">");
_sh_word("test_checksum.txt");
  return !_sh_system_rc();
}

static int _sh_site_9(void) {
_sh_reset();
_sh_word("rm");
_sh_word("-f");
_sh_word("test_checksum.txt");
_sh_word("test_tee.txt");
  return !_sh_system_rc();
}

static int _sh_site_10(void) {
_sh_reset();
_sh_word("rm");
_sh_word("-r");
_sh_word("-f");
_sh_export("d", (d ? d : ""));
_sh_addraw("\"$d\"");
  return !_sh_system_rc();
}

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  freopen("/dev/null", "w", stderr);
  setvbuf(stdout, 0, _IONBF, 0);

    (_sh_rc = 0, fputs("=== Output and Formatting Commands ===\n", stdout));
    echo_result = strdup(_cap_0());
    (_sh_rc = 0, printf("Echo result: %s\n", ((char*)(echo_result) ? (char*)(echo_result) : "")));
    printf_result = strdup(_cap_1());
    (_sh_rc = 0, printf("Printf result: %s\n", ((char*)(printf_result) ? (char*)(printf_result) : "")));
    (_sh_rc = 0, fputs("=== Compression Commands ===\n", stdout));
    (_sh_rc = 0, fputs("=== Network Commands ===\n", stdout));
    (_sh_rc = 0, fputs("=== Process Management Commands ===\n", stdout));
    d = strdup(_cap_2());
    { int _t0 = (({ int _r = chdir((d ? d : "")); _sh_rc = (_r == 0 ? 0 : 1); if (_r == 0) setenv("PWD", getcwd(0, 0), 1); _r == 0; }));
      _sh_rc = _t0 ? 0 : 1;
      if (!_t0) {
        (exit(1), 0);
      }
    }
    (_sh_rc = 0, fputs("=== Checksum Commands ===\n", stdout));
    _sh_site_3();
    sha256_result = strdup(_cap_4());
    (_sh_rc = 0, printf("SHA256 result: %s\n", ((char*)(sha256_result) ? (char*)(sha256_result) : "")));
    sha512_result = strdup(_cap_5());
    (_sh_rc = 0, printf("SHA512 result: %s\n", ((char*)(sha512_result) ? (char*)(sha512_result) : "")));
    strings_result = strdup(_cap_6());
    (_sh_rc = 0, fputs("Strings result:\n", stdout));
    (_sh_rc = 0, printf("%s\n", ((char*)(strings_result) ? (char*)(strings_result) : "")));
    (_sh_rc = 0, fputs("=== I/O Redirection Commands ===\n", stdout));
    tee_result = strdup(_cap_7());
    (_sh_rc = 0, printf("Tee result: %s\n", ((char*)(tee_result) ? (char*)(tee_result) : "")));
    (_sh_rc = 0, fputs("=== Perl Command ===\n", stdout));
    perl_result = strdup(_cap_8());
    (_sh_rc = 0, printf("Perl result: %s\n", ((char*)(perl_result) ? (char*)(perl_result) : "")));
    _sh_site_9();
    ({ int _r = chdir("/"); _sh_rc = (_r == 0 ? 0 : 1); if (_r == 0) setenv("PWD", getcwd(0, 0), 1); _r == 0; });
    _sh_site_10();
    return 0;
}