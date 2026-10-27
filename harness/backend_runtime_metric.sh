#!/usr/bin/env bash
# backend_runtime_metric.sh — count each backend's calls into ITS OWN runtime.
#
# WHY THIS EXISTS. The per-tree board reports, for a green tree, how much it
# still delegates to its runtime. The number it had was the gate's `stub`
# count, which is `grep -cE 'TODO\(unsupported\)|sh2[A-Za-z_0-9]+\('
# (setup_backends.sh:1337). That pattern sees the `sh2_*` namespace ONLY.
#
# The backends do not share that namespace. Measured 2026-09-30 on
# 000__04c_text_processing_commands.sh:
#
#     backend   runtime calls in the output   gate's stub count
#     c             309  _sh_*                        0
#     rust          166  __sh_*                       0
#     perl           33  __sh_*                       0
#     zig            44  sh2*                        (sees it)
#     js/estree      51  sh2.*                       (sees it)
#
# So a 0 from that pattern means "this backend names its runtime something
# else", not "this backend is native" — and the board was printing it as the
# latter. Each namespace below was read off a real render, not guessed.
#
# WHAT IT IS NOT. The totals are NOT comparable across backends as a quality
# ranking: they measure how big each runtime's API is, not how native the
# lowering is. rust delegating 166 times to `__sh_print_words` is not 40x
# worse than python delegating 4 times to `__sh_exec` — a bulk helper can
# replace what another target spells out in many lines. Use the number to
# find the backends still leaning on their runtime, not to rank them.
#
# Usage:  harness/backend_runtime_metric.sh [LANG ...]
# Writes: <tree>/.rt_metric.tsv   (key<TAB>value, `total` first)
#         and prints the same table. progress.sh reads the per-tree file.
set -u
cd "$(dirname "$0")/.."
ROOT="$PWD"
CLI="${OTRANSPILERL_BIN:-$ROOT/otranspilerl/target/debug/otranspilerl-cli}"
export OTRANSPILER_ROOT="${OTRANSPILER_ROOT:-$ROOT}"
# zsh has no --target arm in the CLI; its renderer is the worktree's
# shir_render bin (see render_one).
ZSH_SHIR_RENDER="${ZSH_SHIR_RENDER:-$ROOT/sh2perl/backends/zsh/target/debug/shir_render}"
# SAME REASON for c: the CLI's `--target c` arm links the MAIN tree's
# c_backend.rs, which is a DIFFERENT (older) revision from the worktree the
# c worker actually edits. Measured 2026-10-01 on
# 000__04c_text_processing_commands.sh: main emits 309 `_sh_*` calls, the
# worktree emits 313. Measuring main would report a number that cannot move
# when the worker changes its renderer — the vacuous-measurement bug this
# script exists to prevent, one level up. The gate renders through the
# worktree bin, so the metric must too, or the two disagree about the same
# tree.
C_SHIR_RENDER="${C_SHIR_RENDER:-$ROOT/sh2perl/backends/c/target/debug/shir_render}"

