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


# ====================================================
# 🔹 DATA PREPROCESSING
# ====================================================
def preprocess_data(data, is_train=True, scaler=None, encoders=None):
    df = data.copy()

    categorical_cols = ['Ever_Married', 'Graduated', 'Profession', 'Var_1', 'Gender']
    ordinal_cols = ['Spending_Score']
    numerical_cols = ['Work_Experience', 'Family_Size', 'Age']

    if encoders is None:
        encoders = {}

    # Handle missing values
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


# ====================================================
# 🔹 LOAD AND SPLIT DATA
# ====================================================
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


# ====================================================
# 🔹 ONE-VS-ONE TRAINING
# ====================================================
def ovo_train(X_train, y_train):
    classes = sorted(y_train.unique())
    K = len(classes)
    n_classifiers = K * (K - 1) // 2
    classifiers = {}

    print(f"\n🔹 Training OvO SVM with {K} classes ({n_classifiers} binary classifiers total)")

    class_pairs = [(classes[i], classes[j]) for i in range(K) for j in range(i + 1, K)]

    for idx, (class_i, class_j) in enumerate(class_pairs):
        print(f"Training classifier {idx + 1}/{n_classifiers}: {class_i} vs {class_j}")
        mask = (y_train == class_i) | (y_train == class_j)
        X_pair = X_train[mask]
        y_pair = y_train[mask]
        y_binary = (y_pair == class_i).astype(int)

        clf = SVC(kernel='rbf', probability=True, class_weight='balanced', random_state=42)
        clf.fit(X_pair, y_binary)

        classifiers[(class_i, class_j)] = clf

    print("\n✅ OvO training completed successfully!")
    return classifiers, classes


# ====================================================
# 🔹 PREDICTION USING TRAINED OVO MODEL
# ====================================================
def ovo_predict(classifiers, classes, X):
    votes = np.zeros((len(X), len(classes)))
    class_to_idx = {cls: idx for idx, cls in enumerate(classes)}

    for (class_i, class_j), clf in classifiers.items():
        preds = clf.predict(X)
        for i, pred in enumerate(preds):
            if pred == 1:
                votes[i, class_to_idx[class_i]] += 1
            else:
                votes[i, class_to_idx[class_j]] += 1

    final_preds = [classes[np.argmax(votes[i])] for i in range(len(X))]
    return final_preds


# ====================================================
# 🔹 MODEL EVALUATION
# ====================================================
def evaluate_model(csv_path):
    results = pd.read_csv(csv_path)
    y_true = results['actual']
    y_pred = results['predicted']

    print("\n📊 Model Evaluation Summary")
    print(f"✅ Accuracy: {accuracy_score(y_true, y_pred) * 100:.2f}%")
    print(classification_report(y_true, y_pred))

    cm = confusion_matrix(y_true, y_pred)
    plt.figure(figsize=(6, 5))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues')
    plt.title("Confusion Matrix")
    plt.xlabel("Predicted")
    plt.ylabel("Actual")
    plt.savefig("confusion_matrix.png", bbox_inches='tight')
    plt.show()


# ====================================================
# 🔹 LEARNING CURVE
# ====================================================
def plot_learning_curves(model, X, y, cv=5, scoring='accuracy', train_sizes=np.linspace(0.1, 1.0, 6)):
    print("\n📘 Generating learning curves...")
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

    plt.figure(figsize=(8, 6))
    plt.plot(train_sizes, np.mean(train_scores, axis=1), 'o-', label="Training")
    plt.plot(train_sizes, np.mean(test_scores, axis=1), 'o-', label="Cross-validation")
    plt.fill_between(train_sizes,
                     np.mean(train_scores, axis=1) - np.std(train_scores, axis=1),
                     np.mean(train_scores, axis=1) + np.std(train_scores, axis=1),
                     alpha=0.1)
    plt.fill_between(train_sizes,
                     np.mean(test_scores, axis=1) - np.std(test_scores, axis=1),
                     np.mean(test_scores, axis=1) + np.std(test_scores, axis=1),
                     alpha=0.1)
    plt.title("Learning Curves")
    plt.xlabel("Training Set Size")
    plt.ylabel("Accuracy")
    plt.legend()
    plt.grid(True)
    plt.show()


# ====================================================
# 🔹 MAIN WORKFLOW
# ====================================================
if __name__ == "__main__":
    train_path = "Customer_train.csv"
    test_path = "Customer_test.csv"

    # 1️⃣ TRAIN MODEL AND SAVE
    X_train, X_val, y_train, y_val, scaler, encoders = load_and_split_data(train_path)
    classifiers, classes = ovo_train(X_train, y_train)

    with open("ovo_model.pkl", "wb") as f:
        pickle.dump({"classifiers": classifiers, "scaler": scaler, "encoders": encoders, "classes": classes}, f)
    print("💾 Saved trained OvO model to ovo_model.pkl")

    # 2️⃣ VALIDATION USING SAVED MODEL
    print("\n🔍 Running validation evaluation...")
    with open("ovo_model.pkl", "rb") as f:
        saved = pickle.load(f)
    classifiers = saved["classifiers"]
    scaler = saved["scaler"]
    encoders = saved["encoders"]
    classes = saved["classes"]

    preds_val = ovo_predict(classifiers, classes, X_val)
    pd.DataFrame({"actual": y_val, "predicted": preds_val}).to_csv("validation_predictions.csv", index=False)
    print("✅ Validation predictions saved to validation_predictions.csv")

    evaluate_model("validation_predictions.csv")

    model = SVC(kernel='rbf', class_weight='balanced', random_state=42)
    plot_learning_curves(model, X_train, y_train)

    # 3️⃣ TEST PREDICTION (UNLABELED DATA)
    print("\n🚀 Running predictions on test data...")
    test_data = pd.read_csv(test_path)
    if 'ID' in test_data.columns:
        test_data = test_data.drop('ID', axis=1)

    X_test_prep, _, _ = preprocess_data(test_data, is_train=False, scaler=scaler, encoders=encoders)
    preds_test = ovo_predict(classifiers, classes, X_test_prep)
    pd.DataFrame({"predicted": preds_test}).to_csv("ovo.csv", index=False)
    print("✅ Test predictions saved to test_predictions.csv")
