#!/usr/bin/env bash
# verus-sync-foldarith.sh — regenerate proofs/verus/fold_arith_ast_pure.rs.
#
#   ./harness/verus-sync-foldarith.sh           # regenerate to stdout / $OUT_TMP
#   ./harness/verus-sync-foldarith.sh --check   # compare with the committed file
#
# WHY. Every earlier model is a hand transcription with a "can drift"
# caveat: `verus-sync-pass05.sh` notices that the six Pass 0.5 functions
# moved, but the spec mirror in `optimize_pass05.rs` is still written by
# hand. This extractor removes that class for the function it covers: the
# AST datatype and `fold_arith_ast` are emitted from `sh2perl/src/ir.rs`
# into a file that Verus VERIFIES, and the hand half (payload types, the
# op-table model, the theorems) contains no copy of the recursion. The
# text that runs and the text that is proved are one artifact, regenerated
# on every gate run; a source edit regenerates a different file and the
# gate's sync check goes red until it is re-blessed deliberately.
#
# TRANSCRIPTION CONTRACT (mechanical, and the complete list):
#   * `&ArithAst` value parameter, `open spec fn`, `decreases ast`;
#   * `String` -> `Str`, `IrType` -> `Ty` (abstract payloads; the fold only
#     clones them through, and the hand half defines both);
#   * `Num(i64)` -> `Num(int)`;
#   * `fold_arith_ast(x)` on a `Box` field reads through the box (`*x`);
#   * `.clone()` dropped (the spec matches by value);
#   * the early `return` in the Bin/Un arms becomes the arm's tail
#     (`if c { E } else { TAIL }`) — spec code has no `return`.
#
# REFUSE > GUESS: a source shape the extractor cannot transcribe is FATAL,
# not emitted half-translated. The marker in the template
# (`fold_arith_ast_pure.in`) is where the generated block lands.
#
# Exit: 0 emitted (or --check clean); 1 drift / unparseable source.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$root/sh2perl/src/ir.rs"
TEMPLATE="$root/sh2perl/proofs/verus/fold_arith_ast_pure.in"
BASE="$root/sh2perl/proofs/verus/fold_arith_ast_pure.rs"
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

[ -f "$SRC" ] || { echo "verus-sync-foldarith: no source: $SRC" >&2; exit 1; }
[ -f "$TEMPLATE" ] || { echo "verus-sync-foldarith: no template: $TEMPLATE" >&2; exit 1; }

