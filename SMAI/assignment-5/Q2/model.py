"""
model.py

Implements baseline predictor models as required for Q2:
- LinearAR (using sklearn)
- MLP (using PyTorch)
- SimpleRNN (using PyTorch)
"""

import torch
import torch.nn as nn
from sklearn.linear_model import LinearRegression

# --- 1. Classical Baseline: Linear Auto-Regression ---

class LinearAR:
    """
    A wrapper for a scikit-learn LinearRegression model to serve as
    a Linear Auto-Regressive (AR) baseline.
    
    This model predicts x_k as a linear combination of (x_k-1, ..., x_k-p).
    """
    def __init__(self, p_history_length):
        """
        Initializes the model.
        
        Args:
            p_history_length (int): The history length 'p'. This corresponds
                                    to the number of features.
        """
        self.p = p_history_length
        self.model = LinearRegression()
        
    def fit(self, X_train, y_train):
        """
        Fits the Linear Regression model.
        
        Args:
            X_train (np.ndarray): Shape (n_samples, p)
            y_train (np.ndarray): Shape (n_samples,)
        """
        print("Fitting LinearAR model...")
        self.model.fit(X_train, y_train)
        print("Fit complete.")
        
    def predict(self, X):
        """
        Predicts using the fitted model.
        
        Args:
            X (np.ndarray): Shape (n_samples, p)
            
        Returns:
            np.ndarray: Shape (n_samples,)
        """
        return self.model.predict(X)

    def get_coefficients(self):
        """
        Returns the learned coefficients (the recurrence relation).
        """
        return self.model.coef_, self.model.intercept_


# --- 2. Deep Learning Baseline: MLP ---

class MLP(nn.Module):
    """
    A simple Multi-Layer Perceptron (MLP) for sequence prediction.
    
    Takes the entire history vector of length 'p' as a flat input.
    """
    def __init__(self, p_history_length, hidden_size=64):
        """
        Args:
            p_history_length (int): The history length 'p'.
            hidden_size (int): The number of neurons in the hidden layer.
        """
        # --- FIX IS HERE ---
        super().__init__()
        # -------------------
        self.p = p_history_length
        
        # A simple 2-layer network
        self.layers = nn.Sequential(
            nn.Linear(p_history_length, hidden_size),
            nn.ReLU(),
            nn.Linear(hidden_size, hidden_size // 2),
            nn.ReLU(),
            nn.Linear(hidden_size // 2, 1) # Output is a single value
        )
        
    def forward(self, x):
        """
        Args:
            x (torch.Tensor): Input tensor of shape (batch_size, p)
            
        Returns:
            torch.Tensor: Output tensor of shape (batch_size, 1)
        """
        # Squeeze the last dimension to match target (batch_size,)
        return self.layers(x).squeeze(-1)


# --- 3. Deep Learning Baseline: RNN ---

class SimpleRNN(nn.Module):
    """
    A small RNN-based model for sequence prediction, as suggested.
    
    Treats the history of length 'p' as a sequence.
    """
    def __init__(self, p_history_length, hidden_size=64, num_layers=1):
        """
        Args:
            p_history_length (int): The history length 'p'. (Not directly used
                                    by RNN core, but good to store).
            hidden_size (int): The size of the RNN's hidden state.
            num_layers (int): The number of stacked RNN layers.
        """
        # --- FIX IS HERE ---
        super().__init__()
        # -------------------
        self.p = p_history_length
        self.hidden_size = hidden_size
        self.num_layers = num_layers
        
        # RNN layer
        # input_size=1 because we have a univariate time series
        # We feed one time step at a time.
        self.rnn = nn.GRU(
            input_size=1, 
            hidden_size=hidden_size,
            num_layers=num_layers, 
            batch_first=True  # Input shape is (batch_size, seq_len, input_size)
        )
        
        # A fully-connected layer to map the final hidden state to the output
        self.fc = nn.Linear(hidden_size, 1)
        
    def forward(self, x):
        """
        Args:
            x (torch.Tensor): Input tensor of shape (batch_size, p)
            
        Returns:
            torch.Tensor: Output tensor of shape (batch_size, 1)
        """
        # The RNN expects input as (batch_size, seq_len, input_size)
        # Our input x is (batch_size, p). We need to add the 'input_size' dim.
        # Reshape x to (batch_size, p, 1)
        x = x.unsqueeze(-1) 
        
        # Initialize hidden state (num_layers, batch_size, hidden_size)
        h0 = torch.zeros(self.num_layers, x.size(0), self.hidden_size).to(x.device)
        
        # Pass through RNN
        # 'out' shape: (batch_size, seq_len, hidden_size)
        # 'hn' shape: (num_layers, batch_size, hidden_size)
        out, hn = self.rnn(x, h0)
        
        # We use the output from the *last* time step
        # out[:, -1, :] gives shape (batch_size, hidden_size)
        out = self.fc(out[:, -1, :])
        
        # Squeeze the last dimension to match target (batch_size,)
        return out.squeeze(-1)


# --- Main execution block to test model shapes ---
if __name__ == '__main__':
    
    # --- Configuration ---
    P_HISTORY = 10  # Example history length 'p'
    BATCH_SIZE = 32
    
    # Create dummy data
    # (batch_size, p)
    dummy_input_batch = torch.randn(BATCH_SIZE, P_HISTORY)
    
    print(f"--- Model Shape Tests (p={P_HISTORY}, batch_size={BATCH_SIZE}) ---")
    print(f"Input batch shape: {dummy_input_batch.shape}\n")

    # --- Test MLP ---
    mlp = MLP(p_history_length=P_HISTORY)
    mlp_output = mlp(dummy_input_batch)
    print(f"MLP Output Shape: {mlp_output.shape}") # Expected: (32,)
    
    # --- Test RNN ---
    rnn = SimpleRNN(p_history_length=P_HISTORY)
    rnn_output = rnn(dummy_input_batch)
    print(f"RNN Output Shape: {rnn_output.shape}") # Expected: (32,)
    
    # --- Test LinearAR (Numpy) ---
    import numpy as np
    dummy_X_train = np.random.randn(100, P_HISTORY)
    dummy_y_train = np.random.randn(100)
    dummy_X_test = np.random.randn(20, P_HISTORY)
    
    linear_ar = LinearAR(p_history_length=P_HISTORY)
    linear_ar.fit(dummy_X_train, dummy_y_train)
    ar_output = linear_ar.predict(dummy_X_test)
    print(f"\nLinearAR Output Shape: {ar_output.shape}") # Expected: (20,)
    
    coef, intercept = linear_ar.get_coefficients()
    print(f"LinearAR Coefs: {len(coef)}") # Expected: 10