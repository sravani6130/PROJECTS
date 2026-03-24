import json
import re
import random
import os

def load_jsonl(filepath):
    """
    Generator that lazily loads texts from a JSONL file line-by-line.
    
    Args:
        filepath (str): Path to input JSONL file.
        
    Yields:
        str: Raw text extracted from each valid JSON line.
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                data = json.loads(line)
                if 'text' in data:
                    yield data['text']
            except json.JSONDecodeError:
                continue

def clean_text(text):
    """
    Cleans a single text string by removing invisible artifacts and excessive spaces.
    
    Args:
        text (str): The raw text to clean.
        
    Returns:
        str: Cleaned text. Returns empty string if it's invalid.
    """
    if not text:
        return ""
    
    # Remove control characters and non-printable unicode artifacts
    text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]', '', text)
    
    # Remove specific zero-width spaces and BOM
    text = re.sub(r'[\u200b\uFEFF]', '', text)
    
    # Normalize multiple whitespaces/newlines to a single space
    text = re.sub(r'\s+', ' ', text)
    
    return text.strip()

def clean_corpus_lines(lines):
    """
    Generator that iterates over raw text lines, yields cleaned lines,
    and drops empty or corrupted inputs.
    
    Args:
        lines (iterable): An iterable of text strings.
        
    Yields:
        str: Successfully cleaned and non-empty text lines.
    """
    for line in lines:
        cleaned = clean_text(line)
        if cleaned:
            yield cleaned

def split_dataset(lines, train_ratio=0.8, val_ratio=0.1, seed=42):
    """
    Splits a collection of cleaned lines into train, validation, and test partitions.
    
    Args:
        lines (list): List of text strings.
        train_ratio (float): Ratio of training data.
        val_ratio (float): Ratio of validation data.
        seed (int): Random seed for deterministic shuffling.
        
    Returns:
        tuple: (train_lines, val_lines, test_lines) as lists of strings.
    """
    random.seed(seed)
    
    # Create a local copy to shuffle in memory 
    shuffled_lines = list(lines)
    random.shuffle(shuffled_lines)
    
    total = len(shuffled_lines)
    train_end = int(total * train_ratio)
    val_end = train_end + int(total * val_ratio)
    
    train_lines = shuffled_lines[:train_end]
    val_lines = shuffled_lines[train_end:val_end]
    test_lines = shuffled_lines[val_end:]
    
    return train_lines, val_lines, test_lines

def save_dataset(lines, filepath):
    """
    Saves an iterable of lines to a flat text file.
    
    Args:
        lines (iterable): Text lines to be written.
        filepath (str): Output file path.
    """
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, 'w', encoding='utf-8') as f:
        for line in lines:
            f.write(line + '\n')

def process_corpus(input_path, output_dir, language, seed=42):
    """
    Executes the full pipeline for preprocessing a raw corpus and partitioning it.
    Processes reading line-by-line where possible before shuffling.
    
    Args:
        input_path (str): File path to raw JSONL data.
        output_dir (str): Directory to save cleaned partition arrays.
        language (str): Language string prefix (e.g., 'en' or 'mn').
        seed (int): Shuffling random seed for deterministic outcome.
        
    Returns:
        dict: A dictionary of corpus statistics.
    """
    total_lines = 0
    cleaned_lines = []
    
    # Process sequentially step-by-step
    raw_lines_gen = load_jsonl(input_path)
    
    for raw_line in raw_lines_gen:
        total_lines += 1
        cleaned = clean_text(raw_line)
        if cleaned:
            cleaned_lines.append(cleaned)
            
    clean_lines_count = len(cleaned_lines)
    
    train_lines, val_lines, test_lines = split_dataset(
        cleaned_lines, train_ratio=0.8, val_ratio=0.1, seed=seed
    )
    
    # Construct paths
    train_path = os.path.join(output_dir, f"{language}_train.txt")
    val_path = os.path.join(output_dir, f"{language}_val.txt")
    test_path = os.path.join(output_dir, f"{language}_test.txt")
    
    save_dataset(train_lines, train_path)
    save_dataset(val_lines, val_path)
    save_dataset(test_lines, test_path)
    
    return {
        "total_lines": total_lines,
        "clean_lines": clean_lines_count,
        "train_size": len(train_lines),
        "val_size": len(val_lines),
        "test_size": len(test_lines)
    }
