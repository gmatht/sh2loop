#!/usr/bin/env python3
"""perl_idiom_census.py — the "no non-idiomatic Perl" census for the Perl emit.

This is the regression gate for the idiom work recorded in PLAN.md ("fifteenth
pass" and earlier). It renders the corpus through the SAME command `./fail`
runs — `otranspilerl-cli --target pl <example>`, with the UU-FFI environment
the gate installs — and counts, in that rendered output, every form the
renderer is no longer supposed to emit. A class that comes back fails the run.

    harness/perl_idiom_census.py                 # render the corpus, census it
    harness/perl_idiom_census.py --jobs 8        # parallel render workers
    harness/perl_idiom_census.py --keep DIR      # keep the renders for reading
    harness/perl_idiom_census.py --renders DIR   # census an existing render dir
    harness/perl_idiom_census.py --inventory F   # one line per hit

Exit status: 0 when every FORBIDDEN class is 0 and every render succeeded,
1 otherwise. ALLOWED classes are printed with their counts and never fail the
run — they are the forms PLAN.md argues are idiomatic (see below).

Class definitions
-----------------
Everything is counted OUTSIDE the runtime helpers: `sub __sh…` / `sub __SH…`
bodies and the `# __SH_RUN_EXT_BEGIN` … `_END` seam are removed before
scanning, so `__SH…` bookkeeping (and anything the runtime does for itself) is
never touched or reported. Remaining text is scanned with a quote/comment mask
(strings `'…'`, `"…"`, backticks, the quote-like operators q qq qw qr qx m s
tr y, and `#` comments), so a `do {` inside a string is not a hit.

Forbidden (any hit fails):
  stmt_do          `do { … };` in statement position — a block that scopes
                   nothing; the emitter hoists the value or splits the body.
  value_do         `do { … }` in value position — replaced by a bare block
                   plus a declared scalar (the "value-`do`" passes).
  empty_block      `{ }` with no statements (only whitespace/`;` between).
  bare_stmt_block  a statement that is exactly `{ … };` around one statement.
  dead_my_init     `my $v = …;` whose `$v` is never read (name-boundary aware,
                   and `${v}` counts as a read; `${v:modifier}` does not — that
                   is the child shell's expansion, not Perl's).
  pipe_autoflush   `$|` — autoflush set on whichever handle is selected.
  string_eval      `eval` applied to a string (`eval "…"`, `eval $x`).
  amp_call         `&name(…)` / `&name;` sigil call.
  at_bracket       `@{[ … ]}` interpolation trick.
  select_call      `select(…)` — the glob-swap/save-restore dance.
  dup_semicolon    `;;`.
  local_stdout     `local *STDOUT` glob swap.
  unused_my        bare `my $v;` whose `$v` is never read.
  bare_1           a statement that is just `1;`.
  bare_return      `return;` with no value.

Allowed (reported, never a failure) — argued class by class in PLAN.md:
  local_slurp      `local $/` / `local $INPUT_RECORD_SEPARATOR` — the slurp
                   idiom; no non-`local` way to read a file in one call.
  local_env        `local %ENV = %ENV` — bash subshell environment isolation.
  local_other      `local @__sh_args` / `local $__sh_args_n` (sub call frame),
                   `local *STDIN` (a child's stdin is the glob), `local $_`.
  tail_return      `return EXPR;` — explicit return is idiomatic Perl; the
                   non-idiomatic variants are `return undef` and bare
                   `return;` (the latter is a forbidden class, `bare_return`).
  slurp_do         `do { local $/; … }` — the canonical way to read a whole
                   file inside an expression (a bare block cannot stand in
                   expression position, and the `local` needs its own scope).
  dead_child_error `$CHILD_ERROR = 0;` immediately before
                   `$CHILD_ERROR = <call>`: NOT provably dead from the text,
                   because the callee may read the status global (the emitted
                   runtime does contain `return $CHILD_ERROR;`), so the
                   renderer keeps the seed and the class is reported, not
                   failed. The call-free variant IS removed
                   (`strip_dead_child_error_assignments`).
"""

import argparse
import collections
import concurrent.futures
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CLI = os.path.join(ROOT, "otranspilerl", "target", "debug", "otranspilerl-cli")
CORPUS = os.path.join(ROOT, "sh2perl", "examples")

