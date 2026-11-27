/* bench.c — fork+exec vs in-process uu_run for coreutils commands.
 *
 * Measures the claim behind uu-ffi: that replacing `fork`+`execv` of a
 * utility with a call into libcoreutils_ffi removes the process, not just
 * some of its work. Three arms, same argv, same sink:
 *
 *   fork-uutils : execv the uutils binary (the distro multicall image)
 *   fork-gnu    : execv the GNU binary (gnuwc / gnusort / grep)
 *   inproc      : sh2_uu_run() from runtime/uu_run.c + libcoreutils_ffi
 *
 * Both fork arms redirect the child's stdout to /dev/null; the in-process
 * arm redirects its own fd 1 once, outside the timed loop, which is what a
 * generated program does (a captured substitution goes through
 * sh2_uu_capture instead, and is NOT timed here).
 *
 * Build (from the repo root):
 *   cc -O2 -o bench-uu-ffi benchmarks/uu-ffi/bench.c sh2perl/runtime/uu_run.c \
 *      -I sh2perl/runtime -L sh2perl/runtime/lib -lcoreutils_ffi -lpthread \
 *      -Wl,-rpath,$PWD/sh2perl/runtime/lib -lm
 *
 * Run:
 *   ./bench-uu-ffi 2000 10 benchmarks/uu-ffi/input.txt   # trial matrix, CSV
 *   ./bench-uu-ffi --exec /bin/true 2000                # fork+exec floor
 *   ./bench-uu-ffi --dump wc input.txt out.wc           # in-process stdout
 *   ./bench-uu-ffi --capture wc input.txt               # rc + byte count
 *
 * Paths default to this machine's layout and can be overridden:
 *   UUBENCH_UUTILS_WC, UUBENCH_UUTILS_SORT,
 *   UUBENCH_GNU_WC, UUBENCH_GNU_SORT, UUBENCH_GNU_GREP
 * An arm whose binary is missing is skipped and named in the CSV header.
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <time.h>
#include "uu_run.h"

static double mono(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static double load1(void) {
    FILE *f = fopen("/proc/loadavg", "r");
    double v = -1.0;
    if (f) { if (fscanf(f, "%lf", &v) != 1) v = -1.0; fclose(f); }
    return v;
}

struct arm { const char *name; const char *path; };

struct util {
    const char *name;
    int ac;
    char *av[5];
    struct arm arms[3];
    int narm;
};

static const char *envpath(const char *var, const char *def) {
    const char *v = getenv(var);
    if (v && *v) return v;
    if (def && access(def, X_OK) == 0) return def;
    return NULL;
}

static void add_arm(struct util *u, const char *name, const char *path) {
    if (!path) return;
    u->arms[u->narm].name = name;
    u->arms[u->narm].path = path;
    u->narm++;
}

static int run_fork(const char *path, char *const av[], int n) {
    for (int i = 0; i < n; i++) {
        pid_t p = fork();
        if (p < 0) { perror("fork"); return -1; }
        if (p == 0) {
            int fd = open("/dev/null", O_WRONLY);
            if (fd >= 0) { dup2(fd, 1); close(fd); }
            execv(path, av);
            _exit(127);
        }
        int st;
        if (waitpid(p, &st, 0) < 0) return -1;
        if (!WIFEXITED(st) || WEXITSTATUS(st) != 0) {
            fprintf(stderr, "fork arm %s exited %d\n", path,
                    WIFEXITED(st) ? WEXITSTATUS(st) : -1);
            return -1;
        }
    }
    return 0;
}

/* redirect this process's stdout to /dev/null, return the saved fd or -1 */
static int sink_stdout(void) {
    int saved = dup(1), fd = open("/dev/null", O_WRONLY);
    if (saved < 0 || fd < 0) { perror("dup/open"); return -1; }
    dup2(fd, 1);
    close(fd);
    return saved;
}

static void restore_stdout(int saved) {
    if (saved >= 0) { dup2(saved, 1); close(saved); }
}

/* in-process arm for the loop: every call runs; a non-zero rc is counted
 * (a utility may legitimately exit non-zero, e.g. grep with no match), not
 * treated as an error — run_uu() below stops at the first failing call. */
static int run_uu_all(int ac, char *const av[], int n, long *nonzero) {
    for (int i = 0; i < n; i++) {
        if (sh2_uu_run(ac, av) != 0 && nonzero) (*nonzero)++;
    }
    return 0;
}


