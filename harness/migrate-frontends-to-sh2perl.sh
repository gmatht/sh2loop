#!/usr/bin/env bash
# migrate-frontends-to-sh2perl.sh — move sh2loop/frontends/ into the sh2perl
# submodule, preserving as much git history as git allows.
#
# WHAT IT DOES
#   Works ONLY in a scratch clone directory (default: mktemp -d). It never
#   modifies the live sh2loop or sh2perl working trees, and it never pushes.
#   It produces four review artifacts:
#
#     $WORK/sh2perl-new/          clone with branch `import-frontends`:
#                                   grafted frontends/ history + codemod commit
#     $WORK/sh2loop-codemod.patch uncommitted patch that (a) deletes
#                                   frontends/ and (b) rewrites the remaining
#                                   sh2loop references to the new location
#     $WORK/MOVE.md               provenance record for the imported tree
#     $WORK/commit-map            old->new SHA map from git filter-repo
#     $WORK/oracle-refs.txt       frontend refs to ../../harness|otranspilerl|
#                                   sh2perl that CANNOT be auto-fixed (a human
#                                   must decide: vendor, golden corpus, or
#                                   out-of-tree oracle)
#
#   History: `git filter-repo` extracts the frontends-only commits from a clone
#   of sh2loop, and the result is merged into a clone of sh2perl with
#   --allow-unrelated-histories. Authors, dates, messages and ordering are
#   preserved; commit SHAs are necessarily rewritten (a cross-repo graft cannot
#   keep SHAs without importing all of sh2loop's history, which this avoids).
#
# REVIEW / ROLLOUT ORDER
#   1. bash harness/migrate-frontends-to-sh2perl.sh            # build artifacts
#   2. review history : git -C $WORK/sh2perl-new log --oneline -- frontends/ | head
#                       git -C $WORK/sh2perl-new diff --stat HEAD~1   # modules
#      review removal: git -C $WORK/sh2loop-codemod log --stat -1
#                       git -C $WORK/sh2loop-codemod show --stat HEAD
#   3. push sh2perl   : git -C $WORK/sh2perl-new push origin import-frontends
#   4. in the LIVE workspace, fetch + merge the removal branch:
#        git fetch $WORK/sh2loop-codemod move-frontends-out
#        git merge FETCH_HEAD      # removes frontends/ + repaths refs
#        git add sh2perl && git commit -m "bump sh2perl: frontends moved in"
#
#   Rollback: nothing outside $WORK changed until step 3, and steps 3/4 are a
#   normal branch + merge (revert or reset). The extracted history is a branch
#   in a temp clone, so dropping $WORK loses nothing committed upstream.
#
# OPTIONS
#   --workdir DIR        scratch dir (default: mktemp -d); kept for review
#   --sh2perl-remote URL override the submodule remote (default: .gitmodules)
#   --sh2perl-src PATH   clone sh2perl from PATH (default: the local submodule,
#                        which carries gitlink-pinned commits not yet pushed)
#   --sh2perl-ref REF    sh2perl base commit (default: the live gitlink)
#   --sh2loop-ref REF    sh2loop base commit (default: live HEAD)
#   --module-path PREFIX new Go module prefix (default github.com/gmatht/sh2perl/frontends)
#   --oracle-map FILE    apply old=new path rewrites (one per line) inside the
#                        imported frontends; without it, refs are only reported
#   --extract-only       stop after the graft (before codemods)
#   --drop-artifacts     exclude tracked generated artifacts (*.wasm, busybox,
#                        coverage/**/target/**) from the sh2perl import
#   --format-patch       also write a portable patch of the removal branch
#                        (large: it embeds the deleted tracked binaries)
#   --push               push the sh2perl branch (the ONLY live action)
#   --allow-dirty-frontends  proceed even if the live frontends/ tree is dirty
#   -h|--help
set -euo pipefail

