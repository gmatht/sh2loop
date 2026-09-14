# collatz: branchy Collatz step counts.
N = 18000000
total = 0
for k in range(N):
    v = (k * 37 + 3) % 251
    s = 0
    while v > 1:
        if v % 2 == 0:
            v = v // 2
        else:
            v = 3 * v + 1
        s = s + 1
    total = total + s
print(total)
