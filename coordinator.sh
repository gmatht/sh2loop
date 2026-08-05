#!/usr/bin/env bash
# coordinator.sh — the SERVER side of remote work-stealing.
#
# A worker slot can be LEASED to a desktop. While leased, the server-side
# loop yields; the desktop runs the same gate+pi loop on its own clone.
# The lease has a HEARTBEAT: the desktop renews it periodically; the
# server REAPS stale leases (a desktop that vanished loses its slots and
# the server loops resume). The server can also reclaim when IT has spare
# compute (--reap --when-idle).
#
#   coordinator.sh --status
#   coordinator.sh --lease <lang> <desktop>
#   coordinator.sh --lease-fraction <frac> <desktop> [--allow-estree]
#       lease ceil(frac * free) slots (estree only with --allow-estree);
#       prints the leased lang list, one per line
#   coordinator.sh --heartbeat <lang> <desktop>     renew a lease
#   coordinator.sh --release <lang>
#   coordinator.sh --reap [--stale-min N] [--when-idle] [--allow-estree]
#       reclaim stale leases (and, with --when-idle, leases while the
#       server has spare compute)
#   coordinator.sh --apply <lang> <sub.bundle> [root.bundle]

set -u
WS="${WS:-/nvme/ai/sh2loop}"
SUB="$WS/sh2perl"
LEASES="$WS/.leases"
mkdir -p "$LEASES"

# the production estree worker is the shared-core owner + priority CPU —
# stealable ONLY with an explicit --allow-estree (a verified-faster
# desktop, fully-paused server loop, reliable lease)
STEALABLE="c go python rust zig"
ALL_ESTREE="estree"

now() { date +%s; }

lease_line() { # lang -> "desktop ts" or ""
  [ -f "$LEASES/$1" ] && cat "$LEASES/$1" || echo ""
}

case "${1:-}" in
  --status)
    echo "== worker slots =="
    for lang in $STEALABLE; do
      l=$(lease_line "$lang")
      if [ -n "$l" ]; then
        printf '  %-12s LEASED to %s (heartbeat %ss ago)\n' "$lang" \
          "$(echo "$l" | cut -d' ' -f1)" "$(( $(now) - $(echo "$l" | cut -d' ' -f2) ))"
      else
        running=$(pgrep -f "backends/$lang'" 2>/dev/null | wc -l)
        printf '  %-12s free (server loop: %s)\n' "$lang" \
          "$([ "$running" -gt 0 ] && echo running || echo absent)"
      fi
    done
    l=$(lease_line estree)
    if [ -n "$l" ]; then
      printf '  %-12s LEASED to %s (heartbeat %ss ago)\n' estree \
        "$(echo "$l" | cut -d' ' -f1)" "$(( $(now) - $(echo "$l" | cut -d' ' -f2) ))"
    else
      echo "  estree       running (priority — stealable only with --allow-estree)"
    fi
    ;;
  --lease)
    lang="$2"; desktop="$3"
    case " $STEALABLE " in *" $lang "*) ;; *) echo "not a stealable slot: $lang"; exit 1;; esac
    if [ -n "$(lease_line "$lang")" ]; then
      echo "already leased to $(lease_line "$lang" | cut -d' ' -f1)"; exit 1
    fi
    echo "$desktop $(now)" > "$LEASES/$lang"
    echo "leased $lang to $desktop"
    ;;
  --lease-fraction)
    frac="$2"; desktop="$3"; allow_estree=0
    [ "${4:-}" = "--allow-estree" ] && allow_estree=1
    # free slots = stealable (not leased) + optionally estree (not leased)
    free=""
    for lang in $STEALABLE; do
      [ -z "$(lease_line "$lang")" ] && free="$free $lang"
    done
    if [ "$allow_estree" = 1 ] && [ -z "$(lease_line estree)" ]; then
      free="$free estree"
    fi
    n_free=$(echo $free | wc -w)
    n_take=$(awk -v f="$frac" -v n="$n_free" 'BEGIN { c = f * n; printf "%d", (c - int(c) > 0 ? int(c) + 1 : c) }')
    [ "$n_take" -lt 1 ] && n_take=1
    [ "$n_take" -gt "$n_free" ] && n_take=$n_free
    i=0
    for lang in $free; do
      [ "$i" -ge "$n_take" ] && break
      echo "$desktop $(now)" > "$LEASES/$lang"
      echo "leased $lang to $desktop"
      i=$((i+1))
    done
    ;;
  --heartbeat)
    lang="$2"; desktop="$3"
    if [ -n "$(lease_line "$lang")" ]; then
      echo "$desktop $(now)" > "$LEASES/$lang"
    else
      echo "no lease for $lang (lost to a reap?)"; exit 1
    fi
    ;;
  --release)
    lang="$2"
    rm -f "$LEASES/$lang"
    echo "released $lang"
    ;;
  --reap)
    stale_min="${3:-10}"; when_idle=0; allow_estree=0
    for a in "$@"; do
      [ "$a" = "--when-idle" ] && when_idle=1
      [ "$a" = "--allow-estree" ] && allow_estree=1
    done
    load1=$(awk '{print $1}' /proc/loadavg)
    nproc=$(nproc)
    for lang in $STEALABLE; do
      l=$(lease_line "$lang")
      [ -z "$l" ] && continue
      ts=$(echo "$l" | cut -d' ' -f2)
      age=$(( $(now) - ts ))
      # reclaim: stale heartbeat, OR the server has spare compute
      if [ "$age" -gt $((stale_min * 60)) ]; then
        rm -f "$LEASES/$lang"
        echo "reaped $lang (stale heartbeat, ${age}s old — the server loop resumes)"
      elif [ "$when_idle" = 1 ] && awk -v l="$load1" -v n="$nproc" 'BEGIN { exit !(l < 0.6 * n) }'; then
        rm -f "$LEASES/$lang"
        echo "reaped $lang (server has spare compute — taking the work back)"
      fi
    done
    if [ "$allow_estree" = 1 ]; then
      l=$(lease_line estree)
      if [ -n "$l" ]; then
        ts=$(echo "$l" | cut -d' ' -f2)
        age=$(( $(now) - ts ))
        if [ "$age" -gt $((stale_min * 60)) ]; then
          rm -f "$LEASES/estree"
          echo "reaped estree (stale heartbeat)"
        fi
      fi
    fi
    ;;
  --apply)
    lang="$2"; sub_bundle="${3:-}"; root_bundle="${4:-}"
    if [ -n "$sub_bundle" ] && [ -f "$sub_bundle" ]; then
      cd "$SUB" || exit 1
      git fetch "$sub_bundle" "backend/$lang:backend/$lang" 2>&1 | tail -1
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
  *) echo "usage: $0 {--status|--lease <lang> <desktop>|--lease-fraction <frac> <desktop> [--allow-estree]|--heartbeat <lang> <desktop>|--release <lang>|--reap [--when-idle] [--allow-estree]|--apply <lang> <sub.bundle> [root.bundle]}";;
esac
