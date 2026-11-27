/* bench-concurrency.c — the uu-ffi calling conventions, side by side.
 *
 * `bench.c` times ONE invocation at a time (fork+exec vs in-process
 * sh2_uu_run). This harness answers the two questions that leaves open,
 * because they decide which convention a *transpiled* program should use:
 *
 *   threaded  — when a script runs several utilities at once (`cmd &`,
 *               `xargs -P`), does in-process dispatch still pay, and does
 *               it scale with threads? Each worker thread runs the uu
 *               call back to back on a PRIVATE fd-1 sink (its own scratch
 *               file): fd 1 is process-wide, so the convention only works
 *               per-thread, never for sh2_uu_capture.
 *   capture   — `$(cmd ...)` goes through sh2_uu_capture: pipe + a
 *               per-call reader thread (runtime/uu_run.c). That extra
 *               plumbing is NOT timed by bench.c. Here the same argv is
 *               timed three ways:
 *                 fork-capture : fork + execv + read the pipe (what bash
 *                                does for every `$(...)`)
 *                 capture      : sh2_uu_capture   (in-process, pipe+thread)
 *                 plain        : sh2_uu_run to /dev/null (no capture; the
 *                                floor the capture cost is measured from)
 *               plus `big`, which captures ~3.9 MB (beyond the 64 KiB
 *               pipe buffer) to show the concurrent drain is required, not
 *               decoration.
 *
 * Output is CSV on stdout; arm order within a trial is rotated so a
 * drifting load average does not systematically favour one arm.
 *
 * Build (from the repo root; same link line as bench.c):
 *   cc -O3 -o /tmp/bench-uu-conc benchmarks/uu-ffi/bench-concurrency.c \
 *      sh2perl/runtime/uu_run.c -I sh2perl/runtime -L sh2perl/runtime/lib \
 *      -lcoreutils_ffi -lpthread -Wl,-rpath,$PWD/sh2perl/runtime/lib -lm
 *
 * Run:
 *   /tmp/bench-uu-conc threads  <trials> <iters> <threads>  <file>
 *   /tmp/bench-uu-conc capture  <trials> <iters>  <file>
 *   /tmp/bench-uu-conc big      <trials> <iters> <lines> <scratch-file>
 *   /tmp/bench-uu-conc --help
 *
 * Binary paths default to this machine's layout (as bench.c) and can be
 * overridden with UUBENCH_GNU_WC / UUBENCH_GNU_SORT / UUBENCH_GNU_GREP /
 * UUBENCH_UUTILS_WC / UUBENCH_UUTILS_SORT.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
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

static const char *envpath(const char *name, const char *dflt) {
    const char *v = getenv(name);
    if (v && *v && access(v, X_OK) == 0) return v;
    if (dflt && access(dflt, X_OK) == 0) return dflt;
    return NULL; /* arm unavailable on this install */
}

/* ------------------------------------------------------------------ */
/* threaded: N worker threads × iters in-process calls, private sinks  */
/*                                                                     */
/* Each worker writes its result line to ITS OWN regular file and the  */
/* parent prints them after joining. Workers must NOT touch stdout:    */
/* dup2(f, 1) leaves stdio's fd-1 flush path armed, and (measured here) */
/* that flush writes the parent's and the utilities' buffered output   */
/* to the RESTORED fd 1 — the CSV, and once an entire `sort` page,     */
/* ends up on the terminal while fstat reports the scratch file.       */
/* ------------------------------------------------------------------ */

typedef struct {
    int wfd;   /* write end of this worker's result pipe (its own file) */
    int iters;
    int argc;
    char *const *argv;
    double sec;
    long ok;   /* calls that returned 0 */
    long bad;  /* calls that returned non-zero */
    long bytes;/* bytes the utility wrote (into a scratch file; proves it ran) */
    long pad;  /* worker index, for a private scratch path */
} worker_arg;

