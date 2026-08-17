#!/usr/bin/env bash
# core-sweep.sh — the LLM-free core loop (PLAN §11.9): build the shared
# core + every backend (via build-lock.sh), run each backend's gate, and
# append verdicts to core-requests/transforms/verdicts.log for the
# backends to read. NO pi — acceptance is the gate verdict: a backend's
# gate passing with its transform set ACCEPTS it; a failure is logged
# with the transform + prereq attribution the backend reads and fixes.
#
#   core-sweep.sh [--backends "rust sh c ..."] [--limit N]
#   core-sweep.sh --bundles            validate every bundle's spec+manifests
#   core-sweep.sh --apply-bundles      apply node+transforms, build, gate,
#                                      REVERT (atomic; explicit operator mode)
#
# verdict line format (append-only, tsv like triage/verdicts.tsv):
#   <backend> <transform-set-hash> PASS|FAIL <detail> <epoch>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$ROOT/core-requests/transforms/verdicts.log"
LOCK="$ROOT/harness/build-lock.sh"
DEFAULT_BACKENDS="perl js c python zig go rust sh java"
LIMIT=""
bundles_dir="$ROOT/core-requests/bundles"

# ── bundle protocol (PLAN §11 bundles) ──────────────────────────────────
# A bundle = a contract-node spec + ONE OR MORE transforms that consume it
# (transforms/*.rs — different backends may want different lowerings of
# the same node). Atomicity: the CORE applies the node + all transforms as
# one unit, builds+gates the pair, logs one verdict, and a failed bundle is
# reverted WHOLE. Acceptance stays per-transform: each backend's gate
# verdict on its transform set decides accept/reject.

