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
    'reads': bool, 'escape': bool}. The frontend's leading
    `Assign <name> = getVar(N)` bindings map each pointer PARAM NAME to
    its positional — deref reads/writes through the bound name
    (memLoad/memStore(getVar(<name>))) classify identically to the
    positional form."""
    name_to_pos = {}
    for b in fn.get('body', []):
        if (b.get('type') == 'Assign' and b.get('expr')
                and is_call(b['expr'], 'getVar')):
            t = b.get('targets', [{}])[0]
            a0 = b['expr'].get('args', [{}])[0]
            v = t.get('var') if isinstance(t, dict) else None
            p = a0.get('value') if isinstance(a0, dict) else None
            if v and p and str(p).isdigit():
                name_to_pos[v] = str(p)
    def pos_of(n):
        p = param_pos(n)
        if p is not None:
            return p
        if is_call(n, 'getVar') and n.get('args'):
            a0 = n['args'][0]
            nm = a0.get('value') if isinstance(a0, dict) else None
            if nm in name_to_pos:
                return name_to_pos[nm]
        return None
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
            p = pos_of(t)
            # arena shape: memStore(handle, offset, type, value); the
            # slice-1 shape is memStore(handle, value)
            val = args[3] if len(args) > 3 else (args[1] if len(args) > 1 else {})
            if p is not None:
                note(p)
                out[p]['writes'].append((ctx, val))
            else:
                walk_expr(t, 'other')
            walk_expr(val, 'store-value')
            return
        if is_call(n, 'memLoad'):
            args = n.get('args', [{}])
            p = pos_of(args[0] if args else {})
            if p is not None:
                note(p)
                out[p]['reads'] = True
            else:
                for a in args:
                    walk_expr(a, 'other')
            return
        # a BOUND-PARAM read — an Arith Var or a plain getVar(<name>) of a
        # param (a non-pointer param read like `*dst = x * scale`, or the
        # param itself appearing in a value) — marks the position READ
        # (the renumbering must shift it when earlier write-params drop)
        if n.get('type') == 'Var' and n.get('name') in name_to_pos:
            p = name_to_pos[n['name']]
            note(p)
            out[p]['reads'] = True
            return
        if is_call(n, 'getVar') and n.get('args'):
            a0 = n['args'][0]
            nm = a0.get('value') if isinstance(a0, dict) else None
            if nm in name_to_pos and not (is_call(n, 'memLoad') or is_call(n, 'memStore')):
                p = name_to_pos[nm]
                note(p)
                out[p]['reads'] = True
                return
        p = pos_of(n)
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
        elif s.get('type') == 'Assign':
            e = s.get('expr', {})
            # the leading `Assign <param> = getVar(N)` bindings are the
            # param plumbing (identity copies) — skip; any other Assign
            # (a read+write temp like `__t = memLoad(N)`) is walked
            if not (is_call(e, 'getVar') and param_pos(e)):
                walk_expr(e, s)
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
        if not write_poss:
            # PASS-BY-VALUE: read-only pointer params (const int *x) — the
            # caller passes the VALUE (addrOf(v) -> getVar(v)); inside, the
            # param IS the value (memLoad(N) -> getVar(N)). No return, no
            # renumbering (the param keeps its position).
            load_rewrites = set(read_poss)
            s['body'] = [rewrite_value(b, load_rewrites) for b in s.get('body', [])]
            plan[s['name']] = {'write_pos': None, 'read_poss': read_poss}
            continue
        # write-param handling — ONE or MORE write targets (multi-return A1,
        # core request c-multi-return): each write-pos's LAST store becomes
        # an ECHO of its value (one per line, in body order — the shell
        # value-return channel carries several values); earlier stores to
        # any write-pos drop; the caller captures and destructures.
        wps = sorted(write_poss, key=int)
        # dropping the write-params renumbers the later read-params: a read
        # at pos N shifts down by the count of dropped write-params below it
        def dropped_below(n):
            # a READ+WRITE write-param is an IN-OUT: it drops from the
            # RETURN channel but KEEPS its input position (the caller
            # passes the current value) — only WRITE-ONLY params shift
            # the later positions down.
            return sum(1 for w in wps if int(w) < n and w not in rw)
        # READ+WRITE write-params (`*x = *x + 1`) are ALSO inputs: the
        # caller passes the current value at the renumbered position, so
        # their loads renumber like read-pos reads.
        rw = [w for w in wps if uses[w]['reads']]
        renum = {p: str(int(p) - dropped_below(int(p)))
                 for p in read_poss + rw}
        # the leading bindings map param NAMES to their positionals
        name_to_pos = {}
        for b in s.get('body', []):
            if (b.get('type') == 'Assign' and b.get('expr')
                    and is_call(b['expr'], 'getVar')):
                t = b.get('targets', [{}])[0]
                a0 = b['expr'].get('args', [{}])[0]
                v = t.get('var') if isinstance(t, dict) else None
                p = a0.get('value') if isinstance(a0, dict) else None
                if v and p and str(p).isdigit():
                    name_to_pos[v] = str(p)
        def pos_of(n):
            p = param_pos(n)
            if p is not None:
                return p
            if is_call(n, 'getVar') and n.get('args'):
                a0 = n['args'][0]
                nm = a0.get('value') if isinstance(a0, dict) else None
                if nm in name_to_pos:
                    return name_to_pos[nm]
            return None
        def renum_value(v):
            if isinstance(v, dict) and is_call(v, 'memLoad'):
                args = v.get('args', [{}])
                p = pos_of(args[0] if args else {})
                if p in renum:
                    return {'func': 'getVar', 'purity': 'Emulable', 'type': 'Call',
                            'args': [{'style': 'DoubleQuoted', 'type': 'Str',
                                      'value': renum[p]}]}
            if isinstance(v, dict):
                return {k: renum_value(x) for k, x in v.items()}
            if isinstance(v, list):
                return [renum_value(x) for x in v]
            return v
        last_stores = {wp: uses[wp]['writes'][-1] for wp in wps}  # pos -> (stmt, value)
        echo_order = []   # write positions in body-echo order (for the caller)
        # the frontend's leading `Assign <param> = getVar(N)` bindings:
        # DROP the write-param bindings (the params no longer exist) and
        # RENUMBER the read-param bindings (a read param at N shifts to
        # N - dropped_below(N)) — the body's reads of the BOUND var then
        # see the caller's renumbered arg.
        def renum_binding(b):
            if (b.get('type') == 'Assign' and b.get('expr')
                    and is_call(b['expr'], 'getVar')):
                a0 = b['expr'].get('args', [{}])[0]
                oldp = a0.get('value') if isinstance(a0, dict) else None
                if oldp in renum:
                    b['expr'] = {'func': 'getVar', 'purity': 'Emulable',
                                 'type': 'Call',
                                 'args': [{'style': 'DoubleQuoted',
                                           'type': 'Str',
                                           'value': renum[oldp]}]}
            return b
        new_body = []
        for b in s.get('body', []):
            if (b.get('type') == 'Assign' and b.get('expr')
                    and is_call(b['expr'], 'getVar')):
                a0 = b['expr'].get('args', [{}])[0]
                oldp = a0.get('value') if isinstance(a0, dict) else None
                if oldp in last_stores:
                    continue                      # write-param binding drops
                if oldp in renum:
                    b = renum_binding(b)
            if any(b is st for st, _ in last_stores.values()):
                # b is one of the last stores -> echo its value (body order)
                pos = next(w for w, (st, _) in last_stores.items() if st is b)
                echo_order.append(pos)
                new_body.append({'type': 'Expr', 'expr': {
                    'func': 'exec', 'purity': 'Emulable', 'type': 'Call',
                    'args': [{'style': 'DoubleQuoted', 'type': 'Str', 'value': 'echo'},
                             {'elements': [renum_value(last_stores[pos][1])],
                              'type': 'Array'}]}})
            elif (b.get('type') == 'Expr'
                  and is_call(b.get('expr', {}), 'memStore')
                  and param_pos(b['expr'].get('args', [{}])[0]) in last_stores):
                continue                              # earlier stores to any out-param drop
            else:
                # kept statements are renumbered too — a read+write
                # param's load lives in a temp Assign (`__t = memLoad(N)`)
                # and must read the caller's passed value at the new pos
                new_body.append(renum_value(b))
        s['body'] = new_body
        plan[s['name']] = {'write_pos': wps, 'echo_order': echo_order,
                           'read_poss': read_poss, 'readwrite': rw}
    # rewrite call sites (index loop — a multi-write call site becomes a
    # Block of several statements)
    for idx, s in enumerate(prog.get('stmts', [])):
        if s.get('type') != 'Expr':
            continue
        e = s.get('expr', {})
        if not is_call(e, 'fnCall'):
            continue
        args = e.get('args', [])
        name = args[0].get('value') if args and isinstance(args[0], dict) else None
        if name not in plan:
            continue
        p = plan[name]
        elems = args[1].get('elements', []) if len(args) > 1 else []
        wps = p['write_pos']
        write_vars = {}    # pos -> out-var name (from the addrOf arg)
        call_args = []
        for i, a in enumerate(elems):
            pos = str(i + 1)
            if pos in wps:
                if is_call(a, 'addrOf') and a.get('args'):
                    write_vars[pos] = a['args'][0].get('value')
                if pos in p['readwrite']:
                    # read+write: the caller passes the CURRENT value
                    # (the function reads it via the renumbered load)
                    if is_call(a, 'addrOf') and a.get('args'):
                        v = a['args'][0].get('value')
                        call_args.append({'func': 'getVar', 'purity': 'Emulable',
                                          'type': 'Call',
                                          'args': [{'style': 'DoubleQuoted',
                                                    'type': 'Str', 'value': v}]})
                    else:
                        call_args.append(a)
                # else: the out-arg is dropped from the call
            else:
                if is_call(a, 'addrOf') and a.get('args'):
                    v = a['args'][0].get('value')
                    call_args.append({'func': 'getVar', 'purity': 'Emulable',
                                      'type': 'Call',
                                      'args': [{'style': 'DoubleQuoted',
                                                'type': 'Str', 'value': v}]})
                else:
                    call_args.append(a)
        if not wps:
            # read-only param function: just pass values
            s['expr'] = {'func': 'fnCall', 'purity': 'Emulable', 'type': 'Call',
                         'args': [args[0], {'elements': call_args, 'type': 'Array'}]}
            continue
        # x = $(f v1 v2) — the shell value-return: the function echoes (one
        # value per line), the caller captures. MULTI (multi-return A1):
        # a temp holds the captured lines, each out-var gets its line.
        fncall = {'func': 'fnCall', 'purity': 'Emulable', 'type': 'Call',
                  'args': [args[0], {'elements': call_args, 'type': 'Array'}]}
        capture = {'func': 'capture', 'purity': 'Emulable', 'type': 'Call',
                   'args': [{'type': 'Arrow', 'body': [
                       {'type': 'Expr', 'expr': fncall}]}]}
        if len(wps) == 1:
            s['expr'] = {'func': 'setVar', 'purity': 'Emulable', 'type': 'Call',
                         'args': [
                             {'style': 'DoubleQuoted', 'type': 'Str',
                              'value': write_vars[p['echo_order'][0]]},
                             capture]}
            continue
        # multi-write: capture once, destructure line-by-line
        temp = '__out_' + name
        body = [
            {'type': 'Expr', 'expr': {'func': 'setVar', 'purity': 'Emulable',
                                      'type': 'Call',
                                      'args': [{'style': 'DoubleQuoted', 'type': 'Str',
                                                'value': temp}, capture]}},
        ]
        for k, pos in enumerate(p['echo_order']):
            v = write_vars.get(pos)
            if v is None:
                continue
            # Assign (not setVar Expr): the lifted-vs-store desync — a
            # source-less var is VACUOUSLY liftable, so a runtime setVar
            # write would land in the store while reads use the native
            # binding. The Assign arm's lifted path renders a `line`
            # source natively (see shir.rs), and a store-bound var falls
            # back to the same setVar — either way consistent.
            body.append({'type': 'Assign',
                         'targets': [{'indices': [], 'sigil': None, 'var': v}],
                         'expr': {'func': 'line', 'purity': 'Emulable',
                                  'type': 'Call',
                                  'args': [
                                      {'func': 'getVar', 'purity': 'Emulable',
                                       'type': 'Call',
                                       'args': [{'style': 'DoubleQuoted',
                                                 'type': 'Str',
                                                 'value': temp}]},
                                      {'style': 'DoubleQuoted', 'type': 'Str',
                                       'value': str(k)}]}})
        prog['stmts'][idx] = {'type': 'Block', 'body': body}
    return prog

def main():
    data = json.load(sys.stdin)
    transform(data)
    json.dump(data, sys.stdout, separators=(',', ':'))
    print()

if __name__ == '__main__':
    main()
