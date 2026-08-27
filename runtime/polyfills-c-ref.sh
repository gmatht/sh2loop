#!/bin/bash
# polyfills-c-ref.sh — the self-test oracle for polyfills.c. Runs the
# same battery as the C self-test (main() under -DSH2POLY_SELFTEST)
# with REAL bash builtins, printing the same `== name` / `status=N`
# format. Diff this against the C self-test output:
#
#   cc -DSH2POLY_SELFTEST -o polyfills-selftest polyfills.c
#   ./polyfills-selftest > /tmp/c.out
#   bash polyfills-c-ref.sh > /tmp/ref.out
#   diff /tmp/ref.out /tmp/c.out
#
# Deterministic: uses fixed temp files and a fixed stdin input.
set -u
T=/tmp/sh2poly_selftest.txt
R=/tmp/sh2poly_redir.txt
IN=/tmp/sh2poly_selftest_in.txt
printf 'alpha beta gamma\none\ntwo\nthree\n' > "$IN"

run() {  # run <name> <cmd...>
  local name="$1"; shift
  printf '== %s\n' "$name"
  "$@"
  printf 'status=%d\n' "$?"
}

run echo echo hello world
run echo echo -n no-newline
run echo echo -e 'a\tb\n'
run printf printf '%s-%d\n' x 42
run printf printf '%05d\n' 7
run printf printf '%b' 'a\tb\n'
run printf printf '%q' 'a b'
run seq seq 5
run seq seq 2 2 8
run seq seq -s , 3
run let let '2+3*4'
run let let 10 0
run true true
run false false
run ':' :

run pwd pwd
run cd cd /tmp
run pwd pwd

printf 'line1\nline2\n' > "$T"
run fs_write true
run fs_read cat "$T"
run fs_stat stat -c '%s %a' "$T"
run fs_read cat /tmp/sh2poly_missing.txt

run exec true
run exec false
run exec sh -c 'echo exec-ok'
run capture echo captured
run pipeline sh -c 'echo hi | tr a-z A-Z'
run redirect sh -c 'echo redir-ok > '"$R"
run fs_read cat "$R"

run wc wc -l "$T"
run head head -1 "$T"
run tail tail -1 "$T"
run grep grep line "$T"
run sort sort "$T"
run cat cat "$T"
run touch touch /tmp/sh2poly_touched.txt
run fs_stat stat -c '%s %a' /tmp/sh2poly_touched.txt
run rm rm /tmp/sh2poly_touched.txt
run uname uname
run whoami whoami
run hostname hostname
run pwd pwd

run export export SH2POLY_TEST=hello
run declare declare SH2POLY_DECL=world
run unset unset SH2POLY_DECL
run type type echo
run type type ls
run which which ls
run read read SH2POLY_READVAR < "$IN"
run readarray readarray SH2POLY_ARR < "$IN"

run rm rm -f "$T"
run rm rm -f "$R"
run rm rm -f "$IN"
exit 0
