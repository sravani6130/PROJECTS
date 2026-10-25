import re
import os
import json
from pathlib import Path
from transformers import AutoTokenizer

def extract_metadata_from_filename(filename):
    name = filename.lower()

    # CK12 textbooks
    if name.startswith("ck12"):
        return {
            "textbook": "CK12",
            "grade": ["8", "9", "10"]  # list of strings
        }

    # NCERT mapping
    prefix_map = {
        "f": "6", "g": "7", "h": "8", "i": "9",
        "j": "10", "k": "11", "l": "12"
    }
    prefix = name[0]

    if prefix in prefix_map:
        return {
            "textbook": "NCERT",
            "grade": prefix_map[prefix]
        }

    return {"textbook": "Unknown", "grade": None}


def count_meaningful_lines(text):
    return len([ln for ln in text.splitlines() if ln.strip() != ""])


def split_by_headings(text):
    heading_re = re.compile(r"^(#{1,6})\s+(.+)$", re.MULTILINE)

    chunks = []
    current_heading = None
    current_body = []

    for line in text.splitlines():
        match = heading_re.match(line)
        if match:
            if current_heading is not None:
                chunks.append((current_heading, "\n".join(current_body).strip()))
            current_heading = line.strip()
            current_body = []
        else:
            current_body.append(line)

    if current_heading is not None:
        chunks.append((current_heading, "\n".join(current_body).strip()))

    return chunks

def merge_small_content_headings(chunks, min_lines=5):
    merged = []
    buffer_heading = None
    buffer_body = []

    for heading, body in chunks:
        if count_meaningful_lines(body) < min_lines:
            if buffer_heading is None:
                buffer_heading = heading
            else:
                buffer_heading += "\n" + heading
            buffer_body.append(body)
        else:
            if buffer_heading is None:
                merged.append((heading, body))
            else:
                merged.append((
                    buffer_heading + "\n" + heading,
                    "\n".join(buffer_body + [body])
                ))
                buffer_heading = None
                buffer_body = []

    if buffer_heading is not None:
        merged.append((buffer_heading, "\n".join(buffer_body)))

    return merged



# Token based chunking
def chunk_tokens(token_ids, chunk_size=512, overlap=50):
    chunks = []
    start = 0
    while start < len(token_ids):
        end = min(start + chunk_size, len(token_ids))
        chunks.append(token_ids[start:end])
        if end == len(token_ids):
            break
        start += chunk_size - overlap
    return chunks

GLOBAL_CHUNK_ID = 0


def process_single_md(filepath, tokenizer, chunk_size=512, overlap=50):
    global GLOBAL_CHUNK_ID

    text = Path(filepath).read_text(encoding="utf-8")
    metadata = extract_metadata_from_filename(Path(filepath).name)

    raw_chunks = split_by_headings(text)
    semantic_chunks = merge_small_content_headings(raw_chunks, min_lines=5)

    final_output = []

    for heading, body in semantic_chunks:
        combined = heading + "\n" + body
        encoded = tokenizer(combined, return_tensors="pt", truncation=False)
        token_ids = encoded["input_ids"][0].tolist()

        if len(token_ids) <= chunk_size:
            final_output.append({
                "chunk_id": GLOBAL_CHUNK_ID,
                "text": combined,
                "file_name": Path(filepath).name,
                "textbook": metadata["textbook"],
                "grade": metadata["grade"],
                "heading": heading
            })
            GLOBAL_CHUNK_ID += 1

        else:
            token_chunks = chunk_tokens(token_ids, chunk_size, overlap)
            for subset in token_chunks:
                decoded = tokenizer.decode(subset, skip_special_tokens=True)
                final_output.append({
                    "chunk_id": GLOBAL_CHUNK_ID,
                    "text": decoded,
                    "file_name": Path(filepath).name,
                    "textbook": metadata["textbook"],
                    "grade": metadata["grade"],
                    "heading": heading
                })
                GLOBAL_CHUNK_ID += 1

    return final_output


def process_all_md_folder(md_folder, output_jsonl="all_chunks.jsonl"):
    tokenizer = AutoTokenizer.from_pretrained("sentence-transformers/all-mpnet-base-v2")

    folder = Path(md_folder)
    files = [p for p in folder.rglob("*.md")]

    all_chunks = []

    for f in files:
        print("Processing:", f)
        file_chunks = process_single_md(f, tokenizer)
        all_chunks.extend(file_chunks)

    with open(output_jsonl, "w", encoding="utf-8") as out:
        for item in all_chunks:
            out.write(json.dumps(item, ensure_ascii=False) + "\n")

    print("Saved:", output_jsonl)
    print("Total chunks:", len(all_chunks))
