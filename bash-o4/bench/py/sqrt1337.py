# sqrt1337: i in 1..10000 with "1337" in i*i.
for i in range(1, 10001):
    if "1337" in str(i * i):
        print(i)
