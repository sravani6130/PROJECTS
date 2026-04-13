import subprocess
import math

class Tools:
    @staticmethod
    def calculate(expression):
        """
        Evaluates a mathematical expression safely.
        """
        try:
            # Using eval with limited scope for safety
            allowed_names = {"math": math, "sqrt": math.sqrt, "pow": math.pow, "abs": abs}
            code = compile(expression, "<string>", "eval")
            for name in code.co_names:
                if name not in allowed_names:
                    raise NameError(f"Use of {name} is not allowed")
            return eval(code, {"__builtins__": {}}, allowed_names)
        except Exception as e:
            return f"Error calculating {expression}: {str(e)}"

    @staticmethod
    def web_search(query):
        """
        Mock web search function.
        """
        print(f"[Tool] Searching web for: {query}")
        return f"Search results for {query}: [Mock Result 1], [Mock Result 2]"

    @staticmethod
    def write_file(path, content):
        """
        Writes content to a file.
        """
        try:
            with open(path, 'w') as f:
                f.write(content)
            return f"Successfully wrote to {path}"
        except Exception as e:
            return f"Error writing file: {str(e)}"

    @staticmethod
    def run_file(path):
        """
        Runs a python file and returns stdout/stderr.
        """
        try:
            result = subprocess.run(['python3', path], capture_output=True, text=True, timeout=10)
            return f"Output:\n{result.stdout}\nErrors:\n{result.stderr}"
        except Exception as e:
            return f"Error running file: {str(e)}"
