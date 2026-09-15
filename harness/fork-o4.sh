#!/usr/bin/env bash
# fork-o4.sh — fork the -O4 driver family (bash-o4 + otranspilerl) out of the
# sh2loop development workspace into its own GPL-3 repository, with sh2perl as
# a pinned submodule.
#
# Plan: docs/O4-FORK-PLAN.md (topology, decisions, verification, rollback).
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
#   bash harness/fork-o4.sh --workdir /tmp/o4fork --snapshot
#   bash /tmp/o4fork/o4/tests/fork-check.sh
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
#   --no-frontend          do not vendor frontends/py-sh-go (python-O4 then
#                          needs $PY_SH_GO or a sh2perl that carries it)
#   --name NAME            repository/dir name (default: o4)
#   --allow-dirty          proceed even if the extracted live paths are dirty
#   --allow-broken-ref     proceed even if a base REF is broken (committed merge
#                          conflict markers). The fork is REF-based, so it cannot
#                          build from a broken ref however clean your worktree is.
#   --selftest             assemble, build and run tests/fork-check.sh, report
#   --push                 push to origin (the ONLY live action)
#   -h|--help
set -euo pipefail

log()  { printf '\033[1m[fork]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[fork] WARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[fork] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }
run()  { log "+ $*"; "$@"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK=""; SNAP=0; SH2LOOP_REF=""; SH2PERL_REF=""; SH2PERL_REMOTE=""; SH2PERL_SRC=""
NEW_REMOTE=""; BARE=""; WITH_FE=1; NAME="o4"; ALLOW_DIRTY=0; SELFTEST=0; PUSH=0
ALLOW_BROKEN=0

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
    --no-frontend)     WITH_FE=0; shift;;
    --name)            NAME="$2"; shift 2;;
    --allow-dirty)     ALLOW_DIRTY=1; shift;;
    --allow-broken-ref) ALLOW_BROKEN=1; shift;;
    --selftest)        SELFTEST=1; shift;;
    --push)            PUSH=1; shift;;
    -h|--help)         sed -n '2,52p' "$0"; exit 0;;
    *) die "unknown flag $1 (try --help)";;
  esac
done

# Paths that become the fork.  `bash-o4` carries its own bench corpus.
EXTRACT_PATHS=(bash-o4 otranspilerl)

# --------------------------------------------------------------- preflight
[ "$SNAP" -eq 0 ] && { command -v git-filter-repo >/dev/null \
  || die "git-filter-repo not found (use --snapshot, or install it)"; }
[ -d "$ROOT/sh2perl/.git" ] || [ -f "$ROOT/sh2perl/.git" ] \
  || die "$ROOT/sh2perl is not a git checkout (submodule not initialised?)"
[ -d "$ROOT/bash-o4" ] || die "$ROOT/bash-o4 not found"
[ -d "$ROOT/otranspilerl" ] || die "$ROOT/otranspilerl not found"
[ -f "$ROOT/sh2perl/LICENSE" ] \
  || die "$ROOT/sh2perl/LICENSE missing — the fork's licence is a verbatim copy of it; refusing to invent one"

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

[ -n "$WORK" ] || WORK="$(mktemp -d "${TMPDIR:-/tmp}/o4-fork.XXXXXX")"
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
  warn "live sh2perl is dirty; the fork is based on the pinned ref ($SH2PERL_REF), not your working tree."
  warn "commit + push sh2perl work first if it must be in the release."
fi

