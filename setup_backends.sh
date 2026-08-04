#!/usr/bin/env bash
# setup_backends.sh — one git worktree per target backend, on branch
# backend/<lang>, all sharing the sh2perl submodule's core (ShIR + parser
# + node model). The lowering phase keeps the CORE single-owner; backend
# work (renderer, runtime, gate, metric) lives per-worktree.
#
#   setup_backends.sh [langs...]          create/verify worktrees (default:
#                                         perl js c python zig go rust)
#   setup_backends.sh --sync [langs]      merge main into each worktree branch
#   setup_backends.sh --remove [langs]    remove the worktrees (keeps branches)
#   setup_backends.sh --frontends [langs] scaffold frontends/<lang>/ dirs
#                                         (workspace-side; no worktree — the
#                                         "scope" is the dir itself)
#   setup_backends.sh --build [scope]     build backends and/or frontends in
#                                         parallel; load-gated for heavy ops
#                                         (threshold = 1.5 × nproc, poll 60s)
#   setup_backends.sh --wait              wait for load to drop below threshold
#                                         (1.5×nproc), then exit 0. Workers
#                                         call this before each heavy op.
#   setup_backends.sh --start-workers     start one worker per backend worktree
#                                         and per frontend dir, each scoped to
#                                         its own part of the code; load-gated
#
# Merge discipline (see PLAN.md): workers commit on backend/<lang>, merge
# main in BEFORE each verification run, and push to main only when the
# commit does not touch the shared core (src/shir.rs, src/ir.rs,
# src/estree.rs, src/parser/). Core changes stay single-owner.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SUB="$ROOT/sh2perl"
BT="$SUB/backends"   # worktrees live INSIDE the sh2perl submodule
                     # (they share the submodule's core); $ROOT/backends
                     # was a path inconsistency — the worktrees are here.
FT="$ROOT/frontends"
WORKSPACE="$ROOT"

DEFAULT_BACKEND_LANGS="perl js c python zig go rust"
DEFAULT_FRONTEND_LANGS="py-sh-go go-sh posix-sh-go perl-sh-go"

# Active backends whose workers already run from the main checkout
# (main_loop_rust.pl / main_loop_estree.pl); the per-worktree worker
# started by --start-workers is a *scoped complement* (it touches only
# its worktree's subdir + harness/*, not the shared core).
declare -A WORKER=( [perl]=main_loop_rust.pl [js]=main_loop_estree.pl )

# Load-gate: poll the 5-min load average and wait until it drops below
# (nproc * threshold). Used before every heavy op (build/test/corpus).
# Args: [threshold=1.5] [poll_secs=60] [max_wait_secs=1800]
wait_for_load() {
  local threshold="${1:-1.5}"
  local poll_secs="${2:-60}"
  local max_wait="${3:-1800}"
  local nproc_val; nproc_val=$(nproc 2>/dev/null || echo 1)
  local max_load; max_load=$(awk -v n="$nproc_val" -v t="$threshold" 'BEGIN{printf "%d", n*t}')
  local waited=0
  while (( waited < max_wait )); do
    local load5; load5=$(awk '{print $2}' /proc/loadavg)
    local over; over=$(awk -v l="$load5" -v m="$max_load" 'BEGIN{print (l+0>m+0)?1:0}')
    if (( over == 0 )); then return 0; fi
    echo "    load5=${load5} > ${max_load} (${nproc_val}*${threshold}); waiting ${poll_secs}s (waited ${waited}s)..." >&2
    sleep "$poll_secs"
    waited=$((waited + poll_secs))
  done
  echo "    load still > ${max_load} after ${waited}s; proceeding" >&2
  return 1
}

