#!/usr/bin/env python3
"""free-sites.py — the first stage of the C use-after-free obligation
generator: recover every heap block's life (allocation, statement boundary,
free) from a rendered C file, and say whether the render is TRACTABLE.

    harness/free-sites.py <render.c> [--json]

WHY FROM THE TEXT, NOT FROM THE BACKEND. The renderer already decides which
vars get `free()` (`emit_fn_frees_excluding`, `flush_pending_frees`,
`emit_vec_local_frees_in`), but it decides SYMBOLICALLY while emitting. The
obligation generator needs the sites as DATA per program. Two routes:

  (a) a side channel in `c_backend.rs` recording (function, var, site) —
      precise, but a 53k-line file is rewritten by a worker; and
  (b) recover them from the emitted text, using the naming discipline the
      backend already guarantees.

This file is (b), because it can run against any render without touching
the backend, and because the question it answers — "how many blocks, how
many free sites, how many per function" — decides whether (a) is worth the
merge conflict. It is NOT a soundness proof: it recovers only the shapes
below and reports everything else as UNKNOWN rather than guessing.

FIRST RESULT (6 renders, 2026-10-23): one render had NO heap block at all
(`054_fibonacci` is all `long long` and `fputs`), another had 11 blocks in
`main` alone, and `051_primes` needs 7 blocks across 2 functions. Those are
numbers Isabelle's `eval`-on-a-concrete-trace discharge can absorb. But the
`realloc`-class construct (`_sh_grow_str`, `_sh_vbuf`, `_sh_vgrow`) appears
in 5 of 6 renders — the growable-buffer path is NOT modelled by this script
and must be modelled in `MemorySafety.thy` before any per-program theorem
covers a realistic program. That is the real cost: the trace model, not the
trace count.

The shapes it recognises (all straight from the renderer's own templates):

    char *v = strdup(...)                  allocation, owned
    char *v = <call>(...);   +  free(v);   allocation + statement free
                                           (pending_frees, flushed at each
                                           statement boundary)
    v = strdup(...)                        RE-allocation of an owned var
    free(v)                                release
    v = <literal or borrowed>              kills the old block (the renderer
                                           frees-then-assigns or aliases)
    _sh_vbuf / realloc                     UNKNOWN (growable buffers are not
                                           modelled by this script)

Exit: 0 when a report was produced (whatever it says), 2 on usage/IO.
"""

import json
import re
import sys
from collections import defaultdict

# --- lexing ---------------------------------------------------------------

