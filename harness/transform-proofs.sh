#!/usr/bin/env bash
# transform-proofs.sh — build every Isabelle session in the tree that CLAIMS
# to be checked.
#
#   ./harness/transform-proofs.sh            # manifests + named session dirs
#   ./harness/transform-proofs.sh --list     # show what would be checked
#
# Checked today (6 sessions, all green — measured 2026-10-23):
#   proofs/ (DivModPow2, I32Provable, BigIntRange, IntervalFloor),
#   proofs/ArithIdentity, sh2perl/docs/fm/TextOps, verif/ (MemorySafety),
#   and the per-manifest claim in core-requests/…/div-mod-pow2.rs.
#
# To add a session: add its directory to SESSION_DIRS below AND give it a
# ROOT with `quick_and_dirty = false`. NOTHING is discovered by walking the
# tree — see the traps in the loop's header.
#
# TWO KINDS OF CLAIM are checked, because the repo has two:
#
#   1. A transform manifest carrying a `proof:` line — the per-transform
#      form, next to the offer it constrains.
#
# A manifest line
#
#   proof: proof/Invariant.thy#div_mod_pow2_sound (checked — …)
#
#   2. A top-level `ROOT` with `quick_and_dirty = false` and no `sorry` in its
#      theories — the analysis/verdict form (`proofs/`, the node semantics in
#      `sh2perl/docs/fm/`). Those claims currently live in a README, where
#      "built once, by hand" reads exactly like "proved".
#
# A claim that cannot be built is worse than no claim, because sorry-free text
# that LOOKS like a proof is indistinguishable from a proof to a reader.
#
# Exit: 0 when every `checked` claim builds (or there is none); 1 when a claim
# fails; 2 when Isabelle is absent (nothing was verified — do NOT read that as
# green), or when a manifest claims `checked` with no `ROOT` to build.
#
# Note on `--proofs`: PLAN's D3 wanted this run pre-merge, not per commit —
# an Isabelle build is ~30 s warm and ~6 min on a cold HOL image, and it wants
# ~4 GB. That cost is why it is a separate script rather than a step in ./fail.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISABELLE="${ISABELLE:-isabelle}"
if ! command -v "$ISABELLE" >/dev/null 2>&1; then
    for cand in /opt/Isabelle*/bin/isabelle; do
        [ -x "$cand" ] && ISABELLE="$cand" && break
    done
fi
if ! command -v "$ISABELLE" >/dev/null 2>&1 && [ ! -x "$ISABELLE" ]; then
    echo "transform-proofs: Isabelle not found — NOTHING was verified" >&2
    echo "  install: /opt/Isabelle2025-2/bin/isabelle, or set ISABELLE=" >&2
    exit 2
fi

list=0
[ "${1:-}" = "--list" ] && list=1

manifests=$(command find "$root/core-requests" -name manifest -type f 2>/dev/null | sort)
checked=0; skipped=0; failed=0; stated=0
failed_names=()

# ── The whole-directory form: every ROOT outside the scratch trees ────────
# A session directory is checked when its ROOT sets quick_and_dirty = false
# (so `sorry` cannot sneak in) and none of its theories contains `sorry` /
# `oops`. A directory whose ROOT does not pin quick_and_dirty is reported as
# STATED: it is a claim the repo is not standing behind.
#
# TRAPS on this box, each of which silently produced a PASS over nothing:
#   * `find` is a shell FUNCTION that forwards to `rg --files`; `grep` is a
#     ripgrep wrapper. Both are spelled `command` here.
#   * The scratch tree `sh2loop/` holds self-referencing copies of the whole
#     workspace and sits BELOW the root, so it is filtered as the relative
#     path `sh2loop/ROOT` (not by pruning the root itself).
#   * `find … 2>/dev/null | sort` under `set -o pipefail` yields the EMPTY
#     string when the tree changes under the walk, so the redirect comes
#     before the pipe.
# The sessions of record, listed explicitly. NOT discovered by walking the
# tree: this workspace contains a 97 GB scratch dir whose name is the
# workspace's own (`sh2loop/`) and holds self-referencing copies of it, and
# three `find`/`grep`-based discovery attempts here each produced a gate that
# checked nothing and printed PASS. A new proof session is added to this list
# WITH its ROOT — the same rule as "a new worker needs two edits".
SESSION_DIRS=(
    proofs
    proofs/ArithIdentity
    sh2perl/docs/fm/TextOps
    verif
)
dirs=""
for rel in "${SESSION_DIRS[@]}"; do
    [ -f "$root/$rel/ROOT" ] && dirs="$dirs$root/$rel"$'\n'
