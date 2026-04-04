'''
python pos_tagger.py \
    --embedding-type fasttext \
    --embedding-path /ssd_scratch/saiteja/inlp/wiki-news-300d-1M-subword.vec \
    --num-epochs 20

python pos_tagger.py \
    --embedding-type svd \
    --embedding-path /home2/saiteja3000/inlp/A-2/embeddings/svd.pt \
    --num-epochs 20

python pos_tagger.py \
    --embedding-type cbow \
    --embedding-path /home2/saiteja3000/inlp/A-2/embeddings/cbow.pt \
    --num-epochs 20


'''


import torch
import torch.nn as nn
import torch.optim as optim
import numpy as np,random
import argparse
import os
from tqdm import tqdm
from collections import Counter
from nltk.corpus import brown
import nltk, re
from torch.utils.data import Dataset, DataLoader
random.seed(42)
torch.manual_seed(42)
np.random.seed(42)


class POSTaggerMLP(nn.Module):
    __doc__ = "MLP-based POS tagger with sliding window context."

    def __init__(self, vocab_size, embedding_dim, context_size, hidden_dim1, hidden_dim2, num_tags, dropout=0.3):
        """
        Args:
            vocab_size: Size of vocabulary
            embedding_dim: Dimension of word embeddings
            context_size: Size of context window on each side (C)
            hidden_dim1: Dimension of first hidden layer
            hidden_dim2: Dimension of second hidden layer
            num_tags: Number of POS tags
            dropout: Dropout rate
        """
        super(POSTaggerMLP, self).__init__()
        self.context_size = context_size
        self.embedding_dim = embedding_dim
        self.embedding = nn.Embedding(vocab_size, embedding_dim, padding_idx=0)
        input_dim = (2 * context_size + 1) * embedding_dim
        self.fc1 = nn.Linear(input_dim, hidden_dim1)
        self.relu1 = nn.ReLU()
        self.dropout1 = nn.Dropout(dropout)
        self.fc2 = nn.Linear(hidden_dim1, hidden_dim2)
        self.relu2 = nn.ReLU()
        self.dropout2 = nn.Dropout(dropout)
        self.fc_out = nn.Linear(hidden_dim2, num_tags)

    def forward(self, context_indices):
        """
        Args:
            context_indices: Tensor of shape (batch_size, 2*context_size+1)
        
        Returns:
            logits: Tensor of shape (batch_size, num_tags)
        """
        embeddings = self.embedding(context_indices)
        concat_embeddings = embeddings.view(embeddings.size(0), -1)
        hidden1 = self.dropout1(self.relu1(self.fc1(concat_embeddings)))
        hidden2 = self.dropout2(self.relu2(self.fc2(hidden1)))
        logits = self.fc_out(hidden2)
        return logits

    def load_pretrained_embeddings(self, pretrained_embeddings, word2idx):
        """Load pretrained embeddings into the embedding layer."""
        with torch.no_grad():
            for word, idx in word2idx.items():
                if word in pretrained_embeddings:
                    self.embedding.weight[idx] = torch.FloatTensor(pretrained_embeddings[word])




class POSDataset(Dataset):
    __doc__ = "Dataset for POS tagging with sliding window context."

    def __init__(self, tagged_sents, word2idx, tag2idx, context_size=1):
        """
        Args:
            tagged_sents: List of sentences, each sentence is a list of (word, tag) tuples
            word2idx: Dictionary mapping words to indices
            tag2idx: Dictionary mapping tags to indices
            context_size: Size of context window on each side (C)
        """
        self.word2idx = word2idx
        self.tag2idx = tag2idx
        self.context_size = context_size
        self.pad_idx = word2idx["<PAD>"]
        self.unk_idx = word2idx["<UNK>"]
        self.examples = []
        for sent in tagged_sents:
            words = [word.lower() for word, _ in sent]
            tags = [tag for _, tag in sent]
            padded_words = [
             "<PAD>"] * context_size + words + ["<PAD>"] * context_size
            for i in range(len(words)):
                center_idx = i + context_size
                context_words = padded_words[center_idx - context_size:center_idx + context_size + 1]
                context_indices = [self.word2idx.get(w, self.unk_idx) for w in context_words]
                tag_idx = self.tag2idx[tags[i]]
                self.examples.append((context_indices, tag_idx))

    def __len__(self):
        return len(self.examples)

    def __getitem__(self, idx):
        context_indices, tag_idx = self.examples[idx]
        return (torch.LongTensor(context_indices), torch.LongTensor([tag_idx]))



