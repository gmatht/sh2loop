/*
 * polyfills.c — the host-bound/IO seam of the sh2.* runtime, authored
 * once in C, linked per-backend (native POSIX/glibc). Complements
 * polyfills.sh (the pure-CPU core, authored once in bash, transpiled
 * per-backend by the same pipeline that transpiles user programs).
 *
 * Interface: bash function convention (positional args in, stdout out).
 * Each polyfill is `int sh2poly_<name>(int argc, char **argv)`:
 *   - argc/argv: the positional args ($1, $2, ...)
 *   - writes its result to stdout (like the bash polyfills' echo)
 *   - returns the exit status (0 = success)
 *
 * What lives here (the parts bash cannot express without recursing):
 *   - the host-bound seam: exec, capture, fs.*, pipeline, redirect,
 *     background, subshell, exit — native C over POSIX
 *     (fork/exec, pipe, open/read/write/stat)
 *   - the IO-bound builtins (cat, ls, grep, sed, sort, ...) — thin
 *     wrappers over the host's standard tools (the host IS the
 *     implementation; the polyfill provides the builtin contract)
 *   - the shell-state builtins (declare, export, local, set, shift,
 *     unset, read, ...) — through the host callbacks below (the
 *     embedding backend owns the variable/positional store)
 *
 * What stays in polyfills.sh (the pure-CPU core): basename, dirname,
 * test, param, globMatch, caseMatch, brace, the string primitives, and
 * the wc/head/tail line cores. Backends transpile those per-backend;
 * this library supplies the rest. Together they cover every sh2perl
 * builtin (see check-coverage.py).
 *
 * Self-test: build with -DSH2POLY_SELFTEST to get a main() that runs
 * the battery at the bottom. The oracle: run the same battery under
 * bash (polyfills-c-ref.sh) and diff — the C polyfills must match the
 * real builtins' output.
 */
#define _POSIX_C_SOURCE 200809L
#define _GNU_SOURCE

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stdint.h>
#include <ctype.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <dirent.h>
#include <time.h>
#include <limits.h>
#include <libgen.h>

/* ─── host callbacks (the embedding backend provides these) ──────────
 * The state registers (getVar/setVar/positional/lastExit) stay
 * per-backend; the C polyfills reach them through this surface. The
 * defaults are process-level (environ + exit), so the library is
 * usable standalone and the self-test needs no backend.
 */
typedef const char *(*sh2poly_getvar_fn)(const char *name);
typedef void (*sh2poly_setvar_fn)(const char *name, const char *value);
typedef const char *(*sh2poly_getpos_fn)(int i);          /* $i, 1-based */
typedef void (*sh2poly_setpos_fn)(int i, const char *v);
typedef int (*sh2poly_poscount_fn)(void);
typedef void (*sh2poly_exit_fn)(int code);
typedef void (*sh2poly_error_fn)(const char *msg);

static sh2poly_getvar_fn  sh2poly_getvar  = NULL;
static sh2poly_setvar_fn  sh2poly_setvar  = NULL;
static sh2poly_getpos_fn  sh2poly_getpos  = NULL;
static sh2poly_setpos_fn  sh2poly_setpos  = NULL;
static sh2poly_poscount_fn sh2poly_poscount = NULL;
static sh2poly_exit_fn    sh2poly_exitfn  = NULL;
static sh2poly_error_fn   sh2poly_errorfn = NULL;

void sh2poly_set_callbacks(
    sh2poly_getvar_fn gv, sh2poly_setvar_fn sv,
    sh2poly_getpos_fn gp, sh2poly_setpos_fn sp, sh2poly_poscount_fn pc,
    sh2poly_exit_fn ex, sh2poly_error_fn er)
{
    sh2poly_getvar = gv; sh2poly_setvar = sv;
    sh2poly_getpos = gp; sh2poly_setpos = sp; sh2poly_poscount = pc;
    sh2poly_exitfn = ex; sh2poly_errorfn = er;
}

static const char *poly_getvar(const char *name) {
    if (sh2poly_getvar) return sh2poly_getvar(name);
    return getenv(name);
}
static void poly_setvar(const char *name, const char *value) {
    if (sh2poly_setvar) { sh2poly_setvar(name, value); return; }
    if (value) setenv(name, value, 1); else unsetenv(name);
}
static const char *poly_getpos(int i) {
    if (sh2poly_getpos) return sh2poly_getpos(i);
    return NULL;
}
static void poly_setpos(int i, const char *v) {
    if (sh2poly_setpos) sh2poly_setpos(i, v);
}
static int poly_poscount(void) {
    if (sh2poly_poscount) return sh2poly_poscount();
    return 0;
}
static void poly_exit(int code) {
    if (sh2poly_exitfn) sh2poly_exitfn(code);
    exit(code);
}
static void poly_error(const char *msg) {
    if (sh2poly_errorfn) { sh2poly_errorfn(msg); return; }
    fputs(msg, stderr);
}

/* ─── small helpers ────────────────────────────────────────────────── */
static void outn(const char *s) { fputs(s, stdout); fputc('\n', stdout); }
static void errmsg(const char *s) { poly_error(s); }

/* read all of stdin into a malloc'd NUL-terminated buffer */
static char *read_all_stdin(void) {
    size_t cap = 4096, len = 0;
    char *buf = malloc(cap);
    if (!buf) return NULL;
    for (;;) {
        if (len + 4096 + 1 > cap) { cap *= 2; char *nb = realloc(buf, cap); if (!nb) { free(buf); return NULL; } buf = nb; }
        size_t n = fread(buf + len, 1, 4096, stdin);
        len += n;
        if (n < 4096) break;
    }
    buf[len] = 0;
    return buf;
}

/* run a command (argv[0] = program) with the given argv, waiting; return
 * the exit status (0-255). Used by the seam and the delegating builtins. */
static int run_prog(char **argv) {
    pid_t pid = fork();
    if (pid < 0) { errmsg("sh2poly: fork failed\n"); return 127; }
    if (pid == 0) {
        execvp(argv[0], argv);
        fprintf(stderr, "sh2poly: %s: %s\n", argv[0], strerror(errno));
        _exit(errno == ENOENT ? 127 : 126);
    }
    int st = 0;
    while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
    if (WIFEXITED(st)) return WEXITSTATUS(st);
    if (WIFSIGNALED(st)) return 128 + WTERMSIG(st);
    return 1;
}

