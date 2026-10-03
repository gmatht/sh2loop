#!/bin/bash
# Batch triage for the perl generator: runs N examples through the SAME
# invocation shape the gate uses, and reports the first differing line.
#   harness/pgq.sh <name>              -> single example, full diff
#   harness/pgq.sh -l <file>           -> list file, one line per example
# The gate runs examples with cwd = wherever ./fail was invoked; relative
# /tmp and ./ paths are therefore resolved against $PWD. This script honours
# PGPWD (default: the invocation cwd) so a repro matches the gate's view.
set -u
root=/home/llm/sh2loop
bin="$root/otranspilerl/target/debug/otranspilerl-cli"
cwd="${PGPWD:-$PWD}"
export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"

if [ "${1:-}" = "-l" ]; then
    list="$2"
    while read -r name; do
        [ -n "$name" ] || continue
        case "$name" in \#*) continue ;; esac
        case "$name" in *.sh) ;; *) name="$name.sh" ;; esac
        d=$(mktemp -d "$root/scratch/pgq.XXXXXX") || exit 1
        ex="$root/sh2perl/examples/$name"
        timeout 60 "$bin" --target pl "$ex" >"$d/gen.pl" 2>"$d/gen.err"
        ( cd "$cwd" && timeout 20 bash "$ex" >"$d/bash.out" 2>/dev/null ); bexit=$?
        ( cd "$cwd" && timeout 20 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' \
            "$ex" "$d/gen.pl" >"$d/perl.out" 2>"$d/perl.err" ); pexit=$?
        if cmp -s "$d/bash.out" "$d/perl.out" && [ "$bexit" = "$pexit" ]; then
            echo "PASS $name"
        else
            fd=$(diff "$d/bash.out" "$d/perl.out" 2>/dev/null | head -2 | tail -1)
            pe=$(head -1 "$d/perl.err" 2>/dev/null | cut -c1-70)
            echo "FAIL $name exit(b=$bexit p=$pexit) | $fd | ${pe:-}"
        fi
        rm -rf "$d"
    done <"$list"
    exit 0
fi

ex="$root/sh2perl/examples/${1%.sh}.sh"
d=$(mktemp -d "$root/scratch/pgq.XXXXXX") || exit 1
trap 'rm -rf "$d"' EXIT
if ! timeout 60 "$bin" --target pl "$ex" >"$d/gen.pl" 2>"$d/gen.err"; then
    echo "== GENERATE FAILED =="; head -5 "$d/gen.err"; exit 1
fi
[ -s "$d/gen.err" ] && { echo "-- stderr --"; head -3 "$d/gen.err"; }
( cd "$cwd" && timeout 20 bash "$ex" >"$d/bash.out" 2>/dev/null ); bexit=$?
( cd "$cwd" && timeout 20 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' \
    "$ex" "$d/gen.pl" >"$d/perl.out" 2>"$d/perl.err" ); pexit=$?
echo "== exit: bash=$bexit perl=$pexit"
[ -s "$d/perl.err" ] && { echo "-- perl stderr (first 6) --"; head -6 "$d/perl.err"; }
if cmp -s "$d/bash.out" "$d/perl.out"; then
    echo "== STDOUT MATCH"
else
    echo "== STDOUT DIFF (- bash, + perl) --"
    diff -u "$d/bash.out" "$d/perl.out" | head -50
fi