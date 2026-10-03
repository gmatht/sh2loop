#!/usr/bin/env bash
# pg-sig.sh — for each case, emit the generated Perl and report whether it
# contains an EMPTY rendered value where bash produced output:
#   print('', ...)      — captureWords over a Pipeline rendered to nothing
#   = '';               — a capture assigned the empty string
#   qx{} / qx() empty   — an empty shell-out
# This is the cheap signal for "command substitution was dropped".
set -u

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CLI="$root/otranspilerl/target/debug/otranspilerl-cli"
list="${1:-$root/harness/pg-cases44.txt}"

tmp=$(mktemp -d /tmp/pgsig-XXXXXX)
trap 'rm -rf "$tmp"' EXIT

while IFS= read -r name; do
  [ -n "$name" ] || continue
  f="$root/sh2perl/examples/$name"
  [ -f "$f" ] || continue
  pl="$tmp/$name.pl"
  "$CLI" --target pl "$f" "$pl" >/dev/null 2>&1 || { printf 'GENFAIL\t%s\n' "$name"; continue; }
  sig=""
  grep -q "print(''," "$pl" && sig="${sig}EMPTY_PRINT,"
  grep -qE "= '';" "$pl" && sig="${sig}EMPTY_ASSIGN,"
  grep -qE "qx\{\}" "$pl" && sig="${sig}EMPTY_QX,"
  grep -q "__sh_capture_empty" "$pl" && sig="${sig}EMPTY_CAP,"
  if [ -n "$sig" ]; then
    printf 'EMPTYSIG\t%s\t%s\n' "$name" "$sig"
  else
    printf 'nosig\t%s\n' "$name"
  fi
done < "$list"