# The gate's environment (see run_one_test in ./fail): with the FFI libraries
# present the renderer emits `__sh_uu_run(…)` calls instead of fork/exec.
GATE_ENV = {
    "SH2_UU_LIB": os.path.join(ROOT, "sh2perl", "runtime", "lib", "libcoreutils_ffi.so"),
    "SH2_UU_PIPELINE_LIB": os.path.join(
        ROOT, "sh2perl", "runtime", "lib", "libcoreutils_ffi_pipeline.so"
    ),
    "UU_FFI_MULTICALL": os.path.join(
        ROOT, "sh2perl", "runtime", "lib", "coreutils-ffi-multicall"
    ),
    "OTRANSPILER_ROOT": ROOT,
}

# The corpus contains negative parser tests: their render is a deliberate
# `print STDERR "syntax error: …"; exit 2;` stub, which has no program to
# census. Anything OTHER than these producing a stub is a failing measurement.
STUB_ALLOWLIST = {
    "parse-double-semicolon",
    "parse-error-doublesemicolon",
    "parse-parameter-expansion-eof",
    "parse-paren-after-do",
    "parse-unexpected-end-of-input",
}

FORBIDDEN = [
    "stmt_do",
    "value_do",
    "empty_block",
    "bare_stmt_block",
    "dead_my_init",
    "pipe_autoflush",
    "string_eval",
    "amp_call",
    "at_bracket",
    "select_call",
    "dup_semicolon",
    "local_stdout",
    "unused_my",
    "bare_1",
    "bare_return",
]
ALLOWED = [
    "local_slurp",
    "local_env",
    "local_other",
    "tail_return",
    "slurp_do",
    "dead_child_error",
]

OPENERS = {"{": "}", "[": "]", "(": ")", "<": ">"}
QOPS = ("tr", "qq", "qw", "qr", "qx", "q", "m", "s", "y")
FLAGS = set("msixpogcedualr")
HELPER_PREFIXES = ("sub __sh", "sub __SH", "BEGIN {", "# __SH_RUN_EXT_BEGIN")


def scan_mask(text):
    """mask[i] is True when text[i] is inside a string, quote-like or comment."""
    n = len(text)
    mask = [False] * n

    def mark(a, b):
        for k in range(max(0, a), min(n, b)):
            mask[k] = True

    def one(j, d):
        """End index of a delimited run starting AT the delimiter j."""
        if d in OPENERS:
            close = OPENERS[d]
            depth = 0
            while j < n:
                c = text[j]
                if c == "\\":
                    j += 2
                    continue
                if c == d:
                    depth += 1
                elif c == close:
                    depth -= 1
                    if depth == 0:
                        return j + 1
                j += 1
            return n
        j += 1
        while j < n:
            if text[j] == "\\":
                j += 2
                continue
            if text[j] == d:
                return j + 1
            j += 1
        return n

    i = 0
    while i < n:
        c = text[i]
        if c == "#" and not (i and text[i - 1] == "$"):
            j = text.find("\n", i)
            j = n if j < 0 else j
            mark(i, j)
            i = j
            continue
        if c in "'\"`":
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == c:
                    break
                j += 1
            mark(i, j + 1)
            i = j + 1
            continue
        hit = None
        for cand in QOPS:
            if not text.startswith(cand, i):
                continue
            k = i + len(cand)
            if k < n and (text[k].isalnum() or text[k] == "_"):
                continue  # a longer identifier, e.g. `sort` / `map`
            while k < n and text[k] in " \t":
                k += 1
            if k >= n or text[k] not in "/|{([<!#~":
                continue
            hit = (cand, k)
            break
        if hit:
            cand, k = hit
            end = one(k, text[k])
            if cand in ("s", "tr", "y"):
                # the second half has its own delimiter (or shares `{}` pairs)
                if text[k] in OPENERS:
                    end = one(end, text[k])
                else:
                    e2 = end
                    while e2 < n and text[e2] != text[k]:
                        if text[e2] == "\\":
                            e2 += 2
                            continue
                        e2 += 1
                    end = min(n, e2 + 1)
            while end < n and text[end] in FLAGS:
                end += 1
            mark(i, end)
            i = end
            continue
        if text.startswith("<<", i):
            m = re.match(r"<<~?\s*(['\"]?)([A-Za-z_]\w*)\1", text[i:])
            if m:
                tag = m.group(2)
                body_start = text.find("\n", i)
                if body_start < 0:
                    body_start = n
                end = n
                pos = body_start
                while pos < n:
                    nl = text.find("\n", pos + 1)
                    if nl < 0:
                        nl = n
                    line = text[pos + 1 : nl]
                    if line.strip() == tag:
                        end = nl
                        break
                    pos = nl
                mark(i, end)
                i = end
                continue
        i += 1
    return mask


