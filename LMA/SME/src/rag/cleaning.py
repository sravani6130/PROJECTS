import re
import os
from pathlib import Path

def remove_empty_lines(text):
    lines = text.splitlines()
    non_empty = [line for line in lines if line.strip() != ""]
    return "\n".join(non_empty)

def remove_image_links(text):
    # Remove markdown images: ![alt](url)
    text = re.sub(r"!\[.*?\]\(.*?\)", "", text)

    # Remove figure captions like: Figure 2: ...
    text = re.sub(r"figure\s*\d+[:.\- ]+.*", "", text, flags=re.IGNORECASE)

    return text

def remove_hyperlinks(text):
    # Remove bare URLs
    text = re.sub(r"http[s]?://\S+", "", text)

    # Remove markdown hyperlinks: [text](url)
    text = re.sub(r"\[.*?\]\(.*?\)", "", text)

    return text

def simple_preprocess(text):
    text = remove_hyperlinks(text)
    text = remove_image_links(text)
    text = remove_empty_lines(text)
    return text.lower().strip()

def preprocess_markdown_file(file_path):
    file_path = Path(file_path)
    with open(file_path, "r", encoding="utf_8") as f:
        content = f.read()
    cleaned = simple_preprocess(content)
    return cleaned

def collect_markdown_files(directory):
    directory = Path(directory)
    md_files = []
    for root, dirs, files in os.walk(directory):
        for name in files:
            if name.lower().endswith(".md"):
                md_files.append(Path(root) / name)
    return md_files

if __name__ == "__main__":
    input_dir = Path("./all_md_files")

    md_files = collect_markdown_files(input_dir)

    for path in md_files:
        cleaned = preprocess_markdown_file(path)

        # Overwrite original file
        with open(path, "w", encoding="utf_8") as f:
            f.write(cleaned)

        print(f"Cleaned and overwritten: {path}")

    print("All markdown files cleaned in-place.")