gen() {
python3 - "$SRC" "$TEMPLATE" <<'PYEOF'
import hashlib
import sys

src_path, template_path = sys.argv[1], sys.argv[2]
src = open(src_path, encoding="utf-8").read()
sha = hashlib.sha256(src.encode()).hexdigest()[:12]

def fatal(msg):
    print(f"verus-sync-foldarith: FATAL: {msg}", file=sys.stderr)
    print("  (the source outgrew the extractor — extend it, do not hand-edit)", file=sys.stderr)
    sys.exit(1)

# ---- shipped refusal arms -------------------------------------------
# The hand half models the op table, but the REFUSAL arms are the part
# the value theorems (and the pins) claim about running code. Pin their
# exact shipped guard text here, so mutating any of them fails generation
# (and therefore the gate) instead of leaving the proof describing a
# guard the table no longer has. The op ids used by the hand model are
# documented by correspondence: 1 `+`, 2 `-`, 4 `*`, 5 `/`, 6 `%`,
# 8 `**` (7 is unused).
flat = " ".join(src.split())
REQUIRED_GUARDS = [
    ('"/" if b != 0 && !(a == i64::MIN && b == -1) => Some(a / b),',
     "div arm (zero divisor AND MIN / -1 refusal)"),
    ('"%" if b != 0 && !(a == i64::MIN && b == -1) => Some(a % b),',
     "mod arm (zero divisor AND MIN % -1 refusal)"),
    ('"**" if b >= 0 => Some(pow_wrapping(a, b)),',
     "pow arm (negative-exponent refusal)"),
]
for pat, what in REQUIRED_GUARDS:
    if pat not in flat:
        fatal(
            f"shipped `fold_bin_op` lost its {what}: expected `{pat}` "
            "— the proved refusal arms no longer match the running table"
        )

def matching(text, start):
    """Index of the brace matching text[start] == '{'."""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return i
    fatal("unbalanced braces")

def strip_docs(block):
    out = []
    for line in block.splitlines():
        s = line.strip()
        if s.startswith("///") or s.startswith("#[") or s.startswith("//"):
            continue
        out.append(line)
    return "\n".join(out)

# ---- the enum -------------------------------------------------------
sig = "pub enum ArithAst {"
i = src.find(sig)
if i < 0:
    fatal("cannot find `pub enum ArithAst`")
end = matching(src, src.index("{", i))
enum_text = src[i:end + 1]
enum_text = strip_docs(enum_text)
for a, b in [
    ("IrType", "Ty"),
    ("Box<ArithAst>", "Box<Ast>"),
    ("ArithAst", "Ast"),
    ("String", "Str"),
    ("Num(i64)", "Num(int)"),
]:
    enum_text = enum_text.replace(a, b)
if "pub enum Ast {" not in enum_text:
    fatal("enum transcription lost its head")
for variant in ["Num", "Var", "Ident", "Index", "Bin", "Un", "Cond", "Assign", "IncDec", "Sizeof", "Cast"]:
    if f"    {variant}" not in enum_text:
        fatal(f"enum lost the `{variant}` variant")
if "Box<ArithAst>" in enum_text:
    fatal("enum still mentions Box<ArithAst> after transcription")

# ---- fold_arith_ast -------------------------------------------------
sig = "pub(crate) fn fold_arith_ast(ast: &ArithAst) -> ArithAst {"
i = src.find(sig)
if i < 0:
    fatal("cannot find `pub(crate) fn fold_arith_ast`")
open_brace = src.index("{", i)
end = matching(src, open_brace)
fn_text = src[i:end + 1]

body_start = fn_text.index("{")
fn_head = (
    "pub open spec fn fold_arith_ast(ast: Ast) -> Ast\n"
    "    decreases ast,\n"
    "{"
)
fn_text = fn_head + fn_text[body_start + 1:]

for a, b in [("ArithAst", "Ast"), (".clone()", "")]:
    fn_text = fn_text.replace(a, b)
# Box-field reads: the spec matches by value, so the field is a Box.
for field in ["lhs", "rhs", "arg", "test", "then", "else_", "key"]:
    fn_text = fn_text.replace(f"fold_arith_ast({field})", f"fold_arith_ast(*{field})")

def enclosing_opens(text, pos):
    """Open-brace positions enclosing text[pos], innermost first."""
    depth = 0
    out = []
    i = pos - 1
    while i >= 0:
        if text[i] == "}":
            depth += 1
        elif text[i] == "{":
            if depth == 0:
                out.append(i)
            else:
                depth -= 1
        i -= 1
    return out


def fold_returns(text):
    """Rewrite the early `return E;` of the Bin/Un arms into the arm tail.

    The source shape is: an arm block whose guard is `if A { if B { return
    E; } }`, followed by the arm's tail expression. The rule is early-return
    elimination, applied inside the arm:

        if A { if B { return E; } } TAIL
      = if A { if B { E } else { TAIL } } else { TAIL }

    Anything that does not have this shape is FATAL, not guessed.
    """
    while "return " in text:
        m = text.index("return ")
        semi = text.index(";", m)
        expr = text[m + len("return "):semi].strip()
        if "return " in expr:
            fatal("nested `return` inside the returned expression")
        opens = enclosing_opens(text, m)
        # The arm's block is the innermost enclosing brace introduced by
        # `=> {` — everything between the return and it is the guard.
        arm_i = None
        for k, o in enumerate(opens):
            if text[:o].rstrip().endswith("=>"):
                arm_i = k
                break
        if arm_i is None:
            fatal("`return` is not inside a match arm")
        arm_open = opens[arm_i]
        arm_close = matching(text, arm_open)
        n = arm_i  # guard blocks to close before the arm's tail
        if n < 1:
            fatal("`return` not under a guard block")
        pos = semi + 1
        tail = text[pos:arm_close].strip()
        # strip the guard's closing braces out of the tail region
        skipped = 0
        j = pos
        while skipped < n:
            while j < arm_close and text[j] != "}":
                j += 1
            if j >= arm_close:
                fatal("cannot find the braces closing a `return`")
            j += 1
            skipped += 1
        tail = text[j:arm_close].strip()
        if not tail:
            fatal("`return` arm has no tail expression")
        out = text[:m] + expr
        pos = semi + 1
        skipped = 0
        while skipped < n:
            while pos < arm_close and text[pos] != "}":
                out += text[pos]
                pos += 1
            if pos >= arm_close:
                fatal("cannot find the braces closing a `return` (second pass)")
            out += "} else { " + tail + " }"
            pos += 1
            skipped += 1
        out += text[arm_close:]
        text = out
    return text

fn_text = fold_returns(fn_text)
if "return " in fn_text:
    fatal("a `return` survived transcription")
if "ArithAst" in fn_text:
    fatal("the function still mentions ArithAst after transcription")

generated = (
    "// ---- GENERATED: enum Ast + fold_arith_ast (from src/ir.rs) --------\n"
    + enum_text
    + "\n\n"
    + fn_text
)

header = f"""// GENERATED from sh2perl/src/ir.rs @ {sha}
// DO NOT EDIT — run harness/verus-sync-foldarith.sh
// Region: `enum ArithAst` and `fn fold_arith_ast` — the recursive Pass 0.5
// driver that runs on EVERY program.
//
// The block below is the RUNNING source text, mechanically transcribed, and
// this file is what Verus verifies: there is no hand copy of the recursion to
// drift from the code. Mechanical rewrites (the complete list):
//   * `&ArithAst` value parameter, `open spec fn`, `decreases ast`;
//   * `String` -> `Str`, `IrType` -> `Ty` (abstract payloads, never read);
//   * `Num(i64)` -> `Num(int)`;
//   * `fold_arith_ast(x)` on a `Box` field reads through the box (`*x`);
//   * `.clone()` dropped (the spec matches by value);
//   * the early `return` of the Bin/Un arms becomes the arm tail
//     (`if c {{ E }} else {{ TAIL }}`), since spec code has no `return`.
// Everything else is verbatim. A source shape outside these rewrites is
// FATAL in the extractor rather than emitted half-translated.
//
// The hand half below (payload types, the op-table model, the theorems) is
// the template `fold_arith_ast_pure.in`; it contains no copy of the
// implementation.
"""

template = open(template_path, encoding="utf-8").read()
marker = "// @@GENERATED@@"
if template.count(marker) != 1:
    fatal(f"template must contain exactly one `{marker}`")
before, after = template.split(marker)

sys.stdout.write(header + "\n" + before.rstrip() + "\n\n" + generated + after)
PYEOF
}

if [ "$CHECK" -eq 1 ]; then
  tmp="$(mktemp)"
  OUT_TMP="$tmp" bash "${BASH_SOURCE[0]}" || { rm -f "$tmp"; exit 1; }
  if diff -u "$BASE" "$tmp"; then
    echo "verus-sync-foldarith: clean ($(wc -l < "$tmp") lines)"
    rm -f "$tmp"
    exit 0
  fi
  rm -f "$tmp"
  echo "verus-sync-foldarith: DRIFT — regenerate $BASE and re-read the model" >&2
  exit 1
fi

if [ -n "${OUT_TMP:-}" ]; then
  gen > "$OUT_TMP"
else
  gen
fi
