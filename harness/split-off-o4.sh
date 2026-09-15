#!/usr/bin/env bash
# split-off-o4.sh — SPLIT the -O4 driver family (bash-o4 + otranspilerl) out of
# the sh2loop development workspace into its own GPL-3 repository, with sh2perl
# as a pinned submodule.
#
# NOT a "fork".  There is no upstream repository holding bash-o4, otranspilerl
# or frontends/ — they exist ONLY in sh2loop, so this operation CARVES a
# release repo out of one repo's history (git filter-repo --path).  sh2perl is
# the only component with an upstream, and it is consumed as a submodule, not
# forked.  The distinction matters: a fork implies an upstream to diverge from,
# and for otranspilerl/frontends there is none.
#
# Plan: docs/O4-SPLIT-OFF-PLAN.md (topology, decisions, verification, rollback).
# Conventions mirror harness/migrate-frontends-to-sh2perl.sh: the script works
# ONLY in a scratch directory, never modifies the live trees, and never pushes
# without --push.
#
# WHY THE LAYOUT WORKS WITHOUT SOURCE EDITS
#   o4/{bash-o4,otranspilerl,sh2perl} keeps every path dependency valid:
#     bash-o4     -> ../otranspilerl, ../sh2perl
#     otranspilerl-> ../sh2perl
#   and bash-o4/build.rs hashes `..` + `../sh2perl`, i.e. the new repo's HEAD
#   and the submodule.  The only edits are the gate scripts' hardcoded ROOT.
#
# WHAT IT PRODUCES (in $WORK by default)
#   $WORK/o4/                 the assembled repository (branch `o4`)
#   $WORK/o4.git/             a local bare clone, for review (--bare)
#   $WORK/MOVE.md             provenance: base refs, sources, decisions
#   $WORK/commit-map          old->new SHAs (history mode only)
#   $WORK/human-decisions.txt decisions the script must not make
#   $WORK/extract/           the path-filtered history (history mode)
#
# SELF-TEST (what was actually exercised)
#   bash harness/split-off-o4.sh --workdir /tmp/o4split --snapshot
#   bash /tmp/o4split/o4/tests/release-check.sh
#   The full-history path is the default but is NOT exercised by --selftest
#   (git-filter-repo rewrites a 4.7 GB repository; review it separately).
#
# OPTIONS
#   --workdir DIR          scratch dir (default: mktemp -d); kept for review
#   --snapshot             one squashed "release snapshot" commit instead of
#                          path-filtered history (fast; no commit-map)
#   --sh2loop-ref REF      sh2loop base commit (default: live HEAD)
#   --sh2perl-ref REF      sh2perl base commit (default: the live gitlink SHA)
#   --sh2perl-remote URL   submodule remote (default: .gitmodules entry)
#   --sh2perl-src PATH     clone sh2perl from PATH (default: local submodule,
#                          which may carry commits not yet pushed)
#   --remote URL           set the new repo's `origin` to URL
#   --bare DIR             also create a local bare clone at DIR
#   --frontends-only       build ONLY the frontends repo ($FRONTENDS_NAME) and
#                          stop — push that first, then re-run for the -O4 repo
#   --frontends-remote URL submodule URL for the frontends repo (default: derived
#                          as <sh2perl-org>/$FRONTENDS_NAME on the same host)
#   --frontends-src PATH   clone the frontends repo from PATH (a local checkout
#                          you have already built) instead of splitting sh2loop
#   --frontends-name NAME  default: otranspiler-frontends
#   --drop-frontend-artifacts  exclude tracked build artifacts (*.d, *.o, *.rlib,
#                          *.rmeta, *.wasm, */target/*) from the frontends import
#                          — they are checked in upstream and their contents
#                          name the old workspace path
#   --vendor-frontend      fall back to a plain COPY of frontends/py-sh-go
#                          (deprecated: it goes stale; use the submodule)
#   --no-frontend          add no frontends at all; python-O4 then needs $PY_SH_GO
#   --name NAME            repository/dir name (default: o4)
#   --allow-dirty          proceed even if the extracted live paths are dirty
#   --gh-org ORG           owner used only in the *suggested* `gh repo create`
#                          line it prints (default: parsed from the submodule URL)
#   --allow-broken-ref     proceed even if a base REF is broken (committed merge
#                          conflict markers). The split-off is REF-based, so it cannot
#                          build from a broken ref however clean your worktree is.
#   --selftest             assemble, build and run tests/release-check.sh, report
#   --push                 push to origin (the ONLY live action)
#   -h|--help
set -euo pipefail

log()  { printf '\033[1m[split]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[split] WARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[split] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }
run()  { log "+ $*"; "$@"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK=""; SNAP=0; SH2LOOP_REF=""; SH2PERL_REF=""; SH2PERL_REMOTE=""; SH2PERL_SRC=""
NEW_REMOTE=""; BARE=""; WITH_FE=1; NAME="o4"; ALLOW_DIRTY=0; SELFTEST=0; PUSH=0
ALLOW_BROKEN=0; GH_ORG=""
FRONTENDS_NAME="otranspiler-frontends"   # decided: the frontends' own repo
FRONTENDS_REMOTE=""; FRONTENDS_SRC=""; FRONTENDS_ONLY=0; VENDOR_FE=0
DROP_FE_ART=0

while [ $# -gt 0 ]; do
  case "$1" in
    --workdir)         WORK="$2"; shift 2;;
    --snapshot)        SNAP=1; shift;;
    --sh2loop-ref)     SH2LOOP_REF="$2"; shift 2;;
    --sh2perl-ref)     SH2PERL_REF="$2"; shift 2;;
    --sh2perl-remote)  SH2PERL_REMOTE="$2"; shift 2;;
    --sh2perl-src)     SH2PERL_SRC="$2"; shift 2;;
    --remote)          NEW_REMOTE="$2"; shift 2;;
    --bare)            BARE="$2"; shift 2;;
    --frontends-only)  FRONTENDS_ONLY=1; shift;;
    --frontends-remote) FRONTENDS_REMOTE="$2"; shift 2;;
    --frontends-src)   FRONTENDS_SRC="$2"; shift 2;;
    --vendor-frontend) VENDOR_FE=1; shift;;
    --frontends-name)  FRONTENDS_NAME="$2"; shift 2;;
    --drop-frontend-artifacts) DROP_FE_ART=1; shift;;
    --no-frontend)     WITH_FE=0; shift;;
    --name)            NAME="$2"; shift 2;;
    --allow-dirty)     ALLOW_DIRTY=1; shift;;
    --allow-broken-ref) ALLOW_BROKEN=1; shift;;
    --gh-org)          GH_ORG="$2"; shift 2;;
    --selftest)        SELFTEST=1; shift;;
    --push)            PUSH=1; shift;;
    -h|--help)         sed -n '2,52p' "$0"; exit 0;;
    *) die "unknown flag $1 (try --help)";;
  esac
