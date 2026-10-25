from whoosh import index
from whoosh.fields import Schema, TEXT, ID
from whoosh.qparser import QueryParser
import os
import json

def build_bm25_index(chunks, index_dir="bm25_index"):
    CURRENT_DIR = os.path.dirname(__file__)
    index_dir = os.path.join(CURRENT_DIR, "bm25_index")
    
    if not os.path.exists(index_dir):
        os.mkdir(index_dir)

    schema = Schema(
        chunk_id=ID(stored=True),
        content=TEXT(stored=True)
    )

    ix = index.create_in(index_dir, schema)
    writer = ix.writer()

    for c in chunks:
        writer.add_document(
            chunk_id=str(c["chunk_id"]),
            content=c["text"]
        )

    writer.commit()
    return ix


def main():
    chunks_file = "all_chunks.jsonl"

    if not os.path.exists(chunks_file):
        raise FileNotFoundError(f"Chunk file not found: {chunks_file}")

    # FIXED: load JSONL properly
    chunks = []
    with open(chunks_file, "r", encoding="utf-8") as f:
        for line in f:
            chunks.append(json.loads(line))

    print(f"Loaded {len(chunks)} chunks from {chunks_file}")

    CURRENT_DIR = os.path.dirname(__file__)
    index_dir = os.path.join(CURRENT_DIR, "bm25_index")

    if not os.path.exists(index_dir):
        ix = build_bm25_index(chunks, index_dir=index_dir)
    else:
        ix = index.open_dir(index_dir)

    print("BM25 index ready")

    return ix


if __name__ == "__main__":
    main()
