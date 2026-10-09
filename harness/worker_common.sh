#!/usr/bin/env bash
# harness/worker_common.sh — shared functions for all workers.
#
# Source this file at the top of each worker script:
#   source "$WORKSPACE/harness/worker_common.sh"
#
# Provides:
#   - Configurable CLI (pi / pir / cmd / opencode) with model + effort
#   - invoke_ai_with_backoff() — exponential retry wrapper
#   - log_decision() — append to TSV decision log
#   - generate_decision_report() — append .md decision report
#   - build_surgical_prompt() — concise per-task context template
#   - check_context_budget() — warn/truncate if prompt is too large

# ── CLI configuration ────────────────────────────────────────────────
# Which AI CLI to invoke: pi, pir, cmd, or opencode.
#   pi       — opencode-go provider (legacy, limited model catalog)
#   pir      — featherweight pi-compatible agent (OpenRouter, auto-retry, budget)
#   cmd      — Command Code headless (full CC catalog, heavier)
#   opencode — the OpenCode client (opencode.ai). THE ONLY CLIENT THAT CAN
#              REACH THE opencode-go FREE TIER; see the block below.
#
# DEFAULT IS NOW `cmd` (operator, 2026-10-09). The fleet was switched to
# Glyph Cluster, and Glyph Cluster is a cmd-catalog model: `pir` has no
# glyph-cluster entry at all and answers every call with
#   "pir: no model matches 'commandcode/stealth/glyph-cluster:free'".
# So on this default the non-rotating workers (perl, and any future one)
# would gate fine and then fail EVERY AI call. Verified against both
# catalogs, not assumed: `cmd --list-models` lists
# `stealth/glyph-cluster:free`; `pir` offers no glyph match.
WORKER_CLI="${WORKER_CLI:-cmd}"

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
# GLYPH CLUSTER (operator, 2026-10-09). Replaces space-bunny-alpha as the
# default for this LEGACY path too. Id verified against `cmd --list-models`
# (1.79.1): `stealth/glyph-cluster:free`. The colon form is the one cmd's
# catalog prints and is what it accepts; the hyphen form is rejected as an
# unknown model. Kept commandcode/-qualified to match ai_invoke.py so the
# fleet records ONE model string.
WORKER_MODEL="${WORKER_MODEL:-commandcode/stealth/glyph-cluster:free}"

# ── opencode CLI configuration (added 2026-10-09) ─────────────────────
# The opencode client is the ONLY one that can call opencode-go's FREE tier.
# Measured, not assumed:
#
#   $ cmd -m longcat-2.5-preview-free   -> Error: unknown model
#   $ pir -m opencode/longcat-2.5-preview-free
#         -> HTTP 403: OpenCode's free tier can only be used from within OpenCode
#   $ curl https://opencode.ai/zen/v1/chat/completions  (no client)
#         -> {"type":"FreeTierError","message":"OpenCode's free tier can only
#             be used from within OpenCode"}
#   $ opencode run -m opencode/longcat-2.5-preview-free  -> OK
#
# So the free tier is gated on CLIENT IDENTITY, server-side. cmd reaches
# opencode-go's PAID models (longcat-2.0, kimi-k3, grok-4.7) but not its free
# ones; pir is outside the gate entirely.
#
# MODEL IDS ARE provider-qualified `provider/model` (note the `opencode/`
# prefix and NO `:free` suffix — the store's id already ends in -free):
#   opencode/longcat-2.5-preview-free   free, 1M ctx  (LIMITED TIME promo)
#   opencode/step-5-preview-free        free, 1M ctx  (LIMITED TIME promo)
#   opencode/space-bunny-free           free
#   opencode/ling-3.1-flash-free        free
# Listing them: `opencode models` (11 ids — NOT `cmd --list-models`, which is
# Command Code's catalog and does not contain the free tier at all).
#
# WARNING: both *_preview_free models are launch promotions ("Limited Time").
# Treat them as one link in the fallback chain, not a hard fleet pin, and
# keep WORKER_FALLBACK_MODEL set — the next disruption is a WITHDRAWAL, not a
# quota reset.
WORKER_OPENCODE_MODEL="${WORKER_OPENCODE_MODEL:-opencode/longcat-2.5-preview-free}"

