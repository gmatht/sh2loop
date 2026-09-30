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
#   pi   — opencode-go provider (legacy, limited model catalog)
#   pir  — featherweight pi-compatible agent (OpenRouter, auto-retry, budget)
#   cmd  — Command Code headless (full CC catalog, heavier)
WORKER_CLI="${WORKER_CLI:-pir}"

# Model. For pir: OpenRouter model id (poolside/laguna-s-2.1:free, etc.).
#   For pi: opencode-go model. For cmd: CC catalog id.
# TODO: escalate to DeepSeek for complex failures Laguna can't handle.
#
# EVERY WORKER ON SPACE BUNNY ALPHA (operator, 2026-09-30 21:0x). This was
# `poolside/laguna-s-2.1:free`, and Laguna then hit OpenRouter's exact
# `free-models-per-day` wall ("Add 10 credits to unlock 1000 free model
# requests per day") while the workers that ARE on rotation carried on
# running `stealth/space-bunny-alpha` without a single quota error. Alpha is
# healthy; Laguna's daily free tier is exhausted. Alpha is now the default
# for the direct WORKER_CLI path, so the workers NOT on rotation (perl,
# and any future one) stop inheriting an exhausted model.
#
# This is the LEGACY path only. The rotating workers (rust|c, per
# WORKER_ROTATE_WORKER in setup_backends.sh --run-backend-worker) do not
# read this: they go through harness/ai_invoke.py, which picks the model
# from the four-hour phase table in GROUPS. See ai_invoke.py for that one.
WORKER_MODEL="${WORKER_MODEL:-commandcode/stealth/space-bunny-alpha}"

# Reasoning effort. For pi: --thinking. For cmd: --effort. For pir: unused.
WORKER_EFFORT="${WORKER_EFFORT:-}"
WORKER_EFFORT="${WORKER_EFFORT:-${WORKER_THINKING:-}}"

# Token budget per invocation (pir only). Prevents runaway costs.
# 500K tokens ≈ $0 for Laguna free, enough for a focused fix.
WORKER_BUDGET="${WORKER_BUDGET:-500000}"

# ── Model rotation ───────────────────────────────────────────────────
# When WORKER_ROTATE_WORKER is set (rust|c|perl|estree), AI calls go through
# harness/ai_invoke.py, which picks the model from the four-hour rotation
# phase and records exact token usage. `cmd --model <id>` stays the actual
# selector; this only chooses WHICH id and accounts for it.
# Unset -> the direct WORKER_CLI invocation below (legacy behavior).
WORKER_ROTATE_WORKER="${WORKER_ROTATE_WORKER:-}"
AI_INVOKE="${AI_INVOKE:-${WORKSPACE:-.}/harness/ai_invoke.py}"

# Laguna daily-quota fallback. OpenRouter's exact daily-free error is
# `free-models-per-day`; when the active model is Laguna and that marker
# appears, the SAME prompt is retried on this model (one-way, once). Empty
# disables. Ollama Cloud may be metered — the one intentional cost.
WORKER_FALLBACK_MODEL="${WORKER_FALLBACK_MODEL:-ollama-cloud/deepseek-v4.1-flash}"
export WORKER_FALLBACK_MODEL

# ── Surgical task decomposition ──────────────────────────────────────
# When enabled, the harness decomposes gate failures into individual
# tasks and invokes the AI once per failure with focused context.
SURGICAL_MODE="${SURGICAL_MODE:-1}"  # 1=on by default, 0=off