def load_pos_brown_data(train_split=0.8, val_split=0.1):
    tagged_sents = brown.tagged_sents(tagset="universal")
    tagged_sents = list(tagged_sents)
    random.shuffle(tagged_sents)
    total_size = len(tagged_sents)
    print(f"Total sentences: {total_size}")
    train_size = int(total_size * train_split)
    val_size = int(total_size * val_split)
    test_size = total_size - train_size - val_size
    train_data = tagged_sents[:train_size]
    val_data = tagged_sents[train_size:train_size + val_size]
    test_data = tagged_sents[train_size + val_size:]
    return (
     train_data, val_data, test_data)

def build_vocab_and_tags(train_data, min_freq=2):
    """Build vocabulary and tag mappings from training data."""
    word_counts = Counter()
    tag_counts = Counter()
    for sent in train_data:
        for word, tag in sent:
            word_counts[word.lower()] += 1
            tag_counts[tag] += 1
    word2idx = {'<PAD>':0, 
                '<UNK>':1}
    idx2word = {0:"<PAD>",  1:"<UNK>"}
    idx = 2
    for word, count in word_counts.items():
        if count >= min_freq:
            word2idx[word] = idx
            idx2word[idx] = word
            idx += 1
            
    tag2idx = {}
    idx2tag = {}
    for idx, tag in enumerate(sorted(tag_counts.keys())):
        tag2idx[tag] = idx
        idx2tag[idx] = tag
        
    print(f"Vocabulary size: {len(word2idx)}")
    print(f"Number of tags: {len(tag2idx)}")
    print(f"Tags: {list(tag2idx.keys())}")
    return (
        word2idx, idx2word, tag2idx, idx2tag)

def train_epoch(model, dataloader, criterion, optimizer, device):
    """Train for one epoch."""
    model.train()
    total_loss = 0
    correct = 0
    total = 0
    for context_indices, tags in tqdm(dataloader, desc="Training", leave=False):
        context_indices = context_indices.to(device)
        tags = tags.squeeze(1).to(device)
        optimizer.zero_grad()
        logits = model(context_indices)
        loss = criterion(logits, tags)
        loss.backward()
        optimizer.step()
        predictions = torch.argmax(logits, dim=1)
        correct += (predictions == tags).sum().item()
        total += tags.size(0)
        total_loss += loss.item()
    avg_loss = total_loss / len(dataloader)
    accuracy = correct / total
    return (avg_loss, accuracy)

def evaluate(model, dataloader, criterion, device):
    """Evaluate model on validation/test set."""
    model.eval()
    total_loss = 0
    correct = 0
    total = 0
    with torch.no_grad():
        for context_indices, tags in tqdm(dataloader, desc="Evaluating", leave=False):
            context_indices = context_indices.to(device)
            tags = tags.squeeze(1).to(device)
            logits = model(context_indices)
            loss = criterion(logits, tags)
            predictions = torch.argmax(logits, dim=1)
            correct += (predictions == tags).sum().item()
            total += tags.size(0)
            total_loss += loss.item()

    avg_loss = total_loss / len(dataloader)
    accuracy = correct / total
    return (avg_loss, accuracy)


MODEL_OUTPUT_DIR = 'pos_tagger_models'


