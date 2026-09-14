# squares-map: materialise a[i]=i*i, then a mod-2^32 checksum (the fair
# CPU counterpart to a GPU map+readback: same memory traffic). Matches
# bench/c/squaresmap.c exactly (unsigned wrap per element, u32 sum).
#
# `append` is the CPython-valid way to build a growing list (lists do not
# auto-grow). python-O4 rewrites a counted loop's single append into the
# affine indexed store `a[i] = v` for the CUDA candidacy view, so this
# SAME source drives every leg (see docs/PYTHON-O4.md).
N = 100000000
a = []
for i in range(N):
    a.append(i * i)
s = 0
for i in range(N):
    s = (s + a[i]) % 4294967296
print(s)
