"""Kaggle Hangman submission script; paste its sections into a notebook if needed."""
import random
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset

SEED = 2026
random.seed(SEED); np.random.seed(SEED); torch.manual_seed(SEED)
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")
ALPHABET = "abcdefghijklmnopqrstuvwxyz"
LID = {c: i for i, c in enumerate(ALPHABET)}
PAD, MASK, OTHER = 0, 1, 28

def locate(name):
    direct = Path("/kaggle/input/competitions/brand-buzzword-hackathon") / name
    hits = [direct] if direct.exists() else list(Path("/kaggle/input").rglob(name))
    if not hits:
        raise FileNotFoundError(f"Cannot find {name}; edit locate() with your dataset path")
    return hits[0]

def read_words(path):
    with open(path, encoding="utf-8") as handle:
        return [line.rstrip("\n").lower() for line in handle if line.strip()]

train_words, test_words = read_words(locate("train.txt")), read_words(locate("test.txt"))
# This file is a schema/shape contract only; its guesses are never read or used.
sample_submission = pd.read_csv(locate("sample_submission.csv"))
REQUIRED_COLUMNS = ["word_id", "guessed_letters_string"]
assert list(sample_submission.columns) == REQUIRED_COLUMNS, "Unexpected sample_submission.csv schema"
assert len(test_words) == len(sample_submission), "test.txt and sample submission row counts differ"
MAX_LEN = min(64, max(map(len, train_words + test_words)))
freq = Counter(c for w in train_words for c in w if c in LID)
prior = np.array([freq[c] for c in ALPHABET], dtype=np.float32); prior /= prior.sum()

class MaskedBoards(Dataset):
    """Random board states teach the model the actual next-letter task."""
    def __init__(self, words, copies=4):
        self.words = [w for w in words if any(c in LID for c in w)]
        self.n = len(self.words) * copies
    def __len__(self): return self.n
    def __getitem__(self, idx):
        word = self.words[idx % len(self.words)]
        letters = sorted(set(c for c in word if c in LID))
        revealed = {c for c in letters if random.random() < random.uniform(.05, .8)}
        if len(revealed) == len(letters): revealed.remove(random.choice(letters))
        absent = [c for c in ALPHABET if c not in letters]
        wrong = set(random.sample(absent, random.randrange(min(6, len(absent)) + 1)))
        board = np.zeros(MAX_LEN, dtype=np.int64)
        for i, c in enumerate(word[:MAX_LEN]):
            board[i] = 2 + LID[c] if c in revealed else (MASK if c in LID else OTHER)
        guessed = np.zeros(26, dtype=np.float32)
        for c in revealed | wrong: guessed[LID[c]] = 1
        target = np.zeros(26, dtype=np.float32)
        for c in set(letters) - revealed: target[LID[c]] = 1
        return torch.from_numpy(board), torch.from_numpy(guessed), torch.tensor(len(word)/MAX_LEN), torch.from_numpy(target)

class BoardTransformer(nn.Module):
    def __init__(self):
        super().__init__(); d = 128
        self.token = nn.Embedding(29, d, padding_idx=PAD); self.pos = nn.Embedding(MAX_LEN, d)
        layer = nn.TransformerEncoderLayer(d, 8, 256, .1, batch_first=True, norm_first=True)
        self.encoder = nn.TransformerEncoder(layer, 3)
        self.state = nn.Sequential(nn.Linear(27, 128), nn.GELU(), nn.Dropout(.1))
        self.head = nn.Sequential(nn.Linear(256, 192), nn.GELU(), nn.Dropout(.1), nn.Linear(192, 26))
    def forward(self, board, guessed, length):
        positions = torch.arange(board.shape[1], device=board.device)
        encoded = self.encoder(self.token(board) + self.pos(positions)[None], src_key_padding_mask=board == PAD)
        valid = (board != PAD).unsqueeze(-1)
        pooled = (encoded * valid).sum(1) / valid.sum(1).clamp_min(1)
        return self.head(torch.cat((pooled, self.state(torch.cat((guessed, length[:, None]), 1))), 1))

model = BoardTransformer().to(DEVICE)
loader = DataLoader(MaskedBoards(train_words), batch_size=512, shuffle=True, num_workers=2, pin_memory=DEVICE.type == "cuda")
opt = torch.optim.AdamW(model.parameters(), lr=2e-3, weight_decay=1e-2)
loss_fn = nn.BCEWithLogitsLoss()
for epoch in range(5):
    model.train(); losses = []
    for board, guessed, length, target in loader:
        board, guessed, length, target = (x.to(DEVICE, non_blocking=True) for x in (board, guessed, length, target))
        opt.zero_grad(set_to_none=True); loss = loss_fn(model(board, guessed, length), target)
        loss.backward(); torch.nn.utils.clip_grad_norm_(model.parameters(), 1); opt.step(); losses.append(loss.item())
    print(f"epoch {epoch + 1}: BCE {np.mean(losses):.4f}")
model.eval()

# Training-only lexicon: a complementary pattern signal, never a test-word lookup.
by_length = defaultdict(list)
for word in set(train_words): by_length[len(word)].append(word)

@torch.inference_mode()
def neural_score(board, guessed):
    tokens = np.zeros((1, MAX_LEN), dtype=np.int64)
    for i, c in enumerate(board[:MAX_LEN]): tokens[0, i] = MASK if c == "_" else (2 + LID[c] if c in LID else OTHER)
    history = np.zeros((1, 26), dtype=np.float32)
    for c in guessed: history[0, LID[c]] = 1
    out = model(torch.from_numpy(tokens).to(DEVICE), torch.from_numpy(history).to(DEVICE), torch.tensor([len(board)/MAX_LEN], device=DEVICE))
    return torch.sigmoid(out).squeeze(0).cpu().numpy()

def compatible(word, board, wrong):
    return all((shown == "_" and actual not in wrong) or shown == actual for shown, actual in zip(board, word))

def choose(board, guessed):
    wrong = guessed - {c for c in board if c in LID}
    candidates = [w for w in by_length[len(board)] if compatible(w, board, wrong)]
    neural = neural_score(board, guessed)
    if candidates:
        counts = Counter(c for w in candidates for c in set(w) if c not in guessed)
        lexical = np.array([counts[c] / len(candidates) for c in ALPHABET])
        score = .58 * neural + .37 * lexical + .05 * prior
    else: score = .92 * neural + .08 * prior
    for c in guessed: score[LID[c]] = -1
    return ALPHABET[score.argmax()]

def play(word):
    board = [c if c not in LID else "_" for c in word]; guessed = set(); sequence = []; strikes = 0
    while "_" in board and strikes < 6:
        letter = choose(board, guessed); guessed.add(letter); sequence.append(letter)
        if letter in word: board = [letter if actual == letter else shown for actual, shown in zip(word, board)]
        else: strikes += 1
    return "".join(sequence)

submission = pd.DataFrame({"word_id": np.arange(len(test_words)), "guessed_letters_string": [play(w) for w in test_words]})
assert list(submission.columns) == REQUIRED_COLUMNS
assert submission.shape == sample_submission.shape
assert submission.word_id.equals(pd.Series(np.arange(len(test_words)), name="word_id"))
# A word containing only visible non-letters correctly terminates with no guesses.
assert submission.guessed_letters_string.map(lambda x: x == "" or (x.isalpha() and x.islower())).all()
submission.to_csv("submission.csv", index=False)
