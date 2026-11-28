#!/usr/bin/env bash
# compat-probe.sh — differential compatibility of bash-O4 and dash against bash.
#
# Runs ONE bash program three ways and compares stdout + exit status:
#
#   bash     : the reference (GNU bash 5.3 here)
#   bash-O4  : the transpiled native binary (bash-O4 -o), run on the SAME argv
#   dash     : a strict POSIX shell (the usual /bin/sh)
#
# The cases sit ON the bash/POSIX fault lines on purpose: constructs a shell
# can only match bash on by being bash-specific. "The script ran" is not the
# test; agreement on stdout AND exit status is.
#
# Usage:
#   harness/compat-probe.sh                 # per-case verdicts + summary
#   harness/compat-probe.sh --diff          # + what each side actually printed
#   harness/compat-probe.sh --list          # one line per case for all three
#   harness/compat-probe.sh --only 2,9,13   # subset by case number
#   BO4=/path/to/bash-O4 harness/compat-probe.sh
#
# Case file format (harness/compat-cases.txt): name<TAB>program, one per line,
# '#' comments. The program is ONE bash snippet; it may print several lines.
#
# Exit: 0 when the run completed (differences are the RESULT — a probe, not a
# gate). 2 when bash-O4 is missing: nothing was measured, which must not read
# as a pass (the harness/posix-oracle.sh rule).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BO4="${BO4:-$ROOT/bash-o4/target/debug/bash-O4}"
export BASH_O4_SH2PERL="${BASH_O4_SH2PERL:-$ROOT/sh2perl}"
CASES_FILE="${CASES_FILE:-$ROOT/harness/compat-cases.txt}"
BASH_BIN="$(command -v bash)"
DASH_BIN="$(command -v dash || true)"
MODE=table
ONLY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --list) MODE=list ;;
        --diff) MODE=diff ;;
        --only) ONLY="$2"; shift ;;
        -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
        *) echo "unknown option $1" >&2; exit 2 ;;
    esac
    shift
done
[ -x "$BO4" ] || { echo "compat-probe: no bash-O4 at $BO4 — nothing measured, NOT a pass" >&2; exit 2; }
[ -f "$CASES_FILE" ] || { echo "compat-probe: no case file at $CASES_FILE" >&2; exit 2; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT

# run <program-file> <command...> -> "rc|stdout" (stderr dropped, 20 s cap)
run() {
    local prog="$1"; shift
    local out rc
    out=$( cd "$W" && env -u BASH_ENV timeout 20 "$@" "$prog" 2>/dev/null ); rc=$?
    printf '%d|%s' "$rc" "$out"
}

printf '%-30s %-8s %-8s %s\n' "case" "bash-O4" "dash" "what bash does here"
printf -- '-------------------------------------------------------------------------\n'

n=0; s_bo4=0; d_bo4=0; s_dash=0; d_dash=0; skipped=0
while IFS=$'\t' read -r name prog; do
    case "$name" in ''|\#*) continue ;; esac
    n=$((n + 1))
    if [ -n "$ONLY" ]; then
        case ",$ONLY," in *",$n,"*) : ;; *) continue ;; esac
    fi
    p="$W/$n.sh"
    printf '%s\n' "$prog" > "$p"

    ref=$(run "$p" "$BASH_BIN")

    if "$BO4" -o "$W/$n.bin" "$p" >"$W/$n.log" 2>&1; then
        got_bo4=$(run "$p" "$W/$n.bin")
    else
        got_bo4="RENDER|$(tail -1 "$W/$n.log" | sed 's/.*error: //' | cut -c1-40)"
        skipped=$((skipped + 1))
    fi
    if [ -n "$DASH_BIN" ]; then got_dash=$(run "$p" "$DASH_BIN"); else got_dash="nodash|"; fi

    # A render failure is not "different output" — it is a fourth outcome,
    # and counting it as a DIFF would hide how many cases are actually
    # compared. Verdicts: SAME / DIFF / RENDER (bash-O4 could not build it).
    case "$got_bo4" in
        RENDER*) vb=RENDER; d_bo4=$((d_bo4 + 1)) ;;
        *) if [ "$got_bo4" = "$ref" ]; then vb=SAME; s_bo4=$((s_bo4 + 1))
           else vb=DIFF; d_bo4=$((d_bo4 + 1)); fi ;;
    esac
    if [ "$got_dash" = "$ref" ]; then vd=SAME; s_dash=$((s_dash + 1))
    else vd=DIFF; d_dash=$((d_dash + 1)); fi

    short=$(printf '%s' "$prog" | cut -c1-52)
    case "$MODE" in
        table) printf '%-30s %-8s %-8s %s\n' "$name" "$vb" "$vd" "$short" ;;
        list)  printf '%-30s bash=%-28s bo4=%-28s dash=%s\n' "$name" "$ref" "$got_bo4" "$got_dash" ;;
        diff)  printf '%-30s bash-O4:%-6s dash:%-6s %s\n' "$name" "$vb" "$vd" "$short"
               [ "$vb" = SAME ] || printf '    %-9s %s\n' "bash:" "$ref"
               [ "$vb" = SAME ] || printf '    %-9s %s\n' "bash-O4:" "$got_bo4"
               [ "$vd" = SAME ] || printf '    %-9s %s\n' "dash:" "$got_dash" ;;
    esac
done < "$CASES_FILE"

compared=$((n - skipped))
printf -- '-------------------------------------------------------------------------\n'
printf '== summary (of %d cases, %d compared, %d bash-O4 render failures) ==\n' "$n" "$compared" "$skipped"
printf '  bash-O4 vs bash : %2d SAME  %2d DIFF   (%.0f%% same)\n' "$s_bo4" "$d_bo4" \
    "$(awk -v a="$s_bo4" -v b="$compared" 'BEGIN{print (b>0 ? 100*a/b : 0)}')"
printf '  dash    vs bash : %2d SAME  %2d DIFF   (%.0f%% same)\n' "$s_dash" "$d_dash" \
    "$(awk -v a="$s_dash" -v b="$n" 'BEGIN{print (b>0 ? 100*a/b : 0)}')"