def load_svd_embeddings(embeddings_path='embeddings/svd.pt'):
    """Load SVD embeddings from saved file."""
    print(f"Loading SVD embeddings from {embeddings_path}...")
    data = torch.load(embeddings_path)
    embeddings = data['embeddings']
    vocab = data['vocab']
    idx2word = data['idx2word']
    
    print(f"  Loaded {embeddings.shape[0]} words with {embeddings.shape[1]} dimensions")
    return embeddings, vocab, idx2word


def load_cbow_embeddings(embeddings_path='embeddings/cbow.pt'):
    """Load CBOW/Word2Vec embeddings from saved file."""
    print(f"Loading CBOW embeddings from {embeddings_path}...")
    data = torch.load(embeddings_path)
    embeddings = data['embeddings']
    vocab = data['vocab']
    idx2word = data['idx2word']
    
    print(f"  Loaded {embeddings.shape[0]} words with {embeddings.shape[1]} dimensions")
    return embeddings, vocab, idx2word


def load_glove_embeddings(glove_path='glove.6B.100d.txt', vocab_size=None):
    """
    Load pretrained GloVe embeddings.
    
    Args:
        glove_path: Path to GloVe file
        vocab_size: Optional limit on vocabulary size
    
    Returns:
        embeddings: Tensor of embeddings
        vocab: Dictionary mapping words to indices
        idx2word: Dictionary mapping indices to words
    """
    print(f"Loading GloVe embeddings from {glove_path}...")
    
    embeddings_list = []
    vocab = {}
    idx2word = {}
    
    with open(glove_path, 'r', encoding='utf-8') as f:
        for idx, line in enumerate(tqdm(f, desc="Loading GloVe")):
            if vocab_size and idx >= vocab_size:
                break
            
            values = line.strip().split()
            word = values[0]
            vector = np.array(values[1:], dtype='float32')
            
            vocab[word] = idx
            idx2word[idx] = word
            embeddings_list.append(vector)
    
    embeddings = torch.tensor(np.array(embeddings_list), dtype=torch.float32)
    print(f"  Loaded {embeddings.shape[0]} words with {embeddings.shape[1]} dimensions")
    
    return embeddings, vocab, idx2word


def load_fasttext_embeddings(fasttext_path='wiki-news-300d-1M-subword.vec', vocab_size=None):
    """
    Load pretrained fastText embeddings.
    
    Args:
        fasttext_path: Path to fastText .vec file
        vocab_size: Optional limit on vocabulary size
    
    Returns:
        embeddings: Tensor of embeddings
        vocab: Dictionary mapping words to indices
        idx2word: Dictionary mapping indices to words
        
    Note: fastText .vec files have a header line with vocab_size and dim
    """
    print(f"Loading fastText embeddings from {fasttext_path}...")
    
    embeddings_list = []
    vocab = {}
    idx2word = {}
    
    with open(fasttext_path, 'r', encoding='utf-8', newline='\n', errors='ignore') as fin:
        # Read the header line (contains vocab_size and dimension)
        n, d = map(int, fin.readline().split())
        print(f"  fastText file contains {n} words with {d} dimensions")
        
        idx = 0
        for line in tqdm(fin, desc="Loading fastText", total=n if not vocab_size else min(n, vocab_size)):
            if vocab_size and idx >= vocab_size:
                break
            
            tokens = line.rstrip().split(' ')
            word = tokens[0]
            vector = np.array(tokens[1:], dtype='float32')
            
            vocab[word] = idx
            idx2word[idx] = word
            embeddings_list.append(vector)
            idx += 1
    
    embeddings = torch.tensor(np.array(embeddings_list), dtype=torch.float32)
    print(f"  Loaded {embeddings.shape[0]} words with {embeddings.shape[1]} dimensions")
    
    return embeddings, vocab, idx2word