/* run a command, capturing its stdout into a malloc'd buffer */
static char *capture_prog(char **argv, int *status) {
    int pfd[2];
    if (pipe(pfd) < 0) { *status = 127; return NULL; }
    pid_t pid = fork();
    if (pid < 0) { close(pfd[0]); close(pfd[1]); *status = 127; return NULL; }
    if (pid == 0) {
        close(pfd[0]);
        dup2(pfd[1], 1);
        close(pfd[1]);
        execvp(argv[0], argv);
        fprintf(stderr, "sh2poly: %s: %s\n", argv[0], strerror(errno));
        _exit(errno == ENOENT ? 127 : 126);
    }
    close(pfd[1]);
    size_t cap = 4096, len = 0;
    char *buf = malloc(cap);
    if (!buf) { close(pfd[0]); *status = 1; return NULL; }
    for (;;) {
        if (len + 4096 + 1 > cap) { cap *= 2; char *nb = realloc(buf, cap); if (!nb) { free(buf); close(pfd[0]); *status = 1; return NULL; } buf = nb; }
        ssize_t n = read(pfd[0], buf + len, 4096);
        if (n <= 0) break;
        len += (size_t)n;
    }
    close(pfd[0]);
    buf[len] = 0;
    int st = 0;
    while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
    *status = WIFEXITED(st) ? WEXITSTATUS(st) : (WIFSIGNALED(st) ? 128 + WTERMSIG(st) : 1);
    return buf;
}

/* ─── the host-bound seam (native C over POSIX) ────────────────────── */

/* exec — run a command, wait, return its status. argv[0] = command. */
int sh2poly_exec(int argc, char **argv) {
    if (argc < 1) return 2;
    char **av = malloc(sizeof(char *) * (argc + 1));
    if (!av) return 2;
    for (int i = 0; i < argc; i++) av[i] = argv[i];
    av[argc] = NULL;
    int st = run_prog(av);
    free(av);
    return st;
}

/* capture — run a command, write its captured stdout to our stdout. */
int sh2poly_capture(int argc, char **argv) {
    if (argc < 1) return 2;
    char **av = malloc(sizeof(char *) * (argc + 1));
    if (!av) return 2;
    for (int i = 0; i < argc; i++) av[i] = argv[i];
    av[argc] = NULL;
    int st = 0;
    char *cap = capture_prog(av, &st);
    free(av);
    if (cap) { fputs(cap, stdout); free(cap); }
    return st;
}

/* fs_read — cat a file to stdout. argv[0] = path. */
int sh2poly_fs_read(int argc, char **argv) {
    if (argc < 1) return 2;
    FILE *f = fopen(argv[0], "rb");
    if (!f) { fprintf(stderr, "sh2poly: %s: %s\n", argv[0], strerror(errno)); return 1; }
    char buf[65536];
    size_t n;
    while ((n = fread(buf, 1, sizeof buf, f)) > 0) fwrite(buf, 1, n, stdout);
    fclose(f);
    return 0;
}

/* fs_write — write data to a file. argv[0] = path, argv[1] = data
 * (or read stdin when argv[1] is absent). */
int sh2poly_fs_write(int argc, char **argv) {
    if (argc < 1) return 2;
    const char *data = argc >= 2 ? argv[1] : read_all_stdin();
    if (!data) return 1;
    FILE *f = fopen(argv[0], "wb");
    if (!f) { fprintf(stderr, "sh2poly: %s: %s\n", argv[0], strerror(errno)); return 1; }
    fwrite(data, 1, strlen(data), f);
    fclose(f);
    return 0;
}

/* fs_stat — print "size mode mtime" for a path. argv[0] = path. */
int sh2poly_fs_stat(int argc, char **argv) {
    if (argc < 1) return 2;
    struct stat st;
    if (stat(argv[0], &st) != 0) { fprintf(stderr, "sh2poly: %s: %s\n", argv[0], strerror(errno)); return 1; }
    printf("%lld %o\n", (long long)st.st_size, (unsigned)st.st_mode & 07777);
    return 0;
}

/* pipeline — run a pipeline. argv = [cmd1, a1..., "|", cmd2, a2...].
 * Each stage's stdout feeds the next stage's stdin; the last stage's
 * stdout is ours. Returns the last stage's status. */
int sh2poly_pipeline(int argc, char **argv) {
    if (argc < 1) return 2;
    /* split argv into stages on the literal "|" token */
    int nstages = 1;
    for (int i = 0; i < argc; i++) if (strcmp(argv[i], "|") == 0) nstages++;
    char ***stages = calloc((size_t)nstages, sizeof(char **));
    if (!stages) return 2;
    int *lens = calloc((size_t)nstages, sizeof(int));
    if (!lens) { free(stages); return 2; }
    int s = 0;
    for (int i = 0; i < argc; i++) {
        if (strcmp(argv[i], "|") == 0) { s++; continue; }
        lens[s]++;
    }
    for (int i = 0; i < nstages; i++) {
        stages[i] = malloc(sizeof(char *) * ((size_t)lens[i] + 1));
        if (!stages[i]) { for (int j = 0; j < i; j++) free(stages[j]); free(stages); free(lens); return 2; }
    }
    s = 0; int k = 0;
    for (int i = 0; i < argc; i++) {
        if (strcmp(argv[i], "|") == 0) { stages[s][k] = NULL; s++; k = 0; continue; }
        stages[s][k++] = argv[i];
    }
    stages[s][k] = NULL;

    int prev_read = -1;
    int last = 0;
    for (int i = 0; i < nstages; i++) {
        int pfd[2];
        if (i < nstages - 1 && pipe(pfd) < 0) { last = 127; break; }
        pid_t pid = fork();
        if (pid < 0) { last = 127; break; }
        if (pid == 0) {
            if (prev_read >= 0) { dup2(prev_read, 0); close(prev_read); }
            if (i < nstages - 1) { dup2(pfd[1], 1); close(pfd[1]); close(pfd[0]); }
            execvp(stages[i][0], stages[i]);
            fprintf(stderr, "sh2poly: %s: %s\n", stages[i][0], strerror(errno));
            _exit(errno == ENOENT ? 127 : 126);
        }
        if (prev_read >= 0) close(prev_read);
        if (i < nstages - 1) { close(pfd[1]); prev_read = pfd[0]; }
        int st = 0;
        while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
        last = WIFEXITED(st) ? WEXITSTATUS(st) : (WIFSIGNALED(st) ? 128 + WTERMSIG(st) : 1);
    }
    if (prev_read >= 0) close(prev_read);
    for (int i = 0; i < nstages; i++) free(stages[i]);
    free(stages); free(lens);
    return last;
}

