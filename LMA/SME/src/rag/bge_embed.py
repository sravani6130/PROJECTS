from sentence_transformers import SentenceTransformer
from pinecone import Pinecone, ServerlessSpec
import json


chunks_file = "all_chunks.jsonl"

chunks = []
with open(chunks_file, "r", encoding="utf-8") as f:
    for i, line in enumerate(f):
        chunks.append(json.loads(line))

chunk_texts = [c["text"] for c in chunks]

model_bge = SentenceTransformer("BAAI/bge-base-en")

print("Encoding with BGE...")
emb_bge = model_bge.encode(chunk_texts, batch_size=16, show_progress_bar=True)

pc = Pinecone(api_key="pcsk_pRmYp_RYoaM41dkbpkdnALxnumw23MZ6LVgX76iwERSQQ8zN4SG8KPvSf7XAuqgcuHoSw") 

index_bge = "k12algebrabge"


# -------------------------------------------------------
# Create BGE index if missing
# -------------------------------------------------------
if not pc.has_index(index_bge):
    pc.create_index(
        name=index_bge,
        dimension=emb_bge.shape[1], 
        metric="cosine",
        spec=ServerlessSpec(cloud="aws", region="us-east-1")
    )

# idx_mpnet = pc.Index(index_mpnet)
idx_bge = pc.Index(index_bge)

vectors_bge = []
for i, emb in enumerate(emb_bge):
    c = chunks[i]
    vectors_bge.append((
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
# BGE Upsert
batch_size = 100
for i in range(0, len(vectors_bge), batch_size):
    idx_bge.upsert(vectors=vectors_bge[i:i+batch_size])

print("Indexing into BGE index completed.")



from sentence_transformers import SentenceTransformer
from pinecone import Pinecone
import json

# --- Initialize Pinecone ---
pc = Pinecone(api_key="pcsk_pRmYp_RYoaM41dkbpkdnALxnumw23MZ6LVgX76iwERSQQ8zN4SG8KPvSf7XAuqgcuHoSw")  # replace with your actual API key


index_bge = "k12algebrabge"

idx_bge = pc.Index(index_bge)

chunks_file = "all_chunks.jsonl"
chunks_dict = {}  # map chunk_id -> chunk data
with open(chunks_file, "r", encoding="utf-8") as f:
    for line in f:
        c = json.loads(line)
        chunks_dict[str(c["chunk_id"])] = c  # store as string to match Pinecone IDs

model_bge = SentenceTransformer("BAAI/bge-base-en")

# --- Example query ---
query_text = "What is the algebraic expression for perimeter of a rectangle?"
query_emb_bge = model_bge.encode([query_text])[0].tolist()



# --- Query BGE index ---
result_bge = idx_bge.query(
    vector=query_emb_bge,
    top_k=5,
    include_metadata=True
)

# print("\nBGE Results:")
# for match in result_bge.matches:
#     chunk_id = int(float(match.metadata["chunk_id"]))  # ensure integer
#     chunk = chunks_dict.get(str(chunk_id))

#     if chunk:
#         print(f"Score: {match.score}")
#         print(f"Text: {chunk['text']}")
#         print(f"File: {chunk['file_name']}, Grade: {chunk['grade']}, Heading: {chunk['heading']}")
#         print("-----------")










