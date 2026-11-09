#!/usr/bin/env bash
# a1_store_write_soundness.sh — does the A1 exporter account for every write a
# STORE-WRITING BUILTIN performs?
#
# WHY THIS EXISTS. `classify_builtin_writes` (sh2perl/src/transforms/
# copy_propagation.rs) feeds the copy-propagation fold table. It strips '-'
# from a builtin's argument BEFORE deciding the argument is a flag:
#
#     let s = s.trim_start_matches('-');
#     if s.is_empty() || (s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) {
#         continue;                             // "a flag like -i/-r/-x"
#     }
#
# so a 1-2 letter VARIABLE NAME in `unset x` / `read x` is dropped as if it were
# `-x`. No write is recorded, the variable keeps its single-def literal, and the
# fold substitutes that STALE value into later reads — `${x:-gone}` becomes the
# literal "5" right there in the A1:
#
#     $ otranspilerl-cli --target shir t70_unset.sh |
#           jq -c '.stmts[2].expr.args[1].elements[0]'
#     {"style":"DoubleQuoted","type":"Str","value":"5"}      # "gone" is not in the IR
#
# That is A1-CONTRACT CORRUPTION, not a renderer defect: every backend is handed
# a program whose printed output contradicts bash, and no renderer can recover
# the word that was folded away. It is also COMMITTED code (HEAD is already
# wrong on the plain-read form `x=5; unset x; echo "$x"`); the uncommitted
# param-const-fold WIP in the live checkout widens it to the `${v:-word}` family.
#
# THIS SCRIPT is the runnable oracle for that class, so the next reader does not
# have to re-derive it from a corpus diff: bash is the expected output, the A1
# goes through the perl renderer and is executed, and every NAME-LENGTH case is
# covered — because name length is the whole bug (len<=2 = mistaken for a flag,
# len>=3 = survives, which is why a 3-letter control is in the matrix).
#
# It stays RED until the core fix lands. Green means the write accounting is
# sound for these builtins; it does not mean the rest of A1 is sound.
#
# Usage:
#   harness/a1_store_write_soundness.sh          # full matrix
#   harness/a1_store_write_soundness.sh -v       # also print the A1 verdict per case
#   harness/a1_store_write_soundness.sh --a1     # dump each case's A1 (core debugging)
#
# Exit: 0 = every case matches bash, 1 = at least one case is corrupted,
#       2 = the measurement could not run (missing emitter/renderer — NOT a pass).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMITTER="${OTRANSPILERL_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
RENDER="${PERL_SHIR_RENDER:-$ROOT/sh2perl/backends/perl/target/debug/shir_render}"
export OTRANSPILER_ROOT="${OTRANSPILER_ROOT:-$ROOT}"

VERBOSE=0
DUMP_A1=0
case "${1:-}" in
    -v) VERBOSE=1 ;;
    --a1) DUMP_A1=1; VERBOSE=1 ;;
esac