# A REF-based fork cannot be rescued by a clean working tree, so check the refs
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
    warn "a ref-based fork deliberately ignores uncommitted files. Commit the fix in"
    warn "sh2perl (then re-run), or pass --sh2perl-ref <a ref that builds>."
  fi
  [ "$ALLOW_BROKEN" -eq 1 ] || die "refusing to fork a broken ref (use --allow-broken-ref to assemble anyway)"
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
for d in BASH-O4.md BASH_VULKAN.md PYTHON-O4.md O4-FORK-PLAN.md; do copy_if_new "docs/$d" "docs/$d"; done
for h in c_gate_main.sh gpu_gate.sh; do copy_if_new "harness/$h" "harness/$h"; done
[ "$WITH_FE" -eq 1 ] && [ ! -e "$DEST/frontends/py-sh-go" ] && {
  mkdir -p "$DEST/frontends"
  # Tracked files + the built binary if present (python-O4 needs it at runtime).
  git -C "$ROOT" archive HEAD frontends/py-sh-go 2>/dev/null | tar -x -C "$DEST" || warn "frontends/py-sh-go export failed"
  [ -x "$ROOT/frontends/py-sh-go/py-sh-go" ] && {
    mkdir -p "$DEST/frontends/py-sh-go"
    cp -a "$ROOT/frontends/py-sh-go/py-sh-go" "$DEST/frontends/py-sh-go/py-sh-go"
  }
  log "vendored frontends/py-sh-go (decision D3; sh2perl's frontends migration will supersede it)"
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
frontends/      py-sh-go, used by python-O4
docs/           BASH-O4.md, BASH_VULKAN.md, PYTHON-O4.md, O4-FORK-PLAN.md
harness/        the two gates (ROOT is derived from $0)
tests/          fork-check.sh — the pre-tag verification
```

```sh
git submodule update --init        # once, after cloning
cd bash-o4 && cargo build --offline --bins
cd .. && bash harness/c_gate_main.sh && bash harness/gpu_gate.sh
bash tests/fork-check.sh           # all of the above, in one gate
```
LAY
  log "README.md: appended a repository-layout section"
fi

# ------------------------------------------------- 4. sh2perl as a submodule
if [ ! -e "$DEST/.gitmodules" ]; then
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
if [ ! -f "$DEST/LICENSE" ]; then
  # Verbatim copy: the fork is a derivative of the GPL-3 core, so it carries
  # the SAME terms (GPL-3 + sh2perl's additional Apache-2.0 permission).
  # Nothing is authored here — inventing licence text would be a legal claim.
  cp "$ROOT/sh2perl/LICENSE" "$DEST/LICENSE"
  cp "$ROOT/sh2perl/LICENSE" "$DEST/bash-o4/LICENSE"
  log "licence: verbatim copy of sh2perl/LICENSE -> LICENSE and bash-o4/LICENSE"
fi
if ! grep -q '^license-file' "$DEST/bash-o4/Cargo.toml" 2>/dev/null; then
  perl -0pi -e 's/^(version = "[^"]+"\n)/$1license-file = "LICENSE"\n/m' "$DEST/bash-o4/Cargo.toml" \
    || die "could not add license-file to bash-o4/Cargo.toml"
  # The source tree deliberately carries no licence key and explains why; in
  # the fork that question is settled, so replace the note rather than leave a
  # comment contradicting the key above it.
  python3 - "$DEST/bash-o4/Cargo.toml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(
    r"# NO `license` / `license-file` key yet, deliberately\..*?`license-file` pointing at a copy of `\.\./sh2perl/LICENSE`\)\.\n",
    "# Licence: GPL-3 (see LICENSE, copied verbatim from sh2perl).  sh2perl's\n"
    "# terms are GPL-3 PLUS an additional Apache-2.0 permission for named\n"
    "# paid-work recipients and their subrecipients, which has no single SPDX\n"
    "# id -- hence `license-file` rather than `license`.\n",
    s, count=1, flags=re.S)
open(p, "w").write(s)
PY
  log "bash-o4/Cargo.toml: license-file = \"LICENSE\" (SPDX has no id for GPL-3 + extra permission)"
fi

# ------------------------------------------------------- 6. repath the gates
# The only source edits the fork needs: both gates hardcode the workspace path.
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
# Prove no absolute workspace path survived anywhere in the tree.
stray="$(grep -rIl '/home/llm/sh2loop' "$DEST" 2>/dev/null | grep -v '^'"$DEST"'/sh2perl/' | grep -v '\.git/' || true)"
[ -n "$stray" ] && { printf '%s\n' "$stray" >&2; warn "absolute workspace paths still present (above)"; } \
  || log "no absolute workspace paths remain (outside the sh2perl submodule)"

# --------------------------------------------------- 7. provenance + decisions
if [ -f "$WORK/extract/.git/filter-repo/commit-map" ]; then
  cp "$WORK/extract/.git/filter-repo/commit-map" "$WORK/commit-map"
fi
{
  echo "# human decisions the fork must not make (docs/O4-FORK-PLAN.md §3)"
  echo
  echo "D1 licence      : copied verbatim from sh2perl/LICENSE. Confirm it is the"
  echo "                  intended distribution (a legal call, not mechanical)."
  echo "D3 frontend     : frontends/py-sh-go is vendored$([ "$WITH_FE" -eq 1 ] && echo '' || echo ' (SKIPPED: --no-frontend)')."
  echo "                  Once the frontends->sh2perl migration lands, point at"
  echo "                  sh2perl/frontends/ and drop the vendored copy."
  echo "D4 remote       : ${NEW_REMOTE:-<none set — pass --remote URL>}"
  echo "D5 flow         : fork is a RELEASE MIRROR. Development stays in sh2loop;"
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
# -O4 fork provenance

- Extracted from \`$ROOT\` at \`$SH2LOOP_REF\`
  ($([ "$SNAP" -eq 1 ] && echo 'single squashed snapshot commit' || echo 'path-filtered history: \`git filter-repo --path bash-o4/ --path otranspilerl/\`')).
- Paths: \`$(printf '%s, ' "${EXTRACT_PATHS[@]}" | sed 's/, $//')\`.
- \`sh2perl\` submodule pinned at \`$SH2PERL_REF\` (from \`$SH2PERL_REMOTE\`);
  cloned from \`${SH2PERL_SRC:-$ROOT/sh2perl}\` so gitlink-only commits survive.
- Licence: verbatim copy of \`sh2perl/LICENSE\` (GPL-3 + additional Apache-2.0
  permission). No licence text was authored by this script.
- Source edits (all mechanical, all listed here; everything else is
  byte-identical to the source ref):
  1. \`harness/{c_gate_main.sh,gpu_gate.sh}\`: \`ROOT\` is \$0-relative.
  2. \`bash-o4/Cargo.toml\`: \`license-file = "LICENSE"\` added, and the note
     explaining why the source tree has no licence key replaced by the
     resolved one.
  3. \`README.md\`: a generated "Repository layout" section (its quickstart
     paths are relative to \`bash-o4/\`, not to this root).
$([ -f "$WORK/commit-map" ] && echo "- Rewritten SHAs: \`commit-map\` beside this file." || echo "- No commit-map (snapshot mode).")
- Layout rationale and decisions: \`docs/O4-FORK-PLAN.md\`.
EOF
log "wrote $DEST/MOVE.md (+ $WORK/human-decisions.txt)"

# --------------------------------------------------------- 8. self-verification
cat > "$DEST/tests/fork-check.sh" <<'CHK'
#!/usr/bin/env bash
# fork-check.sh — last gate before tagging a release. Run from the repo root.
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
if [ -x "$ROOT/frontends/py-sh-go/py-sh-go" ]; then
  ok "frontends/py-sh-go present"
elif [ -n "${PY_SH_GO:-}" ] && [ -x "${PY_SH_GO:-}" ]; then
  ok "PY_SH_GO=$PY_SH_GO"
else
  bad "no py-sh-go frontend (python-O4 would refuse; see MOVE.md decision D3)"
fi

echo "== portability =="
s=$(grep -rIl '/home/llm/sh2loop' . 2>/dev/null | grep -v '^\./sh2perl/' | grep -v '/\.git/' | head -5)
[ -z "$s" ] && ok "no absolute workspace paths" || bad "absolute paths: $s"

echo "== submodule =="
git submodule status sh2perl | grep -q '^-' && bad "sh2perl submodule not initialised" \
  || ok "sh2perl $(git submodule status sh2perl | awk '{print substr($1,1,9)}')"

echo
echo "fork-check: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
CHK
chmod +x "$DEST/tests/fork-check.sh"

# ------------------------------------------------------------- 9. bare + push
if [ -n "$BARE" ]; then
  [ -d "$BARE" ] || run git clone --quiet --bare "$DEST" "$BARE"
  log "bare review clone: $BARE"
fi

SELFTEST_OK=1
if [ "$SELFTEST" -eq 1 ]; then
  log "--selftest: running tests/fork-check.sh in $DEST"
  if ! ( cd "$DEST" && bash tests/fork-check.sh ); then
    SELFTEST_OK=0
    warn "--selftest FAILED — this fork is not releasable as assembled"
    [ "$BROKEN_REFS" -eq 1 ] && warn "cause: a base ref is broken (see the preflight report above)"
  fi
fi

if [ "$PUSH" -eq 1 ]; then
  [ -n "$NEW_REMOTE" ] || die "--push needs --remote URL"
  [ "$SELFTEST_OK" -eq 1 ] || die "refusing to push an unverified fork (--selftest failed)"
  run git -C "$DEST" push -u origin HEAD
  log "pushed to $NEW_REMOTE"
else
  log "not pushed (use --push --remote URL after review)"
fi

if [ "$SELFTEST" -eq 0 ]; then
  warn "not verified: run \`bash $DEST/tests/fork-check.sh\` before tagging"
elif [ "$SELFTEST_OK" -eq 1 ]; then
  log "verified: fork-check passed"
else
  warn "VERIFICATION FAILED — do not tag this as a release"
fi
[ "$BROKEN_REFS" -eq 1 ] && warn "base ref(s) broken: fix sh2perl, bump the gitlink, and re-fork"

cat <<EOF

next steps
  1. review layout  : git -C $DEST log --oneline | head
                      git -C $DEST ls-files | head -40
  2. read the asks  : cat $WORK/human-decisions.txt
  3. verify         : bash $DEST/tests/fork-check.sh
  4. create the remote, then:
                      bash harness/fork-o4.sh --workdir $WORK --remote <url> --push
  5. tag the release in the new repo (the fork is a mirror of $SH2LOOP_REF).
EOF
