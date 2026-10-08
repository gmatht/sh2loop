#!/usr/bin/env bash
# bat-triage-repro.sh — reproduce the bat-sh-go cross-product triage failures.
#
# The bat native side is cmd.exe (Windows-only), so the AUTHORITATIVE
# expectation is the recorded native stdout carried by the shared gate
# (harness/bat-expected.tsv, extracted verbatim from the native_limits_bat
# block in harness/frontend-stdout.sh — that block IS the record, since
# capture-refs.sh cannot run cmd.exe here).
#
# For each (backend, example): emit A1 via the frontend, render it with
# otranspilerl-cli, run the rendered program, compare stdout against the
# record. This is the cross-product the triage requests are about: estree
# passes (the reference), the named backend differs.
#
# Usage: harness/bat-triage-repro.sh <backend> <example>...
#        harness/bat-triage-repro.sh --sweep <backend>
# Keep: set BAT_KEEP=1 to retain the per-case workdirs (with the rendered
# program) for inspection.
set -u

ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
FRONTEND="$ROOT/sh2perl/frontends/bat-sh-go"
CLI="${BAT_CLI:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
TD="$FRONTEND/testdata"
EXPECT="$ROOT/harness/bat-expected.tsv"

die() { printf 'bat-triage-repro.sh: %s\n' "$*" >&2; exit 2; }
[ -x "$CLI" ] || die "otranspilerl-cli not found/executable at $CLI (cargo build --bin otranspilerl-cli in otranspilerl/)"
[ -f "$EXPECT" ] || die "expectation table missing: $EXPECT"

# Recorded expectation for an example name, \n-unescaped to real newlines.
expected_for() {
  command grep -m1 "^$1|" "$EXPECT" | cut -d'|' -f2- \
    | sed 's/\\n/\n/g'
}

ext_for() {
  case "$1" in
    rust)   printf 'rs' ;;
    python) printf 'py' ;;
    perl)   printf 'pl' ;;
    estree) printf 'mjs' ;;
    *)      printf 'sh' ;;
  esac
}

run_rendered() { # backend, rendered-file, workdir, source-file -> stdout
  local bk=$1 f=$2 wd=$3 src=$4
  case "$bk" in
    rust)   ( cd "$wd" && rustc -A warnings -o prog "$f" >/dev/null 2>&1 && ./prog 2>/dev/null ) ;;
    sh)     ( cd "$wd" && timeout 10 sh "$f" 2>/dev/null ) ;;
    python) ( cd "$wd" && timeout 10 python3 "$f" 2>/dev/null ) ;;
    perl)   ( cd "$wd" && timeout 10 perl "$f" 2>/dev/null ) ;;
    # estree emits raw ESTree JSON; the shared runner supplies the sh2
    # runtime the program calls into (same invocation as frontend-stdout.sh).
    estree) ( cd "$wd" && timeout 20 node "$ROOT/harness/estree-runner.mjs" "$wd/$f" --source "$src" 2>/dev/null ) || true ;;
    *)      return 1 ;;
  esac
}

one() { # backend, example (with .bat)
  local bk=$1 ex=$2
  local src="$TD/$ex"
  [ -f "$src" ] || { printf '%-7s %-20s SKIP (no testdata example)\n' "$bk" "$ex"; return 0; }
  local want; want=$(expected_for "$ex")
  [ -n "$want" ] || { printf '%-7s %-20s SKIP (no recorded expectation)\n' "$bk" "$ex"; return 0; }

  local wd; wd=$(mktemp -d "${TMPDIR:-/tmp}/batrepro.${bk}.${ex%.bat}.XXXXXX")
  local ext; ext=$(ext_for "$bk")

  if ! "$FRONTEND/bat-sh-go" --shir "$src" --raw > "$wd/a1.json" 2>"$wd/emit.err"; then
    printf '%-7s %-20s FAIL (frontend emit: %s)\n' "$bk" "$ex" "$(head -1 "$wd/emit.err")"
    rm -rf "$wd"; return 1
  fi

  if ! "$CLI" - --target "$bk" < "$wd/a1.json" > "$wd/main.$ext" 2>"$wd/render.err"; then
    printf '%-7s %-20s FAIL (render: %s)\n' "$bk" "$ex" "$(head -1 "$wd/render.err")"
    rm -rf "$wd"; return 1
  fi

  local got; got=$(run_rendered "$bk" "main.$ext" "$wd" "$src")

  # Same normalization the shared gate uses: strip \r, trim edge whitespace.
  local gn wn
  gn=$(printf '%s' "$got"  | tr -d '\r' | sed -e 's/[[:space:]]*$//')
  wn=$(printf '%s' "$want" | tr -d '\r' | sed -e 's/[[:space:]]*$//')

  if [ "$gn" = "$wn" ]; then
    printf '%-7s %-20s OK\n' "$bk" "$ex"
    [ "${BAT_KEEP:-0}" = 1 ] || rm -rf "$wd"
    return 0
  fi

  printf '%-7s %-20s DIFFERS\n' "$bk" "$ex"
  printf '  want: %s\n' "$(printf '%s' "$wn"  | tr '\n' '|')"
  printf '  got : %s\n' "$(printf '%s' "$got" | tr '\n' '|')"
  printf '  --- rendered %s ---\n' "$ext"
  sed 's/^/  | /' "$wd/main.$ext" | head -40
  [ "${BAT_KEEP:-0}" = 1 ] || rm -rf "$wd"
  return 1
}

if [ "${1:-}" = "--sweep" ]; then
  [ $# -ge 2 ] || die "usage: $0 --sweep <backend>"
  bk=$2
  fails=0; total=0
  for f in "$TD"/*.bat; do
    ex=$(basename "$f")
    total=$((total+1))
    one "$bk" "$ex" || fails=$((fails+1))
  done
  printf '\nsweep %s: %d/%d differ or fail\n' "$bk" "$fails" "$total"
  exit $((fails>0))
fi

[ $# -ge 2 ] || die "usage: $0 <backend> <example>... | --sweep <backend>"
bk=$1; shift
rc=0
for ex in "$@"; do one "$bk" "$ex" || rc=1; done
exit $rc