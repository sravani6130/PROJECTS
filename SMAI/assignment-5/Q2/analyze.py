"""
analyze.py

Performs the final evaluation for Q2 as required by Q2.4.
1. Reports test performance (MAE, MSE) for single-step prediction.
2. Plots residuals for the best models.
3. Evaluates and plots autoregressive forecasting error vs. horizon.
"""
from contextlib import nullcontext
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
from sklearn.metrics import mean_absolute_error, mean_squared_error

# Import from our other files
from data_prep import load_data, create_splits, normalize_data, create_supervised_pairs
from model import LinearAR, MLP, SimpleRNN  # Import all models

# ----------------------------------------------------------------------
# --- CONFIGURATION (!!! YOU MUST EDIT THIS SECTION !!!) ---
# ----------------------------------------------------------------------
# 1. Fill in 'p' from identify.py
BEST_P = 10  # Example: 5

# 2. Fill in the best DL model name and class from train.py
BEST_DL_MODEL_NAME = 'MLP' # Example: 'RNN' or 'MLP'
BEST_DL_MODEL_CLASS = MLP  # Example: SimpleRNN or MLP

# [cite_start]3. Fill in your email username for plots [cite: 26]
EMAIL_USERNAME = "ritama.sanyal"
# ----------------------------------------------------------------------

# --- PyTorch Training Configuration ---
EPOCHS = 50
BATCH_SIZE = 64
LEARNING_RATE = 0.001
DEVICE = 'cuda' if torch.cuda.is_available() else 'cpu'

# --- Helper function to train a PyTorch model ---
# (Copied from train.py for self-contained analysis)
def train_pytorch_model(model, X_train, y_train):
    """
    Trains a PyTorch model and returns the trained model.
    """
    print(f"Training {model.__class__.__name__} on {DEVICE}...")
    model.to(DEVICE)
    
    # Create Tensors and DataLoaders
    X_train_t = torch.tensor(X_train, dtype=torch.float32)
    y_train_t = torch.tensor(y_train, dtype=torch.float32)
    
    train_dataset = TensorDataset(X_train_t, y_train_t)
    train_loader = DataLoader(train_dataset, batch_size=BATCH_SIZE, shuffle=True)
    
    criterion = nn.MSELoss()
    optimizer = optim.Adam(model.parameters(), lr=LEARNING_RATE)
    
    model.train()
    for epoch in range(EPOCHS):
        for X_batch, y_batch in train_loader:
            X_batch, y_batch = X_batch.to(DEVICE), y_batch.to(DEVICE)
            optimizer.zero_grad()
            y_pred = model(X_batch)
            loss = criterion(y_pred, y_batch)
            loss.backward()
            optimizer.step()
    
    print("Training complete.")
    return model

def get_final_models_and_data(p, dl_class):
    """
    Loads, preps data, and trains the final two models.
    """
    # 1. Load, Split, Normalize
    raw_data = load_data('recurrence_timeseries.csv')
    train_raw, val_raw, test_raw = create_splits(raw_data)
    train_norm, val_norm, test_norm, scaler = normalize_data(train_raw, val_raw, test_raw)
    
    # 2. Create supervised pairs for 'p'
    X_train, y_train = create_supervised_pairs(train_norm, p)
    X_test, y_test = create_supervised_pairs(test_norm, p)
    
    # 3. Train Analytical Model (LinearAR)
    print(f"\nTraining Analytical (LinearAR) model with p={p}...")
    ar_model = LinearAR(p_history_length=p)
    ar_model.fit(X_train, y_train)
    
    # 4. Train Best DL Model
    print(f"\nTraining Best DL ({dl_class.__name__}) model with p={p}...")
    dl_model = dl_class(p_history_length=p)
    dl_model = train_pytorch_model(dl_model, X_train, y_train)
    
    return ar_model, dl_model, X_test, y_test, test_norm, scaler

def generate_autoregressive_forecast(model, start_history, forecast_length):
    """
    Generates a forecast of a given length, one step at a time.
    """
    p = len(start_history)
    history = list(start_history)
    forecast = []
    
    is_torch = isinstance(model, nn.Module)
    if is_torch:
        model.eval()
        model.to(DEVICE)
        
    with (torch.no_grad() if is_torch else nullcontext()): # Context manager hack
        for _ in range(forecast_length):
            # Get the last 'p' steps as the input
            history_np = np.array(history[-p:])
            
            if is_torch:
                history_tensor = torch.tensor(history_np, dtype=torch.float32).reshape(1, p).to(DEVICE)
                pred = model(history_tensor).item()
            else: # LinearAR
                pred = model.predict(history_np.reshape(1, p))[0]
                
            forecast.append(pred)
            history.append(pred) # Add the new prediction to the history
            
    return np.array(forecast)

def add_username_to_plot(ax, username):
    """Helper to add username to plot axes."""
    ax.text(
        0.95, 0.95,
        username,
        ha='right', va='top',
        transform=ax.transAxes,
        fontsize=10, color='gray', alpha=0.7
    )

