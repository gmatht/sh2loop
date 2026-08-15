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
# Torn-write guard: frontend pi sessions rewrite this shared script IN
# PLACE (2026-08-12 13:13: rust-frontend adding run_estree while the
# py-sh-go gate was mid-run; that gate parsed a torn mix — "line 270:
# syntax error near unexpected token `same'" — AFTER its 74 tests had
# already passed, because bash's lazy tail-read landed mid-line in the
# new content). No reader can stop the in-place writer, but the reader
# CAN stop reading torn bytes: re-exec from a parse-verified snapshot.
# The snapshot (unique mktemp name) is never rewritten, so every later
# lazy read is stable; a torn COPY is caught by `bash -n` and retried
# while the writer settles (8 tries x 1s covers any realistic rewrite).
if [ -z "${FS_SNAPSHOT:-}" ]; then
  snap=""
  for _try in 1 2 3 4 5 6 7 8; do
    snap=$(mktemp "${TMPDIR:-/tmp}/frontend-stdout.XXXXXX") || exit 1
    if cp "$0" "$snap" 2>/dev/null && bash -n "$snap" 2>/dev/null; then
      break
    fi
    rm -f "$snap"
    snap=""
    sleep 1
  done
  if [ -n "$snap" ]; then
    # Re-exec from the stable snapshot. FS_ORIG_ROOT keeps $root
    # resolving to the REAL harness dir (dirname of the snapshot $0
    # is /tmp, which would misplace estree-runner.mjs).
    exec env FS_SNAPSHOT="$snap" FS_ORIG_ROOT="$(cd "$(dirname "$0")/.." && pwd)" \
      bash "$snap" "$@"
  fi
  echo "frontend-stdout.sh: no parse-clean snapshot obtainable (concurrent rewrite of the harness script?)" >&2
  exit 1
fi

