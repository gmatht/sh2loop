#!/usr/bin/env python3
# outparam_to_returns.py — out-parameter elimination over A1 shIR JSON.
#
# Classifies each positional parameter of a function by its USE pattern and
# chooses the lowering form accordingly:
#
#   write-only param (memStore through getVar(N), never read)  -> PURE RETURN
#       void fill(int *out) { *out = 42; }  ==>  int fill() { return 42; }
#       call site: x = fill()               (the out-var becomes the return target)
#
#   read+write param (memLoad AND memStore) -> PASS-BY-VALUE + RETURN
#       void bump(int *x) { *x = *x + 1; }  ==>  int bump(int x) { return x + 1; }
#       call site: x = bump(x)              (the CURRENT value must be passed)
#
#   read-only param (memLoad only)          -> PASS-BY-VALUE (input)
#       the call site passes the value: f(x); the body's memLoad(N) -> getVar(N)
#
#   any other use (escape: passed on, stored globally, returned) -> SKIP (the
#   mem.* seam stays — the transform is only sound for non-escaping params).
#
# Multiple write-targets would need multi-return A1 support — the transform
# handles ONE write-target per function and refuses the rest (fail loud).
#
# Usage: outparam_to_returns.py < before.json > after.json

import json
import sys

def is_str(n, s):
    return isinstance(n, dict) and n.get('type') == 'Str' and n.get('value') == s

def is_call(n, f):
    return isinstance(n, dict) and n.get('type') == 'Call' and n.get('func') == f

def param_pos(n):
    """If n is getVar('N') (a positional param read), return N, else None."""
    if is_call(n, 'getVar') and n.get('args'):
        a = n['args'][0]
        if is_str(a, '1') or (isinstance(a, dict) and a.get('type') == 'Str'
                              and a.get('value', '').isdigit()):
            return a['value']
    return None

# ── per-function classification ─────────────────────────────────────────
def classify(fn):
    """Scan the body. Returns dict: pos -> {'writes': [(stmt, value)],
    'reads': bool, 'escape': bool}."""
    out = {}
    def note(pos):
        out.setdefault(pos, {'writes': [], 'reads': False, 'escape': False})
    def walk_expr(n, ctx):
        # ctx: 'store-target' | 'store-value' | 'other'
        if not isinstance(n, dict):
            return
        if is_call(n, 'memStore'):
            args = n.get('args', [{}])
            t = args[0] if args else {}
            p = param_pos(t)
            if p is not None:
                note(p)
                out[p]['writes'].append((ctx, args[1] if len(args) > 1 else {}))
            else:
                walk_expr(t, 'other')
            if len(args) > 1:
                walk_expr(args[1], 'store-value')
            return
        if is_call(n, 'memLoad'):
            args = n.get('args', [{}])
            p = param_pos(args[0] if args else {})
            if p is not None:
                note(p)
                out[p]['reads'] = True
            else:
                for a in args:
                    walk_expr(a, 'other')
            return
        p = param_pos(n)
        if p is not None:
            note(p)
            out[p]['escape'] = True   # the raw handle used outside mem ops
        for v in n.values():
            if isinstance(v, list):
                for x in v:
                    walk_expr(x, 'other')
            elif isinstance(v, dict):
                walk_expr(v, ctx)
    def walk_stmt(s):
        if s.get('type') == 'Expr':
            walk_expr(s.get('expr', {}), s)
        # nested bodies (If/While/Block) — walk them too
        for key in ('then', 'else', 'body', 'elsifs'):
            v = s.get(key)
            if isinstance(v, list):
                for x in v:
                    walk_stmt(x)
            elif isinstance(v, dict):
                walk_stmt(v)
    for b in fn.get('body', []):
        walk_stmt(b)
    return out

def rewrite_value(n, load_rewrites):
    """Replace memLoad(getVar(N)) with getVar(N) for pass-by-value params."""
    if not isinstance(n, dict):
        return n
    if is_call(n, 'memLoad'):
        args = n.get('args', [{}])
        p = param_pos(args[0] if args else {})
        if p in load_rewrites:
            return {'func': 'getVar', 'purity': 'Emulable', 'type': 'Call',
                    'args': [{'style': 'DoubleQuoted', 'type': 'Str', 'value': p}]}
    return {k: (rewrite_value(v, load_rewrites) if isinstance(v, dict)
                else ([rewrite_value(x, load_rewrites) for x in v] if isinstance(v, list) else v))
            for k, v in n.items()}

