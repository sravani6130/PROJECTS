import os
from typing import List, Literal
from pydantic import BaseModel, Field
from langchain.agents import create_agent
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.agents.structured_output import ToolStrategy
from rag.retrieve import retrieve
from typing import List
from pydantic import BaseModel, Field

class QuizContent(BaseModel):
    question: str = Field(
        ...,
        description="The quiz question text"
    )
    options: List[str] = Field(
        ...,
        description="List of four answer options"
    )
    correct_answer: str = Field(
        ...,
        description="The correct answer option"
    )

class Agent2Output(BaseModel):
    questions: List[QuizContent] = Field(
        ...,
        description="A list of quiz questions with options and correct answers"
    )
    
def quiz_to_markdown(agent_output: Agent2Output) -> str:
    """
    Convert Agent2Output (list of quiz questions) into a Markdown string.
    """

    md_lines = []

    for i, q in enumerate(agent_output.questions, 1):
        md_lines.append(f"### Q{i}. {q.question}\n")

        # List options as A, B, C, D...
        option_labels = ["A", "B", "C", "D"]
        for label, option in zip(option_labels, q.options):
            md_lines.append(f"- **{label})** {option}")

        md_lines.append("")  # blank line

        # Correct answer
        # Determine correct label if the correct answer text matches an option
        if q.correct_answer in q.options:
            idx = q.options.index(q.correct_answer)
            correct_label = option_labels[idx]
            md_lines.append(f"**Correct Answer:** {correct_label}) {q.correct_answer}\n")
        else:
            # Fallback (shouldn't happen)
            md_lines.append(f"**Correct Answer:** {q.correct_answer}\n")

    return "\n".join(md_lines)

SYSTEM_PROMPT = """
Your task is to generate quiz questions strictly aligned with K12 algebraic concepts.

Your responsibilities are:
Determine how many questions the user wants. If the user does not specify a number, produce five questions by default.
Produce a list of well formed QuizContent objects.
Each QuizContent contains a clear question, four options, and one correct answer.
All questions must be unambiguous, grade appropriate, and directly related to the user prompt.
Do not include explanations or reasoning in the output.
Output must strictly follow the Agent2Output structure.

Guidelines for generating the quiz:
Questions must test understanding of algebraic expressions, linear equations, inequalities, functions, operations with variables, coordinate geometry, or other K12 algebra topics.
Questions must be concise and concept focused.
Options must be distinct and plausible.
Correct answer must be one of the options and must be exact.

Expected output format:
Agent2Output with a list of QuizContent items.

Few shot example:

User Prompt:
Generate a quiz  practice questions on simplifying expressions.

Output:
{
  "questions": [
    {
      "question": "What is the simplified form of 3x plus 5x",
      "options": ["5x", "8x", "15x", "3x minus 5x"],
      "correct_answer": "8x"
    },
    {
      "question": "What is the simplified form of 4y minus 2y plus y",
      "options": ["3y", "2y", "4y", "5y"],
      "correct_answer": "3y"
    }
  ]
}
"""


# ============================================================
# 3. BUILD THE MODEL
# ============================================================

gemini_model = ChatGoogleGenerativeAI(
    model="gemini-2.5-flash-lite",
    api_key="AIzaSyBogQ6dec87gt1dr2mPej0IO1D9elr8H70",
    temperature=0
)

agent2 = create_agent(
    model=gemini_model,
    tools=[],
    system_prompt= SYSTEM_PROMPT,
    response_format=ToolStrategy(Agent2Output)
)

# ============================================================
# 4. FUNCTION: Run Quiz Agent with rag_input and user_prompt
# ============================================================

def run_agent2(user_prompt: str, rag_output: list[str], conversation_history) -> str:
    context = "\n\n".join(rag_output)
    prompt = (
        f"Request: {user_prompt}\n\n"
        f"Context:\n{context}\n\n"
    )    
    conversation_history.append({"role": "user", "content": prompt})
    response = agent2.invoke({"messages": conversation_history})
    quiz = response["structured_response"]
    return quiz_to_markdown(quiz)


# ============================================================
# 5. TEST
# ============================================================

if __name__ == "__main__":
    user_prompt = "Create a quiz with 10 questions on solving linear equations."
    rag_output = retrieve(user_prompt, k=5)
    result = run_agent2(user_prompt, rag_output)
    print(result)