static void *worker(void *p) {
    worker_arg *w = (worker_arg *)p;
    int tid = (int)(long)w->pad;
    /* Private sink: fd 1 is process-wide, so a thread that shared it with
     * another thread's utility would interleave output. Each worker opens
     * its OWN scratch file; its size after the loop is the "did the
     * utility actually run" evidence (/dev/null's st_size is always 0, so
     * it cannot be the evidence).
     *
     * fd 1 is never restored and no stdio runs in this function. That is
     * not tidiness: this box's glibc is LOCK-FREE stdio for single-
     * threaded programs (setvbuf(STDOUT_FILENO) takes the
     * single-thread path), so a worker's fflush/flockfile either
     * serialises every utility write on the stdout lock or aborts with "a
     * printf deadlock was detected", and restoring a per-worker `saved`
     * races another worker's dup2(sink,1). Measured: 2 threads deadlocked
     * inside redirection, and once an entire `sort` page reached the
     * terminal. So: output to the scratch file, the result line to the
     * worker's pipe, and the parent prints after join. */
    char path[64];
    snprintf(path, sizeof path, "/tmp/sh2conc.%ld.%d", (long)getpid(), tid);
    int sink = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (sink < 0) { w->sec = -1; return NULL; }
    if (dup2(sink, 1) < 0) { close(sink); w->sec = -1; return NULL; }
    close(sink);
    double t0 = mono();
    for (int i = 0; i < w->iters; i++) {
        int rc = uu_run(w->argv[0], w->argc, w->argv);
        if (rc == 0) w->ok++; else w->bad++;
    }
    w->sec = mono() - t0;
    struct stat sb;
    if (fstat(1, &sb) == 0) w->bytes = (long)sb.st_size;
    unlink(path);
    dprintf(w->wfd, "%ld %ld %ld %.6f\n", w->ok, w->bad, w->bytes, w->sec);
    close(w->wfd);
    return NULL;
}

static int cmd_threads(int trials, int iters, int nthreads, const char *file) {
    /* the utilities bench.c times, as (name, argc, argv) */
    char *av_wc[]   = { "wc", "-l", (char *)file, NULL };
    char *av_sort[] = { "sort", (char *)file, NULL };
    char *av_grep[] = { "grep", "-c", ".", (char *)file, NULL };
    struct { const char *name; int argc; char **argv; } u[3] = {
        { "wc",   3, av_wc   },
        { "sort", 2, av_sort },
        { "grep", 4, av_grep },
    };
    int outfd = dup(1);      /* printed through: workers move fd 1 around */
    if (outfd < 0) { perror("dup(1)"); return 2; }
    dprintf(outfd, "trial,util,threads,iters,wall_sec,us_per_call,"
                   "agg_calls_per_sec,calls_ok,calls_bad,sink_bytes,"
                   "load1_before/after\n");
    for (int t = 0; t < trials; t++) {
        for (int k = 0; k < 3; k++) {
            int ui = (k + t) % 3;                 /* rotate the arm order */
            int *rfd = calloc((size_t)nthreads, sizeof *rfd);
            worker_arg *wa = calloc((size_t)nthreads, sizeof *wa);
            pthread_t *th = calloc((size_t)nthreads, sizeof *th);
            for (int j = 0; j < nthreads; j++) {
                int pf[2];
                if (pipe(pf) != 0) return 2;
                rfd[j] = pf[0];
                wa[j].wfd = pf[1];
                wa[j].iters = iters;
                wa[j].argc = u[ui].argc;
                wa[j].argv = u[ui].argv;
            }
            double l0 = load1();
            for (int j = 0; j < nthreads; j++)
                pthread_create(&th[j], NULL, worker, &wa[j]);
            long ok = 0, bad = 0, bytes = 0;
            double worst = 0, sum = 0;
            for (int j = 0; j < nthreads; j++) {
                pthread_join(th[j], NULL);
                /* the parent reads each worker's result, never fd 1.
                 * Read FIRST, then join: the worker's write end is closed
                 * only when it returns, so the read sees EOF after the
                 * worker's line (closing our copy before the join and
                 * then reading is what hung the first version — and
                 * closing after the join threw the line away, which is
                 * why every row read ok=0). */
                char buf[128];
                int fd = rfd[j];
                ssize_t n = 0, r;
                while (n < (ssize_t)sizeof buf - 1 &&
                       (r = read(fd, buf + n, sizeof buf - 1 - n)) > 0) n += r;
                buf[n] = 0;
                close(fd);
                pthread_join(th[j], NULL);
                long o = 0, b = 0, by = 0; double sec = -1;
                if (sscanf(buf, "%ld %ld %ld %lf", &o, &b, &by, &sec) == 4) {
                    ok += o; bad += b; bytes += by;
                    sum += sec;
                    if (sec > worst) worst = sec;
                }
            }
            double calls = (double)nthreads * (double)iters;
            /* wall is the slowest worker's own loop (not spawn+join); the
             * aggregate rate divides total calls by it. */
            double us = worst > 0 ? worst / iters * 1e6 : -1;
            dprintf(outfd, "%d,%s,%d,%d,%.6f,%.2f,%.0f,%ld,%ld,%ld,%.2f/%.2f\n",
                    t, u[ui].name, nthreads, iters, worst, us,
                    worst > 0 ? calls / worst : -1, ok, bad, bytes, l0, load1());
            free(rfd); free(wa); free(th);
        }
    }
    close(outfd);
    return 0;
}

