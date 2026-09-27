
from datasets import load_dataset
import json

# Download the 'tel_Telu' split from the 'fineweb-2' dataset
dataset = load_dataset("HuggingFaceFW/fineweb-2", "tel_Telu")

# Save the dataset to a local file in JSONL format
output_file = "fineweb_telugu.jsonl"
with open(output_file, "w", encoding="utf-8") as f:
	for item in dataset["train"]:
		f.write(json.dumps(item, ensure_ascii=False) + "\n")

print(f"Saved {len(dataset['train'])} samples to {output_file}")