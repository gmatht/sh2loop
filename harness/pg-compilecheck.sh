#!/usr/bin/env bash
# Split the Perl GENERATOR failures into the two classes that need different
# fixes:
#
#   COMPILE-ERROR  the generated Perl will not even compile (`perl -c`), so
#                  stdout is empty and EVERY assertion downstream is void.
#   RUN-ERROR      it compiles but dies/wrong-stdout at runtime, so there is a
#                  real stdout diff to reason about.
#
# The distinction decides where to spend effort: a compile error in a long
# example hides all of that example's real bugs, so fixing one compile error
# can reveal (and unblock) several runtime ones.
#
#   harness/pg-compilecheck.sh [fail-list]
set -u

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cli="$root/otranspilerl/target/debug/otranspilerl-cli"
list=${1:-"$root/harness/pg-fail-list.txt"}

printf 'example\tperl -c\tfirst diagnostic\n'
nce=0; nre=0; nok=0
while read -r name; do
  [[ -n $name ]] || continue
  ex="$root/sh2perl/examples/$name"
  [[ -f $ex ]] || { printf '%s\tNOEXAMPLE\t-\n' "$name"; continue; }
  wd=$(mktemp -d "/tmp/pgcc-XXXXXX")
  if ! timeout 25 "$cli" --target pl "$ex" >"$wd/test.pl" 2>"$wd/gen.err"; then
    printf '%s\tGEN-FAIL\t%s\n' "$name" "$(head -c 100 "$wd/gen.err" | tr '\n\t' '  ')"
    rm -rf "$wd"; continue
  fi
  # `perl -c` is the oracle. -I is irrelevant here; the prelude is self-contained.
  if err=$(perl -c "$wd/test.pl" 2>&1 >/dev/null); then
    printf '%s\tOK\t-\n' "$name"; nok=$((nok+1))
  else
    first=$(printf '%s\n' "$err" | grep -v '^ ' | grep -v 'aborted due to' | head -1 \
            | sed 's/at .*test\.pl line [0-9]*\./@LINE/' | cut -c1-95)
    printf '%s\tCOMPILE-ERROR\t%s\n' "$name" "$first"
    nce=$((nce+1))
  fi
  rm -rf "$wd"
done <"$list"
printf '\n# OK(compile)=%d  COMPILE-ERROR=%d\n' "$nok" "$nce" >&2