missing=0
[ -x "$EMITTER" ] || { echo "a1_store_write_soundness: no A1 emitter at $EMITTER" >&2; missing=1; }
[ -x "$RENDER" ]  || { echo "a1_store_write_soundness: no perl renderer at $RENDER" >&2; missing=1; }
command -v perl >/dev/null 2>&1 || { echo "a1_store_write_soundness: perl not on PATH" >&2; missing=1; }
[ "$missing" -eq 0 ] || { echo "  (build them: cargo build -p otranspilerl --bin otranspilerl-cli; cargo build --manifest-path $ROOT/sh2perl/backends/perl/Cargo.toml --bin shir_render)" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# One case per line: bash source with ';' for newlines, then the builtin and the
# NAME LENGTH that decide the verdict. The expected output is never baked in —
# it is whatever bash does to the same source.
CASES=(
    # --- unset, the family the corpus cell (t70_unset.sh) exercises -----------
    'unset|len1|:-|x=5;unset x;echo "${x:-gone}"'
    'unset|len1|plain|x=5;unset x;echo "$x"'
    'unset|len1|-|dash-op|x=5;unset x;echo "${x-gone}"'
    'unset|len1|:=|assign-op|x=5;unset x;echo "${x:=gone}";echo "$x"'
    'unset|len1|flag-v|x=5;unset -v x;echo "${x:-gone}"'
    'unset|len1|multi|x=5;unset y x;echo "${x:-gone}"'
    'unset|len2|:-|ab=5;unset ab;echo "${ab:-gone}"'
    'unset|len3|:-|CONTROL|abc=5;unset abc;echo "${abc:-gone}"'
    # --- read, same accounting hole (the operand is a NAME, not a flag) ------
    'read|len1|:-|x=5;read x </dev/null;echo "${x:-gone}"'
    'read|len3|:-|CONTROL|abc=5;read abc </dev/null;echo "${abc:-gone}"'
)

pass=0; fail=0; failed_names=""
n=0
for row in "${CASES[@]}"; do
    case_spec="${row##*|}"            # the trailing field is always the source
    n=$((n + 1))
    src="$tmp/case$n.sh"
    printf '%s\n' "$case_spec" | tr ';' '\n' > "$src"
    name="$(echo "$case_spec" | cut -c1-46)"

    bash -n "$src" 2>/dev/null || { echo "SKIP  $name  (bash cannot parse the case — fix the matrix)"; continue; }
    expected="$(bash "$src" 2>/dev/null)"

    a1="$("$EMITTER" --target shir "$src" 2>/dev/null)" || {
        echo "UNMEASURED  $name  (core A1 emit failed — not a pass)"; fail=$((fail + 1)); failed_names="$failed_names $n"; continue; }
    [ -n "$a1" ] || { echo "UNMEASURED  $name  (core A1 emitted nothing — not a pass)"; fail=$((fail + 1)); failed_names="$failed_names $n"; continue; }

    actual="$(printf '%s' "$a1" | "$RENDER" --target=perl - 2>/dev/null | perl 2>/dev/null)"

    # Which layer dropped the expansion, and how many? `SH2_TRANSFORMS` is a
    # comma-separated ALLOW list (empty/unset = every transform), so a name that
    # matches no registered transform runs NOTHING — that emit is the
    # frontend's own output, the reference for what the program really contains.
    # Fewer read nodes in the default emit means a fold removed them.
    a1_raw="$(SH2_TRANSFORMS='no-such-transform' "$EMITTER" --target shir "$src" 2>/dev/null)"
    read_nodes() { printf '%s' "$1" | grep -oE '"(param|getVar)"' | wc -l; }
    n_raw="$(read_nodes "$a1_raw")"
    n_default="$(read_nodes "$a1")"
    if [ "$n_default" -lt "$n_raw" ]; then
        a1_verdict="FOLDED-BY-CORE ($n_raw read nodes -> $n_default)"
    else
        a1_verdict="expansion-intact ($n_default read nodes)"
    fi

    [ "$DUMP_A1" -eq 1 ] && printf '  A1: %s\n' "$a1"

    if [ "$expected" = "$actual" ]; then
        pass=$((pass + 1))
        [ "$VERBOSE" -eq 1 ] && printf 'PASS  %-46s printf %%s %s\n' "$name" "$(printf '%s' "$actual" | tr '\n' ' ')"
    else
        fail=$((fail + 1)); failed_names="$failed_names $n"
        printf 'FAIL  %-46s bash=[%s] perl=[%s]  A1: %s\n' \
            "$name" "$(printf '%s' "$expected" | tr '\n' ' ')" "$(printf '%s' "$actual" | tr '\n' ' ')" "$a1_verdict"
        if [ "$n_default" -lt "$n_raw" ]; then
            printf '      -> the untransformed emit carries %s read node(s), the default emit %s:\n' "$n_raw" "$n_default"
            printf '         the fold in copy_propagation removed the rest (core bug, not a renderer gap)\n'
        fi
    fi
done

total=$((pass + fail))
echo
printf '[a1-store-writes] %d/%d cases match bash, %d corrupted — spec: unset/read operand names are WRITES\n' \
    "$pass" "$total" "$fail"
if [ "$total" -eq 0 ]; then
    echo "  no case could be measured — that is NOT a pass" >&2
    exit 2
fi
if [ "$fail" -gt 0 ]; then
    echo "fails:$failed_names"
    echo "  fix: classify_builtin_writes must decide 'flag' from the argument's OWN leading '-',"
    echo "       never from the text left after trim_start_matches('-'):"
    echo "         let dashed = s.starts_with('-');"
    echo "         if s.is_empty() || (dashed && s.chars().all(|c| c.is_ascii_alphabetic()) && s.len() <= 2) { continue; }"
    exit 1
fi
exit 0