# SAME REASON for perl, and it is NOT hypothetical: `otranspilerl --target
# perl` links the MAIN tree's src/perl_backend.rs (last touched 2026-09-24),
# a DIFFERENT revision from the worktree renderer the perl gate actually runs
# (last touched 2026-10-01). Measured 2026-10-02 on
# 000__04c_text_processing_commands.sh:
#
#     renderer                          lines   __sh_* calls
#     main, via --target perl              363             39
#     worktree, via shir_render            172             57
#
# So the perl number was measuring a stale renderer in a tree no perl worker
# edits — the same vacuous-measurement bug described above for c, and the perl
# worker could never move it by improving the code that is under test.
PERL_SHIR_RENDER="${PERL_SHIR_RENDER:-$ROOT/sh2perl/backends/perl/target/debug/shir_render}"
# Same reasoning as PERL_SHIR_RENDER: fish has no --target on the CLI, so its
# renderer is only reachable via the fish worktree's own shir_render. Pointing
# this at the main tree would measure a tree no fish worker edits.
FISH_SHIR_RENDER="${FISH_SHIR_RENDER:-$ROOT/sh2perl/backends/fish/target/debug/shir_render}"
# SAME REASON for rust, measured 2026-10-03 on 018_grep_params.sh: the CLI's
# `--target rust` arm links the MAIN tree's src/rust_backend.rs, a DIFFERENT
# revision from the worktree renderer the rust gate actually runs.
#
#     renderer                          __sh_* mentions
#     main, via --target rust                   194
#     worktree, via shir_render                 188
#
# The two renders are not even byte-identical. So the rust number was measuring
# a renderer no rust worker edits — the same vacuous-measurement bug described
# above for c and perl, one level up. The gate renders through the worktree bin
# (setup_backends.sh's scaffold arm: g_bin="$g_wt/target/debug/shir_render",
# g_flag="--target=$g_lang"), so the metric must too or the two disagree about
# the same tree.
RUST_SHIR_RENDER="${RUST_SHIR_RENDER:-$ROOT/sh2perl/backends/rust/target/debug/shir_render}"
# SAME REASON for go, measured 2026-10-09 on 018_grep_params.sh: the CLI's
# `--target go` arm links the MAIN tree's src/go_backend.rs via the
# `debashl` path dependency, a DIFFERENT revision from the worktree
# renderer the go gate actually runs.
#
#     renderer                          lines   runtime calls
#     main, via --target go              8633            129
#     worktree, via shir_render          8639            129
#
# (identical counts on that file, but the two renders are not byte-equal —
# the counts will diverge as the worktree renderer improves, and the whole
# point of the number is that the go worker can move it.) The gate renders
# through the worktree bin (setup_backends.sh's scaffold arm:
# g_bin="$g_wt/target/debug/shir_render", g_flag="--target=$g_lang"), so the
# metric must too or the two disagree about the same tree.
GO_SHIR_RENDER="${GO_SHIR_RENDER:-$ROOT/sh2perl/backends/go/target/debug/shir_render}"

[ -x "$CLI" ] || { echo "backend_runtime_metric: $CLI missing" >&2; exit 1; }

