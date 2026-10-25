import os
import requests
import time

# Suggesting use of Gemini or OpenAI
API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent"
API_KEY = os.getenv("GEMINI_API_KEY", "YOUR_API_KEY")

prompt_template = """
You are an expert Java developer. Refactor the following code to resolve the design smell: {smell}.
The smell may involve one or multiple files. If it involves multiple files, they are provided below.
Maintain the original functionality perfectly.

If the refactoring involves creating new files or modifying multiple existing ones, output each file in its own block.

Output your response EXACTLY in this format:
---RATIONALE_START---
[3-4 bullet points explaining what was changed, why, and the resulting metrics]
---RATIONALE_END---

---FILE_START: [Filename or Path]---
[Refactored Java Code]
---FILE_END---

(Repeat the FILE blocks if multiple files are involved)

Code to refactor:
{code_blocks}
"""

def get_refactored_code(files_dict, smell_type, max_retries=3):
    """
    Sends multiple code files to Gemini API for refactoring and rationale.
    files_dict: { "path/to/File.java": "content", ... }
    """
    if API_KEY == "YOUR_API_KEY" or not API_KEY:
        return {"RefactoredFile.java": "// [MOCK] Refactored code"}, "- Simplified complexity."

    # Format code blocks for the prompt
    code_blocks = ""
    for filename, content in files_dict.items():
        code_blocks += f"\nFILE: {filename}\n```java\n{content}\n```\n"

    headers = {'Content-Type': 'application/json'}
    payload = {
        "contents": [{
            "parts": [{
                "text": prompt_template.format(smell=smell_type, code_blocks=code_blocks)
            }]
        }]
    }
    
    for attempt in range(max_retries):
        try:
            response = requests.post(f"{API_URL}?key={API_KEY}", json=payload, headers=headers)
            
            if response.status_code == 200:
                text = response.json()['candidates'][0]['content']['parts'][0]['text']
                
                # Parse files and rationale
                refactored_files = {}
                rationale = "No rationale provided."
                
                # Extract Rationale
                if "---RATIONALE_START---" in text and "---RATIONALE_END---" in text:
                    rationale = text.split("---RATIONALE_START---")[1].split("---RATIONALE_END---")[0].strip()
                
                # Extract Files
                file_blocks = text.split("---FILE_START:")
                for block in file_blocks[1:]: # Skip text before first block
                    if "---FILE_END---" in block:
                        parts = block.split("---FILE_END---")
                        header_and_code = parts[0].strip()
                        lines = header_and_code.split("\n")
                        filename = lines[0].replace("---", "").strip()
                        code = "\n".join(lines[1:]).strip()
                        refactored_files[filename] = code
                
                # Fallback if no specific file blocks but text is present
                if not refactored_files:
                    refactored_files["RefactoredResult.java"] = text 
                
                return refactored_files, rationale
            elif response.status_code == 429:
                # Rate limit hit, wait and retry
                wait_time = (attempt + 1) * 15 # Wait 15, 30, 45 seconds
                print(f"Rate limit hit (429). Waiting {wait_time} seconds before retry...")
                time.sleep(wait_time)
            else:
                return {}, f"Error: {response.status_code} - {response.text}"
        except Exception as e:
            print(f"Request failed: {e}")
            time.sleep(5)
            
    return {}, "Error: Maximum retries exceeded for refactoring."

def chunk_large_file(file_path):
    """
    Reads a file and returns it in manageable chunks for LLM context.
    For simplicity, this splits by method-like structures if the file is too large.
    """
    with open(file_path, 'r') as f:
        content = f.read()
    
    # If file is small, return as one chunk
    if len(content) < 4000:
        return [content]
    
    # Simple chunking by 100 lines for demonstration
    lines = content.split('\n')
    chunks = []
    for i in range(0, len(lines), 100):
        chunks.append('\n'.join(lines[i:i+100]))
    return chunks

if __name__ == "__main__":
    # Test with a mock snippet
    test_files = {"Test.java": "public void doEverything() { /* massive body */ }"}
    print(get_refactored_code(test_files, "Long Method"))
