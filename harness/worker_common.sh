#!/usr/bin/env bash
# harness/worker_common.sh — shared functions for all workers.
#
# Source this file at the top of each worker script:
#   source "$WORKSPACE/harness/worker_common.sh"
#
# Provides:
#   - Configurable CLI (pi / pir / cmd) with model + effort
#   - invoke_ai_with_backoff() — exponential retry wrapper
#   - log_decision() — append to TSV decision log
#   - generate_decision_report() — append .md decision report
#   - build_surgical_prompt() — concise per-task context template
#   - check_context_budget() — warn/truncate if prompt is too large

# ── CLI configuration ────────────────────────────────────────────────
# Which AI CLI to invoke: pi, pir, or cmd.
#   pi   — opencode-go provider (existing setup, limited model catalog)
#   pir  — pi with retry (if your pi variant supports it)
#   cmd  — Command Code headless (full catalog incl. Laguna, $0/$0)
WORKER_CLI="${WORKER_CLI:-cmd}"

# Model. For cmd: any Command Code catalog id (poolside/laguna-s-2.1-free,
#   deepseek-v4-flash, claude-sonnet-5, etc.). For pi/pir: whatever
#   opencode-go serves. Override: WORKER_MODEL=deepseek-v4-flash
# TODO: escalate to DeepSeek for complex failures Laguna can't handle.
WORKER_MODEL="${WORKER_MODEL:-poolside/laguna-s-2.1-free}"

# Reasoning effort. For pi/pir: maps to --thinking. For cmd: maps to
#   --effort. Laguna has no effort levels — leave empty. Set for models
#   that support it (e.g. WORKER_EFFORT=xhigh for deepseek-v4-flash).
WORKER_EFFORT="${WORKER_EFFORT:-}"

# Backward compat: accept WORKER_THINKING as alias for WORKER_EFFORT.
WORKER_EFFORT="${WORKER_EFFORT:-${WORKER_THINKING:-}}"

# ── Exponential backoff configuration ────────────────────────────────
BACKOFF_BASE="${BACKOFF_BASE:-5}"
BACKOFF_MAX="${BACKOFF_MAX:-300}"
BACKOFF_MULTIPLIER="${BACKOFF_MULTIPLIER:-2}"
BACKOFF_MAX_RETRIES="${BACKOFF_MAX_RETRIES:-30}"

# ── Decision log ─────────────────────────────────────────────────────
DECISIONS_TSV="${DECISIONS_TSV:-${WORKSPACE:-.}/worker_decisions.tsv}"

# ── invoke_ai ────────────────────────────────────────────────────────
# Invoke the configured AI CLI once (no retry).
# Args: $1=prompt_file, $2=log_file
# Reads the prompt from $prompt_file and appends output to $log_file.
# Returns the CLI's exit code.
invoke_ai() {
  local prompt_file="$1" log_file="$2"
  case "$WORKER_CLI" in
    pi|pir)
      local args=(--mode json --provider opencode-go --model "$WORKER_MODEL")
      [ -n "$WORKER_EFFORT" ] && args+=(--thinking "$WORKER_EFFORT")
      "$WORKER_CLI" "${args[@]}" < "$prompt_file" >> "$log_file" 2>&1
      ;;
    cmd)
      local args=(-p --no-session --yolo --model "$WORKER_MODEL" --output-format json --tools-all)
      [ -n "$WORKER_EFFORT" ] && args+=(--effort "$WORKER_EFFORT")
      # Pass prompt via temp file expansion. For large prompts, cmd -p
      # reads from stdin when no query argument is given.
      local query
      query=$(< "$prompt_file")
      # Check if query fits in ARG_MAX (leave 10KB headroom)
      if [ ${#query} -gt 100000 ]; then
        # Large prompt: pipe via stdin (cmd -p with no query arg reads stdin)
        cmd "${args[@]}" < "$prompt_file" >> "$log_file" 2>&1
      else
        cmd "${args[@]}" "$query" >> "$log_file" 2>&1
      fi
      ;;
    *)
      echo "[$(date +%FT%T)] ERROR: Unknown WORKER_CLI=$WORKER_CLI (expected pi|pir|cmd)" >> "$log_file"
      return 1
      ;;
  esac
}

