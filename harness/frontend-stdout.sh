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
  c)    ext=.c;    native=(cc) ;;        # compile+run wrapper below
  sh)   ext=.sh;   native=(bash) ;;
  pl)   ext=.pl;   native=(perl) ;;
  fish) ext=.fish; native=(fish) ;;
  zsh)  ext=.zsh;  native=(zsh) ;;
  bat)  ext=.bat;  native=() ;;      # cmd.exe is Windows-only — native side
                                    # is the RECORDED expectations below
  *) echo "unknown lang: $lang"; exit 2 ;;
esac

# Go toolchain resolution. The PATH wrapper /snap/bin/go re-execs through
# snap-confine, which fails in containerized workers ("home directories
# outside of /home needs configuration" / missing cap_dac_override) even
# though the direct snap binary works fine. Honor an explicit GO, else
# prefer the direct binary, else fall back to PATH.
gobin=go
if [ "$lang" = go ]; then
  if [ -n "${GO:-}" ] && [ -x "$GO" ]; then
    gobin="$GO"
  elif [ -x /snap/go/current/bin/go ]; then
    gobin=/snap/go/current/bin/go
  fi
fi

# Native-interpreter limitation list: tests the NATIVE interpreter cannot
# run (a real language gap — e.g. fish has no heredocs at all) while the
# transpiled pipeline handles them. Listed tests compare the transpiled
# run against a RECORDED expected stdout (\n escapes) instead of the
# native run, so the transpiler path keeps real coverage. Format:
#   "name.ext|expected-stdout-with-\\n-escapes" (one entry per line)
native_limits_fish="t43_heredoc.fish|line1\nline2"
native_limits_bat="t01_echo.bat|hello world\n\n\n
t02_set.bat|hello world\n
t03_arith.bat|x=14\n
t04_if.bat|eq\nno\nright\n
t05_if_not.bat|not-eq\nnot-eq2\n
t06_goto.bat|before\nafter\n
t07_for.bat|item alpha\nitem beta\nitem gamma\n
t08_block.bat|in-block\nsecond-line\nafter\n
t08_exit.bat|before\n

t09_args.bat|arg1= arg2= all=\n
t10_mixed.bat|total is 5\niter 1\niter 2\nend\n
t11_commands.bat|one\none\na.txt\nc.txt\none\n
t12_forf.bat|word alpha\nword gamma\nitem one\nitem three\npair x-y\ngot from\n
t13_v11.bat|defined\nnot-defined-2\npasswd-exists\nok\nnum 1\nnum 2\nnum 3\none two\n"

run_native() {  # <file> -> stdout on stdout
  local f=$1
  if [ "$lang" = c ]; then
    cp "$f" "$tmp/main.c"
    (cd "$tmp" && timeout 20 cc main.c -o main 2>/dev/null && timeout 20 ./main) < /dev/null 2>/dev/null
  elif [ "$lang" = go ]; then
    if grep -q 'func main()' "$f"; then
      # already a full program (its own package main/import/func main) —
      # wrapping it again would nest a package decl inside func main
      # (t01_print.go). Run it as-is.
      cp "$f" "$tmp/main.go"
    else
      # wrap into a runnable Go program: import only what the example uses
      local imports=""
      grep -q 'fmt\.'  "$f" && imports="$imports\n\t\"fmt\""
      grep -q 'exec\.' "$f" && imports="$imports\n\t\"os/exec\""
      grep -q 'bufio\.' "$f" && imports="$imports\n\t\"bufio\""
      grep -q 'strings\.' "$f" && imports="$imports\n\t\"strings\""
      grep -q 'filepath\.' "$f" && imports="$imports\n\t\"path/filepath\""
      grep -q 'bytes\.' "$f" && imports="$imports\n\t\"bytes\""
      grep -qE 'os\.(Getenv|WriteFile|Setenv|Stat|Stdin|Stdout)' "$f" && imports="$imports\n\t\"os\""
      { printf 'package main\n\nimport (\n%b\n)\n\nfunc main() {\n' "$imports"; cat "$f"; printf '\n}\n'; } > "$tmp/main.go"
    fi
    (cd "$tmp" && timeout 20 "$gobin" run main.go) < /dev/null 2>/dev/null
  else
    timeout 20 "${native[@]}" "$f" < /dev/null 2>/dev/null
  fi
}

normalize() { printf '%s' "$1" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

total=0; fails=0; skips=0
for f in "$dir"/*"$ext"; do
  [ -f "$f" ] || continue
  bn=$(basename "$f"); total=$((total+1))
  if [ "$lang" != go ] && [ "$lang" != bat ] && ! command -v "${native[0]}" >/dev/null 2>&1; then
    echo "SKIP $bn (native interpreter '${native[0]}' not installed)"
    skips=$((skips+1)); continue
  fi
  # 1. native execution (capture stdout even on nonzero exit). A test on
  # the native-limitation list compares against its RECORDED expected
  # stdout instead (the native interpreter cannot run it — a runtime
  # limitation, never a transpiler bug).
  limits=""
  case "$lang" in
    fish) limits=$native_limits_fish ;;
    bat)  limits=$native_limits_bat ;;
  esac
  native_out=""
  if [ -n "$limits" ]; then
    # line-based (the recorded expectations contain spaces — a
    # word-split `for entry in $limits` would shred them)
    while IFS= read -r entry; do
      [ -z "$entry" ] && continue
      if [ "${entry%%|*}" = "$bn" ]; then
        native_out=$(printf '%b' "${entry#*|}")
        break
      fi
    done <<EOF
$limits
EOF
  fi
  if [ -z "$native_out" ]; then
    native_out=$(run_native "$f") || true
  fi
  # 2. frontend emit
  if ! "$bin" --shir "$f" --raw > "$tmp/a1.json" 2>/dev/null; then
    echo "FAIL $bn (frontend emit)"
    fails=$((fails+1)); continue
  fi
  # 2b. A1 -> ESTree. debashc is rebuilt by the estree worker whenever
  # core changes land; a CONCURRENT cargo relink can briefly leave a
  # truncated/invalid binary at target/debug/debashc, failing exactly one
  # invocation while every other test passes (the fish-sh-go gate hit this
  # on t40_nested_loop at 18:04:22-27). Retry once after the link usually
  # finishes; a real deterministic regression fails the retry too and is
  # still reported as FAIL.
  if ! "$debashc" --shir-in-estree "$tmp/a1.json" > "$tmp/e.json" 2>/dev/null; then
    sleep 3
    if ! "$debashc" --shir-in-estree "$tmp/a1.json" > "$tmp/e.json" 2>/dev/null; then
      echo "FAIL $bn (A1 -> ESTree conversion)"
      fails=$((fails+1)); continue
    fi
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
