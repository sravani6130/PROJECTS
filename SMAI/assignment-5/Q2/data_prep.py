"""
data_prep.py

Loads, splits, and normalizes the time series data for Q2.
Also provides a utility for creating supervised (history, target) pairs.
"""

import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler

def load_data(filepath='recurrence_timeseries.csv'):
    """
    [cite_start]Loads the time series data from the CSV file. [cite: 99]
    
    Args:
        filepath (str): The path to the CSV file.
        
    Returns:
        np.ndarray: A 1D numpy array of the 'x_value' time series.
    """
    try:
        df = pd.read_csv(filepath)
        # Convert to a 1D numpy array of float32 for efficiency
        data = df['x_value'].values.astype(np.float32)
        print(f"Loaded data from '{filepath}'. Total samples: {len(data)}")
        return data
    except FileNotFoundError:
        print(f"Error: Data file not found at {filepath}")
        return np.array([])

def create_splits(data, train_pct=0.7, val_pct=0.15):
    """
    [cite_start]Creates chronological train/validation/test splits. [cite: 95, 99]
    
    Args:
        data (np.ndarray): The complete 1D time series.
        train_pct (float): Percentage of data for training.
        val_pct (float): Percentage of data for validation.
        
    Returns:
        tuple: (train_data, val_data, test_data)
    """
    n = len(data)
    train_end = int(n * train_pct)
    val_end = int(n * (train_pct + val_pct))
    
    train_data = data[0:train_end]
    val_data = data[train_end:val_end]
    test_data = data[val_end:]
    
    print(f"Data split chronologically:")
    print(f"  Train: {len(train_data)} samples (0 -> {train_end})")
    print(f"  Valid: {len(val_data)} samples ({train_end} -> {val_end})")
    print(f"  Test:  {len(test_data)} samples ({val_end} -> {n})")
    
    return train_data, val_data, test_data

def normalize_data(train_data, val_data, test_data):
    """
    [cite_start]Applies StandardScaler normalization based ONLY on the training set. [cite: 97, 99]
    
    Args:
        train_data (np.ndarray): The training time series.
        val_data (np.ndarray): The validation time series.
        test_data (np.ndarray): The test time series.
        
    Returns:
        tuple: (train_norm, val_norm, test_norm, scaler_object)
    """
    # Scaler expects data in shape (n_samples, n_features)
    # We reshape our 1D data to (n_samples, 1)
    train_data_reshaped = train_data.reshape(-1, 1)
    val_data_reshaped = val_data.reshape(-1, 1)
    test_data_reshaped = test_data.reshape(-1, 1)
    
    # 1. Initialize and FIT ONLY on training data
    scaler = StandardScaler()
    scaler.fit(train_data_reshaped)
    
    # 2. Transform all three sets
    train_norm = scaler.transform(train_data_reshaped)
    val_norm = scaler.transform(val_data_reshaped)
    test_norm = scaler.transform(test_data_reshaped)
    
    print(f"Normalization applied (fit on train set):")
    print(f"  Train Mean: {scaler.mean_[0]:.4f}, Train Std: {scaler.scale_[0]:.4f}")
    
    # Squeeze back to 1D arrays for easier handling
    return train_norm.squeeze(), val_norm.squeeze(), test_norm.squeeze(), scaler

def create_supervised_pairs(data, p_history_length):
    """
    [cite_start]Forms (history -> target) pairs using a sliding window. [cite: 96]
    
    Args:
        data (np.ndarray): The 1D time series (e.g., train_norm).
        p_history_length (int): The history length 'p'.
        
    Returns:
        tuple: (X, y)
            X (np.ndarray): Shape (n_samples, p)
            y (np.ndarray): Shape (n_samples,)
    """
    X, y = [], []
    for i in range(len(data) - p_history_length):
        # History (h_k): data from i to i+p
        history_hk = data[i : i + p_history_length]
        # Target (x_k): data at i+p
        target_xk = data[i + p_history_length]
        
        X.append(history_hk)
        y.append(target_xk)
        
    return np.array(X), np.array(y)

# --- Main execution block to test the script ---
if __name__ == '__main__':
    
    # --- Configuration ---
    FILE_PATH = 'recurrence_timeseries.csv'
    P_HISTORY = 10  # Example history length 'p'
    
    # --- 1. Load Data ---
    raw_data = load_data(FILE_PATH)
    
    if raw_data.size > 0:
        # --- 2. Create Splits ---
        train_raw, val_raw, test_raw = create_splits(raw_data, train_pct=0.7, val_pct=0.15)
        
        # --- 3. Normalize Data ---
        train_norm, val_norm, test_norm, scaler = normalize_data(train_raw, val_raw, test_raw)
        
        print("\n--- Inverse Transform Check ---")
        # [cite_start]The 'scaler' object is needed for the inverse transform [cite: 97]
        sample_norm = np.array([1.0, 0.0, -2.5])
        sample_original = scaler.inverse_transform(sample_norm.reshape(-1, 1)).squeeze()
        print(f"Normalized {sample_norm} -> Original {sample_original}")
        
        # --- 4. Create Supervised Pairs (Example) ---
        print(f"\n--- Supervised Pairs Check (p={P_HISTORY}) ---")
        X_train, y_train = create_supervised_pairs(train_norm, P_HISTORY)
        X_val, y_val = create_supervised_pairs(val_norm, P_HISTORY)
        
        print(f"X_train shape: {X_train.shape}, y_train shape: {y_train.shape}")
        print(f"X_val shape: {X_val.shape}, y_val shape: {y_val.shape}")