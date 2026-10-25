from sentence_transformers import SentenceTransformer
from pinecone import Pinecone, ServerlessSpec
from pathlib import Path
import json

# --- Load chunks ---
chunks_file = "ck12_cleaned_chunks.json"
with open(chunks_file, "r", encoding="utf-8") as f:
    chunks = json.load(f)

# --- Load embedding model ---
model = SentenceTransformer("all-mpnet-base-v2")

# --- Generate embeddings ---
embeddings = model.encode(chunks, batch_size=16, show_progress_bar=True)
print(f"Embeddings shape: {embeddings.shape}")

# --- Initialize Pinecone client ---
pc = Pinecone(api_key="pcsk_pRmYp_RYoaM41dkbpkdnALxnumw23MZ6LVgX76iwERSQQ8zN4SG8KPvSf7XAuqgcuHoSw")  # replace with your actual API key

index_name = "textbook-chunks"

# --- Create index if it doesn't exist ---
if not pc.has_index(index_name):
    pc.create_index(
        name=index_name,
        dimension=embeddings.shape[1],  # 768 for all-mpnet-base-v2
        metric="cosine",
        spec=ServerlessSpec(cloud="aws", region="us-east-1")
    )

# --- Connect to index ---
index = pc.Index(index_name)

# --- Prepare vectors with metadata ---
vectors = []
for i, chunk_vec in enumerate(embeddings):
    metadata = {"chunk_id": i, "parent_doc": Path(chunks_file).stem}
    vectors.append((str(i), chunk_vec.tolist(), metadata))

# --- Upsert vectors in batches ---
batch_size = 50
for i in range(0, len(vectors), batch_size):
    batch = vectors[i:i + batch_size]
    index.upsert(vectors=batch)

print("All chunks indexed in Pinecone successfully.")
