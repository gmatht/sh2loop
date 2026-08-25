#!/usr/bin/env python3
"""Tally all sh2.* call sites by shape, from generated ESTree JSON."""
import json, subprocess, os, collections

root = "/home/llm/sh2loop/sh2perl"
ex = os.path.join(root, "examples")
debashc = os.path.join(root, "target/debug/debashc")

counts = collections.Counter()          # sh2.<name> totals
builtin_names = collections.Counter()   # sh2.builtin("name", ...)
capture_names = collections.Counter()   # sh2.capture(<cmd>) inner names
getvar_names = collections.Counter()    # sh2.getVar("name")
setvar_names = collections.Counter()
join_shapes = collections.Counter()
test_shapes = collections.Counter()
arith_shapes = collections.Counter()
redirect_shapes = collections.Counter()
param_names = collections.Counter()
inloop = collections.Counter()

def first_lit(args):
    for a in args:
        if isinstance(a, dict) and a.get("type") == "Literal" and isinstance(a.get("value"), str):
            return a["value"]
    return None

def cmd_name(args):
    for a in args:
        if isinstance(a, dict) and a.get("type") == "Literal" and isinstance(a.get("value"), str):
            return a["value"]
        if isinstance(a, dict) and a.get("type") == "ArrayExpression":
            for e in a.get("elements", []):
                if isinstance(e, dict) and e.get("type") == "Literal" and isinstance(e.get("value"), str):
                    return e["value"]
    return None

def walk(n, il):
    if isinstance(n, dict):
        t = n.get("type")
        if t == "CallExpression":
            c = n.get("callee")
            if isinstance(c, dict) and c.get("object", {}).get("name") == "sh2":
                nm = c.get("property", {}).get("name", "")
                counts[nm] += 1
                if il: inloop[nm] += 1
                args = n.get("arguments", [])
                if nm == "builtin":
                    builtin_names[first_lit(args)] += 1
                elif nm == "capture":
                    capture_names[cmd_name(args)] += 1
                elif nm == "getVar":
                    getvar_names[first_lit(args)] += 1
                elif nm == "setVar":
                    setvar_names[first_lit(args)] += 1
                elif nm == "join":
                    join_shapes[str([a.get("type") if isinstance(a, dict) else type(a).__name__ for a in args])] += 1
                elif nm == "test":
                    # shape of first arg
                    a0 = args[0] if args else None
                    s = json.dumps(a0)[:100] if isinstance(a0, dict) else str(a0)
                    test_shapes[s] += 1
                elif nm in ("arith", "arithEval"):
                    a0 = args[0] if args else None
                    s = json.dumps(a0)[:80] if isinstance(a0, dict) else str(a0)
                    arith_shapes[(nm, s)] += 1
                elif nm == "redirect":
                    a0 = args[0] if args else None
                    redirect_shapes[str(first_lit([a0]) if isinstance(a0, dict) else None)] += 1
                elif nm == "param":
                    param_names[str(first_lit(args))] += 1
                if nm and nm.endswith("Loop"):
                    for a in args:
                        if isinstance(a, dict) and a.get("type") == "ArrowFunctionExpression":
                            walk(a, True)
                    return
            elif isinstance(c, dict) and c.get("type") == "Identifier" and c.get("name") in ("sh2",):
                pass
        for v in n.values():
            walk(v, il)
    elif isinstance(n, list):
        for v in n:
            walk(v, il)

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
    walk(d, False)

print(f"files: {files}")
print("=== sh2.* totals:")
for k, v in counts.most_common():
    print(f"  {v:5d}  {k}")
print("=== builtin names:")
for k, v in builtin_names.most_common(40):
    print(f"  {v:5d}  {k}")
print("=== capture inner commands:")
for k, v in capture_names.most_common(40):
    print(f"  {v:5d}  {k}")
print("=== getVar names (top 30):")
for k, v in getvar_names.most_common(30):
    print(f"  {v:5d}  {k}")
print("=== setVar names (top 30):")
for k, v in setvar_names.most_common(30):
    print(f"  {v:5d}  {k}")
print("=== param:")
for k, v in param_names.most_common(20):
    print(f"  {v:5d}  {k}")
print("=== join arg shapes:")
for k, v in join_shapes.most_common(10):
    print(f"  {v:5d}  {k}")
print("=== redirect first-arg (top 20):")
for k, v in redirect_shapes.most_common(20):
    print(f"  {v:5d}  {k}")
print("=== in-loop sh2 sites:")
for k, v in inloop.most_common():
    print(f"  {v:5d}  {k}")