# Max failures to process per iteration (prevents spending all day on fixes)
SURGICAL_MAX="${SURGICAL_MAX:-5}"

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

  # Rotating workers go through the shared wrapper: it picks the model for the
  # current four-hour phase, applies the Laguna quota fallback, and records
  # token usage. `cmd --model <id>` remains the actual selector.
  if [ -n "$WORKER_ROTATE_WORKER" ] && [ -x "$AI_INVOKE" -o -f "$AI_INVOKE" ]; then
    python3 "$AI_INVOKE" \
      --worker "$WORKER_ROTATE_WORKER" \
      --prompt-file "$prompt_file" \
      --log "$log_file"
    return $?
  fi

  case "$WORKER_CLI" in
    pi)
      local args=(--mode json --provider opencode-go --model "$WORKER_MODEL")
      [ -n "$WORKER_EFFORT" ] && args+=(--thinking "$WORKER_EFFORT")
      pi "${args[@]}" < "$prompt_file" >> "$log_file" 2>&1
      ;;
    pir)
      local args=(-y --no-color -m "$WORKER_MODEL")
      [ -n "$WORKER_BUDGET" ] && args+=(--budget "$WORKER_BUDGET")
      # `pir` takes its prompt as a POSITIONAL argument and IGNORES stdin, so
      # the >100KB stdin branch below could never have worked: it produced a
      # pir that started with no prompt, saw no terminal, and exited having
      # done nothing. Verified live on 2026-09-28 — a piped prompt returns no
      # reply, while a positional prompt does.
      #
      # argv cannot carry a large prompt (MAX_ARG_STRLEN; a 600KB prompt
      # fails with "Argument list too long"), so for a big one pass a SHORT
      # positional prompt that tells the agent to read the file itself. That
      # keeps the whole prompt in the file — no truncation — and still gives
      # pir something to act on.
      local size
      size=$(wc -c < "$prompt_file")
      if [ "$size" -gt 100000 ]; then
        pir "${args[@]}" \
          "Read the full task instructions from $prompt_file and carry them out." \
          >> "$log_file" 2>&1
      else
        pir "${args[@]}" "$(< "$prompt_file")" >> "$log_file" 2>&1
      fi
      ;;
    cmd)
      local args=(-p --no-session --yolo --model "$WORKER_MODEL" --output-format json --tools-all)
      [ -n "$WORKER_EFFORT" ] && args+=(--effort "$WORKER_EFFORT")
      local query
      query=$(< "$prompt_file")
      if [ ${#query} -gt 100000 ]; then
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
# Returns 0 on success. NEVER gives up — retries indefinitely at max delay.
# Checks context budget before invoking (truncates if too large).
invoke_ai_with_backoff() {
  local prompt_file="$1" log_file="$2"
  local attempt=0
  local delay=$BACKOFF_BASE

  # Context budget guard: truncate if prompt is too large for the model.
  # Laguna has 256K context; cap input at 200K tokens (~800KB).
  check_context_budget "$prompt_file" "$log_file" 200000 || true

  while true; do
    if invoke_ai "$prompt_file" "$log_file"; then
      return 0
    fi
    local rc=$?
    attempt=$((attempt + 1))
    echo "[$(date +%FT%T)] $WORKER_CLI failed (rc=$rc, attempt $attempt), retry in ${delay}s" >> "$log_file"
    sleep "$delay"
    delay=$((delay * BACKOFF_MULTIPLIER))
    [ $delay -gt $BACKOFF_MAX ] && delay=$BACKOFF_MAX
  done
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

# ── run_surgical_fix ─────────────────────────────────────────────────
# Decompose gate failures into individual tasks and fix each one.
# Args: $1=gate_output_file, $2=scope, $3=verify_cmd, $4=log_file, $5=worker_name
# Parses FAIL lines from gate output, builds focused prompts, invokes AI.
# Returns number of fixes attempted.
run_surgical_fix() {
  local gate_output="$1" scope="$2" verify_cmd="$3" log_file="$4"
  local worker_name="${5:-unknown}"
  local fixes=0

  # Parse FAIL lines: "  FAIL: example_name [backend] — reason"
  while IFS= read -r fail_line; do
    [ -z "$fail_line" ] && continue
    [ $fixes -ge $SURGICAL_MAX ] && break

    local example reason
    example=$(echo "$fail_line" | sed -n 's/.*FAIL: \([^ ]*\).*/\1/p')
    reason=$(echo "$fail_line" | sed -n 's/.*— \(.*\)/\1/p')
    [ -z "$example" ] && continue

    echo "[$(date +%FT%T)] surgical: fixing $example ($reason)" >> "$log_file"

    # Build focused prompt for THIS example only
    local prompt_file="/tmp/surgical_${example}_$$.txt"
    {
      printf 'TASK: Fix gate failure in example: %s\n' "$example"
      printf 'REASON: %s\n' "$reason"
      printf 'SCOPE: %s\n' "$scope"
      printf 'VERIFY: %s %s\n\n' "$verify_cmd" "$example"
      printf 'Run VERIFY to see the failure. Fix the code in SCOPE so it passes.\n'
      printf 'Keep changes minimal — fix ONE thing at a time.\n'
      printf 'If a SHARED-CORE change is required, APPEND a core-request and exit 0.\n'
    } > "$prompt_file"

    # Context budget check
    check_context_budget "$prompt_file" "$log_file" 50000 || true

    # Invoke AI with backoff
    invoke_ai_with_backoff "$prompt_file" "$log_file" || true
    rm -f "$prompt_file"

    fixes=$((fixes + 1))
    log_decision "$worker_name" "$example" "attempted" "unknown" "$reason"
  done < <(grep '  FAIL:' "$gate_output" | head -"$SURGICAL_MAX")

  echo "[$(date +%FT%T)] surgical: attempted $fixes fix(es)" >> "$log_file"
  return $fixes
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

# ── record_gate ──────────────────────────────────────────────────────
# Append a complete gate result for the model-rotation report.
# Args: $1=worker, $2=corpus, $3=pass, $4=fail, $5=skip, [extra k=v ...]
record_gate() {
  local worker="$1" corpus="$2" n_pass="$3" n_fail="$4" n_skip="${5:-0}"
  shift 5 2>/dev/null || shift $#
  local args=(record-gate --worker "$worker" --corpus "$corpus"
              --pass "$n_pass" --fail "$n_fail" --skip "$n_skip")
  local kv k v
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    args+=("--$k" "$v")
  done
  python3 "${WORKSPACE:-.}/harness/model_report.py" "${args[@]}" || true
}
