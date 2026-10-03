#!/usr/bin/env bash
# Classify every currently-failing Perl GENERATOR example by a compact
# signature, so a batch of 60 stdout mismatches can be grouped into the
# handful of distinct root causes instead of triaged one at a time.
#
# Usage: pg-classify-all.sh <name-list-file> <out-file>
set -u
ROOT=/home/llm/sh2loop
LIST=$1; OUT=$2
BIN=$ROOT/otranspilerl/target/debug/otranspilerl-cli
CAP=$ROOT/harness/cap-capture.pl
: > "$OUT"

while read -r name; do
  [ -z "$name" ] && continue
  EX=$ROOT/sh2perl/examples/$name
  D=$(mktemp -d "$ROOT/tmp_run/pgc.XXXXXX")

  "$BIN" --target pl "$EX" > "$D/test.pl" 2>"$D/gen.err"
  if [ $? -ne 0 ]; then
    printf '%s\tGENFAIL\t%s\n' "$name" "$(head -1 "$D/gen.err")" >> "$OUT"
    rm -rf "$D"; continue
  fi
  # The gate's own fallback test is `system\('bash',\s*'[^']*'\)` — a quoted
  # LITERAL path. The renderer's preamble helper `system('bash', '-c', $cmd)`
  # is a legitimate seam present in EVERY program, so the looser
  # `system\('bash',` match is a false positive that mislabels the whole
  # batch as parser gaps. Match the gate exactly.
  if perl -ne 'exit(/system\(\x27bash\x27,\s*\x27[^\x27]*\x27\)/ ? 0 : 1)' "$D/test.pl"; then
    printf '%s\tFALLBACK\tparser emitted bash wrapper\n' "$name" >> "$OUT"
    rm -rf "$D"; continue
  fi

  # Run from inside $D with a RELATIVE ./test.pl: Perl 5.26+ removed '.'
  # from @INC, so `do "$D/test.pl"` works but `do shift @ARGV` on an
  # absolute path is fine too — the bug this guards is a *cwd* mismatch,
  # because the examples create temp files and must not collide with a
  # concurrent gate's. cwd = $D on both sides.
  ( cd "$D" && timeout -k 2 20 bash "$EX" > bash.out 2>/dev/null </dev/null ); bex=$?
  ( cd "$D" && timeout -k 2 20 perl -M5.010 -e '$0=shift @ARGV; my $__f=shift @ARGV; do $__f' "$EX" ./test.pl \
      > perl.out 2>perl.err </dev/null ); pex=$?
  # the gate caps BOTH sides; a runaway that only differs by size is a
  # distinct class, so cap here too before comparing.
  perl "$CAP" 1048576 < "$D/perl.out" > "$D/perl.capped" 2>/dev/null
  mv "$D/perl.capped" "$D/perl.out"

  if cmp -s "$D/bash.out" "$D/perl.out" && [ "$bex" = "$pex" ]; then
    printf '%s\tPASS-now\t(gate race, not a real failure)\n' "$name" >> "$OUT"
    rm -rf "$D"; continue
  fi

  # ── signature ──
  sig=""
  # perl failed to even compile / run?
  if command grep -qE 'syntax error|Global symbol|Bareword|not allowed|Compilation failed|Undefined subroutine|panic' "$D/perl.err"; then
    sig="COMPILE: $(command grep -oE 'syntax error|Global symbol "[^"]*"|Bareword [a-z]+|Undefined subroutine [^ ]*' "$D/perl.err" | head -1)"
  elif [ -s "$D/perl.err" ] && command grep -qE '^Use of uninitialized value' "$D/perl.err"; then
    sig="UNINIT: $(command grep -oE 'Use of uninitialized value [^ ]+' "$D/perl.err" | head -1)"
  fi
  # exit code disagreement
  [ "$bex" != "$pex" ] && sig="$sig EXIT(bash=$bex,perl=$pex)"
  # stdout shapes
  nb=$(wc -l < "$D/bash.out"); np=$(wc -l < "$D/perl.out")
  if [ "$sig" = "" ]; then
    if [ "$np" -gt "$nb" ]; then
      first=$(diff "$D/bash.out" "$D/perl.out" | command grep '^>' | head -1 | cut -c1-70)
      sig="EXTRA-STDOUT (+$((np-nb)) lines) first: $first"
    elif [ "$nb" -gt "$np" ]; then
      first=$(diff "$D/bash.out" "$D/perl.out" | command grep '^<' | head -1 | cut -c1-70)
      sig="MISSING-STDOUT (-$((nb-np)) lines) first: $first"
    else
      sig="CONTENT-DIFF same-line-count: $(diff "$D/bash.out" "$D/perl.out" | command grep '^[<>]' | head -1 | cut -c1-70)"
    fi
  fi
  printf '%s\t%s\n' "$name" "$sig" >> "$OUT"
  rm -rf "$D"
done < "$LIST"
echo "wrote $OUT"