done

# Paths that become the split-off.  `bash-o4` carries its own bench corpus.
EXTRACT_PATHS=(bash-o4 otranspilerl)

# --------------------------------------------------------------- preflight
[ "$SNAP" -eq 0 ] && { command -v git-filter-repo >/dev/null \
  || die "git-filter-repo not found (use --snapshot, or install it)"; }
[ -d "$ROOT/sh2perl/.git" ] || [ -f "$ROOT/sh2perl/.git" ] \
  || die "$ROOT/sh2perl is not a git checkout (submodule not initialised?)"
[ -d "$ROOT/bash-o4" ] || die "$ROOT/bash-o4 not found"
[ -d "$ROOT/otranspilerl" ] || die "$ROOT/otranspilerl not found"
# The licence TEXT comes from sh2perl/LICENSE.GPL3.  sh2perl/LICENSE is a
# personal, relationship-keyed grant and is deliberately never copied.
[ -f "$ROOT/sh2perl/LICENSE.GPL3" ] \
  || die "$ROOT/sh2perl/LICENSE.GPL3 missing — this repo's licence text comes from there; refusing to invent one"

if [ -z "$SH2PERL_REMOTE" ]; then
  SH2PERL_REMOTE="$(git -C "$ROOT" config -f .gitmodules --get submodule.sh2perl.url 2>/dev/null || true)"
  [ -n "$SH2PERL_REMOTE" ] || die "cannot read submodule.sh2perl.url; pass --sh2perl-remote"
fi

if [ "$ALLOW_DIRTY" -eq 0 ]; then
  for p in "${EXTRACT_PATHS[@]}"; do
    if [ -n "$(git -C "$ROOT" status --porcelain -- "$p" | head -1)" ]; then
      git -C "$ROOT" status --short -- "$p" >&2
      die "live $p is dirty; commit it first (or --allow-dirty)"
    fi
  done
fi

[ -n "$WORK" ] || WORK="$(mktemp -d "${TMPDIR:-/tmp}/o4-split.XXXXXX")"
mkdir -p "$WORK"
DEST="$WORK/$NAME"

# Freeze the base: first run records the refs, reruns reuse them (a moving live
# HEAD must not half-rebase a resumed run).  Fresh --workdir to re-base.
BASE_FILE="$WORK/base.env"
if [ -f "$BASE_FILE" ]; then
  # shellcheck disable=SC1090
  . "$BASE_FILE"
  live_loop="$(git -C "$ROOT" rev-parse HEAD)"
  live_core="$(git -C "$ROOT/sh2perl" rev-parse HEAD)"
  [ "$live_loop" = "$SH2LOOP_REF" ] || warn "live sh2loop HEAD moved ($live_loop != recorded $SH2LOOP_REF); staying on the recorded base"
  [ "$live_core" = "$SH2PERL_REF" ] || warn "live sh2perl HEAD moved ($live_core != recorded $SH2PERL_REF); staying on the recorded base"
else
  [ -n "$SH2LOOP_REF" ] || SH2LOOP_REF="$(git -C "$ROOT" rev-parse HEAD)"
  # The gitlink is what sh2loop actually builds against, so it is the default.
  [ -n "$SH2PERL_REF" ] || SH2PERL_REF="$(git -C "$ROOT" ls-tree "$SH2LOOP_REF" sh2perl | awk '{print $3}')"
  [ -n "$SH2PERL_REF" ] || die "cannot read the sh2perl gitlink at $SH2LOOP_REF"
  printf 'SH2LOOP_REF=%q\nSH2PERL_REF=%q\n' "$SH2LOOP_REF" "$SH2PERL_REF" > "$BASE_FILE"
fi
if [ -n "$(git -C "$ROOT/sh2perl" status --porcelain | head -1)" ]; then
  warn "live sh2perl is dirty; the split-off is based on the pinned ref ($SH2PERL_REF), not your working tree."
  warn "commit + push sh2perl work first if it must be in the release."
fi

# A REF-based split-off cannot be rescued by a clean working tree, so check the refs
# themselves before spending time on the extraction.  Committed conflict markers
# are cheap to detect and are the failure mode actually seen in practice.
ref_integrity() { # repo ref label
  local repo="$1" ref="$2" label="$3" hits
  hits="$(git -C "$repo" grep -nE '^(<<<<<<<|>>>>>>>)' "$ref" -- '*.rs' '*.go' '*.c' '*.h' 2>/dev/null || true)"
  [ -z "$hits" ] && return 0
  printf '%s\n' "$hits" >&2
  warn "$label ref $ref has $(printf '%s\n' "$hits" | wc -l | tr -d ' ') committed merge-conflict marker(s) (above)"
  return 1
}
BROKEN_REFS=0
ref_integrity "$ROOT/sh2perl" "$SH2PERL_REF" sh2perl || BROKEN_REFS=1
ref_integrity "$ROOT" "$SH2LOOP_REF" sh2loop || BROKEN_REFS=1
if [ "$BROKEN_REFS" -eq 1 ]; then
  if [ -n "$(git -C "$ROOT/sh2perl" status --porcelain | head -1)" ]; then
    warn "your live sh2perl worktree is DIRTY, which is probably why local builds work:"
    warn "a ref-based split-off deliberately ignores uncommitted files. Commit the fix in"
    warn "sh2perl (then re-run), or pass --sh2perl-ref <a ref that builds>."
  fi
  [ "$ALLOW_BROKEN" -eq 1 ] || die "refusing to split off from a broken ref (use --allow-broken-ref to assemble anyway)"
