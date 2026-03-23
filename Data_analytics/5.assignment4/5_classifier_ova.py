import pandas as pd
import numpy as np
import pickle
import seaborn as sns
import matplotlib.pyplot as plt
from sklearn.preprocessing import StandardScaler, OneHotEncoder, label_binarize
from sklearn.model_selection import train_test_split, learning_curve
from sklearn.svm import SVC
from sklearn.metrics import (
    accuracy_score, classification_report, confusion_matrix,
    roc_curve, auc
)
import os


# ================================
# 🔹 DATA PREPROCESSING
# ================================
def preprocess_data(data, is_train=True, scaler=None, encoders=None):
    df = data.copy()

    categorical_cols = ['Ever_Married', 'Graduated', 'Profession', 'Var_1', 'Gender']
    ordinal_cols = ['Spending_Score']
    numerical_cols = ['Work_Experience', 'Family_Size', 'Age']

    if encoders is None:
        encoders = {}

    # Fill missing values
    for col in categorical_cols + ordinal_cols:
        if col in df.columns:
            df[col] = df[col].fillna(df[col].mode()[0])

    for col in numerical_cols:
        if col in df.columns:
            df[col] = df[col].fillna(df[col].median())

    # Ordinal encode Spending_Score
    if 'Spending_Score' in df.columns:
        mapping = {'Low': 0, 'Average': 1, 'High': 2}
        df['Spending_Score'] = df['Spending_Score'].map(mapping).fillna(0)

    # One-hot encode categorical columns
    for col in categorical_cols:
        if col in df.columns:
            if is_train:
                encoder = OneHotEncoder(sparse_output=False, handle_unknown='ignore')
                encoded = encoder.fit_transform(df[[col]])
                encoders[col] = encoder
            else:
                encoder = encoders[col]
                encoded = encoder.transform(df[[col]])

            feature_names = [f"{col}_{cat}" for cat in encoder.categories_[0]]
            encoded_df = pd.DataFrame(encoded, columns=feature_names, index=df.index)
            df = df.drop(col, axis=1)
            df = pd.concat([df, encoded_df], axis=1)

    # Scale numeric columns
    if is_train:
        scaler = StandardScaler()
        df[numerical_cols] = scaler.fit_transform(df[numerical_cols])
    else:
        df[numerical_cols] = scaler.transform(df[numerical_cols])

    return df, scaler, encoders


# ================================
# 🔹 SPLIT TRAIN / VALIDATION DATA
# ================================
def load_and_split_data(file_path, test_size=0.2, random_state=42):
    data = pd.read_csv(file_path)
    if 'ID' in data.columns:
        data = data.drop('ID', axis=1)

    if 'Segmentation' not in data.columns:
        raise ValueError("Target column 'Segmentation' not found in data")

    X = data.drop('Segmentation', axis=1)
    y = data['Segmentation']

    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=test_size, random_state=random_state, stratify=y
    )

    X_train_prep, scaler, encoders = preprocess_data(X_train, is_train=True)
    X_val_prep, _, _ = preprocess_data(X_val, is_train=False, scaler=scaler, encoders=encoders)

    return X_train_prep, X_val_prep, y_train, y_val, scaler, encoders


# ================================
# 🔹 TRAIN ONE-VS-ALL SVM
# ================================
def train_ova_svm(X_train, y_train):
    classes = sorted(y_train.unique())
    classifiers = {}

    print(f"\n🔹 Training {len(classes)} One-vs-All SVM classifiers...")
    for c in classes:
        y_binary = (y_train == c).astype(int)
        clf = SVC(kernel='rbf', probability=True, class_weight='balanced', random_state=42)
        clf.fit(X_train, y_binary)
        classifiers[c] = clf
        print(f"✅ Trained classifier for class: {c}")

    return classifiers, classes


# ================================
# 🔹 PREDICT USING TRAINED CLASSIFIERS
# ================================
def predict_with_model(classifiers, X, classes):
    probabilities = np.column_stack([
        clf.predict_proba(X)[:, 1] for clf in classifiers.values()
    ])
    pred_indices = np.argmax(probabilities, axis=1)
    predictions = [classes[i] for i in pred_indices]
    return predictions


