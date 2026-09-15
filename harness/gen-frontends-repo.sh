#!/usr/bin/env bash
# gen-frontends-repo.sh — generate `otranspiler-frontends` (the frontends'
# OWN repository) out of sh2loop's frontends/, and make it sh2perl's frontend
# submodule at `sh2perl/frontends/`.
#
# WHY
#   frontends/ exists only inside the sh2loop development workspace; it is not
#   in sh2perl and has no remote of its own (verified: 0 commits touching it in
#   sh2perl on any ref; 1392 tracked files in sh2loop;
#   harness/migrate-frontends-to-sh2perl.sh is an unapplied proposal).  The -O4
#   drivers need it (python-O4 shells out to py-sh-go), and sh2perl's own
#   per-backend gates reference the C/Go corpora under it.  Giving it a repo and
#   consuming it as a SUBMODULE keeps one copy authoritative instead of
#   duplicating the tree into each consumer.
#
# WHAT IT DOES (all LOCAL; nothing is pushed without --push)
#   1. splits `frontends/` out of a clone of sh2loop with git filter-repo,
#      renaming `frontends/...` -> `...` so the repo root IS the frontends tree
#      (git filter-repo --path frontends/ --path-rename frontends/:)
#   2. creates the repo at $DEST, adds LICENSE (the GPL-3 TEXT copied from
#      sh2perl/LICENSE.GPL3 — never sh2perl/LICENSE, which is a personal grant)
#      and a GENERATED README, sets origin, commits
#   3. with --add-to-sh2perl: `git submodule add <repo> frontends` inside
#      sh2perl, points its origin at the real URL, and commits in sh2perl
#   4. prints the push order and the follow-ups that are NOT done here
#
# NOT DONE HERE (deliberately, they are separate decisions)
#   - removing sh2loop/frontends: 12 harness/CI scripts reference those paths,
#     so the removal has its own review (see the printed follow-ups).
#   - pushing anything.
#
# OPTIONS
#   --dest DIR             where to create the repo
#                          (default: $HOME/src/otranspiler-frontends)
#   --workdir DIR          scratch dir (default: mktemp -d); kept for review
#   --remote URL           origin for the new repo
#                          (default: derived from sh2perl's GitHub URL)
#   --sh2loop-ref REF      sh2loop base commit (default: live HEAD)
#   --name NAME            repository name (default: otranspiler-frontends)
#   --snapshot             single squashed import instead of full history
#   --add-to-sh2perl       also add it as sh2perl's `frontends` submodule
#   --allow-dirty          proceed even if frontends/ is dirty
#   --push                 push the frontends repo and sh2perl (the ONLY live
#                          actions); requires --remote
#   -h|--help
set -euo pipefail

log()  { printf '\033[1m[fe]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[fe] WARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[fe] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }
run()  { log "+ $*"; "$@"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST=""; WORK=""; REMOTE=""; SH2LOOP_REF=""; NAME="otranspiler-frontends"
SNAP=0; ADD_SH2PERL=0; ALLOW_DIRTY=0; PUSH=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dest)            DEST="$2"; shift 2;;
    --workdir)         WORK="$2"; shift 2;;
    --remote)          REMOTE="$2"; shift 2;;
    --sh2loop-ref)     SH2LOOP_REF="$2"; shift 2;;
    --name)            NAME="$2"; shift 2;;
    --snapshot)        SNAP=1; shift;;
    --add-to-sh2perl)  ADD_SH2PERL=1; shift;;
    --allow-dirty)     ALLOW_DIRTY=1; shift;;
    --push)            PUSH=1; shift;;
    -h|--help)         sed -n '2,46p' "$0"; exit 0;;
    *) die "unknown flag $1 (try --help)";;
  esac
done

# ---------------------------------------------------------------- preflight
[ -d "$ROOT/frontends" ] || die "$ROOT/frontends not found — already moved?"
[ -d "$ROOT/sh2perl/.git" ] || [ -f "$ROOT/sh2perl/.git" ] \
  || die "$ROOT/sh2perl is not a git checkout (submodule not initialised?)"
# The licence TEXT, never the personal grant (see D1 in docs/O4-SPLIT-OFF-PLAN.md).
[ -f "$ROOT/sh2perl/LICENSE.GPL3" ] \
  || die "$ROOT/sh2perl/LICENSE.GPL3 missing — refusing to invent a licence"
[ "$SNAP" -eq 0 ] && { command -v git-filter-repo >/dev/null \
  || die "git-filter-repo not found (use --snapshot)"; }
if [ "$ALLOW_DIRTY" -eq 0 ] && [ -n "$(git -C "$ROOT" status --porcelain -- frontends | head -1)" ]; then
  git -C "$ROOT" status --short -- frontends >&2
  die "live frontends/ is dirty; commit it first (or --allow-dirty)"
