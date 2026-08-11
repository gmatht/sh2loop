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
  cpp)  ext=.cc;   native=(c++) ;;       # compile+run wrapper below
  rust) ext=.rs;   native=(rustc) ;;     # compile+run wrapper below
  sh)   ext=.sh;   native=(bash) ;;
  pl)   ext=.pl;   native=(perl) ;;
  fish) ext=.fish; native=(fish) ;;
  zsh)  ext=.zsh;  native=(zsh) ;;
  bat)  ext=.bat;  native=() ;;      # cmd.exe is Windows-only — native side
                                    # is the RECORDED expectations below
  powershell) ext=.ps1; native=() ;;  # pwsh not installed on the fleet —
                                    # native side is the RECORDED
                                    # expectations below (bat precedent)
  zig)  ext=.zig;   native=(zig run) ;;  # snap direct binary below
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
# Zig: prefer the direct snap binary (snap-confine fails in containers)
# over the /snap/bin wrapper — same rationale as the go case above.
zigbin=zig
if [ "$lang" = zig ]; then
  if [ -n "${ZIG:-}" ] && [ -x "$ZIG" ]; then
    zigbin="$ZIG"
  elif [ -x /snap/zig/current/bin/zig ]; then
    zigbin=/snap/zig/current/bin/zig
  fi
  native=( "$zigbin" run )
fi

# Native-interpreter limitation list: tests the NATIVE interpreter cannot
# run (a real language gap — e.g. fish has no heredocs at all) while the
# transpiled pipeline handles them. Listed tests compare the transpiled
# run against a RECORDED expected stdout (\n escapes) instead of the
# native run, so the transpiler path keeps real coverage. Format:
#   "name.ext|expected-stdout-with-\\n-escapes" (one entry per line)
native_limits_fish="t43_heredoc.fish|line1\nline2"
native_limits_powershell=""
native_limits_bat="t01_echo.bat|hello world\n
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
t12_forf.bat|word alpha\nword gamma\nitem one\npair x-y\ngot from\n
t13_v11.bat|defined\nnot-defined-2\npasswd-exists\nok\nnum 1\nnum 2\nnum 3\nonetwo\n
t14_call.bat|start\nhello World\nhello Batch\ndone\n
t15_fallthrough.bat|a\nb\nc\n
t16_case.bat|Hello\n100% percent\n
t17_amp.bat|one\ntwo\nthree\nafter\ndone\n
t18_comments.bat|before\nin-block\nafter\n
t19_arith.bat|x=9\nm=1\ny=10\nz=5\nn=20\ns=7\n
t20_forblock.bat|item alpha\nfirst\nitem beta\nlast\nnum 1\nnum 2\nnum 3\n
t21_exist.bat|exists\nnot-there\n
t22_subargs.bat|got one and two\ngot alpha and\n
t23_labels.bat|start\nmiddle\nend\n
t24_forf2.bat|whole=alpha beta gamma\nfirst=hello\nitem=one\n
t25_err.bat|before\nfailed\nerr=1\nhi\nerr2=0\n
t26_echoforms.bat|a\n\nb\n\nc\n\nd\n
t27_defined.bat|filled-defined\nempty-not\nempty-not-2\nmissing-not\n
t28_redirects2.bat|one\ntwo\none\ntwo\nthree\n
t29_mixed2.bat|name=bat\nis-bat\nequal\nword x\nword y\nword z\ndone\nreally\nthe-end\n
t30_substar.bat|all=a b c\nall=one\n
t34_dirs.bat|dirs-done\n
t35_arith3.bat|x=-5\ny=-3\nz=-3\nw=-6\n
t36_redirect_var.bat|hi\nmore\n
t37_ifexist_path.bat|there\nvar-there\n
t38_setvar.bat|hello world\nworld-world\n
t39_varblock.bat|x=5\ndeep\nv=5 i=1\nv=5 i=2\n
t40_echooff.bat|a\nb\n
t41_nestedfor.bat|1-x\n1-y\n2-x\n2-y\n
t42_nestedcall.bat|outer\ninner\nback\n
t43_midsub.bat|sub-run\nsub-run\nmain-done\n
t44_erase.bat|done\n
t45_fileflags.bat|z\n
t46_forftok.bat|got a-b\ntriple x-y-z\n
t47_exitval.bat|before\n
t48_robocopy.bat|one\ntwo\npurged\ngone\ndone\n
t49_robocopy2.bat|top-ok\nsub-no\ndry-clean\ntxt-ok\nlog-filtered\nxd-top-ok\nsub-excluded\nxf-top-ok\nskip-excluded\nlog-copy-ok\nlog-written\nmoved-ok\nsrc-moved\ndone\n
"

