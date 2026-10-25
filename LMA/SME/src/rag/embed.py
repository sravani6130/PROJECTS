from sentence_transformers import SentenceTransformer
from pinecone import Pinecone, ServerlessSpec
import json

# -------------------------------------------------------
# Load chunks
# -------------------------------------------------------
chunks_file = "all_chunks.jsonl"

chunks = []
with open(chunks_file, "r", encoding="utf-8") as f:
    for i, line in enumerate(f):
        chunks.append(json.loads(line))

chunk_texts = [c["text"] for c in chunks]

# -------------------------------------------------------
# Load embedding models
# -------------------------------------------------------
model_mpnet = SentenceTransformer("sentence-transformers/all-mpnet-base-v2")
# model_bge = SentenceTransformer("BAAI/bge-base-en")

print("Encoding with MPNet...")
emb_mpnet = model_mpnet.encode(chunk_texts, batch_size=16, show_progress_bar=True)

# -------------------------------------------------------
# Pinecone init
# -------------------------------------------------------
pc = Pinecone(api_key="pcsk_pRmYp_RYoaM41dkbpkdnALxnumw23MZ6LVgX76iwERSQQ8zN4SG8KPvSf7XAuqgcuHoSw") 

index_mpnet = "k12embeddata"

# -------------------------------------------------------
# Create MPNet index if missing
# -------------------------------------------------------
if not pc.has_index(index_mpnet):
    pc.create_index(
        name=index_mpnet,
        dimension=emb_mpnet.shape[1], 
        metric="cosine",
        spec=ServerlessSpec(cloud="aws", region="us-east-1")
    )


idx_mpnet = pc.Index(index_mpnet)
# -------------------------------------------------------
# Prepare vectors for MPNet
# -------------------------------------------------------
vectors_mpnet = []
for i, emb in enumerate(emb_mpnet):
    c = chunks[i]
    vectors_mpnet.append((
        str(c["chunk_id"]),
        emb.tolist(),
        {
            "chunk_id": c["chunk_id"],
            "file": c["file_name"],
            "grade": c["grade"],
            "textbook": c["textbook"],
            "heading": c["heading"]
        }
    ))

batch_size = 100

# MPNet Upsert
for i in range(0, len(vectors_mpnet), batch_size):
    idx_mpnet.upsert(vectors=vectors_mpnet[i:i+batch_size])
    
print("Indexing into MPNet index completed.")