# --- Main Analysis Script ---
def main():
    if BEST_P is None or BEST_DL_MODEL_NAME is None:
        print("Error: Please update the 'CONFIGURATION' section at the top of analyze.py")
        return

    print("--- 2.4 Evaluation and Analysis ---")
    
    # 1. Get trained models and test data
    ar_model, dl_model, X_test_norm, y_test_norm, test_norm_series, scaler = \
        get_final_models_and_data(BEST_P, BEST_DL_MODEL_CLASS)
        
    # [cite_start]--- 2. Single-Step Prediction Evaluation [cite: 119] ---
    print("\n--- 2.4.1 Single-Step Prediction Performance (on Test Set) ---")
    
    # Get predictions
    ar_pred_norm = ar_model.predict(X_test_norm)
    
    dl_model.eval()
    with torch.no_grad():
        X_test_t = torch.tensor(X_test_norm, dtype=torch.float32).to(DEVICE)
        dl_pred_norm = dl_model(X_test_t).cpu().numpy()
        
    # Inverse transform to original scale
    y_test_orig = scaler.inverse_transform(y_test_norm.reshape(-1, 1)).squeeze()
    ar_pred_orig = scaler.inverse_transform(ar_pred_norm.reshape(-1, 1)).squeeze()
    dl_pred_orig = scaler.inverse_transform(dl_pred_norm.reshape(-1, 1)).squeeze()

    # Calculate metrics
    results = {
        'Analytical (LinearAR)': {
            'MAE': mean_absolute_error(y_test_orig, ar_pred_orig),
            'MSE': mean_squared_error(y_test_orig, ar_pred_orig)
        },
        f'DL Model ({BEST_DL_MODEL_NAME})': {
            'MAE': mean_absolute_error(y_test_orig, dl_pred_orig),
            'MSE': mean_squared_error(y_test_orig, dl_pred_orig)
        }
    }
    
    print(pd.DataFrame.from_dict(results, orient='index').to_string())

    # [cite_start]--- 3. Plot Residuals [cite: 103] ---
    print("\nPlotting residuals...")
    fig1, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
    
    # Residuals = True - Predicted (on normalized data)
    ar_residuals = y_test_norm - ar_pred_norm
    dl_residuals = y_test_norm - dl_pred_norm
    
    ax1.scatter(ar_pred_norm, ar_residuals, alpha=0.5)
    ax1.axhline(0, color='red', linestyle='--')
    ax1.set_title(f'Residual Plot: Analytical (LinearAR, p={BEST_P})')
    ax1.set_xlabel('Predicted Value (Normalized)')
    ax1.set_ylabel('Residual (True - Pred)')
    add_username_to_plot(ax1, EMAIL_USERNAME)
    
    ax2.scatter(dl_pred_norm, dl_residuals, alpha=0.5)
    ax2.axhline(0, color='red', linestyle='--')
    ax2.set_title(f'Residual Plot: DL Model ({BEST_DL_MODEL_NAME}, p={BEST_P})')
    ax2.set_xlabel('Predicted Value (Normalized)')
    ax2.set_ylabel('Residual (True - Pred)')
    add_username_to_plot(ax2, EMAIL_USERNAME)
    
    fig1.suptitle('Residual Analysis (Normalized Scale)')

    # [cite_start]--- 4. Autoregressive Forecasting Evaluation [cite: 120, 121] ---
    print("Evaluating autoregressive forecasting...")
    
    # Define horizons to test
    horizons = [1, 2, 3, 5, 7, 10, 15, 20, 30]
    max_h = max(horizons)
    
    # Get the starting history and the ground truth
    start_history = test_norm_series[0:BEST_P]
    ground_truth = test_norm_series[BEST_P : BEST_P + max_h]
    
    ar_errors_mse = []
    dl_errors_mse = []

    for h in horizons:
        # Get ground truth for this horizon
        h_truth = ground_truth[0:h]
        
        # Get AR forecast and error
        ar_forecast = generate_autoregressive_forecast(ar_model, start_history, h)
        ar_err = mean_squared_error(h_truth, ar_forecast)
        ar_errors_mse.append(ar_err)
        
        # Get DL forecast and error
        dl_forecast = generate_autoregressive_forecast(dl_model, start_history, h)
        dl_err = mean_squared_error(h_truth, dl_forecast)
        dl_errors_mse.append(dl_err)
        
    # Plot the results
    fig2, ax_forecast = plt.subplots(figsize=(10, 6))
    
    ax_forecast.plot(horizons, ar_errors_mse, 'o-', label=f'Analytical ($F_\\theta$ LinearAR)')
    ax_forecast.plot(horizons, dl_errors_mse, 's-', label=f'DL Model ({BEST_DL_MODEL_NAME})')
    
    ax_forecast.set_title('Autoregressive Forecast Error vs. Horizon Length')
    ax_forecast.set_xlabel('Forecast Length (h steps)')
    ax_forecast.set_ylabel('Mean Squared Error (MSE) (Normalized Scale)')
    ax_forecast.set_xticks(horizons)
    ax_forecast.set_yscale('log') # Errors often grow exponentially
    ax_forecast.legend()
    ax_forecast.grid(True, which='both', linestyle='--', alpha=0.6)
    add_username_to_plot(ax_forecast, EMAIL_USERNAME)
    
    print("Displaying plots. Close plot windows to exit.")
    plt.tight_layout()
    plt.show()

if __name__ == '__main__':
    main()