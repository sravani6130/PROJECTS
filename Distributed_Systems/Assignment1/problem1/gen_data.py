import random, os
vocab = ["apple", "banana", "cluster", "distributed", "mapreduce", "spark"]
def gen(name, size_mb):
    with open(name, 'w') as f:
        while os.path.getsize(name) < size_mb * 1024 * 1024:
            f.write(f"doc_{random.randint(1,1000)}\t" + " ".join(random.choices(vocab, k=10)) + "\n")

gen("data_1MB.txt", 1)
gen("data_10MB.txt", 10)
gen("data_100MB.txt", 100)