set -u
lang=$1; bin=$2; dir=$3; debashc=$4
root=${FS_ORIG_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
runner="$root/harness/estree-runner.mjs"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"; rm -f "${FS_SNAPSHOT:-}"' EXIT
# Oracle stability: target/debug/debashc is rebuilt CONCURRENTLY by the
# estree worker (core changes) and by other gates' self-heal rules; a
# relink mid-gate tears the shared binary and fails exactly one test with
# a misleading "(A1 -> ESTree conversion)" (zsh-sh-go t71_var_name_mods
# 2026-08-12 20:55:24, debashc relinked 4s earlier; fish-sh-go t40 18:04;
# go-sh t02; estree worker log: "the binary is GONE", "binary was
# replaced under me"). Snapshot + functionally verify ONCE at gate
# start (harness/snapshot-debashc.sh); every conversion below then runs
# the stable copy, so a concurrent relink can never corrupt a mid-gate
# invocation. A genuinely unavailable oracle fails fast with a clear
# message instead of a random per-test FAIL.
snap="$tmp/debashc.snap"
if ! "$root/harness/snapshot-debashc.sh" "$debashc" "$snap" 2>"$tmp/snap.err"; then
  echo "frontend-stdout.sh: debashc oracle unavailable: $(head -c 200 "$tmp/snap.err" | tr '\n' ' ')" >&2
  exit 1
fi
# frontend binary: same tear class as debashc — the frontend's own gate
# (`make test` = rm + rebuild, or an in-place `go build -o`) can remove
# or replace $bin mid-run when a concurrent gate/coverage run overlaps
# this one, so an emit can hit "No such file or directory" or exec a
# partial binary (posix-sh-go t08-t11, 2026-08-13 15:17 — 4 consecutive
# FAILs mid-phase, then recovery). Snapshot the binary once at gate
# start; every emit below runs the stable copy, and a genuinely missing
# binary fails fast with one clear message instead of a random per-test
# FAIL. (The gate's build step runs before us, so a missing binary here
# means a broken build, not a by-design refusal — the per-test
# "(frontend emit: ...)" path below still classifies refusals.)
binpath=$bin
case "$bin" in
  /*) ;;
  *)  binpath="$(pwd)/$bin" ;;
esac
bin_snap="$tmp/frontend.snap"
if ! cp "$binpath" "$bin_snap" 2>"$tmp/bin.err"; then
  echo "frontend-stdout.sh: frontend binary unavailable ($binpath): $(head -c 200 "$tmp/bin.err" 2>/dev/null | tr '\n' ' ')" >&2
  exit 1
fi
bin="$bin_snap"

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
                                    # is the RECORDED expectations below.
                                    # On a WSL box the real interpreter is
                                    # reachable at the standard mount path:
                                    # prefer the LIVE cmd.exe oracle over the
                                    # record (CRLF staging in run_native).
                                    # cmdbin is set below; the record stays
                                    # the fallback when cmd.exe is absent.
  powershell) ext=.ps1; native=(pwsh -NoProfile -File) ;;  # live pwsh oracle
                                    # (2026-08-13; the /snap/bin wrapper
                                    # re-execs through snap-confine, so the
                                    # direct snap binary is preferred below)
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
# The snap layout puts the binary at /snap/zig/current/zig (some snaps
# expose a bin/ subdir); both are probed before the PATH fallback.
zigbin=zig
if [ "$lang" = zig ]; then
  if [ -n "${ZIG:-}" ] && [ -x "$ZIG" ]; then
    zigbin="$ZIG"
  elif [ -x /snap/zig/current/bin/zig ]; then
    zigbin=/snap/zig/current/bin/zig
  elif [ -x /snap/zig/current/zig ]; then
    zigbin=/snap/zig/current/zig
  fi
  native=( "$zigbin" run )
fi
# pwsh: the /snap/bin wrapper re-execs through snap-confine, which fails
# in containerized workers (same rationale as the go/zig cases) — prefer
# the direct snap binary, else a PWSH override, else PATH.
pwshbin=pwsh
if [ "$lang" = powershell ]; then
  if [ -n "${PWSH:-}" ] && [ -x "$PWSH" ]; then
    pwshbin="$PWSH"
  elif [ -x /snap/powershell/current/opt/powershell/pwsh ]; then
    pwshbin=/snap/powershell/current/opt/powershell/pwsh
  fi
  native=( "$pwshbin" -NoProfile -File )
fi
# cmd.exe live oracle for batch (WSL interop): the Windows interpreter at
# the standard WSL mount path. When present, the bat tests run through REAL
# cmd.exe instead of the recorded expectations — the strongest form of the
# cmd reference (capture-refs.sh --wsl stages the same run). Empty when
# cmd.exe is unreachable (non-WSL box) — the record is used then.
cmdbin=""
if [ "$lang" = bat ] && [ -x /mnt/c/Windows/System32/cmd.exe ]; then
  cmdbin=/mnt/c/Windows/System32/cmd.exe
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
t50_conjunction.bat|one\ntwo\ncaught\nfour\na\nb\nc\ndone\n
t51_shift.bat|arg one\narg two\narg three\ndone\n
t52_pipeline.bat|beta\npipe-end\n
t53_renpattern.bat|one\ntwo\n
"

run_native() {  # <file> -> stdout on stdout
  local f=$1
  if [ "$lang" = zig ]; then
    # Zig's idiomatic std.debug.print writes to STDERR; the transpiled
    # target emits stdout — the observable output (2>&1) is the gate.
    # `zig run` resolves its file argument against the CWD, and we cd
    # into the scratch dir first — resolve the (possibly relative) path
    # up front so the compile cache can hash the source.
    fabs=$(readlink -f "$f")
    (cd "$tmp" && timeout 20 "$zigbin" run "$fabs") < /dev/null 2>&1
  elif [ "$lang" = c ]; then
    cp "$f" "$tmp/main.c"
    (cd "$tmp" && timeout 20 cc main.c -o main 2>/dev/null && timeout 20 ./main) < /dev/null 2>/dev/null
  elif [ "$lang" = cpp ]; then
    cp "$f" "$tmp/main.cc"
    (cd "$tmp" && timeout 20 c++ main.cc -o main 2>/dev/null && timeout 20 ./main) < /dev/null 2>/dev/null
  elif [ "$lang" = rust ]; then
    # rustc is the slowest native toolchain in the fleet, and the first
    # compile of a gate run is the one most likely to be starved or
    # OOM-killed by a concurrent worker's cargo build (2026-08-12
    # 14:49: t01's native side returned empty on the first attempt AND
    # on the 1s outer retry, while the transpiled side was correct and
    # 19/20 other tests were green). Retry the compile+run with backoff
    # and a longer compile timeout so one cold-start hiccup cannot fail
    # the gate; a real regression fails every attempt and is still DIFF.
    cp "$f" "$tmp/main.rs"
    out=""
    for _try in 1 2 3; do
      out=$( (cd "$tmp" && timeout 60 rustc main.rs -o main 2>/dev/null && timeout 20 ./main) < /dev/null 2>/dev/null ) && break
      out=""
      [ "$_try" -lt 3 ] && sleep 3
    done
    printf '%s' "$out"
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
  elif [ "$lang" = py ]; then
    # py-sh-go t32_redirect: the same per-run scratch-dir isolation as
    # the go case above. The py parser only accepts a LITERAL path in
    # with open(PATH, MODE), so a unique-per-run path is impossible in
    # the source; instead both sides run in the gate's scratch dir and
    # the test uses a relative target (the go-sh precedent). A fixed
    # /tmp path collides across users (a stale root-owned /tmp/f blocks
    # llm's open with EACCES — 2026-08-12 gate DIFF on t32_redirect.py:
    # native python crashed before print, transpiled echoed fine).
    # Resolve the source to an absolute path BEFORE cd'ing (make test
    # passes the testdata dir relative to the frontend CWD): the gate's
    # scratch dir is a different CWD, and a relative "testdata/x.py"
    # would silently fail to open there (empty native stdout → 72
    # spurious DIFFs; the zig branch has the same readlink-first
    # pattern).
    fabs=$(readlink -f "$f")
    (cd "$tmp" && timeout 20 "${native[@]}" "$fabs") < /dev/null 2>/dev/null
  elif [ "$lang" = bat ]; then
    # cmd.exe REQUIRES CRLF batch files (LF-only files fail with "(echo was
    # unexpected at this time.") — stage a CRLF copy, then run via WSL
    # interop (`cmd /c call` — the call keeps the batch from aborting on
    # exit /b, mirroring refs/capture.cmd). cmd.exe inherits the harness
    # CWD (translated), so the batch's relative file ops land where the
    # transpiled side runs them; its CRLF stdout is normalized later.
    # Empty when cmd.exe is absent — the recorded limits cover that case.
    if [ -n "$cmdbin" ]; then
      fabs=$(readlink -f "$f")
      crlf="$tmp/$(basename "$f")"
      sed 's/$/\r/' "$fabs" > "$crlf"
      timeout 20 "$cmdbin" /c "call \"$crlf\"" < /dev/null 2>/dev/null
    fi
  else
    timeout 20 "${native[@]}" "$f" < /dev/null 2>/dev/null
  fi
}

normalize() { printf '%s' "$1" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }

run_estree() {  # <estree-json> <source-file> -> transpiled stdout
  # The go native side runs in the per-run scratch dir (run_native); run
  # the transpiled side in the same sandbox so relative-path file writes
  # (t32_redirect.go) land in the per-run dir on BOTH sides — an absolute
  # shared path (/tmp/f) collides across users and makes the transpiled
  # writeFile throw EACCES while native Go discards the error (flaky
  # DIFF). py-sh-go's t32_redirect.py needs the same isolation (literal
  # path in with open(...); a stale root-owned /tmp/f crashes the native
  # python side with EACCES before its print). Other langs run both sides
  # from the frontend dir; keep their CWD as-is.
  if [ "$lang" = go ] || [ "$lang" = py ]; then
    (cd "$tmp" && timeout 20 node "$runner" "$1" --source "$2" 2>"$tmp/estree.err") || true
  else
    timeout 20 node "$runner" "$1" --source "$2" 2>"$tmp/estree.err" || true
  fi
  # node's stderr (JS runtime errors, OOM kills, missing modules) is kept
  # in $tmp/estree.err per test; the DIFF branch surfaces it when the
  # transpiled side produced NOTHING, so an empty stdout is diagnosable.
}

total=0; fails=0; skips=0
compare_phase() {  # one pass over all tests; returns 0 iff every test passed
  total=0; fails=0; skips=0
# Cache this verdict to .frontend_gate.tsv (lang<TAB>file<TAB>PASS|FAIL|SKIP)
# — the otranspiler GUI's sync-backend-gates.sh consumes it to colour the
# per-frontend example buttons + source pills. Appends only; the GUI keeps
# the LAST row per (lang,file), so concurrent worker gates just refresh it.
# One short line per verdict — a torn write across concurrent appends is
# impossible for writes < PIPE_BUF under O_APPEND.
record() {  # status bn
  printf '%s\t%s\t%s\n' "$lang" "$bn" "$1" >> "$root/.frontend_gate.tsv" 2>/dev/null || true
}
for f in "$dir"/*"$ext"; do
  [ -f "$f" ] || continue
  bn=$(basename "$f"); total=$((total+1))
  # refusal pins (*_refuse.*) are the frontend's negative tests — the
  # emit MUST fail, so they are exercised by the frontend's own gate
  # (make test), never compared here.
  case "$bn" in *_refuse*) record SKIP; echo "SKIP $bn (refusal pin — asserted failing by the frontend gate)"; skips=$((skips+1)); continue ;; esac
  if [ "$lang" != go ] && [ "$lang" != bat ] && [ "$lang" != powershell ] && ! command -v "${native[0]}" >/dev/null 2>&1; then
    record SKIP; echo "SKIP $bn (native interpreter '${native[0]}' not installed)"
    skips=$((skips+1)); continue
  fi
  # 1. native execution (capture stdout even on nonzero exit). A test on
  # the native-limitation list compares against its RECORDED expected
  # stdout instead (the native interpreter cannot run it — a runtime
  # limitation, never a transpiler bug).
  limits=""
  case "$lang" in
    fish) limits=$native_limits_fish ;;
    bat)  limits=$native_limits_bat
          # live cmd.exe oracle — prefer the REAL interpreter over the record
          [ -n "$cmdbin" ] && limits=""
          ;;
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
    record FAIL; echo "FAIL $bn (frontend emit: $(head -c 200 "$tmp/emit.err" 2>/dev/null | tr '\n' ' '))"
    fails=$((fails+1)); continue
  fi
  # 2a. out-parameter elimination (the C frontend's out-param channel):
  # a function with write-target pointer params echoes its values and the
  # caller captures them. Conservative — identity for programs without
  # out-params (multi-return A1, core request c-multi-return).
  if [ "$lang" = c ]; then
    if ! python3 "$root/harness/outparam_to_returns.py" < "$tmp/a1.json" > "$tmp/a1.t.json" 2>/dev/null; then
      record FAIL; echo "FAIL $bn (outparam transform)"
      fails=$((fails+1)); continue
    fi
    mv "$tmp/a1.t.json" "$tmp/a1.json"
  fi
  # 2b. A1 -> ESTree. The gate-start snapshot (above) is already
  # functionally verified, so this normally cannot fail; keep the retry
  # as defense-in-depth for a pathological snapshot (a real deterministic
  # regression fails the retry too and is still reported as FAIL).
  if ! "$snap" --shir-in-estree "$tmp/a1.json" > "$tmp/e.json" 2>/dev/null; then
    sleep 3
    if ! "$snap" --shir-in-estree "$tmp/a1.json" > "$tmp/e.json" 2>/dev/null; then
      echo "FAIL $bn (A1 -> ESTree conversion)"
      record FAIL; fails=$((fails+1)); continue
    fi
  fi
  # 2c. run transpiled JS
  trans_out=$(run_estree "$tmp/e.json" "$f")
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
    trans_out=$(run_estree "$tmp/e.json" "$f")
  fi
  # Second chance: the core's debashc binary is rebuilt CONCURRENTLY by
  # the estree worker while implementing core requests (src/estree.rs,
  # src/shir.rs held mid-edit). A snapshot taken from such a build can
  # render exit-0-but-UNRUNNABLE ESTree for real programs (a SyntaxError
  # or an immediate runtime crash) while the minimal empty-program
  # snapshot verify passes — every test then DIFFs with empty transpiled
  # stdout, and the retry above reuses the SAME broken e.json
  # (fish-sh-go 2026-08-15 17:27:56: 0/80 match while the estree worker
  # held src/estree.rs mid-edit; gate green again after its next build
  # landed). On a persistent mismatch, re-snapshot the oracle (picks up
  # the settled build), re-convert, and re-run BOTH sides once. A real
  # deterministic regression fails this tier too and is still reported
  # as DIFF/FAIL (same policy as the relink retries above).
  if [ "$(normalize "$native_out")" != "$(normalize "$trans_out")" ]; then
    if "$root/harness/snapshot-debashc.sh" "$debashc" "$snap" 2>/dev/null && \
       "$snap" --shir-in-estree "$tmp/a1.json" > "$tmp/e.json" 2>/dev/null; then
      if [ "$native_ran" -eq 1 ]; then
        native_out=$(run_native "$f") || true
      fi
      trans_out=$(run_estree "$tmp/e.json" "$f")
    fi
  fi
  if [ "$(normalize "$native_out")" = "$(normalize "$trans_out")" ]; then
    record PASS; echo "OK   $bn (stdout match)"
  else
    record FAIL; echo "DIFF $bn (stdout mismatch)"
    diff <(printf '%s\n' "$native_out") <(printf '%s\n' "$trans_out") \
      | head -6 | sed 's/^/     /'
    # Empty transpiled stdout + a node stderr capture = the runner died
    # before printing anything ("Killed" OOM, "FATAL ERROR: ...",
    # "Cannot find module"). Show it: an all-empty DIFF row is otherwise
    # indistinguishable from a real regression (c-sh-go 2026-08-15
    # 17:23 gate: every test DIFFed empty while the estree worker's
    # concurrent cargo rebuild of debashc starved/OOM-killed node).
    if [ -z "$(normalize "$trans_out")" ] && [ -s "$tmp/estree.err" ]; then
      sed 's/^/     [estree stderr] /' "$tmp/estree.err" | head -5
    fi
    fails=$((fails+1))
  fi
done
echo "--- frontend-stdout [$lang]: $((total-fails-skips))/$total match, $fails FAIL, $skips SKIP"
[ "$fails" -eq 0 ]
}

# System-wide transient guard (c-sh-go 2026-08-15 17:23 gate FAIL): the
# estree worker's concurrent `cargo build` of the shared debashc oracle
# (a multi-GB rustc) starved/OOM-killed EVERY node execution in the phase
# — 0/103 transpiled runs produced output, so the per-test retry (above)
# could not help: the whole window was affected and every test DIFFed
# with EMPTY transpiled stdout. A deterministic regression is unaffected
# (it fails the retry too, and the gate still FAILs); this only rescues
# genuine system-wide transients, exactly like the snapshot/retry layers
# already in place for torn binaries. The retry re-runs the ENTIRE phase
# (native + transpiled) after a 45s backoff that lets a concurrent relink
# finish.
if ! compare_phase; then
  if [ "$total" -gt 0 ] && [ "$fails" -eq "$total" ]; then
    echo "frontend-stdout.sh: ALL $total tests failed — likely a system-wide transient (concurrent core rebuild starving node?); retrying the whole phase once after 45s" >&2
    sleep 45
    compare_phase
  else
    false   # partial failure: a real regression — do NOT mask it with a retry
  fi
fi