/* redirect — run a command with an fd redirected. argv = [fd, mode,
 * path, cmd, args...]. mode: ">" (truncate), ">>" (append), "<" (read). */
int sh2poly_redirect(int argc, char **argv) {
    if (argc < 4) return 2;
    int fd = atoi(argv[0]);
    const char *mode = argv[1];
    const char *path = argv[2];
    int flags;
    if (strcmp(mode, ">") == 0) flags = O_WRONLY | O_CREAT | O_TRUNC;
    else if (strcmp(mode, ">>") == 0) flags = O_WRONLY | O_CREAT | O_APPEND;
    else if (strcmp(mode, "<") == 0) flags = O_RDONLY;
    else { errmsg("sh2poly: redirect: bad mode\n"); return 2; }
    int ofd = open(path, flags, 0666);
    if (ofd < 0) { fprintf(stderr, "sh2poly: %s: %s\n", path, strerror(errno)); return 1; }
    pid_t pid = fork();
    if (pid < 0) { close(ofd); return 127; }
    if (pid == 0) {
        dup2(ofd, fd);
        close(ofd);
        char **av = malloc(sizeof(char *) * ((size_t)(argc - 3) + 1));
        if (!av) _exit(2);
        for (int i = 3; i < argc; i++) av[i - 3] = argv[i];
        av[argc - 3] = NULL;
        execvp(av[0], av);
        fprintf(stderr, "sh2poly: %s: %s\n", av[0], strerror(errno));
        _exit(errno == ENOENT ? 127 : 126);
    }
    close(ofd);
    int st = 0;
    while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
    return WIFEXITED(st) ? WEXITSTATUS(st) : (WIFSIGNALED(st) ? 128 + WTERMSIG(st) : 1);
}

/* background — run a command in the background; print the child pid
 * (the caller captures it, like $!). argv[0] = command. */
int sh2poly_background(int argc, char **argv) {
    if (argc < 1) return 2;
    char **av = malloc(sizeof(char *) * ((size_t)argc + 1));
    if (!av) return 2;
    for (int i = 0; i < argc; i++) av[i] = argv[i];
    av[argc] = NULL;
    pid_t pid = fork();
    if (pid < 0) { free(av); return 127; }
    if (pid == 0) {
        setsid();
        execvp(av[0], av);
        _exit(errno == ENOENT ? 127 : 126);
    }
    free(av);
    printf("%d\n", (int)pid);
    return 0;
}

/* subshell — run a command in a forked subshell, wait, return status. */
int sh2poly_subshell(int argc, char **argv) {
    return sh2poly_exec(argc, argv);
}

/* exit — terminate with the given code. argv[0] = code (default 0). */
int sh2poly_exit(int argc, char **argv) {
    int code = argc >= 1 ? atoi(argv[0]) : 0;
    poly_exit(code);
    return code; /* unreachable when the callback exits */
}

/* ─── native-C builtins (pure-CPU, not in polyfills.sh) ────────────── */

/* echo — -n (no newline), -e (backslash escapes). */
int sh2poly_echo(int argc, char **argv) {
    int n = 0, e = 0, i = 0;
    if (argc > 0 && strcmp(argv[0], "-n") == 0) { n = 1; i = 1; }
    else if (argc > 0 && strcmp(argv[0], "-e") == 0) { e = 1; i = 1; }
    for (; i < argc; i++) {
        if (i > (n || e ? 1 : 0)) fputc(' ', stdout);
        if (e) {
            for (const char *p = argv[i]; *p; p++) {
                if (*p == '\\' && p[1]) {
                    p++;
                    switch (*p) {
                        case 'n': fputc('\n', stdout); break;
                        case 't': fputc('\t', stdout); break;
                        case 'r': fputc('\r', stdout); break;
                        case '\\': fputc('\\', stdout); break;
                        case 'a': fputc('\a', stdout); break;
                        case 'b': fputc('\b', stdout); break;
                        case 'f': fputc('\f', stdout); break;
                        case 'v': fputc('\v', stdout); break;
                        case '0': {
                            int v = 0, k = 0;
                            while (k < 3 && p[1] >= '0' && p[1] <= '7') { v = v * 8 + (p[1] - '0'); p++; k++; }
                            fputc(v & 0xff, stdout);
                            break;
                        }
                        default: fputc('\\', stdout); fputc(*p, stdout);
                    }
                } else fputc(*p, stdout);
            }
        } else fputs(argv[i], stdout);
    }
    if (!n) fputc('\n', stdout);
    return 0;
}

/* printf — bash printf subset: %s %d %i %u %x %X %o %c %f %e %g %b %q
 * %%, with width/precision and the -v VAR form. */
