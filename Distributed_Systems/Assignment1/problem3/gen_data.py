import random

n = 10000  # 10k nodes
m = 200000 # 200k edges

with open("large.txt", "w") as f:
    f.write(f"{n} {m}\n")
    for _ in range(m):
        u = random.randint(0, n-1)
        v = random.randint(0, n-1)
        w = random.randint(1, 100)
        if u != v:
            f.write(f"{u} {v} {w}\n")
