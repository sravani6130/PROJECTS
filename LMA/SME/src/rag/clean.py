import re
import sys
from pathlib import Path

def remove_empty_lines(text):
    lines = text.splitlines()
    non_empty_lines = [line for line in lines if line.strip() != ""]
    return "\n".join(non_empty_lines)

def remove_image_links(text):
    return re.sub(r"!\[.*?\]\(.*?\)", "", text)

def simple_preprocess(text):
    text = re.sub(r"http\S+", "", text)           # Remove URLs
    text = remove_image_links(text)  # Remove image links
    text = remove_empty_lines(text)   # Remove empty lines
    return text.lower().strip()

def preprocess_markdown_file(file_path):
    file_path = Path(file_path)
    if not file_path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")
    
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    cleaned_text = simple_preprocess(content)
    return cleaned_text

# Example usage from command line
if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python clean.py <path_to_markdown_file>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    cleaned_text = preprocess_markdown_file(input_file)
    output_file = "ck12_cleaned.md"
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(cleaned_text)
    print(f"Cleaned text saved to {output_file}")

