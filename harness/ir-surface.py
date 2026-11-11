#!/usr/bin/env python3
"""harness/ir-surface.py — which IR shapes the example corpus actually reaches.

WHY THIS EXISTS: `fail-rs` compares program behaviour, so an IR shape that no
example produces is invisible to every gate. D4 deleted two whole-program
BigInt rules that the 563-example corpus could not see (0 programs render
`num_bigint`, before and after: bash wraps past i64, so shell-derived IR never
carries a huge value). This turns that blindness into a measurement:

  * a table of every IR `type` tag and every `Call.func` op the corpus emits,
    with both occurrence and program counts;
  * a drift check against `harness/ir-surface.json` — a type or op that
    DISAPPEARS is a coverage regression (fail); a new one is progress
    (record with --update);
  * `--fixtures`: render the synthetic IR under `harness/ir-fixtures/` through
    every backend and compile the result, so the shapes the corpus cannot
    reach still have an end-to-end oracle.

Usage:
  python3 harness/ir-surface.py                table + drift check
  python3 harness/ir-surface.py --json         machine-readable census
  python3 harness/ir-surface.py --update       rewrite harness/ir-surface.json
  python3 harness/ir-surface.py --fixtures     render + compile every fixture
  python3 harness/ir-surface.py <prefix>       only examples starting with it

Exit: 0 clean, 1 drift/fixture failure, 2 no CLI.
"""
import glob
import json
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLI = os.environ.get(
    "OTRANSPILERL_BIN", os.path.join(ROOT, "otranspilerl/target/debug/otranspilerl-cli")
)
EX = os.path.join(ROOT, "sh2perl/examples")
BASE = os.path.join(ROOT, "harness/ir-surface.json")
FIX = os.path.join(ROOT, "harness/ir-fixtures")


def walk(doc):
    """(type_counts, op_counts) over every dict in the document."""
    types, ops = {}, {}

    def rec(x):
        if isinstance(x, dict):
            t = x.get("type")
            if isinstance(t, str):
                types[t] = types.get(t, 0) + 1
                if t == "Call" and isinstance(x.get("func"), str):
                    ops[x["func"]] = ops.get(x["func"], 0) + 1
            for v in x.values():
                rec(v)
        elif isinstance(x, list):
            for v in x:
                rec(v)

    rec(doc)
    return types, ops


def census(prefix=""):
    types, ops, prog_t = {}, {}, {}
    programs, skipped = 0, []
    for f in sorted(glob.glob(os.path.join(EX, prefix + "*.sh"))):
        r = subprocess.run([CLI, "--shir", f], capture_output=True, text=True)
        if not r.stdout.strip():
            skipped.append(os.path.basename(f))
            continue
        try:
            doc = json.loads(r.stdout)
        except json.JSONDecodeError:
            skipped.append(os.path.basename(f))
            continue
        programs += 1
        t, o = walk(doc)
        for k, v in t.items():
            types[k] = types.get(k, 0) + v
            prog_t.setdefault(k, set()).add(os.path.basename(f))
        for k, v in o.items():
            ops[k] = ops.get(k, 0) + v
    return {
        "programs": programs,
        "types": types,
        "ops": ops,
        "programs_with": {k: len(v) for k, v in prog_t.items()},
        "skipped": skipped,
    }


def drift(cur):
    """Types/ops present in the baseline but absent now (coverage loss)."""
    if not os.path.exists(BASE):
        return None
    with open(BASE) as fh:
        base = json.load(fh)
    lost = []
    for key in ("types", "ops"):
        for name in base.get(key, {}):
            if name not in cur[key]:
                lost.append(f"{key[:-1]}:{name}")
    return lost


def fixtures():
    files = sorted(glob.glob(os.path.join(FIX, "*.shir")))
    if not files:
        print(f"ir-surface: no fixtures under {FIX}")
        return 1
    bad = []
    for f in files:
        print(os.path.basename(f))
        for backend in ("rs", "c", "py", "js"):
            r = subprocess.run([CLI, "--target", backend, f], capture_output=True, text=True)
            out = r.stdout
            if not out.strip():
                print(f"  {backend}: EMIT-FAIL {(r.stderr or '').strip()[:120]}")
                bad.append((f, backend, "emit"))
                continue
            # a single-file program cannot link an external crate: these build
            # through the emitted Cargo project (fail-rs), not bare rustc
            if backend == "rs" and any(
                s in out for s in ("num_bigint", "regex::Regex", "revera::")
            ):
                print("  rs: dep (needs the emitted cargo project) — skipped")
                continue
            with tempfile.TemporaryDirectory() as td:
                path = os.path.join(td, "prog." + backend)
                with open(path, "w") as fh:
                    fh.write(out)
                if backend == "rs":
                    cmd = ["rustc", "--crate-name", "prog", "--emit=metadata",
                           "-o", os.path.join(td, "prog.meta"), path]
                elif backend == "c":
                    cmd = ["cc", "-fsyntax-only", "-w", path]
                elif backend == "py":
                    cmd = [sys.executable, "-m", "py_compile", path]
                else:
                    cmd = ["node", "--check", path]
                r2 = subprocess.run(cmd, capture_output=True, text=True)
                if r2.returncode == 0:
                    print(f"  {backend}: compiled")
                else:
                    first = (r2.stderr or r2.stdout).strip().splitlines()
                    print(f"  {backend}: COMPILE-FAIL {first[0] if first else ''}"[:160])
                    bad.append((f, backend, "compile"))
    if bad:
        print(f"\nir-surface --fixtures: {len(bad)} failure(s)")
        return 1
    print("\nir-surface --fixtures: every fixture renders and compiles")
    return 0


def main(argv):
    args = list(argv)
    as_json = "--json" in args
    update = "--update" in args
    args = [a for a in args if not a.startswith("--") or a in ("--json", "--update")]
    if "--fixtures" in argv:
        return fixtures()
    prefix = next((a for a in args if not a.startswith("--")), "")
    if not os.access(CLI, os.X_OK):
        print(f"ir-surface: no CLI at {CLI}", file=sys.stderr)
        return 2
    cur = census(prefix)
    lost = drift(cur)
    if update:
        with open(BASE, "w") as fh:
            json.dump({"types": cur["types"], "ops": cur["ops"]}, fh, indent=1, sort_keys=True)
            fh.write("\n")
        print(f"ir-surface: baseline written ({len(cur['types'])} types, {len(cur['ops'])} ops)")
        return 0
    if as_json:
        print(json.dumps(cur, indent=1, sort_keys=True))
        return 1 if lost else 0
    print(f"ir-surface: {cur['programs']} programs"
          + (f" ({len(cur['skipped'])} without IR)" if cur["skipped"] else ""))
    print("\n  IR node types (occurrences / programs reaching them)")
    for name, n in sorted(cur["types"].items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"    {name:<22} {n:>7} / {cur['programs_with'].get(name, 0)}")
    print(f"\n  Call.func ops ({len(cur['ops'])})")
    print("    " + ", ".join(f"{k}({v})" for k, v in sorted(cur["ops"].items())))
    if lost is None:
        print("\nir-surface: no baseline yet — record this surface with --update")
        return 0
    if lost:
        print("\nir-surface: COVERAGE REGRESSION — the corpus no longer reaches:")
        for n in lost:
            print(f"    {n}")
        return 1
    print("\nir-surface: no coverage regression")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
