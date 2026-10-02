# C backend: two pre-existing leaks (getcwd + print_chars), reproduced on x86_64 and aarch64

## NEED
Two definite leaks in emitted C. Neither is new — both reproduce on
`main` and on x86_64 valgrind, so they predate the `gcc -fanalyzer` work
(`963a992f3`, `ce784092d`). They are the *only* valgrind findings left on
aarch64 after those fixes: 40/40 programs compile and run with 0 stdout
mismatches, 0 invalid accesses, and 12 of 40 leak.

## EVIDENCE

`10.42.0.1` (aarch64, valgrind 3.22.0), `harness/c_valgrind.sh` criteria
(`--error-exitcode=99 --leak-check=full --errors-for-leak-kinds=definite,possible`),
40 corpus examples, rendered with `SH2_UU_FFI=0`:

    compiled      : 40  (cc failures: 0)
    ran           : 40  (stdout/exit mismatches vs bash: 0)
    valgrind runs : 40  (MEMORY failures: 12)

    Invalid read/write/free | Mismatched | uninitialised : 0
    definitely lost: 22 bytes in 2 blocks   x11
    definitely lost: 18 bytes in 9 blocks   x1

Both also reproduce locally on x86_64 with the same byte counts, so this
is a renderer defect and not an aarch64/valgrind-version artifact.

### Leak 1 — `getcwd(0, 0)` (11 files, 22 bytes)

The emitted `chdir` helper (c_backend.rs:18114):

    ({{ int _r = chdir({dir}); _sh_rc = (_r == 0 ? 0 : 1);
       if (_r == 0) setenv("PWD", getcwd(0, 0), 1); _r == 0; }})

POSIX: with a NULL buffer `getcwd` allocates; glibc uses `realloc`, so
valgrind attributes it to `getcwd.c:86` rather than `malloc`. Nothing
frees it. 44 such sites across the sample.

Fix shape: hoist a buffer and free it, e.g.

    char _sh_cwd[4096]; if (getcwd(_sh_cwd, sizeof _sh_cwd)) setenv("PWD", _sh_cwd, 1);

(a fixed buffer also avoids a heap allocation per `cd`), or malloc+free
around the existing call.

### Leak 2 — `_sh_xstrdup` in `print_chars` (1 file, 18 bytes / 9 blocks)

`011_substring_loop_param.c:60`:

    static _sh_vbuf _v7 = {0, 0};
    _sh_substr(&_v7, _v4.p, (long long)atoll(_v5.p), 1);
    ch = _sh_xstrdup((char*)(_v7.p));
    (_sh_rc = 0, printf("%s", (ch ? ch : "")));

`ch` is never freed, and the loop body runs 9 times, so it accumulates.
This looks like the general shape of "assign `_sh_xstrdup(...)` to a
scalar for printing" — worth checking whether other render sites have the
same pattern rather than fixing this one call site.

## IMPACT
Gate-facing: `harness/c_valgrind.sh` treats a definite leak as a memory
failure, so every example containing a `cd` stays red in that gate. On the
`c` backend gate's own 25-file valgrind sample these are the remaining
findings once the fd fixes land.

## NOTE FOR WHOEVER PICKS THIS UP
Do not fix by suppressing valgrind's leak kinds — the existing flag set
(`definite,possible`) is already correct and these are real. This is the
"leak class the analyzer gate deliberately excludes as advisory"
(`harness/c-fanalyze.sh` STRICT): a one-shot transpiled program is not
required to be leak-free, so `-Wanalyzer-malloc-leak` is style. These two
are still worth fixing — they are unbounded in a loop (leak 2) and one
allocation per `cd` (leak 1), not a fixed startup footprint.