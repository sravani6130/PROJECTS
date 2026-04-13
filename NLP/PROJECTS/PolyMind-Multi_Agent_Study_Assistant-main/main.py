import sys
from utils.llm_client import LLMClient
from agents.mathagent import MathAgent
from agents.generalagent import GeneralAgent
from agents.codeagent import CodeAgent
from agents.formatteragent import FormatterAgent

def main():
    print("PolyMind Multi-Agent Study Assistant Initialized.")
    print("Enter your query (or 'exit' to quit):")

    llm = LLMClient()
    math_agent = MathAgent()
    general_agent = GeneralAgent()
    code_agent = CodeAgent()
    formatter_agent = FormatterAgent()

    while True:
        try:
            query = input("> ")
            if query.lower() in ['exit', 'quit']:
                break
            
            if not query.strip():
                continue

            # 1. Preprocessing (Spell Check / Correction)
            print("Preprocessing query...")
            preprocess_prompt = f"Correct the spelling and grammar of this query: '{query}'. Return only the corrected query."
            corrected_query = llm.get_response(preprocess_prompt, system_prompt="You are a spell checker.").strip()
            print(f"Corrected Query: {corrected_query}")

            # 2. Routing
            print("Routing query...")
            routing_prompt = f"Classify this query into one of these categories: MATH, CODE, GENERAL. Query: '{corrected_query}'. Return only the category name."
            category = llm.get_response(routing_prompt, system_prompt="You are a Router.").strip().upper()
            print(f"Category: {category}")

            # 3. Agent Execution
            response = ""
            if "MATH" in category:
                response = math_agent.process(corrected_query)
            elif "CODE" in category:
                response = code_agent.process(corrected_query)
            else:
                response = general_agent.process(corrected_query)

            # 4. Formatting
            formatted_response = formatter_agent.process(response)

            # 5. Output
            print("\n=== Response ===")
            print(formatted_response)
            print("================\n")

        except KeyboardInterrupt:
            print("\nExiting...")
            break
        except Exception as e:
            print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()