from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional

from agents.agent1 import run_agent1
from agents.agent2 import run_agent2
from agents.agent3 import run_agent3
from agents.agent4 import run_agent4
from agents.agent5 import run_agent5
from tools.mail import send_email
from tools.convert import save
from logger import get_request_logger

from rag.reranked import hybrid_rerank

app = FastAPI(title="Multi-Agent Algebra SME API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],      # you can restrict later
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------
# Request & Response Models
# ---------------------------

class ChatRequest(BaseModel):
    user_input: str
    conversation_history: Optional[List[dict]] = None


class ChatResponse(BaseModel):
    final_output: str
    output_format: str
    should_email: bool
    email_status: Optional[str] = None
    updated_history: List[dict]


# ---------------------------
# Helper functions
# ---------------------------

def extract_pure_text(output):
    """Convert pydantic models or objects to plain string."""
    if isinstance(output, str):
        return output
    try:
        # Extract first textual field
        for v in output.__dict__.values():
            if isinstance(v, str):
                return v
    except:
        pass
    return str(output)


# ---------------------------
# Main Chat Endpoint
# ---------------------------

@app.post("/chat", response_model=ChatResponse)
def chat(request: ChatRequest):

    log = get_request_logger()
    log.info("REQUEST RECEIVED: %s", request.user_input)

    user_input = request.user_input
    conversation_history = request.conversation_history or []

    # Agent 1
    agent1_output = run_agent1(user_input)
    log.info("Agent 1 Output: %s", agent1_output)

    filtered_user_input = agent1_output.content_prompt
    md_report = None
    
    rag_outputs = hybrid_rerank(agent1_output.topics, agent1_output.rag_prompt, N=5)
    rag_output = "\n\n".join([item for item in rag_outputs])
    log.info("RAG Output: %s", rag_output[:200])

    # Content generation
    if agent1_output.task_type == "quiz":
        log.info("Invoking Agent 2 (Quiz Generator)")
        md_report = run_agent2(filtered_user_input, rag_output, conversation_history)

    elif agent1_output.task_type == "summary":
        log.info("Invoking Agent 3 (Report Generator)")
        md_report = run_agent3(filtered_user_input, rag_output, conversation_history)

    elif agent1_output.task_type == "qa":
        log.info("Invoking Agent 4 (QA)")
        md_report = run_agent4(filtered_user_input, rag_output, conversation_history)

    log.info("Intermediate content (md_report): %s", md_report)

    # Normalize to text
    pure_agent_text = extract_pure_text(md_report)
    log.info("Normalized content: %s", pure_agent_text[:200])  # preview first 200 chars

    final_output = None
    email_status = None

    # Formatting / file generation
    if agent1_output.output_format == "pptx":
        log.info("Invoking Agent 5 (PPTX Generator)")
        final_output = run_agent5(pure_agent_text)
        log.info("PPTX generated: %s", final_output)

    elif agent1_output.output_format in ["md", "pdf", "txt", "docx"]:
        output_file = f"output.{agent1_output.output_format}"
        log.info("Saving to file: %s", output_file)
        save(pure_agent_text, output_file)
        final_output = output_file

    else:
        final_output = pure_agent_text
        log.info("Output returned as chat text")

    # EMAIL
    if agent1_output.should_email:
        log.info("Email requested → sending to %s", agent1_output.email_address)
        attachments = []

        if agent1_output.output_format in ["pdf", "docx", "pptx", "txt", "md"]:
            attachments.append(final_output)

        email_status = send_email(
            agent1_output.email_address,
            "Your Requested Content",
            final_output if not attachments else "Please find the requested content attached.",
            attachments
        )
        final_output += f"\n\n ## {email_status}"
        log.info("Email status: %s", email_status)
        
    # Update history
    conversation_history.append({"role": "user", "content": user_input})
    conversation_history.append({"role": "assistant", "content": pure_agent_text})

    while len(conversation_history) > 6:
        conversation_history.pop(0)

    log.info("RESPONSE RETURNED")
    log.info("------------------------------------------------------------")

    return ChatResponse(
        final_output=final_output,
        output_format=agent1_output.output_format,
        should_email=agent1_output.should_email,
        email_status=email_status,
        updated_history=conversation_history
    )
