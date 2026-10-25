from whoosh import index
from whoosh.qparser import QueryParser

def retrieve_bm25(topics, total_k=10, index_dir="bm25_index"):
    """
    Retrieve top chunks for a list of topics using BM25.
    Ensures at least the highest-scoring hit per topic is included.
    """
    ix = index.open_dir(index_dir)
    qp = QueryParser("content", schema=ix.schema)
    
    all_hits = []
    guaranteed_hits = []  # store the top hit per topic

    with ix.searcher() as searcher:
        for topic in topics:
            q = qp.parse(topic)
            results = searcher.search(q, limit=total_k)
            topic_results = []

            for r in results:
                hit = {
                    "chunk_id": r["chunk_id"],
                    "score": float(r.score),
                    # "topic": topic
                    "text": r["content"]
                }
                topic_results.append(hit)
            
            # Keep the max scoring hit from this topic if any
            if topic_results:
                max_hit = max(topic_results, key=lambda x: x["score"])
                guaranteed_hits.append(max_hit)
            
            all_hits.extend(topic_results)
    
    # Sort all hits by score descending
    all_hits = sorted(all_hits, key=lambda x: x["score"], reverse=True)

    # Start with guaranteed top hits
    final_hits = guaranteed_hits.copy()
    remaining_slots = total_k - len(final_hits)
    
    # Fill remaining slots with highest scoring hits, avoiding duplicates
    for h in all_hits:
        if len(final_hits) >= total_k:
            break
        if h not in final_hits:
            final_hits.append(h)
    
    return final_hits[:total_k]


# # Example usage:
# if __name__ == "__main__":
#     topics = ["linear algebra", "quadratic equations", "functions"]
#     top_k = 5
#     hits = bm25_search_for_topics(topics, total_k=top_k)
    
#     for h in hits:
#         print(h)