fi
# This check is NOT exhaustive — it only sees committed conflict markers.  Three
# distinct breakages have been observed in this repo's gitlinks, and two of them
# are invisible here:
#   1. a committed `>>>>>>> <sha>` marker                (caught above)
#   2. unbalanced braces, e.g. a half-applied conflict   (needs a compile)
#   3. a call into a module deleted in the working tree  (needs a compile)
# `--selftest` is the definitive gate; a green preflight only means "not
# obviously broken".

log "live sh2loop : $ROOT"
log "sh2loop base : $SH2LOOP_REF"
log "sh2perl      : $SH2PERL_REMOTE @ $SH2PERL_REF"
log "work dir     : $WORK"
log "mode         : $([ "$SNAP" -eq 1 ] && echo 'snapshot (squashed)' || echo 'history (git filter-repo)')"

# --------------------------------------------------- 1. source (clone at ref)
SRC="$WORK/src"
if [ ! -d "$SRC" ]; then
  run git clone --quiet "$ROOT" "$SRC"
  run git -C "$SRC" checkout -q "$SH2LOOP_REF"
fi

# ------------------------------- 1b. the frontends' OWN repo (runs FIRST)
# The frontends must exist as a repo before the -O4 repo can submodule them, so
# `--frontends-only` stops here, before any assembly.
# --- the frontends live in their OWN repo ($FRONTENDS_NAME), consumed here as
# --- a submodule.  FACT: they are NOT in sh2perl (0 commits on any ref) and
# --- have no remote; sh2loop is their only home, so this split-off can also
# --- produce their repo.
FE_DEST="$WORK/$FRONTENDS_NAME"
if [ "$WITH_FE" -eq 1 ] && [ -z "$FRONTENDS_SRC" ] && [ ! -d "$FE_DEST" ]; then
  [ -d "$ROOT/frontends" ] || die "$ROOT/frontends not found (and no --frontends-src given)"
  if [ "$SNAP" -eq 0 ]; then
    FE_EX="$WORK/fe-extract"
    if [ ! -d "$FE_EX" ]; then
      run git clone --quiet "$SRC" "$FE_EX"
      run git -C "$FE_EX" filter-repo --force --path frontends/
      if [ "$DROP_FE_ART" -eq 1 ]; then
        # filter-repo has no --path-exclude: a second, inverted pass removes them
        run git -C "$FE_EX" filter-repo --force --invert-paths \
          --path-regex '^frontends/.*(/target/.*|[.](o|rlib|rmeta|wasm|d))$'
      fi
    fi
    run git init -q "$FE_DEST"
    run git -C "$FE_DEST" remote add extracted "$FE_EX"
    run git -C "$FE_DEST" fetch --quiet extracted "$(git -C "$FE_EX" rev-parse --abbrev-ref HEAD)"
    git -C "$FE_DEST" merge --allow-unrelated-histories --no-edit --no-stat \
      -m "Import frontends/ history from sh2loop ($SH2LOOP_REF)" FETCH_HEAD \
      || die "frontends graft conflicted; resolve in $FE_DEST"
  else
    run git init -q "$FE_DEST"
    # --strip-components=1 lands frontends/* AT the repo root.  (A `mv dir/*`
    # would silently skip dotfiles such as frontends/.gitignore.)
    excl=()
    [ "$DROP_FE_ART" -eq 1 ] && excl=(--exclude='*/target/*' --exclude='*.d' --exclude='*.o' \
                                      --exclude='*.rlib' --exclude='*.rmeta' --exclude='*.wasm')
    git -C "$SRC" archive "$SH2LOOP_REF" frontends \
      | tar -x -C "$FE_DEST" --strip-components=1 "${excl[@]+"${excl[@]}"}" \
      || die "frontends snapshot export failed"
  fi
  git -C "$FE_DEST" add -A
  git -C "$FE_DEST" -c user.email=split@local -c user.name=split \
      commit -q -m "$FRONTENDS_NAME: split out of sh2loop ($SH2LOOP_REF)" 2>/dev/null || true
  log "frontends repo built: $FE_DEST ($(git -C "$FE_DEST" rev-list --count HEAD) commits at $FE_DEST)"
fi
# Default the submodule URL by DERIVING it from two facts you gave: the
# sh2perl remote's host+owner, and the repo name.  Override with
# --frontends-remote.
if [ "$WITH_FE" -eq 1 ] && [ -z "$FRONTENDS_REMOTE" ]; then
  # bash parameter expansion, not sed: the replacement contains $ and escaped
  # parens that sed -E mangles ("unterminated s command").
  case "$SH2PERL_REMOTE" in
    */?*) FRONTENDS_REMOTE="${SH2PERL_REMOTE%/*}/${FRONTENDS_NAME}.git";;
    *)    FRONTENDS_REMOTE="";;
  esac
  [ "$FRONTENDS_REMOTE" = "$SH2PERL_REMOTE" ] && FRONTENDS_REMOTE=""
fi

if [ "$FRONTENDS_ONLY" -eq 1 ]; then
  [ -d "$FE_DEST" ] || die "--frontends-only needs a built frontends repo"
  log "--frontends-only: stopping.  Push it, then re-run for the -O4 repo:"
  log "  git -C $FE_DEST remote add origin $FRONTENDS_REMOTE"
  log "  git -C $FE_DEST push -u origin HEAD"
  exit 0
fi

[ "$FRONTENDS_ONLY" -eq 1 ] && exit 0