log()  { printf '\033[1m[migrate]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[migrate] WARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[migrate] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }
run()  { log "+ $*"; "$@"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK=""
REMOTE=""
SH2PERL_REF=""
SH2PERL_SRC=""
SH2LOOP_REF=""
MODULE_PREFIX="github.com/gmatht/sh2perl/frontends"
ORACLE_MAP=""
EXTRACT_ONLY=0
PUSH=0
ALLOW_DIRTY_FE=0
DROP_ARTIFACTS=0
FORMAT_PATCH=0

while [ $# -gt 0 ]; do
  case "$1" in
    --workdir)        WORK="$2"; shift 2;;
    --sh2perl-remote) REMOTE="$2"; shift 2;;
    --sh2perl-src)    SH2PERL_SRC="$2"; shift 2;;
    --sh2perl-ref)    SH2PERL_REF="$2"; shift 2;;
    --sh2loop-ref)    SH2LOOP_REF="$2"; shift 2;;
    --module-path)    MODULE_PREFIX="$2"; shift 2;;
    --oracle-map)     ORACLE_MAP="$2"; shift 2;;
    --extract-only)   EXTRACT_ONLY=1; shift;;
    --drop-artifacts) DROP_ARTIFACTS=1; shift;;
    --format-patch)   FORMAT_PATCH=1; shift;;
    --push)           PUSH=1; shift;;
    --allow-dirty-frontends) ALLOW_DIRTY_FE=1; shift;;
    -h|--help)        sed -n '2,50p' "$0"; exit 0;;
    *) die "unknown flag $1 (try --help)";;
  esac
done

# ---------------------------------------------------------------- preflight
command -v git-filter-repo >/dev/null \
  || die "git-filter-repo not found (install git-filter-repo; the git-subtree fallback is documented in docs/TRANSFERS*.md)"
command -v perl >/dev/null || die "perl not found (used for the path codemod)"

[ -d "$ROOT/sh2perl/.git" ] || [ -f "$ROOT/sh2perl/.git" ] \
  || die "$ROOT/sh2perl is not a git checkout (submodule not initialised?)"
[ -d "$ROOT/frontends" ] || die "$ROOT/frontends not found — already moved?"

if [ -z "$REMOTE" ]; then
  REMOTE="$(git -C "$ROOT" config -f .gitmodules --get submodule.sh2perl.url 2>/dev/null || true)"
  [ -n "$REMOTE" ] || die "cannot read submodule.sh2perl.url; pass --sh2perl-remote"
fi

# The extraction is from HEAD, so uncommitted frontend work would be lost.
if [ "$ALLOW_DIRTY_FE" -eq 0 ] && \
   [ -n "$(git -C "$ROOT" status --porcelain -- frontends | head -1)" ]; then
  git -C "$ROOT" status --short -- frontends >&2
  die "live frontends/ is dirty; commit it first (or --allow-dirty-frontends)"
fi

[ -n "$WORK" ] || WORK="$(mktemp -d "${TMPDIR:-/tmp}/frontends-migrate.XXXXXX")"
mkdir -p "$WORK"

# Freeze the base: the first run records the refs it used and every rerun
# reuses them, so a moving live HEAD cannot half-rebase a resumed run (the
# clones are per-base; use a fresh --workdir to re-base).
BASE_FILE="$WORK/base.env"
if [ -f "$BASE_FILE" ]; then
  # shellcheck disable=SC1090
  . "$BASE_FILE"
  live_loop="$(git -C "$ROOT" rev-parse HEAD)"
  live_core="$(git -C "$ROOT/sh2perl" rev-parse HEAD)"
  [ "$live_loop" = "$SH2LOOP_REF" ] || warn "live sh2loop HEAD moved ($live_loop != recorded $SH2LOOP_REF); this run stays on the recorded base"
  [ "$live_core" = "$SH2PERL_REF" ] || warn "live sh2perl HEAD moved ($live_core != recorded $SH2PERL_REF); this run stays on the recorded base"
else
  [ -n "$SH2LOOP_REF" ] || SH2LOOP_REF="$(git -C "$ROOT" rev-parse HEAD)"
  [ -n "$SH2PERL_REF" ] || SH2PERL_REF="$(git -C "$ROOT/sh2perl" rev-parse HEAD)"
  printf 'SH2LOOP_REF=%q\nSH2PERL_REF=%q\n' "$SH2LOOP_REF" "$SH2PERL_REF" > "$BASE_FILE"
