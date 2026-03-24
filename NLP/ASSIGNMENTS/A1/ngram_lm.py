import math
from collections import defaultdict
try:
    from tqdm import tqdm
except ImportError:
    tqdm = lambda x, **kwargs: x

class NGramModel:
    """
    A Probabilistic 4-Gram Language Model using native Python dictionary structs.
    Supports Smoothing: 'none', 'witten_bell', 'kneser_ney'.
    """
    def __init__(self, n=4, tokenizer=None, smoothing='none'):
        self.n = n
        self.tokenizer = tokenizer
        self.smoothing = smoothing
        
        self.counts = {i: defaultdict(lambda: defaultdict(int)) for i in range(1, n+1)}
        self.context_totals = {i: defaultdict(int) for i in range(1, n+1)}
        
        self.kn_continuations = {i: defaultdict(lambda: defaultdict(int)) for i in range(1, n)} 
        self.kn_context_totals = {i: defaultdict(int) for i in range(1, n)} 
        
        self.vocab = set()
        self.sos_id = -1
        self.eos_id = -2

    def train(self, corpus_lines):
        for line in tqdm(corpus_lines, desc=f"Training {self.smoothing.upper()} LM", unit="line", leave=False):
            token_ids = self.tokenizer.encode(line)
            if not token_ids:
                continue
                
            self.vocab.update(token_ids)
            padded_tokens = [self.sos_id] * (self.n - 1) + token_ids + [self.eos_id]
            
            for k in range(1, self.n + 1):
                for i in range(len(padded_tokens) - k + 1):
                    ngram = tuple(padded_tokens[i:i+k])
                    context = ngram[:-1]
                    target = ngram[-1]
                    
                    self.counts[k][context][target] += 1
                    self.context_totals[k][context] += 1
                    
        # Post-process for Kneser-Ney continuation metrics
        if self.smoothing == 'kneser_ney':
            for k in range(self.n, 1, -1):
                for context, targets in self.counts[k].items():
                    suffix_context = context[1:]
                    for target in targets.keys():
                        self.kn_continuations[k-1][suffix_context][target] += 1
            
            for k in range(1, self.n):
                for context, targets in self.kn_continuations[k].items():
                    self.kn_context_totals[k][context] = sum(targets.values())

    def _prob(self, k, context, target):
        if self.smoothing == 'none':
            c_context = self.context_totals[self.n][context]
            return self.counts[self.n][context][target] / c_context if c_context > 0 else 0.0
            
        elif self.smoothing == 'witten_bell':
            # Base Case
            if k == 1:
                return self.counts[1][()][target] / max(1, self.context_totals[1][()])
                
            c_cw = self.counts[k][context][target]
            c_c = self.context_totals[k][context]
            
            # Unseen Context Backoff
            if c_c == 0:
                return self._prob(k-1, context[1:], target)
                
            n_c = len(self.counts[k][context])
            p_backoff = self._prob(k-1, context[1:], target)
            return (c_cw + n_c * p_backoff) / (c_c + n_c)
            
        elif self.smoothing == 'kneser_ney':
            d = 0.75 
            if k == self.n:
                c_cw = self.counts[k][context][target]
                c_c  = self.context_totals[k][context]
                n_c = len(self.counts[k][context])
            else:
                c_cw = self.kn_continuations[k][context][target]
                c_c  = self.kn_context_totals[k][context]
                n_c = len(self.kn_continuations[k][context])
            
            # Base Case
            if k == 1:
                return c_cw / max(1, c_c)
                
            # Unseen Context Backoff
            if c_c == 0:
                return self._prob(k-1, context[1:], target)
                
            lmbda = (d / c_c) * n_c
            p_backoff = self._prob(k-1, context[1:], target)
            
            term1 = max(c_cw - d, 0) / c_c
            return term1 + lmbda * p_backoff

    def generate_next_token(self, current_sequence):
        context_len = self.n - 1
        if len(current_sequence) < context_len:
            context = tuple([self.sos_id] * (context_len - len(current_sequence)) + current_sequence)
        else:
            context = tuple(current_sequence[-context_len:])
            
        if self.smoothing == 'none':
            seen = self.counts[self.n][context]
            return max(seen, key=seen.get) if seen else self.eos_id
            
        best_token = self.eos_id
        best_prob = -1
        candidates = list(self.vocab) + [self.eos_id]
        
        for candidate in candidates:
            prob = self._prob(self.n, context, candidate)
            if prob > best_prob:
                best_prob = prob
                best_token = candidate
                
        return best_token

    def autocomplete(self, partial_text, max_new_tokens=20):
        token_ids = self.tokenizer.encode(partial_text)
        for _ in range(max_new_tokens):
            next_token = self.generate_next_token(token_ids)
            if next_token == self.eos_id:
                break
            token_ids.append(next_token)
            
        return self.tokenizer.decode(token_ids)

    def calculate_perplexity(self, test_lines):
        """Calculates the perplexity of the model on a given text sequence collection"""
        total_log_prob = 0.0
        total_tokens = 0
        
        for line in tqdm(test_lines, desc=f"Evaluating Perplexity ({self.smoothing.upper()})", unit="line", leave=False):
            token_ids = self.tokenizer.encode(line)
            if not token_ids:
                continue
                
            padded_tokens = [self.sos_id] * (self.n - 1) + token_ids + [self.eos_id]
            
            for i in range(len(padded_tokens) - self.n + 1):
                ngram = tuple(padded_tokens[i:i+self.n])
                context = ngram[:-1]
                target = ngram[-1]
                
                prob = self._prob(self.n, context, target)
                
                # Handling zero probability natively outputs infinite perplexity
                if prob <= 0.0:
                    prob = 1e-10
                    
                total_log_prob += math.log(prob)
                total_tokens += 1
                
        if total_tokens == 0:
            return float('inf')
            
        avg_log_prob = total_log_prob / total_tokens
        return math.exp(-avg_log_prob)

