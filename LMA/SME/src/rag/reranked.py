from sentence_transformers import SentenceTransformer
import numpy as np
from .retrieve_mpnet import retrieve_mpnet
from .sparse_retrieval import retrieve_bm25

def hybrid_rerank(topics, query_text, N):
    # Determine number of hits from each source (retrieve slightly more for reranking)
    k_mpnet = N + 4
    k_bm25 = N + 4

    # Step 1: Retrieve hits
    mpnet_hits = retrieve_mpnet(query_text=query_text, top_k=k_mpnet)
    bm25_hits = retrieve_bm25(topics=topics, total_k=k_bm25)

    # Add source info (optional, can be removed if not needed)
    for h in mpnet_hits:
        h["source"] = "mpnet"
    for h in bm25_hits:
        h["source"] = "bm25"

    # Step 2: Merge candidates (avoid duplicates by chunk_id)
    candidates = {}
    for h in mpnet_hits + bm25_hits:
        candidates[h["chunk_id"]] = {
            "text": h["text"]
        }

    candidate_texts = [candidates[cid]["text"] for cid in candidates]

    # Step 3: Encode query and candidates using BGE
    model_bge = SentenceTransformer("BAAI/bge-base-en")
    query_emb = model_bge.encode([query_text])[0]
    candidate_embs = model_bge.encode(candidate_texts, batch_size=16)

    # Step 4: Compute cosine similarity
    similarities = np.dot(candidate_embs, query_emb) / (
        np.linalg.norm(candidate_embs, axis=1) * np.linalg.norm(query_emb)
    )

    # Step 5: Rerank and return only texts
    reranked_texts = [
        text for text, score in sorted(
            zip(candidate_texts, similarities),
            key=lambda x: x[1],
            reverse=True
        )
    ]

    return reranked_texts[:N]

# # ----------------- Example Usage -----------------
# if __name__ == "__main__":
#     topics = ["linear algebra", "quadratic equations"]
#     query = "algebraic expression for perimeter of a rectangle"
#     N = 4

#     top_texts = hybrid_rerank(topics, query, N)

#     for i, text in enumerate(top_texts, 1):
#         print(f"{i}. {text} ...")
#         print("-----------")
