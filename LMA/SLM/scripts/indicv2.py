from datasets import load_dataset

dataset_name = "ai4bharat/IndicCorpV2"
config_name = "indiccorp_v2"
split_name = "tel_Telu"

# Load in streaming mode
ds = load_dataset(dataset_name, name=config_name, split=split_name, streaming=True)

output_path = "indiccorp_tel.txt"
with open(output_path, "w", encoding="utf-8") as f:
    for record in ds:
        text = record['text']
        if text:   # skip empty rows
            f.write(text + "\n")