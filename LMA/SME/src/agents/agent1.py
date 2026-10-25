import os
from typing import List, Literal
from pydantic import BaseModel, Field
from langchain.agents import create_agent
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.agents.structured_output import ToolStrategy
from typing import Optional

# ============================================================
# 1. STRUCTURED OUTPUT SCHEMA (Pydantic)
# ============================================================

class Agent1Output(BaseModel):
    topics: List[str] = Field(
        ..., 
        description="Pure academic topics extracted from the user request (e.g., 'Linear Equations')."
    )
    rag_prompt: str = Field(
        ..., 
        description="A clean academic query intended ONLY for retrieval—free from instructions about file creation, emailing, formatting, or task type."
    )
    task_type: Literal["quiz", "summary", "qa"] = Field(
        ..., 
        description="Type of task requested by the user: quiz generation, summary/report, or regular Q/A."
    )
    content_prompt: str = Field(
        ..., 
        description="The user's content-only instruction with all operational instructions (convert, email, format, send, export) removed. Purely what content needs to be generated"
    )
    output_format: Literal["chat", "pdf", "md", "pptx", "docx"] = Field(
        ..., 
        description="Desired output format. Default to 'chat' if the user does not specify one."
    )
    should_email: bool = Field(
        ..., 
        description="True if the user explicitly asks for email delivery."
    )
    email_address: Optional[str] = Field(
        None,
        description="The email address to send the output to, if should_email is True."
    )


# ============================================================
# 2. SYSTEM PROMPT WITH FEW-SHOT EXAMPLES
# ============================================================

SYSTEM_PROMPT1 = """
You are Agent 1 in a multi-agent Subject-Matter Expert (SME) system for **K–12 Algebra**.
Your ONLY job is to extract structured metadata from the user's request.

You must extract:

1. **topics**  
   - A list of clean K–12 Algebra concepts (e.g., "Linear equations", "Quadratic formula").  
   - Strip away anything unrelated to academic content (e.g., report, quiz, email).

2. **rag_prompt**  
   - A clean academic formulation of the topic(s).  
   - Should be suitable for retrieval from an Algebra knowledge base.  
   - MUST NOT include instructions about output format, quizzes, reports, email, or other meta-tasks.  
   - This is only about the *content itself*, e.g.,  
     "Explain the concept of solving simultaneous linear equations."  
     "Overview of algebraic identities used in factorization."

3. **task_type**  
   - Must be one of: "quiz", "summary", "qa"  
   - Classification rules:  
     • If user asks for test, quiz, MCQs → "quiz"  
     • If user asks for summary, notes, explanation, report → "summary"  
     • Otherwise → "qa"

4. **content_prompt**
    - The user's content-only instruction with all operational instructions (convert, email, format, send, export) removed.
    - Should not contain any instructions about output format, quizzes, reports, email, or other meta-tasks.
    - If the user input is related to converting or sending the previous output, set content_prompt to: "Give the exact assistant output from the previous step."
    
5. **output_format**  
   - Must be one of: ["chat", "pdf", "md", "pptx", "docx"]  
   - If user doesn't specify → "chat"

6. **should_email**  
   - True only if user *explicitly* asks to email.

7. **email_address**
    - Extract email address if should_email is True; otherwise, null.
   
Use the following examples as a guide:

[Example 1]
User: "Make a 10-question quiz on quadratic equations and give it as a PDF."
Output:
{
  "topics": ["quadratic equations"],
  "rag_prompt": "Key concepts, definitions, and problem types related to quadratic equations.",
  "task_type": "quiz",
  "content_prompt": "Make a 10-question quiz on quadratic equations.",
  "output_format": "pdf",
  "should_email": false,
  "email_address": null
}

[Example 2]
User: "Give me a detailed report on algebraic identities, especially (a+b)^2 and (a-b)^2."
Output:
{
  "topics": ["algebraic identities", "(a+b)^2", "(a-b)^2"],
  "rag_prompt": "Detailed explanation and examples of algebraic identities including (a+b)^2 and (a-b)^2.",
  "task_type": "summary",
  "content_prompt": "Give me a detailed report on algebraic identities, especially (a+b)^2 and (a-b)^2.",
  "output_format": "chat",
  "should_email": false,
  "email_address": null
}

[Example 3]
User: "Explain linear equations in one variable and email it to me at a@gmail.com"
Output:
{
  "topics": ["linear equations in one variable"],
  "rag_prompt": "Concept explanation and examples of solving linear equations in one variable.",
  "task_type": "summary",
  "content_prompt": "Explain linear equations in one variable.",
  "output_format": "chat",
  "should_email": true,
  "email_address": "a@gmail.com"
}

[Example 4]
User: "Give me notes on polynomials and also mail it to abc@gmail.com"
Output:
{
  "topics": ["Polynomials"]
  "rag_prompt": "Notes and explanation of polynomials."
  "content_prompt": "Give me notes on polynomials."
  "task_type": "summary"
  "output_format": "chat"
  "should_email": True
  "email_address": "abc@gmail.com"
}

[Exmaple 5]
User: "Convert the above to pptx and send it."
Output:
{
    "topics" = []
    "rag_prompt" = ""
    "content_prompt" = "Give the exact assistant output from the previous step."
    "task_type" = "qa"
}
"""


# ============================================================
# 3. BUILD THE MODEL
# ============================================================

gemini_model = ChatGoogleGenerativeAI(
    model="gemini-2.5-flash-lite",
    api_key=os.environ.get("GOOGLE_API_KEY"),
    temperature=0
)

agent1 = create_agent(
    model=gemini_model,
    tools=[],
    system_prompt= SYSTEM_PROMPT1,
    response_format=ToolStrategy(Agent1Output)
)


# ============================================================
# 4. FUNCTION: Run Agent 1
# ============================================================

def run_agent1(user_query: str) -> Agent1Output:
    response = agent1.invoke(
        {"messages": [{"role": "user", "content": user_query}]}
    )
    return response["structured_response"]

# ============================================================
# 5. TEST
# ============================================================

if __name__ == "__main__":
    user_query = input("Enter input: ")
    result = run_agent1(user_query)
    print(result)