fi
if [ -n "$(git -C "$ROOT/sh2perl" status --porcelain | head -1)" ]; then
  warn "live sh2perl is dirty; the import is based on the pinned ref ($SH2PERL_REF), not your working tree."
  warn "commit + push your sh2perl work first if it must be in the import base."
fi

log "workspace : $ROOT"
log "sh2loop   : $SH2LOOP_REF (recorded in $BASE_FILE)"
log "sh2perl   : $REMOTE @ $SH2PERL_REF"
log "work dir  : $WORK"

# Generated build artifacts that are (mistakenly) TRACKED under frontends/.
# They bloat the import and cannot be deleted by a text patch, so reviewers
# should either move them with the tree (default) or untrack them here with
# --drop-artifacts (excluded from the import; sh2loop still deletes the dir).
ARTIFACT_PATHS=(
  'frontends/**/target/**'
  'frontends/coverage/**/target/**'
  'frontends/**/*.wasm'
  'frontends/busybox/busybox'
  'frontends/**/*.o'
  'frontends/**/*.rlib'
  'frontends/**/*.rmeta'
)
artifact_count() {
  git -C "$ROOT" ls-files -- "${ARTIFACT_PATHS[@]}" 2>/dev/null | wc -l | tr -d ' '
}
artifact_bytes() {
  git -C "$ROOT" ls-files -z -- "${ARTIFACT_PATHS[@]}" 2>/dev/null \
    | xargs -0 du -ch 2>/dev/null | tail -1 | cut -f1
}
ART_COUNT="$(artifact_count)"
if [ "$ART_COUNT" -gt 0 ]; then
  if [ "$DROP_ARTIFACTS" -eq 1 ]; then
    log "excluding $ART_COUNT tracked generated artifact files ($(artifact_bytes)) from the import"
  else
    warn "frontends/ TRACKS $ART_COUNT generated artifact files ($(artifact_bytes)) —"
    warn "e.g. *.wasm, busybox, coverage/**/target/**. Move them with the tree, or"
    warn "re-run with --drop-artifacts to exclude them from the sh2perl import."
  fi
fi

# ------------------------------------------------- 1. extract frontends history
SRC="$WORK/sh2loop-src"
if [ ! -d "$SRC" ]; then
  run git clone --quiet "$ROOT" "$SRC"
  run git -C "$SRC" checkout -q -b src-base "$SH2LOOP_REF"
fi
EXTRACT="$WORK/fe-extract"
if [ ! -d "$EXTRACT" ]; then
  # filter-repo wants a fresh clone; a fresh clone of the clone is cheap.
  run git clone --quiet "$SRC" "$EXTRACT"
  run git -C "$EXTRACT" checkout -q -b fe-import src-base
  # keep only commits touching frontends/, paths unchanged (frontends/...)
  run git -C "$EXTRACT" filter-repo --force --path frontends/
  if [ "$DROP_ARTIFACTS" -eq 1 ]; then
    # git-filter-repo has no --path-exclude; a second pass with --invert-paths
    # removes the generated artifacts from the imported history entirely.
    run git -C "$EXTRACT" filter-repo --force --invert-paths \
      --path-regex '^frontends/.*(/target/.*|[.](o|rlib|rmeta|wasm))$' \
      --path-regex '^frontends/busybox/busybox$'
  fi
fi
FE_BRANCH="$(git -C "$EXTRACT" rev-parse --abbrev-ref HEAD)"
[ "$FE_BRANCH" = HEAD ] && { git -C "$EXTRACT" checkout -q -b fe-import; FE_BRANCH=fe-import; }
FE_COUNT="$(git -C "$EXTRACT" rev-list --count HEAD)"
log "extracted $FE_COUNT commits touching frontends/ (branch $FE_BRANCH)"