int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr,
                "usage: %s <iters> <trials> <file>\n"
                "       %s --exec <path> <iters> [args...]\n"
                "       %s --dump <util> <file> <out>\n"
                "       %s --capture <util> <file>\n", argv[0], argv[0], argv[0], argv[0]);
        return 2;
    }

    /* fork+exec of a trivial binary: the floor under every fork arm */
    if (strcmp(argv[1], "--exec") == 0 && argc >= 4) {
        char *av[8]; int k = 0;
        av[k++] = argv[2];
        for (int i = 4; i < argc && k < 7; i++) av[k++] = argv[i];
        av[k] = NULL;
        int n = atoi(argv[3]);
        if (run_fork(argv[2], av, 50) != 0) return 3;
        double t0 = mono();
        if (run_fork(argv[2], av, n) != 0) return 3;
        printf("exec %s %d %.6f\n", argv[2], n, mono() - t0);
        return 0;
    }

    int capture_mode = strcmp(argv[1], "--capture") == 0;
    int dump_mode = strcmp(argv[1], "--dump") == 0;
    int iters = (capture_mode || dump_mode) ? 1 : atoi(argv[1]);
    int trials = (capture_mode || dump_mode) ? 1 : atoi(argv[2]);
    const char *file = (capture_mode || dump_mode) ? argv[3] : argv[3];

    struct util utils[3];
    memset(utils, 0, sizeof utils);

    utils[0].name = "wc";
    utils[0].ac = 3;
    utils[0].av[0] = "wc"; utils[0].av[1] = "-l"; utils[0].av[2] = (char *)file;

    utils[1].name = "sort";
    utils[1].ac = 2;
    utils[1].av[0] = "sort"; utils[1].av[1] = (char *)file;

    utils[2].name = "grep";
    utils[2].ac = 4;
    utils[2].av[0] = "grep"; utils[2].av[1] = "-c"; utils[2].av[2] = ".";
    utils[2].av[3] = (char *)file;

    add_arm(&utils[0], "fork-uutils", envpath("UUBENCH_UUTILS_WC", "/usr/lib/cargo/bin/coreutils/wc"));
    add_arm(&utils[0], "fork-gnu", envpath("UUBENCH_GNU_WC", "/usr/bin/gnuwc"));
    add_arm(&utils[1], "fork-uutils", envpath("UUBENCH_UUTILS_SORT", "/usr/lib/cargo/bin/coreutils/sort"));
    add_arm(&utils[1], "fork-gnu", envpath("UUBENCH_GNU_SORT", "/usr/bin/gnusort"));
    add_arm(&utils[2], "fork-gnu", envpath("UUBENCH_GNU_GREP", "/usr/bin/grep"));

    for (int i = 0; i < 3; i++) add_arm(&utils[i], "inproc", "inproc");

    int which = -1;
    for (int i = 0; i < 3; i++) if (strcmp(utils[i].name, argv[2]) == 0) which = i;

    if (capture_mode || dump_mode) {
        if (which < 0) { fprintf(stderr, "unknown util %s\n", argv[2]); return 2; }
        struct util *u = &utils[which];
        char buf[65536]; size_t len = 0;
        int rc = sh2_uu_capture(u->ac, u->av, buf, sizeof buf, &len);
        if (dump_mode && argc >= 5) {
            FILE *o = fopen(argv[4], "wb");
            if (!o) { perror(argv[4]); return 2; }
            fwrite(buf, 1, len, o);
            fclose(o);
        }
        fprintf(stderr, "%s rc=%d bytes=%zu\n", u->name, rc, len);
        return rc;
    }

    printf("trial,util,arm,iters,sec,us_per_call,nonzero,load1_before/after\n");
    for (int i = 0; i < 3; i++) {
        for (int a = 0; a < utils[i].narm; a++)
            fprintf(stderr, "# arm %s %s\n", utils[i].name, utils[i].arms[a].path);
    }
    fflush(stdout);

    for (int t = 0; t < trials; t++) {
        for (int i = 0; i < 3; i++) {
            struct util *u = &utils[i];
            struct arm order[3];
            memcpy(order, u->arms, sizeof order);

            /* alternate arm order per trial so drift cannot favour one arm */
            if (t % 2 && u->narm > 1) {
                for (int a = 0; a < u->narm / 2; a++) {
                    struct arm tmp = order[a];
                    order[a] = order[u->narm - 1 - a];
                    order[u->narm - 1 - a] = tmp;
                }
            }

            for (int a = 0; a < u->narm; a++) {
                int is_uu = strcmp(order[a].name, "inproc") == 0;

                /* warmup, untimed */
                if (is_uu) {
                    int saved = sink_stdout();
                    long z = 0;
                    if (run_uu_all(u->ac, u->av, 50, &z) != 0) return 3;
                    restore_stdout(saved);
                } else {
                    if (run_fork(order[a].path, u->av, 50) != 0) return 3;
                }

                double l0 = load1(), t0, dt;
                long nonzero = -1;
                if (is_uu) {
                    int saved = sink_stdout();
                    nonzero = 0;
                    t0 = mono();
                    if (run_uu_all(u->ac, u->av, iters, &nonzero) != 0) return 3;
                    dt = mono() - t0;
                    restore_stdout(saved);
                } else {
                    t0 = mono();
                    if (run_fork(order[a].path, u->av, iters) != 0) return 3;
                    dt = mono() - t0;
                }
                printf("%d,%s,%s,%d,%.6f,%.2f,%ld,%.2f/%.2f\n",
                       t, u->name, order[a].name, iters, dt,
                       dt / iters * 1e6, nonzero, l0, load1());
                fflush(stdout);
            }
        }
    }
    return 0;
}
