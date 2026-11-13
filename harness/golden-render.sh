#!/bin/bash
# harness/golden-render.sh — render the corpus for one backend into a stamped
# "set" in the golden record (the archive of what the transpiler emits).
#
# WHY: the behaviour gates compare program OUTPUT, so a lowering can change
# every render it touches and still pass. This keeps the rendered text, with
# the exact renderer identity that produced it, so a change is a reviewable
# diff and "which sh2perl made this render?" has an answer in the tree.
#
# Usage:
#   harness/golden-render.sh --backend rs            one backend
#   harness/golden-render.sh --all --jobs 4          every backend with a renderer
#   harness/golden-render.sh --backend c --limit 20  smoke run
#   harness/golden-render.sh --backend c --dry-run   render + stamp, stage nothing
#
# Options:
#   --backend L[,L...]  backend(s), default rs
#   --all               every sh2perl/backends/* with a renderer
#   --jobs N            parallel renders (default 1; sets are independent)
#   --limit N           first N examples only (smoke runs)
#   --out DIR           override the set directory
#   --stamp-only        do not render; write the stamp from an existing --out
#   --dry-run           render into a temp dir and print the stamp, write nothing
#   --force             overwrite an existing set directory
#   --no-inbox-init     do not create the git repo in .golden-inbox/
#
# The record root is $SH2_GOLDEN_REPO, else the ignored .golden-inbox/ in the
# workspace (so nothing lands in a tracked path until a real repo exists).
#
# Set layout (one directory per render round):
#   sets/<utc-stamp>-<sh2perl-sha7>-<backend>/
#     render.json      the stamp: renderer identity, corpus identity, outcomes
#     MANIFEST.tsv     name<TAB>sha256<TAB>bytes<TAB>status
#     renders/<example>.<ext>        (status=rendered)
#     renders/<example>.<ext>.refused (status=refused; first diagnostic line)
#     renders/<example>.<ext>.error   (status=error; first stderr line)
#     patches/*.patch  (only when the worktree had tracked changes)
#
# Determinism: every render is done TWICE into two temp dirs and compared;
# a mismatch marks the set unstable=1 and the differing files are listed in
# determinism.diff. An unstable set is still written (it is evidence) but must
# not be blessed. Re-rendering with an unchanged binary must leave the record's
# tree clean — a render that churns without a code change is a determinism bug.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=golden-lib.sh
. "$HERE/golden-lib.sh"

WS="$(gl_workspace)" || gl_die "cannot find the workspace (a repo with sh2perl/Cargo.toml)"

# defaults (also read by the record-root block on the main path)
BACKENDS=(); JOBS=1; LIMIT=0; OUT=""; DRY=0; FORCE=0; STAMP_ONLY=0; INIT_INBOX=1

INBOX="$WS/.golden-inbox"
ROOT="${SH2_GOLDEN_REPO:-$INBOX}"

# ── record root ──────────────────────────────────────────────────────────
if [ "$DRY" = 0 ] && [ "$ROOT" = "$INBOX" ] && [ "$INIT_INBOX" = 1 ] && [ ! -d "$INBOX/.git" ]; then
  mkdir -p "$INBOX"
  git -C "$INBOX" init -q -b main .
  printf '# golden render record (machine state; see harness/golden-render.sh)\n' > "$INBOX/.gitignore"
  gl_log "initialised record repo at $INBOX"
fi

# tracked-change patch of a worktree (a worker's WIP is the normal case; the
# stamp must be enough to reproduce the render after the worktree moves on)
save_patch() {   # <worktree> <dest-dir>
  local wt="$1" dest="$2" n
  mkdir -p "$dest"
  n="$(git -C "$wt" status --porcelain --untracked-files=no | wc -l)"
  [ "$n" -gt 0 ] || return 0
  git -C "$wt" diff HEAD --binary > "$dest/tracked.patch" 2>/dev/null || true
  gl_log "saved tracked.patch ($n files) from $(basename "$wt")"
}

