from sentence_transformers import SentenceTransformer
from pinecone import Pinecone, ServerlessSpec
from pathlib import Path

import os
import json

CURRENT_DIR = os.path.dirname(__file__)
chunks_file = os.path.join(CURRENT_DIR, "ck12_cleaned_chunks.json")

with open(chunks_file, "r", encoding="utf-8") as f:
    chunks = json.load(f)

# --- Initialize Pinecone client ---
pc = Pinecone(api_key="pcsk_pRmYp_RYoaM41dkbpkdnALxnumw23MZ6LVgX76iwERSQQ8zN4SG8KPvSf7XAuqgcuHoSw")
index_name = "k12algebra"
index = pc.Index(index_name)

def retrieve(query_text,k):
    # --- Encode query ---
    model = SentenceTransformer("all-mpnet-base-v2")
    query_embedding = model.encode([query_text])[0].tolist()

    # --- Query Pinecone ---
    results = index.query(vector=query_embedding, top_k=k, include_metadata=True)

    # --- Retrieve and return chunks ---
    return [chunks[int(match['metadata']['chunk_id'])] for match in results['matches']]

if __name__ == "__main__":
    query = "What is the quadratic formula?"
    top_k = 5
    retrieved_chunks = retrieve(query, top_k)
    for i, chunk in enumerate(retrieved_chunks):
        print(f"Chunk {i+1}:\n{chunk}\n")