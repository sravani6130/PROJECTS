from utils.llm_client import LLMClient
from utils.tools import Tools
import re

class MathAgent:
    def __init__(self):
        self.llm = LLMClient()

    def process(self, query):
        print(f"Math Agent processing: {query}")
        
        # Prompt 1: Planning
        plan_prompt = f"Plan the task for this math query: {query}. You have access to a calculator. Return a step-by-step plan."
        plan = self.llm.get_response(plan_prompt, system_prompt="You are a Math Agent Planner.")
        print(f"Plan: {plan}")

        # CoT Loop
        context = f"Query: {query}\nPlan: {plan}\n"
        max_steps = 5
        for i in range(max_steps):
            step_prompt = f"{context}\nBased on the plan, what is the next step? If you need to calculate something, output 'CALCULATE: <expression>'. If you have the final answer, output 'FINAL ANSWER: <answer>'."
            response = self.llm.get_response(step_prompt, system_prompt="You are a Math Agent Executor.")
            print(f"Step {i+1}: {response}")

            if "FINAL ANSWER:" in response:
                return response.split("FINAL ANSWER:")[1].strip()
            
            if "CALCULATE:" in response:
                expression = response.split("CALCULATE:")[1].strip()
                result = Tools.calculate(expression)
                context += f"\nAction: Calculated {expression}\nResult: {result}\n"
            else:
                context += f"\nThought: {response}\n"
        
        return "Could not solve within step limit."