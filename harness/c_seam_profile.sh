#!/usr/bin/env bash
# harness/c_seam_profile.sh — rank the c runtime's `_sh_*` helpers by CALL
# SITES in the program BODY, so the next lowering target is chosen by measured
# frequency rather than a guess.
#
# The render path is EXACTLY backend_runtime_metric.sh's c arm (the worktree
# shir_render). If this used a different renderer the ranking would describe a
# tree nobody edits — the vacuous-measurement bug the metric script documents.
#
# Two numbers per helper:
#   body   — occurrences after `int main` (the program; what a lowering can
#            actually replace)
#   defs   — occurrences in the emitted runtime preamble (emitted once per
#            file; the floor a lowering cannot move)
#
# Modes:
#   (default)   rank helpers present in the body
#   --defs      rank helpers present in the preamble
#   --totals    body/defs token totals only
set -u
cd "$(dirname "$0")/.."
ROOT="$PWD"
CLI="${OTRANSPILERL_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
C_SHIR_RENDER="${C_SHIR_RENDER:-$ROOT/sh2perl/backends/c/target/debug/shir_render}"

[ -x "$CLI" ] || { echo "c_seam_profile: $CLI missing" >&2; exit 1; }
[ -x "$C_SHIR_RENDER" ] || { echo "c_seam_profile: $C_SHIR_RENDER missing" >&2; exit 1; }

MODE=body
case "${1:-}" in --defs) MODE=defs;; --totals) MODE=totals;; esac

CORPUS=("$ROOT"/sh2perl/examples/*.sh)
[ -e "${CORPUS[0]}" ] || { echo "no corpus under sh2perl/examples" >&2; exit 1; }

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
: > "$W/all.c"; : > "$W/body.c"; : > "$W/pre.c"
files=0
for f in "${CORPUS[@]}"; do
    [ -f "$f" ] || continue
    shir=$("$CLI" --target shir "$f" 2>/dev/null) || continue
    [ -n "$shir" ] || continue
    out="$W/one.c"
    printf '%s' "$shir" | "$C_SHIR_RENDER" --target=c - > "$out" 2>/dev/null || continue
    [ -s "$out" ] || continue
    cat "$out" >> "$W/all.c"; printf '\n' >> "$W/all.c"
    # Per-file body/preamble split: every file has its own `int main`, so a
    # single file-wide awk over a concatenation would count later files'
    # preambles as body.
    awk -v B="$W/body.c" -v P="$W/pre.c" \
        '/^int main\(/ { b=1 } { print >> (b ? B : P) }' "$out"
    files=$((files+1))
done

echo "=== corpus rendered: $files files, $(grep -c '' "$W/all.c") lines ==="

grep -aohE '_sh_[A-Za-z_0-9]+' "$W/body.c" | sort | uniq -c | sort -rn > "$W/body.tally"
grep -aohE '_sh_[A-Za-z_0-9]+' "$W/pre.c"  | sort | uniq -c | sort -rn > "$W/pre.tally"

printf '\nbody tokens: %s   pre tokens: %s\n\n' \
    "$(awk '{s+=$1} END{print s+0}' "$W/body.tally")" \
    "$(awk '{s+=$1} END{print s+0}' "$W/pre.tally")"

case "$MODE" in
totals) exit 0;;
defs)
    printf '%-28s %8s\n' HELPER PRE
    head -"${PROFILE_N:-40}" "$W/pre.tally" | awk '{printf "%-28s %8d\n", $2, $1}'
    ;;
body)
    printf '%-28s %8s %8s\n' HELPER BODY DEFS
    awk 'NR==FNR{p[$2]=$1;next}{ printf "%-28s %8d %8d\n", $2, $1, p[$2]+0 }' \
        "$W/pre.tally" "$W/body.tally" | head -"${PROFILE_N:-40}"
    ;;
esac