# ------------------------------------------------------- 2. graft into sh2perl
DEST="$WORK/sh2perl-new"
if [ ! -d "$DEST" ]; then
  # Clone the LOCAL submodule (it may carry gitlink-pinned commits not yet
  # pushed); point origin at the real remote for the eventual push.
  run git clone --quiet "${SH2PERL_SRC:-$ROOT/sh2perl}" "$DEST"
  run git -C "$DEST" remote set-url origin "$REMOTE"
  run git -C "$DEST" checkout -q -b import-frontends "$SH2PERL_REF"
  [ -e "$DEST/frontends" ] && die "$DEST already has frontends/ — resolve manually"
  run git -C "$DEST" fetch --quiet "$EXTRACT" "$FE_BRANCH"
  if ! git -C "$DEST" merge --allow-unrelated-histories --no-edit --no-stat \
        -m "Import frontends/ history from sh2loop ($SH2LOOP_REF)" FETCH_HEAD; then
    die "merge conflicted; resolve in $DEST then rerun with the same --workdir"
  fi
fi
log "grafted: $(git -C "$DEST" rev-list --count HEAD -- frontends/) commits touch frontends/"

if [ "$EXTRACT_ONLY" -eq 1 ]; then
  log "--extract-only: stopping before codemods. Inspect:"
  log "  git -C $DEST log --oneline -- frontends/ | head"
  exit 0
fi

# ------------------------------------- 3. codemod inside the imported frontends
# 3a. Go module paths: github.com/gmatht/sh2loop/frontends/* -> the new prefix.
if git -C "$DEST" grep -qI 'github.com/gmatht/sh2loop/frontends' -- frontends 2>/dev/null; then
  git -C "$DEST" grep -lI 'github.com/gmatht/sh2loop/frontends' -- frontends \
    | while read -r f; do
        perl -pi -e "s{github\.com/gmatht/sh2loop/frontends}{$MODULE_PREFIX}g" "$DEST/$f"
      done
  run git -C "$DEST" add -A frontends
  log "module paths rewritten -> $MODULE_PREFIX"
fi

# 3b. Optional oracle-path rewrites (human-supplied mapping; never guessed).
if [ -n "$ORACLE_MAP" ]; then
  [ -f "$ORACLE_MAP" ] || die "--oracle-map $ORACLE_MAP not found"
  while IFS='=' read -r old new; do
    [ -z "$old" ] && continue
    case "$old" in \#*) continue;; esac
    log "oracle-path rewrite: $old -> $new"
    git -C "$DEST" grep -lI -- "$old" -- frontends 2>/dev/null | while read -r f; do
      perl -pi -e "s{\Q$old\E}{$new}g" "$DEST/$f"
    done
  done < "$ORACLE_MAP"
  run git -C "$DEST" add -A frontends
fi

# 3c. Report the refs that must NOT be auto-rewritten (they point outside
# sh2perl and are a policy decision, not a path substitution).
{
  echo "# Frontend references OUTSIDE sh2perl — decide per policy."
  echo "# vendor a runner/namespace into sh2perl, switch to a golden-A1 corpus,"
  echo "# or accept an out-of-tree oracle (breaks sh2perl's self-contained CI)."
  echo "#"
  git -C "$DEST" grep -nIE '\.\./\.\./(harness|otranspilerl|sh2perl)' -- frontends 2>/dev/null || true
} > "$WORK/oracle-refs.txt"
log "oracle refs needing a decision: $(grep -c '\.\./\.\./' "$WORK/oracle-refs.txt" || true) (see $WORK/oracle-refs.txt)"

if ! git -C "$DEST" diff --cached --quiet; then
  run git -C "$DEST" commit -q -m "frontends: repath after move into sh2perl (modules${ORACLE_MAP:+ + oracle paths})"
  log "codemod commit created; inspect: git -C $DEST diff --stat HEAD~1"
else
  log "no codemod changes were needed"
fi

