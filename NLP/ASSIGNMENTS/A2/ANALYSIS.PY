# =========================
# IMPORTS
# =========================
import torch
import numpy as np
import os
from numpy.linalg import norm
from gensim.models import KeyedVectors

# =========================
# COSINE SIMILARITY
# =========================
def cosine_similarity(a, b):
    return np.dot(a, b) / (norm(a) * norm(b) + 1e-8)


# =========================
# LOAD EMBEDDINGS (.pt)
# =========================
def load_pt_embeddings(path):
    print(f"\n[INFO] Loading embeddings from {path}")

    data = torch.load(path)
    print("[DEBUG] Keys:", data.keys())

    embeddings = data['embeddings'].numpy()
    vocab = data['vocab']

    id2word = {i:w for w,i in vocab.items()}

    print("[INFO] Shape:", embeddings.shape)

    return embeddings, vocab, id2word


# =========================
# TOP-K SIMILAR WORDS
# =========================
def get_top_k(vec, embeddings, id2word, k=5):
    sims = embeddings @ vec
    top_ids = np.argsort(-sims)[1:k+1]
    return [id2word[i] for i in top_ids]


# =========================
# ANALOGY (SVD / CBOW)
# =========================
def analogy(a, b, c, embeddings, vocab, id2word):
    if a not in vocab or b not in vocab or c not in vocab:
        return ["(word missing in vocab)"]

    vec = embeddings[vocab[b]] - embeddings[vocab[a]] + embeddings[vocab[c]]
    return get_top_k(vec, embeddings, id2word)


# =========================
# ANALOGY (GLOVE)
# =========================
def glove_analogy(model, a, b, c):
    try:
        return [w for w, _ in model.most_similar(
            positive=[b, c],
            negative=[a],
            topn=5
        )]
    except:
        return ["(error)"]


# =========================
# BIAS FUNCTION
# =========================
def bias_score(model, w1, w2):
    return model.similarity(w1, w2)


# =========================
# MAIN
# =========================
def main():
    print("\n========== PART 2 ANALYSIS ==========\n")

    # -------------------------
    # CHECK FILES
    # -------------------------
    print("[INFO] Files in /kaggle/working:")
    print(os.listdir("/kaggle/working"))

    # -------------------------
    # LOAD YOUR EMBEDDINGS
    # -------------------------
    svd_emb, svd_vocab, svd_id2word = load_pt_embeddings("/kaggle/working/svd.pt")
    cbow_emb, cbow_vocab, cbow_id2word = load_pt_embeddings("/kaggle/working/cbow.pt")

    # -------------------------
    # LOAD GLOVE
    # -------------------------
    print("\n[INFO] Loading GloVe...")

    glove = KeyedVectors.load_word2vec_format(
        "/kaggle/working/glove.6B.100d.txt",
        binary=False,
        no_header=True
    )

    print("[INFO] GloVe loaded\n")

    # =========================
    # ANALOGY TASK
    # =========================
    print("\n========== ANALOGY TASK ==========\n")

    analogies = [
        ("paris", "france", "delhi"),
        ("king", "man", "queen"),
        ("swim", "swimming", "run")
    ]

    for a, b, c in analogies:
        print(f"\n--- {a} : {b} :: {c} : ? ---\n")

        print("SVD  :", analogy(a, b, c, svd_emb, svd_vocab, svd_id2word))
        print("CBOW :", analogy(a, b, c, cbow_emb, cbow_vocab, cbow_id2word))
        print("GloVe:", glove_analogy(glove, a, b, c))

    # =========================
    # BIAS ANALYSIS (GLOVE ONLY)
    # =========================
    print("\n========== BIAS ANALYSIS ==========\n")

    pairs = [
        ("doctor", "man", "woman"),
        ("nurse", "man", "woman"),
        ("homemaker", "man", "woman")
    ]

    for word, g1, g2 in pairs:
        try:
            sim1 = bias_score(glove, word, g1)
            sim2 = bias_score(glove, word, g2)

            print(f"\n{word.upper()}:")
            print(f"cos({word}, {g1})   = {sim1:.4f}")
            print(f"cos({word}, {g2}) = {sim2:.4f}")

        except:
            print(f"{word} not found in GloVe")

    print("\n========== DONE ==========\n")


# =========================
# RUN
# =========================
if __name__ == "__main__":
    main()