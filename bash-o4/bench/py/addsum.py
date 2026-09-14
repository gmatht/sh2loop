# addsum: scalar accumulation (native i64). The addsum32 problem reuses
# this exact program with a smaller N (int32-exact sum).
N = 1000000
s = 0
for i in range(N):
    s = s + i
print(s)
