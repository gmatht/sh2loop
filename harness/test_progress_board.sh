#!/usr/bin/env bash
# test_progress_board.sh — regression tests for the per-tree board's TEXT.
#
# WHY THIS EXISTS. The board printed the same explanatory phrase twice on one
# screen: once in the units legend and again in every row, e.g.
#
#     units: <n>f = failing tests   <n> runtime calls = this tree's own delegation
#     c    0f 0f 0f  GREEN — 0 fails; 29103 runtime calls (this tree's namespace)
#
# It got fixed, and then came back — three times, across three commits, each
# time by a different route (a legend edit that did not remove the row copy; a
# stray `))` repair that restored a truncated f-string; a warning appended to
# the same print). Nobody noticed for four hours because a human reading a
# green board sees "a number" and not "the number plus a clause I have already
# read". So the check is automated here rather than left to attention.
#
# WHAT IT ASSERTS. For a green row, the explanatory prose must appear in
# exactly ONE place on the board: the legend. A row carries the number and its
# unit, and nothing else. Duplicated prose is the failure this guards.
#
# It also guards the unit-tagging contract: every number a row prints must be
# unit-tagged (`0f` for fails, a bare integer followed by a unit word), because
# an untagged number in a shared column is ambiguous by construction.
#
# IMPLEMENTATION NOTE, because it cost this test its first result: `grep -qF`
# and `grep -qi` are BROKEN on this box. `grep` is a shell function wrapping
# ripgrep, and it forwards `-F` to rg, which rejects it ("unrecognized flag"),
# so `grep -qF <needle> <file>` returns non-zero for EVERY input -- including
# text that does contain the needle. The first version of the duplication
# check used it, passed against the very regression it was written for, and
# would have done so again forever. Every grep below is `command grep`, which
# bypasses the alias; a test that cannot fail is worse than no test, because
# it is read as evidence.
#
# Usage:  harness/test_progress_board.sh        # exits 0 on pass, 1 on fail
set -u
cd "$(dirname "$0")/.."
ROOT="$PWD"
BOARD="${1:-./progress.sh}"

pass=0; fail=0
ok()  { printf '  ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail+1)); }

# Run the board and capture ONLY the per-tree board section — the legend plus
# the rows. Slicing by section matters: the rest of progress.sh prints the
# metric history, the model-rotation report and the worker panel, and a
# duplicate phrase there is a different (and legitimate) discussion.
board_section() {
    "$BOARD" 2>/dev/null \
      | sed -n '/^--- Per-tree board/,/^$/p'
}

out=$(board_section)
if [ -z "$out" ]; then
    bad "could not read the per-tree board from $BOARD (empty section)"
    printf '\n  %d passed, %d failed\n' "$pass" "$fail"
    exit 1
fi

legend=$(printf '%s\n' "$out" | sed -n '/units:/p')
# Rows only: the data lines are `  <tree> <24h> <4h> <now> <trend>`, so the
# first field is a tree name and there are at least 5 fields. The header line
# (`tree  24h  4h  now  trend`) has the same shape, so exclude it by name --
# without this the unit-tag check reads the HEADER's column labels as if they
# were data, which is how it reported '24h' '4h' 'now' as untagged numbers.
# Skip the section banner too: it starts with `---` and its first field is
# "---", which otherwise parses as a "row" whose columns are prose.
rows=$(printf '%s\n' "$out" | awk '$1 != "---" && NF>=5 && $1 != "tree" && $1 != "units:" {print}')

# ── 1. the duplication this file exists for ───────────────────────────
# Every prose clause the LEGEND defines must not also appear in a row. The
# legend is the single source; a row repeats nothing.
dupes=""
for phrase in "this tree's own delegation" "this tree's namespace" "fully native" "(this tree)"; do
    # does any ROW carry it?
    if printf '%s\n' "$rows" | command grep -qF "$phrase"; then
        dupes="$dupes '$phrase'"
    fi
done
if [ -n "$dupes" ]; then
    bad "legend prose is duplicated into the rows:$dupes"
    printf '%s\n' "$rows" | sed -n '1,4p' | sed 's/^/         row: /'
else
    ok "no legend prose is repeated in any row"
fi

# ── 2. the legend must still DEFINE the units ────────────────────────
# Removing the duplication must not remove the explanation itself.
if printf '%s\n' "$legend" | command grep -q 'runtime calls'; then
    ok "the legend still names the green-row unit"
else
    bad "the legend no longer names 'runtime calls' — the green row's number is now unlabelled"
fi
if printf '%s\n' "$legend" | command grep -q 'failing tests'; then
    ok "the legend still names the fail unit"
else
    bad "the legend no longer names 'failing tests'"
fi

# ── 3. every row is unit-tagged ──────────────────────────────────────
# A bare number in a shared column is ambiguous. Rows must end their numeric
# columns with `f` (fails) or carry an explicit unit in the trend text.
untagged=""
while IFS= read -r line; do
    [ -n "$line" ] || continue
    # columns 2-4 are 24h/4h/now; each must be `-` or end in `f`
    cols=$(printf '%s\n' "$line" | awk '{print $2, $3, $4}')
    for c in $cols; do
        case "$c" in
            -|*f) ;;
            *) untagged="$untagged '$c'" ;;
        esac
    done
done <<< "$rows"
if [ -n "$untagged" ]; then
    bad "untagged number(s) in a fail column:$untagged"
else
    ok "every fail column is unit-tagged"
fi

# ── 4. a green row states its number, and it is not called native ────
# The regression that started this: "0 stubs (this tree — fully native)"
# when the backend's runtime namespace is not the sh2_* one, i.e. a 0 that
# was zero by construction. A green row must not assert "native".
if printf '%s\n' "$rows" | command grep -qi 'fully native'; then
    bad "a row claims 'fully native' — that was the vacuous-zero regression"
else
    ok "no row claims 'fully native'"
fi

# ── 5. the board must not hide an unparsed row ───────────────────────
# A report row the parser cannot read is a run whose verdict is invisible.
# Silence here is the failure.
printf '\n  %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
exit 0
