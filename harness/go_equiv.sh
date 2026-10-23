#!/usr/bin/env bash
# go_equiv.sh — the go backend's EXECUTED-equivalence oracle.
#
# WHY THIS EXISTS. setup_backends.sh's --backend-gate compares the rendered
# program's stdout against `bash file` for every backend with a toolchain.
# For go it looks for `/snap/go/current/bin/go`; on a box where the toolchain
# lives elsewhere (e.g. /usr/bin/go) that probe fails and eq_gate stays 0 —
# the gate then prints `equiv: 0 pass vs bash`, which reads as "no equivalence
# failures" while meaning "no equivalence MEASUREMENT". A renderer can regress
# its programs' behaviour and the gate verdict does not move.
#
# This script is that measurement, taken locally, so a lowering change can be
# checked before it is committed: render → go build → run, and compare stdout
# with bash's, exactly as the gate does (STDERR IS IGNORED on both sides — the
# gate compares stdout only).
#
#   usage: harness/go_equiv.sh [-j N] [--keep] [file.sh ...]
#          (no files → the whole corpus under sh2perl/examples)
#   out:   <cache>/<name>/{main.go,go.out,bash.out,compile.err}
#   exit:  0 all equivalent, 1 at least one diff/compile error
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
R="${GO_SHIR_RENDER:-$ROOT/sh2perl/backends/go/target/debug/shir_render}"
GO="${GO:-$(command -v go)}"
JOBS=4
CACHE="${GO_EQUIV_CACHE:-/mnt/wsl/tmpbtrfs/go-equiv-cache}"

files=()
while [ $# -gt 0 ]; do
  case "$1" in
    -j) JOBS="$2"; shift 2;;
    --keep) shift;;
    *) files+=("$1"); shift;;
  esac
done
[ ${#files[@]} -eq 0 ] && files=("$ROOT"/sh2perl/examples/*.sh)

[ -x "$CLI" ] || { echo "go_equiv: missing $CLI" >&2; exit 1; }
[ -x "$R" ]   || { echo "go_equiv: missing $R (cargo build --bin shir_render)" >&2; exit 1; }
[ -n "$GO" ] && [ -x "$GO" ] || { echo "go_equiv: no go toolchain" >&2; exit 1; }

mkdir -p "$CACHE/gocache" "$CACHE/gomodcache"
export GOCACHE="$CACHE/gocache" GOMODCACHE="$CACHE/gomodcache" GOFLAGS=-mod=mod GO111MODULE=on

one() { # $1 = .sh file
  f=$(cd "$(dirname "$1")" && pwd)/$(basename "$1"); b=$(basename "$f" .sh)
  d="$CACHE/$b"; rm -rf "$d"; mkdir -p "$d"
  "$CLI" --target shir "$f" > "$d/a1.json" 2>/dev/null || { echo "EMIT $b"; return; }
  [ -s "$d/a1.json" ] || { echo "EMIT $b"; return; }
  "$R" --target=go - < "$d/a1.json" > "$d/main.go" 2>/dev/null || { echo "RENDER $b"; return; }
  ( cd "$d" && timeout 120 "$GO" build -o prog main.go ) 2> "$d/compile.err" \
    || { echo "BUILD $b"; return; }
  ( cd "$d" && timeout 60 ./prog ) > "$d/go.out" 2>/dev/null
  ( cd "$d" && timeout 60 bash "$f" ) > "$d/bash.out" 2>/dev/null
  if cmp -s "$d/bash.out" "$d/go.out"; then
    echo "PASS $b"
  else
    echo "DIFF $b"
  fi
}
export -f one
export CLI R GO CACHE

res=$(printf '%s\n' "${files[@]}" | xargs -P "$JOBS" -I{} bash -c 'one "$@"' _ {})

pass=$(printf '%s\n' "$res" | grep -c '^PASS' || true)
diff=$(printf '%s\n' "$res" | grep -c '^DIFF' || true)
build=$(printf '%s\n' "$res" | grep -c '^BUILD' || true)
render=$(printf '%s\n' "$res" | grep -c '^RENDER' || true)
emit=$(printf '%s\n' "$res" | grep -c '^EMIT' || true)
total=$((pass + diff + build + render + emit))

echo "go equiv: $pass/$total pass, $diff stdout-diff, $build build-fail, $render render-fail, $emit emit-fail"
printf '%s\n' "$res" | grep -vE '^PASS' | sed 's/^/  /' | head -60
[ "$diff" -eq 0 ] && [ "$build" -eq 0 ] && [ "$render" -eq 0 ] && [ "$emit" -eq 0 ]
