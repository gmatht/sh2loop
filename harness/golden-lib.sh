#!/bin/bash
# harness/golden-lib.sh — shared plumbing for the golden render record.
#
# A "set" is one backend's render of the corpus, stamped with the exact
# renderer identity that produced it (see render.json in golden-render.sh).
# Sets live in $SH2_GOLDEN_REPO/sets/; while the repo has no remote the
# default is the ignored .golden-inbox/ in the workspace.
#
# Everything here is read-only with respect to the corpus and the worktrees:
# it runs `git -C` queries and sha256sums, never a checkout, never a stash.
set -u


gl_die() { printf 'golden: %s\n' "$*" >&2; exit 2; }
gl_log() { printf 'golden: %s\n' "$*" >&2; }

# workspace root (the repo that carries the sh2perl gitlink)
gl_workspace() {
  local d
  for d in "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" "$PWD"; do
    if git -C "$d" rev-parse --git-dir >/dev/null 2>&1 && [ -e "$d/sh2perl/Cargo.toml" ]; then
      printf '%s\n' "$d"; return 0
    fi
  done
  return 1
}

# Map a backend name (or alias: rs=rust, pl=perl, py=python, js=estree) to
# its worktree directory name. Worktrees are backends/<lang> on branch
# backend/<lang>; the alias keeps "rs" (the CLI's --target) working.
gl_lang() {
  case "$1" in rs|rust) echo rust;; pl|perl) echo perl;; py|python) echo python;;
              js|estree) echo estree;; *) echo "$1";; esac
}

# worktree that owns a backend's renderer
gl_worktree() {   # <workspace> <backend>
  printf '%s/sh2perl/backends/%s\n' "$1" "$(gl_lang "$2")"
}

# The corpus a backend renders: its own worktree's examples/ (each worktree
# carries a per-branch snapshot) plus the workspace's frontend testdata.
gl_corpus_dir() {  # <workspace> <backend>
  local wt; wt="$(gl_worktree "$1" "$2")"
  if [ -d "$wt/examples" ]; then printf '%s\n' "$wt/examples"; else printf '%s/sh2perl/examples\n' "$1"; fi
}

# Renderer for a backend: the worktree's shir_render (what the gates use) when
# it exists, else the shared CLI. Echoes "<kind>\t<path>".
gl_renderer() {   # <workspace> <backend>
  local wt; wt="$(gl_worktree "$1" "$2")"
  if [ -x "$wt/target/debug/shir_render" ]; then
    printf 'shir_render\t%s\n' "$wt/target/debug/shir_render"; return 0
  fi
  local cli="$1/otranspilerl/target/debug/otranspilerl-cli"
  [ -x "$cli" ] || cli="$(command -v otranspilerl-cli 2>/dev/null)"
  [ -n "${cli:-}" ] && [ -x "$cli" ] && { printf 'cli\t%s\n' "$cli"; return 0; }
  return 1
}

# File extension of a backend's rendered artifact (informational only: the
# file name is <example>.<ext>, so a refactor's ext change is a visible diff).
gl_ext() {
  case "$1" in
    rs|rust) echo rs;; c) echo c;; go) echo go;; fish) echo fish;;
    perl|pl) echo pl;; py|python) echo py;; sh) echo sh;; zsh) echo zsh;;
    java) echo java;; zig) echo zig;; js|estree) echo json;;
    glsl|glslv) echo glsl;; lint) echo lint;; *) echo txt;;
  esac
}

# shir_render --target name for a backend
gl_target() {
  case "$1" in
    rust) echo rs;; python) echo py;; perl) echo pl;; estree|js) echo estree;;
    *) echo "$1";;
  esac
}

# Deterministic identity of a git worktree, one key=value per line. `dirty`
# counts TRACKED changes only: untracked scratch (pid files, caches) does not
# change what the compiler does, and counting it would mark every worktree
# dirty forever (the c worktree alone has 1300+ untracked entries).
gl_repo_identity() {  # <dir> <label>
  local d="$1" label="$2" sha branch ahead behind dirty base
  sha="$(git -C "$d" rev-parse HEAD 2>/dev/null || echo unknown)"
  branch="$(git -C "$d" branch --show-current 2>/dev/null || true)"
  [ -n "$branch" ] || branch="$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"
  if git -C "$d" rev-parse --verify -q main >/dev/null 2>&1; then
    base=main
  elif git -C "$d" rev-parse --verify -q origin/main >/dev/null 2>&1; then
    base=origin/main
  else
    base=""
  fi
  ahead=0; behind=0
  if [ -n "$base" ]; then
    ahead="$(git -C "$d" rev-list --count "$base..HEAD" 2>/dev/null || echo '?')"
    behind="$(git -C "$d" rev-list --count "HEAD..$base" 2>/dev/null || echo '?')"
  fi
  dirty="$(git -C "$d" status --porcelain --untracked-files=no 2>/dev/null | wc -l)"
  printf '%s_sha=%s\n' "$label" "$sha"
  printf '%s_branch=%s\n' "$label" "$branch"
  printf '%s_base=%s\n' "$label" "$base"
  printf '%s_ahead=%s\n' "$label" "$ahead"
  printf '%s_behind=%s\n' "$label" "$behind"
  printf '%s_dirty=%s\n' "$label" "$dirty"
}

gl_sha256_file() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

# Deterministic hash of a corpus directory: relative name + content, sorted.
gl_corpus_sha() {   # <dir>
  ( cd "$1" && ls -1 -- *.sh 2>/dev/null | LC_ALL=C sort | while read -r f; do
      printf '%s  %s\n' "$(sha256sum "$f" | awk '{print $1}')" "$f"
    done ) | sha256sum | awk '{print $1}'
}

# json-escape a string (paths, branch names)
gl_json_str() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