# RAM gate: wait until MemAvailable (from /proc/meminfo) is above
# min_free (MB, default 2048) AND swap usage is below max_swap_frac
# (default 0.5), polling every poll_secs. Fail-open (return 1 on
# timeout, caller proceeds with a warning) — same as wait_for_load.
# RAM is the binding constraint for the pi agents (xhigh thinking loads
# ~200-700MB each) and for cargo/go builds; the CPU gate alone does not
# protect against OOM.
wait_for_ram() {
  local min_free="${1:-2048}"
  local max_swap_frac="${2:-0.5}"
  local poll_secs="${3:-30}"
  local max_wait="${4:-1800}"
  local waited=0
  while (( waited < max_wait )); do
    local avail_kb swap_tot_kb swap_used_kb
    avail_kb=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    swap_tot_kb=$(awk '/^SwapTotal:/{print $2}' /proc/meminfo)
    swap_used_kb=$(awk -v t="$swap_tot_kb" -v f="$(awk '/^SwapFree:/{print $2}' /proc/meminfo)" 'BEGIN{print t-f}')
    local avail_mb=$(( avail_kb / 1024 ))
    local tight=0
    if (( avail_mb < min_free )); then tight=1; fi
    if (( swap_tot_kb > 0 )); then
      if awk -v u="$swap_used_kb" -v t="$swap_tot_kb" -v m="$max_swap_frac" 'BEGIN{exit !(u/t > m)}'; then tight=1; fi
    fi
    if (( tight == 0 )); then return 0; fi
    echo "    memAvail=${avail_mb}MB < ${min_free}MB or swap ${swap_used_kb}/${swap_tot_kb} > ${max_swap_frac}; waiting ${poll_secs}s (waited ${waited}s)..." >&2
    sleep "$poll_secs"
    waited=$((waited + poll_secs))
  done
  echo "    RAM still tight after ${waited}s; proceeding (fail-open)" >&2
  return 1
}

# Run a command under the load gate. If --light, skip the gate.
# Returns the command's exit status.
gated() {
  local light=0
  [[ "${1:-}" == "--light" ]] && { light=1; shift; }
  if (( light )); then
    "$@"
  else
    if wait_for_load; then echo "    ok (load ok)"; else echo "    ok (load warn)"; fi
    "$@"
  fi
}

# Invoke `pi` for a scoped fix (opencode-go + deepseek-v4-flash, with
# automatic API-key rotation handled by the opencode-go provider — same
# invocation the main_loop_estree.pl / main_loop_rust.pl workers use).
# Args: $1=log_file, $2=scope_label (shown in the prompt), $3=scope_dir,
# $4=prompt_body. The prompt is written to a temp file (avoids quoting
# nightmares with multi-line bodies) and piped to `pi` on stdin.
pi_fix() {
  local log="$1" scope_label="$2" scope_dir="$3" body="$4"
  local prompt_file; prompt_file=$(mktemp --suffix=.pi-prompt)
  {
    printf '%s\n' "$body"
    printf '\n--- SCOPE ---\n'
    printf 'Work only inside: %s\n' "$scope_dir"
    printf 'Also allowed (shared test infra): %s/harness/\n' "$WORKSPACE"
    printf 'NEVER touch: %s/sh2perl/src/shir.rs, %s/sh2perl/src/ir.rs, %s/sh2perl/src/estree.rs, %s/sh2perl/src/parser/ (single-owner core)\n' \
      "$WORKSPACE" "$WORKSPACE" "$WORKSPACE" "$WORKSPACE"
  } > "$prompt_file"
  echo "    [$scope_label] invoking pi (opencode-go + deepseek-v4-flash, key rotation automatic)..." >> "$log"
  # RAM gate (fail-open, up to 10 min): don't start pi while RAM is tight
  wait_for_ram 2048 0.5 30 600 || true
  if pi --mode json --provider opencode-go --model deepseek-v4-flash \
        --thinking xhigh < "$prompt_file" >> "$log" 2>&1; then
    echo "    [$scope_label] pi fix complete" >> "$log"
  else
    echo "    [$scope_label] pi fix FAILED (rc=$?)" >> "$log"
  fi
  rm -f "$prompt_file"
}

# Per-language build command. Returns the command (echo) — call gated()
# to run it. light=1 for syntax/parse checks; 0 for full build + corpus.
build_cmd() {
  local kind="$1" lang="$2"
  case "$kind:$lang" in
    backend:perl|backend:js)         echo "cargo build --manifest-path $SUB/Cargo.toml" ;;
    backend:c|backend:python|backend:rust|backend:zig)
                                    echo "cargo build --manifest-path $SUB/Cargo.toml" ;;
    backend:go)                     echo "true" ;;  # no Go renderer yet; build = noop
    frontend:py-sh)                 echo "python3 -c 'import ast; ast.parse(open(\"$FT/py-sh/pysh.py\").read())'" ;;
    frontend:go-sh)                 echo "go build -o /tmp/go-sh-build $FT/go-sh/" ;;
    *) echo "echo 'no build for $kind:$lang' && true" ;;
  esac
}