# The opencode binary. NOT on the systemd PATH (/usr/bin/opencode and
# /usr/local/bin/opencode do not exist; only /root/.opencode/bin/opencode
# does), so a worker launched with a minimal PATH would silently fail every
# call. Resolve an absolute path with a fallback chain, and let the operator
# override.
WORKER_OPENCODE_BIN="${WORKER_OPENCODE_BIN:-}"
if [ -z "$WORKER_OPENCODE_BIN" ]; then
  for _oc in /root/.opencode/bin/opencode \
             "${HOME:-/root}/.opencode/bin/opencode" \
             /mnt/wsl/projects/home/.opencode/bin/opencode; do
    [ -x "$_oc" ] && { WORKER_OPENCODE_BIN="$_oc"; break; }
  done
  unset _oc
fi
WORKER_OPENCODE_BIN="${WORKER_OPENCODE_BIN:-opencode}"
export WORKER_OPENCODE_BIN

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
    opencode)
      # `opencode run` is the headless analogue of `cmd -p`. NOT argv-compatible
      # with cmd: there is no --no-session / --yolo / --tools-all, and the model
      # is provider-qualified. Measured flags that DO exist (2026-10-09,
      # `opencode run --help`):
      #   --format json  NDJSON event stream (step_start/text/tool_use/step_finish)
      #   -m, --model    provider/model
      #   --variant      provider-specific reasoning effort (cmd's --effort)
      #   --dir          directory to run in
      # --auto is NOT required: verified that write AND bash tools run without
      # it in `opencode run` (non-interactive) mode. Left off deliberately —
      # it only governs permissions "not explicitly denied", and the workers
      # already rely on the fleet's own confinement.
      local args=(run --format json -m "${WORKER_OPENCODE_MODEL:-$WORKER_MODEL}")
      [ -n "$WORKER_EFFORT" ] && args+=(--variant "$WORKER_EFFORT")
      local query
      query=$(< "$prompt_file")
      # The prompt is POSITIONAL (like pir, not stdin). MAX_ARG_STRLEN still
      # applies, so for a large prompt hand over a short instruction to read
      # the file itself — the same shape the pir branch uses, and for the same
      # reason (no truncation, but the agent still has a real prompt).
      if [ ${#query} -gt 100000 ]; then
        "$WORKER_OPENCODE_BIN" "${args[@]}" \
          "Read the full task instructions from $prompt_file and carry them out." \
          >> "$log_file" 2>&1
      else
        "$WORKER_OPENCODE_BIN" "${args[@]}" "$query" >> "$log_file" 2>&1
      fi
      ;;
    *)
      echo "[$(date +%FT%T)] ERROR: Unknown WORKER_CLI=$WORKER_CLI (expected pi|pir|cmd|opencode)" >> "$log_file"
      return 1
      ;;
  esac
}

# ── daily-quota fallback (legacy WORKER_CLI path) ─────────────────────
#
# WHY (2026-10-09). The rotating workers get this from harness/ai_invoke.py;
# this path had NONE. So a worker not on rotation — perl, and any future one —
# that hit a provider's daily wall re-issued the same exhausted request
# forever at the backoff maximum. That is not a retry, it is a stall that
# looks like work. Observed live: Glyph Cluster returning
#   "Error: You've reached today's limit on Glyph Cluster. Resets in 7h 10m"
# with cmd exiting rc=5, while the worker logged `cmd failed (rc=5, attempt N)`
# every 300s indefinitely.
#
# One-way and at most once per process, matching the rotating path: no
# oscillation, no loop, and the primary is re-probed by the next worker
# restart once its quota resets.
#
# Detection is on the MESSAGE, not the exit code: rc=5 also covers unrelated
# errors, and the text is the only reliable discriminator. Only a quota
# signal switches, so a genuine build or model error still retries and still
# surfaces — this must never mask a real failure.
_quota_wall_in_log() {
  tail -c 4000 "$1" 2>/dev/null | command grep -qaE \
    'reached today.s limit|free-models-per-day|currently at capacity|GoUsageLimitError|quota.?exhausted|FreeTierError|is unavailable for free|free tier can only be used'
}