# The namespace each renderer actually emits. Keep these in step with the
# renderers; a backend that renames its runtime must be updated here or it
# silently reports 0 — which is the bug this script exists to stop.
SEAM_c='_sh_[A-Za-z_0-9]+'
SEAM_rust='__sh_[A-Za-z_0-9]+'
SEAM_perl='__sh_[A-Za-z_0-9]+'
# perl: the seam above counts IDENTIFIER MENTIONS, and in this renderer every
# one of them is a LEXICAL, not a runtime entry point. Re-measured 2026-10-24
# (20:05) over the 562 corpus renders, the 1113 hits decompose exactly as:
#
#     1040  $__sh_st     the `$?` model scalar (read AND written per command —
#                        the renderer's own bookkeeping, no call, no helper)
#       37  $__sh_ls0    a saved-status temp (`set -o pipefail` restore)
#       26  @__sh_bg     the background pid list
#        8  $__sh_fh0/$__sh_fd3/$__sh_fd5   fd lexicals
#        2  $__sh_eh0
#        0  `__sh_printf_*` helper headers — no call site survives
#
# (The earlier reading of this table was 1109 = 1036 st / 6 fd / 2
# `__sh_printf_*` headers. The two header lines went away when the two
# LITERAL-operand call sites — `__sh_printf_q("\n\t")` in
# parse-dollar-single-quote.sh, `__sh_printf_b("a\\tb\\n")` in
# printf-format-and-v.sh — started folding at render time (`printf_b_decode` /
# `printf_q_quote` in perl_backend.rs run the helper's own table over the
# constant). Today the same 562 renders give 1040 st / 8 fd / 0 headers; the
# old per-bucket numbers no longer apply, and the total alone is not a
# change-detector — which is why the call-site count is reported beside it.)
#
# Counted as CALL SITES — the rule the fish and go seams below already encode —
# the same corpus is ZERO, and has been since those two printf folds landed.
#
# RE-MEASURED 2026-10-25 (11:19) over the 563 corpus renders — one more file
# than the 562 above, because `realpath-cmdsub.sh` had been failing to render
# at ingress (a stale `builtin::BUILTINS` copy: the table gained id/od/panic/
# realpath/tty on main and the worktree had not taken the sync). The 1043 hits
# decompose exactly as:
#
#      970  $__sh_st     the `$?` model scalar
#       37  $__sh_ls0    a saved-status temp (`set -o pipefail` restore)
#       26  @__sh_bg     the background pid list
#        8  $__sh_fh0/$__sh_fd3/$__sh_fd5   fd lexicals
#        2  $__sh_eh0
#        0  call sites (`SEAM_CALL_perl`) — still no runtime ENTRY POINT
#
# The delta from 1113 is all `$__sh_st` (1040 -> 970): the guarded-failure
# fold, the per-statement dead-status liveness, and a new
# `fold_status_chain_else` pass that turns an `A && B || C` chain's two
# sibling `if`s (each re-testing the status, each ending in its own reset)
# into one perl `if`/`else` with the shared reset hoisted below it.
#
# The surviving 970 cannot be lowered: `$__sh_st` is how this renderer models
# `$?`, and a script that reads `$?` needs it whatever the backend does. Both
# numbers are reported (`calls` and `total`) rather than swapping the seam,
# because `total` is the historical series and silently dropping 99.8% of it
# would read as a 1113→2 "win" that no code produced.
SEAM_CALL_perl='__sh_[A-Za-z_0-9]+[[:space:]]*\('
SEAM_python='__sh_[A-Za-z_0-9]+'
SEAM_zig='sh2[A-Za-z_0-9]+'
# go: CALL SITES ONLY, for the same reason as fish above — but the seam is
# not the problem here, the SCOPE is. The go renderer emits its runtime as a
# Go PACKAGE-LEVEL PREAMBLE (`func s2s(x any) string {` … `func redirRun(…)`)
# ahead of `func main`. Grepping the whole file counts the definitions, the
# helpers' own internal calls, and every helper that had to be pulled in
# transitively: measured 2026-10-22 over the 562 corpus renders, 2068 whole-
# file hits of which 1467 are the preamble and 601 are real call sites in the
# program body. A number 71% of which no lowering can move measures the size
# of the emitted library, not how native the lowering is — and it moves BACK
# UP when the renderer lowers something (fewer helpers needed, but a different
# subset). So the count starts at `func main` — the same call-site rule the
# fish seam encodes with its trailing group. (Whole-file figure, for history:
# 2068 on 2026-10-22, 3376 on the pre-WIP renderer of the same corpus.)
SEAM_go='s2s|capRun|capCmd|runCmd|redirRun|redirCap'
# The CALL-SITE column had no go seam, so `calls` on the go row was 0 BY
# CONSTRUCTION (`seam_for` fell back to the empty string and the counter
# never ran) while the body carried 48 real call sites. The board printed
# that 0 as "0 runtime calls / 562 files" — the same vacuous reading this
# script exists to prevent, one column over. `s2s(x any)` is a plain
# function in this renderer, so a call site is the name followed by `(`; a
# bare mention cannot survive the body rule (the definitions are all in the
# preamble, above `func main`). Measured 2026-10-25: 48 body mentions, all
# of them calls.
SEAM_CALL_go='(s2s|capRun|capCmd|runCmd|redirRun|redirCap)[[:space:]]*\('
SEAM_BODY_go='^func main\(\)'
SEAM_java='sh[A-Z][A-Za-z0-9]+'
SEAM_js='sh2\.[A-Za-z_0-9]+'
SEAM_sh='sh2[a-z_]+\('
SEAM_zsh='_[a-z][a-z_0-9]*\('
# fish had SEAM_fish='sh2[a-z_]*\(' — the sh2_* namespace — and reported
# "0 calls / 560 files" forever. That 0 was VACUOUS for exactly the reason
# this script exists: the fish renderer emits no sh2_* name at all, so the
# seam could never see its runtime. Its runtime is a fish-FUNCTION PREAMBLE
# (`function _arr_expand …` … `function _fish_get_el …`) emitted ahead of the
# translated body whenever the file touches a bash array. Measured
# 2026-10-09 over the 644 corpus renders: 8 helpers emitted as a block into
# 23 files (184 definitions), plus 130 CALL sites. A fish function call is
# fish's own naming underneath, which is the trap the old seam fell into —
# `grep 'sh2[a-z_]*('` cannot match `(_arr_expand arr)`.
#
# The seam counts CALL SITES, not mentions: the definition block is emitted
# whole (all 8 helpers) whenever one is needed, so including it would let the
# number move without a single construct being lowered natively. The trailing
# group is what separates the two — a call is followed by `)`, `;`, EOL, or a
# space then a non-`-` argument, while a definition is followed by
# ` --argument-names`. The `\b` is load-bearing: without it the `[a-z_]+`
# backtracks into the identifier (`_arr_expan` + `d`) and every definition
# matches. Measured against the corpus: 130 call sites, 0 definitions.
SEAM_fish='_(arr_[a-z_]+|fish_get_el)\b(\)| [^-]|;|$)'

