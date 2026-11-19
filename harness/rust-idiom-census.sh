#!/bin/bash
# harness/rust-idiom-census.sh — how much non-idiomatic Rust the core emits.
#
# `fail-rs` asks "does it run"; this asks "is the emitted code worth reading".
# It renders every corpus example with the core's `--target rs` path and
# reports, per program, which emitted helper families are still dragged in,
# the structural artifacts no helper call captures (thread-local store, $?
# plumbing, string-typed arithmetic) and the shell commands still spawned.
#
#   ./harness/rust-idiom-census.sh            full report + summary
#   ./harness/rust-idiom-census.sh --quiet    summary only
#   ./harness/rust-idiom-census.sh <prefix>   only examples whose name starts
#
# FAMILIES are the emission classes of PLAN v157: plumbing (I/O sink, status,
# spawn), quoting/splitting, matchers, command emulation, stat predicates,
# text ops. A program counts once per family it touches, so the per-family
# numbers overlap; `helpers-free` and `plumbing-only` are the verdicts.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${OTRANSPILERL_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
EX="$ROOT/sh2perl/examples"
[ -x "$CLI" ] || { echo "idiom-census: CLI missing: $CLI (build otranspilerl-cli)" >&2; exit 2; }

quiet=0; prefix=""
for a in "$@"; do
  case "$a" in
    --quiet) quiet=1 ;;
    -*) echo "idiom-census: unknown argument $a" >&2; exit 2 ;;
    *) prefix="$a" ;;
  esac
done

work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT

rendered=0; failed=0; unparseable=0
for f in "$EX"/"$prefix"*.sh; do
  [ -f "$f" ] || continue
  # the same filter fail-rs uses: a file bash itself rejects is not a program
  bash -n "$f" 2>/dev/null || { unparseable=$((unparseable + 1)); continue; }
  name=$(basename "$f" .sh)
  if "$CLI" --target rs "$f" > "$work/$name.rs" 2>/dev/null && [ -s "$work/$name.rs" ]; then
    rendered=$((rendered + 1))
  else
    rm -f "$work/$name.rs"; failed=$((failed + 1))
  fi
done

# helper names called or defined, per program
limit_helpers() {
  command grep -oE '__sh_[a-z_0-9]+\(' "$1" 2>/dev/null | sed 's/($//' | sort -u
}

# family → member helpers (the PLAN v157 classes)
fam_names() {
  case "$1" in
    plumbing) echo "sink print_words puts spawn run capture_rc run_traps arg ret_rc wait_all bg fn_capture cap_bytes out_bytes" ;;
    quoting)  echo "q wq" ;;
    splitting) echo "split_ifs read_fields" ;;
    matchers) echo "fnmatch regex glob glob_like strippre stripsuf case" ;;
    fs_commands) echo "rm mkdir touch mktemp sleep samefile cat cat_stmt catf fread" ;;
    stat)     echo "freg fdir fexists fsym fmode fowner fgroup mtime fnewer uid gid hostname basename_args dirname_args" ;;
    text)     echo "substr replace echo_esc atoi div mod pow env readline" ;;
  esac
}

helpers_free=0; with_helpers=0; plumbing_only=0
: > "$work/families"
for rs in "$work"/*.rs; do
  [ -f "$rs" ] || continue
  hs=$(limit_helpers "$rs")
  if [ -z "$hs" ]; then helpers_free=$((helpers_free + 1)); continue; fi
  with_helpers=$((with_helpers + 1))
  only=1
  for fam in plumbing quoting splitting matchers fs_commands stat text; do
    hit=0
    for h in $(fam_names "$fam"); do
      if printf '%s\n' "$hs" | command grep -qx "__sh_$h"; then hit=1; break; fi
    done
    [ "$hit" = 1 ] && echo "$fam" >> "$work/families"
    case "$fam" in
      plumbing|quoting) ;;
      *) [ "$hit" = 1 ] && only=0 ;;
    esac
  done
  [ "$only" = 1 ] && plumbing_only=$((plumbing_only + 1))
done

bytes=$(cat "$work"/*.rs | wc -c)
helpers=$(awk '/^fn __sh_/{c++} END{print c+0}' "$work"/*.rs)
sites=$(cat "$work"/*.rs | command grep -oE '__sh_[a-z_0-9]+\(' | wc -l)

# structural artifacts: no helper call, but not what a Rust reader writes
shv=0; tls=0; rc=0; parseint=0; spawn=0
for rs in "$work"/*.rs; do
  [ -f "$rs" ] || continue
  command grep -q '__SHV_' "$rs" && shv=$((shv + 1))
  command grep -q 'thread_local!' "$rs" && tls=$((tls + 1))
  command grep -q '__SH_RC' "$rs" && rc=$((rc + 1))
  command grep -q 'parse::<i64>' "$rs" && parseint=$((parseint + 1))
  command grep -q '__sh_spawn(' "$rs" && spawn=$((spawn + 1))
done

# shell command words still spawned (statically visible first word)
: > "$work/cmds"
for rs in "$work"/*.rs; do
  # `__sh_spawn("'tee' 'f'")` — a statically visible first word;
  # a `format!` head (`"{} | {}"`) has none and is skipped.
  command grep -oE "__sh_spawn\\(\\s*\"'?[A-Za-z0-9_.+-]+'?" "$rs" 2>/dev/null \
    | sed "s/.*\"'\?//; s/'$//" | sort -u >> "$work/cmds"
done

if [ "$quiet" = 0 ]; then
  echo "programs rendered: $rendered (emit failed: $failed, bash -n rejected: $unparseable)"
  echo "helpers-free:      $helpers_free"
  echo "with helpers:      $with_helpers"
  echo "  plumbing only:   $plumbing_only"
  echo "bytes: $bytes  helper defs: $helpers  __sh_* call sites: $sites"
  echo "structural: __SHV_ $shv  thread_local! $tls  __SH_RC $rc  parse::<i64> $parseint  spawn $spawn"
  echo "spawned command words:"
  sort "$work/cmds" | uniq -c | sort -rn | head -20 | sed 's/^/  /'
fi
echo "idiom census: $rendered programs, $helpers_free helpers-free, $with_helpers with helpers ($plumbing_only plumbing-only), $bytes bytes, $helpers helper defs, $sites call sites, $spawn spawn, $(sort -u "$work/cmds" | wc -l) command words"
exit 0
