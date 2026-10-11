#!/usr/bin/env bash
# go_diff.sh — show ONE corpus file's go-vs-bash differential in detail.
#
# WHY: harness/go_fast_equiv.sh gives the verdict per file but deletes its
# scratch on exit, so a DIFF cannot be inspected. This keeps the render and
# both outputs on disk and prints the unified diff plus the render's
# bash -c seams, which is what a lowering decision needs.
#
#   usage: harness/go_diff.sh <file.sh>
set -u
ROOT=/mnt/wsl/projects/sh2loop
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
R="${GO_SHIR_RENDER:-$ROOT/sh2perl/backends/go/target/debug/shir_render}"
GO=$(command -v go)
CACHE="${GO_FAST_CACHE:-/mnt/wsl/tmpbtrfs/go-fast-cache}"
mkdir -p "$CACHE/gocache" "$CACHE/gomodcache"
export GOCACHE="$CACHE/gocache" GOMODCACHE="$CACHE/gomodcache" GOFLAGS=-mod=mod

f=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
out="/tmp/commandcode/shellout/godiff.$(basename "$f" .sh)"
rm -rf "$out"; mkdir -p "$out"

"$CLI" --target shir "$f" > "$out/a1.json" 2>/dev/null || { echo "A1 emit failed"; exit 1; }
"$R" --target=go - < "$out/a1.json" > "$out/main.go" 2>/dev/null || { echo "render failed"; exit 1; }
cp "$out/main.go" "$out/main.go.bak"
( cd "$out" && timeout 90 "$GO" build -o prog main.go ) 2> "$out/compile.err"
build_rc=$?
if [ $build_rc -ne 0 ]; then
  echo "== COMPILE ERROR =="; sed -n '1,30p' "$out/compile.err"; exit 0
fi
( cd "$out" && timeout 30 ./prog ) > "$out/go.out" 2>/dev/null; go_rc=$?
( cd "$out" && timeout 30 bash "$f" ) > "$out/bash.out" 2>/dev/null; bash_rc=$?

echo "file:    $f"
echo "render:  $out/main.go"
echo "rc:      go=$go_rc bash=$bash_rc"
echo "seams:   $(grep -cE 'capRun|redirRun' "$out/main.go") bash -c sites, $(grep -c 's2s(' "$out/main.go") s2s"
echo "== stdout diff (bash < | > go) =="
diff "$out/bash.out" "$out/go.out" | sed -n '1,40p'
echo "== bash -c scripts in the render =="
grep -oE '(capRun|redirRun)\("[^"]*"' "$out/main.go" | sed 's/^/  /' | head -12
