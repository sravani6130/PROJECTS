from datasets import load_dataset, DownloadConfig

download_config = DownloadConfig(120)  # timeout in seconds
dataset = load_dataset("HuggingFaceFW/fineweb", split="train", streaming=True, download_config=download_config)

output_path = "fineweb_english.txt"
word_limit = 2_000_000_000
word_count = 0
sample_count = 0

try:
    with open(output_path, "w", encoding="utf-8") as f:
        for sample in dataset:
            text = sample["text"]
            words = len(text.split())
            word_count += words
            f.write(text + "\n")
            sample_count += 1
            if sample_count % 1_000_000 == 0:
                print(f"Saved {sample_count} samples, {word_count} words...")
            if word_count >= word_limit:
                print(f"Reached {word_count} words at {sample_count} samples.")
                break
    print(f"Done! Total samples saved: {sample_count}, total words: {word_count}")
except Exception as e:
    print(f"Error: {e}")