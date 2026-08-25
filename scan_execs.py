#!/usr/bin/env python3
"""Scan generated ESTree JSON for sh2.exec / sh2.capture / sh2.pipeline call sites."""
import json, subprocess, sys, os, collections

root = "/home/llm/sh2loop/sh2perl"
ex = os.path.join(root, "examples")
debashc = os.path.join(root, "target/debug/debashc")

exec_cmds = collections.Counter()
inloop = collections.Counter()
files = 0
for fn in sorted(os.listdir(ex)):
    if not fn.endswith(".sh"):
        continue
    files += 1
    p = os.path.join(ex, fn)
    try:
        out = subprocess.run([debashc, "file", "--estree", p], cwd=root,
                             capture_output=True, text=True, timeout=20)
        d = json.loads(out.stdout)
    except Exception:
        continue
    def walk(n, in_loop):
        if isinstance(n, dict):
            t = n.get("type")
            if t == "CallExpression":
                c = n.get("callee")
                if isinstance(c, dict) and c.get("object", {}).get("name") == "sh2":
                    nm = c.get("property", {}).get("name")
                    if nm == "exec":
                        for a in n.get("arguments", []):
                            if isinstance(a, dict) and a.get("type") == "Literal" and isinstance(a.get("value"), str):
                                exec_cmds[a["value"]] += 1
                                if in_loop: inloop[a["value"]] += 1
                    if nm and nm.endswith("Loop"):
                        # body arrow = in-loop
                        for a in n.get("arguments", []):
                            if isinstance(a, dict) and a.get("type") == "ArrowFunctionExpression":
                                walk(a, True)
                        return
            for v in n.values():
                walk(v, in_loop)
        elif isinstance(n, list):
            for v in n:
                walk(v, in_loop)
    walk(d, False)

print(f"files scanned: {files}")
print("=== exec commands (total / in-loop):")
for cmd, n in exec_cmds.most_common(60):
    print(f"  {n:5d}  {cmd}")