static void printf_quote(FILE *mem, const char *s) {
    /* bash %q: backslash-escape chars outside the safe set */
    for (const char *p = s; *p; p++) {
        unsigned char c = (unsigned char)*p;
        if (isalnum(c) || strchr("_./-:=+@%,~", c)) fputc(c, mem);
        else { fputc('\\', mem); fputc(c, mem); }
    }
}
static void printf_bs(FILE *mem, const char *s) {
    for (const char *p = s; *p; p++) {
        if (*p == '\\' && p[1]) {
            p++;
            switch (*p) {
                case 'n': fputc('\n', mem); break;
                case 't': fputc('\t', mem); break;
                case 'r': fputc('\r', mem); break;
                case '\\': fputc('\\', mem); break;
                case 'a': fputc('\a', mem); break;
                case 'b': fputc('\b', mem); break;
                case 'f': fputc('\f', mem); break;
                case 'v': fputc('\v', mem); break;
                case '0': {
                    int v = 0, k = 0;
                    while (k < 3 && p[1] >= '0' && p[1] <= '7') { v = v * 8 + (p[1] - '0'); p++; k++; }
                    fputc(v & 0xff, mem);
                    break;
                }
                default: fputc('\\', mem); fputc(*p, mem);
            }
        } else fputc(*p, mem);
    }
}
/* interpret backslash escapes in a printf format (bash printf semantics) */
static void printf_fmt_bs(FILE *mem, const char **pp) {
    const char *p = *pp;
    p++; /* skip the backslash */
    switch (*p) {
        case 'n': fputc('\n', mem); p++; break;
        case 't': fputc('\t', mem); p++; break;
        case 'r': fputc('\r', mem); p++; break;
        case '\\': fputc('\\', mem); p++; break;
        case 'a': fputc('\a', mem); p++; break;
        case 'b': fputc('\b', mem); p++; break;
        case 'f': fputc('\f', mem); p++; break;
        case 'v': fputc('\v', mem); p++; break;
        case '0': {
            int v = 0, k = 0;
            p++;
            while (k < 3 && p[0] >= '0' && p[0] <= '7') { v = v * 8 + (p[0] - '0'); p++; k++; }
            fputc(v & 0xff, mem);
            break;
        }
        default: fputc('\\', mem); fputc(*p, mem); p++;
    }
    *pp = p;
}
int sh2poly_printf(int argc, char **argv) {
    int i = 0;
    const char *target = NULL;
    if (argc >= 2 && strcmp(argv[0], "-v") == 0) { target = argv[1]; i = 2; }
    if (i >= argc) return 0;
    const char *fmt = argv[i++];
    /* accumulate into a buffer so -v can capture it (open_memstream
     * NUL-terminates and reports the length) */
    char *buf = NULL;
    size_t blen = 0;
    FILE *mem = open_memstream(&buf, &blen);
    if (!mem) return 1;
    int argi = i;
    for (const char *p = fmt; *p; ) {
        if (*p == '\\') { printf_fmt_bs(mem, &p); continue; }
        if (*p != '%') { fputc(*p, mem); p++; continue; }
        p++;
        if (*p == '%') { fputc('%', mem); p++; continue; }
        /* parse flags/width/precision into a spec we can pass to fprintf */
        char spec[64]; size_t si = 0;
        spec[si++] = '%';
        while (*p && strchr("-+ #0", *p)) spec[si++] = *p++;
        while (*p && isdigit((unsigned char)*p)) spec[si++] = *p++;
        if (*p == '.') { spec[si++] = *p++; while (*p && isdigit((unsigned char)*p)) spec[si++] = *p++; }
        if (si >= sizeof spec - 4) break;
        char conv = *p;
        const char *arg = argi < argc ? argv[argi] : "";
        if (argi < argc) argi++;
        switch (conv) {
            case 's': spec[si++] = 's'; spec[si] = 0; fprintf(mem, spec, arg); break;
            case 'd': case 'i': spec[si++] = 'd'; spec[si] = 0; fprintf(mem, spec, (int)strtoll(arg, NULL, 10)); break;
            case 'u': spec[si++] = 'u'; spec[si] = 0; fprintf(mem, spec, (unsigned)strtoull(arg, NULL, 10)); break;
            case 'x': spec[si++] = 'x'; spec[si] = 0; fprintf(mem, spec, (unsigned)strtoull(arg, NULL, 16)); break;
            case 'X': spec[si++] = 'X'; spec[si] = 0; fprintf(mem, spec, (unsigned)strtoull(arg, NULL, 16)); break;
            case 'o': spec[si++] = 'o'; spec[si] = 0; fprintf(mem, spec, (unsigned)strtoull(arg, NULL, 8)); break;
            case 'c': spec[si++] = 'c'; spec[si] = 0; fprintf(mem, spec, arg[0]); break;
            case 'f': spec[si++] = 'f'; spec[si] = 0; fprintf(mem, spec, strtod(arg, NULL)); break;
            case 'e': spec[si++] = 'e'; spec[si] = 0; fprintf(mem, spec, strtod(arg, NULL)); break;
            case 'g': spec[si++] = 'g'; spec[si] = 0; fprintf(mem, spec, strtod(arg, NULL)); break;
            case 'b': printf_bs(mem, arg); break;
            case 'q': printf_quote(mem, arg); break;
            default: fputc('%', mem); fputc(conv, mem);
        }
        p++; /* skip the conversion char */
    }
    fclose(mem);
    if (target) {
        char *v = malloc(blen + 1);
        if (v) { memcpy(v, buf, blen + 1); poly_setvar(target, v); free(v); }
    } else {
        fwrite(buf, 1, blen, stdout);
    }
    free(buf);
    return 0;
}

/* seq — first/step/last with -s separator, -w padding, -f format. */
int sh2poly_seq(int argc, char **argv) {
    const char *sep = "\n";
    const char *fmt = NULL;
    int pad = 0;
    double first = 1, step = 1, last = 0;
    double pos[3]; int np = 0;
    for (int i = 0; i < argc; i++) {
        const char *a = argv[i];
        if (strcmp(a, "-s") == 0 && i + 1 < argc) { sep = argv[++i]; continue; }
        if (strcmp(a, "-w") == 0) { pad = 1; continue; }
        if (strcmp(a, "-f") == 0 && i + 1 < argc) { fmt = argv[++i]; continue; }
        char *end = NULL;
        double v = strtod(a, &end);
        if (end && *end == 0 && np < 3) pos[np++] = v;
    }
    if (np == 1) last = pos[0];
    else if (np == 2) { first = pos[0]; last = pos[1]; }
    else if (np >= 3) { first = pos[0]; step = pos[1]; last = pos[2]; }
    int width = 0;
    if (pad) {
        char b[64];
        snprintf(b, sizeof b, "%.0f", first > last ? first : last);
        width = (int)strlen(b);
    }
    int firstout = 1;
    for (double v = first; (step >= 0 ? v <= last : v >= last); v += step) {
        if (!firstout) fputs(sep, stdout);
        firstout = 0;
        if (fmt) {
            char b[256];
            snprintf(b, sizeof b, fmt, v);
            fputs(b, stdout);
        } else if (pad) {
            char b[64];
            snprintf(b, sizeof b, "%.0f", v);
            for (int k = (int)strlen(b); k < width; k++) fputc('0', stdout);
            fputs(b, stdout);
        } else {
            /* print like bash: integers without a decimal point */
            if (v == (double)(long long)v) printf("%lld", (long long)v);
            else printf("%g", v);
        }
    }
    fputc('\n', stdout);
    return 0;
}

/* let — integer arithmetic expression evaluator (bash let subset:
 * + - * / % ** << >> & | ^ ~ ! ( ) comparisons, var refs via getvar). */
