#!/bin/bash
# shIR → Perl backend metric: for every corpus example, emit ShIR JSON,
# render it via --shir-in-perl, syntax-check the Perl, run it vs bash,
# and compare stdout (normalized: trailing-whitespace-free) + exit code.
# Usage: harness/ir-perl-metric.sh [prefix]
set -u
DEB=${DEB:-$(pwd)/sh2perl/target/debug/debashc}
CORPUS=${FAIL_CORPUS:-$(pwd)/sh2perl/examples}
PREFIX="${1:-}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
pass=0; syn=0; die=0; runt=0; total=0
: > "$tmp/failures.tsv"
for f in "$CORPUS"/$PREFIX*.sh; do
    [ -f "$f" ] || continue
    total=$((total+1))
    name=$(basename "$f")
    # 1. emit + render
    if ! "$DEB" --shir "$f" > "$tmp/p.json" 2>/dev/null; then
        echo -e "$name\temit-fail" >> "$tmp/failures.tsv"; continue
    fi
    if ! "$DEB" --shir-in-perl "$tmp/p.json" > "$tmp/ir.pl" 2>/dev/null; then
        echo -e "$name\trender-panic" >> "$tmp/failures.tsv"; continue
    fi
    # 2. syntax check
    if ! perl -c "$tmp/ir.pl" >/dev/null 2>&1; then
        syn=$((syn+1)); echo -e "$name\tsyntax" >> "$tmp/failures.tsv"; continue
    fi
    # 3. run in a scratch dir (hermetic: no CWD/-tmp churn). The real gate
    # (fail) compares STDOUT only — stderr warnings are captured but not
    # compared, so do the same here.
    rm -rf "$tmp/run"; mkdir -p "$tmp/run"
    cp "$f" "$tmp/run/script.sh"
    ( cd "$tmp/run" && timeout 15 bash script.sh ) > "$tmp/b.out" 2>/dev/null; bc=$?
    ( cd "$tmp/run" && timeout 15 perl "$tmp/ir.pl" ) > "$tmp/i.out" 2>/dev/null; ic=$?
    # normalize: strip leading/trailing whitespace + trailing space per line
    sed 's/[[:space:]]*$//' "$tmp/b.out" > "$tmp/b.n"; sed 's/[[:space:]]*$//' "$tmp/i.out" > "$tmp/i.n"
    if diff -q "$tmp/b.n" "$tmp/i.n" >/dev/null 2>&1 && [ "$bc" = "$ic" ]; then
        pass=$((pass+1))
    else
        runt=$((runt+1)); echo -e "$name\tstdout/exit (bash=$bc perl=$ic)" >> "$tmp/failures.tsv"
    fi
done
echo "=== shIR→Perl metric: $pass/$total pass (syntax-fail $syn, render-panic/die $die, stdout-or-exit mismatch $runt)"
echo "=== failure sample (first 15):"
head -15 "$tmp/failures.tsv"