ensure_worktree () {
  local lang="$1"
  local dir="$BT/$lang" branch="backend/$lang"
  mkdir -p "$BT"
  if git -C "$SUB" worktree list --porcelain | grep -q "^worktree $dir$"; then
    echo "  [$lang] worktree exists: $dir ($(git -C "$dir" rev-parse --abbrev-ref HEAD))"
  else
    if git -C "$SUB" show-ref --verify --quiet "refs/heads/$branch"; then
      git -C "$SUB" worktree add "$dir" "$branch" >/dev/null
    else
      git -C "$SUB" worktree add -b "$branch" "$dir" >/dev/null
    fi
    echo "  [$lang] created worktree $dir on $branch"
  fi
}

sync_worktree () {
  local lang="$1"
  local dir="$BT/$lang" branch="backend/$lang"
  [ -e "$dir/.git" ] || { echo "  [$lang] no worktree — run setup first"; return; }
  echo "  [$lang] merging main into $branch"
  git -C "$dir" fetch origin main 2>/dev/null || git -C "$SUB" fetch origin main 2>/dev/null || true
  git -C "$dir" merge main -m "merge main into $branch" --no-edit >/dev/null 2>&1 \
    && echo "  [$lang] merged cleanly" \
    || echo "  [$lang] MERGE CONFLICT — resolve in $dir by hand, then re-run"
}

remove_worktree () {
  local lang="$1"
  local dir="$BT/$lang"
  git -C "$SUB" worktree remove --force "$dir" 2>/dev/null \
    && echo "  [$lang] removed worktree" || echo "  [$lang] no worktree"
}

scaffold () {
  local lang="$1"
  local dir="$BT/$lang" worker="${WORKER[$lang]:-}"
  # per-worktree worker entry
  cat > "$dir/run_worker.sh" <<EOF
#!/usr/bin/env bash
# Run the $lang backend worker from THIS worktree.
cd "\$(dirname "\$0")"
EOF
  if [ -n "$worker" ]; then
    cat >> "$dir/run_worker.sh" <<EOF
nohup perl "$ROOT/$worker" >> "$ROOT/loop-$lang.log" 2>&1 &
echo "$lang worker started (PID \$!) — log: $ROOT/loop-$lang.log"
EOF
  else
    cat >> "$dir/run_worker.sh" <<EOF
echo "[$lang] backend not implemented yet — scaffold: renderer + runtime + gate + metric in this worktree"
EOF
  fi
  chmod +x "$dir/run_worker.sh"
  # per-worktree contract
  cat > "$dir/BACKEND.md" <<EOF
# $lang backend (worktree: $dir, branch: backend/$lang)

Shared core (do NOT fork): src/shir.rs (ShIR + lowering), src/ir.rs,
src/estree.rs (node model), src/parser/. Consume the ShIR; render it in
your language's idioms.

Yours (in THIS worktree): the renderer, the runtime namespace, the corpus
gate, and the sh2.*-usage metric for $lang.

Merge discipline:
- commit on backend/$lang; merge main BEFORE each verification run
- push to main only when the commit does NOT touch the shared core
- core changes are single-owner (the estree worker during the lowering
  phase) — queue, don't fork

Verify: the corpus gate must stay 100% and the metric must only go down.
EOF
}