typedef struct { const char *s; size_t i; int err; } arith_ctx;
static long long arith_expr(arith_ctx *c);
static void arith_ws(arith_ctx *c) { while (c->s[c->i] == ' ' || c->s[c->i] == '\t') c->i++; }
static long long arith_primary(arith_ctx *c) {
    arith_ws(c);
    if (c->s[c->i] == '(') { c->i++; long long v = arith_expr(c); arith_ws(c); if (c->s[c->i] == ')') c->i++; return v; }
    if (c->s[c->i] == '-') { c->i++; return -arith_primary(c); }
    if (c->s[c->i] == '+') { c->i++; return arith_primary(c); }
    if (c->s[c->i] == '~') { c->i++; return ~arith_primary(c); }
    if (c->s[c->i] == '!') { c->i++; return !arith_primary(c); }
    if (isdigit((unsigned char)c->s[c->i]) || c->s[c->i] == '0') {
        char *end = NULL;
        long long v = strtoll(c->s + c->i, &end, 0);
        c->i = (size_t)(end - c->s);
        return v;
    }
    /* variable reference */
    size_t st = c->i;
    while (isalnum((unsigned char)c->s[c->i]) || c->s[c->i] == '_') c->i++;
    if (c->i == st) { c->err = 1; return 0; }
    char name[256];
    size_t n = c->i - st;
    if (n >= sizeof name) n = sizeof name - 1;
    memcpy(name, c->s + st, n); name[n] = 0;
    const char *v = poly_getvar(name);
    return v ? strtoll(v, NULL, 0) : 0;
}
static long long arith_mul(arith_ctx *c) {
    long long l = arith_primary(c);
    for (;;) {
        arith_ws(c);
        char op = c->s[c->i];
        if (op == '*' && c->s[c->i + 1] == '*') { c->i += 2; long long r = arith_primary(c); long long acc = 1; for (long long k = 0; k < r; k++) acc *= l; l = acc; }
        else if (op == '*') { c->i++; l *= arith_primary(c); }
        else if (op == '/') { c->i++; long long r = arith_primary(c); l = r ? l / r : 0; }
        else if (op == '%') { c->i++; long long r = arith_primary(c); l = r ? l % r : 0; }
        else break;
    }
    return l;
}
static long long arith_add(arith_ctx *c) {
    long long l = arith_mul(c);
    for (;;) {
        arith_ws(c);
        char op = c->s[c->i];
        if (op == '+') { c->i++; l += arith_mul(c); }
        else if (op == '-') { c->i++; l -= arith_mul(c); }
        else break;
    }
    return l;
}
static long long arith_shift(arith_ctx *c) {
    long long l = arith_add(c);
    for (;;) {
        arith_ws(c);
        if (c->s[c->i] == '<' && c->s[c->i + 1] == '<') { c->i += 2; l <<= arith_add(c); }
        else if (c->s[c->i] == '>' && c->s[c->i + 1] == '>') { c->i += 2; l >>= arith_add(c); }
        else break;
    }
    return l;
}
static long long arith_cmp(arith_ctx *c) {
    long long l = arith_shift(c);
    for (;;) {
        arith_ws(c);
        if (c->s[c->i] == '<' && c->s[c->i + 1] == '=') { c->i += 2; l = l <= arith_shift(c); }
        else if (c->s[c->i] == '>' && c->s[c->i + 1] == '=') { c->i += 2; l = l >= arith_shift(c); }
        else if (c->s[c->i] == '<') { c->i++; l = l < arith_shift(c); }
        else if (c->s[c->i] == '>') { c->i++; l = l > arith_shift(c); }
        else break;
    }
    return l;
}
static long long arith_eq(arith_ctx *c) {
    long long l = arith_cmp(c);
    for (;;) {
        arith_ws(c);
        if (c->s[c->i] == '=' && c->s[c->i + 1] == '=') { c->i += 2; l = l == arith_cmp(c); }
        else if (c->s[c->i] == '!' && c->s[c->i + 1] == '=') { c->i += 2; l = l != arith_cmp(c); }
        else break;
    }
    return l;
}
static long long arith_and(arith_ctx *c) {
    long long l = arith_eq(c);
    for (;;) { arith_ws(c); if (c->s[c->i] == '&' && c->s[c->i + 1] != '&') { c->i++; l &= arith_eq(c); } else break; }
    return l;
}
static long long arith_xor(arith_ctx *c) {
    long long l = arith_and(c);
    for (;;) { arith_ws(c); if (c->s[c->i] == '^') { c->i++; l ^= arith_and(c); } else break; }
    return l;
}
static long long arith_or(arith_ctx *c) {
    long long l = arith_xor(c);
    for (;;) { arith_ws(c); if (c->s[c->i] == '|' && c->s[c->i + 1] != '|') { c->i++; l |= arith_xor(c); } else break; }
    return l;
}
static long long arith_logand(arith_ctx *c) {
    long long l = arith_or(c);
    for (;;) { arith_ws(c); if (c->s[c->i] == '&' && c->s[c->i + 1] == '&') { c->i += 2; long long r = arith_or(c); l = l && r; } else break; }
    return l;
}
static long long arith_logor(arith_ctx *c) {
    long long l = arith_logand(c);
    for (;;) { arith_ws(c); if (c->s[c->i] == '|' && c->s[c->i + 1] == '|') { c->i += 2; long long r = arith_logand(c); l = l || r; } else break; }
    return l;
}
static long long arith_expr(arith_ctx *c) { return arith_logor(c); }
int sh2poly_let(int argc, char **argv) {
    int rc = 1;
    for (int i = 0; i < argc; i++) {
        arith_ctx c = { argv[i], 0, 0 };
        long long v = arith_expr(&c);
        if (c.err) { rc = 1; continue; }
        rc = (v != 0) ? 0 : 1;   /* bash: status = last expression's truthiness */
    }
    return rc;
}

/* true / false / : — trivial */
int sh2poly_true(int argc, char **argv) { (void)argc; (void)argv; return 0; }
int sh2poly_false(int argc, char **argv) { (void)argc; (void)argv; return 1; }
int sh2poly_colon(int argc, char **argv) { (void)argc; (void)argv; return 0; }

/* cd — change directory (process-level; the backend's cwd follows). */
int sh2poly_cd(int argc, char **argv) {
    const char *dir = NULL;
    if (argc >= 1 && strcmp(argv[0], "--") == 0) dir = argc >= 2 ? argv[1] : NULL;
    else if (argc >= 1) dir = argv[0];
    if (!dir) dir = poly_getvar("HOME");
    if (!dir || !*dir) dir = "/";
    if (chdir(dir) != 0) {
        fprintf(stderr, "cd: %s: No such file or directory\n", dir);
        return 1;
    }
    return 0;
}

/* pwd — print the working directory. */
int sh2poly_pwd(int argc, char **argv) {
    (void)argc; (void)argv;
    char buf[PATH_MAX];
    if (!getcwd(buf, sizeof buf)) return 1;
    outn(buf);
    return 0;
}