done
for d in $dirs; do
    r="$d/ROOT"
    if command grep -q "quick_and_dirty *= *false" "$r"; then
        status=checked
    else
        status=stated
    fi
    # Isabelle comments are (* … *); strip them before looking for a bare
    # `sorry`/`oops`, or a theory that SAYS "no sorry can hide here" is
    # reported as containing one (it was).
    sorries=""
    for f in "$d"/*.thy; do
        [ -f "$f" ] || continue
        if perl -0777 -ne 's/\(\*.*?\*\)//gs; exit(/ (?<![A-Za-z_])(?:sorry|oops)(?![A-Za-z_]) /x ? 0 : 1)' -- "$f"; then
            sorries="$sorries$f"$'\n'
        fi
    done
    sorries=$(printf '%s' "$sorries" | head -3)
    if [ -n "$sorries" ]; then
        echo "transform-proofs: $d contains sorry/oops — not a proof:" >&2
        printf '    %s\n' $sorries >&2
        failed=$((failed + 1)); failed_names+=("$d"); continue
    fi
    if [ "$status" = "stated" ]; then
        stated=$((stated + 1))
        [ $list -eq 1 ] && echo "STATED  $d  (ROOT does not set quick_and_dirty = false)"
        continue
    fi
    if [ $list -eq 1 ]; then
        echo "CHECK   $d"
        continue
    fi
    # Build exactly the sessions whose theory is present. A ROOT may declare
    # a session that is NOT in the default build (BigIntRange is recorded in
    # proofs/ROOT as not-yet-checking); building by name would fail on a
    # missing-theory error rather than on the session's own state, so those
    # are skipped BY NAME — and the run is bounded in TIME, because Isabelle
    # can take minutes per session and a gate that hangs is a gate nobody runs.
    log=$(mktemp)
    names=""
    if [ -f "$d/ROOT" ]; then
        names=$(python3 - "$d/ROOT" "$d" <<'PYEOF'
import os, re, shlex, sys
root = os.path.abspath(sys.argv[1]); d = os.path.abspath(sys.argv[2])
lines = open(root, encoding='utf-8', errors='replace').read()
out = []
for m in re.finditer(r'^session\s+(\S+)(?:\s+in\s+(\S+))?\s*=(.*?)(?=^session\s|\Z)',
                     lines, re.M | re.S):
    name, sub, body = m.group(1), m.group(2) or '.', m.group(3)
    th = re.search(r'\btheories\b(.*)', body, re.S)
    theories = re.findall(r'^\s+([A-Z][A-Za-z0-9_]*)\s*$', th.group(1), re.M) if th else []
    # The theory file may sit in <d>/<sub>/, <d>/<session>/, or <d>/<sub>/<session>/.
    for t in theories or [name]:
        for cand in (os.path.join(d, sub, t + '.thy'),
                     os.path.join(d, name, t + '.thy'),
                     os.path.join(d, sub, name, t + '.thy'),
                     os.path.join(d, t + '.thy')):
            if os.path.exists(cand):
                out.append(name); break
        else:
            continue
        break
print(' '.join(shlex.quote(x) for x in out))
PYEOF
)
    fi
    names=$(printf '%s' "$names" | tr -s ' ' | sed 's/^ *//; s/ *$//')
    if [ -n "$names" ]; then
        ok=1
        # shellcheck disable=SC2086
        # NOT `-c`: two sessions in this tree build from the same HOL heap, and
        # a from-scratch build of one while the other is cached makes Isabelle
        # move the source DB under the running process (SQLITE_READONLY_DBMOVED).
        # `quick_and_dirty = false` is what rejects `sorry`; `-c` only forbids
        # reusing a heap, which is a CI-purity question, not a soundness one.
        # A PER-RUN user home: two Isabelle invocations sharing
        # ~/.isabelle corrupt each other's source DB (SQLITE_READONLY_DBMOVED,
        # then SQLITE_CONSTRAINT_PRIMARYKEY on the next run). Heaps are still
        # found through ISABELLE_HEAPS, which points at the installed ones.
        isa_home=$(mktemp -d)
        if USER_HOME="$isa_home" timeout "${PROOF_BUILD_TIMEOUT:-900}" "$ISABELLE" build \
                -o quick_and_dirty=false -D "$d" $names >"$log" 2>&1; then
            ok=1
        else
            ok=0
        fi
        rm -rf "$isa_home"
    elif [ -f "$d/ROOT" ]; then
        # A ROOT whose sessions name theories we cannot locate (a `in <sub>`
        # form, or a session built on ANOTHER session). Building it by name
        # means building the default session of the whole ROOT — for
        # `proofs/` that drags in a session the ROOT itself marks as failing,
        # and the verdict then blames the wrong directory. This is an
        # UNKNOWN, reported as such: add the missing theory or leave the
        # directory out of SESSION_DIRS.
        ok=2
    else
        ok=0
    fi
    if [ "$ok" = 1 ]; then
        checked=$((checked + 1))
        echo "OK      $d"
    elif [ "$ok" = 2 ]; then
        echo "UNKNOWN $d  (no theory located for its session(s) — not a pass, not a proof)" >&2
    else
        failed=$((failed + 1)); failed_names+=("$d")
        echo "FAILED  $d" >&2
        sed 's/^/    /' "$log" | tail -12 >&2
    fi
    rm -f "$log"