/* ------------------------------------------------------------------ */
/* capture: fork+exec+read vs sh2_uu_capture vs plain uu_run           */
/* ------------------------------------------------------------------ */

/* fork, execv the file, read everything the child writes. Returns bytes. */
static long fork_capture(const char *path, char *const *argv, char *buf, size_t cap) {
    int pfd[2];
    if (pipe(pfd) != 0) return -1;
    pid_t pid = fork();
    if (pid < 0) { close(pfd[0]); close(pfd[1]); return -1; }
    if (pid == 0) {
        close(pfd[0]);
        dup2(pfd[1], 1);
        close(pfd[1]);
        int dn = open("/dev/null", O_WRONLY);
        if (dn >= 0) { dup2(dn, 2); close(dn); }
        execv(path, argv);
        _exit(127);
    }
    close(pfd[1]);
    size_t n = 0;
    while (n < cap) {
        ssize_t r = read(pfd[0], buf + n, cap - n - 1);
        if (r < 0) { if (errno == EINTR) continue; break; }
        if (r == 0) break;
        n += (size_t)r;
    }
    close(pfd[0]);
    int st = 0;
    while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
    buf[n] = 0;
    return (long)n;
}

/* one in-process call to /dev/null (the no-capture floor). */
static void plain_uu(char *const *argv) {
    fflush(stdout);
    int saved = dup(1);
    int dn = open("/dev/null", O_WRONLY);
    if (saved < 0 || dn < 0) { if (saved >= 0) close(saved); if (dn >= 0) close(dn); return; }
    dup2(dn, 1);
    close(dn);
    uu_run(argv[0], (int)({ int c = 0; while (argv[c]) c++; c; }), argv);
    dup2(saved, 1);
    close(saved);
}

