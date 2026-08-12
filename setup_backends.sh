#!/usr/bin/env bash
# setup_backends.sh — one git worktree per target backend, on branch
# backend/<lang>, all sharing the sh2perl submodule's core (ShIR + parser
# + node model). The lowering phase keeps the CORE single-owner; backend
# work (renderer, runtime, gate, metric) lives per-worktree.
#
#   setup_backends.sh [langs...]          create/verify worktrees (default:
#                                         perl js c python zig go rust sh java)
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

DEFAULT_BACKEND_LANGS="perl js c python zig go rust sh java"
DEFAULT_FRONTEND_LANGS="py-sh-go go-sh posix-sh-go perl-sh-go fish-sh-go zsh-sh-go c-sh-go cpp-sh-go rust-frontend zig-sh-go powershell-sh-go"

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
# min_free (MB, default 2048). Swap is a SECONDARY signal, not an
# independent blocker: if MemAvailable is plentiful (>= min_free*2), high
# swap is ignored (swapped-out pages are stale; the system has room to
# pull them back). If MemAvailable is moderately low (min_free..min_free*2)
# AND swap is high (swap_frac > max_swap_frac, default 0.5), that is real
# pressure and we wait. Poll every poll_secs. Fail-open (return 1 on
# timeout) — same as wait_for_load.
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
    if (( avail_mb < min_free )); then
      tight=1  # low RAM = OOM risk, regardless of swap
    elif (( avail_mb < min_free * 2 )); then
      # moderate RAM: high swap is the secondary pressure signal
      if (( swap_tot_kb > 0 )); then
        if awk -v u="$swap_used_kb" -v t="$swap_tot_kb" -v m="$max_swap_frac" 'BEGIN{exit !(u/t > m)}'; then tight=1; fi
      fi
      # else (plenty of RAM) high swap is ignored
    fi
    if (( tight == 0 )); then return 0; fi
    echo "    memAvail=${avail_mb}MB < ${min_free}MB (or moderate + swap ${swap_used_kb}/${swap_tot_kb} > ${max_swap_frac}); waiting ${poll_secs}s (waited ${waited}s)..." >&2
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
    backend:c|backend:python|backend:rust|backend:zig|backend:sh|backend:java)
                                    echo "cargo build --manifest-path $SUB/Cargo.toml" ;;
    backend:go)                     echo "true" ;;  # no Go renderer yet; build = noop
    frontend:py-sh)                 echo "python3 -c 'import ast; ast.parse(open(\"$FT/py-sh/pysh.py\").read())'" ;;
    frontend:go-sh)                 echo "go build -o /tmp/go-sh-build $FT/go-sh/" ;;
    frontend:cpp-sh-go)             echo "make -C $FT/cpp-sh-go build" ;;
    frontend:zig-sh-go)             echo "make -C $FT/zig-sh-go build" ;;
    frontend:powershell-sh-go)      echo "make -C $FT/powershell-sh-go build" ;;
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
  # WORK-STEALING: a leased slot is run by a desktop — yield until released
  if [ -f "$WORKSPACE/.leases/$lang" ]; then
    echo "[\$(date +%FT%T)] frontend $lang: leased to \$(cut -d' ' -f1 "\$WORKSPACE/.leases/$lang") — yielding" >> "\$LOG"
    sleep 300; continue
  fi
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
    backends)  langs=(perl js c python zig go rust sh java) ;;
    frontends) langs=(py-sh-go go-sh c-sh-go cpp-sh-go) ;;
    all|*)     langs=(perl js c python zig go rust sh java py-sh go-sh c-sh-go cpp-sh-go) ;;
  esac
  echo "=== build: scope=$scope langs=${langs[*]} ==="
  # parallel: run each build in background, wait for all. Bound the
  # parallelism at nproc (each cargo/go build is CPU-heavy).
  local -a pids=()
  local par; par=$(nproc 2>/dev/null || echo 2)
  for lang in "${langs[@]}"; do
    # decide kind
    local kind="backend"
    case "$lang" in py-sh|go-sh|posix-sh|busybox-ash|fish|zsh|perl-sh|cpp-sh|rust-sh|c-sh-go|cpp-sh-go|rust-frontend) kind="frontend" ;; esac
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
  for lang in $DEFAULT_BACKEND_LANGS; do
    local dir="$BT/$lang"
    [ -d "$dir" ] || { echo "  [$lang] no worktree — skip (run setup first)"; continue; }
    if [ -f "$dir/loop-backend-$lang.pid" ] && kill -0 "$(cat "$dir/loop-backend-$lang.pid")" 2>/dev/null; then
      echo "  [$lang] worker already running (pid $(cat "$dir/loop-backend-$lang.pid"))"
      continue
    fi
    # fleet niceness: heavy (19) — the estree worker (nice 5) owns the
    # shared CPU; the backend/frontend workers yield to it
    nice -n 19 nohup bash -c "
      set -euo pipefail
      # supervisor: restart the worker up to 5 times when it dies
      attempts=0
      while [ \$attempts -lt 5 ]; do
        attempts=\$((attempts+1))
        echo \"[\$(date +%FT%T)] $lang: worker attempt \$attempts\" >> '$WORKSPACE/loop-backend-$lang.log'
        bash '$WORKSPACE/setup_backends.sh' --run-backend-worker '$lang'
        echo \"[\$(date +%FT%T)] $lang: worker exited (attempt \$attempts) — restarting in 5s\" >> '$WORKSPACE/loop-backend-$lang.log'
        sleep 5
      done
      echo \"[\$(date +%FT%T)] $lang: gave up after 5 attempts — re-run --start-workers\" >> '$WORKSPACE/loop-backend-$lang.log'
    

    " >/dev/null 2>&1 &
    echo $! > "$dir/loop-backend-$lang.pid"
    echo "  [$lang] worker started (pid $(cat "$dir/loop-backend-$lang.pid")) — log: $WORKSPACE/loop-backend-$lang.log"
  done
  for lang in $DEFAULT_FRONTEND_LANGS; do
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
    nice -n 19 nohup bash -c "
      # frontend supervisor: restart the worker up to 5 times when it dies
      attempts=0
      while [ \$attempts -lt 5 ]; do
        attempts=\$((attempts+1))
        echo \"[\$(date +%FT%T)] frontend $lang: worker attempt \$attempts\" >> '$WORKSPACE/loop-frontend-$lang.log'
        bash '$dir/run_frontend_worker.sh'
        echo \"[\$(date +%FT%T)] frontend $lang: worker exited (attempt \$attempts) — restarting in 5s\" >> '$WORKSPACE/loop-frontend-$lang.log'
        sleep 5
      done
      echo \"[\$(date +%FT%T)] frontend $lang: gave up after 5 attempts\" >> '$WORKSPACE/loop-frontend-$lang.log'
    " >/dev/null 2>&1 &
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
  --start-triage-worker) # the cross-product triage worker (frontend corpus ×
                  # backend). Rotates frontends, sweeps each through ALL
                  # backends, escalates NEW failures by class (frontend →
                  # --pi-fix-frontend; backend → a core-request), and
                  # regenerates triage/report.json for external consumers.
                  # Verdicts: triage/verdicts.tsv (see harness/triage.sh).
                  nohup nice -n 19 bash "$ROOT/run_triage_worker.sh" \
                    >> "$WORKSPACE/loop-triage-worker.log" 2>&1 &
                  echo "triage worker started (pid $!) — log: $WORKSPACE/loop-triage-worker.log"
                  exit 0 ;;
  --run-backend-worker) # internal: run ONE backend worker loop until it
                  # dies (the start-workers supervisor relaunches it up to
                  # 5 times). Usage: setup_backends.sh --run-backend-worker <lang>
                  shift; rw_lang="$1"; rw_dir="$BT/$rw_lang"
                  export WORKSPACE LOG
                  LOG="$WORKSPACE/loop-backend-$rw_lang.log"
                  cd "$rw_dir" || exit 1
                  fail_count=0
                  while true; do
                    # WORK-STEALING: a leased slot is run by a desktop.
                    # HEARTBEAT + RECLAIM: a stale lease (the desktop
                    # vanished — no heartbeat for 10 min) is reaped; and
                    # when the SERVER has spare compute (load < 0.6*nproc)
                    # the work comes back even from a live desktop.
                    load1=$(awk '{print $1}' /proc/loadavg)
                    nproc=$(nproc)
                    if [ -f "$WORKSPACE/.leases/$rw_lang" ]; then
                      lts=$(cut -d' ' -f2 "$WORKSPACE/.leases/$rw_lang")
                      lage=$(( $(date +%s) - lts ))
                      if [ "$lage" -gt 600 ]; then
                        rm -f "$WORKSPACE/.leases/$rw_lang"
                        echo "[$(date +%FT%T)] $rw_lang: reaped stale lease (${lage}s old) — resuming" >> "$LOG"
                      elif awk -v l="$load1" -v n="$nproc" 'BEGIN { exit !(l < 0.6 * n) }'; then
                        rm -f "$WORKSPACE/.leases/$rw_lang"
                        echo "[$(date +%FT%T)] $rw_lang: server has spare compute (load $load1) — reclaimed" >> "$LOG"
                      else
                        echo "[$(date +%FT%T)] $rw_lang: leased to $(cut -d' ' -f1 "$WORKSPACE/.leases/$rw_lang") — yielding" >> "$LOG"
                        sleep 300; continue
                      fi
                    fi
                    # CPU+RAM gate before the heavy phase (parity with the
                    # frontend workers' per-iteration --wait): load <=
                    # 1.5×nproc AND >= 2048MB RAM free before building. A
                    # cold start still races (all workers pass an idle gate)
                    # but the steady-state iterations serialize on load.
                    bash "$WORKSPACE/setup_backends.sh" --wait >> "$LOG" 2>&1 || true
                    # HARD-SERIALIZE the build+test phase across ALL backend
                    # workers: one cargo build at a time (a cold start races
                    # the --wait gate — every worker passes an idle load —
                    # and N concurrent builds thrash a small box; the flock
                    # makes the heavy phase one-at-a-time regardless).
                    (
                      flock 9
                      bash "$WORKSPACE/setup_backends.sh" --backend-gate "$rw_lang" >> "$LOG" 2>&1
                    ) 9>"$WORKSPACE/.gate.lock"
                    gate_rc=$?
                    if [ $gate_rc -eq 0 ]; then
                      fail_count=0
                      changes=$(git -C "$WORKSPACE" status --porcelain 2>/dev/null \
                                | awk '/^.. /{print $2}' \
                                | awk -v d="$rw_dir" '$0 ~ "^"d || $0 ~ /^harness\//' || true)
                      if [ -n "$changes" ]; then
                        if grep -lE '^(<<<<<<<|=======|>>>>>>>)' $changes 2>/dev/null | grep -q .; then
                          echo "[$(date +%FT%T)] $rw_lang: conflict markers in staged files — NOT committing" >> "$LOG"
                        elif echo "$changes" | grep -q '^harness/'; then
                          if (cd "$WORKSPACE" && perl fail-estree --gate >/dev/null 2>&1); then
                            git -C "$WORKSPACE" add $changes 2>/dev/null || true
                            git -C "$WORKSPACE" commit -m "backend $rw_lang: gate pass" 2>/dev/null || true
                          else
                            echo "[$(date +%FT%T)] $rw_lang: harness edits regress the core corpus — NOT committing" >> "$LOG"
                          fi
                        else
                          git -C "$WORKSPACE" add $changes 2>/dev/null || true
                          git -C "$WORKSPACE" commit -m "backend $rw_lang: gate pass" 2>/dev/null || true
                        fi
                      fi
                      echo "[$(date +%FT%T)] $rw_lang: gate GREEN" >> "$LOG"
                    else
                      fail_count=$((fail_count+1))
                      echo "[$(date +%FT%T)] $rw_lang: gate FAILED ($fail_count/3) — invoking pi (deepseek-v4-flash, scoped)" >> "$LOG"
                      bash "$WORKSPACE/setup_backends.sh" --pi-fix-backend "$rw_lang" 2>> "$LOG" || true
                      if [ "$fail_count" -ge 3 ]; then
                        echo "[$(date +%FT%T)] $rw_lang: TRAPPED — escalating and backing off 30 min" >> "$LOG"
                        bash "$WORKSPACE/setup_backends.sh" --worker-trapped "$rw_lang" backend >> "$LOG" 2>&1 || true
                        git -C "$rw_dir" stash -q 2>/dev/null || true
                        fail_count=0
                        for ((_i = 1; _i <= 30; _i++)); do
                          [ -f "$WORKSPACE/.leases/$rw_lang" ] && { echo "[$(date +%FT%T)] $rw_lang: leased during backoff — yielding" >> "$LOG"; sleep 300; continue 2; }
                          sleep 60
                        done
                      fi
                    fi
                    sleep 300
                  done
                  ;;
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
                    printf 'The backend gate needs a RENDERER ENTRY in the worktree: wire a --shir-in-%s flag into the worktree''s cli/src/lib.rs argument dispatch (mirroring the --shir-in-perl/--shir-in-estree branches; takes shIR JSON on stdin via `-`) or add a %s_backend bin taking the .sh file (the c backend''s pattern). The gate probes the flag before the corpus loop — no flag, no bin = the gate stays red.\n' "$fix_lang" "$fix_lang"
                    printf 'STUB GATE: the gate FAILS any file whose output contains sh2.* stub calls (sh2_exec()/sh2GetVar()/...) or TODO(unsupported) markers. Replace them with NATIVE lowering — the stub/TODO count is the progress metric and must drop toward zero.\n'
                    printf '\nCONCRETE RECIPE (the C backend''s PROVEN pattern — mirror it, do not reinvent):\n'
                    printf '  1. RENDERER: a library fn `shir_to_%s(&IrProgram) -> String` walking the ShIR nodes —\n' "$fix_lang"
                    printf '     read the reference: `git -C backends/c show backend/c:src/c_backend.rs` — the C\n'
                    printf '     renderer consumes the IR in-process, uses the A2 var_types verdicts (Int ->\n'
                    printf '     the target''s int type, Str -> its string, missing -> the runtime store), and\n'
                    printf '     emits a compile-able sh2.* stub or a /* TODO */ marker for anything outside\n'
                    printf '     the lowable subset — the output ALWAYS compiles.\n'
                    printf '  2. ENTRY: wire --shir-in-%s in the worktree''s cli/src/lib.rs — mirror the\n' "$fix_lang"
                    printf '     --shir-in-perl arm (~line 661): read the file (or stdin via `-`) ->\n'
                    printf '     shir_json_in::shir_json_to_ir -> shir_to_%s -> print.\n' "$fix_lang"
                    printf '  3. BOOTSTRAP ORDER: get the gate GREEN on the MINIMAL subset FIRST (Output +\n'
                    printf '     Assign only — the corpus loop starts tiny), then grow (If/While/arith/test).\n'
                    printf '     Never aim for the whole corpus in one shot — land the first green, commit,\n'
                    printf '     then extend.\n'
                    printf '  4. RUNTIME: the per-language sh2.* port comes AFTER the renderer is green\n'
                    printf '     (backends/c/docs/backend-c-core-needs.md section 7 table). Stubs are fine\n'
                    printf '     for the first green.\n'
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
                    if [ "$fix_name" = "cpp-sh-go" ]; then
                      printf 'C++-surface only: you may edit THIS dir. c-sh-go-owned code (frontends/c-sh-go/*) is single-owner — if a fix needs a SHARED-LOWERING change there, APPEND a structured request to c-requests/%s-<timestamp>.md per c-requests/README.md (NEED / WHY / MINIMAL-C-CHANGE / FAILING-CASE / VALIDATION) and exit 0. Do NOT touch c-sh-go-owned files — the c-sh-go worker implements c-requests.\n' "$fix_name"
                    elif [ "$fix_name" = "c-sh-go" ]; then
                      printf 'You are the OWNER of the shared C lowering and the c-requests implementer. If c-requests/*.md (not in done/) exist, implement them FIRST; acceptance = make test AND the request VALIDATION target both green; then move them to c-requests/done/.\n'
                    fi
                    printf 'If a SHARED-CORE change is required (shIR node, deserializer, contract field, parser fix) to fix this, APPEND a structured request to core-requests/%s-<timestamp>.md per core-requests/README.md (NEED / WHY / MINIMAL-CORE-CHANGE / FAILING-CASE) and exit 0. Do NOT touch the core — the estree worker implements core requests.\n' "$fix_name"
                  } > /tmp/pi-fix-prompt-$$
                  # RAM gate (fail-open, up to 10 min): don't start pi while RAM is tight
                  wait_for_ram 2048 0.5 30 600 || true
                  pi --mode json --provider opencode-go --model deepseek-v4-flash \
                     --thinking xhigh < /tmp/pi-fix-prompt-$$ >> "$fix_log" 2>&1 || true
                  rm -f /tmp/pi-fix-prompt-$$
                  exit 0 ;;
  --pi-coverage-example) # internal: invoked by a frontend worker after a
                  # GREEN gate when its parser node coverage is incomplete
                  # (worker-coverage-step.sh). pi creates ONE testdata
                  # example exercising the uncovered node, scoped to
                  # frontends/<name>/testdata/. The worker's gate validates
                  # and commits (or discards) it.
                  # Usage: setup_backends.sh --pi-coverage-example <name> <gap>
                  shift; cov_name="$1"; cov_gap="$2"
                  cov_dir="$FT/$cov_name"; cov_log="$WORKSPACE/loop-frontend-$cov_name.log"
                  {
                    cat <<EOF
Your frontend's gate is GREEN, but its testdata examples do not yet cover every parser node.
Uncovered parser construct: $cov_gap

This may be an external-grammar rule (grammars-v4 / the POSIX subset /
PPI) that no testdata example exercises — a real language construct, not
an A1-emission node. Judge expressibility against the frontend subset
(FRONTEND.md): if the frontend refuses it by design, do NOT create the
example (exit 0); if the frontend can express it, create the example.

Create ONE new testdata example in $cov_dir/testdata/ that exercises this construct.

Constraints:
  - check the existing testdata/ files first — the construct must NOT already be covered
  - the example must be a minimal, valid $cov_name program the frontend EXPRESSES (it must EMIT, not refuse)
  - it must pass the gate: make test in $cov_dir (refusals + ingress acceptance + executed-stdout oracle)
  - name it t<NN>_<description>.<ext> following the existing testdata numbering
  - if the frontend REFUSES this construct by design (check FRONTEND.md / the parser source), do NOT create the example; exit 0

Edit surface: frontends/$cov_name/testdata/ only (harness/* only if the oracle needs it).
Shared core (DO NOT TOUCH): sh2perl/src/shir.rs, sh2perl/src/ir.rs, sh2perl/src/estree.rs, sh2perl/src/parser/
EOF
                  } > /tmp/pi-coverage-prompt-$$
                  wait_for_ram 2048 0.5 30 600 || true
                  pi --mode json --provider opencode-go --model deepseek-v4-flash \
                     --thinking xhigh < /tmp/pi-coverage-prompt-$$ >> "$cov_log" 2>&1 || true
                  rm -f /tmp/pi-coverage-prompt-$$
                  exit 0 ;;
  --pi-fix-c-requests) # internal: the c-sh-go worker implements pending
                  # c-requests/ (cpp-sh-go -> c-sh-go shared-lowering
                  # requests, CPP_PLAN §4). Builds a prompt from the pending
                  # request files and runs pi scoped to frontends/c-sh-go/.
                  # The worker's own gate (make test) validates; on green it
                  # moves the requests to c-requests/done/.
                  c_reqdir="$WORKSPACE/c-requests"
                  c_pending=$(ls "$c_reqdir"/*.md 2>/dev/null | grep -v '/done/' || true)
                  if [ -z "$c_pending" ]; then
                    exit 0
                  fi
                  c_log="$WORKSPACE/loop-frontend-c-sh-go.log"
                  {
                    printf 'Implement the pending c-requests (cpp-sh-go -> the shared C lowering).\n\n'
                    for r in $c_pending; do
                      printf '===== %s =====\n' "$r"
                      cat "$r"
                      printf '\n'
                    done
                    printf 'You are the OWNER of frontends/c-sh-go/ (the shared C lowering) and the c-requests implementer.\n'
                    printf 'Acceptance = make test (the C corpus stays green) AND each request VALIDATION target (proves the feature works) — then the worker moves the requests to c-requests/done/.\n'
                    printf 'Shared core (DO NOT TOUCH): sh2perl/src/shir.rs, sh2perl/src/ir.rs, sh2perl/src/estree.rs, sh2perl/src/parser/\n'
                    printf 'If a SHARED-CORE change is required to satisfy a request, APPEND a structured request to core-requests/c-sh-go-<timestamp>.md per core-requests/README.md and exit 0.\n'
                  } > /tmp/pi-fix-c-requests-$$
                  wait_for_ram 2048 0.5 30 600 || true
                  pi --mode json --provider opencode-go --model deepseek-v4-flash \
                     --thinking xhigh < /tmp/pi-fix-c-requests-$$ >> "$c_log" 2>&1 || true
                  rm -f /tmp/pi-fix-c-requests-$$
                  exit 0 ;;
  --backend-gate) # internal: the backend worker's progress signal. Render the
                  # shared corpus (sh2perl/examples/*.sh + frontend testdata)
                  # through THIS backend and report PASS/FAIL.
                  #   js, perl -> the WORKTREE renderers (--shir-in-js /
                  #          --shir-in-perl). perl renders perl text: the
                  #          stub gate + executed equivalence apply. js
                  #          renders the ESTree JSON contract (delegates to
                  #          the core's shir_to_estree_json) and is executed
                  #          through the harness's estree→js implementation
                  #          (estree-runner.mjs + the real sh2.* runtime).
                  #   scaffolds (c go python rust zig sh java) -> the WORKTREE must
                  #          have a renderer: a --shir-in-<lang> flag wired
                  #          into its debashc (cli/src/lib.rs dispatch), or a
                  #          <lang>_backend bin (c's pattern). Neither -> FAIL:
                  #          the old `*) ok=1` was vacuous (never failed, so
                  #          the scaffold workers idled at the shared commit).
                  # Usage: setup_backends.sh --backend-gate <lang>
                  shift; g_lang="$1"
                  g_wt="$BT/$g_lang"
                  g_bin="$SUB/target/debug/debashc"; g_flag=""; g_binmode=0; g_stubgate=0; g_eq=0
                  case "$g_lang" in
                    js|perl)
                      # production backends: consume the SHARED core binary
                      # (estree.rs / ir_to_perl live in the core) — the
                      # shared target is fine (only js/perl/main build it)
                      if ! cargo build --manifest-path "$SUB/Cargo.toml" >> "$WORKSPACE/loop-backend-$g_lang.log" 2>&1; then
                        echo "  [$g_lang] backend gate: core build FAILED"; exit 1
                      fi
                      # js's + perl's renderers live in the WORKTREES
                      # (--shir-in-js / --shir-in-perl, worktree-local —
                      # mirrors the c_backend pattern): the old empty-flag
                      # arm hit the cli's shell-command fallback (never read
                      # stdin), which SIGPIPE-races the corpus pipe under
                      # load (rc=141 false fails). Probe them like the
                      # scaffolds. (perl's worktree renderer — src/
                      # perl_backend.rs, shir_to_perl — renders the full ShIR
                      # vocabulary without panicking, unlike the shared
                      # core's legacy ir_to_perl which still has
                      # ESTree-path-only unreachable! arms; see
                      # core-requests/perl-*.md.)
                      if [ "$g_lang" = "js" ] || [ "$g_lang" = "perl" ]; then
                        if ! (export CARGO_TARGET_DIR="$g_wt/target"; cargo build --manifest-path "$g_wt/Cargo.toml") >> "$WORKSPACE/loop-backend-$g_lang.log" 2>&1; then
                          echo "  [$g_lang] backend gate: worktree build FAILED"; exit 1
                        fi
                        g_bin="$g_wt/target/debug/debashc"
                        # probe: feed an invalid shIR JSON — the deserializer's
                        # "ShIR JSON ingress" marker proves --shir-in-js is wired.
                        # The probe is EXPECTED to exit 1 (ingress error), so it
                        # must stay inside an `if` condition — set -e (and the
                        # scaffolds' probes, which return 0 only via the
                        # shell-command fallback) would otherwise kill the gate.
                        if printf '%s' '{"contract_version":1,"imports":[],"requires":[],"stmts":[],"subs":[],"var_types":[],"stmt_lines":[]}' \
                          | "$g_bin" "--shir-in-$g_lang" - >/dev/null 2>/tmp/gate_probe_$$; then
                          g_flag="--shir-in-$g_lang"
                        elif grep -q "ShIR JSON ingress" /tmp/gate_probe_$$; then
                          g_flag="--shir-in-$g_lang"
                        elif [ -x "$g_wt/target/debug/${g_lang}_backend" ]; then
                          g_binmode=1
                        else
                          rm -f /tmp/gate_probe_$$
                          echo "  [$g_lang] backend gate: NO RENDERER — wire --shir-in-$g_lang into the worktree's cli/src/lib.rs dispatch (mirroring --shir-in-perl) or add a ${g_lang}_backend bin (c's pattern). The gate lands with the renderer."
                          exit 1
                        fi
                        rm -f /tmp/gate_probe_$$
                      fi
                      # perl: same gate as the scaffolds — the sh2.*/TODO
                      # stub check AND executed equivalence (its render is
                      # perl text; sh2.*/TODO markers are unfinished
                      # lowering).
                      # js: the renderer emits the ESTree JSON contract —
                      # sh2.* in the JSON are the REAL runtime namespace,
                      # not stubs, so the stub gate is OFF; equivalence
                      # runs the JSON through estree-runner.mjs (the
                      # harness's estree→js printer + sh2.* node runtime).
                      if [ "$g_lang" = "js" ]; then
                        g_stubgate=0; g_eq=1
                      else
                        g_stubgate=1; g_eq=1
                      fi
                      ;;
                    *)
                      # scaffolds (c go python rust zig sh java): PER-WORKTREE target
                      # dirs — each compiles its OWN copy of the core
                      # ($g_wt/target-core) and its worktree renderer
                      # ($g_wt/target), so the five scaffold gates stop
                      # serializing on the SHARED cargo build lock (the
                      # "Blocking waiting for file lock" contention). The
                      # two manifests (main core vs the branch core) are the
                      # same package — keep them in SEPARATE target dirs.
                      if ! (export CARGO_TARGET_DIR="$g_wt/target-core";                             cargo build --manifest-path "$SUB/Cargo.toml") >> "$WORKSPACE/loop-backend-$g_lang.log" 2>&1; then
                        echo "  [$g_lang] backend gate: core build FAILED"; exit 1
                      fi
                      # build the worktree (the branch's core + its renderer)
                      if ! (export CARGO_TARGET_DIR="$g_wt/target";                             cargo build --manifest-path "$g_wt/Cargo.toml") >> "$WORKSPACE/loop-backend-$g_lang.log" 2>&1; then
                        echo "  [$g_lang] backend gate: worktree build FAILED"; exit 1
                      fi
                      g_bin="$g_wt/target/debug/debashc"
                      # probe: feed an invalid shIR JSON — the deserializer's
                      # "ShIR JSON ingress" marker proves --shir-in-<lang> is
                      # wired into the worktree's CLI. The probe exits 1 by
                      # design (ingress error), so it MUST stay inside an `if`
                      # condition — set -e + pipefail would otherwise kill the
                      # whole gate before the corpus runs.
                      if printf '%s' '{"contract_version":1,"imports":[],"requires":[],"stmts":[],"subs":[],"var_types":[],"stmt_lines":[]}' \
                        | "$g_bin" "--shir-in-$g_lang" - >/dev/null 2>/tmp/gate_probe_$$; then
                        : # probe rc=0 — fall through to the marker check
                      fi
                      if grep -q "ShIR JSON ingress" /tmp/gate_probe_$$; then
                        g_flag="--shir-in-$g_lang"
                      elif [ -x "$g_wt/target/debug/${g_lang}_backend" ]; then
                        g_binmode=1
                      else
                        rm -f /tmp/gate_probe_$$
                        echo "  [$g_lang] backend gate: NO RENDERER — wire --shir-in-$g_lang into the worktree's cli/src/lib.rs dispatch (mirroring --shir-in-perl) or add a ${g_lang}_backend bin (c's pattern). The gate lands with the renderer."
                        exit 1
                      fi
                      # the sh2.*/TODO stub gate applies to every backend
                      # except js (its render is the ESTree JSON contract —
                      # see the js|perl arm)
                      g_stubgate=1
                      g_eq=1
                      rm -f /tmp/gate_probe_$$;;
                  esac
                  corpus=$(ls "$SUB"/examples/*.sh "$WORKSPACE"/frontends/*/testdata/*.sh 2>/dev/null)
                  # ── EQUIVALENCE gate (every backend with a toolchain) ──────
                  # A render-clean file (exit 0; no stubs where the stub gate
                  # applies) must ALSO match bash's stdout when compiled+run
                  # — wrong-but-compiling code no longer passes. perl runs
                  # its render under perl; js runs the emitted ESTree JSON
                  # through estree-runner.mjs (the harness's estree→js + the
                  # real sh2.* runtime); the scaffolds compile+run natively.
                  # STDERR IS IGNORED ON BOTH SIDES: the reference runs
                  # `bash file 2>/dev/null` and the translation runs with its
                  # stderr discarded too — only stdout is ever compared, so a
                  # translation is never forced to reproduce (or suppress)
                  # tool diagnostics, command-not-found messages, or
                  # `echo >&2` behavior. (This was previously asymmetric —
                  # the translation side used `2>&1`, merging its stderr into
                  # the diff, which forced renderers to inject a global
                  # stderr-silencer to pass.)
                  # MULTITASKING: SERIAL by design. The gate is a correctness
                  # signal, not a benchmark — 7 scaffold workers × parallel
                  # gcc/go/rustc compiles would spike the shared 8-core box
                  # (already load 20+). The worker's --wait load gate throttles
                  # the gate as a whole; per-file runs are one-at-a-time. Set
                  # EQUIV_PARALLEL=N to enable xargs -P N if gate time ever
                  # becomes the bottleneck.
                  eq_tool=""; eq_ext=""
                  case "$g_lang" in
                    c)      eq_tool="cc";        eq_ext="c";;
                    go)     eq_tool="/snap/go/current/bin/go"; eq_ext="go";;
                    python) eq_tool="python3";    eq_ext="py";;
                    rust)   eq_tool="rustc";      eq_ext="rs";;
                    zig)    eq_tool="zig";        eq_ext="zig";;
                    sh)     eq_tool="sh";         eq_ext="sh";;
                    java)   eq_tool="javac";      eq_ext="java";;
                    perl)   eq_tool="perl";       eq_ext="pl";;
                    js)     eq_tool="node";       eq_ext="json";;
                  esac
                  eq_gate=0; eq_pass=0; eq_fail=0
                  if [ "$g_eq" = 1 ] && [ -n "$eq_tool" ] && command -v "$eq_tool" >/dev/null 2>&1; then
                    eq_gate=1
                  fi
                  pass=0; skip=0; fail=0; fails=""; stub_total=0; stub_files=0
                  for f in $corpus; do
                    # shIR emit from the CORE (the A1 contract source of truth):
                    # if the core emits nothing (rc!=0 or empty JSON — the 4
                    # parse-error examples), SKIP (not a backend gap).
                    shir=$("$SUB/target/debug/debashc" --shir "$f" --raw 2>/dev/null)
                    if [ -z "$shir" ]; then
                      skip=$((skip+1)); continue
                    fi
                    g_out=""
                    if [ "$g_binmode" = 1 ]; then
                      if g_out=$("$g_wt/target/debug/${g_lang}_backend" "$f" 2>/dev/null); then ok=1; else ok=0; g_out=""; fi
                    else
                      if g_out=$(printf '%s' "$shir" | "$g_bin" "$g_flag" - 2>/dev/null); then ok=1; else ok=0; g_out=""; fi
                    fi
                    # STUB GATE: an emitted sh2.* stub call
                    # (sh2_exec()/sh2GetVar()/...) or TODO(unsupported) marker
                    # is UNFINISHED lowering — the file FAILS until the stubs
                    # are replaced with native code, so the failure-driven
                    # worker grinds them to zero instead of sleeping on a
                    # green-but-stubby renderer. Off for js: its output is
                    # the ESTree JSON contract, where sh2.* is the real
                    # runtime namespace (enforced by the estree gate's
                    # whitelist, not by this grep).
                    if [ "$g_stubgate" = 1 ]; then
                      s=$(printf '%s' "$g_out" | grep -cE "TODO\(unsupported\)|sh2[A-Za-z_]" || true)
                    else
                      s=0
                    fi
                    stub_total=$((stub_total + s))
                    if [ "$ok" = 1 ] && [ "$s" -eq 0 ]; then
                      if [ "$eq_gate" = 1 ]; then
                        # EQUIVALENCE: compile+run the render, diff its stdout
                        # against `bash "$f"`. A mismatch = wrong lowering the
                        # worker must fix (the gate's new correctness oracle).
                        # java: javac requires the public class in a file named
                        # Sh2Program.java — write there (serial gate, no clash).
                        if [ "$g_lang" = java ]; then
                          printf '%s' "$g_out" > /tmp/Sh2Program.java
                        else
                          printf '%s' "$g_out" > /tmp/eq_$$.$eq_ext
                        fi
                        eq_exit=1
                        case "$g_lang" in
                          c)    cc /tmp/eq_$$.c -o /tmp/eq_$$_bin 2>/dev/null && timeout 15 /tmp/eq_$$_bin > /tmp/eq_$$_out 2>/dev/null && eq_exit=0;;
                          go)   timeout 30 "$eq_tool" run /tmp/eq_$$.go > /tmp/eq_$$_out 2>/dev/null && eq_exit=0;;
                          python) timeout 15 python3 /tmp/eq_$$.py > /tmp/eq_$$_out 2>/dev/null && eq_exit=0;;
                          rust) rustc /tmp/eq_$$.rs -o /tmp/eq_$$_bin 2>/dev/null && timeout 15 /tmp/eq_$$_bin > /tmp/eq_$$_out 2>/dev/null && eq_exit=0;;
                          zig)  timeout 30 "$eq_tool" run /tmp/eq_$$.zig > /tmp/eq_$$_out 2>/dev/null && eq_exit=0;;
                          sh)   timeout 15 sh -c '. /dev/fd/3' "$f" 3< /tmp/eq_$$.sh > /tmp/eq_$$_out 2>/dev/null && eq_exit=0;;
                          java) javac -d /tmp /tmp/Sh2Program.java 2>/dev/null && timeout 15 java -cp /tmp Sh2Program > /tmp/eq_$$_out 2>/dev/null && eq_exit=0;;
                          perl) timeout 15 perl /tmp/eq_$$.pl > /tmp/eq_$$_out 2>/dev/null && eq_exit=0;;
                          js)   timeout 20 node "$WORKSPACE/harness/estree-runner.mjs" /tmp/eq_$$.json --source "$f" > /tmp/eq_$$_out 2>/dev/null && eq_exit=0;;
                        esac
                        if [ "$eq_exit" = 0 ] \
                           && timeout 15 bash "$f" > /tmp/eq_$$_ref 2>/dev/null \
                           && diff -q /tmp/eq_$$_out /tmp/eq_$$_ref >/dev/null 2>&1; then
                          pass=$((pass+1)); eq_pass=$((eq_pass+1))
                        else
                          fail=$((fail+1)); eq_fail=$((eq_fail+1)); fails="$f $fails"
                        fi
                        rm -f /tmp/eq_$$_bin /tmp/eq_$$_out /tmp/eq_$$_ref /tmp/eq_$$.$eq_ext /tmp/Sh2Program.class /tmp/Sh2Program.java
                      else
                        pass=$((pass+1))
                      fi
                    else
                      fail=$((fail+1))
                      [ "$s" -gt 0 ] && stub_files=$((stub_files+1))
                      fails="$f $fails"
                    fi
                  done
                  echo "  [$g_lang] backend gate: $pass/$((pass+skip+fail)) corpus render OK, $fail fail ($stub_files stubs, $eq_fail equiv), $skip skip — $stub_total stubs emitted${eq_gate:+; equiv: $eq_pass pass vs bash}"
                  # CHIMERA gate (sh only): the bash-free WSL sandbox (BSD
                  # shell + busybox toolchain, no bash/perl/GNU coreutils). A
                  # test PASSES only if it passes under BOTH Ubuntu (dash,
                  # above) AND Chimera — so chimera failures union into the
                  # worker's work list. Skipped gracefully where the sh-gate
                  # deployment (the sudo rule + harness script) is absent.
                  if [ "$g_lang" = "sh" ] && command -v sh-gate >/dev/null 2>&1 && [ -x "$WORKSPACE/harness/chimera-gate.sh" ]; then
                    if bash "$WORKSPACE/harness/chimera-gate.sh" "$g_wt/target/debug/debashc" "$WORKSPACE"; then
                      echo "  [sh] backend gate: chimera green (passes under Ubuntu AND Chimera)"
                    else
                      fail=$((fail+1))
                      echo "  [sh] backend gate: CHIMERA RED — a test fails if it fails under Ubuntu OR Chimera (lists above)"
                    fi
                  fi
                  if [ "$fail" -gt 0 ]; then echo "  fails: $fails" | head -c 200; echo; exit 1; fi
                  # valgrind memory gate (the C worker): the generated C
                  # must run without memory errors — a bounded sample (the
                  # full 531 under valgrind is too slow for the gate loop)
                  if [ "$g_lang" = "c" ] && command -v valgrind >/dev/null 2>&1; then
                    sample=$(ls "$SUB"/examples/*.sh 2>/dev/null | head -25)
                    if bash "$WORKSPACE/harness/c_valgrind.sh" $sample >> "$WORKSPACE/loop-backend-$g_lang.log" 2>&1; then
                      echo "  [$g_lang] backend gate: valgrind clean (25-sample)"
                    else
                      echo "  [$g_lang] backend gate: VALGRIND FAILURES — the renderer emits memory errors"; exit 1
                    fi
                  fi
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
