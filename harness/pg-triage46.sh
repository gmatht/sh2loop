#!/usr/bin/env bash
# pg-triage46.sh — classify the 46 perl-generator corpus failures by root
# cause. `./fail` reports every one as "stdout mismatch" because a generated
# file that fails to compile produces NOTHING on stdout and exits 0. That makes
# a compile bug indistinguishable from a semantic bug in the report. This
# re-runs the same 46 cases through `perl -c` + a byte compare and buckets
# them, so a cluster of "silent" failures is recognised as ONE bug.
#
# Usage: harness/pg-triage46.sh [names...]
#   with no args, reads the name list from .failures_current.tsv / stdin.
set -uo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CLI="$root/otranspilerl/target/debug/otranspilerl-cli"
EX="$root/sh2perl/examples"

export SH2_UU_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$root/sh2perl/runtime/lib/coreutils-ffi-multicall"

declare -a names=("$@")
if [ ${#names[@]} -eq 0 ]; then
  if [ -t 0 ]; then
    echo "usage: harness/pg-triage46.sh <name> [name...]   (or pipe names on stdin)" >&2
    exit 2
  fi
  mapfile -t names
fi

work=$(mktemp -d "$COMMANDCODE_SCRATCHPAD/pgtri-XXXXXX")
trap 'rm -rf "$work"' EXIT

for n in "${names[@]}"; do
  [ -n "$n" ] || continue
  ex="$EX/$n"
  if [ ! -f "$ex" ]; then printf 'NOFILE\t%s\n' "$n"; continue; fi
  d="$work/$n"; mkdir -p "$d"

  if ! "$CLI" --target pl "$ex" >"$d/t.pl" 2>"$d/gen.err"; then
    printf 'GENERR\t%s\t%s\n' "$n" "$(head -1 "$d/gen.err")"; continue
  fi

  # The real classifier: a compile error makes `do FILE` emit nothing at all.
  cerr=$(perl -c "$d/t.pl" 2>&1 \
    | command grep -v 'uu-ffi' \
    | command grep -v 'syntax OK' \
    | command grep -E 'error|Missing|Unterminated|Bareword|Ambiguous|String found' \
    | head -1)
  if [ -n "$cerr" ]; then
    printf 'COMPILE\t%s\t%s\n' "$n" "$(printf '%s' "$cerr" | sed "s|$d/t.pl|GEN|")"
    continue
  fi

  mkdir -p "$d/b" "$d/p"
  ( cd "$d/b" && timeout 30 bash "$ex" ) >"$d/b.out" 2>"$d/b.err"; brc=$?
  ( cd "$d/p" && timeout 30 perl -M5.010 -e '$0=shift @ARGV; my $f=shift @ARGV; do $f' "$ex" "$d/t.pl" ) >"$d/p.out" 2>"$d/p.err"; prc=$?

  if cmp -s "$d/b.out" "$d/p.out" && [ "$brc" = "$prc" ]; then
    printf 'PASS\t%s\t\n' "$n"
  elif [ "$brc" != "$prc" ]; then
    printf 'EXIT\t%s\tbash=%s perl=%s\n' "$n" "$brc" "$prc"
  else
    # Distinguish "perl wrote nothing" (upstream error swallowed) from a
    # partial/extra-output semantic diff.
    pb=$(wc -c <"$d/b.out"); pp=$(wc -c <"$d/p.out")
    kind=DIFF
    [ "$pp" = 0 ] && kind=EMPTY
    printf '%s\t%s\tbash=%sB perl=%sB %s\n' "$kind" "$n" "$pb" "$pp" \
      "$(head -1 "$d/p.err" 2>/dev/null | cut -c1-90)"
  fi
done