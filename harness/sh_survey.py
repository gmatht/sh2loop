#!/usr/bin/env python3
"""Survey the shIR vocabulary used across the corpus (for the sh renderer)."""
import json, subprocess, sys, collections, os

DEB = "/nvme/ai/sh2loop/sh2perl/target/debug/debashc"
files = sys.argv[1:]

stmt_types = collections.Counter()
call_funcs = collections.Counter()
expr_types = collections.Counter()
interp_kinds = collections.Counter()
redirect_modes = collections.Counter()
n_ok = n_skip = 0
examples = {}

def walk_expr(e, depth=0):
    if not isinstance(e, dict):
        return
    t = e.get("type")
    if t:
        expr_types[t] += 1
        if t == "Call":
            call_funcs[e.get("func", "?")] += 1
        if t == "Interpolate":
            for p in e.get("parts", []):
                interp_kinds[p.get("kind", "?")] += 1
    for k, v in e.items():
        if isinstance(v, dict):
            walk_expr(v, depth + 1)
        elif isinstance(v, list):
            for it in v:
                if isinstance(it, dict):
                    walk_expr(it, depth + 1)

def walk_stmt(s, depth=0):
    if not isinstance(s, dict):
        return
    t = s.get("type")
    if t:
        stmt_types[t] += 1
        if t == "Redirect":
            for r in s.get("redirects", []):
                redirect_modes[r.get("mode", "?")] += 1
        if t == "Expr":
            walk_expr(s.get("expr", {}), depth + 1)
    for k, v in s.items():
        if k == "expr":
            walk_expr(v, depth + 1)
        elif isinstance(v, dict):
            walk_stmt(v, depth + 1)
        elif isinstance(v, list):
            for it in v:
                if isinstance(it, dict):
                    walk_stmt(it, depth + 1)

for f in files:
    r = subprocess.run([DEB, "--shir", f, "--raw"], capture_output=True, text=True)
    if not r.stdout.strip():
        n_skip += 1
        continue
    n_ok += 1
    try:
        d = json.loads(r.stdout)
    except Exception:
        continue
    for s in d.get("stmts", []):
        walk_stmt(s)
    for sub in d.get("subs", []):
        for s in sub.get("body", []):
            walk_stmt(s)

print(f"files: {n_ok} parsed, {n_skip} skip")
print("\n== stmt types ==")
for k, v in stmt_types.most_common():
    print(f"{v:6d}  {k}")
print("\n== call funcs ==")
for k, v in call_funcs.most_common():
    print(f"{v:6d}  {k}")
print("\n== expr types ==")
for k, v in expr_types.most_common():
    print(f"{v:6d}  {k}")
print("\n== interp parts ==")
for k, v in interp_kinds.most_common():
    print(f"{v:6d}  {k}")
print("\n== redirect modes ==")
for k, v in redirect_modes.most_common():
    print(f"{v:6d}  {k}")