# ------------------------------ 4. sh2loop side: removal + reference rewrite
# Committed on a branch (NOT a raw patch): frontends/ tracks generated
# binaries (*.wasm, busybox, coverage/**/target/**), and a binary deletion is
# not expressible as a plain text patch. A branch is also easier to review.
COD="$WORK/sh2loop-codemod"
if [ ! -d "$COD" ]; then
  run git clone --quiet "$ROOT" "$COD"
  run git -C "$COD" checkout -q -b move-frontends-out "$SH2LOOP_REF"
  run git -C "$COD" rm -r -q frontends
  # Rewrite remaining references, excluding other repos/mirrors and generated logs.
  # Guard: do not double-prefix an existing sh2perl/frontends/.
  git -C "$COD" grep -lI 'frontends/' 2>/dev/null \
    | grep -vE '^(s2p\.[a-z]+/|s2p_go/|node_modules/|triage/|gate-reports/|junk/|\.pir|frontends/)' \
    | while read -r f; do
        perl -pi -e 's{(?<!sh2perl/)frontends/}{sh2perl/frontends/}g' "$COD/$f"
      done
  run git -C "$COD" add -A
  run git -C "$COD" commit -q -m "frontends moved into sh2perl: remove + repath refs"
fi
# format-patch is binary-safe but large (it embeds deleted tracked binaries);
# the branch is the primary artifact. Opt in with --format-patch.
if [ "$FORMAT_PATCH" -eq 1 ]; then
  git -C "$COD" format-patch -1 --stdout > "$WORK/sh2loop-move.patch" 2>/dev/null || true
fi
log "sh2loop branch move-frontends-out: $(git -C "$COD" show --stat --oneline HEAD | head -1)"
log "  stat: $(git -C "$COD" show --shortstat HEAD | tail -1)"
if [ "$FORMAT_PATCH" -eq 1 ]; then
  log "  convenience patch: $WORK/sh2loop-move.patch ($(du -h "$WORK/sh2loop-move.patch" 2>/dev/null | cut -f1 || echo 0))"
fi

# ------------------------------------------------------- 5. provenance record + map
[ -f "$EXTRACT/.git/filter-repo/commit-map" ] \
  && cp "$EXTRACT/.git/filter-repo/commit-map" "$WORK/commit-map"
cat > "$WORK/MOVE.md" <<EOF
# frontends/ provenance

- Imported from: \`$(git -C "$ROOT" remote get-url origin 2>/dev/null || echo sh2loop)\`
  at \`$SH2LOOP_REF\` (frontends-only history, \`git filter-repo --path frontends/\`).
- Imported into: \`$REMOTE\` at \`$SH2PERL_REF\`, branch \`import-frontends\`.
- Commit SHAs were rewritten by the graft; see \`commit-map\` beside this file.
- Go module prefix rewritten to \`$MODULE_PREFIX\`.
- Oracle references (\`../../harness\`, \`../../otranspilerl\`, \`../../sh2perl\`)
  are listed in \`oracle-refs.txt\` and were NOT auto-rewritten.
- sh2loop-side removal + reference rewrite: branch \`move-frontends-out\` in
  \`$COD\`$(if [ "$FORMAT_PATCH" -eq 1 ]; then printf ' (patch copy: \`sh2loop-move.patch\`)'; fi).
- Tracked generated artifacts under frontends/: $ART_COUNT files ($(artifact_bytes)):
  $(if [ "$DROP_ARTIFACTS" -eq 1 ]; then echo 'EXCLUDED from this import (--drop-artifacts).'; else echo 'included; consider --drop-artifacts on a re-run.'; fi)
EOF
log "wrote $WORK/MOVE.md"

# ------------------------------------------------------------------- 6. push / next
if [ "$PUSH" -eq 1 ]; then
  run git -C "$DEST" push origin import-frontends
  log "pushed; open a PR in sh2perl, then apply the sh2loop patch:"
else
  log "not pushed (use --push, or push manually after review)"
fi
cat <<EOF

next steps
  1. review history : git -C $DEST log --oneline -- frontends/ | head
                      git -C $DEST diff --stat HEAD~1
  2. review removal : git -C $COD log --stat -1
                      git -C $COD show --stat HEAD
  3. push sh2perl   : git -C $DEST push origin import-frontends   # PR + merge
  4. live workspace : git fetch $COD move-frontends-out
                      git merge FETCH_HEAD
                      git add sh2perl
                      git commit -m "bump sh2perl: frontends moved into the core"
  5. freeze reminder: nothing may commit to sh2loop/frontends after step 3
                      until step 4 has landed on every active branch.
EOF
