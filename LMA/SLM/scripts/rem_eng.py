import re
input_file = "telugu_inc.txt"
output_file = "indiccorp.txt"

with open(input_file, 'r', encoding='utf-8') as f_in, \
     open(output_file, 'w', encoding='utf-8') as f_out:
    for line in f_in:
        text = line.strip()
        if not text:
            continue
        # Keep only Telugu characters and spaces
        text = re.sub(r'[^\u0C00-\u0C7F\s]', '', text)
        # Collapse multiple spaces
        text = re.sub(r'\s+', ' ', text)
        if text:
            f_out.write(text + "\n")