# Frontend scaffold: analogous to scaffold() but for frontends/<lang>/.
# Frontends are workspace-side dirs (no worktree — the "scope" is the
# dir itself). The run_frontend_worker.sh loops: build (gated) → if a
# gate script exists in the dir, run it (gated) → commit within scope
# → sleep. The fix-scope = frontends/<lang>/ + harness/* (shared test
# infra); does NOT touch the core.
scaffold_frontend () {
  local lang="$1"
  local dir="$FT/$lang"
  mkdir -p "$dir"
  cat > "$dir/run_frontend_worker.sh" <<EOF
#!/usr/bin/env bash
# $lang frontend worker — runs in THIS dir, scope = frontends/$lang/ +
# harness/* (shared test infra). Does NOT touch the core
# (src/shir.rs, src/ir.rs, src/estree.rs, src/parser/) — those are
# single-owner (the estree worker during the lowering phase).
set -euo pipefail
cd "\$(dirname "\$0")"
WORKSPACE="$WORKSPACE"
LOG="$WORKSPACE/loop-frontend-$lang.log"
echo "[\$(date +%FT%T)] frontend $lang worker started (pid=\$\$, scope=$dir)" >> "\$LOG"
while true; do
  # light ops (no load gate): git status, scope check
  changes=\$(git -C "\$WORKSPACE" status --porcelain 2>/dev/null \
            | awk '/^.. /{print \$2}' \
            | awk -v d="$dir" '\$0 ~ "^"d || \$0 ~ /^harness\//' \
            || true)
  if [ -n "\$changes" ]; then
    # heavy: wait for low load, then build (the --noop-gated prints
    # the build cmd for this scope; we then run it gated).
    bash "\$WORKSPACE/setup_backends.sh" --wait 2>>"\$LOG" || true
    bash "\$WORKSPACE/setup_backends.sh" --noop-gated build frontend $lang 2>>"\$LOG" >/dev/null \
      && eval "\$(bash "\$WORKSPACE/setup_backends.sh" --noop-gated build frontend $lang)" 2>>"\$LOG"
    git -C "\$WORKSPACE" add \$changes 2>>"\$LOG" || true
    git -C "\$WORKSPACE" commit -m "frontend $lang: build/fix" 2>>"\$LOG" || true
  fi
  sleep 300
done
EOF
  chmod +x "$dir/run_frontend_worker.sh"
  cat > "$dir/FRONTEND.md" <<EOF
# $lang frontend (dir: $dir)

Workspace-side dir; no git worktree. The "scope" is this dir +
harness/* (shared test infra).

Yours (in THIS dir): the lexer, parser, emitter, and any tests
specific to this frontend.

Shared (do NOT fork): frontends/shir-contract/, frontends/check_contract.py,
frontends/equiv.py, frontends/test_pipe.py, frontends/plan.md,
frontends/cxx-rust-adequacy.md — these are cross-frontend contracts
and tests, maintained centrally. Also: the core
(src/shir.rs, src/ir.rs, src/estree.rs, src/parser/) is single-owner
(the estree worker during the lowering phase).

Worker: $dir/run_frontend_worker.sh
EOF
}

# --build: parallel build of backends and/or frontends. Heavy ops are
# load-gated (wait_for_load). Scope = "backends" | "frontends" | "all".
do_build () {
  local scope="${1:-all}"
  # Load-gate the whole batch: wait for load < 1.5×nproc before
  # starting any builds. (Per-build gating would defeat parallelism.)
  wait_for_load || true
  local -a langs=()
  case "$scope" in
    backends)  langs=(perl js c python zig go rust) ;;
    frontends) langs=(py-sh go-sh) ;;
    all|*)     langs=(perl js c python zig go rust py-sh go-sh) ;;
  esac
  echo "=== build: scope=$scope langs=${langs[*]} ==="
  # parallel: run each build in background, wait for all. Bound the
  # parallelism at nproc (each cargo/go build is CPU-heavy).
  local -a pids=()
  local par; par=$(nproc 2>/dev/null || echo 2)
  for lang in "${langs[@]}"; do
    # decide kind
    local kind="backend"
    case "$lang" in py-sh|go-sh|posix-sh|busybox-ash|fish|zsh|perl-sh|cpp-sh|rust-sh) kind="frontend" ;; esac
    local cmd; cmd=$(build_cmd "$kind" "$lang")
    echo "  [$kind:$lang] build: $cmd"
    (
      out=$("$cmd" 2>&1) && echo "  [$kind:$lang] build OK" \
        || echo "  [$kind:$lang] build FAIL: $out"
    ) &
    pids+=($!)
    # bound parallelism
    if (( ${#pids[@]} >= par )); then
      wait "${pids[@]}" 2>/dev/null || true
      pids=()
    fi
  done
  wait "${pids[@]}" 2>/dev/null || true
}

# --start-workers: launch one scoped worker per backend worktree and
# per frontend dir. Each worker: build (gated) → optional gate (gated)
# → commit within scope → sleep. The fix-scope per worker is the
# worktree's language dir + harness/* (backends) or frontends/<lang>/
# + harness/* (frontends). Does NOT touch the shared core.
do_start_workers () {
  echo "=== start-workers (load-gated; threshold=1.5×nproc) ==="
  for lang in perl js c python zig go rust; do
    local dir="$BT/$lang"
    [ -d "$dir" ] || { echo "  [$lang] no worktree — skip (run setup first)"; continue; }
    if [ -f "$dir/loop-backend-$lang.pid" ] && kill -0 "$(cat "$dir/loop-backend-$lang.pid")" 2>/dev/null; then
      echo "  [$lang] worker already running (pid $(cat "$dir/loop-backend-$lang.pid"))"
      continue
    fi
    nohup bash -c "
      set -euo pipefail
      cd '$dir'
      fail_count=0
      while true; do
        # light: git status / scope check
        if git -C '$WORKSPACE' rev-parse --git-dir >/dev/null 2>&1; then
          changes=\$(git -C '$WORKSPACE' status --porcelain 2>/dev/null \
                    | awk '/^.. /{print \$2}' \
                    | awk -v d='$dir' '\$0 ~ \"^\"d || \$0 ~ /^harness\\//' || true)
          if [ -n \"\$changes\" ]; then
            # heavy: wait for low load, then build
            bash \"$WORKSPACE/setup_backends.sh\" --wait 2>>\"\$LOG\" || true
            echo \"[\$(date +%FT%T)] $lang: build start\" >> '$WORKSPACE/loop-backend-$lang.log'
            if cargo build --manifest-path '$SUB/Cargo.toml' >> '$WORKSPACE/loop-backend-$lang.log' 2>&1; then
              fail_count=0
              # build OK: commit within scope only (worktree dir + harness/*)
              git -C '$WORKSPACE' add \$changes 2>/dev/null || true
              git -C '$WORKSPACE' commit -m 'backend $lang: build/fix (auto)' 2>/dev/null || true
            else
              fail_count=\$((fail_count+1))
              # build FAIL: invoke pi (scoped) for a fix
              echo \"[\$(date +%FT%T)] $lang: build FAILED (\$fail_count/3) — invoking pi (deepseek-v4-flash, scoped)\" >> '$WORKSPACE/loop-backend-$lang.log'
              bash \"$WORKSPACE/setup_backends.sh\" --pi-fix-backend '$lang' 2>>\"\$LOG\" || true
              if [ \"\$fail_count\" -ge 3 ]; then
                echo \"[\$(date +%FT%T)] $lang: TRAPPED — escalating to core request and sleeping\" >> '$WORKSPACE/loop-backend-$lang.log'
                # blocks until the estree worker removes core-requests/sleeping-$lang
                bash \"$WORKSPACE/setup_backends.sh\" --worker-trapped '$lang' backend >> \"\$LOG\" 2>&1 || true
                fail_count=0
              fi
            fi
          fi
        fi
        sleep 300
      done
    " >/dev/null 2>&1 &
    echo $! > "$dir/loop-backend-$lang.pid"
    echo "  [$lang] worker started (pid $(cat "$dir/loop-backend-$lang.pid")) — log: $WORKSPACE/loop-backend-$lang.log"
  done
  for lang in py-sh-go go-sh posix-sh-go perl-sh-go; do
    local dir="$FT/$lang"
    [ -d "$dir" ] || { echo "  [$lang] no frontend dir — skip (run --frontends first)"; continue; }
    [ -f "$dir/run_frontend_worker.sh" ] || { echo "  [$lang] no run_frontend_worker.sh — skip (run --frontends first)"; continue; }
    if [ -f "$WORKSPACE/loop-frontend-$lang.pid" ] && kill -0 "$(cat "$WORKSPACE/loop-frontend-$lang.pid")" 2>/dev/null; then
      echo "  [$lang] worker already running (pid $(cat "$WORKSPACE/loop-frontend-$lang.pid"))"
      continue
    fi
    # startup is a fork — no load gate needed. The per-iteration --wait
    # inside the worker handles the real heavy ops (build/test).
    : # no-op
    nohup bash "$dir/run_frontend_worker.sh" >/dev/null 2>&1 &
    echo $! > "$WORKSPACE/loop-frontend-$lang.pid"
    echo "  [$lang] worker started (pid $(cat "$WORKSPACE/loop-frontend-$lang.pid")) — log: $WORKSPACE/loop-frontend-$lang.log"
  done
}

MODE=setup
SCOPE=all
case "${1:-}" in
  --sync)         MODE=sync; shift ;;
  --remove)       MODE=remove; shift ;;
  --frontends)    MODE=frontends; shift ;;
  --build)        MODE=build; shift; SCOPE="${1:-all}"; shift || true ;;
  --start-workers) MODE=start-workers; shift ;;
  --wait)          # public: wait for load + RAM, then exit 0. Workers use this
                  # before heavy ops. Args: [load_thr] [load_poll] [load_max]
                  # [ram_min_free] [ram_max_swap] [ram_poll] [ram_max]
                  shift
                  wait_for_load "${1:-1.5}" "${2:-60}" "${3:-1800}" || true
                  wait_for_ram "${4:-2048}" "${5:-0.5}" "${6:-30}" "${7:-1800}" || true
                  exit 0 ;;
  --pi-fix-backend) # internal: invoked by the per-worktree backend worker
                  # when its build FAILS. Calls pi (opencode-go +
                  # deepseek-v4-flash, automatic key rotation) with a
                  # prompt scoped to backends/<lang>/ + harness/*.
                  # Usage: setup_backends.sh --pi-fix-backend <lang>
                  shift; fix_lang="$1"
                  fix_dir="$BT/$fix_lang"; fix_log="$WORKSPACE/loop-backend-$fix_lang.log"
                  {
                    printf 'The %s backend in %s is failing to build.\n\n' "$fix_lang" "$fix_dir"
                    printf 'Tail of the build log (%s):\n' "$fix_log"
                    tail -50 "$fix_log" 2>/dev/null || true
                    printf '\nThe shIR (A1) contract is the source of truth. Render the %s backend in idiomatic %s.\n' "$fix_lang" "$fix_lang"
                    printf 'Shared core (DO NOT TOUCH): sh2perl/src/shir.rs, sh2perl/src/ir.rs, sh2perl/src/estree.rs, sh2perl/src/parser/\n'
                    printf 'You may create or edit files inside backends/%s/ and harness/.\n' "$fix_lang"
                    printf 'If a SHARED-CORE change is required (shIR node, deserializer, contract field, parser fix) to fix this, APPEND a structured request to core-requests/%s-<timestamp>.md per core-requests/README.md (NEED / WHY / MINIMAL-CORE-CHANGE / FAILING-CASE) and exit 0. Do NOT touch the core — the estree worker implements core requests.\n' "$fix_lang"
                  } > /tmp/pi-fix-prompt-$$
                  # RAM gate (fail-open, up to 10 min): don't start pi while RAM is tight
                  wait_for_ram 2048 0.5 30 600 || true
                  pi --mode json --provider opencode-go --model deepseek-v4-flash \
                     --thinking xhigh < /tmp/pi-fix-prompt-$$ >> "$fix_log" 2>&1 || true
                  rm -f /tmp/pi-fix-prompt-$$
                  exit 0 ;;
  --pi-fix-frontend) # internal: invoked by the per-frontend worker
                  # when its build FAILS. Calls pi (opencode-go +
                  # deepseek-v4-flash, automatic key rotation) with a
                  # prompt scoped to frontends/<name>/ + harness/*.
                  # Usage: setup_backends.sh --pi-fix-frontend <name>
                  shift; fix_name="$1"
                  fix_dir="$FT/$fix_name"; fix_log="$WORKSPACE/loop-frontend-$fix_name.log"
                  {
                    printf 'The %s frontend in %s is failing to build.\n\n' "$fix_name" "$fix_dir"
                    printf 'Tail of the build log (%s):\n' "$fix_log"
                    tail -50 "$fix_log" 2>/dev/null || true
                    printf '\nThe shIR (A1) contract is the source of truth (sh2perl/src/shir_json.rs). Parse the %s source language, emit the A1 shIR JSON byte-identical to the core frontend.\n' "$fix_name"
                    printf 'Shared core (DO NOT TOUCH): sh2perl/src/shir.rs, sh2perl/src/ir.rs, sh2perl/src/estree.rs, sh2perl/src/parser/\n'
                    printf 'You may create or edit files inside frontends/%s/ and harness/.\n' "$fix_name"
                    printf 'If a SHARED-CORE change is required (shIR node, deserializer, contract field, parser fix) to fix this, APPEND a structured request to core-requests/%s-<timestamp>.md per core-requests/README.md (NEED / WHY / MINIMAL-CORE-CHANGE / FAILING-CASE) and exit 0. Do NOT touch the core — the estree worker implements core requests.\n' "$fix_name"
                  } > /tmp/pi-fix-prompt-$$
                  # RAM gate (fail-open, up to 10 min): don't start pi while RAM is tight
                  wait_for_ram 2048 0.5 30 600 || true
                  pi --mode json --provider opencode-go --model deepseek-v4-flash \
                     --thinking xhigh < /tmp/pi-fix-prompt-$$ >> "$fix_log" 2>&1 || true
                  rm -f /tmp/pi-fix-prompt-$$
                  exit 0 ;;
  --worker-trapped) # internal: a worker is TRAPPED (repeated build
                  # failures, likely needing a core change it cannot make
                  # in-scope). Ensure a core request exists (fallback to a
                  # trapped marker request), create the sleeping marker
                  # core-requests/sleeping-<name>, and SLEEP until the
                  # estree worker removes the marker (the wake).
                  # Usage: setup_backends.sh --worker-trapped <name> <kind>
                  shift; t_name="$1"; t_kind="$2"
                  t_reqdir="$WORKSPACE/core-requests"
                  mkdir -p "$t_reqdir"
                  # ensure a request exists (fallback if pi didn't write one)
                  if ! ls "$t_reqdir/$t_name-"*.md >/dev/null 2>&1; then
                    req="$t_reqdir/$t_name-$(date +%Y%m%d-%H%M%S).md"
                    {
                      printf '# %s: TRAPPED (build fails repeatedly)\n\n' "$t_name"
                      printf '## NEED\n'
                      printf 'The %s worker cannot build; it likely needs a shared-core change (shIR node / deserializer / contract / parser) it cannot make in-scope. Inspect the worker log and the pi-fix attempts.\n' "$t_name"
                      printf '\n## WHY\n'
                      printf 'Repeated build failures; see frontends-or-backends/%s and harness/.\n' "$t_kind"
                      printf '\n## MINIMAL-CORE-CHANGE\n'
                      printf 'To be determined by the estree worker from the failing build.\n'
                      printf '\n## FAILING-CASE\n'
                      printf 'See the worker log: %s/loop-frontend-or-backend-%s.log.\n' "$WORKSPACE" "$t_name"
                    } > "$req"
                  fi
                  touch "$t_reqdir/sleeping-$t_name"
                  echo "[$(date +%FT%T)] $t_name TRAPPED — sleeping until estree wakes (marker core-requests/sleeping-$t_name)" >> "$WORKSPACE/loop-frontend-or-backend-$t_name.log" 2>/dev/null || true
                  while [ -f "$t_reqdir/sleeping-$t_name" ]; do
                    sleep 60
                  done
                  exit 0 ;;
  --noop-gated)   # internal: print the gated build cmd and exit (for the
                  # frontend worker's self-test). Usage: setup_backends.sh --noop-gated <kind> <lang>
                  # $1=--noop-gated, $2=<kind>, $3=<lang>
                  kind="$2"; lang="$3"
                  build_cmd "$kind" "$lang"
                  exit 0 ;;
esac

case "$MODE" in
  setup|frontends)
    if [ "$MODE" = setup ]; then
      LANGS="${*:-$DEFAULT_BACKEND_LANGS}"
      echo "=== setup: backends=$LANGS ==="
      for l in $LANGS; do ensure_worktree "$l"; scaffold "$l"; done
    else
      LANGS="${*:-$DEFAULT_FRONTEND_LANGS}"
      echo "=== setup: frontends=$LANGS ==="
      for l in $LANGS; do scaffold_frontend "$l"; done
    fi
    ;;
  sync)   LANGS="${*:-$DEFAULT_BACKEND_LANGS}"; for l in $LANGS; do sync_worktree "$l"; done ;;
  remove) LANGS="${*:-$DEFAULT_BACKEND_LANGS}"; for l in $LANGS; do remove_worktree "$l"; done ;;
  build)        do_build "$SCOPE" ;;
  start-workers) do_start_workers ;;
esac

case "$MODE" in
  setup|frontends)
    echo
    echo "Ready:"
    [ "$MODE" = setup ] && git -C "$SUB" worktree list
    echo
    echo "Build (parallel, load-gated):   $0 --build [backends|frontends|all]"
    echo "Start scoped workers:            $0 --start-workers"
    echo "Sync main in:                    $0 --sync"
    echo "Remove:                          $0 --remove"
    ;;
esac