render_one() {   # <kind> <renderer> <target> <example> <destdir>  -> prints status
  local kind="$1" bin="$2" target="$3" ex="$4" dest="$5"
  local base ext out err rc first
  base="$(basename "$ex" .sh)"; ext="$(gl_ext "$(gl_lang "$target")")"
  out="$dest/$base.$ext"; err="$dest/.$base.err"
  if [ "$kind" = shir_render ]; then
    # shir_render consumes A1 shIR JSON: produce it with the shared CLI.
    local shir="$dest/.$base.shir.json"
    if ! "$CLI" "$ex" --shir >"$shir" 2>"$err"; then
      first="$(head -1 "$err")"; printf '%s\trefused\t%s\n' "$base" "$first" > "$dest/.$base.res"
      rm -f "$shir"; return 0
    fi
    if ! "$bin" --target="$target" <"$shir" >"$out" 2>"$err"; then
      first="$(head -1 "$err")"; printf '%s\terror\t%s\n' "$base" "$first" > "$dest/.$base.res"
      rm -f "$out" "$shir"; return 0
    fi
    rm -f "$shir"
  else
    if ! "$bin" "$ex" --target "$target" >"$out" 2>"$err"; then
      first="$(head -1 "$err")"; printf '%s\trefused\t%s\n' "$base" "$first" > "$dest/.$base.res"
      rm -f "$out"; return 0
    fi
  fi
  [ -s "$out" ] || { first="$(head -1 "$err")"; printf '%s\terror\t%s\n' "$base" "empty render: $first" > "$dest/.$base.res"; return 0; }
  first=""; printf '%s\trendered\t\n' "$base" > "$dest/.$base.res"
  rm -f "$err"
}

