from sentence_transformers import SentenceTransformer
from pinecone import Pinecone
import json 
import os

def retrieve_mpnet(query_text, top_k=5):
    
    CURRENT_DIR = os.path.dirname(__file__)
    chunks_file = os.path.join(CURRENT_DIR, "all_chunks.jsonl")
    # --- Load local chunks
    chunks_dict = {}
    with open(chunks_file, "r", encoding="utf-8") as f:
        for line in f:
            c = json.loads(line)
            chunks_dict[str(c["chunk_id"])] = c  # store as string to match Pinecone IDs

    # --- Initialize Pinecone ---
    pc = Pinecone(api_key="pcsk_pRmYp_RYoaM41dkbpkdnALxnumw23MZ6LVgX76iwERSQQ8zN4SG8KPvSf7XAuqgcuHoSw")
    idx_mpnet = pc.Index("k12embeddata")

    # --- Load MPNet model ---
    model_mpnet = SentenceTransformer("sentence-transformers/all-mpnet-base-v2")

    # --- Encode query ---
    query_emb_mpnet = model_mpnet.encode([query_text])[0].tolist()

    # --- Query MPNet index ---
    result_mpnet = idx_mpnet.query(
        vector=query_emb_mpnet,
        top_k=top_k,
        include_metadata=True
    )

    # --- Collect results ---
    hits = []
    for match in result_mpnet.matches:
        chunk_id = str(int(float(match.metadata["chunk_id"])))
        chunk = chunks_dict.get(chunk_id)
        if chunk:
            hits.append({
                "chunk_id": chunk_id,
                # "score": match.score,
                "text": chunk["text"],
                # "file": chunk.get("file_name"),
                # "grade": chunk.get("grade"),
                # "heading": chunk.get("heading")
            })
    return hits


# # --- Example usage ---
# if __name__ == "__main__":
#     query = "What is the algebraic expression for perimeter of a rectangle?"
#     top_results = retrieve_mpnet(query, top_k=5)

#     for r in top_results:
#         print(f"Score: {r['score']}")
#         print(f"Text: {r['text'][:300]}...")  # first 300 chars
#         # print(f"File: {r['file']}, Grade: {r['grade']}, Heading: {r['heading']}")
#         print("-----------")