def create_aligned_embeddings(pretrained_embeddings, pretrained_vocab, pos_word2idx, embedding_dim):
    """
    Create embedding matrix aligned with POS tagger vocabulary.
    
    Args:
        pretrained_embeddings: Pretrained embedding tensor
        pretrained_vocab: Vocabulary from pretrained embeddings
        pos_word2idx: Vocabulary from POS tagger
        embedding_dim: Dimension of embeddings
    
    Returns:
        aligned_embeddings: Tensor of shape (len(pos_word2idx), embedding_dim)
        num_found: Number of words found in pretrained embeddings
    """
    aligned = torch.randn(len(pos_word2idx), embedding_dim) * 0.01
    num_found = 0
    
    # Special tokens are initialized randomly
    # <PAD> at index 0
    aligned[0] = torch.zeros(embedding_dim)
    
    # Align pretrained embeddings with POS vocabulary
    for word, idx in pos_word2idx.items():
        if word in pretrained_vocab:
            pretrained_idx = pretrained_vocab[word]
            aligned[idx] = pretrained_embeddings[pretrained_idx]
            num_found += 1
    
    print(f"  Found {num_found}/{len(pos_word2idx)} words in pretrained embeddings")
    print(f"  Coverage: {num_found/len(pos_word2idx)*100:.2f}%")
    
    return aligned, num_found


def initialize_model_with_embeddings(model, aligned_embeddings, freeze_embeddings=False):
    """
    Initialize model's embedding layer with pretrained embeddings.
    
    Args:
        model: POSTaggerMLP model
        aligned_embeddings: Tensor of aligned embeddings
        freeze_embeddings: Whether to freeze embeddings during training
    """
    with torch.no_grad():
        model.embedding.weight.copy_(aligned_embeddings)
    
    if freeze_embeddings:
        model.embedding.weight.requires_grad = False
        print("  Embeddings are FROZEN (will not be updated during training)")
    else:
        model.embedding.weight.requires_grad = True
        print("  Embeddings will be FINE-TUNED during training")


