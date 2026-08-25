#!/usr/bin/env bash
# compare_worktree_renderers.sh — measure TODO-stub counts from EACH backend
# worktree's authoritative renderer (what the gate builds/uses) vs main's
# current renderer. Shows which worktrees are ahead/superior (merging gains
# something) vs stale/inferior (merging would regress or gain little).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SUB="$ROOT/sh2perl"
MAIN_BIN="$SUB/target/debug/debashc"
CORPUS="$SUB/examples"

measure() {
  local bin="$1" lang="$2"
  local total=0 files=0 err=0
  for f in "$CORPUS"/*.sh; do
    shir=$("$MAIN_BIN" --shir "$f" --raw 2>/dev/null) || continue
    [ -z "$shir" ] && continue
    out=$(printf '%s' "$shir" | "$bin" "--shir-in-$lang" - 2>/dev/null) || { err=$((err+1)); continue; }
    s=$(printf '%s' "$out" | grep -oE 'sh2[A-Za-z_]+\(|TODO\(unsupported\)' | grep -v '^sh2perl(' | wc -l)
    [ "$s" -gt 0 ] && files=$((files+1))
    total=$((total+s))
  done
  echo "$total"
}

for lang in c go rust python zig sh java perl; do
  echo "=== $lang ==="
  mc=$(measure "$MAIN_BIN" "$lang")
  echo "  main renderer:        $mc stubs"
  wt="$SUB/backends/$lang"
  wtbin="$wt/target/debug/debashc"
  if [ -x "$wtbin" ]; then
    c=$(measure "$wtbin" "$lang")
    behind=$(git -C "$SUB" rev-list --count backend/$lang..main 2>/dev/null)
    echo "  $lang worktree renderer: $c stubs ($behind commits behind main)"
    verdict="SAME"
    if [ "$c" -lt "$mc" ]; then verdict="WORKTREE AHEAD (merging gains coverage)"; fi
    if [ "$c" -gt "$mc" ]; then verdict="WORKTREE BEHIND (stale; merging gains little)"; fi
    echo "  => $verdict"
  else
    echo "  $lang worktree: not built"
  fi
done
