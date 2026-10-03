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

[ -x "$CLI" ] || { echo "backend_runtime_metric: $CLI missing" >&2; exit 1; }

# The namespace each renderer actually emits. Keep these in step with the
# renderers; a backend that renames its runtime must be updated here or it
# silently reports 0 — which is the bug this script exists to stop.
SEAM_c='_sh_[A-Za-z_0-9]+'
SEAM_rust='__sh_[A-Za-z_0-9]+'
SEAM_perl='__sh_[A-Za-z_0-9]+'
SEAM_python='__sh_[A-Za-z_0-9]+'
SEAM_zig='sh2[A-Za-z_0-9]+'
SEAM_go='s2s|capRun|capCmd|runCmd|redirRun|redirCap'
SEAM_java='sh[A-Z][A-Za-z0-9]+'
SEAM_js='sh2\.[A-Za-z_0-9]+'
SEAM_sh='sh2[a-z_]+\('
SEAM_zsh='_[a-z][a-z_0-9]*\('
# fish has no sh2.* runtime at all: the renderer lowers every construct it can
# into native fish (`set`, `math`, `(cmd)`, `begin`/`end`), so the namespace to
# count is the same sh2.* one the gate's stub check uses. Kept identical to
# SEAM_sh on purpose — a fish render that DOES emit sh2_* is a regression, and
# this must count it rather than reporting a vacuous 0.
SEAM_fish='sh2[a-z_]*\('

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

printf '%-8s %8s %10s %12s  %s\n' backend files calls per_file namespace
for lang in $LANGS; do
    seam=$(seam_for "$lang")
    [ -n "$seam" ] || { printf '%-8s (no seam defined — update SEAM_%s)\n' "$lang" "$lang"; continue; }
    ext=$(ext_for "$lang")
    tree=$(tree_for "$lang")
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    files=0; total=0
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
            n=$(grep -oE "$seam" "$out" 2>/dev/null | wc -l)
            total=$((total + n)); files=$((files + 1))
        fi
    done
    if [ "$files" -eq 0 ]; then
        printf '%-8s (0 files rendered — target not reachable from this CLI)\n' "$lang"
        continue
    fi
    per=$( [ "$files" -gt 0 ] && echo $((total / files)) || echo 0 )
    printf '%-8s %8d %10d %12d  %s\n' "$lang" "$files" "$total" "$per" "$seam"
    # Per-tree artefact for progress.sh, written into the tree the gate for
    # this backend measures — same rule fail-estree uses, so two workers
    # measuring two trees cannot clobber each other.
    outdir="$ROOT/sh2perl/backends/$tree"
    [ -d "$outdir" ] || outdir="$ROOT/sh2perl"
    {
        printf 'total\t%d\n' "$total"
        printf 'files\t%d\n' "$files"
        printf 'per_file\t%d\n' "$per"
        printf 'seam\t%s\n' "$seam"
    } > "$outdir/.rt_metric.tsv"
    rm -rf "$tmp"; trap - EXIT
done