# --------------------------------------------------- 2. assemble the new repo
if [ ! -d "$DEST" ]; then
  if [ "$SNAP" -eq 0 ]; then
    # 2a. path-filtered history, then graft into a fresh repo.
    EXTRACT="$WORK/extract"
    if [ ! -d "$EXTRACT" ]; then
      run git clone --quiet "$SRC" "$EXTRACT"
      args=(); for p in "${EXTRACT_PATHS[@]}"; do args+=(--path "$p/"); done
      run git -C "$EXTRACT" filter-repo --force "${args[@]}"
    fi
    run git init -q "$DEST"
    run git -C "$DEST" remote add extracted "$EXTRACT"
    run git -C "$DEST" fetch --quiet extracted "$(git -C "$EXTRACT" rev-parse --abbrev-ref HEAD)"
    if ! git -C "$DEST" merge --allow-unrelated-histories --no-edit --no-stat \
          -m "Import -O4 driver history from sh2loop ($SH2LOOP_REF)" FETCH_HEAD; then
      die "merge conflicted; resolve in $DEST then rerun with the same --workdir"
    fi
    log "imported: $(git -C "$DEST" rev-list --count HEAD) commits ($(git -C "$DEST" rev-list --count HEAD -- bash-o4/ otranspilerl/) touch the extracted paths)"
  else
    # 2b. snapshot: export the paths from the frozen ref as a plain tree
    # (no history, no commit-map).  Ref-based, so it deliberately excludes
    # uncommitted work — which is what --allow-dirty acknowledges.
    run git init -q "$DEST"
    for p in "${EXTRACT_PATHS[@]}"; do
      git -C "$SRC" archive "$SH2LOOP_REF" "$p" | tar -x -C "$DEST" \
        || die "snapshot export of $p at $SH2LOOP_REF failed"
    done
    log "snapshot: exported ${EXTRACT_PATHS[*]} at $SH2LOOP_REF (no history; no commit-map)"
  fi
fi

# ------------------------------------------- 3. release docs, gates, frontend
mkdir -p "$DEST/docs" "$DEST/harness" "$DEST/tests"
copy_if_new() { # src rel
  [ -e "$DEST/$2" ] && return 0
  [ -e "$ROOT/$1" ] || { warn "missing $1"; return 0; }
  cp -a "$ROOT/$1" "$DEST/$2"
}
copy_if_new bash-o4/README.md      README.md
copy_if_new bash-o4/CHANGELOG.md   CHANGELOG.md
copy_if_new bash-o4/build.rs       bash-o4/build.rs
for d in BASH-O4.md BASH_VULKAN.md PYTHON-O4.md O4-SPLIT-OFF-PLAN.md; do copy_if_new "docs/$d" "docs/$d"; done
for h in c_gate_main.sh gpu_gate.sh; do copy_if_new "harness/$h" "harness/$h"; done
[ "$WITH_FE" -eq 1 ] && \
  ! git -C "$DEST" config -f .gitmodules --get submodule.frontends.url >/dev/null 2>&1 && {
  if [ "$VENDOR_FE" -eq 1 ]; then
    warn "--vendor-frontend: copying frontends/py-sh-go instead of using a submodule"
    warn "  this copy goes stale (the upstream is actively developed in sh2loop)"
    mkdir -p "$DEST/frontends"
    git -C "$ROOT" archive HEAD frontends/py-sh-go 2>/dev/null | tar -x -C "$DEST" || warn "frontends/py-sh-go export failed"
    [ -x "$ROOT/frontends/py-sh-go/py-sh-go" ] && cp -a "$ROOT/frontends/py-sh-go/py-sh-go" "$DEST/frontends/py-sh-go/py-sh-go"
    log "vendored frontends/py-sh-go (--vendor-frontend; will go stale)"
  else
    FE_SRC="${FRONTENDS_SRC:-$FE_DEST}"
    [ -d "$FE_SRC" ] || die "no frontends source ($FE_SRC); pass --frontends-src, build it with --frontends-only, or --vendor-frontend"
    run git -C "$DEST" -c protocol.file.allow=always submodule add --force "$FE_SRC" frontends
    [ -n "$FRONTENDS_REMOTE" ] && run git -C "$DEST" config -f .gitmodules "submodule.frontends.url" "$FRONTENDS_REMOTE"
    run git -C "$DEST/frontends" remote set-url origin "${FRONTENDS_REMOTE:-$FE_SRC}"
    log "submodule frontends -> $FRONTENDS_NAME @ $(git -C "$DEST/frontends" rev-parse --short HEAD)"
  fi
}

# The borrowed README was written from inside `bash-o4/`, but it now sits at
# the repository root, so say where things are.
if [ -f "$DEST/README.md" ] && ! grep -q '^## Repository layout' "$DEST/README.md"; then
  cat >> "$DEST/README.md" <<'LAY'

## Repository layout

This is the `-O4` release repository (see `MOVE.md` for provenance).  Paths
below the crate root are unchanged, so the quickstart commands above are run
from **`bash-o4/`**, not from here:

```
bash-o4/        the driver crate + its benchmark corpus   <- `cd bash-o4` first
otranspilerl/   the sh2perl CLI front end (a path dependency of bash-o4)
sh2perl/        GPL-3 core, pinned as a submodule
frontends/      SUBMODULE otranspiler-frontends (build: make -C frontends/py-sh-go)
docs/           BASH-O4.md, BASH_VULKAN.md, PYTHON-O4.md, O4-SPLIT-OFF-PLAN.md
harness/        the two gates (ROOT is derived from $0)
tests/          release-check.sh — the pre-tag verification
```

```sh
git submodule update --init        # once, after cloning
make -C frontends/py-sh-go         # REQUIRED for python-O4: the frontend binary is
                                   # gitignored upstream (build-on-test), so the
                                   # submodule ships source only
cd bash-o4 && cargo build --offline --bins
cd ../otranspilerl && cargo build --offline --bin otranspilerl-cli
cd ../sh2perl && bash runtime/build_uu_ffi.sh     # libcoreutils_ffi.so
cd .. && bash harness/c_gate_main.sh && bash harness/gpu_gate.sh
bash tests/release-check.sh        # all of the above, in one gate
```

### Three artifacts are BUILT, not tracked

Nothing is committed for these, so a fresh clone must build them before the gates
mean anything. Each one silently changes the gate result, so they are listed:

