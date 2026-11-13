#!/bin/bash
# harness/golden-diff.sh — compare two golden render sets (or a set against a
# working tree), per backend, and say what actually changed.
#
# WHY: the behaviour gates compare program OUTPUT, so a lowering can change
# every emission it touches and still pass. The golden record keeps the
# rendered text; this turns two records into the review surface:
#   "rs fea559e → rs 1a2b3c4: 61 rendered changed, 2 rendered→refused, 1 new"
#
# Usage:
#   harness/golden-diff.sh <setA> <setB>          summarise A → B
#   harness/golden-diff.sh <setA> --list          list changed examples
#   harness/golden-diff.sh <setA> --grep PATTERN  show files whose render
#                                                 matches/loses PATTERN
#   harness/golden-diff.sh <setA> --stat          git-style diffstat per file
#   harness/golden-diff.sh --latest <backend>     newest recorded set for a backend
#   harness/golden-diff.sh <setA>                 summarise newest set → A
#
# Sets are directories (sets/<id>/ with render.json + MANIFEST.tsv + renders/).
# The record root is $SH2_GOLDEN_REPO, else the ignored .golden-inbox/.
#
# Exit: 0 no differences, 1 differences, 2 usage/error. A difference between
# sets rendered from DIFFERENT sh2perl commits is reported but still exit 1 —
# the caller decides whether that is expected.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=golden-lib.sh
. "$HERE/golden-lib.sh"

WS="$(gl_workspace)" || gl_die "cannot find the workspace"
ROOT="${SH2_GOLDEN_REPO:-$WS/.golden-inbox}"

mode=summary
args=()
for a in "$@"; do
  case "$a" in
    --list) mode=list ;;
    --stat) mode=stat ;;
    --grep) mode=grep ;;
    --latest) mode=latest ;;
    -h|--help) sed -n '2,25p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) args+=("$a") ;;
  esac
done

resolve() {   # <set-or-backend>  -> set dir
  local x="$1"
  if [ -d "$x" ]; then printf '%s\n' "$x"; return 0; fi
  # a backend name: newest set for it
  local latest
  latest="$(ls -1d "$ROOT"/sets/*-"$(gl_lang "$x")" 2>/dev/null | sort | tail -1)"
  [ -n "$latest" ] && { printf '%s\n' "$latest"; return 0; }
  return 1
}

grep_pattern=""
if [ "$mode" = grep ]; then
  grep_pattern="${args[1]:-}"; [ -n "$grep_pattern" ] || gl_die "--grep needs a pattern"
  A="$(resolve "${args[0]}")" || gl_die "no such set: ${args[0]}"
  B=""
elif [ "$mode" = latest ]; then
  A="$(resolve "${args[0]:-rs}")" || gl_die "no recorded set for ${args[0]:-rs}"
  B=""
else
  A="$(resolve "${args[0]:-}")" || gl_die "no such set: ${args[0]:-<none>}"
  B="$(resolve "${args[1]:-}")" || gl_die "no such set: ${args[1]:-<none>}"
fi

set_field() {  # <setdir> <json key>
  sed -n "s/^  \"$2\": *\"\{0,1\}\([^\",]*\)\"\{0,1\},\{0,1\}$/\1/p" "$1/render.json" | head -1
}
describe() {   # <setdir>
  printf '%s (%s@%s)' "$(basename "$1")" \
    "$(set_field "$1" sh2perl_worktree_branch)" "$(set_field "$1" sh2perl_worktree_sha | cut -c1-7)"
}

if [ "$mode" = grep ]; then
  gl_log "searching $(basename "$A")"
  hits=0
  while IFS=$'\t' read -r name _ _ status; do
    [ "$status" = rendered ] || continue
    f="$(ls "$A/renders/$name".* 2>/dev/null | head -1)"
    [ -n "$f" ] || continue
    if command grep -qE -- "$grep_pattern" "$f"; then
      printf '%s\t%s\n' "$name" "$f"; ((hits++))
    fi
  done < "$A/MANIFEST.tsv"
  gl_log "$hits file(s) match /$grep_pattern/"
  [ "$hits" -gt 0 ] && exit 1 || exit 0
fi

if [ -z "$B" ]; then
  # single set: report its own stamp and status counts
  echo "set:      $(describe "$A")"
  echo "renderer: $(set_field "$A" kind) $(set_field "$A" path)"
  echo "corpus:   $(set_field "$A" sha256)"
  echo "unstable: $(set_field "$A" unstable)"
  awk -F'\t' '{c[$4]++} END {for (k in c) printf "  %-9s %d\n", k, c[k]}' "$A/MANIFEST.tsv"
  exit 0
fi

