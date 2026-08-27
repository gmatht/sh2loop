#!/usr/bin/env python3
"""Coverage check: every sh2perl builtin has an implementation in either
the bash polyfills (polyfills.sh) or the C polyfills (polyfills.c).

Reads the authoritative builtin list (sh2perl/data/sh2-builtins.json,
the A4 sync_builtins) and the two polyfill sources. Reports any builtin
with no implementation in either, and exits nonzero on a gap.

Usage: python3 check-coverage.py [sh2perl-data-dir]
"""
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DATA = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE.parent / "sh2perl" / "data"

# bash polyfill function name → builtin name (the pure-CPU cores use
# builtin-named functions; the line cores use wcLines/headLines/tailLines)
BASH_ALIASES = {
    "wcLines": "wc",
    "headLines": "head",
    "tailLines": "tail",
}

# C polyfill function name → builtin name (dot/colon can't be C
# identifiers)
C_ALIASES = {
    "sh2poly_dot": ".",
    "sh2poly_colon": ":",
}

def bash_polyfill_names(src: str) -> set:
    names = set(re.findall(r"^([A-Za-z_][A-Za-z0-9_]*)\s*\(\)\s*\{", src, re.M))
    return {BASH_ALIASES.get(n, n) for n in names}

def c_polyfill_names(src: str) -> set:
    names = set(re.findall(r"int\s+sh2poly_([A-Za-z_][A-Za-z0-9_]*)\s*\(", src))
    # the DELEGATE(name, tool) macro generates sh2poly_<name> for the
    # IO-bound builtins
    names |= set(re.findall(r"DELEGATE\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*,", src))
    return {C_ALIASES.get(f"sh2poly_{n}", n) for n in names}

def main() -> int:
    builtins = json.loads((DATA / "sh2-builtins.json").read_text())["sync_builtins"]
    bash_src = (HERE / "polyfills.sh").read_text()
    c_src = (HERE / "polyfills.c").read_text()
    bash_names = bash_polyfill_names(bash_src)
    c_names = c_polyfill_names(c_src)

    bash_covered = {b for b in builtins if b in bash_names}
    c_covered = {b for b in builtins if b in c_names}
    gaps = [b for b in builtins if b not in bash_covered and b not in c_covered]

    print(f"builtins: {len(builtins)}")
    print(f"bash polyfills cover: {len(bash_covered)}  -> {sorted(bash_covered)}")
    print(f"C polyfills cover:    {len(c_covered)}  -> {sorted(c_covered)}")
    print(f"gaps: {len(gaps)}  -> {gaps}")
    return 1 if gaps else 0

if __name__ == "__main__":
    sys.exit(main())
