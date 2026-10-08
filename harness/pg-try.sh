#!/bin/bash
# pg-try.sh <example.sh>... — rebuild otranspilerl-cli, then classify the named
# examples against it. One call per iteration of the fix loop, so the numbers
# always come from a binary that matches the current source.
#
#   usage: harness/pg-try.sh <example.sh>...
set -u
ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
[ $# -ge 1 ] || { echo "usage: $0 <example.sh>..." >&2; exit 2; }

echo "=== building"
if ! "$ROOT/harness/build-lock.sh" --role core -- bash -c \
        'cd "$1" && cargo build --bin otranspilerl-cli 2>&1 | tail -3' _ "$ROOT/otranspilerl"
then
    echo "=== BUILD FAILED"; exit 2
fi

# pg-classify caches per-name; force a fresh dir so nothing is stale.
out=$(mktemp -d /tmp/pgtry.XXXXXX)
names=""
for f in "$@"; do names="$names
$(basename "$f" .sh).sh"; done
printf '%s\n' "${names#}" > "$out/names"
PG_ONLY="$out/names" "$ROOT/harness/pg-classify.sh" "$out/run" 2>&1 | tail -40
echo "(outdir $out)"
