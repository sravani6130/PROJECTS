import sys
from pathlib import Path
from marker.convert import convert_single_pdf, convert_single_docx, convert_single_pptx

def convert_to_markdown(input_path):
    """
    Converts a file (PDF, DOCX, PPTX, TXT, or MD) to Markdown using the `marker` library.
    Returns the converted Markdown text.
    """
    input_path = Path(input_path)
    if not input_path.exists():
        raise FileNotFoundError(f"File not found: {input_path}")

    ext = input_path.suffix.lower()

    if ext == ".pdf":
        print("Converting PDF to Markdown...")
        result = convert_single_pdf(str(input_path))
        return result.markdown_text

    elif ext == ".docx":
        print("Converting DOCX to Markdown...")
        result = convert_single_docx(str(input_path))
        return result.markdown_text

    elif ext == ".pptx":
        print("Converting PPTX to Markdown...")
        result = convert_single_pptx(str(input_path))
        return result.markdown_text

    elif ext == ".txt":
        print("Converting TXT → Markdown (simple copy)...")
        return input_path.read_text(encoding="utf-8")

    elif ext == ".md":
        print("File is already Markdown.")
        return input_path.read_text(encoding="utf-8")

    else:
        raise ValueError(f"Unsupported file type: {ext}")

def save_markdown(markdown_text, output_path):
    """Saves Markdown text to a file."""
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(markdown_text)
    print(f"✅ Markdown saved to: {output_path}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python format.py <input_file>")
        sys.exit(1)

    input_file = Path(sys.argv[1])
    md_text = convert_to_markdown(input_file)
    output_file = input_file.with_suffix(".md")
    save_markdown(md_text, output_file)