| step | without it |
|---|---|
| `cargo build --bin otranspilerl-cli` (in `otranspilerl/`) | `c_gate_main.sh` **SKIPs all 644 files** (`PASS=0 FAIL=0 SKIP=644`) — it shells out to that binary |
| `make -C frontends/py-sh-go` | `python-O4` reports "cannot locate the py-sh-go frontend"; its binary is gitignored upstream (build-on-test) |
| `bash sh2perl/runtime/build_uu_ffi.sh` | the gates link `runtime/lib/libcoreutils_ffi.so`; without it **30 examples fail** (`cpu=1`, all uu-ffi builtins: `test`, `uname`, `sleep`, …) |

`build_uu_ffi.sh` additionally needs an **out-of-tree** crate
(`/root/src/coreutils/uu-ffi`, overridable via `$UU_FFI_DIR`) with no pin
recorded in this repo — see `docs/O4-SPLIT-OFF-PLAN.md` §7, self-containment.
LAY
  log "README.md: appended a repository-layout section"
fi

# ------------------------------------------------- 4. sh2perl as a submodule
# Guard on THIS submodule's config entry, not on .gitmodules existing: the
# frontends submodule below creates .gitmodules first, which silently skipped
# sh2perl entirely.
if ! git -C "$DEST" config -f .gitmodules --get submodule.sh2perl.url >/dev/null 2>&1; then
  # Clone from the LOCAL submodule (it may carry gitlink-pinned commits not yet
  # pushed), then point origin at the real remote.
  run git -C "$DEST" -c protocol.file.allow=always submodule add --force \
      "${SH2PERL_SRC:-$ROOT/sh2perl}" sh2perl
  run git -C "$DEST" config -f .gitmodules "submodule.sh2perl.url" "$SH2PERL_REMOTE"
  run git -C "$DEST/sh2perl" remote set-url origin "$SH2PERL_REMOTE"
  run git -C "$DEST/sh2perl" checkout -q "$SH2PERL_REF"
  log "submodule sh2perl pinned at $SH2PERL_REF"
fi

# ------------------------------------------------------------- 5. licence
# GPL-3 ONLY, and specifically NOT `sh2perl/LICENSE`.
#
# The two files in sh2perl are not a pair to be copied together:
#   sh2perl/LICENSE       a PERSONAL grant: "GPL-3. ADDITIONALLY, recipients
#                         ... that I, John Christopher McCabe-Dansted, have
#                         sent or linked this software to during paid work
#                         ... may additionally distribute ... under
#                         Apache-2.0".  It is keyed to named relationships
#                         and specific recipients — it is not a general
#                         licence for the public, and it must not be
#                         republished as if it were this repo's licence.
#   sh2perl/LICENSE.GPL3  the GNU GPL v3 licence TEXT.  This is what a
#                         derived work is conveyed under.
# So: LICENSE.GPL3 -> LICENSE, verbatim, and sh2perl/LICENSE is copied
# nowhere.  Nothing is authored here (inventing licence text would be a legal
# claim, not a mechanical act).
if [ ! -f "$DEST/LICENSE" ]; then
  [ -f "$ROOT/sh2perl/LICENSE.GPL3" ] \
    || die "$ROOT/sh2perl/LICENSE.GPL3 missing — this repo's licence text comes from there; refusing to invent one"
  cp "$ROOT/sh2perl/LICENSE.GPL3" "$DEST/LICENSE"
  cp "$ROOT/sh2perl/LICENSE.GPL3" "$DEST/bash-o4/LICENSE"
  log "licence: LICENSE.GPL3 -> LICENSE (GPL-3 text), in the root and in bash-o4/"
fi
# Belt and braces: the personal grant must not have arrived by any other route
# (e.g. a hand copy).  Fail loudly, do not sanitise.
for f in "$DEST/LICENSE" "$DEST/bash-o4/LICENSE"; do
  [ -f "$f" ] || continue
  if grep -qiE 'ADDITIONALLY|McCabe-Dansted|Apache-2\.0' "$f"; then
    die "$f contains sh2perl's personal grant text; this repo must carry the GPL-3 text only"
  fi
done
# The Apache-2.0 text is deliberately NOT bundled: the additional permission it
# belonged to is not part of this repo's grant.
if ! grep -q '^license-file' "$DEST/bash-o4/Cargo.toml" 2>/dev/null; then
  perl -0pi -e 's/^(version = "[^"]+"\n)/$1license = "GPL-3.0-only"\nlicense-file = "LICENSE"\n/m' "$DEST/bash-o4/Cargo.toml" \
    || die "could not add license-file to bash-o4/Cargo.toml"
  # The source tree deliberately carries no licence key and explains why; in
  # this repo that question is settled, so replace the note rather than leave a
  # comment contradicting the key above it.
  python3 - "$DEST/bash-o4/Cargo.toml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(
    r"# NO `license` / `license-file` key yet, deliberately\..*?`license-file` pointing at a copy of `\.\./sh2perl/LICENSE`\)\.\n",
    "# Licence: GPL-3.0-only (see LICENSE, a verbatim copy of\n"
    "# sh2perl/LICENSE.GPL3).  sh2perl's separate LICENSE file is a PERSONAL\n"
    "# grant (GPL-3 plus an Apache-2.0 permission keyed to named paid-work\n"
    "# recipients) and is deliberately NOT copied here, so this repo's terms\n"
    "# are plain GPL-3 and the SPDX id is exact.\n",
    s, count=1, flags=re.S)
open(p, "w").write(s)
PY
  log "bash-o4/Cargo.toml: license-file = \"LICENSE\" (SPDX has no id for GPL-3 + extra permission)"
fi

# ------------------------------------------------------- 6. repath the gates
# The only source edits the split-off needs: both gates hardcode the workspace path.
for h in c_gate_main.sh gpu_gate.sh; do
  f="$DEST/harness/$h"
  [ -f "$f" ] || continue
  if grep -q '^ROOT=/home/llm/sh2loop' "$f"; then
    # NOT `perl -pi -e`: the replacement contains $( ) and $0, which perl
    # interpolates ($( = GID, $0 = program name), producing a mangled line.
    # python does a literal replacement.
    python3 - "$f" <<'PY'
import sys
p = sys.argv[1]
new = 'ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"'
lines = open(p).read().split('\n')
for i, l in enumerate(lines):
    if l == 'ROOT=/home/llm/sh2loop':
        lines[i] = new
