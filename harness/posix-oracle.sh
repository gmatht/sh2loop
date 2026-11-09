#!/usr/bin/env bash
# posix-oracle.sh — differential gate against the REFERENCE POSIX semantics
# rather than against bash.
#
#   ./harness/posix-oracle.sh                 # corpus, summary
#   ./harness/posix-oracle.sh 051 064         # filename prefixes
#   ./harness/posix-oracle.sh --list          # one line per differing file
#   SMOOSH=/path/to/smoosh ./harness/posix-oracle.sh
#
# Exit: 0 for a completed comparison (a difference is a RESULT, not a
# failure), 2 when the oracle is missing (nothing was measured — do not read
# that as green; same convention as harness/transform-diff.sh).
#
# WHY A SECOND ORACLE. `./fail` compares every backend against BASH. bash is
# not the standard: for the constructs where the spec and bash disagree
# (tilde expansion in assignments, local/export interaction, errexit edges,
# bg signal handling), a bash-identical transpiler is a POSIX-WRONG
# transpiler, and a bash difference is not necessarily a bug.
#
# Smoosh (POPL 2020, "Executable Formal Semantics for the POSIX Shell") is
# an EXECUTABLE shell derived from a Lem formalization of POSIX sh, and the
# paper measures it as the most conformant of bash, dash, zsh, OSH, mksh,
# ksh93 and yash. As an oracle it is a third opinion, not a replacement:
# the three-way comparison bash vs dash vs Smoosh is what tells you whether
# a mismatch is "we are wrong" or "bash is special".
#
# IMPORTANT LIMIT, measured 2026-10-24 and recorded so nobody re-derives it:
# Smoosh is NOT a proof development and cannot be one of our proofs' targets.
# It is 14 .lem files extracted to OCaml; there are zero .v files, and
# `lem -coq`/`lem -isa` fail on its own sources (96 `declare ocaml
# target_rep`, none for any proof assistant). So Smoosh is useful HERE, as a
# runtime oracle, and NOT as a foundation for Tier-3 theorems
# (docs/transform-verification.md, Tier 3 item 3).
#
# BUILDING THE ORACLE (not done by this script):
#   git clone --recurse-submodules https://github.com/mgree/smoosh
#   cd smoosh/libdash && ./autogen.sh && ./configure && make && make install
#     (needs autoconf automake libtool pkg-config)
#   opam install -y ocamlfind ocamlbuild num zarith extunix lem
#   cd smoosh/src && make all      # produces ./smoosh and ./shtepper
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sub="$root/sh2perl"
CLI="${OTRANSPILERL:-$root/otranspilerl/target/debug/otranspilerl-cli}"
RENDER="${SHIR_RENDER:-$sub/backends/c/target/debug/shir_render}"
SMOOSH="${SMOOSH:-}"
CAP="${CAP_BYTES:-1048576}"

list=0
files=()
for a in "$@"; do
    case "$a" in
        --list) list=1 ;;
        *) files+=("$a") ;;
    esac
done

# Find a smoosh binary unless one was named.
if [ -z "$SMOOSH" ]; then
    for cand in "$root/smoosh/src/smoosh" "$(command -v smoosh || true)"; do
        [ -n "$cand" ] && [ -x "$cand" ] && SMOOSH="$cand" && break
    done
fi
if [ -z "$SMOOSH" ] || [ ! -x "$SMOOSH" ]; then
    echo "posix-oracle: no smoosh binary (SMOOSH=... or build it; see the header)" >&2
    echo "posix-oracle: nothing was measured — this is NOT a pass" >&2
    exit 2
fi
[ -x "$CLI" ] || { echo "posix-oracle: no transpiler at $CLI" >&2; exit 2; }