# Render one backend into <setdir>/renders. Echoes a one-line summary.
do_backend() {   # <backend> <setdir> <corpusdir>
  local b="$1" setdir="$2" corpus="$3"
  local kind bin target ext dest="$setdir/renders"
  IFS=$'\t' read -r kind bin < <(gl_renderer "$WS" "$b") || gl_die "no renderer for backend $b"
  target="$(gl_target "$b")"; ext="$(gl_ext "$b")"
  mkdir -p "$dest"
  local -a files=(); while IFS= read -r f; do files+=("$f"); done < <(ls -1 -- "$corpus"/*.sh 2>/dev/null | LC_ALL=C sort)
  [ "$LIMIT" -gt 0 ] && files=("${files[@]:0:$LIMIT}")
  # Per-file rendering happens in a fresh `bash` that sources this script with
  # GL_SOURCE_ONLY=1 (it then stops right before option parsing) — one
  # definition of render_one, no second script to keep in sync.
  printf '%s\n' "${files[@]}" | xargs -r -P "$JOBS" -I{} \
    bash -c 'GL_SOURCE_ONLY=1 . "$0"; render_one "$1" "$2" "$3" "$4" "$5"' \
      "$HERE/golden-render.sh" "$kind" "$bin" "$target" "{}" "$dest"

  # MANIFEST + summary
  local rendered=0 refused=0 error=0 oversize=0 tsv="$setdir/MANIFEST.tsv"
  : > "$tsv"
  for res in "$dest"/.*.res; do
    [ -e "$res" ] || continue
    local name status msg file size sha
    IFS=$'\t' read -r name status msg < "$res"
    file="$dest/$name.$ext"
    if [ "$status" = rendered ]; then
      size="$(stat -c %s "$file")"; sha="$(gl_sha256_file "$file")"
      if [ "$size" -gt 1048576 ]; then
        status=oversize; mv -f "$file" "$file.oversize"; file="$file.oversize"
      fi
    else
      # keep the evidence beside the manifest: refused/error sets are facts
      printf '%s\n' "$msg" > "$dest/$name.$ext.${status}"
      sha=""; size=0
    fi
    case "$status" in rendered) ((rendered++));; oversize) ((oversize++));; refused) ((refused++));; error) ((error++));; esac
    printf '%s\t%s\t%s\t%s\n' "$name" "${sha:--}" "$size" "$status" >> "$tsv"
  done
  rm -f "$dest"/.*.res "$dest"/.*.err
  LC_ALL=C sort -o "$tsv" "$tsv"
  printf '%s\t%s\t%s\t%s\t%s\n' "$b" "$rendered" "$refused" "$error" "$oversize"
}

write_stamp() {   # <backend> <setdir> <corpus> <kind> <bin> <counts> <unstable>
  local b="$1" setdir="$2" corpus="$3" kind="$4" bin="$5" counts="$6" unstable="$7"
  local target ext bsha bmtime
  target="$(gl_target "$b")"; ext="$(gl_ext "$b")"
  bsha="$(gl_sha256_file "$bin")"; bmtime="$(stat -c %y "$bin" 2>/dev/null | cut -d. -f1)"
  {
    printf '{\n'
    printf '  "schema": "sh2golden/1",\n'
    printf '  "backend": "%s",\n' "$(gl_json_str "$b")"
    printf '  "target": "%s",\n' "$(gl_json_str "$target")"
    printf '  "renderer": {"kind": "%s", "path": "%s", "sha256": "%s", "mtime": "%s"},\n' \
      "$kind" "$(gl_json_str "$bin")" "$bsha" "$(gl_json_str "$bmtime")"
    printf '  "workspace": {"path": "%s"},\n' "$(gl_json_str "$WS")"
    gl_repo_identity "$WS" workspace | while IFS='=' read -r k v; do printf '  "%s": "%s",\n' "$k" "$(gl_json_str "$v")"; done
    gl_repo_identity "$(gl_worktree "$WS" "$b")" sh2perl_worktree | while IFS='=' read -r k v; do printf '  "%s": "%s",\n' "$k" "$(gl_json_str "$v")"; done
    printf '  "corpus": {"dir": "%s", "glob": "*.sh", "sha256": "%s", "tree": "%s"},\n' \
      "$(gl_json_str "$corpus")" "$(gl_corpus_sha "$corpus")" \
      "$(git -C "$(dirname "$corpus")" rev-parse "HEAD:examples" 2>/dev/null || echo unknown)"
    printf '  "counts": {%s},\n' "$(printf '%s' "$counts" | awk -F'\t' '{printf "\"rendered\": %s, \"refused\": %s, \"error\": %s, \"oversize\": %s", $2,$3,$4,$5}')"
    printf '  "unstable": %s,\n' "$unstable"
    printf '  "created_utc": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "host": "%s"\n' "$(gl_json_str "$(hostname)")"
    printf '}\n'
  } > "$setdir/render.json"
}
CLI="$WS/otranspilerl/target/debug/otranspilerl-cli"
[ -x "$CLI" ] || CLI="$(command -v otranspilerl-cli 2>/dev/null || true)"

# Sourced by render-one.sh (worker for one file): every function below is
# defined and then this script stops — nothing is parsed, nothing is written.
# (The guard must sit AFTER the definitions and BEFORE the main loop: an
# early return leaves render_one undefined, which is exactly the bug that made
# xargs report "unknown argument" instead of rendering.)
if [ "${GL_SOURCE_ONLY:-0}" = 1 ]; then
  return 0 2>/dev/null || exit 0
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --backend) BACKENDS+=(${2//,/ }); shift 2;;
    --backend=*) BACKENDS+=(${1#*=}); shift;;
    --all) mapfile -t BACKENDS < <(for d in "$WS"/sh2perl/backends/*/; do
              b="$(basename "$d")"; case "$b" in --*) continue;; esac
              gl_renderer "$WS" "$b" >/dev/null 2>&1 && echo "$b"; done); shift;;
    --jobs) JOBS="$2"; shift 2;;
    --limit) LIMIT="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    --stamp-only) STAMP_ONLY=1; shift;;
    --dry-run) DRY=1; shift;;
    --force) FORCE=1; shift;;
    --no-inbox-init) INIT_INBOX=0; shift;;
    -h|--help) sed -n '2,40p' "${BASH_SOURCE[0]}"; exit 0;;
    *) gl_die "unknown argument: $1";;
  esac
