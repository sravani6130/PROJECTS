import os
try:
    from tqdm import tqdm
except ImportError:
    tqdm = lambda x, **kwargs: x

from preprocessing import process_corpus
from tokenizer.white_space_token import train_whitespace_tokenizer, WhitespaceTokenizer
from tokenizer.regex_token import train_regex_tokenizer, RegexTokenizer
from tokenizer.bpe_token import train_bpe_tokenizer, BPETokenizer
from ngram_lm import NGramModel

def train_or_load_tokenizers(train_file):
    """
    Initializes and trains (or simply loads) the Whitespace, Regex, and BPE Tokenizers
    to maintain architecture modularity.
    """
    print("\n--- Initializing Tokenizers ---")
    
    # 1. Whitespace Tokenizer
    ws = WhitespaceTokenizer(vocab_size=5000)
    if os.path.exists("Data/models/en_whitespace_vocab.pkl"):
        ws.load("Data/models/en_whitespace_vocab.pkl")
        print("Loaded existing Whitespace tokenizer.")
    else:
        print("Training Whitespace tokenizer...")
        ws = train_whitespace_tokenizer(train_file, vocab_size=5000, save_path="Data/models/en_whitespace_vocab.pkl")
        
    # 2. Regex Tokenizer
    regex = RegexTokenizer(vocab_size=5000)
    if os.path.exists("Data/models/en_regex_vocab.pkl"):
        regex.load("Data/models/en_regex_vocab.pkl")
        print("Loaded existing Regex tokenizer.")
    else:
        print("Training Regex tokenizer...")
        regex = train_regex_tokenizer(train_file, vocab_size=5000, save_path="Data/models/en_regex_vocab.pkl")
        
    # 3. BPE Tokenizer
    bpe = BPETokenizer()
    if os.path.exists("Data/models/en_bpe_vocab.pkl"):
        bpe.load("Data/models/en_bpe_vocab.pkl")
        print("Loaded existing BPE tokenizer.")
    else:
        print("Training BPE tokenizer...")
        bpe = train_bpe_tokenizer(train_file, vocab_size=5000, save_path="Data/models/en_bpe_vocab.pkl", max_lines=100000, min_freq=5)
        
    return ws, regex, bpe

def main():
    # print("Preprocessing English corpus...")
    # en_stats = process_corpus("Data/raw/cc100_en.jsonl", "Data/cleaned", "en")
    # print(f"English corpus stats: {en_stats}")
    
    # print("\nPreprocessing Mongolian corpus...")
    # mn_stats = process_corpus("Data/raw/cc100_mn.jsonl", "Data/cleaned", "mn")
    # print(f"Mongolian corpus stats: {mn_stats}")

    mn_train_file = "Data/cleaned/mn_train.txt"
    en_train_file = "Data/cleaned/en_train.txt"
    
    # print("Training WS on English corpus...")
    # en_ws_tokenizer = train_whitespace_tokenizer(
    #     en_train_file, vocab_size=10000, save_path="Data/models/en_whitespace_vocab.pkl"
    # )
    
    # print("\nTraining WS on Mongolian corpus...")
    # mn_ws_tokenizer = train_whitespace_tokenizer(
    #     mn_train_file, vocab_size=10000, save_path="Data/models/mn_whitespace_vocab.pkl"
    # )
    
    # print("\n--- Training Regex Tokenizers ---")
    
    # print("Training Regex on English corpus...")
    # en_regex_tokenizer = train_regex_tokenizer(
    #     en_train_file, vocab_size=10000, save_path="Data/models/en_regex_vocab.pkl"
    # )
    
    # print("\nTraining Regex on Mongolian corpus...")
    # mn_regex_tokenizer = train_regex_tokenizer(
    #     mn_train_file, vocab_size=10000, save_path="Data/models/mn_regex_vocab.pkl"
    # )
    
    # print("\n--- Training BPE Tokenizers ---")
    
    # print("Training BPE on English corpus...")
    # en_bpe_tokenizer = train_bpe_tokenizer(
    #     en_train_file, vocab_size=5000, save_path="Data/models/en_bpe_vocab.pkl"
    # )
    
    # print("\nTraining BPE on Mongolian corpus...")
    # mn_bpe_tokenizer = train_bpe_tokenizer(
    #     mn_train_file, vocab_size=5000, save_path="Data/models/mn_bpe_vocab.pkl"
    # )

    if not os.path.exists(en_train_file):
        print(f"File {en_train_file} not found. Ensure preprocessing script has been run.")
        return
        
    # Isolate Tokenizers
    ws_tok, reg_tok, bpe_tok = train_or_load_tokenizers(en_train_file)
    tokenizers = {
        "Whitespace": ws_tok,
        "Regex": reg_tok,
        "BPE": bpe_tok
    }
    
    # Extract corpus sample efficiently for multiple LM tests
    # Using 5000 lines because we are running `encode()` 9 consecutive times!
    print(f"\nReading English corpus for Language Model Tests...")
    with open(en_train_file, 'r', encoding='utf-8') as f:
        corpus_lines = []
        for i, line in enumerate(f):
            if i >= 5000:
                break
            corpus_lines.append(line.strip())
            
    # Extract test partition
    en_test_file = "Data/cleaned/en_test.txt"
    with open(en_test_file, 'r', encoding='utf-8') as f:
        test_lines = []
        for i, line in enumerate(f):
            if i >= 500: # Testing on 500 lines for relatively quick generation across 9 models
                break
            test_lines.append(line.strip())

    smoothings = ["none", "witten_bell", "kneser_ney"]
    prompt = "The university is"
    
    print("\n" + "="*60)
    print("      LANGUAGE MODEL PREDICTIONS (9 SETUPS)")
    print("="*60)
    
    # Iterate across 3 tokenizers and 3 smoothings = 9 configurations
    configs = [(tok_name, tok, smooth) for tok_name, tok in tokenizers.items() for smooth in smoothings]
    
    for tok_name, tokenizer, smooth in tqdm(configs, desc="Evaluating 9 LM Setups", unit="model"):
        print(f"\n[TOKENIZER: {tok_name.upper()} | SMOOTHING: {smooth}]")
        lm = NGramModel(n=4, tokenizer=tokenizer, smoothing=smooth)
        lm.train(corpus_lines)
        
        prediction = lm.autocomplete(prompt, max_new_tokens=15)
        perplexity = lm.calculate_perplexity(test_lines)
        
        print(f"  -> Prediction: {prediction}")
        print(f"  -> Test Perplexity: {perplexity:.2f}\n")

if __name__ == "__main__":
    main()