def transform(prog):
    plan = {}  # fn name -> {'write_pos': N, 'read_poss': [..]}
    for s in prog.get('stmts', []):
        if s.get('type') != 'Function':
            continue
        uses = classify(s)
        if not uses:
            continue
        write_poss = [p for p, u in uses.items() if u['writes']]
        read_poss = [p for p, u in uses.items() if u['reads'] and not u['writes']]
        escaped = any(u['escape'] for u in uses.values())
        if escaped:
            continue                                  # seam stays
        if len(write_poss) > 1:
            print(f"REFUSE {s['name']}: multiple write-targets need multi-return A1",
                  file=sys.stderr)
            continue
        if not write_poss:
            continue                                  # input-only params: pass-by-value
        wp = write_poss[0]
        last_stmt, last_value = uses[wp]['writes'][-1]
        # rewrite the function: the last store becomes an ECHO of the value
        # (the shell value-return channel — fnCall returns status, so values
        # flow via stdout capture); loads of pass-by-value params become
        # direct reads; other stores drop
        load_rewrites = set(read_poss)
        new_body = []
        for b in s.get('body', []):
            if b is last_stmt:
                new_body.append({'type': 'Expr', 'expr': {
                    'func': 'exec', 'purity': 'Emulable', 'type': 'Call',
                    'args': [{'style': 'DoubleQuoted', 'type': 'Str', 'value': 'echo'},
                             {'elements': [rewrite_value(last_value, load_rewrites)],
                              'type': 'Array'}]}})
            elif (b.get('type') == 'Expr'
                  and is_call(b.get('expr', {}), 'memStore')
                  and param_pos(b['expr'].get('args', [{}])[0]) == wp):
                continue                              # earlier stores to the out-param drop
            else:
                new_body.append(b)
        s['body'] = new_body
        plan[s['name']] = {'write_pos': wp, 'read_poss': read_poss}
    # rewrite call sites
    for s in prog.get('stmts', []):
        if s.get('type') == 'Expr':
            e = s.get('expr', {})
            if is_call(e, 'fnCall'):
                args = e.get('args', [])
                name = args[0].get('value') if args and isinstance(args[0], dict) else None
                if name in plan:
                    p = plan[name]
                    elems = args[1].get('elements', []) if len(args) > 1 else []
                    write_var = None
                    call_args = []
                    for i, a in enumerate(elems):
                        pos = str(i + 1)
                        if pos == p['write_pos']:
                            if is_call(a, 'addrOf') and a.get('args'):
                                write_var = a['args'][0].get('value')
                            # the out-arg is dropped from the call
                        else:
                            if is_call(a, 'addrOf') and a.get('args'):
                                v = a['args'][0].get('value')
                                call_args.append({'func': 'getVar', 'purity': 'Emulable',
                                                  'type': 'Call',
                                                  'args': [{'style': 'DoubleQuoted',
                                                            'type': 'Str', 'value': v}]})
                            else:
                                call_args.append(a)
                    if write_var is None:
                        continue
                    # x = $(f v1 v2) — the shell value-return: the function
                    # echoes, the caller captures
                    s['expr'] = {'func': 'setVar', 'purity': 'Emulable', 'type': 'Call',
                                 'args': [
                                     {'style': 'DoubleQuoted', 'type': 'Str', 'value': write_var},
                                     {'func': 'capture', 'purity': 'Emulable', 'type': 'Call',
                                      'args': [{'type': 'Arrow', 'body': [
                                          {'type': 'Expr', 'expr': {
                                              'func': 'fnCall', 'purity': 'Emulable',
                                              'type': 'Call',
                                              'args': [args[0],
                                                       {'elements': call_args, 'type': 'Array'}]}}]}]}]}
    return prog

def main():
    data = json.load(sys.stdin)
    transform(data)
    json.dump(data, sys.stdout, separators=(',', ':'))
    print()

if __name__ == '__main__':
    main()