def strip_helpers(text):
    """Drop the runtime's own subs and the `__SH_RUN_EXT` seam.

    Brace matching is mask-aware: a `{` inside a string or a `q{…}` payload is
    not a block delimiter. (Line-based counting breaks exactly there — the
    runtime's helpers are full of `q{…}` command payloads — and a mis-terminated
    helper leaves its body in the census, where a `do {` or an empty `{ }`
    reads as emitted code.)
    """
    mask = scan_mask(text)
    n = len(text)
    keep = [True] * n

    def blank(a, b):
        for k in range(max(0, a), min(n, b)):
            keep[k] = False

    def match_block(open_at):
        """Index just past the `}` matching the `{` at `open_at` (or n)."""
        depth = 0
        k = open_at
        while k < n:
            if mask[k]:
                k += 1
                continue
            if text[k] == "{":
                depth += 1
            elif text[k] == "}":
                depth -= 1
                if depth == 0:
                    return k + 1
            k += 1
        return n

    i = 0
    while i < n:
        # a helper sub starts its line and names a `__sh…` package sub
        if (i == 0 or text[i - 1] == "\n") and text.startswith(("sub __sh", "sub __SH"), i):
            j = text.find("{", i)
            if j < 0:
                break
            end = match_block(j)
            blank(i, end)
            i = end
            continue
        if (i == 0 or text[i - 1] == "\n") and text.startswith("BEGIN {", i):
            end = match_block(text.find("{", i))
            blank(i, end)
            i = end
            continue
        if (i == 0 or text[i - 1] == "\n") and text.startswith("# __SH_RUN_EXT_BEGIN", i):
            m = text.find("\n# __SH_RUN_EXT_END", i)
            end = n if m < 0 else text.find("\n", m + 1)
            if end < 0:
                end = n
            blank(i, end)
            i = end
            continue
        i += 1

    return "".join(ch if keep[k] else "\n" if ch == "\n" else "" for k, ch in enumerate(text))