# ── A → B ────────────────────────────────────────────────────────────────
a_sha="$(set_field "$A" sh2perl_worktree_sha)"; b_sha="$(set_field "$B" sh2perl_worktree_sha)"
a_behind="$(set_field "$A" sh2perl_worktree_behind)"; b_behind="$(set_field "$B" sh2perl_worktree_behind)"
echo "A: $(describe "$A")  [$a_behind behind main]"
echo "B: $(describe "$B")  [$b_behind behind main]"
if [ "$a_sha" != "$b_sha" ]; then
  echo "note: different sh2perl commits — differences may come from the renderer, not the change under test"
fi
if [ "$a_behind" != "$b_behind" ]; then
  echo "note: the two worktrees are at different distances from main ($a_behind vs $b_behind) — renders are not like-for-like"
fi
for s in "$A" "$B"; do
  [ "$(set_field "$s" unstable)" = 1 ] && echo "warning: $(basename "$s") is marked unstable (nondeterministic render)"
done

declare -A a_status b_status
while IFS=$'\t' read -r n _ _ st; do a_status["$n"]="$st"; done < "$A/MANIFEST.tsv"
while IFS=$'\t' read -r n _ _ st; do b_status["$n"]="$st"; done < "$B/MANIFEST.tsv"

changed=0; became_rendered=0; became_refused=0; added=0; removed=0; same=0
: > /tmp/.golden-diff-list.$$
for n in "${!b_status[@]}"; do
  bs="${b_status[$n]}"; as="${a_status[$n]:-}"
  if [ -z "$as" ]; then
    printf 'added\t%s\t%s\n' "$n" "$bs" >> /tmp/.golden-diff-list.$$; ((added++)); continue
  fi
  if [ "$as" = "$bs" ] && [ "$as" = rendered ]; then
    fa="$(ls "$A/renders/$n".* 2>/dev/null | head -1)"; fb="$(ls "$B/renders/$n".* 2>/dev/null | head -1)"
    if cmp -s "$fa" "$fb"; then ((same++)); else
      printf 'changed\t%s\t%s\n' "$n" "$bs" >> /tmp/.golden-diff-list.$$; ((changed++))
    fi
  elif [ "$as" = rendered ] && [ "$bs" != rendered ]; then
    printf 'rendered→%s\t%s\t%s\n' "$bs" "$n" "$bs" >> /tmp/.golden-diff-list.$$; ((became_refused++))
  elif [ "$as" != rendered ] && [ "$bs" = rendered ]; then
    printf '%s→rendered\t%s\t%s\n' "$as" "$n" "$bs" >> /tmp/.golden-diff-list.$$; ((became_rendered++))
  elif [ "$as" != "$bs" ]; then
    printf '%s→%s\t%s\t%s\n' "$as" "$bs" "$n" "$bs" >> /tmp/.golden-diff-list.$$; ((changed++))
  fi
done
for n in "${!a_status[@]}"; do
  [ -n "${b_status[$n]:-}" ] || { printf 'removed\t%s\t\n' "$n" >> /tmp/.golden-diff-list.$$; ((removed++)); }
done

echo
printf '  rendered changed   %d\n' "$changed"
printf '  rendered → not     %d\n' "$became_refused"
printf '  not → rendered     %d\n' "$became_rendered"
printf '  added / removed    %d / %d\n' "$added" "$removed"
printf '  unchanged          %d\n' "$same"

case "$mode" in
  list) LC_ALL=C sort -k2 /tmp/.golden-diff-list.$$ ;;
  stat)
    while IFS=$'\t' read -r kind n _; do
      fa="$(ls "$A/renders/$n".* 2>/dev/null | head -1)"; fb="$(ls "$B/renders/$n".* 2>/dev/null | head -1)"
      [ -n "$fa" ] && [ -n "$fb" ] || { printf '%s\t%s\t%s\n' "$kind" "$n" "(-)"; continue; }
      d="$(diff -U0 "$fa" "$fb" 2>/dev/null | command grep -c '^[-+][^-+]' || true)"
      printf '%s\t%s\t%s changed lines\n' "$kind" "$n" "$d"
    done < <(LC_ALL=C sort -k2 /tmp/.golden-diff-list.$$)
    ;;
  summary)
    LC_ALL=C sort -k2 /tmp/.golden-diff-list.$$ | head -20
    n=$(wc -l < /tmp/.golden-diff-list.$$)
    [ "$n" -gt 20 ] && echo "... $((n - 20)) more (use --list)"
    ;;
esac
rm -f /tmp/.golden-diff-list.$$
[ $((changed + became_refused + became_rendered + added + removed)) -gt 0 ] && exit 1 || exit 0