static int cmd_capture(int trials, int iters, const char *file) {
    const char *gnu_wc   = envpath("UUBENCH_GNU_WC", "/usr/bin/gnuwc");
    const char *gnu_sort = envpath("UUBENCH_GNU_SORT", "/usr/bin/gnusort");
    const char *gnu_grep = envpath("UUBENCH_GNU_GREP", "/usr/bin/grep");
    char *av_wc[]   = { "wc", "-l", (char *)file, NULL };
    char *av_sort[] = { "sort", (char *)file, NULL };
    char *av_grep[] = { "grep", "-c", ".", (char *)file, NULL };
    struct { const char *name; char **argv; const char *forkpath; } u[3] = {
        { "wc",   av_wc,   gnu_wc   },
        { "sort", av_sort, gnu_sort },
        { "grep", av_grep, gnu_grep },
    };
    size_t cap = 1 << 20;                      /* 1 MiB, as the corpus gate */
    char *buf = malloc(cap);
    printf("trial,util,arm,iters,sec,us_per_call,bytes,load1\n");
    for (int t = 0; t < trials; t++) {
        for (int k = 0; k < 3; k++) {
            int ui = (k + t) % 3;
            for (int arm = 0; arm < 3; arm++) {
                const char *an = arm == 0 ? "fork-capture" : arm == 1 ? "capture" : "plain";
                if (arm == 0 && !u[ui].forkpath) continue;
                long bytes = 0;
                double l0 = load1();
                double t0 = mono();
                for (int i = 0; i < iters; i++) {
                    if (arm == 0)      bytes = fork_capture(u[ui].forkpath, u[ui].argv, buf, cap);
                    else if (arm == 1) {
                        size_t n = 0;
                        sh2_uu_capture((int)({ int c = 1; while (u[ui].argv[c]) c++; c; }),
                                       u[ui].argv, buf, cap, &n);
                        bytes = (long)n;
                    } else             plain_uu(u[ui].argv);
                }
                double sec = mono() - t0;
                printf("%d,%s,%s,%d,%.6f,%.2f,%ld,%.2f\n", t, u[ui].name, an, iters,
                       sec, sec / iters * 1e6, arm == 2 ? -1 : bytes, l0);
            }
        }
    }
    free(buf);
    return 0;
}

/* ------------------------------------------------------------------ */
/* big: capture 4 MiB (beyond the pipe buffer) — the deadlock control  */
/* ------------------------------------------------------------------ */

static int cmd_big(int trials, int iters, int lines, const char *scratch) {
    FILE *f = fopen(scratch, "w");
    if (!f) { fprintf(stderr, "cannot write %s\n", scratch); return 2; }
    for (int i = 0; i < lines; i++) fprintf(f, "%07d aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n", i);
    fclose(f);
    /* one `cat scratch` writes ~36-40 bytes/line; 100000 lines > 64 KiB. */
    char *av[] = { "cat", (char *)scratch, NULL };
    size_t cap = 8u << 20;
    char *buf = malloc(cap);
    printf("trial,arm,iters,sec,bytes,load1\n");
    for (int t = 0; t < trials; t++) {
        for (int arm = 0; arm < 2; arm++) {
            size_t n = 0;
            double l0 = load1();
            double t0 = mono();
            for (int i = 0; i < iters; i++) {
                if (arm == 0) n = (size_t)fork_capture("/usr/bin/cat", av, buf, cap);
                else          sh2_uu_capture(2, av, buf, cap, &n);
            }
            double sec = mono() - t0;
            printf("%d,%s,%d,%.6f,%zu,%.2f\n", t, arm == 0 ? "fork-capture" : "capture",
                   iters, sec, n, l0);
        }
    }
    free(buf);
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 2 || !strcmp(argv[1], "--help")) {
        fprintf(stderr,
            "usage: %s threads <trials> <iters> <threads> <file>\n"
            "       %s capture <trials> <iters> <file>\n"
            "       %s big     <trials> <iters> <lines> <scratch-file>\n",
            argv[0], argv[0], argv[0]);
        return argc < 2 ? 2 : 0;
    }
    if (!strcmp(argv[1], "threads") && argc == 6)
        return cmd_threads(atoi(argv[2]), atoi(argv[3]), atoi(argv[4]), argv[5]);
    if (!strcmp(argv[1], "capture") && argc == 5)
        return cmd_capture(atoi(argv[2]), atoi(argv[3]), argv[4]);
    if (!strcmp(argv[1], "big") && argc == 6)
        return cmd_big(atoi(argv[2]), atoi(argv[3]), atoi(argv[4]), argv[5]);
    fprintf(stderr, "%s: bad arguments (try --help)\n", argv[0]);
    return 2;
}
