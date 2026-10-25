import os
from typing import List, Literal
from pydantic import BaseModel, Field
from langchain.agents import create_agent
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.agents.structured_output import ToolStrategy
from rag.retrieve import retrieve

class Agent4Output(BaseModel):
    response: str = Field(
        ..., 
        description="A clear and concise answer to the user's question."
    )

SYSTEM_PROMPT4 = """
You are a helpful assistant specialized in K12 Algebra.
Answer user questions clearly, accurately, and concisely.
Focus only on algebraic concepts relevant to K12 education and if user grade is known, respond at that level.
Use retrieved context if relevant to user query.
Do not include unnecessary explanations or unrelated information.
Respond directly to the user query in a straightforward manner. Be brief, clear, and to the point.
Make sure to use the conversation history to maintain context.
If asked for exact previous answers, refer to the conversation history and provide them accurately.
Strictly don't answer anything outside of K12 Algebra.
Example:
What are computer networks?
Answer: I'm sorry, but I can only assist with questions related to K12 Algebra.
What is quantum physics?
Answer: I'm sorry, but I can only assist with questions related to K12 Algebra.
"""

# ============================================================
# BUILD GEMINI MODEL
# ============================================================

gemini_model = ChatGoogleGenerativeAI(
    model="gemini-2.5-flash-lite",
    api_key="AIzaSyBogQ6dec87gt1dr2mPej0IO1D9elr8H70",
    max_output_tokens=4096
)

agent4 = create_agent(
    model=gemini_model,
    system_prompt= SYSTEM_PROMPT4,
    response_format=ToolStrategy(Agent4Output)
)

def run_agent4(user_request: str, rag_output: list[str], conversation_history) -> str:
    context = "\n\n".join(rag_output)

    prompt = (
        f"Request: {user_request}\n\n"
        f"Context:\n{context}\n\n"
    )
    
    conversation_history.append({"role": "user", "content": prompt})

    result = agent4.invoke({"messages": conversation_history})
    return result["structured_response"].response
    
    

# ============================================================
# TEST AGENT 4
if __name__ == "__main__":
    user_request = "Give the exact assistant output from the previous step"
    rag_prompt = "Give the exact assistant output from the previous step."
    rag_output = retrieve(user_request, k=1)
    print("Retrieved Context Chunks")
    
    conversation_history = [{"role": "user", "content": "What are quadratic equations?"}, 
                            {"role": "assistant", "content": "Quadratic equations are polynomial equations of the form ax^2 + bx + c = 0, where a, b, and c are constants and a ≠ 0."}]
    
    response = run_agent4(user_request, rag_output, conversation_history).response
    print(response)  
