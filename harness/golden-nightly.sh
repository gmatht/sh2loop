#!/bin/bash
# harness/golden-nightly.sh — record a render round into gmatht/sh2examples
# and publish it as a release. Driven by a cron entry at 03:14 local:
#
#   SHELL=/bin/bash
#   PATH=/usr/local/bin:/usr/bin:/bin
#   14 3 * * * /mnt/wsl/projects/sh2loop/harness/golden-nightly.sh >>/mnt/wsl/projects/sh2loop/loop-golden.log 2>&1
#
# (install with --install-cron; the path is machine state, not in git, and a
# tree move must re-run it — same rule as reap-orphan-examples.sh.)
#
# WHAT IT DOES, and why in this order:
#   1. Take the render lock. A round rewrites `renders/` under the record
#      root in place, so it must never overlap another round — or a
#      `golden-render.sh` an operator is running by hand.
#   2. Render every backend with a renderer (--all --jobs 2: this box
#      wedges on IO when several builds compile at once, and a cron job that
#      competes with the worker fleet is a self-inflicted outage).
#   3. Publish: tar the sets, `gh release create`, then commit ONLY
#      INDEX.tsv (sets/ stays gitignored — multi-MB generated text in git is
#      the "tracked target/" mistake, docs/CLEAN_GIT.md).
#   4. Push. The clone is owned by this script only; it never merges, never
#      force-pushes, and refuses to publish on top of local commits it did
#      not make (someone edited the record by hand → report, don't guess).
#
# Contract: it may fail (unlike the zig cache cleaner, a failure here has no
# caller to redden), but it must LEAVE NOTHING BEHIND: no uncommitted renders
# in the clone, no half-created release, no lock.
#
# Options:
#   --dry-run           render + build the tarball, publish nothing
#   --backends a,b      restrict the round (default: all with a renderer)
#   --jobs N            render parallelism (default 2)
#   --limit N           first N examples per backend (a smoke round)
#   --install-cron      install the 03:14 crontab entry (idempotent)
#
# Environment:
#   SH2_GOLDEN_CLONE    the sh2examples clone (default ~/.cache/sh2examples)
#   SH2_GOLDEN_REMOTE   git remote to push to (default gh)
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# cron gives a job almost no environment (this box's cron has no HOME or even
# PATH), so everything this script calls is pinned to an absolute path below.
# `gh` lives in /usr/bin, not /usr/local/bin.
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"
export HOME="${HOME:-/root}"          # git/gh want $HOME; cron may not set it
GH="$(command -v gh || echo /usr/bin/gh)"
CLONE="${SH2_GOLDEN_CLONE:-$HOME/.cache/sh2examples}"
REMOTE="${SH2_GOLDEN_REMOTE:-gh}"
REPO="gmatht/sh2examples"
DRY=0; JOBS=2; BACKENDS=""; LIMIT=0
CRON_LINE='14 3 * * * /mnt/wsl/projects/sh2loop/harness/golden-nightly.sh >>/mnt/wsl/projects/sh2loop/loop-golden.log 2>&1'

say()  { printf '%s golden-nightly: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }
fail() { printf '%s golden-nightly: FAILED: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift;;
    --backends) BACKENDS="$2"; LIMIT=0; shift 2;;
    --jobs) JOBS="$2"; shift 2;;
    --limit) LIMIT="$2"; shift 2;;
    --install-cron)
      cur="$(crontab -l 2>/dev/null || true)"
      if printf '%s\n' "$cur" | command grep -qF "$(printf '%s' "$CRON_LINE" | awk '{print $6}')"; then
        say "cron entry already present"
      else
        { printf '%s\n' "$cur" | sed '/^$/d'; printf '%s\n' "$CRON_LINE"; } | crontab - \
          || fail "could not install crontab entry"
        say "installed cron entry: $CRON_LINE"
      fi
      crontab -l | command grep -F 'golden-nightly.sh'
      exit 0;;
    -h|--help) sed -n '2,40p' "${BASH_SOURCE[0]}"; exit 0;;
    *) fail "unknown argument: $1";;
  esac
done

# ── 1. lock ──────────────────────────────────────────────────────────────
exec 9>"$ROOT/.golden-nightly.lock"
flock -n 9 || { say "another golden round is running (lock held) — skipping"; exit 0; }

# ── 2. refresh the clone ─────────────────────────────────────────────────
if [ ! -d "$CLONE/.git" ]; then
  mkdir -p "$(dirname "$CLONE")"
  say "cloning $REPO into $CLONE"
  git clone -q "git@github.com:$REPO.git" "$CLONE" || fail "clone failed"
  # a fresh clone names its only remote `origin`; --remote names the one we push
  git -C "$CLONE" remote rename origin "$REMOTE" || fail "could not name the remote $REMOTE"
