import re

def clean_english_file(input_file, output_file):
    """
    Reads input_file line by line, cleans English text, and writes to output_file.
    Keeps only English letters, numbers, punctuation, and spaces.
    """
    with open(input_file, 'r', encoding='utf-8') as f_in, \
         open(output_file, 'w', encoding='utf-8') as f_out:
        for line in f_in:
            text = line.strip()
            if not text:
                continue
            # Keep only English letters, numbers, punctuation, spaces
            text = re.sub(r'[^a-zA-Z0-9\s.,;:!?\'"-]', '', text)
            text = re.sub(r'\s+', ' ', text)  # collapse multiple spaces
            if text:
                f_out.write(text + "\n")

clean_english_file("fineweb_eng.txt", "fineweb_english.txt")