def census(text):
    """Count every class in one render. Returns (counts, hits)."""
    body = strip_helpers(text)
    mask = scan_mask(body)
    n = len(body)
    counts = collections.Counter()
    hits = []

    def note(cls, i, snippet=None):
        counts[cls] += 1
        if snippet is None:
            snippet = body[max(0, i - 60) : i + 120]
        hits.append((cls, i, " ".join(snippet.split())[:150]))

    def unmasked(lit):
        i = 0
        while i + len(lit) <= n:
            if body.startswith(lit, i) and not any(mask[i : i + len(lit)]):
                yield i
            i += 1

    def is_slurp_do(i):
        """`do { local $/; … }` — the canonical slurp expression."""
        body_after = body[i + 4 : i + 80].lstrip()
        return body_after.startswith("local $/") or body_after.startswith(
            "local $INPUT_RECORD_SEPARATOR"
        )

    def stmt_spans():
        spans, start, depth, i = [], 0, 0, 0
        while i < n:
            if mask[i]:
                i += 1
                continue
            c = body[i]
            if c in "([":
                depth += 1
            elif c in ")]":
                depth -= 1
            elif c == ";" and depth <= 0:
                spans.append((start, i))
                start = i + 1
            i += 1
        return spans

    # ── statement structure: `do {`, empty blocks, bare blocks, `;;` ────────
    i = 0
    while i < n:
        if mask[i]:
            i += 1
            continue
        c = body[i]
        if body.startswith("do {", i):
            k = i - 1
            while k >= 0 and (mask[k] or body[k] in " \t\n\r"):
                k -= 1
            at_stmt = k < 0 or body[k] in ";{}"
            if at_stmt:
                note("stmt_do", i)
            elif is_slurp_do(i):
                note("slurp_do", i)
            else:
                note("value_do", i)
        if c == "{":
            j = i + 1
            while j < n and not mask[j] and body[j] in " \t\n;":
                j += 1
            if j < n and not mask[j] and body[j] == "}":
                note("empty_block", i)
        if c == ";" and body.startswith(";;", i):
            note("dup_semicolon", i)
        i += 1

    # ── per-statement classes ───────────────────────────────────────────────
    spans = stmt_spans()
    for a, b in spans:
        t = body[a:b].strip()
        if not t:
            continue
        if t == "1":
            note("bare_1", a)
        if t == "return":
            note("bare_return", a)
        if re.fullmatch(r"\{[^{};]*;\s*\}", t):
            note("bare_stmt_block", a)
    for (a0, a1), (b0, b1) in zip(spans, spans[1:]):
        if body[a0:a1].strip() == "$CHILD_ERROR = 0" and body[b0:b1].strip().startswith(
            "$CHILD_ERROR = "
        ):
            note("dead_child_error", a0)

    # ── flat token classes ──────────────────────────────────────────────────
    for i in unmasked("$|"):
        note("pipe_autoflush", i)
    for i in unmasked("@[{"):
        note("at_bracket", i)
    for i in unmasked("local *STDOUT"):
        note("local_stdout", i)
    for i in unmasked("select("):
        note("select_call", i)
    for i in unmasked("local "):
        tail = body[i : i + 40]
        if tail.startswith("local $/") or tail.startswith("local $INPUT_RECORD_SEPARATOR"):
            note("local_slurp", i)
        elif tail.startswith("local %ENV"):
            note("local_env", i)
        else:
            note("local_other", i)
    for m in re.finditer(r'(?<![&\w])eval\s*["\'$]', body):
        if not mask[m.start()]:
            note("string_eval", m.start())
    for m in re.finditer(r"(?<![&\w])&[A-Za-z_]\w*\s*[\(;]", body):
        if not mask[m.start()]:
            note("amp_call", m.start())
    for m in re.finditer(r"(?m)^\s*return\s+[^;]+;", body):
        if not mask[m.start()]:
            note("tail_return", m.start())

    # ── declarations ────────────────────────────────────────────────────────
    def read_elsewhere(name, start, end):
        rest = body[:start] + body[end:]
        reads = r"[$@%&*]" + re.escape(name) + r"\b" + "|" + r"\{\s*" + re.escape(name) + r"\s*\}"
        return re.search(reads, rest) is not None

    for m in re.finditer(r"(?m)^(\s*)my\s+\$(\w+)\s*=\s*([^;\n]+);", body):
        name = m.group(2)
        if name.startswith("__SH"):
            continue  # runtime bookkeeping: never ours to judge
        if not read_elsewhere(name, m.start(2), m.end(0)):
            note("dead_my_init", m.start())
    for m in re.finditer(r"(?m)^(\s*)my\s+\$(\w+);", body):
        name = m.group(2)
        if name.startswith("__SH"):
            continue
        if not read_elsewhere(name, m.start(2), m.end(0)):
            note("unused_my", m.start())

    return counts, hits


# ── rendering ───────────────────────────────────────────────────────────────


