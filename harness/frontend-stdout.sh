#!/bin/bash
# frontend-stdout.sh — executed-stdout gate for the frontend fleet.
#
# For each testdata example of the given frontend:
#   1. run the example natively  (python3 / go run / perl / bash / fish / zsh)
#   2. run the frontend's A1 shIR through the ESTree backend
#      (debashc --shir-in-estree -> estree-runner.mjs under node)
#   3. compare normalized stdout (mirrors ./fail: strip \r, trim edges)
#
# The JS/ESTree backend is the execution target: the A1->Perl round-trip is
# not yet compile-clean (see core-requests), while --shir-in-estree renders
# and runs end-to-end today.
#
# Usage: frontend-stdout.sh <lang> <bin> <testdata-dir> <debashc>
#   lang: py|go|sh|pl|fish|zsh     bin: frontend binary (path as make sees it)
set -u
lang=$1; bin=$2; dir=$3; debashc=$4
root=$(cd "$(dirname "$0")/.." && pwd)
runner="$root/harness/estree-runner.mjs"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

case "$lang" in
  py)   ext=.py;   native=(python3) ;;
  go)   ext=.go;   native=() ;;          # wrapper below
  sh)   ext=.sh;   native=(bash) ;;
  pl)   ext=.pl;   native=(perl) ;;
  fish) ext=.fish; native=(fish) ;;
  zsh)  ext=.zsh;  native=(zsh) ;;
  *) echo "unknown lang: $lang"; exit 2 ;;
esac

run_native() {  # <file> -> stdout on stdout
  local f=$1
  if [ "$lang" = go ]; then
    # wrap into a runnable Go program: import only what the example uses
    local imports=""
    grep -q 'fmt\.'  "$f" && imports="$imports\n\t\"fmt\""
    grep -q 'exec\.' "$f" && imports="$imports\n\t\"os/exec\""
    grep -q 'bufio\.' "$f" && imports="$imports\n\t\"bufio\""
    grep -qE 'os\.(Getenv|WriteFile|Setenv|Stat|Stdin)' "$f" && imports="$imports\n\t\"os\""
    { printf 'package main\n\nimport (\n%b\n)\n\nfunc main() {\n' "$imports"; cat "$f"; printf '\n}\n'; } > "$tmp/main.go"
    (cd "$tmp" && timeout 20 go run main.go) < /dev/null 2>/dev/null
  else
    timeout 20 "${native[@]}" "$f" < /dev/null 2>/dev/null
  fi
}

normalize() { printf '%s' "$1" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

total=0; fails=0; skips=0
for f in "$dir"/*"$ext"; do
  [ -f "$f" ] || continue
  bn=$(basename "$f"); total=$((total+1))
  if [ "$lang" != go ] && ! command -v "${native[0]}" >/dev/null 2>&1; then
    echo "SKIP $bn (native interpreter '${native[0]}' not installed)"
    skips=$((skips+1)); continue
  fi
  # 1. native execution (capture stdout even on nonzero exit)
  native_out=$(run_native "$f") || true
  # 2. frontend emit
  if ! "$bin" --shir "$f" --raw > "$tmp/a1.json" 2>/dev/null; then
    echo "FAIL $bn (frontend emit)"
    fails=$((fails+1)); continue
  fi
  # 2b. A1 -> ESTree
  if ! "$debashc" --shir-in-estree "$tmp/a1.json" > "$tmp/e.json" 2>/dev/null; then
    echo "FAIL $bn (A1 -> ESTree conversion)"
    fails=$((fails+1)); continue
  fi
  # 2c. run transpiled JS
  trans_out=$(timeout 20 node "$runner" "$tmp/e.json" --source "$f" 2>/dev/null) || true
  # 3. compare normalized stdout
  if [ "$(normalize "$native_out")" = "$(normalize "$trans_out")" ]; then
    echo "OK   $bn (stdout match)"
  else
    echo "DIFF $bn (stdout mismatch)"
    diff <(printf '%s\n' "$native_out") <(printf '%s\n' "$trans_out") \
      | head -6 | sed 's/^/     /'
    fails=$((fails+1))
  fi
done
echo "--- frontend-stdout [$lang]: $((total-fails-skips))/$total match, $fails FAIL, $skips SKIP"
[ "$fails" -eq 0 ]
