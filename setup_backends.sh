#!/usr/bin/env bash
# setup_backends.sh — one git worktree per target backend, on branch
# backend/<lang>, all sharing the sh2perl submodule's core (ShIR + parser
# + node model). The lowering phase keeps the CORE single-owner; backend
# work (renderer, runtime, gate, metric) lives per-worktree.
#
#   setup_backends.sh [langs...]      create/verify worktrees (default:
#                                     perl js c python zig go rust)
#   setup_backends.sh --sync [langs]  merge main into each worktree branch
#   setup_backends.sh --remove [langs] remove the worktrees (keeps branches)
#
# Merge discipline (see PLAN.md): workers commit on backend/<lang>, merge
# main in BEFORE each verification run, and push to main only when the
# commit does not touch the shared core (src/shir.rs, src/ir.rs,
# src/estree.rs, src/parser/). Core changes stay single-owner.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SUB="$ROOT/sh2perl"
BT="$ROOT/backends"
DEFAULT_LANGS="perl js c python zig go rust"

MODE=setup
case "${1:-}" in
  --sync)   MODE=sync; shift ;;
  --remove) MODE=remove; shift ;;
esac
LANGS="${*:-$DEFAULT_LANGS}"

# perl and js are the ACTIVE backends: their workers already run from the
# main checkout (main_loop_rust.pl / main_loop_estree.pl); the worktrees
# mirror them so the same discipline applies to all languages.
declare -A WORKER=( [perl]=main_loop_rust.pl [js]=main_loop_estree.pl )

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

echo "=== $MODE: $LANGS ==="
case "$MODE" in
  setup)  for l in $LANGS; do ensure_worktree "$l"; scaffold "$l"; done ;;
  sync)   for l in $LANGS; do sync_worktree "$l"; done ;;
  remove) for l in $LANGS; do remove_worktree "$l"; done ;;
esac

if [ "$MODE" = setup ]; then
  echo
  echo "Worktrees ready:"
  git -C "$SUB" worktree list
  echo
  echo "Run a worker:  backends/<lang>/run_worker.sh   (perl/js wired to the existing loops)"
  echo "Sync main in:  $0 --sync"
  echo "Remove:        $0 --remove"
fi