# ================================
# 🔹 MODEL EVALUATION
# ================================
def evaluate_model(csv_path, save_plots=True):
    results = pd.read_csv(csv_path)
    y_true = results['actual']
    y_pred = results['predicted']

    print("\n📊 Model Evaluation Summary")
    accuracy = accuracy_score(y_true, y_pred)
    print(f"✅ Accuracy: {accuracy * 100:.2f}%")
    print("\n🔍 Classification Report:")
    print(classification_report(y_true, y_pred))

    # Confusion Matrix
    cm = confusion_matrix(y_true, y_pred)
    plt.figure(figsize=(6, 5))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues')
    plt.title("Confusion Matrix")
    plt.xlabel("Predicted Labels")
    plt.ylabel("True Labels")
    if save_plots:
        plt.savefig("confusion_matrix.png", bbox_inches='tight')
    plt.show()

    #  ROC Curves (Multi-class)
    classes = sorted(y_true.unique())
    y_true_bin = label_binarize(y_true, classes=classes)
    y_pred_bin = label_binarize(y_pred, classes=classes)
    n_classes = len(classes)

    fpr, tpr, roc_auc = {}, {}, {}

    for i in range(n_classes):
        fpr[i], tpr[i], _ = roc_curve(y_true_bin[:, i], y_pred_bin[:, i])
        roc_auc[i] = auc(fpr[i], tpr[i])

    # Micro-average ROC
    fpr["micro"], tpr["micro"], _ = roc_curve(y_true_bin.ravel(), y_pred_bin.ravel())
    roc_auc["micro"] = auc(fpr["micro"], tpr["micro"])

    # Macro-average ROC
    all_fpr = np.unique(np.concatenate([fpr[i] for i in range(n_classes)]))
    mean_tpr = np.zeros_like(all_fpr)
    for i in range(n_classes):
        mean_tpr += np.interp(all_fpr, fpr[i], tpr[i])
    mean_tpr /= n_classes

    fpr["macro"], tpr["macro"] = all_fpr, mean_tpr
    roc_auc["macro"] = auc(fpr["macro"], tpr["macro"])

    #  Plot ROC curves
    plt.figure(figsize=(8, 6))
    for i in range(n_classes):
        plt.plot(fpr[i], tpr[i], label=f"Class {classes[i]} (AUC = {roc_auc[i]:.2f})")
    plt.plot(fpr["micro"], tpr["micro"], linestyle=":", linewidth=3,
             label=f"Micro-average (AUC = {roc_auc['micro']:.2f})")
    plt.plot(fpr["macro"], tpr["macro"], linestyle=":", linewidth=3,
             label=f"Macro-average (AUC = {roc_auc['macro']:.2f})")

    plt.plot([0, 1], [0, 1], 'k--', lw=1)
    plt.xlabel("False Positive Rate")
    plt.ylabel("True Positive Rate")
    plt.title("ROC Curves for Multi-class Classification")
    plt.legend(loc="lower right")
    if save_plots:
        plt.savefig("roc_curves.png", bbox_inches='tight')
    plt.show()

    print("\n📁 Evaluation results saved as:")
    print(" - confusion_matrix.png")
    print(" - roc_curves.png\n")

    return {"accuracy": accuracy, "confusion_matrix": cm, "roc_auc": roc_auc}


# ================================
# 🔹 LEARNING CURVE PLOT
# ================================
def plot_learning_curves(model, X, y, cv=5, scoring='accuracy', train_sizes=np.linspace(0.1, 1.0, 6)):
    print("\n📘 Generating learning curves... (this may take some time)")

    train_sizes, train_scores, test_scores = learning_curve(
        estimator=model,
        X=X,
        y=y,
        cv=cv,
        scoring=scoring,
        n_jobs=-1,
        train_sizes=train_sizes,
        shuffle=True,
        random_state=42
    )

    train_mean = np.mean(train_scores, axis=1)
    test_mean = np.mean(test_scores, axis=1)

    plt.figure(figsize=(8, 6))
    plt.plot(train_sizes, train_mean, 'o-', label="Training score")
    plt.plot(train_sizes, test_mean, 'o-', label="Cross-validation score")

    plt.fill_between(train_sizes, train_mean - np.std(train_scores, axis=1), train_mean + np.std(train_scores, axis=1), alpha=0.1)
    plt.fill_between(train_sizes, test_mean - np.std(test_scores, axis=1), test_mean + np.std(test_scores, axis=1), alpha=0.1)

    plt.title("Learning Curves")
    plt.xlabel("Training Set Size")
    plt.ylabel(scoring.capitalize())
    plt.legend(loc="best")
    plt.grid(True)
    plt.tight_layout()
    plt.show()


# ================================
# 🔹 MAIN WORKFLOW
# ================================
if __name__ == "__main__":
    train_path = "Customer_train.csv"
    test_path = "Customer_test.csv"

    # 1️⃣ TRAIN
    X_train, X_val, y_train, y_val, scaler, encoders = load_and_split_data(train_path)
    classifiers, classes = train_ova_svm(X_train, y_train)

    # 2️⃣ VALIDATE
    print("\n🔍 Validating model...")
    y_val_pred = predict_with_model(classifiers, X_val, classes)

    val_results = pd.DataFrame({"actual": y_val.values, "predicted": y_val_pred})
    val_results.to_csv("validation_predictions.csv", index=False)
    print("✅ Validation predictions saved to validation_predictions.csv")

    # Evaluate validation results
    evaluate_model("validation_predictions.csv")

    # Plot learning curve for SVM
    model = SVC(kernel='rbf', class_weight='balanced', random_state=42)
    plot_learning_curves(model, X_train, y_train)

    # 3️⃣ PREDICT ON UNLABELED TEST DATA
    print("\n🚀 Running predictions on test data (no target)...")
    test_data = pd.read_csv(test_path)
    if 'ID' in test_data.columns:
        test_data = test_data.drop('ID', axis=1)
    X_test_prep, _, _ = preprocess_data(test_data, is_train=False, scaler=scaler, encoders=encoders)
    test_predictions = predict_with_model(classifiers, X_test_prep, classes)

    pd.DataFrame({"predicted": test_predictions}).to_csv("ova.csv", index=False)
    print("✅ Test predictions saved to test_predictions.csv")