fi

[ -n "$SH2LOOP_REF" ] || SH2LOOP_REF="$(git -C "$ROOT" rev-parse HEAD)"
[ -n "$WORK" ] || WORK="$(mktemp -d "${TMPDIR:-/tmp}/fe-repo.XXXXXX")"
[ -n "$DEST" ] || DEST="$HOME/src/$NAME"

# Derive the remote from sh2perl's GitHub URL (the .gitmodules entry, not the
# local `ai` mirror that sh2perl's own config points at).
SH2PERL_URL="$(git -C "$ROOT" config -f .gitmodules --get submodule.sh2perl.url 2>/dev/null || true)"
if [ -z "$REMOTE" ] && [ -n "$SH2PERL_URL" ]; then
  case "$SH2PERL_URL" in
    */?*) REMOTE="${SH2PERL_URL%/*}/$NAME.git";;
    *)    REMOTE="";;
  esac
  [ "$REMOTE" = "$SH2PERL_URL" ] && REMOTE=""
fi

log "workspace  : $ROOT"
log "base       : $SH2LOOP_REF"
log "repo       : $DEST  (origin: ${REMOTE:-<none — pass --remote>})"
log "mode       : $([ "$SNAP" -eq 1 ] && echo 'snapshot' || echo 'history (git filter-repo)')"
[ -n "$(git -C "$ROOT/sh2perl" status --porcelain | head -1)" ] && \
  warn "sh2perl is dirty; the submodule commit will be made on top of its working tree"

mkdir -p "$WORK"

# ------------------------------------------------ 1. split frontends history
SRC="$WORK/src"
EX="$WORK/extract"
if [ ! -d "$DEST/.git" ]; then
  if [ "$SNAP" -eq 0 ]; then
    [ -d "$SRC" ] || { run git clone --quiet "$ROOT" "$SRC"; run git -C "$SRC" checkout -q "$SH2LOOP_REF"; }
    if [ ! -d "$EX" ]; then
      run git clone --quiet "$SRC" "$EX"
      # --path-rename strips the prefix so the repo root IS the frontends tree,
      # which keeps `find_frontend()`'s <root>/frontends/py-sh-go layout inside
      # any consumer that mounts it at `frontends/`.
      run git -C "$EX" filter-repo --force --path frontends/ --path-rename frontends/:
    fi
    run git clone --quiet "$EX" "$DEST"
    log "imported $(git -C "$DEST" rev-list --count HEAD) commits of frontends/ history"
    [ -f "$EX/.git/filter-repo/commit-map" ] && cp "$EX/.git/filter-repo/commit-map" "$WORK/commit-map"
  else
    run git init -q "$DEST"
    git -C "$SRC" archive "$SH2LOOP_REF" frontends | tar -x -C "$DEST" --strip-components=1 \
      || { [ -d "$SRC" ] || git clone --quiet "$ROOT" "$SRC"; git -C "$SRC" archive "$SH2LOOP_REF" frontends | tar -x -C "$DEST" --strip-components=1; }
    log "snapshot export at $SH2LOOP_REF (no history)"
  fi
fi

# --------------------------------------------------- 2. licence + README + origin
if [ ! -f "$DEST/LICENSE" ]; then
  # Verbatim GPL-3 TEXT.  sh2perl/LICENSE is a PERSONAL grant keyed to named
  # paid-work recipients and is deliberately NOT copied anywhere.
  cp "$ROOT/sh2perl/LICENSE.GPL3" "$DEST/LICENSE"
  log "LICENSE <- sh2perl/LICENSE.GPL3 (GPL-3 text)"
fi
if [ ! -f "$DEST/README.md" ]; then
  cat > "$DEST/README.md" <<'RD'
# otranspiler-frontends