# Arguments are name PREFIXES (as in ./fail 051 064), not full paths — an
# earlier draft treated them as exact names and reported "0 same, 0 differ,
# 3 skipped", which reads as a pass. Prefix matching now, and a prefix that
# matches nothing is an ERROR rather than a skip.
if [ ${#files[@]} -eq 0 ]; then
    mapfile -t files < <(ls "$sub"/examples/*.sh 2>/dev/null | sed "s|$sub/examples/||; s|\.sh$||")
else
    expanded=()
    for pat in "${files[@]}"; do
        hit=0
        for f in "$sub"/examples/*.sh; do
            n=$(basename "$f" .sh)
            case "$n" in
                *"$pat"*) expanded+=("$n"); hit=1 ;;
            esac
        done
        [ "$hit" = 0 ] && { echo "posix-oracle: no example matches '$pat'" >&2; exit 2; }
    done
    files=("${expanded[@]}")
fi

T=$(mktemp -d "${TMPDIR:-/tmp}/posix-oracle.XXXXXX")
trap 'rm -rf "$T"' EXIT

# Run one side under the box's guards: bounded bytes (a mis-lowered example
# that loops forever produced 1 GB once — see harness/cap-capture.pl), and a
# session sweep so a process-substitution producer cannot outlive the gate.
run_side() { # run_side <shell-or-bin> <script> <outfile> <cwd>
    # The shell's exit status must be captured SEPARATELY from the byte cap:
    # inside a pipeline $? is the LAST command (the cap), and PIPESTATUS does
    # not survive the subshell. Measured: a script exiting 3 reads as 2 (the
    # cap's own status) the naive way — a vacuous rc comparison, which is the
    # "test that cannot fail" class this repo has been bitten by before.
    local sh="$1" script="$2" out="$3" cwd="$4"
    ( cd "$cwd" && env -u BASH_ENV \
        "$root/harness/kill-session.sh" timeout 20 "$sh" "$script" \
        > "$out.raw" 2>/dev/null; echo $? > "$out.rc" )
    perl "$root/harness/cap-capture.pl" "$CAP" "$(basename "$sh")" \
        < "$out.raw" > "$out"
    rm -f "$out.raw"
}

same=0; differs=0; skipped=0
: > "$T/rows"

for f in "${files[@]}"; do
    script="$sub/examples/$f.sh"
    [ -f "$script" ] || script="$f"
    [ -f "$script" ] || { skipped=$((skipped+1)); continue; }
    d="$T/$(basename "$script")"; mkdir -p "$d/bash" "$d/smoosh"

    shir_out=$("$CLI" "$script" --source-lang sh --target shir --raw 2>/dev/null) || { skipped=$((skipped+1)); continue; }
    [ -z "$shir_out" ] && { skipped=$((skipped+1)); continue; }

    run_side "$(command -v bash)" "$script" "$d/bash/out" "$d/bash"
    run_side "$SMOOSH" "$script" "$d/smoosh/out" "$d/smoosh"

    b_rc=$(cat "$d/bash/out.rc" 2>/dev/null || echo 1)
    s_rc=$(cat "$d/smoosh/out.rc" 2>/dev/null || echo 1)

    if diff -q "$d/bash/out" "$d/smoosh/out" >/dev/null 2>&1 && [ "$b_rc" = "$s_rc" ]; then
        same=$((same+1))
        [ $list -eq 1 ] && printf 'SAME    %s\n' "$f"
    else
        differs=$((differs+1))
        printf 'DIFF    %s (rc bash=%s smoosh=%s)\n' "$f" "$b_rc" "$s_rc"
        printf '%s\t%s\t%s\n' "$f" "$b_rc" "$s_rc" >> "$T/rows"
        [ $list -eq 1 ] && diff "$d/bash/out" "$d/smoosh/out" | head -6
    fi
done

echo "posix-oracle: bash vs smoosh — $same same, $differs differ, $skipped skipped"
[ -s "$T/rows" ] && { echo "--- files where the two oracles disagree:"; cut -f1 "$T/rows" | sed 's/^/    /'; }
cat <<'EOF'
NOTE: a DIFF here is not automatically our bug. It means bash and the POSIX
reference disagree on this program; check it against `dash` (the other
conforming shell on this box) before deciding which side the transpiler
should follow.

FIRST RESULT, with `dash` standing in for Smoosh while the oracle is built
(2026-10-24): `001_simple.sh` DIFFERS — `for i in {1..5}` is a bashism, bash
prints 1..5 and dash prints the literal `{1..5}`. That is the gate doing its
job: the corpus contains bash-only examples, and a bash-vs-bash gate cannot
see them. Run with `--list` to get the per-file diff.
EOF
exit 0
