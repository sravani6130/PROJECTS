import subprocess
import uuid
import os

def save(md_string: str, output_file: str) -> str:
    extension = os.path.splitext(output_file)[1].lower()
    temp_md = f"temp_{uuid.uuid4().hex}.md"

    try:
        # Write markdown to temp file
        with open(temp_md, "w", encoding="utf-8") as f:
            f.write(md_string)

        # If output is Markdown → no conversion needed
        if extension == ".md":
            os.rename(temp_md, output_file)
            return f"✔ Saved markdown file as {output_file}"

        # Base command
        pandoc_cmd = [
            "pandoc",
            temp_md,
            "-o",
            output_file
        ]

        # If PDF → use xelatex + Unicode fonts
        if extension == ".pdf":
            pandoc_cmd += [
                "--pdf-engine=xelatex",
                "-V", "mainfont=DejaVu Serif",
                "-V", "sansfont=DejaVu Sans",
                "-V", "monofont=DejaVu Sans Mono"
            ]

        # Run pandoc
        subprocess.run(pandoc_cmd, check=True)

        return f"✔ Created: {output_file}"

    except subprocess.CalledProcessError as e:
        return f"❌ Pandoc failed: {e}"

    except Exception as e:
        return f"❌ Error: {e}"

    finally:
        # Delete temp md file only if it wasn't moved
        if os.path.exists(temp_md) and extension != ".md":
            os.remove(temp_md)
