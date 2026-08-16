#!/usr/bin/env python3
# check_qx_shir.py — the shIR-level anti-shell-out check (the keystone of the
# "backends render native shIR only" architecture).
#
# The A1 shIR contract is the single native-lowering point: a shared
# transform rewrites `exec("cmd", args)` → `builtin("cmd", args)` for every
# command in the shared namespace contract (harness/builtins.json). THIS
# check enforces that invariant on the EMITTED A1: any surviving
# `exec` of a builtins.json command is a transform gap — the backend would
# shell it out (rust bash -c / perl qx) instead of rendering native code.
#
# One check, all backends inherit (replaces the per-backend greps: perl's
# check_qx.pl on generated perl, the rust stub-gate's bash -c blindness).
#
# Usage:
#   debashc --shir file.sh --raw | check_qx_shir.py [--allow FILE]
#   check_qx_shir.py <a1.json> [--allow FILE]
#
# Exit = number of violations (like check_qx.pl). Exemptions (--allow, or
# the default allowed_qx_calls.txt) mirror check_qx.pl's allowlist.
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # the workspace root

BUILTINS = json.load(open(ROOT / "harness" / "builtins.json"))

# exemptions: command prefixes that may stay as raw exec (mirrors
# allowed_qx_calls.txt — documented cases, never to hide a transform gap)
def load_exemptions(path):
    if path:
        return [l.split("#")[0].strip() for l in open(path) if l.split("#")[0].strip()]
    allow = ROOT / "allowed_qx_calls.txt"
    return [l.split("#")[0].strip() for l in open(allow) if l.split("#")[0].strip()]

EXEMPTIONS = load_exemptions(
    sys.argv[sys.argv.index("--allow") + 1] if "--allow" in sys.argv else None
)


def walk(obj, violations, path, in_capture=False):
    """Recursively find exec calls of builtins.json commands in the A1.

    Capture-context execs are EXEMPT by design: a command substitution
    (`$(echo …)`) is the async capture path — the exec-to-builtin
    transform deliberately keeps it raw (the capture renderers' native
    folds key on the exec command name), so counting it here would flag
    the documented behavior as a gap.
    """
    if isinstance(obj, dict):
        # a Call node: {"type":"Call","func":X,"args":[...]}
        if obj.get("type") == "Call" and obj.get("func") == "exec":
            args = obj.get("args") or []
            if args and isinstance(args[0], dict) and args[0].get("type") == "Str":
                cmd = args[0].get("value", "")
                base = cmd.split("/")[-1]
                # a Var-sourced command is not statically checkable — skip
                if cmd.startswith("$"):
                    pass
                elif "/" in cmd:
                    # a path-qualified command is the EXTERNAL binary
                    # (`/bin/echo ≠` the bash builtin) — a legitimate
                    # shell-out, not a transform gap
                    pass
                elif (
                    not in_capture
                    and base in BUILTINS
                    and not any(base.startswith(e) for e in EXEMPTIONS)
                ):
                    violations.append((path, cmd))
        for k, v in obj.items():
            walk(
                v,
                violations,
                f"{path}.{k}",
                in_capture or obj.get("type") == "Capture",
            )
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            walk(v, violations, f"{path}[{i}]", in_capture)


def main():
    data = sys.stdin.read()
    if not data.strip() and len(sys.argv) >= 2 and not sys.argv[1].startswith("--"):
        data = open(sys.argv[1]).read()
    try:
        a1 = json.loads(data)
    except json.JSONDecodeError as e:
        print(f"  FAIL: invalid A1 JSON — {e}")
        return 1

    violations = []
    walk(a1, violations, "a1")
    for path, cmd in violations:
        print(f"  FAIL: exec of builtin '{cmd}' survives in the A1 ({path}) — the builtins.json → builtin() transform should have lowered it")
    if violations:
        print(f"check_qx_shir: {len(violations)} exec-of-builtin violation(s) — backends would shell out, not render native")
    else:
        print("check_qx_shir: A1 is native — no exec of a builtins.json command survives")
    return len(violations)


if __name__ == "__main__":
    sys.exit(main())
