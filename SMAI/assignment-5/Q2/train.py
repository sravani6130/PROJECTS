"""
train.py

Trains the chosen models (LinearAR, MLP, RNN) and tunes the 'p'
hyperparameter (history length). Logs and reports the results.
"""
"""
Run train.py first. This script will test all your p values (e.g., 2, 3, 5, 10, 20) with all your models (LinearAR, MLP, RNN).

Look at the final output of train.py. It will print a "Best Configuration" table. Note down the best p and the best model (e.g., p=5 and model='RNN').

Then, edit identify.py: Change the BEST_P variable at the top of the file to match the best p you just found.

Then, edit analyze.py: Change the BEST_P, BEST_DL_MODEL_NAME, and BEST_DL_MODEL_CLASS variables at the top to match your results.

Finally, run identify.py and analyze.py to generate your final recurrence formula and evaluation plots.
"""
import numpy as np
import pandas as pd
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
from tqdm import tqdm

# Import from our other files
from data_prep import load_data, create_splits, normalize_data, create_supervised_pairs
from model import LinearAR, MLP, SimpleRNN

# --- PyTorch Training Configuration ---
EPOCHS = 50
BATCH_SIZE = 64
LEARNING_RATE = 0.0001
DEVICE = 'cuda' if torch.cuda.is_available() else 'cpu'

# --- Tuning Configuration ---
# Define the 'p' values to test
P_VALUES_TO_TUNE = [2, 3, 5, 10, 20]
# Define the models to train
MODEL_CLASSES = {
    'LinearAR': LinearAR,
    'MLP': MLP,
    'RNN': SimpleRNN
}

def run_pytorch_training(model, X_train, y_train, X_val, y_val):
    """
    A helper function to train and validate a PyTorch model.
    Returns the best validation loss.
    """
    model.to(DEVICE)
    
    # Create Tensors and DataLoaders
    X_train_t = torch.tensor(X_train, dtype=torch.float32)
    y_train_t = torch.tensor(y_train, dtype=torch.float32)
    X_val_t = torch.tensor(X_val, dtype=torch.float32)
    y_val_t = torch.tensor(y_val, dtype=torch.float32)
    
    train_dataset = TensorDataset(X_train_t, y_train_t)
    val_dataset = TensorDataset(X_val_t, y_val_t)
    
    train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=BATCH_SIZE, shuffle=False)
    
    # Loss and Optimizer
    criterion = nn.MSELoss() # Using MSE as per Q2.4 [cite: 119]
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    
    best_val_loss = float('inf')
    
    for epoch in range(EPOCHS):
        # --- Training Phase ---
        model.train()
        for X_batch, y_batch in train_loader:
            X_batch, y_batch = X_batch.to(DEVICE), y_batch.to(DEVICE)
            
            optimizer.zero_grad()
            y_pred = model(X_batch)
            loss = criterion(y_pred, y_batch)
            loss.backward()
            optimizer.step()
            
        # --- Validation Phase ---
        model.eval()
        total_val_loss = 0
        with torch.no_grad():
            for X_batch, y_batch in val_loader:
                X_batch, y_batch = X_batch.to(DEVICE), y_batch.to(DEVICE)
                y_pred = model(X_batch)
                val_loss = criterion(y_pred, y_batch)
                total_val_loss += val_loss.item()
                
        avg_val_loss = total_val_loss / len(val_loader)
        
        if avg_val_loss < best_val_loss:
            best_val_loss = avg_val_loss
            
    return best_val_loss


def main():
    """
    Main training and tuning script.
    """
    # 1. Load, Split, Normalize Data (from data_prep.py)
    raw_data = load_data('recurrence_timeseries.csv')
    train_raw, val_raw, test_raw = create_splits(raw_data)
    # The 'scaler' object will be needed in analyze.py, but not here
    train_norm, val_norm, test_norm, scaler = normalize_data(train_raw, val_raw, test_raw)

    # 2. Results log
    results_log = []

    # 3. Tuning Loop
    for model_name, model_class in MODEL_CLASSES.items():
        for p in P_VALUES_TO_TUNE:
            
            print(f"\n--- Training {model_name} with p={p} ---")
            
            # 4. Create supervised pairs for this 'p'
            X_train, y_train = create_supervised_pairs(train_norm, p)
            X_val, y_val = create_supervised_pairs(val_norm, p)
            
            if len(X_train) == 0 or len(X_val) == 0:
                print(f"Not enough data to create pairs for p={p}. Skipping.")
                continue

            # 5. Train and Validate
            val_loss = 0.0
            
            if model_name == 'LinearAR':
                model = model_class(p_history_length=p)
                model.fit(X_train, y_train)
                y_val_pred = model.predict(X_val)
                # Calculate MSE loss [cite: 119]
                val_loss = np.mean((y_val_pred - y_val)**2)
            
            else: # PyTorch Models (MLP, RNN)
                model = model_class(p_history_length=p)
                val_loss = run_pytorch_training(model, X_train, y_train, X_val, y_val)
            
            print(f"Result: {model_name} (p={p}) | Validation MSE: {val_loss:.6f}")
            results_log.append({
                'model': model_name,
                'p': p,
                'val_loss_mse': val_loss
            })

    # 6. Log and Report Results 
    results_df = pd.DataFrame(results_log)
    
    print("\n\n" + "="*30)
    print("      TUNING RESULTS       ")
    print("="*30)
    # Sort by loss for clarity
    results_df = results_df.sort_values(by='val_loss_mse')
    print(results_df.to_string(index=False))
    
    # Find the best setting
    best_setting = results_df.loc[results_df['val_loss_mse'].idxmin()]
    
    print("\n--- Best Configuration ---")
    print(f"Model: {best_setting['model']}")
    print(f"p (History): {best_setting['p']}")
    print(f"Validation MSE: {best_setting['val_loss_mse']:.6f}")
    print("\nThis configuration should be used for the final analysis.")

if __name__ == '__main__':
    main()