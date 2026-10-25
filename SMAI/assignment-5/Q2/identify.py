"""
identify.py

Derives a compact analytical recurrence (F_theta) consistent with
the learned mapping, as required by Q2.3.

This is done by training a LinearAR model and extracting its coefficients.
"""

import numpy as np
import pandas as pd
from data_prep import load_data, create_splits, normalize_data, create_supervised_pairs
from model import LinearAR

# --- CONFIGURATION ---
# !!! IMPORTANT !!!
# Update this value based on the "Best Configuration" from train.py
BEST_P = 10  # e.g., if train.py said 5 was best, put 5 here.
# ---------------------

def main():
    if BEST_P is None:
        print("Error: Please update the 'BEST_P' variable in this script")
        print("with the best 'p' value found by 'train.py'.")
        return
        
    print(f"--- 2.3 Analytical Recurrence Identification ---")
    print(f"Identifying linear recurrence F_theta using p = {BEST_P}\n")

    # 1. Load, Split, Normalize Data (from data_prep.py)
    raw_data = load_data('recurrence_timeseries.csv')
    train_raw, val_raw, test_raw = create_splits(raw_data)
    # We train the final AR model on the training set, just as in train.py
    train_norm, val_norm, test_norm, scaler = normalize_data(train_raw, val_raw, test_raw)
    
    # 2. Create supervised pairs
    X_train, y_train = create_supervised_pairs(train_norm, BEST_P)

    # 3. Train the LinearAR model to find the recurrence
    # The LinearAR model *is* our analytical function F_theta
    print(f"Training LinearAR(p={BEST_P}) on the training data...")
    ar_model = LinearAR(p_history_length=BEST_P)
    ar_model.fit(X_train, y_train)
    print("Training complete.")

    # 4. Derive and report the analytical recurrence
    coeffs, intercept = ar_model.get_coefficients()

    print("\n--- Derived Analytical Recurrence (F_theta) ---")
    print("This recurrence is based on the LinearAR model")
    print("and operates on the *normalized* data (x_norm).")
    
    # Build the equation string
    equation = f"\n  x_norm[k] = "
    for i, c in enumerate(coeffs):
        term = f"({c:+.4f} * x_norm[k-{i+1}])"
        equation += f"{term} + "
    
    equation += f"({intercept:+.4f})"
    
    print(equation)
    
    print("\nParameters (theta):")
    for i, c in enumerate(coeffs):
        print(f"  theta_{i+1} (coeff for x_norm[k-{i+1}]): {c:.6f}")
    print(f"  Intercept: {intercept:.6f}")
    
    print(f"\nThis analytical function (F_theta) and the 'best' model")
    print("from train.py will both be evaluated in 'analyze.py'.")

if __name__ == '__main__':
    main()