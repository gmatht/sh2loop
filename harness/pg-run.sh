#!/usr/bin/env bash
# pg-run.sh — run harness/pg-triage.sh over a list of corpus examples and keep
# every artefact in one place, so a batch of red cases can be CLASSIFIED
# (not just counted). The gate stays ./fail; this is the diagnostic driver.
#
#   harness/pg-run.sh <outdir> [example ...]
#
# With no examples it reads the newline-separated list on stdin.
set -u
out=$1; shift
root="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
mkdir -p "$out"
if [ "$#" -gt 0 ]; then
  cases=("$@")
else
  mapfile -t cases
fi
verdicts="$out/verdicts.tsv"
: >"$verdicts"
for ex in "${cases[@]}"; do
  [ -n "$ex" ] || continue
  name=${ex%.sh}
  v=$("$root/harness/pg-triage.sh" "$root/sh2perl/examples/$name.sh" 2>&1 | head -1)
  printf '%-48s %s\n' "$name" "$v" | tee -a "$verdicts"
  # Keep the artefacts: the .pl is the thing under test, the diff is the reason.
  d="$root/tmp_run/pg-triage/$name"
  if [ -d "$d" ]; then
    cp -f "$d/perl.out" "$out/$name.perl.out" 2>/dev/null
    cp -f "$d/bash.out" "$out/$name.bash.out" 2>/dev/null
    cp -f "$d/perl.err" "$out/$name.perl.err" 2>/dev/null
    cp -f "$d/gen.pl"  "$out/$name.pl" 2>/dev/null
  fi
done
printf '\n── summary ──\n'
awk -F'\t' '{print $2}' "$verdicts" | sed 's/ .*//' | sort | uniq -c | sort -rn
printf 'artifacts: %s\n' "$out"
