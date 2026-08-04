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
BT="$ROOT/backends"
FT="$ROOT/frontends"
WORKSPACE="$ROOT"

DEFAULT_BACKEND_LANGS="perl js c python zig go rust"
DEFAULT_FRONTEND_LANGS="py-sh go-sh"

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
  [ -d "$dir/.git" ] || { echo "  [$lang] no worktree — run setup first"; return; }
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
    # heavy: load-gated. The per-worktree worker is a background loop.
    wait_for_load || true
    nohup bash -c "
      set -euo pipefail
      cd '$dir'
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
            cargo build --manifest-path '$SUB/Cargo.toml' >> '$WORKSPACE/loop-backend-$lang.log' 2>&1 || true
            # commit within scope only (worktree dir + harness/*)
            git -C '$WORKSPACE' add \$changes 2>/dev/null || true
            git -C '$WORKSPACE' commit -m 'backend $lang: build/fix (auto)' 2>/dev/null || true
          fi
        fi
        sleep 300
      done
    " >/dev/null 2>&1 &
    echo $! > "$dir/loop-backend-$lang.pid"
    echo "  [$lang] worker started (pid $(cat "$dir/loop-backend-$lang.pid")) — log: $WORKSPACE/loop-backend-$lang.log"
  done
  for lang in py-sh go-sh posix-sh busybox-ash fish zsh perl-sh cpp-sh rust-sh; do
    local dir="$FT/$lang"
    [ -d "$dir" ] || { echo "  [$lang] no frontend dir — skip (run --frontends first)"; continue; }
    [ -f "$dir/run_frontend_worker.sh" ] || { echo "  [$lang] no run_frontend_worker.sh — skip (run --frontends first)"; continue; }
    if [ -f "$WORKSPACE/loop-frontend-$lang.pid" ] && kill -0 "$(cat "$WORKSPACE/loop-frontend-$lang.pid")" 2>/dev/null; then
      echo "  [$lang] worker already running (pid $(cat "$WORKSPACE/loop-frontend-$lang.pid"))"
      continue
    fi
    wait_for_load || true
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
  --wait)          # public: wait for load, then exit 0. Workers use this
                  # before heavy ops. Args: [threshold=1.5] [poll=60] [max_wait=1800]
                  shift
                  wait_for_load "${1:-1.5}" "${2:-60}" "${3:-1800}" || true
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
