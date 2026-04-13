from utils.llm_client import LLMClient
from utils.tools import Tools

class GeneralAgent:
    def __init__(self):
        self.llm = LLMClient()

    def process(self, query):
        print(f"General Agent processing: {query}")
        
        # Prompt 1: Planning
        plan_prompt = f"Plan the task for this general query: {query}. You have access to web search. Return a step-by-step plan."
        plan = self.llm.get_response(plan_prompt, system_prompt="You are a General Agent Planner.")
        print(f"Plan: {plan}")

        # CoT Loop
        context = f"Query: {query}\nPlan: {plan}\n"
        max_steps = 5
        for i in range(max_steps):
            step_prompt = f"{context}\nBased on the plan, what is the next step? If you need to search, output 'SEARCH: <query>'. If you have the final answer, output 'FINAL ANSWER: <answer>'."
            response = self.llm.get_response(step_prompt, system_prompt="You are a General Agent Executor.")
            print(f"Step {i+1}: {response}")

            if "FINAL ANSWER:" in response:
                return response.split("FINAL ANSWER:")[1].strip()
            
            if "SEARCH:" in response:
                search_query = response.split("SEARCH:")[1].strip()
                result = Tools.web_search(search_query)
                context += f"\nAction: Searched {search_query}\nResult: {result}\n"
            else:
                context += f"\nThought: {response}\n"
        
        return "Could not find answer within step limit."