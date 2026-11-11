#!/usr/bin/env bash
# parked-work.sh — the commit-before-next-item rule, made checkable.
#
# WHY (measured 2026-11-11): a workspace commit lands on a side branch
# whenever origin/master has moved and the tree is too dirty to rebase, and
# NOTHING stops the next item from starting. Four branches were parked at
# once (section-a, section-b, plan-v153, d4-v154) — the backlog grows faster
# than a human clears it.
#
#   --report          age/commit table for every branch ahead of origin/master
#   --guard <worker>  exit 3 if THAT worker already has parked commits: it
#                     lands or drops that work before starting a new item
#   --no-fetch        skip `git fetch` (preflight callers, offline boxes)
#
# SH2_PARKED_MAX_H (default 24) marks a branch FROZEN in the report. The guard
# fires regardless of age, because a worker must not stack items.
#
# The guard is PER WORKER on purpose: a global stop would freeze the whole
# fleet on someone else's parked branch. `harness/start-worker.sh` calls it
# with the worker name, so a worker that parked its last commit does not
# begin another item; everyone else is unaffected.
set -uo pipefail

ROOT="${SH2_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
MAXH="${SH2_PARKED_MAX_H:-24}"
mode=report
worker=""
fetch=1
while [ $# -gt 0 ]; do
  case "$1" in
    --report)   mode=report ;;
    --guard)    mode=guard; worker="${2:?--guard needs a worker name}"; shift ;;
    --no-fetch) fetch=0 ;;
    -h|--help)  sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "parked-work.sh: unknown argument '$1'" >&2; exit 2 ;;
  esac
  shift
done

cd "$ROOT" || exit 2
[ "$fetch" = 1 ] && git fetch -q origin 2>/dev/null

now=$(date +%s)
TAB=$(printf '\t')
# "branch<TAB>commits<TAB>age_hours", oldest first.
rows="$(
  git for-each-ref --format='%(refname:short)' refs/remotes/origin 2>/dev/null \
  | command grep -v -e '^origin/HEAD$' -e '^origin/master$' \
  | while read -r b; do
      n=$(git rev-list --count "origin/master..$b" 2>/dev/null || echo 0)
      [ "${n:-0}" -gt 0 ] || continue
      ct=$(git log -1 --format=%ct "$b" 2>/dev/null || echo "$now")
      printf '%s\t%s\t%s\n' "${b#origin/}" "$n" "$(( (now - ct) / 3600 ))"
    done | sort -t "$TAB" -k3,3nr
)"

if [ "$mode" = guard ]; then
  if [ "${SH2_PARKED_FREEZE:-1}" = 0 ]; then
    echo "parked-work: guard disabled for this start (SH2_PARKED_FREEZE=0)"
    exit 0
  fi
  hit="$(printf '%s\n' "$rows" | awk -F'\t' -v w="$worker" 'NF && ($1 == w || $1 ~ ("(^|-)" w "(-|$)"))')"
  if [ -n "$hit" ]; then
    echo "PARKED WORK BLOCKS $worker — land or drop it before the next item:" >&2
    printf '%s\n' "$hit" | awk -F'\t' '{printf "  %-24s %s commit(s), %sh old\n", $1, $2, $3}' >&2
    echo "Remedy: rebase onto origin/master and push, or tag it and delete the" >&2
    echo "        branch. SH2_PARKED_FREEZE=0 disables this guard for one start." >&2
    exit 3
  fi
  exit 0
fi

if [ -z "$rows" ]; then
  echo "parked-work: nothing parked (every branch is at or behind origin/master)"
  exit 0
fi

printf '%-26s %8s %7s  %s\n' BRANCH COMMITS AGE_H STATE
frozen=0
total=0
while IFS="$TAB" read -r b n age; do
  [ -n "${b:-}" ] || continue
  state=ok
  if [ "$age" -ge "$MAXH" ]; then state="FROZEN(>${MAXH}h)"; frozen=$((frozen + 1)); fi
  printf '%-26s %8s %7s  %s\n' "$b" "$n" "$age" "$state"
  total=$((total + n))
done <<< "$rows"

echo
echo "parked-work: $(printf '%s\n' "$rows" | wc -l) branch(es), $total commit(s), $frozen frozen at ${MAXH}h."
if [ "$frozen" -gt 0 ]; then
  echo "  A frozen branch means the next item should NOT start until it lands."
fi
exit 0
