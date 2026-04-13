import os
import requests
import json

class LLMClient:
    def __init__(self, api_key=None):
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        if not self.api_key:
            # Try loading from .env manually if not in env
            try:
                with open('.env', 'r') as f:
                    for line in f:
                        if line.startswith("GEMINI_API_KEY"):
                            self.api_key = line.split("=")[1].strip().strip('"')
                            break
            except:
                pass
        
        if not self.api_key:
            print("Warning: GEMINI_API_KEY not found.")

        self.base_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent"

    def get_response(self, prompt, system_prompt=None):
        if not self.api_key:
            return "Error: API Key missing."

        headers = {
            "Content-Type": "application/json"
        }
        
        data = {
            "contents": [{
                "parts": [{"text": prompt}]
            }]
        }

        if system_prompt:
            data["systemInstruction"] = {
                "parts": [{"text": system_prompt}]
            }

        import time
        max_retries = 5
        for attempt in range(max_retries):
            try:
                response = requests.post(
                    f"{self.base_url}?key={self.api_key}",
                    headers=headers,
                    json=data
                )
                response.raise_for_status()
                result = response.json()
                
                # Parse response
                if "candidates" in result and result["candidates"]:
                    return result["candidates"][0]["content"]["parts"][0]["text"].strip()
                else:
                    return "Error: No content in response."
                    
            except requests.exceptions.HTTPError as e:
                if e.response.status_code == 429:
                    if attempt < max_retries - 1:
                        wait_time = (2 ** attempt) + 1  # Exponential backoff: 2s, 3s, 5s, 9s...
                        print(f"Rate limit hit. Retrying in {wait_time}s...")
                        time.sleep(wait_time)
                        continue
                return f"Error calling Gemini API: {str(e)}"
            except Exception as e:
                return f"Error calling Gemini API: {str(e)}"

    def get_json_response(self, prompt):
        # Not strictly used in current flow but good to have
        response = self.get_response(prompt + "\nReturn JSON only.")
        try:
            # clean markdown code blocks if present
            if "```json" in response:
                response = response.split("```json")[1].split("```")[0]
            elif "```" in response:
                response = response.split("```")[1].split("```")[0]
            return json.loads(response)
        except:
            return {}
