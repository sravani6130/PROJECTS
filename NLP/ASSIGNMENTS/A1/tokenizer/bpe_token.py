import re
import pickle
from collections import Counter, defaultdict
import os
try:
    from tqdm import tqdm
except ImportError:
    tqdm = lambda x, **kwargs: x

class BPETokenizer:
    """
    A Byte-Pair Encoding (BPE) tokenizer that builds a vocabulary from a corpus
    without using any external libraries.
    """
    def __init__(self, vocab_size=5000, unk_token="<UNK>", pad_token="<PAD>"):
        self.vocab_size = vocab_size
        self.unk_token = unk_token
        self.pad_token = pad_token
        
        self.vocab = {}
        self.inverse_vocab = {}
        self.merges = {}  # { (pair_tuple): merged_string }
        
        # Add special tokens
        self.unk_id = 0
        self.pad_id = 1
        
        self.vocab[self.unk_token] = self.unk_id
        self.vocab[self.pad_token] = self.pad_id
        self.inverse_vocab[self.unk_id] = self.unk_token
        self.inverse_vocab[self.pad_id] = self.pad_token

    def _get_stats(self, vocab):
        """Calculates frequency of next adjacent symbol pairs."""
        pairs = defaultdict(int)
        for word, freq in vocab.items():
            symbols = word.split()
            for i in range(len(symbols) - 1):
                pairs[symbols[i], symbols[i+1]] += freq
        return pairs

    def _merge_vocab(self, pair, v_in):
        """Replaces the most frequent pair in all occurrences in the vocab."""
        v_out = {}
        replacement = ''.join(pair)
        for word, freq in v_in.items():
            symbols = word.split()
            w_out = []
            i = 0
            while i < len(symbols):
                if i < len(symbols) - 1 and symbols[i] == pair[0] and symbols[i+1] == pair[1]:
                    w_out.append(replacement)
                    i += 2
                else:
                    w_out.append(symbols[i])
                    i += 1
            v_out[' '.join(w_out)] = freq
        return v_out

    def train(self, corpus_lines, max_lines=None, min_freq=5):
        """
        Trains BPE tokenizer on the provided corpus lines.
        """
        word_counts = Counter()
        
        # Get word frequencies across entire corpus
        for i, line in tqdm(enumerate(corpus_lines), desc="Counting word frequencies", unit="lines", total=max_lines):
            if max_lines is not None and i >= max_lines:
                break
            words = re.findall(r"\w+|[^\w\s]", line)
            for w in words:
                word_counts[" ".join(list(w)) + " </w>"] += 1
                
        # Filter rare words to speed up BPE merges
        filtered_counts = Counter({w: c for w, c in word_counts.items() if c >= min_freq})
        word_counts = filtered_counts
        
        # Initialize token vocabulary with base characters
        char_freqs = defaultdict(int)
        for word, freq in word_counts.items():
            for char in word.split():
                char_freqs[char] += freq
                
        for char in sorted(char_freqs.keys()):
            if char not in self.vocab:
                idx = len(self.vocab)
                self.vocab[char] = idx
                self.inverse_vocab[idx] = char
                
        # Calculate how many merges we can do
        num_merges = self.vocab_size - len(self.vocab)
        
        for i in tqdm(range(num_merges), desc="BPE Merging", unit="merge"):
            pairs = self._get_stats(word_counts)
            if not pairs:
                break
                
            best_pair = max(pairs, key=pairs.get)
            self.merges[best_pair] = "".join(best_pair)
            
            # Apply merge to vocab
            word_counts = self._merge_vocab(best_pair, word_counts)
            
            # Add new token to vocab
            new_token = "".join(best_pair)
            if new_token not in self.vocab:
                idx = len(self.vocab)
                self.vocab[new_token] = idx
                self.inverse_vocab[idx] = new_token
                
            # Optional: print progress for large tokenizers
            # if i % 100 == 0:
            #     print(f"BPE merge {i}/{num_merges}")

    def encode(self, text):
        """Encodes text to a list of token ids using learned BPE merges."""
        if not text:
            return []
            
        words = re.findall(r"\w+|[^\w\s]", text)
        token_ids = []
        
        for w in words:
            word = " ".join(list(w)) + " </w>"
            
            # Apply merges sequentially
            for pair, merged in self.merges.items():
                symbols = word.split()
                w_out = []
                i = 0
                while i < len(symbols):
                    if i < len(symbols) - 1 and symbols[i] == pair[0] and symbols[i+1] == pair[1]:
                        w_out.append(merged)
                        i += 2
                    else:
                        w_out.append(symbols[i])
                        i += 1
                word = " ".join(w_out)
                
            # Map symbol to token id
            for token in word.split():
                token_ids.append(self.vocab.get(token, self.unk_id))
                
        return token_ids

    def decode(self, token_ids):
        """Decodes token ids back into text."""
        tokens = [self.inverse_vocab.get(tid, self.unk_token) for tid in token_ids]
        text = "".join(tokens)
        text = text.replace("</w>", " ")
        return text.strip()

    def save(self, filepath):
        with open(filepath, 'wb') as f:
            pickle.dump({
                "vocab": self.vocab,
                "inverse_vocab": self.inverse_vocab,
                "vocab_size": self.vocab_size,
                "unk_token": self.unk_token,
                "pad_token": self.pad_token,
                "unk_id": self.unk_id,
                "pad_id": self.pad_id,
                "merges": self.merges
            }, f)
            
    def load(self, filepath):
        with open(filepath, 'rb') as f:
            data = pickle.load(f)
            
        self.vocab = data["vocab"]
        self.inverse_vocab = data["inverse_vocab"]
        self.vocab_size = data["vocab_size"]
        self.unk_token = data["unk_token"]
        self.pad_token = data["pad_token"]
        self.unk_id = data["unk_id"]
        self.pad_id = data["pad_id"]
        self.merges = data.get("merges", {})

def train_bpe_tokenizer(train_file_path, vocab_size=5000, save_path=None, max_lines=100000, min_freq=5):
    """
    Trains a BPETokenizer on the specified file and returns the trained instance.
    Optionally saves the vocabulary if save_path is provided.
    """
    tokenizer = BPETokenizer(vocab_size=vocab_size)
    
    if os.path.exists(train_file_path):
        with open(train_file_path, 'r', encoding='utf-8') as f:
            tokenizer.train(f, max_lines=max_lines, min_freq=min_freq)
        print(f"[{train_file_path}] Trained BPE Tokenizer. Vocabulary size: {len(tokenizer.vocab)}")
        
        if save_path:
            os.makedirs(os.path.dirname(save_path), exist_ok=True)
            tokenizer.save(save_path)
            print(f"Saved BPE tokenizer vocabulary to {save_path}")
    else:
        print(f"Warning: Training file {train_file_path} not found.")
        
    return tokenizer
