#!/usr/bin/env bash
# progress.sh — show worker progress over a time window.
# Usage: ./progress.sh [hours] (default: 4)
set -u
cd "$(dirname "$0")"
HOURS="${1:-4}"
SINCE="$HOURS hours ago"

echo "=== Progress over last ${HOURS}h ($(date)) ==="
echo ""

# ── Fail count trend (from commit messages) ──────────────────────────
echo "--- Perl corpus fail count (from commits) ---"
fail_counts=$(git log --since="$SINCE" --oneline --all 2>/dev/null | grep -o 'fail [0-9]* -> [0-9]*' | tac)
if [ -n "$fail_counts" ]; then
  # After tac: oldest first, newest last
  first=$(echo "$fail_counts" | head -1 | awk -F' -> ' '{print $1}' | awk '{print $NF}')
  last=$(echo "$fail_counts" | tail -1 | awk -F' -> ' '{print $2}')
  if [ -n "$first" ] && [ -n "$last" ]; then
    delta=$((first - last))
    echo "  $first → $last ($delta fixed)"
  fi
  echo "$fail_counts" | tail -10 | sed 's/^/  /'
else
  echo "  (no fail-count changes in this window)"
fi

echo ""

# ── Git commits per worker ───────────────────────────────────────────
echo "--- Commits by worker (last ${HOURS}h) ---"
total=0
for tag in "perl:" "rust:" "python:" "fish" "zsh" "zig" "rust-frontend" "rust-cleanup" "py-idiom" "bump sh2perl" "ingress"; do
  count=$(git log --since="$SINCE" --oneline --all 2>/dev/null | grep -ci "$tag" || true)
  if [ "$count" -gt 0 ]; then
    printf "  %-16s %d commit(s)\n" "$tag" "$count"
    total=$((total + count))
  fi
done
[ "$total" -eq 0 ] && echo "  (none)"
echo "  TOTAL: $total"

echo ""

# ── sh2perl submodule commits ────────────────────────────────────────
echo "--- sh2perl submodule commits (last ${HOURS}h) ---"
sub_count=$(git -C sh2perl log --since="$SINCE" --oneline 2>/dev/null | wc -l)
if [ "$sub_count" -gt 0 ]; then
  git -C sh2perl log --since="$SINCE" --oneline 2>/dev/null | head -15 | sed 's/^/  /'
  [ "$sub_count" -gt 15 ] && echo "  ... ($sub_count total)"
else
  echo "  (none)"
fi

echo ""

# ── Current gate status ──────────────────────────────────────────────
echo "--- Current gate status ---"
# Perl corpus — try multiple sources
if [ -f sh2perl/failing_tests.txt ]; then
  perl_fails=$(wc -l < sh2perl/failing_tests.txt 2>/dev/null || echo "?")
  echo "  Perl corpus: $perl_fails failures"
else
  # Fall back to last commit message
  last_fail=$(git log -1 --oneline --all 2>/dev/null | grep -o 'fail [0-9]*' | awk '{print $2}')
  echo "  Perl corpus: ${last_fail:-?} failures (from last commit)"
fi

# Estree — parse the TSV header for the last row
if [ -f .estree_failures.tsv ]; then
  estree_last=$(tail -1 .estree_failures.tsv 2>/dev/null)
  estree_pass=$(echo "$estree_last" | awk -F'\t' '{for(i=1;i<=NF;i++) if($i ~ /pass/) print $(i-1)}' | head -1)
  estree_fail=$(echo "$estree_last" | awk -F'\t' '{for(i=1;i<=NF;i++) if($i ~ /fail/) print $(i-1)}' | head -1)
  echo "  Estree: ${estree_pass:-?} pass, ${estree_fail:-?} fail"
else
  echo "  Estree: (no data)"
fi

# Rust cleanup
cleanup_commits=$(git -C sh2perl log --since="$SINCE" --oneline 2>/dev/null | grep -c cleanup || true)
echo "  Rust cleanup: $cleanup_commits commit(s) this window"

echo ""

# ── Worker alive status ──────────────────────────────────────────────
echo "--- Workers alive ---"
for name in core triage perl estree fish zsh zig rust-frontend rust-cleanup; do
  case $name in
    core) pat="run_core_worker" ;;
    triage) pat="run_triage_worker" ;;
    perl) pat="main_loop_rust.pl" ;;
    estree) pat="main_loop_estree.pl" ;;
    fish) pat="fish-sh-go/run_frontend" ;;
    zsh) pat="zsh-sh-go/run_frontend" ;;
    zig) pat="zig-sh-go/run_frontend" ;;
    rust-frontend) pat="rust-frontend/run_frontend" ;;
    rust-cleanup) pat="rust_cleanup_worker" ;;
  esac
  # NOTE: `pgrep -f "$pat"` is a SUBSTRING match — it also matches this
  # script's own `/bin/sh -c` line (progress.sh *contains* the pattern),
  # so it always self-reports "alive". Use pgrep -x (exact command name)
  # for name-only patterns, and for path patterns exclude our own pid,
  # our parent shell, and any other bash -c wrapper that merely quotes
  # the pattern (that is exactly the false positive we are fixing).
  pids=""
  while read -r p; do
    [ -n "$p" ] || continue
    [ "$p" = "$$" ] && continue            # this script
    [ "$p" = "$PPID" ] && continue         # the invoking shell (bash -c '...progress.sh')
    cmd=$(ps -o args= -p "$p" 2>/dev/null) || continue
    case "$cmd" in
      *-c*"$pat"*) continue ;;             # a wrapper bash -c merely quoting the pattern
    esac
    pids="$pids $p"
  done < <(pgrep -f "$pat" 2>/dev/null)

  # A worker sleeping between iterations writes nothing to its log; a
  # dead one is silently gone. Report the last log line's age so "✓ but
  # idle for 3h" is distinguishable from "✓ and working".
  idle=""
  case $name in
    core) wlog="loop-core-worker.log" ;;
    triage) wlog="loop-triage-worker.log" ;;
    perl) wlog="loop-perl-worker.log" ;;
    estree) wlog="loop-estree.log" ;;
    fish) wlog="loop-frontend-fish-sh-go.log" ;;
    zsh) wlog="loop-frontend-zsh-sh-go.log" ;;
    zig) wlog="loop-frontend-zig-sh-go.log" ;;
    rust-frontend) wlog="loop-frontend-rust-frontend.log" ;;
    rust-cleanup) wlog="loop-rust-cleanup.log" ;;
  esac
  if [ -n "$pids" ] && [ -n "${wlog:-}" ] && [ -f "$wlog" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$wlog" 2>/dev/null || echo "$(date +%s)") ))
    if   [ "$age" -lt 900 ];  then idle=" (log ${age}s ago)"
    elif [ "$age" -lt 3600 ]; then idle=" (log $((age/60))m ago)"
    else idle=" (log stale: $((age/3600))h$(( (age%3600)/60 ))m — idle between iterations?)"
    fi
  fi

  if [ -n "$pids" ]; then
    printf "  %-16s ✓%s\n" "$name" "$idle"
  else
    printf "  %-16s ✗\n" "$name"
  fi
done