# ── opencode hard-failure detection ──────────────────────────────────
# `opencode run` can FAIL and still exit 0. Measured (2026-10-09):
#
#   $ opencode run -m opencode/nonexistent-model 'hi'          -> rc=1
#   $ opencode run -m opencode/ling-3.0-flash-fin-free 'hi'    -> rc=1
#       "Error: Upstream request failed: Model is unavailable."
#       + "Error: {"name":"UnknownError", ...}" on stderr
#   $ opencode run -m opencode/longcat-2.5-preview-free 'hi'  -> rc=0
#
# (The earlier rc=0 reading was a pipeline artifact: `... | tail` reports
# tail's status, not opencode's. Measured without a pipe, opencode exits
# NON-ZERO on a failed turn — so unlike cmd's glyph wall, rc IS a usable
# signal here. This helper is the belt-and-braces check for the case where a
# failure prints but the exit status is masked by a wrapper.)
#
# The distinction that matters: a genuine model/upstream error must RETRY
# (or fall back), never be silently accepted as a successful turn.
_opencode_failed_in_log() {
  tail -c 4000 "$1" 2>/dev/null | command grep -qaE \
    '^Error: |"name":"UnknownError"|Model is unavailable|Upstream request failed'
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
    # The status MUST be captured by the SAME command that ran the AI, in an
    # else branch. `local rc=$?` placed AFTER a finished `if` reads the status
    # of the *compound statement*, not of invoke_ai: in bash, `if cmd; then
    # …; fi` with a false condition and no `else` yields 0. That made every
    # hard failure log as `rc=0` — a success-class retry — which is how a
    # deterministic, never-going-to-succeed failure ran 92 times over 20h
    # (2026-10-01: the perl worker, `pir: no model matches` on every attempt
    # because its PATH resolved /usr/bin/pir 0.1.1 instead of the current
    # /root/bin/pir 0.1.6; pir's real exit code here is 1).
    local rc=0
    if invoke_ai "$prompt_file" "$log_file"; then
      # `opencode` can print a hard error and still exit 0 through a pipeline
      # (measured — see _opencode_failed_in_log). Treat that as a failure so it
      # retries instead of being banked as a successful turn.
      if [ "$WORKER_CLI" = "opencode" ] && _opencode_failed_in_log "$log_file"; then
        rc=1
      else
        return 0
      fi
    else
      rc=$?
    fi
    attempt=$((attempt + 1))

    # Daily-quota wall: switch the model ONCE rather than retrying a request
    # that cannot succeed until the window resets. Checked before the generic
    # retry so the switch is immediate, not after a 300s backoff.
    #
    # The fallback target must be reachable BY THE SAME CLIENT. For opencode,
    # WORKER_FALLBACK_MODEL (ollama-cloud/…) is NOT in the opencode catalog, so
    # switching to it would trade a quota wall for an unknown-model error on
    # every subsequent call. Fall back WITHIN the opencode free tier instead.
    if [ "${_fallback_used:-0}" = "0" ] && _quota_wall_in_log "$log_file"; then
      if [ "$WORKER_CLI" = "opencode" ]; then
        # A second free opencode-go model, not the cross-provider fallback.
        local oc_fb="${WORKER_OPENCODE_FALLBACK_MODEL:-opencode/step-5-preview-free}"
        if [ "$oc_fb" != "${WORKER_OPENCODE_MODEL:-$WORKER_MODEL}" ]; then
          echo "[$(date +%FT%T)] fallback: ${WORKER_OPENCODE_MODEL:-$WORKER_MODEL} hit a quota wall (rc=$rc) — switching this worker to $oc_fb" >> "$log_file"
          WORKER_OPENCODE_MODEL="$oc_fb"
          export WORKER_OPENCODE_MODEL
          _fallback_used=1
          delay=$BACKOFF_BASE
          continue
        fi
      elif [ -n "${WORKER_FALLBACK_MODEL:-}" ] && [ "$WORKER_FALLBACK_MODEL" != "$WORKER_MODEL" ]; then
        echo "[$(date +%FT%T)] fallback: $WORKER_MODEL hit a daily quota wall (rc=$rc) — switching this worker to $WORKER_FALLBACK_MODEL" >> "$log_file"
        WORKER_MODEL="$WORKER_FALLBACK_MODEL"
        export WORKER_MODEL
        _fallback_used=1
        delay=$BACKOFF_BASE
        continue
      fi
    fi

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
