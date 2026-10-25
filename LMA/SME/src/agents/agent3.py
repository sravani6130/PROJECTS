import os
from typing import List, Literal
from pydantic import BaseModel, Field
from langchain.agents import create_agent
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.agents.structured_output import ToolStrategy
from rag.retrieve import retrieve

class Agent3Output(BaseModel):
    report_markdown: str = Field(
        ..., 
        description="A comprehensive academic report in Markdown format covering the requested topic(s)."
    )


SYSTEM_PROMPT3 = """
You are Agent 3 in a multi-agent system for K–12 Algebra.
Your job is to generate a **high-quality, very detailed academic report in Markdown**.

===============================================================
### REPORT STRUCTURE (Markdown)
===============================================================

Your Markdown MUST include:

## 1. Title
## 2. Table of Contents
## 3. Introduction
## 4. Detailed Explanations
### Definitions
### Properties
### Rules & Theorems
### Step-by-step methods
### Worked Examples
### Common Mistakes

## 5. Real-world Applications
## 6. Practice Problems (≥ 10, NOT MCQs)
## 7. Summary / Key Takeaways
"""


# ============================================================
# BUILD GEMINI MODEL
# ============================================================

gemini_model = ChatGoogleGenerativeAI(
    model="gemini-2.5-flash-lite",
    api_key=os.environ.get("GOOGLE_API_KEY"),
    max_output_tokens=4096
)

agent3 = create_agent(
    model=gemini_model,
    system_prompt= SYSTEM_PROMPT3,
    response_format=ToolStrategy(Agent3Output)
)

def run_agent3(user_request: str, rag_output: list[str], conversation_history) -> str:
    context = "\n\n".join(rag_output)

    prompt = (
        f"Request: {user_request}\n\n"
        f"Context:\n{context}\n\n"
    )
    
    conversation_history.append({"role": "user", "content": prompt})
    response = agent3.invoke({"messages": conversation_history})
    return response["structured_response"].report_markdown
    

# ============================================================
# TEST AGENT 3
if __name__ == "__main__":
    user_request = "Provide a report on quadratic equations."
    rag_prompt = "Explanation, properties, methods, examples, and applications of quadratic equations."
    rag_output = retrieve(user_request, k=5)
    print("Retrieved Context Chunks")
    
    report = run_agent3(user_request, rag_output).report_markdown
    print(report)  