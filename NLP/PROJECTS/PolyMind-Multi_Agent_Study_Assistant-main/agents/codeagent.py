from utils.llm_client import LLMClient
from utils.tools import Tools
from utils.mcts import MCTS

class CodeAgent:
    def __init__(self):
        self.llm = LLMClient()
        self.mcts = MCTS(self.llm)

    def process(self, query):
        print(f"Code Agent processing: {query}")
        
        # Use MCTS for planning
        print("Running MCTS for planning...")
        best_plan = self.mcts.search(initial_state=query)
        print(f"Best Plan from MCTS: {best_plan}")

        # Execution Loop
        context = f"Query: {query}\nPlan: {best_plan}\n"
        max_steps = 5
        for i in range(max_steps):
            step_prompt = f"{context}\nBased on the plan, what is the next step? If you need to write code, output 'WRITE: <filename>\\n<content>'. If you need to run code, output 'RUN: <filename>'. If you have the final answer, output 'FINAL ANSWER: <answer>'."
            response = self.llm.get_response(step_prompt, system_prompt="You are a Code Agent Executor.")
            print(f"Step {i+1}: {response}")

            if "FINAL ANSWER:" in response:
                return response.split("FINAL ANSWER:")[1].strip()
            
            if "WRITE:" in response:
                parts = response.split("WRITE:")[1].strip().split("\n", 1)
                if len(parts) == 2:
                    filename = parts[0].strip()
                    content = parts[1].strip()
                    result = Tools.write_file(filename, content)
                    context += f"\nAction: Wrote {filename}\nResult: {result}\n"
                else:
                    context += "\nError: Invalid WRITE format\n"
            elif "RUN:" in response:
                filename = response.split("RUN:")[1].strip()
                result = Tools.run_file(filename)
                context += f"\nAction: Ran {filename}\nResult: {result}\n"
            else:
                context += f"\nThought: {response}\n"
        
        return "Could not complete coding task within step limit."