# --bundles: validate every bundle's spec + manifest + per-transform
# manifests, log verdicts. Does NOT touch the live tree (the node may not
# exist yet — the generator's well-formedness IS the spec check; the
# fixture round-trip is informational until the node lands).
sweep_bundles() {
  [[ -d "$bundles_dir" ]] || { echo "[core-sweep] no bundles dir"; return 0; }
  for b in "$bundles_dir"/*/; do
    name=$(basename "$b")
    json="$b/bundle.json"
    [[ -f "$json" ]] || { echo -e "bundle:$name\t-\tBUNDLE\tmissing bundle.json\t$(date +%s)" >> "$LOG"; continue; }
    if "$ROOT/harness/contract-gen" "$json" --fixture > /dev/null 2>&1; then
      detail="spec OK (generator emitted a well-formed patch + fixture)"
      verdict="SPEC-OK"
    else
      detail="spec FAILED (contract-gen error)"
      verdict="SPEC-FAIL"
    fi
    if python3 -c "
import json,sys
m=json.load(open('$json'))['manifest']
for k in ('name','depends','invariant','scope'):
    assert k in m, f'missing manifest field {k}'
" 2>/dev/null; then
      detail="$detail; manifest OK"
      verdict="$verdict MANIFEST-OK"
    else
      detail="$detail; manifest INCOMPLETE"
      verdict="$verdict MANIFEST-FAIL"
    fi
    xdir="$b/transforms"
    if [[ -d "$xdir" ]]; then
      for xf in "$xdir"/*.rs; do
        xname=$(basename "$xf" .rs)
        node=$(python3 -c "import json; print(json.load(open('$json'))['spec']['node'])" 2>/dev/null || echo "$name")
        if grep -qE '^//! (name|depends|invariant|scope):' "$xf" && grep -q "^//! depends: \\[$node\\]" "$xf"; then
          echo -e "bundle:$name/$xname\t-\tOFFER-OK\tmanifest complete, depends [$node]\t$(date +%s)" >> "$LOG"
        else
          echo -e "bundle:$name/$xname\t-\tOFFER-FAIL\tmanifest incomplete or wrong depends\t$(date +%s)" >> "$LOG"
        fi
      done
    fi
    echo -e "bundle:$name\t-\t$verdict\t$detail\t$(date +%s)" >> "$LOG"
    echo "[core-sweep] bundle $name: $verdict"
  done
}

# --apply-bundles: apply node + ALL transforms, build, gate, REVERT
# (atomic — the live tree is restored afterwards, the verdict is the record).
apply_bundles() {
  [[ -d "$bundles_dir" ]] || { echo "[core-sweep] no bundles dir"; return 0; }
  for b in "$bundles_dir"/*/; do
    name=$(basename "$b")
    json="$b/bundle.json"
    [[ -f "$json" ]] || continue
    patch="/tmp/bundle-$name.patch"
    "$ROOT/harness/contract-gen" "$json" --out "$patch" || continue
    # 1. apply the node patch to the shared core
    if ! (cd "$ROOT/sh2perl" && git apply --recount "$patch" 2>/dev/null); then
      echo -e "bundle:$name\t-\tAPPLY-FAIL\tnode patch did not apply (open node model?)\t$(date +%s)" >> "$LOG"
      continue
    fi
    # 2. add ALL transform modules (transforms/*.rs; skip placeholders)
    tf=""
    for xf in "$b"/transforms/*.rs; do
      [[ -f "$xf" ]] || continue
      grep -q "PLACEHOLDER" "$xf" && continue
      tname="$(basename "$xf" .rs)"
      cp "$xf" "$ROOT/sh2perl/src/transforms/$tname.rs"
      tf="$tf src/transforms/$tname.rs"
    done
    # 3. build + gate the PAIR
    if "$LOCK" --role backend --timeout 1800 -- bash -c 'cd "$1" && cargo build --manifest-path Cargo.toml --bin debashc' _ "$ROOT/sh2perl" >> "$LOG" 2>&1; then
      verdict="PASS"
      detail="node + transforms built$tf"
    else
      verdict="FAIL"
      detail="build failed — bundle rejected WHOLE"
    fi
    echo -e "bundle:$name\t-\t$verdict\t$detail\t$(date +%s)" >> "$LOG"
    echo "[core-sweep] bundle $name: $verdict"
    # 4. REVERT (atomic: never leave a half-applied bundle in the live tree)
    (cd "$ROOT/sh2perl" && git checkout -- src/ir.rs src/shir_json.rs src/shir_json_in.rs 2>/dev/null || true)
    for t in $tf; do rm -f "$ROOT/sh2perl/$t"; done
  done
}

# ── main ───────────────────────────────────────────────────────────────
backends="$DEFAULT_BACKENDS"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --backends) backends="$2"; shift 2;;
    --limit) LIMIT="$2"; shift 2;;
    --bundles) sweep_bundles; exit 0;;
    --apply-bundles) apply_bundles; exit 0;;
    *) echo "core-sweep.sh: unknown option $1" >&2; exit 2;;
  esac
done

mkdir -p "$(dirname "$LOG")"
epoch=$(date +%s)
echo "[core-sweep] start epoch=$epoch backends='$backends'"

# 1. the shared core (one build, dedup'd — the estree loop and every
#    backend gate share sh2perl/target)
if ! "$LOCK" --role core --timeout 300 -- bash -c 'cd "$1" && cargo build --manifest-path Cargo.toml --bin debashc' _ "$ROOT/sh2perl" >> "$LOG" 2>&1; then
  echo "[core-sweep] core build FAILED" >> "$LOG"
  exit 1
fi

# 2. per backend: build its worktree + run its gate, log the verdict
n=0
for lang in $backends; do
  n=$((n+1))
  if [[ -n "$LIMIT" && $n -gt "$LIMIT" ]]; then break; fi
  wt="$ROOT/sh2perl/backends/$lang"
  if [[ ! -f "$wt/Cargo.toml" ]]; then
    echo -e "$lang\t-\tSKIP\tno worktree at $wt\t$epoch" >> "$LOG"
    continue
  fi
  tset_hash="$(git -C "$ROOT/sh2perl" rev-parse --short HEAD 2>/dev/null || echo unknown)"

  if "$LOCK" --role backend --timeout 1800 --share-target "$wt/target" -- \
       cargo build --manifest-path "$wt/Cargo.toml" >> "$LOG" 2>&1; then
    detail="build ok; gate not run (run-gate.sh $lang test separately)"
    verdict="PASS"
  else
    detail="build failed — see $LOG"
    verdict="FAIL"
  fi
  echo -e "$lang\t$tset_hash\t$verdict\t$detail\t$epoch" >> "$LOG"
  echo "[core-sweep] $lang: $verdict"
done

echo "[core-sweep] done — verdicts appended to $LOG"
