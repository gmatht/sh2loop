#!/usr/bin/env python3
"""node-spec-check — every declared shIR node must say what it MEANS.

    python3 harness/node-spec-check.py            # verdict: exit 1 on unstated
    python3 harness/node-spec-check.py --list     # one line per node
    python3 harness/node-spec-check.py --json

WHY THIS EXISTS. A `.node` declaration names a node, its fields and the
JSON it round-trips to. It does not say what the node DENOTES, and that gap
is not hypothetical: the `wc -l` lowering shipped `length(text) + 1` for
weeks, and every backend reproduced it faithfully, because the node was
called "line count" while the lowering meant "newlines plus one". Nothing
in the declaration format could have caught it. `sh2perl/docs/fm/TextOps/`
caught it only after the fact, and only for the three nodes it covers.

So the format gains one line per node:

    spec: text-ops#wc_count        a theorem in a session that the proof
                                   gate builds (harness/transform-proofs.sh)
    spec: none (effect: C FFI)     no denotation can own it — the REASON is
                                   required, so "none" cannot become a
                                   silent default
    spec: none (unstated)          the honest default for a node nobody has
                                   decided about yet. Reported, and the
                                   verdict FAILS while any remain.

The distinction this enforces is the one that matters: a node is either a
pure function with a short denotation in an explicit domain, or it is an
effect/ABI node (FFI, device, filesystem, pointer) whose contract lives
somewhere else. "Unstated" is not a third kind — it is a todo item wearing
a node's clothes.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NODES = ROOT / "sh2perl" / "src" / "shir_nodes"

# Session directories the proof gate builds (harness/transform-proofs.sh's
# SESSION_DIRS). The theory names are read from the .thy files themselves:
# a session is `session TextOps in .` whose theory is ShIR_TextOps.thy, so
# spelling the session name twice is a trap — the first version of this list
# said "TextOps" while the file is ShIR_TextOps.thy.
PROOF_SESSIONS = [
    "proofs",
    "proofs/ArithIdentity",
    "sh2perl/docs/fm/TextOps",
    "verif",
]

# The reasons that make `spec: none (...)` legal. Anything else is rejected:
# an open-ended exemption list is how a spec obligation quietly disappears.
EFFECT_KINDS = {
    "C FFI", "pointer", "device", "filesystem", "I/O", "control flow",
    "contract callout", "frontend shape",
}


def load_theories() -> set:
    """Theory names available in the proof sessions that the gate builds."""
    names = set()
    for rel in PROOF_SESSIONS:
        d = ROOT / rel
        if d.is_dir():
            for f in d.glob("*.thy"):
                names.add(f.stem)
    return names


def session_named(name: str) -> bool:
    """Is `name` a session declared in a proof ROOT?"""
    for rel in PROOF_SESSIONS:
        root = ROOT / rel / "ROOT"
        if root.is_file():
            for ln in root.read_text(encoding="utf-8", errors="replace").splitlines():
                if re.match(rf"session\s+{re.escape(name)}\s*(=|in\b)", ln.strip()):
                    return True
    return False


def parse_node(path: Path):
    spec = None
    tag = None
    for ln in path.read_text(encoding="utf-8", errors="replace").splitlines():
        ln = ln.strip()
        if ln.startswith("spec:"):
            spec = ln[len("spec:"):].strip()
        elif ln.startswith("tag "):
            tag = ln[4:].strip().strip('"')
    return tag, spec


def classify(spec, theories):
    """-> (status, detail) where status ∈ {theorem, effect, unstated}."""
    if spec is None:
        return "unstated", "no `spec:` line"
    if spec.startswith("none"):
        m = re.match(r"none\s*\((.*?)\)\s*$", spec)
        if not m:
            return "unstated", "`spec: none` without a reason"
        reason = m.group(1).strip()
        if reason.startswith("effect:"):
            kind = reason[len("effect:"):].strip()
            if kind not in EFFECT_KINDS:
                return "unstated", f"effect kind '{kind}' is not on the list"
            return "effect", kind
        if reason == "unstated":
            return "unstated", "declared unstated"
        return "unstated", f"unrecognised exemption '{reason}'"
    # session#lemma
    m = re.match(r"([A-Za-z_][A-Za-z0-9_\-/.]*)#([A-Za-z_][A-Za-z0-9_']*)$", spec)
    if not m:
        return "unstated", f"malformed spec reference '{spec}'"
    theory, lemma = m.group(1).split("/")[-1], m.group(2)
    # Accept the theory stem (ShIR_TextOps) or the session name (TextOps):
    # both are what a manifest author will type. Resolve through the ROOT.
    if theory not in theories and not session_named(theory):
        return "unstated", f"no theory '{theory}' in a session the proof gate builds"
    return "theorem", f"{theory}#{lemma}"


def main(argv):
    as_json = "--json" in argv
    as_list = "--list" in argv
    if not NODES.is_dir():
        print(f"node-spec-check: {NODES} missing", file=sys.stderr)
        return 2
    theories = load_theories()
    rows = []
    for path in sorted(NODES.glob("*.node")):
        tag, spec = parse_node(path)
        status, detail = classify(spec, theories)
        rows.append({
            "node": tag or path.stem,
            "file": path.name,
            "status": status,
            "detail": detail,
            "spec": spec,
        })

    counts = {}
    for r in rows:
        counts[r["status"]] = counts.get(r["status"], 0) + 1

    if as_json:
        print(json.dumps({"counts": counts, "nodes": rows}, indent=2))
    else:
        for r in rows:
            if as_list or r["status"] == "unstated":
                print(f'{r["status"]:9} {r["node"]:18} {r["detail"]}')
        print(
            "node-spec-check: {} theorem-backed, {} effect-exempt, {} unstated "
            "(of {})".format(
                counts.get("theorem", 0), counts.get("effect", 0),
                counts.get("unstated", 0), len(rows),
            )
        )

    # The verdict: an unstated node is a decision nobody has made, and this
    # script exists to force it. The count may fall to zero only by adding a
    # theorem or naming an effect kind.
    left = counts.get("unstated", 0)
    if left and not as_list and not as_json:
        print(
            "\nEach of the {} unstated node(s) needs one line:\n"
            "  spec: <Theory>#<lemma>   — a theorem in a session the proof\n"
            "                             gate builds (harness/transform-proofs.sh)\n"
            "  spec: none (effect: <kind>)  — one of: {}\n"
            "  spec: none (unstated)        — the honest default; still fails".format(
                left, ", ".join(sorted(EFFECT_KINDS))
            ),
            file=sys.stderr,
        )
    return 1 if (left and not as_list and not as_json) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