open(p, 'w').write('\n'.join(lines))
PY
    log "harness/$h: ROOT is now \$0-relative"
  fi
done
# Prove no absolute workspace path survived in THIS repo's CODE.  Prose is
# excluded on purpose: MOVE.md and the plan are supposed to name where the
# tree came from, and this checker's own grep pattern contains the string.
# The submodules are other repos and are excluded too (the frontends tree
# TRACKS rustc `.d` files whose contents name the old path — reported below
# as its own finding, since that is an upstream wart, not a repathing miss).
CODE_GLOB=(-name '*.sh' -o -name '*.rs' -o -name '*.toml' -o -name '*.c' -o -name '*.h' -o -name Makefile)
stray="$(find "$DEST" "${CODE_GLOB[@]}" \
  -not -path "*/sh2perl/*" -not -path "*/frontends/*" -not -path "*/.git/*" \
  -not -name 'release-check.sh' -print0 2>/dev/null \
  | xargs -0 grep -l '/home/llm/sh2loop' 2>/dev/null || true)"
if [ -n "$stray" ]; then
  printf '%s\n' "$stray" >&2
  warn "absolute workspace paths still present in this repo's code (above)"
else
  log "no absolute workspace paths in this repo's code"
fi
fe_art="$(git -C "$DEST/frontends" ls-files 2>/dev/null \
  | grep -cE '(/target/.*|[.](o|rlib|rmeta|wasm)|\.d)$' || true)"
[ "${fe_art:-0}" -gt 0 ] && {
  warn "the $FRONTENDS_NAME tree TRACKS $fe_art generated artifact files (e.g."
  warn "coverage/**/target/*.d) whose CONTENTS name the old workspace path."
  warn "They are a pre-existing wart in frontends/; re-run with"
  warn "--drop-frontend-artifacts to exclude them from that repo's import."
}

# --------------------------------------------------- 7. provenance + decisions
if [ -f "$WORK/extract/.git/filter-repo/commit-map" ]; then
  cp "$WORK/extract/.git/filter-repo/commit-map" "$WORK/commit-map"
fi
{
  echo "# human decisions this script must not make (docs/O4-SPLIT-OFF-PLAN.md §3)"
  echo
  echo "D1 licence      : GPL-3 only. LICENSE is a verbatim copy of"
  echo "                  sh2perl/LICENSE.GPL3 (the GPL-3 TEXT).  sh2perl/LICENSE"
  echo "                  is a PERSONAL grant (GPL-3 + an additional Apache-2.0"
  echo "                  permission keyed to named paid-work recipients) and is"
  echo "                  deliberately NOT copied, here or anywhere.  Confirm the"
  echo "                  GPL-3-only distribution is intended (a legal call)."
  echo "D3 frontend     : frontends/py-sh-go is vendored$([ "$WITH_FE" -eq 1 ] && echo '' || echo ' (SKIPPED: --no-frontend)')."
  echo "                  FACT: it is NOT in sh2perl (0 commits on any ref) and has"
  echo "                  no remote of its own — sh2loop is its only home, and it"
  echo "                  is actively developed there, so this copy WILL go stale."
  echo "                  frontends/PROVENANCE records the exact source ref; the"
  echo "                  durable fix is to give frontends their own repo or move"
  echo "                  them into sh2perl (harness/migrate-frontends-to-sh2perl.sh"
  echo "                  is an UNAPPLIED proposal) and make it a submodule."
  echo "D4 remote       : ${NEW_REMOTE:-<none set — pass --remote URL>}"
  echo "D5 flow         : RELEASE MIRROR. Development stays in sh2loop;"
  echo "                  cut a release by re-running this script at a chosen ref."
  echo "                  Two-way edits would drift."
  echo "also open       : not cargo-publish-able (path deps); tcc is an unvendored"
  echo "                  runtime dependency. See CHANGELOG 'Open release decisions'."
} > "$WORK/human-decisions.txt"

if git -C "$DEST" diff --quiet && git -C "$DEST" diff --cached --quiet; then
  run git -C "$DEST" add -A
  run git -C "$DEST" commit -q -m "o4: assemble the -O4 release repo (sh2perl submodule @ ${SH2PERL_REF:0:9}, GPL-3)"
else
  run git -C "$DEST" add -A
  run git -C "$DEST" commit -q -m "o4: release-repo assembly (docs, gates, licence, submodule)"
fi
[ -n "$NEW_REMOTE" ] && run git -C "$DEST" remote add origin "$NEW_REMOTE" 2>/dev/null || true

cat > "$DEST/MOVE.md" <<EOF
# -O4 split-off provenance

- Extracted from \`$ROOT\` at \`$SH2LOOP_REF\`
  ($([ "$SNAP" -eq 1 ] && echo 'single squashed snapshot commit' || echo 'path-filtered history: \`git filter-repo --path bash-o4/ --path otranspilerl/\`')).
- Paths: \`$(printf '%s, ' "${EXTRACT_PATHS[@]}" | sed 's/, $//')\`.
- \`sh2perl\` submodule pinned at \`$SH2PERL_REF\` (from \`$SH2PERL_REMOTE\`);
  cloned from \`${SH2PERL_SRC:-$ROOT/sh2perl}\` so gitlink-only commits survive.
- Licence: **GPL-3 only**.  \`LICENSE\` (and \`bash-o4/LICENSE\`) is a verbatim
  copy of \`sh2perl/LICENSE.GPL3\`, the GPL-3 licence TEXT.  \`sh2perl/LICENSE\`
  is a personal grant (GPL-3 plus an additional Apache-2.0 permission keyed to
  named paid-work recipients and their subrecipients) and is deliberately
  **NOT copied** into this repo.  No licence text was authored by this script.
  \`bash-o4/Cargo.toml\` carries \`license = "GPL-3.0-only"\` + \`license-file\`."
- Source edits (all mechanical, all listed here; everything else is
  byte-identical to the source ref):
  1. \`harness/{c_gate_main.sh,gpu_gate.sh}\`: \`ROOT\` is \$0-relative.
  2. \`bash-o4/Cargo.toml\`: \`license-file = "LICENSE"\` added, and the note
     explaining why the source tree has no licence key replaced by the
     resolved one.
  3. \`README.md\`: a generated "Repository layout" section (its quickstart
     paths are relative to \`bash-o4/\`, not to this root).
$([ -f "$WORK/commit-map" ] && echo "- Rewritten SHAs: \`commit-map\` beside this file." || echo "- No commit-map (snapshot mode).")
- Layout rationale and decisions: \`docs/O4-SPLIT-OFF-PLAN.md\`.
EOF
log "wrote $DEST/MOVE.md (+ $WORK/human-decisions.txt)"

# --------------------------------------------------------- 8. self-verification
cat > "$DEST/tests/release-check.sh" <<'CHK'
#!/usr/bin/env bash
# release-check.sh — last gate before tagging a release. Run from the repo root.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRATE="$ROOT/bash-o4"          # the crates are not a single workspace root
pass=0; fail=0
ok()   { printf '  PASS %s\n' "$*"; pass=$((pass+1)); }
bad()  { printf '  FAIL %s\n' "$*"; fail=$((fail+1)); }

echo "== build (in bash-o4/) =="
if ( cd "$CRATE" && cargo build --offline --bins >/dev/null 2>&1 ); then
  ok "cargo build --bins"
else bad "cargo build --bins"; fi
for b in bash-O4 python-O4; do
  [ -x "$CRATE/target/debug/$b" ] && ok "$b built" || bad "$b missing"
done

echo "== prerequisites (built, not tracked) =="
CLI="$ROOT/otranspilerl/target/debug/otranspilerl-cli"
[ -x "$CLI" ] || ( cd "$ROOT/otranspilerl" && cargo build --offline --bin otranspilerl-cli >/dev/null 2>&1 ) || true
[ -x "$CLI" ] && ok "otranspilerl-cli built" \
  || bad "otranspilerl-cli missing (c_gate_main.sh SKIPs all 644 files without it)"

FE="$ROOT/frontends/py-sh-go/py-sh-go"
if [ ! -x "$FE" ] && [ -f "$ROOT/frontends/py-sh-go/Makefile" ]; then
  ( cd "$ROOT/frontends/py-sh-go" && make >/dev/null 2>&1 ) || true
fi
[ -x "$FE" ] && ok "py-sh-go frontend built" \
  || bad "py-sh-go missing (run: make -C frontends/py-sh-go)"

SO="$ROOT/sh2perl/runtime/lib/libcoreutils_ffi.so"
if [ ! -f "$SO" ] && [ -f "$ROOT/sh2perl/runtime/build_uu_ffi.sh" ]; then
  ( cd "$ROOT/sh2perl" && bash runtime/build_uu_ffi.sh >/dev/null 2>&1 ) || true
fi
[ -f "$SO" ] && ok "libcoreutils_ffi.so built" \
  || bad "libcoreutils_ffi.so missing — run sh2perl/runtime/build_uu_ffi.sh (needs an out-of-tree uu-ffi source; 30 examples fail without it)"

echo "== tests =="
t=$( cd "$CRATE" && cargo test --offline 2>&1 | grep -E '^test result' | awk '{p+=$4; f+=$6} END {print p+0" "f+0}')
set -- $t
[ "${2:-1}" = "0" ] && ok "cargo test (${1} passed)" || bad "cargo test (${1} passed, ${2} failed)"

echo "== warnings (bash-o4's own sources) =="
w=$( cd "$CRATE" && cargo build --offline --lib --message-format=short 2>&1 | grep -cE '^src/.*warning')
[ "$w" -le 1 ] && ok "warnings=$w (<=1 tolerated: vkffi dead field)" || bad "warnings=$w"

echo "== gate scripts (ROOT repath) =="
EXPECTED='ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"'
for g in c_gate_main.sh gpu_gate.sh; do
  f="$ROOT/harness/$g"
  [ -f "$f" ] || { bad "$g missing"; continue; }
  bash -n "$f" 2>/dev/null && ok "$g parses" || bad "$g has a syntax error"
  if grep -qxF "$EXPECTED" "$f"; then
    # Structural: the ROOT it computes must actually be this repo.
    got=$(bash -c 'cd "$(dirname "$0")" && ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; echo "$ROOT"' "$f")
    [ "$got" = "$ROOT" ] && ok "$g ROOT -> $got" || bad "$g ROOT -> $got (want $ROOT)"
  else
    bad "$g: unexpected ROOT line: $(grep -n '^ROOT=' "$f" | head -1)"
  fi
done

echo "== gates (from the repo root) =="
for g in c_gate_main.sh gpu_gate.sh; do
  out=$(cd "$ROOT" && bash "harness/$g" 2>&1 | tail -n 1)
  case "$out" in
    *FAIL=0*) ok "$g: $out";;
    *)        bad "$g: $out";;
  esac
done

echo "== transpiled-GPU contract =="
sh="$CRATE/bench/sh/squares-map.sh"
if [ -f "$sh" ]; then
  n=1000000
  want=$(bash "$sh" $n 2>/dev/null)
  got=$( (cd "$CRATE" && ./target/debug/bash-O4 --gpu --n $n "$sh") 2>/dev/null | awk '{print $2}')
  [ -n "$got" ] && [ "$got" = "$want" ] && ok "bash-O4 --gpu checksum $got == bash" \
    || bad "bash-O4 --gpu checksum '$got' != bash '$want'"
  (cd "$CRATE" && ./target/debug/bash-O4 --check "$sh") 2>/dev/null | grep -qE '^(MAP|RED|SEQ) candidate' \
    && ok "--check reports a CUDA candidate" || bad "--check reports no CUDA candidate"
else bad "bench corpus not found ($sh)"; fi

echo "== frontend (python-O4) =="
FE="$ROOT/frontends/py-sh-go/py-sh-go"
if [ -x "$FE" ]; then
  ok "frontends/py-sh-go built"
  # It must actually work, and be found WITHOUT env overrides (that is the
  # point of the submodule): run a real probe.
  probe=$( cd "$CRATE" && env -u PY_SH_GO ./target/debug/python-O4 --check \
             "$CRATE/bench/py/squares-map.py" 2>&1 )
  case "$probe" in
    *"MAP candidate"*) ok "python-O4 resolves the submodule frontend (no \$PY_SH_GO)";;
    *"cannot locate"*) bad "python-O4 cannot resolve the frontend: $(printf '%s' "$probe" | head -1)";;
    *)                 bad "unexpected python-O4 --check output: $(printf '%s' "$probe" | head -1)";;
  esac
elif [ -n "${PY_SH_GO:-}" ] && [ -x "${PY_SH_GO:-}" ]; then
  ok "PY_SH_GO=$PY_SH_GO (no vendored/submodule frontend)"
else
  bad "no py-sh-go frontend: run \`make -C frontends/py-sh-go\` or set \$PY_SH_GO"
fi

echo "== licence (GPL-3 text ONLY; the personal grant must NOT be here) =="
for f in LICENSE bash-o4/LICENSE; do
  if [ -s "$ROOT/$f" ]; then
    ok "$f present"
    grep -q "GNU GENERAL PUBLIC LICENSE" "$ROOT/$f" \
      && ok "$f is the GPL-3 text" || bad "$f is not the GPL text"
    if grep -qiE 'ADDITIONALLY|McCabe-Dansted|Apache-2\.0' "$ROOT/$f"; then
      bad "$f contains sh2perl/LICENSE's personal grant — it must not be copied"
    else
      ok "$f carries no personal-grant wording"
    fi
  else
    bad "$f missing"
  fi
done
# The GPL text lives IN LICENSE; a separate LICENSE.GPL3 is not expected.
[ -e "$ROOT/LICENSE.GPL3" ] && ok "LICENSE.GPL3 also present (harmless)" \
  || ok "no LICENSE.GPL3 (the text is LICENSE)"
grep -q 'license = "GPL-3' "$ROOT/bash-o4/Cargo.toml" 2>/dev/null \
  && ok "Cargo.toml declares the GPL-3.0-only SPDX id" \
  || bad "Cargo.toml lacks a GPL-3 SPDX id"

echo "== portability =="
# Code only: MOVE.md / the plan legitimately name the source path, and this
# script's own pattern contains it.  Both submodules are other repos.
s=$(find . \( -name '*.sh' -o -name '*.rs' -o -name '*.toml' -o -name Makefile \) \
      -not -path './sh2perl/*' -not -path './frontends/*' -not -path './.git/*' \
      -not -name 'release-check.sh' -print0 2>/dev/null \
    | xargs -0 grep -l '/home/llm/sh2loop' 2>/dev/null | head -5)
[ -z "$s" ] && ok "no absolute workspace paths in code" || bad "absolute paths: $s"

echo "== submodule =="
git submodule status sh2perl | grep -q '^-' && bad "sh2perl submodule not initialised" \
  || ok "sh2perl $(git submodule status sh2perl | awk '{print substr($1,1,9)}')"

echo
echo "release-check: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
CHK
chmod +x "$DEST/tests/release-check.sh"

# ------------------------------------------------------------- 9. bare + push
if [ -n "$BARE" ]; then
  [ -d "$BARE" ] || run git clone --quiet --bare "$DEST" "$BARE"
  log "bare review clone: $BARE"
fi

SELFTEST_OK=1
if [ "$SELFTEST" -eq 1 ]; then
  log "--selftest: running tests/release-check.sh in $DEST"
  if ! ( cd "$DEST" && bash tests/release-check.sh ); then
    SELFTEST_OK=0
    warn "--selftest FAILED — this repo is not releasable as assembled"
    [ "$BROKEN_REFS" -eq 1 ] && warn "cause: a base ref is broken (see the preflight report above)"
  fi
fi

if [ "$PUSH" -eq 1 ]; then
  [ -n "$NEW_REMOTE" ] || die "--push needs --remote URL"
  [ "$SELFTEST_OK" -eq 1 ] || die "refusing to push an unverified repo (--selftest failed)"
  run git -C "$DEST" push -u origin HEAD
  log "pushed to $NEW_REMOTE"
else
  log "not pushed (use --push --remote URL after review)"
fi

if [ "$SELFTEST" -eq 0 ]; then
  warn "not verified: run \`bash $DEST/tests/release-check.sh\` before tagging"
elif [ "$SELFTEST_OK" -eq 1 ]; then
  log "verified: release-check passed"
else
  warn "VERIFICATION FAILED — do not tag this as a release"
fi
[ "$BROKEN_REFS" -eq 1 ] && warn "base ref(s) broken: fix sh2perl, bump the gitlink, and re-run the split-off"

# The script never creates or infers a repository: `--name` is a LOCAL directory
# name and `--remote` is explicit, because a wrong URL pushed once is a mess.
# It does print a *suggestion*, with the owner taken from the submodule URL.
if [ -z "$GH_ORG" ]; then
  GH_ORG="$(printf '%s' "$SH2PERL_REMOTE" \
    | sed -nE 's#^(git@|https?://|ssh://git@)?[^/:]+[:/]([^/]+)/.*#\2#p')"
fi
REPO_SPEC=""
if [ -n "$GH_ORG" ]; then
  REPO_SPEC="$GH_ORG/$NAME"
  log "no repository was created or named by this script."
  log "suggested (NOT executed; review the licence terms first):"
  log "  gh repo create $REPO_SPEC --private \\"
  log "     --description 'the -O4 driver family for sh2perl (GPL-3)'"
  log "  then: bash harness/split-off-o4.sh --workdir $WORK --remote git@github.com:$REPO_SPEC.git --push"
else
  warn "could not parse an owner from $SH2PERL_REMOTE; pass --gh-org ORG for the suggestion"
fi

cat <<EOF

next steps
  1. review layout  : git -C $DEST log --oneline | head
                      git -C $DEST ls-files | head -40
  2. read the asks  : cat $WORK/human-decisions.txt
  3. verify         : bash $DEST/tests/release-check.sh
  4. create the remote (${REPO_SPEC:-<choose an owner/repo>}), then:
                      bash harness/split-off-o4.sh --workdir $WORK --remote <url> --push
  5. tag the release in the new repo (this repo mirrors $SH2LOOP_REF).
EOF
