#!/bin/bash
# harness/rust-warning-census.sh — generated-code warnings, measured.
#
# `fail-rs` runs rustc with warnings ignored, so a dead initializer or an
# unused binding can only grow there unseen. This census compiles every corpus
# example with the core `--target rs` output and reports the warnings rustc
# emits per program.
#
#   ./harness/rust-warning-census.sh            per-program counts + summary
#   ./harness/rust-warning-census.sh --quiet    summary only
#   ./harness/rust-warning-census.sh --json     {"programs":N,"warned":M,"warnings":W,"by_kind":{...}}
#   ./harness/rust-warning-census.sh <prefix>   only examples whose name starts with <prefix>
#   ./harness/rust-warning-census.sh --kinds=mut  which programs emit which warning kind
#
# A program that fails to compile is reported as COMPILEFAIL and counted
# separately: it is a `fail-rs` red, not a warning.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${OTRANSPILERL_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
EX="$ROOT/sh2perl/examples"
[ -x "$CLI" ] || { echo "census: CLI missing: $CLI (build otranspilerl-cli)" >&2; exit 2; }

quiet=0; json=0; prefix=""
for a in "$@"; do
  case "$a" in
    --quiet) quiet=1 ;;
    --json) json=1 ;;
    --kinds) kinds=1 ;;
    --kinds=*) kinds=1; kinds_grep="${a#--kinds=}" ;;
    -*) echo "census: unknown argument $a" >&2; exit 2 ;;
    *) prefix="$a" ;;
  esac
done

tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp" "$tmp.k" "$tmp.work"' EXIT
/bin/mkdir -p "$tmp.work"
programs=0; warned=0; total=0; fails=0; dep=0
for f in "$EX"/"$prefix"*.sh; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .sh)
  rs="$tmp.work/$name.rs"
  if ! "$CLI" --target rs "$f" > "$rs" 2>/dev/null || [ ! -s "$rs" ]; then
    echo "$name EMITFAIL" >> "$tmp"; fails=$((fails + 1)); continue
  fi
  programs=$((programs + 1))
  # a program that pulls in `regex`/`revera` has no manifest here; it builds
  # through the emitted Cargo project in fail-rs, so rustc alone would report
  # a bogus unresolved crate (not a warning, not a verdict)
  if command grep -qE 'regex::Regex|revera::' "$rs"; then
    echo "$name SKIP-dep" >> "$tmp"; dep=$((dep + 1)); continue
  fi
  err=$(rustc --crate-name prog --emit=metadata -o "$tmp.work/$name.meta" "$rs" 2>&1)
  # EMITFAIL on a compile error: the census is about warnings, not verdicts
  if printf '%s' "$err" | command grep -q '^error'; then
    echo "$name COMPILEFAIL" >> "$tmp"; fails=$((fails + 1)); continue
  fi
  n=$(printf '%s\n' "$err" | command grep -c '^warning: ')
  if [ "$n" -gt 0 ]; then
    warned=$((warned + 1)); total=$((total + n))
    echo "$name $n" >> "$tmp"
    printf '%s\n' "$err" | command grep '^warning: ' | sed 's/^warning: //' >> "$tmp.k"
    printf '%s\n' "$err" | command grep '^warning: ' | sed "s/^warning: //;s/^/$name|/" >> "$tmp.kinds"
  fi
done

if [ "$json" = 1 ]; then
  printf '{"programs":%d,"warned":%d,"warnings":%d,"fails":%d,"by_kind":{' \
    "$programs" "$warned" "$total" "$fails"
  sep=""
  if [ -f "$tmp.k" ]; then
    sort "$tmp.k" | uniq -c | sort -rn | while read -r c k; do
      printf '%s"%s":%s' "$sep" "$(printf '%s' "$k" | sed 's/"/\\"/g')" "$c"
      sep=","
    done
  fi
  printf '}}\n'
  exit 0
fi

if [ "${kinds:-0}" = 1 ]; then
  # per-program kinds, so a warning class can be traced to the example that
  # emits it (e.g. which programs carry `variable does not need to be mutable`)
  sort "$tmp.kinds" 2>/dev/null | command grep -F -- "${kinds_grep:-}" || true
  exit 0
fi

if [ "$quiet" = 0 ]; then
  sort -k2,2rn "$tmp" | command grep -vE ' (COMPILEFAIL|EMITFAIL)$' || true
  command grep -E ' (COMPILEFAIL|EMITFAIL)$' "$tmp" || true
  echo
fi
echo "warning census: $programs programs, $warned with warnings, $total warnings, $fails not compiled, $dep skipped (cargo dep)"
if [ -f "$tmp.k" ]; then
  sort "$tmp.k" | uniq -c | sort -rn | head -10 | sed 's/^/  /'
fi
exit 0