def render_all(corpus, binary, jobs):
    """Render every `*.sh` in `corpus` with the gate's command into a temp dir."""
    examples = sorted(f for f in os.listdir(corpus) if f.endswith(".sh"))
    out_dir = tempfile.mkdtemp(prefix="idiom-census-")
    env = dict(os.environ)
    env.update({k: v for k, v in GATE_ENV.items() if os.path.exists(v)})

    def one(name):
        dst = os.path.join(out_dir, name[:-3] + ".pl")
        try:
            with open(dst, "wb") as fh:
                p = subprocess.run(
                    [binary, "--target", "pl", os.path.join(corpus, name)],
                    stdout=fh,
                    stderr=subprocess.DEVNULL,
                    env=env,
                    timeout=120,
                )
            return name, p.returncode, dst
        except (OSError, subprocess.SubprocessError) as exc:
            return name, -1, str(exc)

    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=jobs) as pool:
        for res in pool.map(one, examples):
            results.append(res)
    return out_dir, results


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--corpus", default=CORPUS, help="example dir (default: sh2perl/examples)")
    ap.add_argument("--binary", default=CLI, help="otranspilerl-cli path")
    ap.add_argument("--jobs", type=int, default=min(8, os.cpu_count() or 1))
    ap.add_argument("--renders", metavar="DIR", help="census an existing render dir")
    ap.add_argument("--keep", metavar="DIR", help="keep the fresh renders here")
    ap.add_argument("--inventory", metavar="FILE", help="write one line per hit")
    args = ap.parse_args(argv)

    render_failures = []
    if args.renders:
        render_dir = args.renders
        files = sorted(f for f in os.listdir(render_dir) if f.endswith(".pl"))
    else:
        if not os.path.exists(args.binary):
            print(
                "perl_idiom_census: %s is missing — build it first:\n"
                "  harness/build-lock.sh --role core -- bash -c 'cd otranspilerl &&"
                " cargo build --bin otranspilerl-cli'" % args.binary,
                file=sys.stderr,
            )
            return 2
        render_dir, results = render_all(args.corpus, args.binary, args.jobs)
        for name, rc, dest in results:
            if rc != 0:
                render_failures.append((name, dest if isinstance(dest, str) else dest))
        files = sorted(f for f in os.listdir(render_dir) if f.endswith(".pl"))

    totals = collections.Counter()
    inventory = []
    empty_or_stub = []
    stubs = []
    for name in files:
        path = os.path.join(render_dir, name)
        try:
            text = open(path, errors="replace").read()
        except OSError as exc:
            render_failures.append((name, str(exc)))
            continue
        if not text.strip() or "our $CHILD_ERROR" not in text:
            # The deliberate parse-error examples render as a syntax-error
            # stub; that is their expected output, not a measurement failure.
            if text.strip() and "syntax error:" in text and name[:-3] in STUB_ALLOWLIST:
                stubs.append(name)
                continue
            empty_or_stub.append(name)
            continue
        counts, hits = census(text)
        totals.update(counts)
        for cls, line_hint, snippet in hits:
            inventory.append((cls, name, snippet, line_hint))

    if args.keep:
        os.makedirs(args.keep, exist_ok=True)
        for name in files:
            shutil.copy2(os.path.join(render_dir, name), os.path.join(args.keep, name))
    if not args.renders:
        shutil.rmtree(render_dir, ignore_errors=True)

    width = max(len(c) for c in FORBIDDEN + ALLOWED)
    print("perl idiom census — %d renders" % len(files))
    bad = 0
    print("forbidden (must be 0):")
    for cls in FORBIDDEN:
        v = totals[cls]
        bad += v
        print("  %-*s %6d%s" % (width, cls, v, "" if v == 0 else "   <-- FAIL"))
    print("expected non-programs (parse-error corpus): %d" % len(stubs))
    print("allowed (argued idiomatic — PLAN.md):")
    for cls in ALLOWED:
        print("  %-*s %6d" % (width, cls, totals[cls]))

    if args.inventory:
        seen = collections.Counter()
        with open(args.inventory, "w") as fh:
            for cls, name, snippet, _ in inventory:
                seen[(cls, name)] += 1
                fh.write("%s\t%s\t%s\n" % (cls, name, snippet))
        del seen

    if bad:
        print("\n%d non-idiomatic occurrence(s):" % bad)
        for cls, name, snippet, _ in inventory:
            if cls in FORBIDDEN:
                print("  %s\t%s\t%s" % (cls, name, snippet))

    failed = False
    if render_failures:
        failed = True
        print("\n%d render(s) failed:" % len(render_failures))
        for name, dest in render_failures[:20]:
            print("  %s (%s)" % (name, dest))
    if empty_or_stub:
        failed = True
        print("\n%d render(s) produced no emitted preamble:" % len(empty_or_stub))
        for name in empty_or_stub[:20]:
            print("  %s" % name)

    if bad or failed:
        print("\nFAIL")
        return 1
    print("\nOK — every forbidden class is 0")
    return 0


if __name__ == "__main__":
    sys.exit(main())
