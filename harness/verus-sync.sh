#!/usr/bin/env bash
# verus-sync.sh — regenerate the SYNCED region of the Verus proof from the
# Rust source, or fail loudly if the source outgrew the generator.
#
#   ./harness/verus-sync.sh                  # regenerate proofs/verus/i32_bounds_sync.rs
#   ./harness/verus-sync.sh --check          # regenerate to temp, diff, exit 1 on drift
#   ./harness/verus-sync.sh path/to/i32_provable.rs   # explicit source (worktree)
#
# DESIGN. The committed proof (proofs/verus/i32_bounds_exec.rs) DUPLICATES
# arith_bounds by hand, so nothing stops it going stale. This script closes
# that hole for the SYNCED region only:
#
#   SYNCED (generated, DO NOT EDIT): consts I32_MIN/I32_MAX, fn within_i32,
#     fn arith_bounds, and the enum ArithAst constructor list.
#   HAND (committed, reviewed): spec ev/in_i32/op_is, the (bool,lo,hi)
#     postcondition bridge, str_eq_* shims, bounds_sound_exec proof.
#
# The split exists because the two mechanical rewrites Verus needs
# (match-on-&str -> if-chains; then_some -> explicit if) are textual and
# stable, while the proof itself is hand work.
#
# What makes a source change break loudly instead of silently:
#   * new match arm / new operator string / new ArithAst variant /
#     removed function / renamed const -> extraction regex finds nothing
#     to emit (or the constructor list mismatches) -> exit 1.
#   * semantic edit inside a covered arm (changed corner order, dropped the
#     within_i32 gate) -> regenerates cleanly, Verus then fails -> exit 1
#     at the proof step (the gate script runs verus after sync).
# What it does NOT catch: an edit to a `_ => None` arm (still refuses),
# an edit to comments/docs/tests. Those keep the verdict identical.
#
# Exit: 0 emitted (or --check clean); 1 drift / unparseable source.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$root/sh2perl/src/transforms/i32_provable.rs}"
CHECK=0
if [ "${1:-}" = "--check" ]; then CHECK=1; SRC="$root/sh2perl/src/transforms/i32_provable.rs"; fi
if [ "${2:-}" = "--check" ]; then CHECK=1; fi
OUT="$root/sh2perl/proofs/verus/i32_bounds_sync.rs"

[ -f "$SRC" ] || { echo "verus-sync: no source: $SRC" >&2; exit 1; }

python3 - "$SRC" <<'PYEOF' > "${OUT_TMP:-/dev/stdout}"
import re, sys, hashlib

src_path = sys.argv[1]
text = open(src_path, encoding="utf-8").read()
sha = hashlib.sha256(text.encode()).hexdigest()[:12]

def grab(pat, name, flags=0):
    m = re.search(pat, text, flags)
    if not m:
        print(f"verus-sync: FATAL: cannot extract {name} from {src_path}", file=sys.stderr)
        print(f"  (the source outgrew the generator — extend the patterns, do not hand-edit)", file=sys.stderr)
        sys.exit(1)
    return m.group(0)

# --- 1. consts -----------------------------------------------------------
consts = grab(r"const I32_MIN: i128 = [^;]+;\nconst I32_MAX: i128 = [^;]+;", "I32_MIN/I32_MAX consts")

# --- 2. within_i32 --------------------------------------------------------
within = grab(r"fn within_i32\(lo: i128, hi: i128\) -> bool \{\n(?:.*\n)*?\}", "fn within_i32")

# --- 3. arith_bounds ------------------------------------------------------
# Balanced-brace extraction: from `fn arith_bounds` to its closing brace at col 0.
start = text.find("fn arith_bounds(a: &ArithAst) -> Option<(i128, i128)> {")
if start < 0:
    print("verus-sync: FATAL: cannot find fn arith_bounds", file=sys.stderr)
    sys.exit(1)
depth, i, n = 0, start, len(text)
while i < n:
    if text[i] == "{":
        depth += 1
    elif text[i] == "}":
        depth -= 1
        if depth == 0:
            break
    i += 1
if depth != 0:
    print("verus-sync: FATAL: unbalanced braces in arith_bounds", file=sys.stderr)
    sys.exit(1)
