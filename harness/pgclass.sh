#!/bin/bash
# Classify generator output for a list of examples: emit the generator's
# stderr, whether the emitted Perl contains a `die` guard, and the first
# Perl RUNTIME error (message + line).
#   harness/pgclass.sh -l <list>
set -u
root="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
bin="$root/otranspilerl/target/debug/otranspilerl-cli"
export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"
list="${2:-$1}"
while read -r name; do
    [ -n "$name" ] || continue
    case "$name" in \#*) continue ;; esac
    case "$name" in *.sh) ;; *) name="$name.sh" ;; esac
    ex="$root/sh2perl/examples/$name"
    d=$(mktemp -d "$root/scratch/pgc.XXXXXX")
    timeout 60 "$bin" --target pl "$ex" >"$d/g.pl" 2>"$d/g.err"
    gerr=$(command grep -o 'DWF: [^;]*\|DEBUG [^;]*' "$d/g.err" | sort -u | tr '\n' ';' | cut -c1-70)
    ndie=$(command grep -c '^die ' "$d/g.pl" 2>/dev/null); ndie=${ndie:-0}
    timeout 20 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' \
        "$ex" "$d/g.pl" >/dev/null 2>"$d/r.err"
    rerr=$(command grep -v '^$' "$d/r.err" | head -1 | sed 's|at /[^ ]*/scratch/[^ ]*/g.pl|@g.pl|' | cut -c1-90)
    printf '%-52s die=%-4s gen=[%s] run=[%s]\n' "$name" "$ndie" "$gerr" "$rerr"
    rm -rf "$d"
done <"$list"
