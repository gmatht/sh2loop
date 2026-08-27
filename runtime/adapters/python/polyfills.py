#!/usr/bin/env python3
"""polyfills.py — the Python backend's thin adapter for the C polyfills.

Loads libsh2poly.so (the C polyfill library) via ctypes and exposes the
sh2.* call-site convention as Python functions. This is the "any backend
with libc bindings" story: the C polyfills are written once, and a
backend that can call C gets the whole IO seam for free.

Usage (library):
    from polyfills import sh2
    sh2.echo("hello", "world")          # -> 0, prints "hello world"
    sh2.cat("/tmp/x")                   # -> 0, prints the file
    sh2.seq("1", "5")                   # -> 0, prints 1..5

Usage (CLI):
    python3 polyfills.py echo hello world   # one call
    python3 polyfills.py --battery          # run adapters/battery.txt
        (TAB-separated fields, `\\` -> backslash, `\\n` -> newline;
        prints the C self-test format `== name` / `status=N`)

The polyfill functions use the bash function convention (positional args
in, stdout out, exit status returned) — the same contract as the
transpiled bash polyfills (runtime/README.md §3).
"""
import ctypes
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_LIB = os.path.join(_HERE, "..", "..", "libsh2poly.so")

_lib = ctypes.CDLL(_LIB)
_lib.sh2poly_init.restype = None
_lib.sh2poly_dispatch.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_char_p)]
_lib.sh2poly_dispatch.restype = ctypes.c_int


def _dispatch(name, args):
    argv = [name.encode()] + [str(a).encode() for a in args]
    arr = (ctypes.c_char_p * (len(argv) + 1))()
    for i, a in enumerate(argv):
        arr[i] = a
    arr[len(argv)] = None
    return _lib.sh2poly_dispatch(len(argv), arr)


class _Sh2:
    """sh2.* namespace over the C polyfills (the runtime call-site
    convention: JS values in, exit status out)."""

    def __getattr__(self, name):
        def call(*args):
            return _dispatch(name, args)
        return call


sh2 = _Sh2()


def _unescape(field):
    out = []
    i = 0
    while i < len(field):
        if field[i] == "\\" and i + 1 < len(field):
            n = field[i + 1]
            if n == "\\":
                out.append("\\")
                i += 2
            elif n == "n":
                out.append("\n")
                i += 2
            elif n == "t":
                out.append("\t")
                i += 2
            else:
                out.append("\\")
                i += 1
        else:
            out.append(field[i])
            i += 1
    return "".join(out)


def _run_battery():
    _lib.sh2poly_init()
    with open("/tmp/sh2poly_selftest_in.txt", "w") as f:
        f.write("alpha beta gamma\none\ntwo\nthree\n")
    # redirect stdin from the input file (read/readarray consume it)
    fd = os.open("/tmp/sh2poly_selftest_in.txt", os.O_RDONLY)
    os.dup2(fd, 0)
    os.close(fd)
    path = os.path.join(_HERE, "battery.txt")
    if not os.path.exists(path):
        path = os.path.join(_HERE, "..", "battery.txt")
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            name = fields[0]
            args = [_unescape(x) for x in fields[1:]]
            print("== %s" % name, flush=True)
            st = _dispatch(name, args)
            print("status=%d" % st, flush=True)


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "--battery":
        sys.exit(_run_battery())
    if len(sys.argv) < 2:
        print(f"usage: {sys.argv[0]} <builtin> [args...] | {sys.argv[0]} --battery", file=sys.stderr)
        sys.exit(2)
    sys.exit(_dispatch(sys.argv[1], sys.argv[2:]))
