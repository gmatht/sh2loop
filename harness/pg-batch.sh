#!/usr/bin/env bash
# pg-batch.sh — run harness/pg-diff.sh over a list of examples, keeping each
# diff in its own artifact dir, and print a one-line cluster summary per
# example. Diagnostic helper for the perl-generator worker.
#
#   harness/pg-batch.sh <outdir> <example...>
set -u
out=$1; shift
mkdir -p "$out"
root="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
for ex in "$@"; do
  name=${ex%.sh}
  [ -f "$root/sh2perl/examples/$ex" ] || ex="$ex.sh"
  d=$(mktemp -d /tmp/pgb.XXXXXX)
  "$root/harness/pg-diff.sh" "$ex" >"$d/report" 2>&1
  grep -o '(artifacts: .*)' "$d/report" | sed 's/.*: //;s/)//' >"$d/artpath"
  rep=$(cat "$d/artpath")
  {
    echo "### $ex"
    head -40 "$d/report"
  } >"$out/$name.txt"
  rm -rf "$rep"
  printf '%-52s ' "$ex"
  head -3 "$d/report" | tail -1 | cut -c1-70
  sed -n '4,14p' "$d/report" | grep -c . >/dev/null
  rm -rf "$d"
done
