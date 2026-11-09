#!/usr/bin/env bash
# clone-full.sh — download the FULL sh2loop source from GitHub, including the
# backend worktrees.
#
# Why this script exists: the backends (sh2perl/backends/<lang>) are git
# WORKTREES of the sh2perl submodule — not submodules, not plain directories.
# A plain `git clone` + `git submodule update --init --recursive` does NOT
# bring them back, and the recursive form actively FAILS: sh2perl/.gitmodules
# holds path-only entries for backends/* (no URL — see the comment in that
# file), so git aborts with "No url found for submodule path ...". This
# script does the clone the way the layout requires:
#   1. clones sh2loop from GitHub (SSH by default, --https for keyless boxes)
#   2. inits ONLY the real submodules: sh2perl, then frontends inside it
#   3. recreates one worktree per origin/backend/* branch at backends/<name>
#   4. recreates root-placed worktrees whose branches are on GitHub (s2p.c)
#   5. prints what could NOT be recreated (branches never pushed to GitHub)
#
# Usage:
#   ./clone-full.sh [--https] [DEST]      (default DEST=./sh2loop-full)
#
# Re-runnable: if DEST already holds the clone, the clone step is skipped and
# missing submodules/worktrees are (re)created in place.
set -euo pipefail

PROTO=ssh
DEST="./sh2loop-full"
while [ $# -gt 0 ]; do
  case "$1" in
    --https) PROTO=https; shift ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | grep '^#' | sed 's/^# //;s/^#//'
      echo "Usage: $0 [--https] [DEST]"
      exit 0 ;;
    -*) echo "unknown flag: $1 (see --help)" >&2; exit 2 ;;
    *) DEST="$1"; shift ;;
  esac
done

if [ "$PROTO" = https ]; then
  ROOT_URL="https://github.com/gmatht/sh2loop.git"
  # The .gitmodules URLs are SSH; rewrite them so a keyless box stays on https.
  INSTEAD_OF=( -c "url.https://github.com/.insteadOf=git@github.com:" )
else
  ROOT_URL="git@github.com:gmatht/sh2loop.git"
  INSTEAD_OF=()
fi
SUB="$DEST/sh2perl"

created=0; skipped=0; missing=0
is_wt() { # $1=repo $2=path : true if path is a REGISTERED worktree
  git -C "$1" worktree list --porcelain 2>/dev/null | grep -qxF "worktree $2"
}
add_wt() { # $1=repo $2=path $3=branch $4=start-point (remote ref)
  local repo="$1" path="$2" branch="$3" start="$4"
  if is_wt "$repo" "$path"; then
    echo "  [skip] $path already a worktree"
    skipped=$((skipped+1)); return 0
  fi
  # A plain clone leaves EMPTY placeholder dirs behind for the unmapped
  # backends/*/s2p.* gitlinks — they are not checkouts, so clear them.
  # Anything with real content that is not a worktree is left alone.
  if [ -e "$path" ]; then
    if [ -n "$(ls -A "$path")" ]; then
      echo "  [warn] $path has content but is not a worktree — leaving alone"
      skipped=$((skipped+1)); return 0
    fi
    rmdir "$path"
  fi
  if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$repo" worktree add -- "$path" "$branch" >/dev/null
  else
    git -C "$repo" worktree add --track -b "$branch" -- "$path" "$start" >/dev/null
  fi
  echo "  [new]  $path <- $branch"
  created=$((created+1))
}

# 1. clone (skip if DEST is already the workspace)
if [ -d "$DEST/.git" ]; then
  echo "== DEST $DEST already cloned — refreshing in place =="
else
  echo "== cloning $ROOT_URL -> $DEST =="
  git "${INSTEAD_OF[@]}" clone "$ROOT_URL" "$DEST"
fi

# 2. real submodules ONLY. A blanket `--recursive` init dies on the path-only
# backends/* entries in sh2perl/.gitmodules (they are worktree gitlinks with
# no URL, not fetchable submodules), and on the unmapped s2p.* gitlinks at
# the root (no .gitmodules entry at all) — so name the real ones explicitly.
echo "== submodules (real ones only) =="
git -C "$DEST" submodule update --init -- sh2perl
git -C "$SUB" submodule update --init -- frontends
git -C "$SUB" fetch origin 2>/dev/null \
  || echo "  (warning: fetch failed — using cached remote refs)"

# 3. one worktree per origin/backend/* branch (the canonical layout that
# setup_backends.sh expects: backends/<name> on backend/<name>)
git -C "$SUB" worktree prune 2>/dev/null || true
echo "== backend worktrees =="
while read -r name; do
  [ -n "$name" ] || continue
  if git -C "$SUB" show-ref --verify --quiet \
       "refs/remotes/origin/backend/$name"; then
    add_wt "$SUB" "$SUB/backends/$name" "backend/$name" \
      "origin/backend/$name"
  else
    echo "  [??] origin/backend/$name vanished — skipping"
    missing=$((missing+1))
  fi
done < <(git -C "$SUB" for-each-ref \
           --format='%(refname:strip=4)' 'refs/remotes/origin/backend/' | sort)

# 4. root-placed sh2perl worktrees whose branches ARE on GitHub.
# (s2p.rust, s2p_go and the .<scratch> worktrees were never pushed, so only
# s2p.c is reproducible from GitHub.)
echo "== extra worktrees =="
for spec in "s2p.c:s2p.c"; do
  rel="${spec%%:*}"; br="${spec##*:}"
  if git -C "$SUB" show-ref --verify --quiet "refs/remotes/origin/$br"; then
    add_wt "$SUB" "$DEST/$rel" "$br" "origin/$br"
  else
    echo "  [missing] origin/$br not on GitHub — cannot recreate $rel"
    missing=$((missing+1))
  fi
done

# 5. verify + report
echo "== verify =="
git -C "$DEST" submodule status -- sh2perl
git -C "$SUB" submodule status -- frontends
echo "--- sh2perl worktrees ---"
git -C "$SUB" worktree list
echo "--- root worktrees ---"
git -C "$DEST" worktree list
echo "== done: $created created, $skipped already present, $missing unrecoverable =="
cat <<'NOTE'
NOTE — a few experiment/scratch branches were never pushed to GitHub and
cannot be downloaded (as of 2026-10-24): s2p.rust, s2p_go,
dedupe/perl-renderer, pir-sqfix, fish-capture-arrow, the .<scratch>
worktrees, and the root fb0-raster worktree. Push them (or fetch
from the LAN remotes) if you need them elsewhere. Next: run
./setup_backends.sh [langs] to scaffold BACKEND.md/run_worker.sh per worktree.
NOTE
