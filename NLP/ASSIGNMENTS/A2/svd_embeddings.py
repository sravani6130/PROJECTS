# =========================
# IMPORTS
# =========================
import numpy as np
import torch
import re
from collections import Counter
from nltk.corpus import brown
from scipy.sparse import lil_matrix
from scipy.sparse.linalg import svds
from tqdm import tqdm
import nltk

# =========================
# HYPERPARAMETERS
# =========================
WINDOW_SIZE = 2
EMBEDDING_DIM = 300   # final recommended: 100–200
VOCAB_SIZE = 20000    # top-K words


# =========================
# FUNCTIONS
# =========================

def load_corpus():
    sentences = brown.sents()
    return sentences


def preprocess(sentences):
    processed = []

    for sent in sentences:
        cleaned_sent = []

        for word in sent:
            word = word.lower()

            # keep only alphabetic words
            if re.match(r"^[a-z]+$", word):
                cleaned_sent.append(word)

        if len(cleaned_sent) > 0:
            processed.append(cleaned_sent)

    return processed


def build_vocab(sentences, vocab_size=None):
    word_freq = Counter()

    for sent in sentences:
        word_freq.update(sent)

    if vocab_size is None:
        most_common = word_freq.most_common()
    else:
        most_common = word_freq.most_common(vocab_size)

    vocab = {word: i for i, (word, _) in enumerate(most_common)}
    id2word = {i: word for word, i in vocab.items()}

    return vocab, id2word


def build_cooccurrence_matrix(sentences, vocab, window_size):
    vocab_size = len(vocab)
    cooc_matrix = lil_matrix((vocab_size, vocab_size))

    for sent in tqdm(sentences[:2000], desc="Building Co-occurrence Matrix"):
        for i, word in enumerate(sent):
            if word not in vocab:
                continue

            word_id = vocab[word]

            start = max(0, i - window_size)
            end = min(len(sent), i + window_size + 1)

            for j in range(start, end):
                if i == j:
                    continue

                context_word = sent[j]
                if context_word not in vocab:
                    continue

                context_id = vocab[context_word]
                cooc_matrix[word_id, context_id] += 1

    return cooc_matrix.tocsr()


def compute_ppmi(cooc_matrix):
    print("\n[INFO] Computing PPMI...")

    total_sum = cooc_matrix.sum()
    word_sum = np.array(cooc_matrix.sum(axis=1)).flatten()
    context_sum = np.array(cooc_matrix.sum(axis=0)).flatten()

    ppmi_matrix = cooc_matrix.copy().astype(float)

    rows, cols = ppmi_matrix.nonzero()

    for i, j in zip(rows[:10000], cols[:10000]):  # limited for speed
        p_ij = ppmi_matrix[i, j] / total_sum
        p_i = word_sum[i] / total_sum
        p_j = context_sum[j] / total_sum

        pmi = np.log2(p_ij / (p_i * p_j + 1e-8))
        ppmi_matrix[i, j] = max(pmi, 0)

    return ppmi_matrix


def compute_svd(ppmi_matrix, embedding_dim):
    print("\n[INFO] Performing SVD...")

    U, S, Vt = svds(ppmi_matrix, k=embedding_dim)

    # sort descending
    U = U[:, ::-1]
    S = S[::-1]

    embeddings = U * np.sqrt(S)

    return embeddings


def save_embeddings(embeddings, vocab, path):
    torch.save({
        'embeddings': torch.tensor(embeddings, dtype=torch.float),
        'vocab': vocab
    }, path)


# =========================
# MAIN FUNCTION
# =========================

def main():
    print("\n========== SVD WORD EMBEDDINGS PIPELINE ==========\n")

    # Step 1: Download data
    nltk.download('brown')

    # Step 2: Load corpus
    sentences = load_corpus()
    print("\n[STEP 1] Loaded corpus")
    print("Sample raw sentences:", sentences[:2])

    # Step 3: Preprocess
    sentences = preprocess(sentences)
    print("\n[STEP 2] After preprocessing")
    print("Sample processed sentences:", sentences[:2])
    print("Total sentences:", len(sentences))

    # Step 4: Build vocab
    vocab, id2word = build_vocab(sentences, VOCAB_SIZE)
    print("\n[STEP 3] Vocabulary built")
    print("Vocab size:", len(vocab))
    print("Sample vocab:", list(vocab.items())[:10])

    # Step 5: Co-occurrence matrix
    cooc_matrix = build_cooccurrence_matrix(sentences, vocab, WINDOW_SIZE)
    print("\n[STEP 4] Co-occurrence matrix created")
    print("Matrix shape:", cooc_matrix.shape)
    print("Non-zero entries:", cooc_matrix.nnz)

    # Step 6: PPMI
    ppmi_matrix = compute_ppmi(cooc_matrix)
    print("\n[STEP 5] PPMI computed")

    rows, cols = ppmi_matrix.nonzero()
    print("Sample PPMI values:")
    for i in range(min(5, len(rows))):
        print(f"PPMI[{rows[i]}, {cols[i]}] =", ppmi_matrix[rows[i], cols[i]])

    # Step 7: SVD
    embeddings = compute_svd(ppmi_matrix, EMBEDDING_DIM)
    print("\n[STEP 6] SVD completed")
    print("Embeddings shape:", embeddings.shape)
    print("Sample embedding vector:", embeddings[0][:10])

    # Step 8: Save
    save_embeddings(embeddings, vocab, "/kaggle/working/svd.pt")
    print("\n[STEP 7] Embeddings saved at /kaggle/working/svd.pt")

    print("\n========== DONE ==========\n")


# =========================
# RUN
# =========================

if __name__ == "__main__":
    main()