/* ─── IO-bound builtins (delegate to the host's standard tools) ────── */
static int delegate(const char *tool, int argc, char **argv) {
    char **av = malloc(sizeof(char *) * ((size_t)argc + 2));
    if (!av) return 2;
    av[0] = (char *)tool;
    for (int i = 0; i < argc; i++) av[i + 1] = argv[i];
    av[argc + 1] = NULL;
    int st = run_prog(av);
    free(av);
    return st;
}
#define DELEGATE(name, tool) \
    int sh2poly_##name(int argc, char **argv) { return delegate(tool, argc, argv); }

DELEGATE(cat, "cat")
DELEGATE(cmp, "cmp")
DELEGATE(comm, "comm")
DELEGATE(cp, "cp")
DELEGATE(cut, "cut")
DELEGATE(date, "date")
DELEGATE(diff, "diff")
DELEGATE(egrep, "egrep")
DELEGATE(find, "find")
DELEGATE(grep, "grep")
DELEGATE(gunzip, "gunzip")
DELEGATE(gzip, "gzip")
DELEGATE(head, "head")
DELEGATE(hostname, "hostname")
DELEGATE(ls, "ls")
DELEGATE(mkdir, "mkdir")
DELEGATE(mktemp, "mktemp")
DELEGATE(mv, "mv")
DELEGATE(paste, "paste")
DELEGATE(readlink, "readlink")
DELEGATE(rm, "rm")
DELEGATE(rmdir, "rmdir")
DELEGATE(sed, "sed")
DELEGATE(sha256sum, "sha256sum")
DELEGATE(sha512sum, "sha512sum")
DELEGATE(sort, "sort")
DELEGATE(stat, "stat")
DELEGATE(tail, "tail")
DELEGATE(tee, "tee")
DELEGATE(touch, "touch")
DELEGATE(tr, "tr")
DELEGATE(uname, "uname")
DELEGATE(uniq, "uniq")
DELEGATE(wc, "wc")
DELEGATE(which, "which")
DELEGATE(whoami, "whoami")

/* ─── shell-state builtins (via the host callbacks) ────────────────── */

/* export — name=value or name (mark exported); no args → print all. */
int sh2poly_export(int argc, char **argv) {
    if (argc == 0) {
        extern char **environ;
        for (char **e = environ; *e; e++) outn(*e);
        return 0;
    }
    for (int i = 0; i < argc; i++) {
        const char *a = argv[i];
        if (strcmp(a, "-p") == 0) continue;
        if (strcmp(a, "-n") == 0) continue;
        const char *eq = strchr(a, '=');
        if (eq) {
            char *name = strndup(a, (size_t)(eq - a));
            poly_setvar(name, eq + 1);
            free(name);
        } else {
            const char *v = poly_getvar(a);
            if (v) poly_setvar(a, v);
        }
    }
    return 0;
}

/* declare / typeset / local / readonly — name=value assignments via
 * the store; no args → print the store (getvar over a known list is
 * backend-specific, so print nothing beyond the assignments). */
static int assign_builtin(int argc, char **argv) {
    for (int i = 0; i < argc; i++) {
        const char *a = argv[i];
        if (*a == '-') continue; /* flags: -x -r -a -i ... accepted */
        const char *eq = strchr(a, '=');
        if (eq) {
            char *name = strndup(a, (size_t)(eq - a));
            poly_setvar(name, eq + 1);
            free(name);
        }
    }
    return 0;
}
int sh2poly_declare(int argc, char **argv) { return assign_builtin(argc, argv); }
int sh2poly_typeset(int argc, char **argv) { return assign_builtin(argc, argv); }
int sh2poly_local(int argc, char **argv) { return assign_builtin(argc, argv); }
int sh2poly_readonly(int argc, char **argv) { return assign_builtin(argc, argv); }

/* set — no args → print the store (via environ); flags accepted;
 * name=value → setvar; other args → set positional params. */
int sh2poly_set(int argc, char **argv) {
    if (argc == 0) {
        extern char **environ;
        for (char **e = environ; *e; e++) outn(*e);
        return 0;
    }
    int pi = 1;
    for (int i = 0; i < argc; i++) {
        const char *a = argv[i];
        if (*a == '-') continue;
        const char *eq = strchr(a, '=');
        if (eq) {
            char *name = strndup(a, (size_t)(eq - a));
            poly_setvar(name, eq + 1);
            free(name);
        } else {
            poly_setpos(pi++, a);
        }
    }
    return 0;
}

/* shift — drop the first N positional params (default 1). */
int sh2poly_shift(int argc, char **argv) {
    int n = argc >= 1 ? atoi(argv[0]) : 1;
    if (n < 0) n = 0;
    int cnt = poly_poscount();
    for (int i = 1; i + n <= cnt; i++) {
        const char *v = poly_getpos(i + n);
        poly_setpos(i, v ? v : "");
    }
    for (int i = cnt - n + 1; i <= cnt; i++) poly_setpos(i, NULL);
    return 0;
}

/* unset — remove variables. */
int sh2poly_unset(int argc, char **argv) {
    for (int i = 0; i < argc; i++) {
        if (*argv[i] == '-') continue;
        poly_setvar(argv[i], NULL);
    }
    return 0;
}

/* eval — evaluate the args as shell code via the host shell. */
int sh2poly_eval(int argc, char **argv) {
    if (argc == 0) return 0;
    size_t len = 1;
    for (int i = 0; i < argc; i++) len += strlen(argv[i]) + 1;
    char *cmd = malloc(len);
    if (!cmd) return 2;
    cmd[0] = 0;
    for (int i = 0; i < argc; i++) {
        if (i) strcat(cmd, " ");
        strcat(cmd, argv[i]);
    }
    char *av[] = { "sh", "-c", cmd, NULL };
    int st = run_prog(av);
    free(cmd);
    return st;
}

/* source / . — run a script file in the current shell (via the host
 * shell; the state pull is the backend's concern). */
static int source_builtin(int argc, char **argv) {
    if (argc < 1) return 2;
    char **av = malloc(sizeof(char *) * ((size_t)argc + 3));
    if (!av) return 2;
    av[0] = "sh"; av[1] = argv[0];
    for (int i = 1; i < argc; i++) av[i + 1] = argv[i];
    av[argc + 1] = NULL;
    int st = run_prog(av);
    free(av);
    return st;
}
int sh2poly_source(int argc, char **argv) { return source_builtin(argc, argv); }
int sh2poly_dot(int argc, char **argv) { return source_builtin(argc, argv); }

/* trap — accept and no-op (the backend owns signal state). */
int sh2poly_trap(int argc, char **argv) { (void)argc; (void)argv; return 0; }