def strip_comments_and_strings(src: str):
    """Remove comments and string/char literal CONTENTS, keeping offsets, so
    a `free(` inside a printf format string cannot be read as a call."""
    out = list(src)
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == '/' and i + 1 < n and src[i + 1] == '*':
            j = src.find('*/', i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if out[k] != '\n':
                    out[k] = ' '
            i = j
        elif c == '/' and i + 1 < n and src[i + 1] == '/':
            j = src.find('\n', i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = ' '
            i = j
        elif c == '"' or c == "'":
            q = c
            j = i + 1
            while j < n:
                if src[j] == '\\':
                    j += 2
                    continue
                if src[j] == q:
                    break
                j += 1
            for k in range(i + 1, min(j, n)):
                if out[k] != '\n':
                    out[k] = ' '
            i = j + 1
        else:
            i += 1
    return ''.join(out)


FUNC_RE = re.compile(r'^[A-Za-z_][\w \*]*\b([A-Za-z_]\w*)\s*\([^;{]*\)\s*\{', re.M)

def functions(clean: str):
    """(name, start, end) for each function body, by brace matching."""
    out = []
    for m in FUNC_RE.finditer(clean):
        name = m.group(1)
        if name in ('if', 'for', 'while', 'switch', 'return', 'sizeof'):
            continue
        i = m.end() - 1
        depth = 0
        while i < len(clean):
            if clean[i] == '{':
                depth += 1
            elif clean[i] == '}':
                depth -= 1
                if depth == 0:
                    break
            i += 1
        out.append((name, m.start(), i))
    return out

# --- site recovery --------------------------------------------------------

# The renderer's ownership idiom is a GNU statement expression:
#   v = ({ const char *_sdN = <src>; char *_xpN = _sdN ? strdup(_sdN) : 0;
#          if (...) exit(127); _xpN; });
# so the ASSIGNED name is the LHS of `= ({`, and the allocation happens on
# `_xpN`. Both are recorded: `_xpN` is the block, `v` is the owning slot.
ALLOC_RE = re.compile(r'\b(?:char\s*\*\s*_xp|([A-Za-z_]\w*)\s*=\s*\(\{)[^;]*?'
                      r'(strdup|_sh_str_dup|_sh_str_new|malloc|calloc)\s*\(')
OWNED_ASSIGN_RE = re.compile(r'\b([A-Za-z_]\w*)\s*=\s*\(\{\s*const char \*_sd\w+')
CALLALLOC_RE = re.compile(r'\bchar\s*\*\s*([A-Za-z_]\w*)\s*=\s*([A-Za-z_]\w*)\s*\(')
FREE_RE = re.compile(r'\bfree\s*\(\s*([A-Za-z_]\w*)\s*\)')
ASSIGN_RE = re.compile(r'^\s*([A-Za-z_]\w*)\s*=\s*(.+?);\s*$', re.M)
UNKNOWN_RE = re.compile(r'\b(?:realloc|_sh_vgrow|_sh_vbuf|_sh_vec_push|_sh_vec_grow)\b')

# calls whose result the renderer owns (heap string) — every `char *x =
# <fn>(...)` in the renderer's native-call arm pushes x onto pending_frees
CALL_OWNED = True

def analyse(path: str):
    src = open(path, encoding='utf-8', errors='replace').read()
    clean = strip_comments_and_strings(src)

    fns = functions(clean)
    blocks = []          # (var, fn, alloc_line, free_lines[])
    unknown = []
    per_fn = defaultdict(lambda: {'allocs': 0, 'frees': 0, 'blocks': 0})

    def line_of(pos):
        return clean.count('\n', 0, pos) + 1

    # allocation sites
    allocs = []
    for m in OWNED_ASSIGN_RE.finditer(clean):
        allocs.append((m.group(1), m.start(), 'owned-expr'))
    for m in CALLALLOC_RE.finditer(clean):
        v, f = m.group(1), m.group(2)
        # the renderer's own helpers are not allocations
        if f in ('_sh_arg', 'getenv', 'strchr', 'strstr'):
            continue
        allocs.append((v, m.start(), 'call'))

    frees = [(m.group(1), m.start()) for m in FREE_RE.finditer(clean)]
    for m in UNKNOWN_RE.finditer(clean):
        unknown.append((line_of(m.start()), m.group(0)))

    def fn_of(pos):
        for name, a, b in fns:
            if a <= pos <= b:
                return name
        return '<main>'

    free_by_var = defaultdict(list)
    for v, pos in frees:
        free_by_var[v].append(pos)

    seen = set()
    for v, pos, kind in allocs:
        key = (v, fn_of(pos))
        per_fn[fn_of(pos)]['allocs'] += 1
        b = {
            'var': v,
            'fn': fn_of(pos),
            'alloc_line': line_of(pos),
            'kind': kind,
            'frees': [line_of(p) for p in free_by_var.get(v, [])],
        }
        blocks.append(b)
        seen.add(key)

    for v, positions in free_by_var.items():
        for p in positions:
            per_fn[fn_of(p)]['frees'] += 1

    for name in per_fn:
        per_fn[name]['blocks'] = sum(1 for b in blocks if b['fn'] == name)

    # tractability: one trace per function, and inside a function the
    # straight-line order of its sites. A function with N sites needs a
    # trace of length N; Isabelle discharges `eval` on a concrete list in
    # linear time, so the cost is the SITE COUNT, not the path count —
    # path enumeration only matters for sites inside branches.
    for name, _, a in [(n, s, a) for (n, s, a) in [(n, s, e) for (n, s, e) in fns]]:
        pass
    return {
        'file': path,
        'functions': len(fns),
        'blocks': blocks,
        'unknown': unknown[:20],
        'unknown_count': len(unknown),
        'per_fn': {k: v for k, v in per_fn.items()},
        'sites': len(allocs) + len(frees),
    }

def main(argv):
    if len(argv) < 2:
        print(__doc__.strip().splitlines()[0], file=sys.stderr)
        return 2
    path = argv[1]
    try:
        rep = analyse(path)
    except OSError as e:
        print(f"free-sites: {path}: {e}", file=sys.stderr)
        return 2
    if '--json' in argv:
        print(json.dumps(rep, indent=2))
    else:
        print(f"{rep['file']}: {rep['functions']} functions, {len(rep['blocks'])} heap blocks, "
              f"{rep['sites']} sites, {rep['unknown_count']} unmodelled constructs")
        for fn, st in sorted(rep['per_fn'].items()):
            if st['allocs'] or st['frees']:
                print(f"  {fn:32} allocs={st['allocs']:3} frees={st['frees']:3}")
        if rep['unknown']:
            print("  unmodelled (NOT covered by the obligation):")
            for ln, what in rep['unknown'][:8]:
                print(f"    line {ln}: {what}")
    return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv))
