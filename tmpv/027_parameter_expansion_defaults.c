#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

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
_sh_mstr maybe = {0};

int main(int _mac, char **_mav) {
  _sh_argv = _mav; _sh_argc = _mac;
  if (!getenv("HOSTNAME")) { extern int gethostname(char *, size_t); static char _hn[256]; if (gethostname(_hn, sizeof _hn) == 0) setenv("HOSTNAME", _hn, 0); }
  setenv("BASH_VERSION", "5.2.15(1)-release", 0);

    1;
    fputs("== Default values ==\n", stdout);
    maybe = "";
    1;
    printf("%s\n", ((char*)((((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : ("default"))) ? (char*)((((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : ("default"))) : ""));
    printf("%s\n", ((char*)((maybe = (((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : ("default")), (((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : ("default")))) ? (char*)((maybe = (((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : ("default")), (((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : ("default")))) : ""));
    printf("%s\n", ((char*)((((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : (fprintf(stderr, "%s\n", "error"), exit(1), (char*)0))) ? (char*)((((_sh_mstr_get(&maybe)) && (_sh_mstr_get(&maybe))[0]) ? (_sh_mstr_get(&maybe)) : (fprintf(stderr, "%s\n", "error"), exit(1), (char*)0))) : ""));
    return 0;
}