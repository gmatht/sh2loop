#!/usr/bin/env bash
# c-memory-safety.sh — measure the C backend's heap discipline, and prove the
# abstraction the ownership proof depends on.
#
#   ./harness/c-memory-safety.sh            # measure (sanitizer arm over renders)
#   ./harness/c-memory-safety.sh --theory   # build verif/MemorySafety.thy
#
# WHAT THIS ANSWERS. "Can Isabelle prove the C backend produces no
# use-after-free?" The end-to-end form is out of reach for the same reason
# C_UB_PROOF.md gives for UB (§3): the `_sh_*` runtime, the frontend and the
# stubs are unproved, so the property would quantify over hand-written C.
# The PER-PROGRAM form is reachable, and `verif/MemorySafety.thy` states it:
#
#   render_program `frees`  ==
#     `lifetimes`  -- the `--target c` program's own free sites, taken from the
#                     renderer's `var_lifetimes`/`site_file_vars` filter
#                     (`emit_fn_frees_excluding`) — never hand-written;
#     `stmts`      -- the A1 the renderer received (the frontend contract);
#     `free`/`malloc`/`call`/... -- the `_sh_*` runtime's behaviour.
#
# The theorem then says: on a trace whose runtime actions ARE that model, no
# load or store touches a freed block. The model of the runtime is the HOLE —
# the file states it as an explicit assumption, so what is proved is "given
# this runtime, the generated frees are safe", not "the C is safe".
#
# MEASUREMENT FIRST (the same rule C_UB_PROOF.md §4 sets). Free-site bugs in
# this backend are documented by measurement, not by argument: `:8278` records
# a real dangling read found by hand (`gv=<garbage>`), and `--warn`-class
# truncations were found only when someone ran gcc over every render. The
# sanitizer arm here is the instrument; the theory is the certificate. A
# theory for a class the instrument never sees is worth nothing, and the
# reverse (measure, never mechanize) lets a fixed bug come back silently.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode=measure
[ "${1:-}" = "--theory" ] && mode=theory

ISABELLE="${ISABELLE:-isabelle}"
if ! command -v "$ISABELLE" >/dev/null 2>&1; then
    for cand in /opt/Isabelle*/bin/isabelle; do
        [ -x "$cand" ] && ISABELLE="$cand" && break
    done
fi

if [ "$mode" = "theory" ]; then
    if ! { command -v "$ISABELLE" >/dev/null 2>&1 || [ -x "$ISABELLE" ]; }; then
        echo "c-memory-safety: Isabelle not found — theory NOT built" >&2
        exit 2
    fi
    # `command find`: see harness/transform-proofs.sh — the shell's `find` is
    # a wrapper here and ignores -prune/-o.
    d=$(command find "$root/verif" -maxdepth 2 -name MemorySafety.thy -print 2>/dev/null | head -1)
    if [ -z "$d" ]; then
        echo "c-memory-safety: verif/MemorySafety.thy missing" >&2
        exit 2
    fi
    log=$(mktemp)
    if timeout 1800 "$ISABELLE" build -c -o quick_and_dirty=false -D "$(dirname "$d")" MemorySafety >"$log" 2>&1; then
        echo "OK      $d"
        rm -f "$log"
        exit 0
    fi
    echo "FAILED  $d" >&2
    sed 's/^/    /' "$log" | tail -20 >&2
    rm -f "$log"
    exit 1
fi

# ── the measurement arm ──────────────────────────────────────────────────
if [ ! -x "$root/harness/c_gate_ubsan.sh" ]; then
    echo "c-memory-safety: harness/c_gate_ubsan.sh missing" >&2
    exit 2
fi
echo "c-memory-safety: the instrument is harness/c_gate_ubsan.sh (UB+ASan over"
echo "  every C render, with positive controls). Its verdict classes do NOT"
echo "  separate 'freed then read' from other ASan reports, so this arm runs"
echo "  it whole and then greps the report log for the heap-use-after-free"
echo "  class specifically."
"$root/harness/c_gate_ubsan.sh" "$@"
rc=$?
LOG=$(ls -t "$root"/gate-reports/*ubsan*.log 2>/dev/null | head -1)
if [ -n "$LOG" ]; then
    n=$(grep -c "heap-use-after-free\|heap-use-after-free on address" "$LOG" 2>/dev/null || true)
    echo "c-memory-safety: heap-use-after-free reports in $LOG: ${n:-0}"
fi
echo "c-memory-safety: the theory for this class is verif/MemorySafety.thy"
echo "  (run with --theory); it proves the per-program obligation GIVEN the"
echo "  runtime model stated in the file, not end-to-end."
exit $rc
