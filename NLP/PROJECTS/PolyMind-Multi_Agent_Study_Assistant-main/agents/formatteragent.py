class FormatterAgent:
    def process(self, response):
        print("Formatter Agent processing response...")
        
        # Basic formatting checks
        formatted_response = response.strip()
        
        # Ensure it starts with a capital letter (basic check)
        if formatted_response and formatted_response[0].islower():
            formatted_response = formatted_response[0].upper() + formatted_response[1:]
            
        # Check for markdown code blocks if it looks like code
        if "def " in formatted_response or "import " in formatted_response:
            if "```" not in formatted_response:
                formatted_response = f"```python\n{formatted_response}\n```"
        
        return formatted_response