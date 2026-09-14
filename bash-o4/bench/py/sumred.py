# sumred: mod-2^32 accumulate of i*i (overflow-exact on every side).
N = 1000000000
s = 0
for i in range(N):
    s = (s + (i * i) % 4294967296) % 4294967296
print(s)
