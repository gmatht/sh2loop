#!/usr/bin/env bash
# coordinator.sh — the SERVER side of remote work-stealing.
#
# A worker slot (a backend/frontend task — loop + pi) can be LEASED to a
# desktop. While leased, the server-side loop yields; the desktop runs the
# same gate+pi loop on its own clone ("worker, pi and all") and returns the
# results via git bundles.
#
# Protocol (all over ssh):
#   coordinator.sh --status                 list the slots + leases
#   coordinator.sh --lease <lang> <desktop>  mark leased (the server loop yields)
#   coordinator.sh --release <lang>          clear the lease (the loop resumes)
#   coordinator.sh --apply <lang> <sub.bundle> [root.bundle]
#                                            ingest the desktop's returned work
#
# Slots are the backend workers (c go python rust zig) + frontends. The
# ESTREE worker is NEVER stealable (it owns the shared core + priority CPU).

set -u
WS="${WS:-/nvme/ai/sh2loop}"
SUB="$WS/sh2perl"
LEASES="$WS/.leases"
mkdir -p "$LEASES"

# the steal script runs the BACKEND gate+pi loop — only the backend
# scaffolds are stealable (the frontend loops are server-side)
STEALABLE="c go python rust zig"

case "${1:-}" in
  --status)
    echo "== worker slots =="
    for lang in $STEALABLE; do
      if [ -f "$LEASES/$lang" ]; then
        printf '  %-12s LEASED to %s (since %s)\n' "$lang" \
          "$(cut -d' ' -f1 "$LEASES/$lang")" "$(cut -d' ' -f2 "$LEASES/$lang")"
      else
        running=$(pgrep -f "backends/$lang'" 2>/dev/null | wc -l)
        printf '  %-12s free (server loop: %s)\n' "$lang" \
          "$([ "$running" -gt 0 ] && echo running || echo absent)"
      fi
    done
    echo "== never stealable =="
    echo "  estree (the shared-core owner)"
    ;;
  --lease)
    lang="$2"; desktop="$3"
    case " $STEALABLE " in *" $lang "*) ;; *) echo "not a stealable slot: $lang"; exit 1;; esac
    if [ -f "$LEASES/$lang" ]; then
      echo "already leased to $(cut -d' ' -f1 "$LEASES/$lang")"; exit 1
    fi
    echo "$desktop $(date -u +%FT%T)" > "$LEASES/$lang"
    echo "leased $lang to $desktop (the server loop yields)"
    ;;
  --release)
    lang="$2"
    rm -f "$LEASES/$lang"
    echo "released $lang (the server loop resumes)"
    ;;
  --apply)
    # ingest the desktop's returned work: the submodule bundle updates
    # backend/<lang>; the optional root bundle updates the workspace root
    # (harness edits the pi may have made).
    lang="$2"; sub_bundle="${3:-}"; root_bundle="${4:-}"
    if [ -n "$sub_bundle" ] && [ -f "$sub_bundle" ]; then
      cd "$SUB" || exit 1
      git fetch "$sub_bundle" "backend/$lang:backend/$lang" 2>&1 | tail -1
      # the branch is checked out in the worktree — bring it in line
      wt="$SUB/backends/$lang"
      if [ -d "$wt" ]; then
        (cd "$wt" && git reset --hard "backend/$lang" 2>/dev/null) || true
      fi
      echo "applied submodule bundle -> backend/$lang"
    fi
    if [ -n "$root_bundle" ] && [ -f "$root_bundle" ]; then
      cd "$WS" || exit 1
      git fetch "$root_bundle" master:master 2>&1 | tail -1
      echo "applied root bundle -> master"
    fi
    ;;
  *) echo "usage: $0 {--status|--lease <lang> <desktop>|--release <lang>|--apply <lang> <sub.bundle> [root.bundle]}";;
esac
