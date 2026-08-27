/*
 * polyfill-cli.c — the C backend's thin adapter for the C polyfills.
 *
 * Maps the sh2.* call-site convention (builtin name + args) to the
 * polyfill functions: `sh2poly_dispatch(argc, argv)` with argv[0] =
 * the builtin name. A transpiled C program (the C backend's output)
 * links libsh2poly.a and calls this for every builtin it lowers to the
 * runtime seam — the same role the bash polyfills' adapter plays for
 * the transpiled bash functions (runtime/README.md §4).
 *
 * Two modes:
 *   ./polyfill-cli <builtin> [args...]   — one call
 *   ./polyfill-cli --battery             — run adapters/battery.txt
 *     (TAB-separated fields, `\\` → backslash, `\n` → newline; prints
 *     the C self-test format `== name` / `status=N`)
 *
 * Build: cc -O2 -o polyfill-cli polyfill-cli.c libsh2poly.a
 */
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>

int sh2poly_init(void);
int sh2poly_dispatch(int argc, char **argv);

static char *unescape(const char *f) {
    size_t n = strlen(f);
    char *out = malloc(n + 1);
    size_t o = 0;
    for (size_t i = 0; i < n; i++) {
        if (f[i] == '\\' && i + 1 < n) {
            switch (f[i + 1]) {
                case '\\': out[o++] = '\\'; i++; break;
                case 'n': out[o++] = '\n'; i++; break;
                case 't': out[o++] = '\t'; i++; break;
                default: out[o++] = '\\'; break;
            }
        } else out[o++] = f[i];
    }
    out[o] = 0;
    return out;
}

static int run_battery(void) {
    sh2poly_init();
    /* deterministic stdin for the read/readarray calls */
    FILE *in = fopen("/tmp/sh2poly_selftest_in.txt", "w");
    if (in) { fputs("alpha beta gamma\none\ntwo\nthree\n", in); fclose(in); }
    int fd = open("/tmp/sh2poly_selftest_in.txt", O_RDONLY);
    if (fd >= 0) { dup2(fd, 0); close(fd); }

    FILE *bat = fopen("adapters/battery.txt", "r");
    if (!bat) bat = fopen("battery.txt", "r");
    if (!bat) { fprintf(stderr, "polyfill-cli: battery.txt not found\n"); return 2; }
    char line[8192];
    while (fgets(line, sizeof line, bat)) {
        char *nl = strchr(line, '\n');
        if (nl) *nl = 0;
        char *t = line;
        while (*t == ' ' || *t == '\t') t++;
        if (!*t || *t == '#') continue;
        /* split on TAB */
        char *fields[256];
        int nf = 0;
        char *p = t;
        fields[nf++] = p;
        for (; *p; p++) if (*p == '\t') { *p = 0; fields[nf++] = p + 1; }
        char *argv[256];
        int argc = 0;
        argv[argc++] = fields[0];
        for (int i = 1; i < nf; i++) argv[argc++] = unescape(fields[i]);
        argv[argc] = NULL;
        printf("== %s\n", argv[0]);
        int st = sh2poly_dispatch(argc, argv);
        printf("status=%d\n", st);
        for (int i = 1; i < argc; i++) free(argv[i]);
    }
    fclose(bat);
    return 0;
}

int main(int argc, char **argv) {
    if (argc >= 2 && strcmp(argv[1], "--battery") == 0) return run_battery();
    if (argc < 2) {
        fprintf(stderr, "usage: %s <builtin> [args...] | %s --battery\n", argv[0], argv[0]);
        return 2;
    }
    sh2poly_init();
    return sh2poly_dispatch(argc - 1, argv + 1);
}
