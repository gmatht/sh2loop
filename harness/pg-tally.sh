#!/usr/bin/env bash
# pg-tally.sh — one line per example: is bash's OWN output stable across two
# runs, and where does the generated Perl first diverge?
#   PASS | bash-UNSTABLE | GENFAIL | bash_lines=N perl_lines=M firstdiff@L <sig>
#
# The SIG is the first differing line pair, whitespace-collapsed, plus the head
# of perl's stderr when there is one. Two examples sharing a signature share a
# root cause, so a fix can be aimed at the largest bucket instead of at one
# example at a time — and the stderr half is what separates the two failure
# modes that otherwise look identical: a `use strict` compile death (no stdout,
# exit 0) and a wrong value (stdout present, wrong contents).
#
# NOTE: `grep` in an interactive shell here is a ripgrep wrapper FUNCTION, so
# `grep -qE`/`grep -qi` fail on EVERY input. Any script that reads an ANSWER out
# of a grep (rather than only printing matches) must call `command grep`, or it
# reports the same thing for both a hit and a miss.
set -u
root=/home/llm/sh2loop
ot=$root/otranspilerl/target/debug/otranspilerl-cli
export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"
# Absolute: the runs below `cd` into their own scratch dir, so a relative
# corpus path would silently make bash fail to open the example (bash's "No such
# file" goes to stderr, which is discarded) and every comparison would be
# against an EMPTY reference.
EX=$(cd "${PG_CORPUS:-$root/sh2perl/backends/perl/examples}" 2>/dev/null && pwd -P)

for name in "$@"; do
  src="$EX/$name"
  [ -f "$src" ] || { echo "$name NOTFOUND"; continue; }
  d=$(mktemp -d "/tmp/pgt.${name%.sh}.XXXXXX")
  if ! timeout 25 "$ot" --target pl "$src" >"$d/test.pl" 2>"$d/gen.err"; then
    # A generator panic/abort is its own class: there is no perl at all.
    printf '%-50s GENFAIL %s\n' "$name" \
      "$(command grep -oE 'panicked at [^ ]+:[0-9]+:[0-9]+' "$d/gen.err" | head -1)"
    rm -rf "$d"; continue
  fi
  ( cd "$d" && setsid timeout -k 2 20 bash "$src" >b1.out 2>/dev/null )
  ( cd "$d" && setsid timeout -k 2 20 bash "$src" >b2.out 2>/dev/null )
  ( cd "$d" && setsid timeout -k 2 20 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' x ./test.pl >p.out 2>p.err )
  if ! cmp -s "$d/b1.out" "$d/b2.out"; then
    printf '%-50s bash-UNSTABLE\n' "$name"; rm -rf "$d"; continue
  fi
  if cmp -s "$d/b1.out" "$d/p.out"; then
    printf '%-50s PASS\n' "$name"
  else
    nb=$(wc -l <"$d/b1.out"); np=$(wc -l <"$d/p.out")
    first=$(diff "$d/b1.out" "$d/p.out" | command grep -m1 -E '^[0-9]' | tr -d 'acd')
    sig=$(diff "$d/b1.out" "$d/p.out" | command grep -E '^[<>]' | head -2 \
          | tr -d ' \t' | tr '\n' '|' | cut -c1-100)
    err=""
    if [ -s "$d/p.err" ]; then
      err=" ERR[$(head -1 "$d/p.err" | cut -c1-70)]"
    fi
    printf '%-50s bash=%-4s perl=%-4s firstdiff@%s %s%s\n' \
      "$name" "$nb" "$np" "${first:-end}" "$sig" "$err"
  fi
  rm -rf "$d"
done