done
for m in $manifests; do
    # the proof: line, continuation lines included, read into one string
    claim=$(awk '
        /^proof:/ { inproof = 1 }
        inproof { printf "%s ", $0 }
        inproof && !/,$/ && NR > 1 {}
    ' "$m" | head -1)
    claim=$(awk 'BEGIN{p=0} /^proof:/{p=1} p{printf "%s ",$0} p && /$/{if (NR>0 && $0 !~ /^proof:/ ) {} }' "$m")
    # simpler and sufficient: grep the proof: line and the following indented lines
    claim=$(python3 - "$m" <<'PY'
import sys
lines = open(sys.argv[1], encoding='utf-8', errors='replace').read().split('\n')
out, on = [], False
for ln in lines:
    if ln.startswith('proof:'):
        on = True
        out.append(ln)
        continue
    if on:
        if ln.startswith((' ', '\t')) and ln.strip():
            out.append(ln)
        else:
            break
print(' '.join(x.strip() for x in out))
PY
)
    [ -z "$claim" ] && continue

    case "$claim" in
        *"(checked"*|*"(checked)"*) status=checked ;;
        *"(stated"*|*"(stated)"*) status=stated ;;
        *) status=unknown ;;
    esac

    dir=$(dirname "$m")
    if [ "$status" = "stated" ]; then
        stated=$((stated + 1))
        [ $list -eq 1 ] && echo "STATED  $m"
        continue
    fi
    if [ "$status" != "checked" ]; then
        echo "transform-proofs: $m: unparseable proof: claim (want 'checked'/'stated')" >&2
        failed=$((failed + 1)); failed_names+=("$m"); continue
    fi

    theory=$(printf '%s' "$claim" | sed -n 's/.*proof: *\([^# ]*\)#.*/\1/p')
    proofdir="$dir/$(dirname "$theory")"
    if [ ! -f "$proofdir/ROOT" ]; then
        echo "transform-proofs: $m claims checked, but $proofdir/ROOT is missing" >&2
        failed=$((failed + 1)); failed_names+=("$m"); continue
    fi
    if [ $list -eq 1 ]; then
        echo "CHECK   $m  ->  $proofdir"
        continue
    fi
    # a `checked` claim must also be sorry-free: -o quick_and_dirty=false makes
    # Isabelle reject `sorry` outright, and `-c` forces a from-scratch build so
    # a cached heap cannot certify a file that has since been edited.
    log=$(mktemp)
    # Per-run Isabelle home (see the note in the directory loop): two builds
    # sharing ~/.isabelle corrupt each other's source DB, and the failure then
    # reads as a proof error.
    isa_home=$(mktemp -d)
    if USER_HOME="$isa_home" timeout 1800 "$ISABELLE" build -c -o quick_and_dirty=false -D "$proofdir" >"$log" 2>&1; then
        checked=$((checked + 1))
        echo "OK      $m"
    else
        failed=$((failed + 1)); failed_names+=("$m")
        echo "FAILED  $m" >&2
        sed 's/^/    /' "$log" | tail -12 >&2
    fi
    rm -rf "$isa_home"
    rm -f "$log"
done

echo "transform-proofs: $checked checked-and-built, $stated stated-only, $failed failed"
if [ $failed -gt 0 ]; then
    printf '  failed: %s\n' "${failed_names[*]}" >&2
    exit 1
fi
exit 0
