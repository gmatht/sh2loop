#!/usr/bin/env python3
"""Find in-loop sh2.* call sites with file + context."""
import json, subprocess, os, collections

root = "/home/llm/sh2loop/sh2perl"
ex = os.path.join(root, "examples")
debashc = os.path.join(root, "target/debug/debashc")

hits = collections.Counter()

def first_lit(args):
    for a in args:
        if isinstance(a, dict) and a.get("type") == "Literal" and isinstance(a.get("value"), str):
            return a["value"]
    return None

def walk(n, il, path):
    if isinstance(n, dict):
        t = n.get("type")
        if t == "CallExpression":
            c = n.get("callee")
            args = n.get("arguments", [])
            if isinstance(c, dict) and c.get("object", {}).get("name") == "sh2":
                nm = c.get("property", {}).get("name", "")
                if il:
                    args = n.get("arguments", [])
                    lit = first_lit(args)
                    hits[(nm, lit, path)] += 1
                if nm and nm.endswith("Loop"):
                    for a in args:
                        if isinstance(a, dict) and a.get("type") == "ArrowFunctionExpression":
                            walk(a, True, path + " >loop")
                    return
        for v in n.values():
            walk(v, il, path)
    elif isinstance(n, list):
        for i, v in enumerate(n):
            walk(v, il, path + f"[{i}]")

for fn in sorted(os.listdir(ex)):
    if not fn.endswith(".sh"):
        continue
    p = os.path.join(ex, fn)
    try:
        out = subprocess.run([debashc, "file", "--estree", p], cwd=root,
                             capture_output=True, text=True, timeout=20)
        d = json.loads(out.stdout)
    except Exception:
        continue
    walk(d, False, "")

for (nm, lit, path), v in hits.most_common():
    print(f"{v:3d}  sh2.{nm}({lit})  {path}")