done
[ ${#BACKENDS[@]} -gt 0 ] || BACKENDS=(rs)

for b in "${BACKENDS[@]}"; do
  corpus="$(gl_corpus_dir "$WS" "$b")"
  [ -d "$corpus" ] || gl_die "no corpus for $b ($corpus)"
  IFS=$'\t' read -r kind bin < <(gl_renderer "$WS" "$b") || gl_die "no renderer for $b"
  [ "$kind" = shir_render ] && [ -z "${CLI:-}" ] && gl_die "shir_render needs the CLI for --shir (not built)"
  wt_sha="$(git -C "$(gl_worktree "$WS" "$b")" rev-parse --short HEAD 2>/dev/null || echo nosha)"
  setname="$(date -u +%Y%m%dT%H%M%SZ)-${wt_sha}-${b}"

  if [ -n "$OUT" ]; then
    setdir="$OUT"
  elif [ "$DRY" = 1 ]; then
    setdir="$(mktemp -d)"
  else
    setdir="$ROOT/sets/$setname"
  fi
  if [ -d "$setdir" ] && [ -n "$(ls -A "$setdir" 2>/dev/null)" ]; then
    [ "$FORCE" = 1 ] || gl_die "set exists: $setdir (use --force)"
    rm -rf "${setdir:?}"/*
  fi
  mkdir -p "$setdir/renders"

  if [ "$STAMP_ONLY" = 0 ]; then
    # pass 1
    gl_log "$b: rendering $(ls -1 -- "$corpus"/*.sh | wc -l) examples from $corpus via $kind"
    counts="$(do_backend "$b" "$setdir" "$corpus")"
    # determinism pass: same render, fresh dir, compare
    chk="$(mktemp -d)"; mkdir -p "$chk/renders"
    do_backend "$b" "$chk" "$corpus" >/dev/null
    unstable=0
    if diff -rq "$setdir/renders" "$chk/renders" >"$chk/diff" 2>&1; then
      unstable=0
    else
      unstable=1
      gl_log "$b: NONDETERMINISTIC render — $(wc -l < "$chk/diff") differences; set marked unstable"
      head -5 "$chk/diff" >&2
    fi
    cp -f "$chk/diff" "$setdir/determinism.diff" 2>/dev/null || true
    rm -rf "$chk"
    save_patch "$(gl_worktree "$WS" "$b")" "$setdir/patches"
  else
    counts=$'\t\t\t\t'; unstable=0
  fi

  write_stamp "$b" "$setdir" "$corpus" "$kind" "$bin" "$counts" "$unstable"
  # one row per set in the record's INDEX.tsv (append-once: a re-run that
  # overwrites a set under --force does not duplicate the row)
  if [ "$DRY" = 0 ] && [ -z "$OUT" ] && [ -d "$ROOT" ]; then
    row="$(printf '%s\t%s\t%s\t%s\t%s' "$(basename "$setdir")" "$b" \
      "$(git -C "$(gl_worktree "$WS" "$b")" rev-parse HEAD 2>/dev/null || echo unknown)" \
      "$(gl_corpus_sha "$corpus")" "$(printf '%s' "$counts" | awk -F'\t' '{printf "r%s/f%s/e%s/o%s", $2,$3,$4,$5}')")"
    idx="$ROOT/INDEX.tsv"
    [ -s "$idx" ] || printf 'set_id\tbackend\tsh2perl_sha\tcorpus_sha\tcounts\n' > "$idx"
    command grep -qF "$(basename "$setdir")"$'\t' "$idx" 2>/dev/null || printf '%s\n' "$row" >> "$idx"
  fi
  gl_log "$b: $(printf '%s' "$counts" | awk -F'\t' '{printf "rendered=%s refused=%s error=%s oversize=%s", $2,$3,$4,$5}')"
  if [ "$DRY" = 1 ]; then
    echo "--- $setdir/render.json"; cat "$setdir/render.json"; rm -rf "$setdir"
  else
    echo "$setdir"
  fi
done
