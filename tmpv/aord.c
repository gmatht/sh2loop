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
static char *config_k[1024] = {0};
static char *config_v[1024] = {0};
static size_t config_n = 0;

char* k = NULL;

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { extern int gethostname(char *, size_t); static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  setenv("BASH_VERSION", "5.2.15(1)-release", 0);

    1;
    _sh_assoc_set(config_k, config_v, &config_n, 1024, "service", "8080");
    _sh_assoc_set(config_k, config_v, &config_n, 1024, "user", "admin");
    _sh_assoc_set(config_k, config_v, &config_n, 1024, "host", "localhost");
    for (size_t _ai_config = 0; _ai_config < config_n; _ai_config++) {
        k = config_k[_ai_config];
        printf("%s\n", ((char*)((char*)_sh_assoc_get(config_k, config_v, config_n, (k ? k : ""))) ? (char*)((char*)_sh_assoc_get(config_k, config_v, config_n, (k ? k : ""))) : ""));
    }
    return 0;
}