/* type — report how a name would be interpreted. Native-C builtins are
 * "shell builtins"; the delegating IO builtins resolve via PATH (like
 * bash, where ls/cat/grep are external commands). */
static int is_native_builtin(const char *n) {
    static const char *native[] = {
        "echo", "printf", "seq", "let", "true", "false", ":", "cd", "pwd",
        "export", "declare", "typeset", "local", "readonly", "set", "shift",
        "unset", "eval", "source", ".", "trap", "type", "return", "break",
        "continue", "read", "readarray", "mapfile", "exit", NULL
    };
    for (int i = 0; native[i]; i++) if (strcmp(native[i], n) == 0) return 1;
    return 0;
}
int sh2poly_type(int argc, char **argv) {
    int rc = 0;
    for (int i = 0; i < argc; i++) {
        const char *n = argv[i];
        if (is_native_builtin(n)) { printf("%s is a shell builtin\n", n); continue; }
        /* PATH search */
        const char *path = poly_getvar("PATH");
        if (!path) path = "/usr/bin:/bin";
        char *p = strdup(path);
        int found = 0;
        for (char *d = strtok(p, ":"); d; d = strtok(NULL, ":")) {
            char full[PATH_MAX];
            snprintf(full, sizeof full, "%s/%s", d, n);
            if (access(full, X_OK) == 0) { printf("%s is %s\n", n, full); found = 1; break; }
        }
        free(p);
        if (!found) { printf("%s: not found\n", n); rc = 1; }
    }
    return rc;
}

/* return / break / continue — control-flow markers. The caller (the
 * transpiled program's loop/function machinery) interprets the code. */
int sh2poly_return(int argc, char **argv) { return argc >= 1 ? atoi(argv[0]) : 0; }
int sh2poly_break(int argc, char **argv) { (void)argc; (void)argv; return 0; }
int sh2poly_continue(int argc, char **argv) { (void)argc; (void)argv; return 0; }

/* read — read a line from stdin, split on IFS, assign to the named
 * vars (last var gets the rest). -r (raw) accepted. */
int sh2poly_read(int argc, char **argv) {
    int raw = 0;
    int i = 0;
    if (argc > 0 && strcmp(argv[0], "-r") == 0) { raw = 1; i = 1; }
    (void)raw;
    if (i >= argc) return 2;
    char *line = read_all_stdin();
    if (!line) return 1;
    /* strip one trailing newline */
    size_t l = strlen(line);
    if (l && line[l - 1] == '\n') line[--l] = 0;
    /* split on whitespace (IFS default) */
    int nvars = argc - i;
    char *save = NULL;
    char *tok = strtok_r(line, " \t\n", &save);
    int v = 0;
    for (; tok && v < nvars - 1; v++) {
        poly_setvar(argv[i + v], tok);
        tok = strtok_r(NULL, " \t\n", &save);
    }
    if (v < nvars) {
        /* last var gets the rest of the line */
        const char *rest = tok ? tok : "";
        if (tok) {
            /* rejoin remaining tokens */
            char *r = strdup(tok);
            char *t2;
            while ((t2 = strtok_r(NULL, " \t\n", &save))) {
                size_t rl = strlen(r), tl = strlen(t2);
                r = realloc(r, rl + tl + 2);
                memcpy(r + rl, " ", 1);
                memcpy(r + rl + 1, t2, tl + 1);
            }
            poly_setvar(argv[i + v], r);
            free(r);
        } else {
            poly_setvar(argv[i + v], rest);
        }
    }
    free(line);
    return 0;
}

/* readarray / mapfile — read stdin lines into an array (via setvar
 * with name[i] keys; the backend's array store interprets them). */
static int readarray_builtin(int argc, char **argv) {
    int i = 0;
    if (argc > 0 && strcmp(argv[0], "-t") == 0) i = 1;
    if (i >= argc) return 2;
    const char *name = argv[i];
    char *line = read_all_stdin();
    if (!line) return 1;
    int idx = 0;
    char *save = NULL;
    for (char *tok = strtok_r(line, "\n", &save); tok; tok = strtok_r(NULL, "\n", &save), idx++) {
        char key[512];
        snprintf(key, sizeof key, "%s[%d]", name, idx);
        poly_setvar(key, tok);
    }
    char key[512];
    snprintf(key, sizeof key, "%s_len", name);
    char lenb[32];
    snprintf(lenb, sizeof lenb, "%d", idx);
    poly_setvar(key, lenb);
    free(line);
    return 0;
}
int sh2poly_readarray(int argc, char **argv) { return readarray_builtin(argc, argv); }
int sh2poly_mapfile(int argc, char **argv) { return readarray_builtin(argc, argv); }

/* ─── dispatch ──────────────────────────────────────────────────────── */
typedef struct { const char *name; int (*fn)(int, char **); } sh2poly_entry;

const sh2poly_entry sh2poly_table[] = {
    { "exec", sh2poly_exec }, { "capture", sh2poly_capture },
    { "fs_read", sh2poly_fs_read }, { "fs_write", sh2poly_fs_write },
    { "fs_stat", sh2poly_fs_stat }, { "pipeline", sh2poly_pipeline },
    { "redirect", sh2poly_redirect }, { "background", sh2poly_background },
    { "subshell", sh2poly_subshell }, { "exit", sh2poly_exit },
    { "echo", sh2poly_echo }, { "printf", sh2poly_printf },
    { "seq", sh2poly_seq }, { "let", sh2poly_let },
    { "true", sh2poly_true }, { "false", sh2poly_false },
    { ":", sh2poly_colon }, { "cd", sh2poly_cd }, { "pwd", sh2poly_pwd },
    { "cat", sh2poly_cat }, { "cmp", sh2poly_cmp }, { "comm", sh2poly_comm },
    { "cp", sh2poly_cp }, { "cut", sh2poly_cut }, { "date", sh2poly_date },
    { "diff", sh2poly_diff }, { "egrep", sh2poly_egrep },
    { "find", sh2poly_find }, { "grep", sh2poly_grep },
    { "gunzip", sh2poly_gunzip }, { "gzip", sh2poly_gzip },
    { "head", sh2poly_head }, { "hostname", sh2poly_hostname },
    { "ls", sh2poly_ls }, { "mkdir", sh2poly_mkdir },
    { "mktemp", sh2poly_mktemp }, { "mv", sh2poly_mv },
    { "paste", sh2poly_paste }, { "readlink", sh2poly_readlink },
    { "rm", sh2poly_rm }, { "rmdir", sh2poly_rmdir },
    { "sed", sh2poly_sed }, { "sha256sum", sh2poly_sha256sum },
    { "sha512sum", sh2poly_sha512sum }, { "sort", sh2poly_sort },
    { "stat", sh2poly_stat }, { "tail", sh2poly_tail },
    { "tee", sh2poly_tee }, { "touch", sh2poly_touch },
    { "tr", sh2poly_tr }, { "uname", sh2poly_uname },
    { "uniq", sh2poly_uniq }, { "wc", sh2poly_wc },
    { "which", sh2poly_which }, { "whoami", sh2poly_whoami },
    { "export", sh2poly_export }, { "declare", sh2poly_declare },
    { "typeset", sh2poly_typeset }, { "local", sh2poly_local },
    { "readonly", sh2poly_readonly }, { "set", sh2poly_set },
    { "shift", sh2poly_shift }, { "unset", sh2poly_unset },
    { "eval", sh2poly_eval }, { "source", sh2poly_source },
    { ".", sh2poly_dot }, { "trap", sh2poly_trap },
    { "type", sh2poly_type }, { "return", sh2poly_return },
    { "break", sh2poly_break }, { "continue", sh2poly_continue },
    { "read", sh2poly_read }, { "readarray", sh2poly_readarray },
    { "mapfile", sh2poly_mapfile },
};
const int sh2poly_table_n = (int)(sizeof sh2poly_table / sizeof sh2poly_table[0]);

