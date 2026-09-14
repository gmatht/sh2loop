#!/usr/bin/env python3
"""bench-py.py — python-O4 vs CPython vs pure C (gcc -O3).

The Python counterpart of bench.sh/bench-opt.sh: same problems, same
agreement gate (every running leg's stdout/checksum must match), same
median-over-runs timing — but every leg is now a *Python* program fed to
`python-O4`:

    bench/py/<name>.py  --(py-sh-go)-->  A1 shIR  --(python-O4)--> C / PTX

Legs per problem (fixed N; byte-exact stdout must agree across all that
run):

    cpython    real CPython (floor reference)
    pyo4-tcc   python-O4 -o (C via tcc, the default driver path)
    pyo4-gcc   the same rendered C via gcc -O3 (backend quality)
    gcc-O3     handwritten C from bench/c/ (CPU ceiling)
    pyo4-gpu   python-O4 --gpu (TRANSPILED Python->ShIR->PTX dispatch)

`--scale fast` uses small N (all legs, CPython included). `--scale opt`
uses the bench-opt N calibrated so the slower CPU leg lands ~1s and
drops the CPython leg (too slow by design, exactly like bench-opt.sh).

Usage: bench/bench-py.py [--scale fast|opt] [--runs K] [--problem NAME]...
Env: PYTHON_O4 (driver path), CC, TIMEOUT.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

BENCH = Path(__file__).resolve().parent
ROOT = BENCH.parent.parent                      # <workspace>/bash-o4/bench -> workspace
PY4 = Path(os.environ.get("PYTHON_O4", ROOT / "bash-o4/target/debug/python-O4"))
PY_SRC = BENCH / "py"
C_SRC = BENCH / "c"
CC = os.environ.get("CC", "cc")
TIMEOUT = int(os.environ.get("TIMEOUT", "900"))
RUNS = int(os.environ.get("RUNS", "3"))


@dataclass
class Problem:
    name: str
    py: str
    cref: str | None
    n_fast: int | None
    n_opt: int | None
    gpu: bool
    c_arg: bool = True
    # Frontend/transpiler unsupported (the driver reports SKIP, not FAIL).
    unsupported: str | None = None


PROBLEMS = {
    "addsum":      Problem("addsum", "addsum.py", "addsum.c", 1_000_000, 1_000_000, True),
    "addsum32":    Problem("addsum32", "addsum.py", "addsum32.c", 46_340, 46_340, True),
    "squares":     Problem("squares", "squares.py", "squares.c", 1_000_000, 1_000_000, True),
    "hash":        Problem("hash", "hash.py", "hash.c", 1_000_000, 1_000_000, False),
    "collatz":     Problem("collatz", "collatz.py", "collatz.c", 500, 18_000_000, True),
    "sumred":      Problem("sumred", "sumred.py", "sumred.c", 1_000_000, 1_000_000_000, True),
    "squares-map": Problem("squares-map", "squares-map.py", "squaresmap.c",
                           10_000, 100_000_000, True),
    "sqrt1337":    Problem("sqrt1337", "sqrt1337.py", "sqrt1337.c", None, None, False,
                           c_arg=False,
                           unsupported="py-sh-go v1 has no string containment "
                                       "(`\"1337\" in str(x)` / `.find`); the valid "
                                       "Python translation is kept as documentation"),
}


def render_py(problem: Problem, n: int | None, out: Path) -> None:
    src = (PY_SRC / problem.py).read_text()
    if n is not None:
        src = re.sub(r"(?m)^N = .*$", f"N = {n}", src, count=1)
    out.write_text(src)


def gpu_measure(problem: Problem, src: Path, n: int, runs: int) -> tuple[float, str] | None:
    """Run the transpiled-CUDA leg; None = SKIP (no device / no shape)."""
    p = subprocess.run(
        [str(PY4), "--gpu=force", "--n", str(n), "--runs", str(runs), str(src)],
        capture_output=True, text=True, timeout=TIMEOUT,
    )
    if p.returncode == 3:
        return None
    if p.returncode != 0:
        raise RuntimeError(f"gpu rc={p.returncode}: {p.stderr.strip()[:200]}")
    ms_s, checksum = p.stdout.split()
    return float(ms_s), checksum


def time_leg(cmd, runs: int) -> float:
    subprocess.run(cmd, capture_output=True, timeout=TIMEOUT)  # warmup
    ts = []
    for _ in range(runs):
        t0 = time.perf_counter()
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT)
        ts.append((time.perf_counter() - t0) * 1000.0)
        if p.returncode != 0:
            raise RuntimeError(f"rc={p.returncode}: {p.stderr.strip()[:160]}")
    return statistics.median(ts)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scale", choices=["fast", "opt"], default="fast")
    ap.add_argument("--runs", type=int, default=RUNS)
    ap.add_argument("--problem", action="append", default=[])
    ap.add_argument("--save", default=None)
    args = ap.parse_args()

    if not PY4.is_file():
        print(f"bench-py: missing {PY4} (cd bash-o4 && cargo build --bin python-O4)", file=sys.stderr)
        return 1
    names = args.problem or [k for k in PROBLEMS if PROBLEMS[k].unsupported is None]
    tmp = Path(tempfile.mkdtemp(prefix="bench-py-"))

    print(f"python-O4: {PY4}")
    print(f"cc: {shutil.which(CC)}   scale: {args.scale}   runs: {args.runs}\n")
    hdr = f"{'problem':<13}{'N':>12} {'leg':<9}{'ms':>12} {'speedup':>9}  checksum"
    print(hdr)
    print("-" * len(hdr))

    rows = []
    for name in names:
        problem = PROBLEMS[name]
        if problem.unsupported:
            print(f"{name:<13} {'':>12} {'SKIP':<9} {problem.unsupported}\n")
            continue
        n = problem.n_fast if args.scale == "fast" else problem.n_opt

        src_lit = tmp / f"{problem.name}.py"
        render_py(problem, n, src_lit)
        src_gpu = src_lit

        # ---- build ----
        cmds: dict[str, list | None] = {}
        try:
            bin_tcc = tmp / f"{problem.name}.tcc"
            out = subprocess.run([str(PY4), "-o", str(bin_tcc), str(src_lit)],
                                 capture_output=True, text=True, timeout=TIMEOUT)
            cmds["pyo4-tcc"] = [str(bin_tcc)] if out.returncode == 0 else None
            if out.returncode != 0:
                print(f"{name:<13} {n!s:>12} pyo4-tcc BUILD SKIP: {out.stderr.strip()[:120]}")
        except Exception as e:
            cmds["pyo4-tcc"] = None
            print(f"{name:<13} {n!s:>12} pyo4-tcc BUILD SKIP: {e}")

        try:
            ctext = subprocess.run([str(PY4), "--emit-c", str(src_lit)],
                                   capture_output=True, text=True, timeout=TIMEOUT)
            if ctext.returncode != 0:
                raise RuntimeError(ctext.stderr.strip()[:160])
            cfile = tmp / f"{problem.name}.pygcc.c"
            cfile.write_text(ctext.stdout)
            cc = subprocess.run([CC, "-O3", str(cfile), "-o", str(tmp / f"{problem.name}.pygcc"),
                                 "-lm", "-lgmp"], capture_output=True, text=True, timeout=TIMEOUT)
            cmds["pyo4-gcc"] = [str(tmp / f"{problem.name}.pygcc")] if cc.returncode == 0 else None
            if cc.returncode != 0:
                print(f"{name:<13} {n!s:>12} pyo4-gcc BUILD SKIP: {cc.stderr.strip()[:120]}")
        except Exception as e:
            cmds["pyo4-gcc"] = None
            print(f"{name:<13} {n!s:>12} pyo4-gcc BUILD SKIP: {e}")

        if problem.cref:
            ref = tmp / f"{problem.name}.ref"
            cc = subprocess.run([CC, "-O3", str(C_SRC / problem.cref), "-o", str(ref)],
                                capture_output=True, text=True, timeout=TIMEOUT)
            cmds["gcc-O3"] = ([str(ref)] + ([str(n)] if problem.c_arg and n is not None else [])
                              if cc.returncode == 0 else None)
        else:
            cmds["gcc-O3"] = None

        # ---- agreement gate: run each leg once, collect stdout ----
        outs: dict[str, str | None] = {}
        for leg in ("cpython", "pyo4-tcc", "pyo4-gcc", "gcc-O3"):
            if leg == "cpython" and args.scale == "fast" and n is not None:
                cmd = [sys.executable, str(src_lit)]
            elif leg == "cpython":
                cmd = None
            else:
                cmd = cmds.get(leg)
            if cmd is None:
                continue
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT)
            outs[leg] = p.stdout.strip() if p.returncode == 0 else None
            if p.returncode != 0:
                print(f"{name:<13} {n!s:>12} {leg:<9} RUN SKIP: {p.stderr.strip()[:120]}")

        running = [k for k, v in outs.items() if v is not None]
        ref = outs[running[0]] if running else None
        if running and not all(outs[k] == ref for k in running):
            print(f"{name:<13} AGREEMENT FAIL: " + " ".join(f"{k}={outs[k]}" for k in running))
            continue

        gpu = None
        if problem.gpu and ref is not None:
            try:
                gpu = gpu_measure(problem, src_gpu, n, args.runs)
            except Exception as e:
                print(f"{name:<13} {n!s:>12} pyo4-gpu SKIP: {e}")
            if gpu is not None and gpu[1] != ref:
                print(f"{name:<13} GPU CHECKSUM MISMATCH: gpu={gpu[1]} cpu={ref}")
                continue

        # ---- time ----
        base_gcc = base_py = None
        for leg in ("cpython", "gcc-O3", "pyo4-tcc", "pyo4-gcc"):
            if leg == "cpython":
                if args.scale != "fast" or n is None:
                    continue
                cmd = [sys.executable, str(src_lit)]
            else:
                cmd = cmds.get(leg)
            if cmd is None:
                continue
            try:
                ms = time_leg(cmd, args.runs)
            except Exception as e:
                print(f"{name:<13} {n!s:>12} {leg:<9} {'SKIP':>12} ({e})")
                continue
            if leg == "cpython":
                base_py = ms
            if leg == "gcc-O3":
                base_gcc = ms
            if leg == "cpython":
                sp = "1.0x"
            elif base_gcc:
                sp = f"{base_gcc / ms:.2f}x" if ms else "-"
            elif base_py:
                sp = f"{base_py / ms:.1f}x"
            else:
                sp = "-"
            rows.append((name, n, leg, ms, ref or ""))
            print(f"{name:<13}{n!s:>12} {leg:<9}{ms:>12.2f} {sp:>9}  {ref}")

        if gpu is not None:
            ms, chk = gpu
            sp = f"{base_gcc / ms:.0f}x" if base_gcc else "-"
            rows.append((name, n, "pyo4-gpu", ms, chk))
            print(f"{name:<13}{n!s:>12} {'pyo4-gpu':<9}{ms:>12.3f} {sp:>9}  {chk}  (vs gcc-O3)")
        elif problem.gpu:
            print(f"{name:<13}{n!s:>12} {'pyo4-gpu':<9}{'SKIP':>12} {'-':>9}")
        print()

    if args.save:
        with open(args.save, "w") as f:
            f.write("problem\tN\tleg\tms\tchecksum\n")
            for r in rows:
                f.write("\t".join(str(x) for x in r) + "\n")
        print(f"wrote {args.save}")
    shutil.rmtree(tmp, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