run_native() {  # <file> -> stdout on stdout
  local f=$1
  if [ "$lang" = zig ]; then
    # Zig's idiomatic std.debug.print writes to STDERR; the transpiled
    # target emits stdout — the observable output (2>&1) is the gate.
    (cd "$tmp" && timeout 20 "$zigbin" run "$f") < /dev/null 2>&1
  elif [ "$lang" = c ]; then
    cp "$f" "$tmp/main.c"
    (cd "$tmp" && timeout 20 cc main.c -o main 2>/dev/null && timeout 20 ./main) < /dev/null 2>/dev/null
  elif [ "$lang" = cpp ]; then
    cp "$f" "$tmp/main.cc"
    (cd "$tmp" && timeout 20 c++ main.cc -o main 2>/dev/null && timeout 20 ./main) < /dev/null 2>/dev/null
  elif [ "$lang" = rust ]; then
    cp "$f" "$tmp/main.rs"
    (cd "$tmp" && timeout 20 rustc main.rs -o main 2>/dev/null && timeout 20 ./main) < /dev/null 2>/dev/null
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
  # refusal pins (*_refuse.*) are the frontend's negative tests — the
  # emit MUST fail, so they are exercised by the frontend's own gate
  # (make test), never compared here.
  case "$bn" in *_refuse*) echo "SKIP $bn (refusal pin — asserted failing by the frontend gate)"; skips=$((skips+1)); continue ;; esac
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
    powershell) limits=$native_limits_powershell ;;
  esac
  native_out=""
  native_ran=0   # 1 when native_out came from an actual interpreter run (not a recorded limit)
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
    native_ran=1
  fi
  # 2. frontend emit
  if ! "$bin" --shir "$f" --raw > "$tmp/a1.json" 2>"$tmp/emit.err"; then
    echo "FAIL $bn (frontend emit: $(head -c 200 "$tmp/emit.err" 2>/dev/null | tr '\n' ' '))"
    fails=$((fails+1)); continue
  fi
  # 2a. out-parameter elimination (the C frontend's out-param channel):
  # a function with write-target pointer params echoes its values and the
  # caller captures them. Conservative — identity for programs without
  # out-params (multi-return A1, core request c-multi-return).
  if [ "$lang" = c ]; then
    if ! python3 "$root/harness/outparam_to_returns.py" < "$tmp/a1.json" > "$tmp/a1.t.json" 2>/dev/null; then
      echo "FAIL $bn (outparam transform)"
      fails=$((fails+1)); continue
    fi
    mv "$tmp/a1.t.json" "$tmp/a1.json"
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
  # 3. compare normalized stdout. The EXECUTION step is the only
  # nondeterministic link in the chain (emit + A1->ESTree are pure), and
  # under concurrent-gate load (several frontends run their runners on one
  # box) a node runner or native interpreter can be starved / timed out /
  # OOM-killed for EXACTLY ONE test (go-sh t02_assign_str at 16:56:55,
  # 1-in-36 gate runs, transpiled side empty). On mismatch, retry both
  # sides once — a real deterministic regression fails the retry too and is
  # still reported as DIFF/FAIL (same policy as the debashc relink retry
  # above; recorded-limit natives are never re-run).
  if [ "$(normalize "$native_out")" != "$(normalize "$trans_out")" ]; then
    sleep 1
    if [ "$native_ran" -eq 1 ]; then
      native_out=$(run_native "$f") || true
    fi
    trans_out=$(timeout 20 node "$runner" "$tmp/e.json" --source "$f" 2>/dev/null) || true
  fi
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
