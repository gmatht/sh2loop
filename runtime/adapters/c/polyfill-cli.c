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
 * This file is also a standalone CLI for testing the seam:
 *
 *   ./polyfill-cli echo hello world
 *   ./polyfill-cli cat /tmp/x
 *   ./polyfill-cli seq 1 5
 *
 * Build: cc -O2 -o polyfill-cli polyfill-cli.c libsh2poly.a
 */
#include <stdio.h>
#include <string.h>

int sh2poly_dispatch(int argc, char **argv);

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s <builtin> [args...]\n", argv[0]);
        return 2;
    }
    return sh2poly_dispatch(argc - 1, argv + 1);
}
