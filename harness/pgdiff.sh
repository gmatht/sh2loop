#!/bin/bash
# Compact diff for a list of examples: first N differing lines only.
#   harness/pgdiff.sh -l <list> [lines]
set -u
root="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
bin="$root/otranspilerl/target/debug/otranspilerl-cli"
cwd="${PGPWD:-$PWD}"
n="${3:-6}"
export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"
while read -r name; do
    [ -n "$name" ] || continue
    case "$name" in \#*) continue ;; esac
    case "$name" in *.sh) ;; *) name="$name.sh" ;; esac
    ex="$root/sh2perl/examples/$name"
    d=$(mktemp -d "$root/scratch/pgd.XXXXXX")
    timeout 60 "$bin" --target pl "$ex" >"$d/g.pl" 2>/dev/null
    ( cd "$cwd" && timeout 20 bash "$ex" >"$d/bash.out" 2>/dev/null ); bexit=$?
    ( cd "$cwd" && timeout 20 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' \
        "$ex" "$d/g.pl" >"$d/perl.out" 2>/dev/null ); pexit=$?
    echo "########## $name  (exit bash=$bexit perl=$pexit)"
    if cmp -s "$d/bash.out" "$d/perl.out" && [ "$bexit" = "$pexit" ]; then
        echo "  PASS"
    else
        diff -u "$d/bash.out" "$d/perl.out" | sed -n '4,20p' | head -"$n" | sed 's/^/  /'
    fi
    rm -rf "$d"
done <"$2"