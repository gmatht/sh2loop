# hash: per-record integer mix, accumulator kept mod 256.
N = 1000000
s = 0
for i in range(N):
    a = (i * 53) % 256
    b = (i * 89) % 256
    s = (s + a * 31 + b * 17) % 256
print(s)
