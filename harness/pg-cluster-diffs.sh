#!/usr/bin/env bash
# pg-cluster-diffs.sh — cluster the perl-GENERATOR failure list by DIFF SHAPE.
#
# Runs each failing example, captures (bash, perl) stdout + exit codes with the
# same 1 MiB cap the gate uses, normalises the diff, and buckets the examples
# by the shape of the first divergence. A fix that clears N examples at once
# needs a class, not a list, so this exists to find the classes.
#
#   usage: harness/pg-cluster-diffs.sh [outdir]
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
OUT="${1:-$ROOT/tmp_run/pg-cluster}"
mkdir -p "$OUT"
export SH2_UU_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
export SH2_UU_PIPELINE_LIB="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so"
export UU_FFI_MULTICALL="$ROOT/sh2perl/runtime/lib/coreutils-ffi-multicall"

fails=${FAIL_LIST:-$ROOT/.perlgen-fails.lst}
[ -f "$fails" ] || { echo "no fail list at $fails"; exit 2; }

# pid-scoped scratch so a concurrent invocation never removes our own dir
S=$(mktemp -d "/tmp/pgcluster.$$.XXXXXX")
trap 'rm -rf "$S"' EXIT INT TERM

: > "$OUT/shapes.tsv"
while read -r ex; do
  [ -n "$ex" ] || continue
  src="$ROOT/sh2perl/examples/$ex"
  [ -f "$src" ] || continue
  if ! timeout 60 "$CLI" "$src" --target pl -o "$S/$ex.pl" >"$S/gen.log" 2>&1; then
    printf 'GENFAIL\t%s\n' "$ex" >> "$OUT/shapes.tsv"; continue
  fi
  # Drain to EOF: head -c closes the pipe early, this fleet ignores SIGPIPE,
  # so the writer would keep looping (see harness/cap-capture.pl).
  timeout 20 bash "$src" >"$S/bash.out" 2>/dev/null; brc=$?
  timeout 20 perl "$S/$ex.pl" >"$S/perl.out" 2>"$S/perl.err"; prc=$?
  head -c 1048576 "$S/bash.out" > "$S/b.c"; head -c 1048576 "$S/perl.out" > "$S/p.c"
  if cmp -s "$S/b.c" "$S/p.c" && [ "$brc" = "$prc" ]; then
    printf 'PASS\t%s\n' "$ex" >> "$OUT/shapes.tsv"; continue
  fi
  # Normalised shape key: the first differing line pair, with example-specific
  # numbers collapsed, so two examples with the same defect bucket together.
  shape=$(diff "$S/b.c" "$S/p.c" 2>/dev/null | sed -n '1,6p' | tr '\n' '|' | cut -c1-160)
  perlwarn=$(command grep -oE "Use of uninitialized value [^ ]+|isn't numeric|Pattern substitution failed|Global symbol [^ ]+ requires" "$S/perl.err" 2>/dev/null | sort -u | tr '\n' ';')
  printf '%s\trc=%s/%s\t%s\t%s\n' "$ex" "$brc" "$prc" "$perlwarn" "$shape" >> "$OUT/shapes.tsv"
done < "$fails"

echo "── clusters (shape key → examples) ───────────────────────────────"
cut -f5 "$OUT/shapes.tsv" | sort | uniq -c | sort -rn | head -20
echo
echo "── per example ──────────────────────────────────────────────────"
column -t -s $'\t' "$OUT/shapes.tsv" | cut -c1-200