/* dispatch — argv[0] = builtin name, argv[1..] = its args. Returns
 * the exit status. Unknown names return 127 (command not found). */
int sh2poly_dispatch(int argc, char **argv) {
    if (argc < 1) return 2;
    for (int i = 0; i < sh2poly_table_n; i++) {
        if (strcmp(sh2poly_table[i].name, argv[0]) == 0)
            return sh2poly_table[i].fn(argc - 1, argv + 1);
    }
    fprintf(stderr, "sh2poly: %s: command not found\n", argv[0]);
    return 127;
}

/* ─── self-test (build with -DSH2POLY_SELFTEST) ───────────────────────
 * Runs a deterministic battery; the oracle is polyfills-c-ref.sh (the
 * same battery under real bash builtins). Diff the two outputs. */
#ifdef SH2POLY_SELFTEST
static void run(const char *name, ...) {
    va_list ap;
    char *av[64];
    int argc = 0;
    av[argc++] = (char *)name;
    va_start(ap, name);
    char *a;
    while ((a = va_arg(ap, char *)) != NULL && argc < 63) av[argc++] = a;
    va_end(ap);
    printf("== %s\n", name);
    int st = sh2poly_dispatch(argc, av);
    printf("status=%d\n", st);
}
#define RUN(n, ...) run(n, ##__VA_ARGS__, NULL)

int main(void) {
    /* unbuffered stdout: child processes write to fd 1 directly, so the
     * parent's stdio buffer would reorder their output after ours */
    setvbuf(stdout, NULL, _IONBF, 0);
    /* deterministic stdin for the read/readarray tests */
    FILE *in = fopen("/tmp/sh2poly_selftest_in.txt", "w");
    if (in) { fputs("alpha beta gamma\n", in); fputs("one\ntwo\nthree\n", in); fclose(in); }
    if (!freopen("/tmp/sh2poly_selftest_in.txt", "r", stdin)) return 1;

    /* echo / printf / seq / let / true / false */
    RUN("echo", "hello", "world");
    RUN("echo", "-n", "no-newline");
    RUN("echo", "-e", "a\\tb\\n");
    RUN("printf", "%s-%d\\n", "x", "42");
    RUN("printf", "%05d\\n", "7");
    RUN("printf", "%b", "a\\tb\\n");
    RUN("printf", "%q", "a b");
    RUN("seq", "5");
    RUN("seq", "2", "2", "8");
    RUN("seq", "-s", ",", "3");
    RUN("let", "2+3*4");
    RUN("let", "10", "0");
    RUN("true");
    RUN("false");
    RUN(":");

    /* cd / pwd */
    RUN("pwd");
    RUN("cd", "/tmp");
    RUN("pwd");

    /* the seam: fs_write + fs_read + fs_stat on a temp file */
    RUN("fs_write", "/tmp/sh2poly_selftest.txt", "line1\nline2\n");
    RUN("fs_read", "/tmp/sh2poly_selftest.txt");
    RUN("fs_stat", "/tmp/sh2poly_selftest.txt");
    RUN("fs_read", "/tmp/sh2poly_missing.txt");

    /* exec / capture / pipeline / redirect */
    RUN("exec", "true");
    RUN("exec", "false");
    RUN("exec", "sh", "-c", "echo exec-ok");
    RUN("capture", "echo", "captured");
    RUN("pipeline", "echo", "hi", "|", "tr", "a-z", "A-Z");
    RUN("redirect", "1", ">", "/tmp/sh2poly_redir.txt", "echo", "redir-ok");
    RUN("fs_read", "/tmp/sh2poly_redir.txt");

    /* IO builtins (delegating) */
    RUN("wc", "-l", "/tmp/sh2poly_selftest.txt");
    RUN("head", "-1", "/tmp/sh2poly_selftest.txt");
    RUN("tail", "-1", "/tmp/sh2poly_selftest.txt");
    RUN("grep", "line", "/tmp/sh2poly_selftest.txt");
    RUN("sort", "/tmp/sh2poly_selftest.txt");
    RUN("cat", "/tmp/sh2poly_selftest.txt");
    RUN("touch", "/tmp/sh2poly_touched.txt");
    RUN("fs_stat", "/tmp/sh2poly_touched.txt");
    RUN("rm", "/tmp/sh2poly_touched.txt");
    RUN("uname");
    RUN("whoami");
    RUN("hostname");
    RUN("pwd");

    /* state builtins */
    RUN("export", "SH2POLY_TEST=hello");
    RUN("declare", "SH2POLY_DECL=world");
    RUN("unset", "SH2POLY_DECL");
    RUN("type", "echo");
    RUN("type", "ls");
    RUN("which", "ls");
    RUN("read", "SH2POLY_READVAR");
    RUN("readarray", "SH2POLY_ARR");

    /* cleanup */
    RUN("rm", "-f", "/tmp/sh2poly_selftest.txt");
    RUN("rm", "-f", "/tmp/sh2poly_redir.txt");
    RUN("rm", "-f", "/tmp/sh2poly_selftest_in.txt");
    return 0;
}
#endif /* SH2POLY_SELFTEST */
