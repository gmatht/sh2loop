#!/usr/bin/env bash
# pg-triage-batch.sh — classify the perl-generator corpus backlog into
# fixable buckets, in ONE command.
#
#   harness/pg-triage-batch.sh [example.sh ...]
#
# With no arguments it sweeps the explicit backlog in
# harness/perl_gen_backlog.txt. Each example is run through
# harness/pg-triage.sh (the gate-faithful per-example runner), and the
# artefacts that leaves in tmp_run/pg-triage/<name>/ are kept on disk.
#
# The point is that the open failures are not 53 independent bugs: they
# collapse into a few shapes, and a generator fix that clears a shape
# clears every member at once. So the output is a class -> members table,
# not a red list. Re-run after each fix and watch the buckets drain.
#
# Output is "|"-delimited, not tab-delimited: a literal tab inside this
# file is easy to introduce by accident and is a nasty class of shell bug
# (bash reads a real tab inside a quoted word as a word separator, which
# turns printf format strings into syntax errors). Example names never
# contain "|", so the delimiter is unambiguous.
set -u

ROOT=/home/llm/sh2loop
BACKLOG="$ROOT/harness/perl_gen_backlog.txt"
ART="$ROOT/tmp_run/pg-triage"

declare -a names=()
declare -a paths=()

# Accept either a bare example name (what harness/perl_gen_backlog.txt holds)
# or a path. A bare name is resolved against the corpus dir. This matters:
# passing a bare name straight through to the CLI makes the transpiler fail
# to find the file, and every example then reports GEN-FAILED — a harness
# fault that looks exactly like a 53-member failure class.
resolve() {
  case "$1" in
    */*) printf '%s' "$1" ;;
    *)   printf '%s/sh2perl/examples/%s' "$ROOT" "$1" ;;
  esac
}

if [ $# -gt 0 ]; then
  names=("$@")
elif [ -f "$BACKLOG" ]; then
  while IFS= read -r line; do
    line=${line%%#*}
    line=$(printf '%s' "$line" | tr -d '[:space:]')
    [ -n "$line" ] && names+=("$line")
  done < "$BACKLOG"
else
  echo "no arguments and no backlog file at $BACKLOG" >&2
  exit 2
fi

for n in "${names[@]}"; do paths+=("$(resolve "$n")"); done

mkdir -p "$ART"
results="$ART/_batch-classes.psv"
: > "$results"

for ex in "${paths[@]}"; do
  out=$(bash "$ROOT/harness/pg-triage.sh" "$ex" 2>&1 | tail -1)
  name=$(basename "$ex" .sh)
  case "$out" in
    *": PASS")              cls=PASS ;;
    *": PARSER-FALLBACK")   cls=parser-fallback ;;
    *": GEN-FAILED"*)       cls=gen-failed ;;
    *": CHECK-QX"*)         cls=check-qx ;;
    *'FAIL(STDOUT+EXIT)'*)  cls=emit-stdout+exit ;;
    *'FAIL(STDOUT)'*)       cls=emit-stdout ;;
    *'FAIL(EXIT)'*)         cls=emit-exit-code ;;
    *)                      cls=unclassified ;;
  esac
  printf '%s|%s|%s\n' "$cls" "$name" "$out" >> "$results"
done

# ── guard: a sweep where nothing was even found is a harness fault ──
# Not a result. Without this, a path-resolution or path-typo bug reports
# as "53/53 GEN-FAILED" and reads like a total generator regression.
missing=$(grep -c '|MISSING' "$results" 2>/dev/null || true)
if [ "${missing:-0}" -gt 0 ]; then
  echo "HARNESS ERROR: $missing example(s) not found — resolve() or the"
  echo "backlog list is wrong; this is not a generator result. First few:"
  grep '|MISSING' "$results" | head -5
  exit 2
fi

echo
n=${#names[@]}
echo "=== perl-generator backlog by class ($n examples) ==="
echo
echo "totals by class (largest bucket first = best value per fix):"
cut -d'|' -f1 "$results" | sort | uniq -c | sort -rn | awk '{printf "  %3d  %s\n", $1, $2}'
echo
echo "members by class:"
sort "$results" | awk -F'|' '
  {
    if (cls != $1) { if (cls != "") printf "\n[%s]  %d\n", cls, cnt; cls = $1; cnt = 0 }
    cnt++
    printf "  %-44s %s\n", $2, $3
  }
  END { if (cls != "") printf "\n[%s]  %d\n", cls, cnt }
'
echo
echo "artefacts: $ART/<name>/  (gen.pl, perl.out, bash.out, *.err)"
