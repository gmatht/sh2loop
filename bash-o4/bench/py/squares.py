# squares: sum of squares (i64 multiply-accumulate).
N = 1000000
s = 0
for i in range(N):
    s = s + i * i
print(s)
