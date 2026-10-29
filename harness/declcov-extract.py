#!/usr/bin/env python3
"""declcov-extract.py — the MECHANICAL TIE for `c_decl_coverage.rs`.

C_UB_PROOF.md §22's honest proviso said the model's walker chains are
"mirrors of c_backend.rs, not extracted (no mechanical extractor bridges
a transcription)".  This closes that gap: it extracts the arm chains of
the census walkers the model transcribes (INVENTORY / HOIST / VETO) and
emits them as a canonical listing that `harness/verus-sync-coverage.sh`
diffs against the committed baseline
(`sh2perl/proofs/verus/c_decl_coverage_sync.txt`).

What one line pins, per arm:

  - the EXACT arm pattern text (whitespace-normalised), guards
    included — `IrStmt::Expr(IrExpr::Call{..}) if is_printf_v_call(args)`
    vs the generic fallthrough is precisely the exclusivity claim the
    model's fidelity section makes, so a loosened guard moves the line;
  - the walker calls attributed to that arm's body (until the next arm
    pattern) — a dropped elsif-cond / For-iter / Try walk removes its
    `collect_*` call from exactly that line, which is the drift event
    that re-broke these censuses historically.

Nested `match` arms (the word-extraction inner matches) are recorded as
arms too — they pin the `local x=` / `unset` / `read` word shapes.

Determinism: source order, no timestamps, whitespace squeezed.  The
listing is region-stable: edits elsewhere in the shared c_backend.rs
(very common — many lanes) do not move it.

Usage:
  declcov-extract.py <c_backend.rs>          # canonical listing to stdout
  declcov-extract.py --sha <c_backend.rs>    # 12-hex digest of the listing
                                              # (manifest header)
Exit: 0 listing emitted; 1 a walked function is missing (source shape
outgrew the extractor — extend FUNCS, do not hand-edit the baseline).
"""
import hashlib
import re
import sys

# The walkers the Verus model transcribes, one entry per model side:
#   INVENTORY = collect_vars_full + collect_vars_expr   (col_*, Inv mode)
#   HOIST     = collect_assigned_vars + _expr           (col_*, Hoist mode)
#   VETO      = collect_param_write_targets/_stmt/_expr (paramw_*)
# (`collect_store_names`/`_expr` are the store census, deliberately
# OUTSIDE the model — §22's carve-out — so they are not extracted.)
FUNCS = [
    "collect_vars_full",
    "collect_vars_expr",
    "collect_assigned_vars",
    "collect_assigned_expr",
    "collect_param_write_targets",
    "collect_param_write_seq",
    "collect_param_write_stmt",
    "collect_param_write_expr",
]

# Walker / helper calls whose presence or ABSENCE inside an arm body is
# a fidelity fact (the model's chains call exactly these).
WALKERS = [
    "collect_assigned_vars",
    "collect_assigned_expr",
    "collect_vars_full",
    "collect_vars",
    "collect_vars_expr",
    "collect_param_write_targets",
    "collect_param_write_seq",
    "collect_param_write_stmt",
    "collect_param_write_expr",
    "collect_store_names",
    "collect_store_expr",
    "scan_raw_assigns_str",
    "param_write_target",
    "is_printf_v_call",
    "let_var_name",
    "unwrap_devnull_redirect",
]

CALL_RE = re.compile(r"\b(" + "|".join(WALKERS) + r")\s*\(")
ARM_START_RE = re.compile(r"^(IrStmt|IrExpr)::")
FN_RE = re.compile(r"^(pub\s+)?fn\s+([A-Za-z0-9_]+)\s*\(")


def fn_region(lines, name):
    """Source lines of a top-level fn: signature through the column-0 `}`."""
    start = None
    for i, line in enumerate(lines):
        m = FN_RE.match(line)
        if m and m.group(2) == name:
            start = i
            break
    if start is None:
        return None
    end = start + 1
    while end < len(lines):
        if lines[end].rstrip("\n") == "}":
            return lines[start : end + 1]
        end += 1
    return lines[start:]


def squeeze(text):
    return " ".join(text.split())


def arm_lines(fn_name, body):
    """Canonical lines for one walker: fn header, then one line per arm."""
    out = ["fn %s" % fn_name]
    seg_kind = "pre"  # 'pre' (before first arm) | 'pat' (collecting) | 'body'
    pat = []
    pending = []  # lines of the current body segment

    def flush():
        nonlocal pat, pending, seg_kind
        if seg_kind == "pre":
            calls = count_calls(" ".join(pending))
            if calls:
                out.append("  pre | calls: %s" % calls)
            pending = []
        elif seg_kind == "body" and pat:
            joined = squeeze(" ".join(pat))
            if "=>" in joined:
                head = squeeze(joined.split("=>", 1)[0])
            else:
                head = joined
            calls = count_calls(" ".join(pending))
            out.append(
                "  arm %s | calls: %s" % (head, calls if calls else "-")
            )
            pat, pending = [], []
        seg_kind = "pre"

    for raw in body[1:]:  # skip the signature line (recorded as fn header)
        s = raw.strip()
        if seg_kind != "pat" and (ARM_START_RE.match(s) or s.startswith("_ =>")):
            flush()
            seg_kind = "pat"
            pat = [s]
            if "=>" in s:
                # pattern and body share one line
                head, _, tail = s.partition("=>")
                pat = [head]
                pending = [tail]
                seg_kind = "body"
            continue
        if seg_kind == "pat":
            pat.append(s)
            if "=>" in s:
                head, _, tail = s.partition("=>")
                pat[-1] = head
                pending = [tail]
                seg_kind = "body"
            continue
        # body (or pre-arm) line
        pending.append(s)
    flush()
    return out


def count_calls(text):
    counts = {}
    for m in CALL_RE.finditer(text):
        counts[m.group(1)] = counts.get(m.group(1), 0) + 1
    if not counts:
        return ""
    return ",".join(
        "%s%s" % (n, ("x%d" % counts[n]) if counts[n] > 1 else "")
        for n in sorted(counts)
    )


def main(argv):
    args = [a for a in argv[1:] if a != "--sha"]
    sha_mode = "--sha" in argv[1:]
    if len(args) != 1:
        print(
            "usage: declcov-extract.py [--sha] <c_backend.rs>",
            file=sys.stderr,
        )
        return 2
    path = args[0]
    try:
        with open(path, encoding="utf-8") as fh:
            lines = fh.read().splitlines(keepends=True)
    except OSError as exc:
        print("declcov-extract: FATAL: %s" % exc, file=sys.stderr)
        return 1

    out = []
    missing = []
    for name in FUNCS:
        region = fn_region(lines, name)
        if region is None:
            missing.append(name)
            continue
        out.extend(arm_lines(name, region))
    if missing:
        print(
            "declcov-extract: FATAL: walker fn(s) not found in %s: %s"
            % (path, ", ".join(missing)),
            file=sys.stderr,
        )
        return 1

    text = "\n".join(out) + "\n"
    if sha_mode:
        print(hashlib.sha256(text.encode("utf-8")).hexdigest()[:12])
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
