# =========================
# IMPORTS
# =========================
import torch
import torch.nn as nn
import torch.optim as optim
import random
import re
from collections import Counter
from nltk.corpus import brown
from tqdm import tqdm
import nltk

# =========================
# HYPERPARAMETERS
# =========================
EMBEDDING_DIM = 100
WINDOW_SIZE = 2
VOCAB_SIZE = 10000
NUM_NEGATIVES = 5
EPOCHS = 50
BATCH_SIZE = 256
LR = 0.003
PATIENCE = 5
MIN_DELTA = 1e-4


# =========================
# DATA FUNCTIONS
# =========================

def load_corpus():
    return brown.sents()

def preprocess(sentences):
    processed = []
    for sent in sentences:
        cleaned = []
        for w in sent:
            w = w.lower()
            if re.match(r"^[a-z]+$", w):
                cleaned.append(w)
        if cleaned:
            processed.append(cleaned)
    return processed

def build_vocab(sentences, vocab_size):
    counter = Counter()
    for sent in sentences:
        counter.update(sent)

    most_common = counter.most_common(vocab_size)
    vocab = {w:i for i,(w,_) in enumerate(most_common)}
    id2word = {i:w for w,i in vocab.items()}

    return vocab, id2word


# =========================
# CREATE CBOW DATA
# =========================

def create_cbow_data(sentences, vocab, window_size):
    data = []

    for sent in sentences:
        for i, word in enumerate(sent):
            if word not in vocab:
                continue

            context = []

            for j in range(i - window_size, i + window_size + 1):
                if j != i and 0 <= j < len(sent):
                    if sent[j] in vocab:
                        context.append(vocab[sent[j]])

            if len(context) > 0:
                data.append((context, vocab[word]))

    return data


# =========================
# MODEL
# =========================

class CBOW(nn.Module):
    def __init__(self, vocab_size, embedding_dim):
        super().__init__()
        self.embeddings = nn.Embedding(vocab_size, embedding_dim)

    def forward(self, context_idxs):
        embeds = self.embeddings(context_idxs)   # (batch, context, dim)
        context_vec = embeds.mean(dim=1)         # (batch, dim)
        return context_vec


# =========================
# NEGATIVE SAMPLING LOSS (BATCH)
# =========================

def negative_sampling_loss(model, context_batch, target_batch, vocab_size, k):

    context_vec = model(context_batch)  # (batch, dim)

    target_embed = model.embeddings(target_batch)  # (batch, dim)

    # positive score
    pos_score = torch.sum(context_vec * target_embed, dim=1)
    pos_loss = torch.log(torch.sigmoid(pos_score) + 1e-8)

    # negative samples
    neg_words = torch.randint(0, vocab_size, (context_batch.size(0), k))
    neg_embed = model.embeddings(neg_words)  # (batch, k, dim)

    neg_score = torch.bmm(neg_embed, context_vec.unsqueeze(2)).squeeze()
    neg_loss = torch.sum(torch.log(torch.sigmoid(-neg_score) + 1e-8), dim=1)

    loss = -(pos_loss + neg_loss).mean()

    return loss


# =========================
# BATCHING FUNCTION
# =========================

def create_batches(data, batch_size):
    random.shuffle(data)

    for i in range(0, len(data), batch_size):
        batch = data[i:i+batch_size]

        contexts = []
        targets = []

        for context, target in batch:
            contexts.append(context)
            targets.append(target)

        # pad contexts
        max_len = max(len(c) for c in contexts)

        padded = []
        for c in contexts:
            padded.append(c + [0]*(max_len - len(c)))

        yield torch.tensor(padded), torch.tensor(targets)


# =========================
# MAIN
# =========================

def main():
    print("\n========== CBOW WORD2VEC ==========\n")

    nltk.download('brown')

    # Load + preprocess
    sentences = preprocess(load_corpus())
    print("[STEP 1] Sample:", sentences[:2])

    # Vocab
    vocab, id2word = build_vocab(sentences, VOCAB_SIZE)
    print("\n[STEP 2] Vocab size:", len(vocab))

    # Dataset
    data = create_cbow_data(sentences[:10000], vocab, WINDOW_SIZE)
    print("\n[STEP 3] Training samples:", len(data))

    # Model
    model = CBOW(len(vocab), EMBEDDING_DIM)
    optimizer = optim.Adam(model.parameters(), lr=LR)

    best_loss = float('inf')
    patience_counter = 0

    print("\n[STEP 4] Training...\n")

    for epoch in range(EPOCHS):
        total_loss = 0
        batches = create_batches(data, BATCH_SIZE)

        for context_batch, target_batch in tqdm(batches, desc=f"Epoch {epoch+1}"):

            loss = negative_sampling_loss(
                model,
                context_batch,
                target_batch,
                len(vocab),
                NUM_NEGATIVES
            )

            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            total_loss += loss.item()

        print(f"Epoch {epoch+1} Loss: {total_loss:.4f}")

        # =========================
        # EARLY STOPPING
        # =========================
        if best_loss - total_loss > MIN_DELTA:
            best_loss = total_loss
            patience_counter = 0
        else:
            patience_counter += 1

        if patience_counter >= PATIENCE:
            print("\n[INFO] Early stopping triggered")
            break

    # Save
    torch.save({
        "embeddings": model.embeddings.weight.data,
        "vocab": vocab
    }, "/kaggle/working/cbow.pt")

    print("\n[STEP 5] Saved embeddings")
    print("\n========== DONE ==========\n")


# =========================
# RUN
# =========================

if __name__ == "__main__":
    main()