# ── invoke_ai_with_backoff ───────────────────────────────────────────
# Invoke the configured AI CLI with exponential backoff on failure.
# Args: $1=prompt_file, $2=log_file
# Returns 0 on success, 1 after exhausting retries.
# Checks context budget before invoking (truncates if too large).
invoke_ai_with_backoff() {
  local prompt_file="$1" log_file="$2"
  local attempt=0
  local delay=$BACKOFF_BASE

  # Context budget guard: truncate if prompt is too large for the model.
  # Laguna has 256K context; cap input at 200K tokens (~800KB).
  check_context_budget "$prompt_file" "$log_file" 200000 || true

  while [ $attempt -lt $BACKOFF_MAX_RETRIES ]; do
    if invoke_ai "$prompt_file" "$log_file"; then
      return 0
    fi
    local rc=$?
    attempt=$((attempt + 1))
    echo "[$(date +%FT%T)] $WORKER_CLI failed (rc=$rc, attempt $attempt/$BACKOFF_MAX_RETRIES), retry in ${delay}s" >> "$log_file"
    sleep "$delay"
    delay=$((delay * BACKOFF_MULTIPLIER))
    [ $delay -gt $BACKOFF_MAX ] && delay=$BACKOFF_MAX
  done

  echo "[$(date +%FT%T)] $WORKER_CLI failed after $BACKOFF_MAX_RETRIES attempts — giving up" >> "$log_file"
  return 1
}

# ── build_surgical_prompt ────────────────────────────────────────────
# Build a concise, focused prompt for ONE failing example.
# Args: $1=example_name, $2=expected_output, $3=actual_output,
#        $4=construct, $5=scope, $6=verify_cmd
# Writes to stdout.
build_surgical_prompt() {
  local example="$1" expected="$2" actual="$3" construct="$4" scope="$5" verify_cmd="$6"
  cat <<EOF
TASK: Fix gate failure in example: $example
CONSTRUCT: ${construct:-unknown}
SCOPE: $scope
VERIFY: $verify_cmd

EXPECTED (first 20 lines):
$(echo "$expected" | head -20)

ACTUAL (first 20 lines):
$(echo "$actual" | head -20)

DIFF (first 40 lines):
$(diff <(echo "$expected" | head -50) <(echo "$actual" | head -50) 2>/dev/null | head -40 || echo "(diff unavailable)")

Fix the code in SCOPE so the output matches EXPECTED.
Keep changes minimal — fix ONE construct at a time.
If a SHARED-CORE change is required, APPEND a core-request and exit 0.
EOF
}

# ── log_decision ─────────────────────────────────────────────────────
# Append a row to the TSV decision log.
# Args: $1=worker, $2=example, $3=action, $4=construct, $5=reason
log_decision() {
  local worker="$1" example="$2" action="$3" construct="$4" reason="$5"
  [ -f "$DECISIONS_TSV" ] || printf 'timestamp\tworker\texample\taction\tconstruct\treason\n' > "$DECISIONS_TSV"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date +%FT%T)" "$worker" "$example" "$action" "$construct" "$reason" >> "$DECISIONS_TSV"
}

# ── generate_decision_report ─────────────────────────────────────────
# Append a structured .md decision report for one example.
# Args: $1=report_file, $2=worker, $3=example, $4=decisions, $5=todos, $6=sh2_stays
generate_decision_report() {
  local report_file="$1" worker="$2" example="$3"
  local decisions="${4:-none}" todos="${5:-none}" sh2_stays="${6:-none}"
  cat >> "$report_file" <<EOF
# $example — $worker Decision Report
## Decisions Made
$decisions
## TODOs
$todos
## Why sh2 Usage Stays
$sh2_stays

---
EOF
}

# ── Context budget guard ─────────────────────────────────────────────
# Estimate token count (rough: 1 token ≈ 4 chars) and warn/truncate if
# close to the model's window. Args: $1=prompt_file, $2=log_file, $3=max_tokens
check_context_budget() {
  local prompt_file="$1" log_file="$2" max_tokens="${3:-200000}"
  local chars tokens
  chars=$(wc -c < "$prompt_file")
  tokens=$((chars / 4))
  if [ $tokens -gt $max_tokens ]; then
    echo "[$(date +%FT%T)] WARNING: prompt ~${tokens} tokens exceeds budget ${max_tokens} — truncating" >> "$log_file"
    local keep_chars=$((max_tokens * 4 * 80 / 100))
    local tail_chars=$((max_tokens * 4 * 20 / 100))
    {
      head -c "$keep_chars" "$prompt_file"
      echo -e "\n\n... [TRUNCATED — context budget exceeded] ...\n\n"
      tail -c "$tail_chars" "$prompt_file"
    } > "${prompt_file}.trunc"
    mv "${prompt_file}.trunc" "$prompt_file"
    return 1
  fi
  return 0
}
