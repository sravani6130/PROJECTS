import re
import pickle
from collections import Counter

def regex_tokenize(text):
    """
    Tokenizes text using a specific regular expression.
    
    This regex captures:
    1. Words with optional internal apostrophes (e.g., "don't", "it's", "hello")
    2. Numbers, including decimals (e.g., "3.14", "42")
    3. Individual punctuation marks or special characters
    
    Args:
        text (str): Input string to be tokenized.
        
    Returns:
        list of str: A list of string tokens.
    """
    if not text:
        return []
    
    # Pattern explanation:
    # [a-zA-Z]+(?:'[a-zA-Z]+)? : Words with optional apostrophe
    # | \d+(?:\.\d+)?          : Numbers with optional decimals
    # | [^\w\s]                : Any non-word, non-whitespace character (punctuation)
    pattern = r"[a-zA-Z]+(?:'[a-zA-Z]+)?|\d+(?:\.\d+)?|[^\w\s]"
    
    return re.findall(pattern, text)


class RegexTokenizer:
    """
    A tokenizer that builds a vocabulary from a cleaned corpus and uses 
    the regex_tokenize rule to encode and decode strings.
    """
    def __init__(self, vocab_size=None, unk_token="<UNK>", pad_token="<PAD>"):
        self.vocab = {}
        self.inverse_vocab = {}
        self.vocab_size = vocab_size
        
        self.unk_token = unk_token
        self.pad_token = pad_token
        
        # Add special tokens to vocabulary
        self._add_to_vocab(self.unk_token)
        self._add_to_vocab(self.pad_token)
        
        self.unk_id = self.vocab[self.unk_token]
        self.pad_id = self.vocab[self.pad_token]

    def _add_to_vocab(self, token):
        if token not in self.vocab:
            idx = len(self.vocab)
            self.vocab[token] = idx
            self.inverse_vocab[idx] = token

    def train(self, corpus_lines):
        """
        Trains the tokenizer by building a vocabulary based on token frequencies
        in the provided corpus lines.
        """
        token_counts = Counter()
        
        for line in corpus_lines:
            tokens = regex_tokenize(line)
            token_counts.update(tokens)
            
        if self.vocab_size is not None:
            max_new_tokens = max(0, self.vocab_size - len(self.vocab))
            common_tokens = token_counts.most_common(max_new_tokens)
            for token, _ in common_tokens:
                self._add_to_vocab(token)
        else:
            for token, _ in token_counts.most_common():
                self._add_to_vocab(token)

    def encode(self, text):
        """
        Converts text string into a list of vocabulary token IDs.
        """
        tokens = regex_tokenize(text)
        return [self.vocab.get(token, self.unk_id) for token in tokens]

    def decode(self, token_ids):
        """
        Converts a list of token IDs back into a text string.
        (Tokens are joined by a space)
        """
        tokens = [self.inverse_vocab.get(tid, self.unk_token) for tid in token_ids]
        return " ".join(tokens)

    def save(self, filepath):
        """
        Saves the tokenizer object to a pickle file.
        """
        with open(filepath, 'wb') as f:
            pickle.dump({
                "vocab": self.vocab,
                "inverse_vocab": self.inverse_vocab,
                "vocab_size": self.vocab_size,
                "unk_token": self.unk_token,
                "pad_token": self.pad_token,
                "unk_id": self.unk_id,
                "pad_id": self.pad_id
            }, f)
            
    def load(self, filepath):
        """
        Loads the tokenizer state from a pickle file, overriding current state.
        """
        with open(filepath, 'rb') as f:
            data = pickle.load(f)
            
        self.vocab = data["vocab"]
        self.inverse_vocab = data["inverse_vocab"]
        self.vocab_size = data["vocab_size"]
        self.unk_token = data["unk_token"]
        self.pad_token = data["pad_token"]
        self.unk_id = data["unk_id"]
        self.pad_id = data["pad_id"]
        

def train_regex_tokenizer(train_file_path, vocab_size=10000, save_path=None):
    """
    Trains a RegexTokenizer on the specified file and returns the trained instance.
    Optionally saves the vocabulary if save_path is provided.
    """
    import os
    tokenizer = RegexTokenizer(vocab_size=vocab_size)
    
    if os.path.exists(train_file_path):
        with open(train_file_path, 'r', encoding='utf-8') as f:
            tokenizer.train(f)
        print(f"[{train_file_path}] Trained Regex Tokenizer. Vocabulary size: {len(tokenizer.vocab)}")
        
        if save_path:
            os.makedirs(os.path.dirname(save_path), exist_ok=True)
            tokenizer.save(save_path)
            print(f"Saved regex tokenizer vocabulary to {save_path}")
    else:
        print(f"Warning: Training file {train_file_path} not found.")
        
    return tokenizer