bounds = text[start:i + 1]

# --- 4. enum constructor list --------------------------------------------
# The proof's ArithAst must name every variant the source matches on. We
# extract variant names from sh2perl/src/ir.rs and require the proof enum
# (HAND region) to list them — checked by --check comparing constructor sets.
ir_path = src_path.replace("src/transforms/i32_provable.rs", "src/ir.rs")
ir = open(ir_path, encoding="utf-8").read()
m = re.search(r"pub enum ArithAst \{(.*?)\n\}", ir, re.S)
if not m:
    print("verus-sync: FATAL: cannot find enum ArithAst in ir.rs", file=sys.stderr)
    sys.exit(1)
variants = re.findall(r"^\s{4}([A-Z][A-Za-z0-9_]*)", m.group(1), re.M)
if not variants:
    print("verus-sync: FATAL: no variants extracted from ArithAst", file=sys.stderr)
    sys.exit(1)

# --- rewrites -------------------------------------------------------------
def rewrite(body):
    """Two mechanical rewrites, nothing else.

    1. then_some: `P.then_some(E)` -> `(if P { Some(E) } else { None })`.
       The pattern is deliberately narrow (no nested parens inside E beyond
       one level -- the source has exactly `within_i32(..).then_some((..))`).
    2. match-on-&str: each `match <expr> {` whose arms are string literals
       or `_` becomes an if/else-if/else chain. Anything else is FATAL.
    """
    out = body
    # -- 1. then_some ------------------------------------------------------
    # `P.then_some((E))` -> `(if P { Some((E)) } else { None })`. The value
    # is a tuple (contains a comma), so a regex cannot delimit it: scan
    # with balanced parens from `.then_some(`. The predicate here is
    # exactly `within_i32(lo, hi)` — anything else is FATAL, because a
    # then_some anywhere else is a new shape the proof has not seen.
    def conv_then_once(text):
        m = re.search(r"within_i32\(lo, hi\)\.then_some\(", text)
        if not m:
            return text, False
        j = m.end() - 1  # the `(` of `.then_some(`
        assert text[j] == "("
        depth, k = 0, j
        while k < len(text):
            if text[k] == "(":
                depth += 1
            elif text[k] == ")":
                depth -= 1
                if depth == 0:
                    break
            k += 1
        if depth != 0:
            print("verus-sync: FATAL: unbalanced then_some(", file=sys.stderr)
            sys.exit(1)
        val = text[j:k + 1]
        repl = f"(if within_i32(lo, hi) {{ Some({val}) }} else {{ None }})"
        return text[:m.start()] + repl + text[k + 1:], True
    while True:
        out, again = conv_then_once(out)
        if not again:
            break
    if ".then_some(" in out:
        print("verus-sync: FATAL: then_some outside within_i32(lo, hi) — new shape, extend the generator", file=sys.stderr)
        sys.exit(1)
    # -- 2. match on op.as_str() -------------------------------------------
    # Recursive: an arm body may itself contain `match op.as_str()` (the Un
    # arm nests one). Each level is rewritten by the same function.
    def conv_matches(lines):
        res, i = [], 0
        nesting = 0  # braces opened inside arm bodies on THIS level
        while i < len(lines):
            ln = lines[i]
            m = (nesting == 0) and re.match(r"^(\s*)(?:[A-Za-z_][\w\s:{},]*=>\s*)?match\s+(op\.as_str\(\))\s*\{\s*$", ln)
            if not m:
                res.append(ln)
                i += 1
                continue
            ind, expr = m.group(1), m.group(2)
            i += 1
            arms = []
            cur_kind, cur_lit, cur_body = None, None, []
            while i < len(lines):
                l2 = lines[i]
                # A nested `match op.as_str() {` INSIDE an arm body (the Un
                # arm is `=> match op.as_str() {` on one line): consume
                # through its closing brace at arm-body indent and convert
                # recursively. `nesting` counts braces opened by body lines
                # so the nested block's own arms are not read as ours.
                # arm is `=> match op.as_str() {` on one line, possibly with a
                # leading arm pattern (`Un {..} => match ...`). Consume through
                # its closing brace and convert recursively.
                mm2 = re.match(r"^(.*=>\s*)match\s+(op\.as_str\(\))\s*\{\s*$", l2)
                if mm2:
                    j = i + 1
                    nind = l2[:len(l2) - len(l2.lstrip())]
                    while j < len(lines):
                        if re.match(r"^" + re.escape(nind) + r"\}\s*,?\s*$", lines[j]):
                            break
                        j += 1
                    if j >= len(lines):
                        print("verus-sync: FATAL: unterminated nested match", file=sys.stderr)
                        sys.exit(1)
                    # keep the opening line, convert the inside, keep closer
                    cur_body.append(l2)
                    for bl in conv_matches(lines[i + 1:j]):
                        cur_body.append(bl)
                    cur_body.append(lines[j])
                    i = j + 1
                    continue
                if re.match(r"^" + re.escape(ind) + r"\}\s*$", l2):
                    break
                ma = re.match(r'^\s*"((?:[^"\\]|\\.)*)"\s*=>\s*(.*)$', l2)
                mw = re.match(r"^\s*_\s*=>\s*(.*)$", l2)
                if ma:
                    if cur_kind is not None:
                        arms.append((cur_kind, cur_lit, cur_body))
                    cur_kind, cur_lit, cur_body = "lit", ma.group(1), []
                    rest = ma.group(2).strip()
                    if rest == "{":
                        # block arm (`"*" => {`): the `{` is structure; the
                        # block's own closer is consumed by brace counting
                        # below, not stored as body text.
                        cur_body.append("BLOCK_OPEN")
                    elif rest:
                        cur_body.append(rest)
                elif mw:
                    if cur_kind is not None:
                        arms.append((cur_kind, cur_lit, cur_body))
                    cur_kind, cur_lit, cur_body = "wild", None, []
                    rest = mw.group(1).strip()
                    if rest:
                        cur_body.append(rest)
                else:
                    if cur_kind is None:
                        print(f"verus-sync: FATAL: code inside match before any arm: {l2!r}", file=sys.stderr)
                        sys.exit(1)
                    if l2.strip() == "}" and "BLOCK_OPEN" in cur_body:
                        # matching closer of a block arm: drop both markers
                        cur_body.remove("BLOCK_OPEN")
                    else:
                        cur_body.append(l2)
                    # track braces so a NESTED match's arms are body text here,
                    # converted by the recursive conv_matches call at emit time
                    nesting += l2.count("{") - l2.count("}")
                i += 1
            else:
                print("verus-sync: FATAL: unterminated match block", file=sys.stderr)
                sys.exit(1)
            if cur_kind is not None:
                arms.append((cur_kind, cur_lit, cur_body))
            if not arms or arms[-1][0] != "wild":
                print("verus-sync: FATAL: match without trailing `_ =>` arm", file=sys.stderr)
                sys.exit(1)
            for k, (kind, lit, blines) in enumerate(arms):
                kw = "if" if k == 0 else ("else if" if kind == "lit" else "else")
                # comments stay where they are (above the arm code); only
                # CODE lines participate in the single-vs-multi decision.
                code = [b for b in blines if b.strip() and not b.strip().startswith("//") and b.strip() != "BLOCK_OPEN"]
                stripped = [b.strip().rstrip(",") for b in code]
                ncode = len(stripped)
                comments = []
                # A leading `{` line opens the arm's own block (multi-line arm
                # written as `"*" => { ... }`); it is structure, not code.
                # Drop it AND its matching closer so they are not counted or
                # re-emitted (the if-chain supplies its own braces).
                fc = next((t for t in stripped if t not in ("{", "},")), None)
                # A leading `{` (after comments) opens the arm's own block.
                fci = next((t for t in range(len(blines))
                            if blines[t].strip() and not blines[t].strip().startswith("//")), None)
                if fci is not None and blines[fci].strip() == "{":
                    depth = 0
                    cut = None
                    for t, bl in enumerate(blines):
                        if t < fci:
                            continue
                        st = bl.strip()
                        if not st or st.startswith("//"):
                            continue
                        depth += st.count("{") - st.count("}")
                        if depth <= 0:
                            cut = t
                            break
                    if cut is None:
                        print("verus-sync: FATAL: unbalanced arm block", file=sys.stderr)
                        sys.exit(1)
                    blines = [b for t2, b in enumerate(blines) if t2 != fci and t2 != cut]
                    code = [b for b in blines if b.strip() and not b.strip().startswith("//")]
                    stripped = [b.strip().rstrip(",") for b in code]
                    ncode = len(stripped)
                if kind == "lit":
                    if ncode == 1:
                        res.append(f"{ind}{kw} {expr} == \"{lit}\" {{ {stripped[0]} }}")
                    else:
                        res.append(f"{ind}{kw} {expr} == \"{lit}\" {{")
                        # re-indent the arm body under the if: strip the COMMON
                        # indent (the arm's own block indent), then add 4.
                        indents = [len(b) - len(b.lstrip()) for b in code]
                        base = min(indents, default=0)
                        shifted = []
                        for b in code:
                            nb = b[base:] if len(b) >= base else b.lstrip()
                            shifted.append(("    " + nb) if nb.strip() else nb)
                        res.extend(conv_matches(shifted))
                        res.append(f"{ind}}}")
                else:
                    if len(stripped) == 1:
                        res.extend(comments)
                        res.append(f"{ind}{kw} {{ {stripped[0]} }}")
                    else:
                        res.extend(comments)
                        res.append(f"{ind}{kw} {{")
                        res.extend(conv_matches([("    " + b) if b.strip() else b for b in blines]))
                        res.append(f"{ind}}}")
            i += 1
        return res
    # pre-pass: `PAT => match op.as_str() { ... }` where the match opens at
    # the END of an arm line (the Un arm). Convert the nested block in place.
    lines = out.split("\n")
    res2, i2 = [], 0
    while i2 < len(lines):
        ln = lines[i2]
        mm = re.match(r"^(\s*.*?=>\s*)match\s+(op\.as_str\(\))\s*\{\s*$", ln)
        if mm:
            prefix = mm.group(1)
            nind = ln[:len(ln) - len(ln.lstrip())]
            j = i2 + 1
            while j < len(lines):
                if re.match(r"^" + re.escape(nind) + r"\}\s*,?\s*$", lines[j]):
                    break
                j += 1
            if j >= len(lines):
                print("verus-sync: FATAL: unterminated inline match", file=sys.stderr)
                sys.exit(1)
            inner = conv_matches(lines[i2 + 1:j])
            trail = "," if lines[j].rstrip().endswith(",") else ""
            res2.append(prefix + "{")
            # inner was indented for a block at nind; shift it to prefix+4
            want = len(prefix) - len(prefix.lstrip()) + 4
            have = len(nind) + 4
            shift = want - have
            for bl in inner:
                if bl.strip():
                    cur = len(bl) - len(bl.lstrip())
                    res2.append(" " * max(0, cur + shift) + bl.lstrip())
                else:
                    res2.append(bl)
            res2.append(nind + "}" + trail)
            i2 = j + 1
            continue
        res2.append(ln)
        i2 += 1
    out_lines = conv_matches(res2)
    res = out_lines
    i = len(res)
    return "\n".join(res)

    return "\n".join(res)


bounds_v = rewrite(bounds)
within_v = rewrite(within)
consts_v = consts  # plain consts need no rewrite

# The generated file keeps Option<(i128,i128)> + `?` EXACTLY as the source:
# the HAND proof wraps it in the (bool,lo,hi) bridge. Do NOT convert here —
# conversion is proof-shape, and proof-shape is hand territory.
print(f"// GENERATED from sh2perl/src/transforms/i32_provable.rs @ {sha}")
print("// DO NOT EDIT — run harness/verus-sync.sh")
print("// Region: consts I32_MIN/I32_MAX, fn within_i32, fn arith_bounds.")
print("// Rewrites: match-on-&str -> if-chains; then_some -> explicit if.")
print("// The HAND proof (spec ev, postcondition bridge) is in")
print("// sh2perl/proofs/verus/i32_bounds_exec.rs and calls arith_bounds_raw.")
print("//")
print(f"// enum ArithAst constructors in scope: {' '.join(variants)}")
print("verus! {")
print()
print(consts_v)
print()
print(within_v)
print()
print(bounds_v.replace("fn arith_bounds(", "fn arith_bounds_raw("))
print()
print("} // verus!")
PYEOF