The front ends for the `otranspiler` / [sh2perl](https://github.com/gmatht/sh2perl)
pipeline: each one parses its own language and emits the same A1 shIR contract,
so every backend consumes one IR.

```
py-sh-go/    Python  ·  c-sh-go/    C  ·  cpp-sh-go/  C++
go-sh/       Go      ·  java-sh-go/ Java ·  perl-sh-go/ Perl
posix-sh-go/ POSIX sh ·  zsh-sh-go/ zsh ·  fish-sh-go/ fish
bat-sh-go/   batch   ·  busybox/    busybox applets
corpus-c/    C corpus ·  coverage/   coverage tooling
```

## Build

Each frontend builds itself; they are Go programs (a couple are Rust):

```sh
make -C py-sh-go          # -> py-sh-go/py-sh-go   (the binary is gitignored)
```

The binaries are **not** committed — upstream `.gitignore` treats them as
build-on-test, so a consumer must build the frontend it needs.
`python-O4` for example shells out to `py-sh-go/py-sh-go`.

## Who uses it

- `sh2perl` mounts this repo at `frontends/` (submodule) — its per-backend
  gates reference the corpora under it.
- the `-O4` drivers (`bash-O4`, `python-O4`) reach the frontends through their
  `sh2perl` submodule, so there is exactly one authoritative copy.

## Licence

GPL-3 — see `LICENSE`, a verbatim copy of `sh2perl/LICENSE.GPL3`.
RD
  log "README.md generated"
fi
if [ ! -e "$DEST/.git" ]; then die "not a git repo: $DEST"; fi
git -C "$DEST" add -A
git -C "$DEST" diff --cached --quiet || \
  git -C "$DEST" -c user.email=split@local -c user.name=split \
    commit -q -m "$NAME: LICENSE (GPL-3) + README"
if [ -n "$REMOTE" ]; then
  git -C "$DEST" remote get-url origin >/dev/null 2>&1 \
    && git -C "$DEST" remote set-url origin "$REMOTE" \
    || git -C "$DEST" remote add origin "$REMOTE"
fi
# Belt and braces: the personal grant must not be present.
for f in "$DEST/LICENSE"; do
  grep -qiE 'ADDITIONALLY|McCabe-Dansted|Apache-2\.0' "$f" \
    && die "$f contains sh2perl's personal grant; this repo carries the GPL-3 text only"
done
log "repo ready: $DEST @ $(git -C "$DEST" rev-parse --short HEAD)"

# ------------------------------------- 3. make it sh2perl's `frontends` submodule
if [ "$ADD_SH2PERL" -eq 1 ]; then
  SH="$ROOT/sh2perl"
  if git -C "$SH" config -f .gitmodules --get submodule.frontends.url >/dev/null 2>&1; then
    log "sh2perl already has a frontends submodule; leaving it alone"
  else
    [ -e "$SH/frontends" ] && die "$SH/frontends already exists — resolve manually"
    run git -C "$SH" -c protocol.file.allow=always submodule add --force "$DEST" frontends
    [ -n "$REMOTE" ] && run git -C "$SH" config -f .gitmodules submodule.frontends.url "$REMOTE"
    run git -C "$SH/frontends" remote set-url origin "${REMOTE:-$DEST}"
    git -C "$SH" add .gitmodules frontends
    git -C "$SH" -c user.email=split@local -c user.name=split \
      commit -q -m "frontends: consume $NAME as a submodule at frontends/

The frontends lived only in the sh2loop workspace; they now have their own
repository and sh2perl mounts it.  Their binaries are built, not committed
($NAME .gitignore), so a consumer runs \`make -C frontends/<lang>-sh-go\`."
    log "sh2perl: frontends submodule @ $(git -C "$SH/frontends" rev-parse --short HEAD)"
    log "workspace gitlink now differs — bump it with: git add sh2perl && git commit"
  fi
fi

# ------------------------------------------------------------------- 4. push / next
if [ "$PUSH" -eq 1 ]; then
  [ -n "$REMOTE" ] || die "--push needs --remote URL"
  run git -C "$DEST" push -u origin HEAD
  [ "$ADD_SH2PERL" -eq 1 ] && log "sh2perl commit is local; push it from sh2perl's own remote"
  log "pushed $NAME"
else
  log "not pushed"
fi

REPO_SPEC="$(printf '%s' "${REMOTE#git@github.com:}" | sed 's/\.git$//')"
cat <<EOF

next steps (nothing was pushed unless --push was given)
  1. review the new repo : git -C $DEST log --oneline | head
                           git -C $DEST ls-files | head -30
                           git -C $DEST show --stat HEAD | head
  2. create the remote   : gh repo create ${REPO_SPEC:-<owner>/<name>} --private \\
                             --description 'front ends for the otranspiler/sh2perl pipeline (GPL-3)'
                           bash harness/gen-frontends-repo.sh --dest $DEST --remote $REMOTE --push
  3. sh2perl side        : git -C $ROOT/sh2perl log --oneline -1
                           (push sh2perl from ITS remote, then bump the gitlink here:
                            git add sh2perl && git commit -m 'bump sh2perl: frontends submodule')
  4. NOT done here — removing sh2loop/frontends.  12 harness/CI scripts still
     reference those paths (c_gate_main.sh, corpus-c.sh, chimera-gate.sh, ...),
     so repath them first; until then the workspace copy is a duplicate.
$([ -f "$WORK/commit-map" ] && echo "  provenance: $WORK/commit-map (rewritten SHAs)" || true)
EOF
