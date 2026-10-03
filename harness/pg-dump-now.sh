#!/usr/bin/env bash
# Dump the bash-vs-perl diff for each name on stdin, against an existing
# pg-classify-now.sh scratch dir (which holds the captured .bout/.pout/.pl).
# Usage: harness/pg-dump-now.sh <scratchdir> [names...]
set -uo pipefail
d=$1; shift
if [ $# -eq 0 ]; then set -- $(ls "$d"/*.sig | sed 's|.*/||; s|\.sig$||'); fi
for n in "$@"; do
  echo "################ $n  [$(awk -F'\t' '{print $2}' "$d/$n.sig")]"
  diff "$d/$n.bout" "$d/$n.pout" 2>&1 | head -"${DIFFLINES:-14}"
done