ext_for() { case "$1" in c) echo c;; rust) echo rs;; perl) echo pl;; python) echo py;;
                  zig) echo zig;; go) echo go;; java) echo java;; js) echo mjs;; sh) echo sh;; zsh) echo zsh;;
                  fish) echo fish;; esac; }
seam_for() { eval "printf '%s' \"\${SEAM_$1:-}\""; }

# Render one corpus file into $out, however that backend's renderer is
# actually reached. The default is the workspace CLI's --target; a backend
# that has no CLI target (zsh: A1 emit via --target shir, then
# shir_render --target zsh reading the shIR JSON on stdin — the same two
# steps the gate runs) gets its own arm.
render_one() {
    local lang="$1" f="$2" out="$3" shir
    case "$lang" in
    zsh)
        [ -x "$ZSH_SHIR_RENDER" ] || return 1
        shir=$("$CLI" --target shir "$f" 2>/dev/null) || return 1
        [ -n "$shir" ] || return 1
        printf '%s' "$shir" | "$ZSH_SHIR_RENDER" --target=zsh - > "$out" 2>/dev/null || return 1
        ;;
    c)
        [ -x "$C_SHIR_RENDER" ] || return 1
        shir=$("$CLI" --target shir "$f" 2>/dev/null) || return 1
        [ -n "$shir" ] || return 1
        printf '%s' "$shir" | "$C_SHIR_RENDER" --target=c - > "$out" 2>/dev/null || return 1
        ;;
    perl)
        # The worktree bin, for the same reason as c: --target perl would
        # measure the main tree's stale perl_backend.rs, not the renderer
        # under test. See the PERL_SHIR_RENDER comment above.
        [ -x "$PERL_SHIR_RENDER" ] || return 1
        shir=$("$CLI" --target shir "$f" 2>/dev/null) || return 1
        [ -n "$shir" ] || return 1
        printf '%s' "$shir" | "$PERL_SHIR_RENDER" --target=perl - > "$out" 2>/dev/null || return 1
        ;;
    fish)
        # The worktree bin, for the same reason as c: the CLI has no --target
        # fish, so the default arm would fail and the backend would be SKIPPED
        # (counting as "no calls" and looking perfectly native). fish is only
        # reachable through shir_render --target fish.
        [ -x "$FISH_SHIR_RENDER" ] || return 1
        shir=$("$CLI" --target shir "$f" 2>/dev/null) || return 1
        [ -n "$shir" ] || return 1
        printf '%s' "$shir" | "$FISH_SHIR_RENDER" --target=fish - > "$out" 2>/dev/null || return 1
        ;;
    rust)
        # The worktree bin, for the same reason as c: --target rust would
        # measure the main tree's stale rust_backend.rs, not the renderer
        # under test. See the RUST_SHIR_RENDER comment above.
        [ -x "$RUST_SHIR_RENDER" ] || return 1
        shir=$("$CLI" --target shir "$f" 2>/dev/null) || return 1
        [ -n "$shir" ] || return 1
        printf '%s' "$shir" | "$RUST_SHIR_RENDER" --target=rust - > "$out" 2>/dev/null || return 1
        ;;
    go)
        # The worktree bin, for the same reason as c: --target go would
        # measure the main tree's stale go_backend.rs, not the renderer
        # under test. See the GO_SHIR_RENDER comment above.
        [ -x "$GO_SHIR_RENDER" ] || return 1
        shir=$("$CLI" --target shir "$f" 2>/dev/null) || return 1
        [ -n "$shir" ] || return 1
        printf '%s' "$shir" | "$GO_SHIR_RENDER" --target=go - > "$out" 2>/dev/null || return 1
        ;;
    *)
        "$CLI" "$f" "$out" --target "$lang" >/dev/null 2>&1 || return 1
        ;;
    esac
    [ -s "$out" ]
}

# The tree a backend's gate lives in, so the number lands beside the gate's
# own state (fail-estree's $outdir rule: a worker's state is its own).
tree_for() { case "$1" in estree) echo estree;; *) echo "$1";; esac; }