fi
# accept whichever name the clone already uses (origin on a fresh clone, gh on
# the operator's copy) — the record is a single-remote repo, so whichever
# exists is the right one.
if ! git -C "$CLONE" remote get-url "$REMOTE" >/dev/null 2>&1; then
  git -C "$CLONE" remote get-url origin >/dev/null 2>&1 && REMOTE=origin
fi
git -C "$CLONE" fetch -q "$REMOTE" || fail "fetch from $REMOTE failed"
if ! git -C "$CLONE" merge-base --is-ancestor "$REMOTE/main" HEAD; then
  fail "$CLONE has local commits $REMOTE/main does not — someone is editing the record by hand; not publishing over them"
fi
git -C "$CLONE" merge -q --ff-only "$REMOTE/main" || fail "could not fast-forward to $REMOTE/main"

before_index="$(sha256sum "$CLONE/INDEX.tsv" 2>/dev/null | awk '{print $1}')"

# ── 3. render ────────────────────────────────────────────────────────────
renders_before="$(git -C "$CLONE" ls-tree -r --name-only HEAD -- sets | wc -l)"
set_args=(--jobs "$JOBS")
if [ -n "$BACKENDS" ]; then set_args+=(--backend "$BACKENDS"); else set_args+=(--all); fi
[ "$LIMIT" -gt 0 ] && set_args+=(--limit "$LIMIT")
say "rendering (${BACKENDS:-all backends}, jobs=$JOBS) into $CLONE/sets"
SH2_GOLDEN_REPO="$CLONE" "$ROOT/harness/golden-render.sh" "${set_args[@]}" >>"$CLONE/.nightly-render.log" 2>&1
rc=$?
tail -5 "$CLONE/.nightly-render.log" | sed 's/^/  | /'
[ $rc -eq 0 ] || fail "golden-render.sh exited $rc (see $CLONE/.nightly-render.log)"
rm -f "$CLONE/.nightly-render.log"

round="$(date -u +%Y%m%dT%H%M%SZ)"
tag="sets-${round}"
tarfile="$CLONE/../sh2examples-sets-$round.tar.gz"
tar czf "$tarfile" -C "$CLONE" sets INDEX.tsv || fail "tar failed"
say "tarball: $(du -h "$tarfile" | cut -f1) at $tarfile"

# ── 4. index commit (only if it changed) ────────────────────────────────
git -C "$CLONE" add INDEX.tsv sets/README.md
index_changed=0
if ! git -C "$CLONE" diff --cached --quiet; then
  index_changed=1
  if [ "$DRY" = 1 ]; then
    say "[dry-run] would commit INDEX.tsv"
  else
    git -C "$CLONE" -c user.name="sh2examples nightly" \
      -c user.email="gmatht-nightly@users.noreply.github.com" \
      commit -q -m "INDEX: render round $round" || fail "commit failed"
  fi
fi

# ── 5. release ──────────────────────────────────────────────────────────
notes="$(mktemp)"
{
  echo "Nightly render round \`$round\` (automated)."
  echo
  echo "| set | backend | sh2perl | rendered | refused | error |"
  echo "|---|---|---|---|---|---|"
  for s in "$CLONE"/sets/*/render.json; do
    [ -e "$s" ] || continue
    python3 - "$s" <<'PY'
import json, os, sys
d = json.load(open(sys.argv[1]))
c = d["counts"]
print("| %s | %s | %s | %s | %s | %s |" % (
    os.path.basename(os.path.dirname(sys.argv[1])), d["backend"],
    d["sh2perl_worktree_sha"][:9], c["rendered"], c["refused"], c["error"]))
PY
  done
  echo
  echo "Sets are directories inside the tarball: \`render.json\` (the stamp: renderer"
  echo "sha256, worktree sha/ahead/behind/dirty, per-file corpus sha), \`MANIFEST.tsv\`,"
  echo "\`renders/\`, and \`patches/tracked.patch\` when the renderer worktree had"
  echo "uncommitted lowering."
} > "$notes"

if [ "$DRY" = 1 ]; then
  say "[dry-run] notes:"; sed 's/^/  | /' "$notes"
  [ "$index_changed" = 1 ] && say "[dry-run] clone has a staged INDEX change"
  rm -f "$notes" "$tarfile"
  say "[dry-run] done — nothing published"
  exit 0
fi

"$GH" release create "$tag" "$tarfile" --repo "$REPO" \
  --title "Render sets $round" --notes-file "$notes" >/dev/null \
  || { rm -f "$notes" "$tarfile"; fail "gh release create failed"; }
say "release: https://github.com/$REPO/releases/tag/$tag"

[ "$index_changed" = 1 ] && { git -C "$CLONE" push -q "$REMOTE" HEAD:main || fail "push failed"; }
rm -f "$notes" "$tarfile"
say "done (index_changed=$index_changed, renders before=$renders_before)"
