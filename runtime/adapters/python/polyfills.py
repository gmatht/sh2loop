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

Usage (CLI, mirrors adapters/c/polyfill-cli.c):
    python3 polyfills.py echo hello world
    python3 polyfills.py seq 1 5

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

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"usage: {sys.argv[0]} <builtin> [args...]", file=sys.stderr)
        sys.exit(2)
    sys.exit(_dispatch(sys.argv[1], sys.argv[2:]))
