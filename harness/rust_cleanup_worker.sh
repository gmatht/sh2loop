#!/usr/bin/env bash
# harness/rust_cleanup_worker.sh — remove unneeded i64 type annotations
# and .to_string() calls from Rust source.
#
# Mostly script-driven: finds candidates, removes each, compile-checks,
# keeps if it passes. Only escalates to LLM for ambiguous cases.
#
# Scope: sh2perl/src/ (all Rust source). Does NOT touch the parser/
# directory (single-owner core managed by the estree worker).
# Gate: cargo build + cargo test --lib
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
SUB="$ROOT/sh2perl"
LOG="$ROOT/loop-rust-cleanup.log"
REPORT="$ROOT/gate-reports/rust-cleanup.report"
LOCK="$ROOT/.gate.lock"
WATCH="${WATCH:-600}"

# Shared worker library (model, CLI, backoff).
[ -f "$ROOT/harness/worker_common.sh" ] && . "$ROOT/harness/worker_common.sh"

perl "$ROOT/harness/WorkerPool.pm" --enter-worker $$ >> "$LOG" 2>&1 || true
mkdir -p "$ROOT/gate-reports"
echo "[$(date +%FT%T)] rust-cleanup worker started (pid=$$)" >> "$LOG"

# Build once to ensure we start from a clean state.
build_ok() {
  ( flock 9; cargo build --manifest-path "$SUB/Cargo.toml" --lib >> "$LOG" 2>&1 )
  9>"$LOCK"
}

test_ok() {
  ( flock 9; cargo test --manifest-path "$SUB/Cargo.toml" --lib >> "$LOG" 2>&1 )
  9>"$LOCK"
}

# Find i64 annotation candidates: `let x: i64 = ...` or `let mut x: i64 = ...`
# where the rhs is a literal or known-i32 expression.
find_i64_candidates() {
  grep -rn ': i64' "$SUB/src/" --include='*.rs' \
    | grep -v '//' \
    | grep -v 'parser/' \
    | grep -v 'target/' \
    | grep -vE '(fn |pub fn |impl |trait |struct |enum |type )' \
    | head -20 || true
}

# Find .to_string() candidates: calls on string literals or &str where
# the target already accepts &str.
find_to_string_candidates() {
  grep -rn '\.to_string()' "$SUB/src/" --include='*.rs' \
    | grep -v '//' \
    | grep -v 'parser/' \
    | grep -v 'target/' \
    | grep -v 'test' \
    | head -20 || true
}

# Replace a specific line in a file. Args: $1=file, $2=line_number, $3=new_content
# Uses Python for robust handling of special characters in replacement text.
replace_line() {
  python3 -c "
import sys
lines = open(sys.argv[1]).readlines()
n = int(sys.argv[2]) - 1
lines[n] = sys.argv[3] + chr(10)
open(sys.argv[1], 'w').writelines(lines)
" "$1" "$2" "$3"
}

# Try removing an i64 annotation. Args: $1=file, $2=line_number
try_remove_i64() {
  local file="$1" line="$2"
  local original
  original=$(sed -n "${line}p" "$file")
  # Replace `: i64` with nothing (let the compiler infer)
  local modified
  modified=$(echo "$original" | sed 's/: i64//')
  if [ "$original" = "$modified" ]; then
    return 1  # nothing changed
  fi
  # Apply the change
  replace_line "$file" "$line" "$modified"
  # Compile-check
  if cargo build --manifest-path "$SUB/Cargo.toml" --lib >> "$LOG" 2>&1; then
    echo "[$(date +%FT%T)] removed i64 from $file:$line" >> "$LOG"
    return 0
  else
    # Revert
    replace_line "$file" "$line" "$original"
    return 1
  fi
}

# Try removing a .to_string() call. Args: $1=file, $2=line_number
try_remove_to_string() {
  local file="$1" line="$2"
  local original
  original=$(sed -n "${line}p" "$file")
  # Replace `.to_string()` with nothing
  local modified
  modified=$(echo "$original" | sed 's/\.to_string()//')
  if [ "$original" = "$modified" ]; then
    return 1  # nothing changed
  fi
  replace_line "$file" "$line" "$modified"
  if cargo build --manifest-path "$SUB/Cargo.toml" --lib >> "$LOG" 2>&1; then
    echo "[$(date +%FT%T)] removed .to_string() from $file:$line" >> "$LOG"
    return 0
  else
    replace_line "$file" "$line" "$original"
    return 1
  fi
}

# Ensure we start clean
if ! build_ok; then
  echo "[$(date +%FT%T)] initial build FAILED — aborting cleanup round" >> "$LOG"
  sleep "$WATCH"
fi

while true; do
  echo "[$(date +%FT%T)] rust-cleanup: iteration start" >> "$LOG"
  changes=0

  # ── Phase 1: remove unneeded i64 annotations ──
  echo "[$(date +%FT%T)] scanning for i64 candidates..." >> "$LOG"
  while IFS=: read -r file line _rest; do
    [ -z "$file" ] && continue
    # Extract just the line number (line comes before the colon-separated content)
    line_num=$(echo "$line" | tr -dc '0-9')
    [ -z "$line_num" ] && continue
    if try_remove_i64 "$file" "$line_num"; then
      changes=$((changes + 1))
    fi
  done < <(find_i64_candidates)

  # ── Phase 2: remove unneeded .to_string() calls ──
  echo "[$(date +%FT%T)] scanning for .to_string() candidates..." >> "$LOG"
  while IFS=: read -r file line _rest; do
    [ -z "$file" ] && continue
    line_num=$(echo "$line" | tr -dc '0-9')
    [ -z "$line_num" ] && continue
    if try_remove_to_string "$file" "$line_num"; then
      changes=$((changes + 1))
    fi
  done < <(find_to_string_candidates)

  # ── Phase 3: commit if we made changes and tests pass ──
  if [ $changes -gt 0 ]; then
    if test_ok; then
      git -C "$SUB" add src/ 2>/dev/null || true
      git -C "$SUB" commit -m "rust-cleanup: removed $changes unnecessary i64/.to_string() annotations" >> "$LOG" 2>&1 || true
      git -C "$ROOT" add sh2perl 2>/dev/null || true
      git -C "$ROOT" commit -m "rust-cleanup: gitlink bump" >> "$LOG" 2>&1 || true
      echo "[$(date +%FT%T)] committed $changes cleanup(s)" >> "$LOG"
      printf '%s rust-cleanup: committed %d removal(s)\n' "$(date +%FT%T)" "$changes" >> "$REPORT"
    else
      echo "[$(date +%FT%T)] tests failed after cleanup — reverting" >> "$LOG"
      git -C "$SUB" checkout -- src/ 2>/dev/null || true
      printf '%s rust-cleanup: REVERTED (tests failed after %d removal(s))\n' "$(date +%FT%T)" "$changes" >> "$REPORT"
    fi
  else
    echo "[$(date +%FT%T)] rust-cleanup: no removable candidates found" >> "$LOG"
    printf '%s rust-cleanup: clean (no candidates)\n' "$(date +%FT%T)" >> "$REPORT"
  fi

  sleep "$WATCH"
done