def train_pos_tagger(
    embedding_type='scratch',
    freeze_embeddings=False,
    embedding_path=None,
    context_size=2,
    embedding_dim=100,
    hidden_dim1=256,
    hidden_dim2=128,
    batch_size=128,
    learning_rate=0.001,
    num_epochs=20,
    dropout=0.3,
    min_freq=2,
    device='cpu'
):
    """
    Train POS tagger with specified embedding initialization.
    
    Args:
        embedding_type: 'scratch', 'svd', 'cbow', or 'glove'
        freeze_embeddings: Whether to freeze embeddings during training
        embedding_path: Path to embedding file (if applicable)
        ... other hyperparameters
    """
    print("="*70)
    print(f"TRAINING POS TAGGER WITH {embedding_type.upper()} EMBEDDINGS")
    print("="*70)
    
    
    # Load data
    print("\nLoading Brown corpus...")
    train_data, val_data, test_data = load_pos_brown_data()
    print(f"Train size: {len(train_data)}")
    print(f"Val size: {len(val_data)}")
    print(f"Test size: {len(test_data)}\n")
    
    # Build vocabulary for POS tagger
    print("Building POS tagger vocabulary...")
    word2idx, idx2word, tag2idx, idx2tag = build_vocab_and_tags(train_data, min_freq=min_freq)
    print()
    
    # Load pretrained embeddings if specified
    pretrained_embeddings = None
    pretrained_vocab = None
    
    if embedding_type == 'svd':
        if embedding_path is None:
            embedding_path = 'embeddings/svd.pt'
        pretrained_embeddings, pretrained_vocab, _ = load_svd_embeddings(embedding_path)
        embedding_dim = pretrained_embeddings.shape[1]
    
    elif embedding_type == 'cbow':
        if embedding_path is None:
            embedding_path = 'embeddings/cbow.pt'
        pretrained_embeddings, pretrained_vocab, _ = load_cbow_embeddings(embedding_path)
        embedding_dim = pretrained_embeddings.shape[1]
    
    elif embedding_type == 'glove':
        if embedding_path is None:
            embedding_path = 'glove.6B.100d.txt'
        pretrained_embeddings, pretrained_vocab, _ = load_glove_embeddings(embedding_path)
        embedding_dim = pretrained_embeddings.shape[1]
    
    elif embedding_type == 'fasttext':
        if embedding_path is None:
            embedding_path = 'wiki-news-300d-1M-subword.vec'  # Default to wiki-news
        pretrained_embeddings, pretrained_vocab, _ = load_fasttext_embeddings(embedding_path)
        embedding_dim = pretrained_embeddings.shape[1]
    
    elif embedding_type == 'scratch':
        print("Training from scratch with randomly initialized embeddings")
    
    else:
        raise ValueError(f"Unknown embedding type: {embedding_type}")
    
    print(f"\nEmbedding dimension: {embedding_dim}")
    print()
    
    # Create datasets
    print("Creating datasets...")
    train_dataset = POSDataset(train_data, word2idx, tag2idx, context_size=context_size)
    val_dataset = POSDataset(val_data, word2idx, tag2idx, context_size=context_size)
    test_dataset = POSDataset(test_data, word2idx, tag2idx, context_size=context_size)
    
    print(f"Train examples: {len(train_dataset)}")
    print(f"Val examples: {len(val_dataset)}")
    print(f"Test examples: {len(test_dataset)}\n")
    
    # Create dataloaders
    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False)
    test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)
    
    # Initialize model
    print("Initializing model...")
    model = POSTaggerMLP(
        vocab_size=len(word2idx),
        embedding_dim=embedding_dim,
        context_size=context_size,
        hidden_dim1=hidden_dim1,
        hidden_dim2=hidden_dim2,
        num_tags=len(tag2idx),
        dropout=dropout
    ).to(device)
    
    # Load pretrained embeddings into model
    if pretrained_embeddings is not None:
        print("\nAligning pretrained embeddings with POS vocabulary...")
        aligned_embeddings, num_found = create_aligned_embeddings(
            pretrained_embeddings, 
            pretrained_vocab, 
            word2idx, 
            embedding_dim
        )
        initialize_model_with_embeddings(model, aligned_embeddings, freeze_embeddings)
    
    print(f"\nModel architecture:")
    print(f"  Input: {(2*context_size+1) * embedding_dim} (context_size={context_size}, embedding_dim={embedding_dim})")
    print(f"  Hidden layer 1: {hidden_dim1}")
    print(f"  Hidden layer 2: {hidden_dim2}")
    print(f"  Output: {len(tag2idx)} tags")
    
    total_params = sum(p.numel() for p in model.parameters())
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"  Total parameters: {total_params:,}")
    print(f"  Trainable parameters: {trainable_params:,}")
    print()
    
    # Loss and optimizer
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(filter(lambda p: p.requires_grad, model.parameters()), lr=learning_rate)
    
    # Training loop
    print("Starting training...")
    best_val_acc = 0.0
    
    for epoch in range(num_epochs):
        print(f"\nEpoch {epoch+1}/{num_epochs}")
        
        # Train
        train_loss, train_acc = train_epoch(model, train_loader, criterion, optimizer, device)
        
        # Validate
        val_loss, val_acc = evaluate(model, val_loader, criterion, device)
        
        print(f"Train Loss: {train_loss:.4f}, Train Acc: {train_acc:.4f}")
        print(f"Val Loss: {val_loss:.4f}, Val Acc: {val_acc:.4f}")
        
        # Save best model
        if val_acc > best_val_acc:
            best_val_acc = val_acc
            
            # Determine save path based on embedding type
            if embedding_type == 'scratch':
                save_path = os.path.join(MODEL_OUTPUT_DIR, 'pos_tagger_best.pt')
            else:
                save_path = os.path.join(MODEL_OUTPUT_DIR, f'pos_tagger_{embedding_type}.pt')
            
            torch.save({
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'val_acc': val_acc,
                'word2idx': word2idx,
                'idx2word': idx2word,
                'tag2idx': tag2idx,
                'idx2tag': idx2tag,
                'hyperparameters': {
                    'context_size': context_size,
                    'embedding_dim': embedding_dim,
                    'hidden_dim1': hidden_dim1,
                    'hidden_dim2': hidden_dim2,
                    'dropout': dropout
                },
                'embedding_type': embedding_type,
                'freeze_embeddings': freeze_embeddings
            }, save_path)
            print(f"✓ Saved best model to {save_path} (Val Acc: {val_acc:.4f})")
    
    # Test on best model
    print("\n" + "="*70)
    print("Testing on best model...")
    
    if embedding_type == 'scratch':
        checkpoint_path = os.path.join(MODEL_OUTPUT_DIR, 'pos_tagger_best.pt')
    else:
        checkpoint_path = os.path.join(MODEL_OUTPUT_DIR, f'pos_tagger_{embedding_type}.pt')
    
    checkpoint = torch.load(checkpoint_path)
    model.load_state_dict(checkpoint['model_state_dict'])
    
    test_loss, test_acc = evaluate(model, test_loader, criterion, device)
    print(f"\nTest Loss: {test_loss:.4f}")
    print(f"Test Accuracy: {test_acc:.4f}")
    print("="*70)
    
    return model, test_acc


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Train POS tagger with different embedding initializations')
    
    parser.add_argument(
        '--embedding-type',
        type=str,
        choices=['scratch', 'svd', 'cbow', 'glove', 'fasttext'],
        required=True,
        help='Type of embedding initialization'
    )
    
    parser.add_argument(
        '--freeze',
        action='store_true',
        help='Freeze embeddings during training (only applicable for pretrained embeddings)'
    )
    
    parser.add_argument(
        '--embedding-path',
        type=str,
        default=None,
        help='Path to embedding file (optional, defaults to standard paths)'
    )
    
    parser.add_argument(
        '--context-size',
        type=int,
        default=2,
        help='Context window size on each side (default: 2)'
    )
    
    parser.add_argument(
        '--hidden-dim1',
        type=int,
        default=256,
        help='First hidden layer dimension (default: 256)'
    )
    
    parser.add_argument(
        '--hidden-dim2',
        type=int,
        default=128,
        help='Second hidden layer dimension (default: 128)'
    )
    
    parser.add_argument(
        '--batch-size',
        type=int,
        default=128,
        help='Batch size (default: 128)'
    )
    
    parser.add_argument(
        '--learning-rate',
        type=float,
        default=0.001,
        help='Learning rate (default: 0.001)'
    )
    
    parser.add_argument(
        '--num-epochs',
        type=int,
        default=20,
        help='Number of training epochs (default: 20)'
    )
    
    parser.add_argument(
        '--dropout',
        type=float,
        default=0.3,
        help='Dropout rate (default: 0.3)'
    )
    
    args = parser.parse_args()

    # Create output directory if it doesn't exist
    os.makedirs(MODEL_OUTPUT_DIR, exist_ok=True)
    
    # Set device
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Using device: {device}\n")
    
    # Train model
    train_pos_tagger(
        embedding_type=args.embedding_type,
        freeze_embeddings=args.freeze,
        embedding_path=args.embedding_path,
        context_size=args.context_size,
        embedding_dim=100,  # Will be overridden by pretrained embeddings if used
        hidden_dim1=args.hidden_dim1,
        hidden_dim2=args.hidden_dim2,
        batch_size=args.batch_size,
        learning_rate=args.learning_rate,
        num_epochs=args.num_epochs,
        dropout=args.dropout,
        device=device
    )