LANGS="${*:-c rust perl python zig go java js}"
CORPUS=("$ROOT"/sh2perl/examples/*.sh)
[ -e "${CORPUS[0]}" ] || { echo "no corpus under sh2perl/examples" >&2; exit 1; }

printf '%-8s %8s %10s %12s  %8s   %s\n' backend files mentions per_file calls namespace
for lang in $LANGS; do
    seam=$(seam_for "$lang")
    [ -n "$seam" ] || { printf '%-8s (no seam defined — update SEAM_%s)\n' "$lang" "$lang"; continue; }
    ext=$(ext_for "$lang")
    tree=$(tree_for "$lang")
    callseam=$(eval "printf '%s' \"\${SEAM_CALL_$lang:-}\"")
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    files=0; total=0; calls=0
    for f in "${CORPUS[@]}"; do
        [ -f "$f" ] || continue
        out="$tmp/$(basename "$f").$ext"
        # A render that fails is SKIPPED, not counted as zero calls: an
        # unrenderable file has no output to measure, and counting it as 0
        # would make a broken backend look like a native one.
        #
        # A backend whose target the CLI does not know (zsh reaches its
        # renderer only through shir_render, not --target) would skip
        # EVERY file and report files=0 calls=0 — the exact vacuous reading
        # this script exists to prevent, one level up. A zero-file result is
        # therefore an error here, not a green backend.
        if render_one "$lang" "$f" "$out"; then
            # SEAM_BODY_<lang> restricts the count to the program body (the
            # lines from that marker on): a runtime emitted as a whole block
            # ahead of the body is the library, not the renderer's calls.
            bodyfrom=$(eval "printf '%s' \"\${SEAM_BODY_$lang:-}\"")
            if [ -n "$bodyfrom" ]; then
                n=$(awk -v m="$bodyfrom" '$0 ~ m { on = 1 } on' "$out" 2>/dev/null | grep -oE "$seam" | wc -l)
            else
                n=$(grep -oE "$seam" "$out" 2>/dev/null | wc -l)
            fi
            total=$((total + n)); files=$((files + 1))
            # SEAM_CALL_<lang>: the CALL-SITE count. Only a name immediately
            # followed by an open paren is a runtime entry point; a bare
            # identifier is a lexical the renderer declared for its own
            # bookkeeping. Subtracting the definitions keeps an emitted
            # helper's own signature out of the count.
            if [ -n "$callseam" ]; then
                if [ -n "$bodyfrom" ]; then
                    nc=$(awk -v m="$bodyfrom" '$0 ~ m { on = 1 } on' "$out" 2>/dev/null | grep -oE "$callseam" | wc -l)
                else
                    nc=$(grep -oE "$callseam" "$out" 2>/dev/null | wc -l)
                fi
                nd=$(grep -cE "sub[[:space:]]+$callseam" "$out" 2>/dev/null || true)
                calls=$((calls + nc - ${nd:-0}))
            fi
        fi
    done
    if [ "$files" -eq 0 ]; then
        printf '%-8s (0 files rendered — target not reachable from this CLI)\n' "$lang"
        continue
    fi
    per=$( [ "$files" -gt 0 ] && echo $((total / files)) || echo 0 )
    if [ -n "$callseam" ]; then
        printf '%-8s %8d %10d %12d  %8d   %s\n' "$lang" "$files" "$total" "$per" "$calls" "$seam"
    else
        printf '%-8s %8d %10d %12d  %8s   %s\n' "$lang" "$files" "$total" "$per" "-" "$seam"
    fi
    # Per-tree artefact for progress.sh, written into the tree the gate for
    # this backend measures — same rule fail-estree uses, so two workers
    # measuring two trees cannot clobber each other.
    outdir="$ROOT/sh2perl/backends/$tree"
    [ -d "$outdir" ] || outdir="$ROOT/sh2perl"
    {
        printf 'total\t%d\n' "$total"
        printf 'files\t%d\n' "$files"
        printf 'per_file\t%d\n' "$per"
        printf 'calls\t%d\n' "$calls"
        printf 'seam\t%s\n' "$seam"
    } > "$outdir/.rt_metric.tsv"
    rm -rf "$tmp"; trap - EXIT
done
