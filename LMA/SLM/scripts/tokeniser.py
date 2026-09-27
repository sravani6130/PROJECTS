from tokenizers import Tokenizer, models, trainers, pre_tokenizers
import glob

files = glob.glob("./data/*.txt")  # all .txt files in the data directory

tokenizer = Tokenizer(models.BPE())
tokenizer.normalizer = None

tokenizer.pre_tokenizer = pre_tokenizers.Whitespace()  # split on whitespace

trainer = trainers.BpeTrainer(
    vocab_size=64000,            # 64k vocabulary
    min_frequency=4,          
    special_tokens=["<pad>", "<unk>", "<s>", "</s>"]
)

tokenizer.train(files, trainer)

tokenizer.save("multilingual_bpe_64k.json")