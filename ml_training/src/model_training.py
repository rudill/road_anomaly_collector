"""
Model training module for road anomaly detection.
Includes functions for training, evaluating, and saving ML models.
"""

import numpy as np
from pathlib import Path
from typing import Tuple, Dict, Any
import joblib


def train_random_forest(
    X_train: np.ndarray,
    y_train: np.ndarray,
    X_val: np.ndarray,
    y_val: np.ndarray,
    n_estimators: int = 100,
    max_depth: int = 20,
    random_state: int = 42
) -> Tuple[Any, Dict[str, float]]:
    """
    Train a Random Forest classifier for road anomaly detection.
    
    Args:
        X_train: Training features
        y_train: Training labels
        X_val: Validation features
        y_val: Validation labels
        n_estimators: Number of trees in the forest
        max_depth: Maximum depth of each tree
        random_state: Random seed for reproducibility
        
    Returns:
        Tuple of (trained model, metrics dictionary)
    """
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, classification_report
    
    print("Training Random Forest classifier...")
    
    model = RandomForestClassifier(
        n_estimators=n_estimators,
        max_depth=max_depth,
        random_state=random_state,
        n_jobs=-1,
        class_weight='balanced'  # Handle imbalanced classes
    )
    
    model.fit(X_train, y_train)
    
    # Evaluate on validation set
    y_pred = model.predict(X_val)
    
    metrics = {
        'accuracy': accuracy_score(y_val, y_pred),
        'precision': precision_score(y_val, y_pred, average='weighted'),
        'recall': recall_score(y_val, y_pred, average='weighted'),
        'f1_score': f1_score(y_val, y_pred, average='weighted')
    }
    
    print("\nValidation Results:")
    print(f"Accuracy: {metrics['accuracy']:.4f}")
    print(f"Precision: {metrics['precision']:.4f}")
    print(f"Recall: {metrics['recall']:.4f}")
    print(f"F1 Score: {metrics['f1_score']:.4f}")
    
    print("\nClassification Report:")
    print(classification_report(y_val, y_pred))
    
    return model, metrics


def train_gradient_boosting(
    X_train: np.ndarray,
    y_train: np.ndarray,
    X_val: np.ndarray,
    y_val: np.ndarray,
    n_estimators: int = 100,
    learning_rate: float = 0.1,
    max_depth: int = 5,
    random_state: int = 42
) -> Tuple[Any, Dict[str, float]]:
    """
    Train a Gradient Boosting classifier for road anomaly detection.
    
    Args:
        X_train: Training features
        y_train: Training labels
        X_val: Validation features
        y_val: Validation labels
        n_estimators: Number of boosting stages
        learning_rate: Learning rate shrinks the contribution of each classifier
        max_depth: Maximum depth of each tree
        random_state: Random seed for reproducibility
        
    Returns:
        Tuple of (trained model, metrics dictionary)
    """
    from sklearn.ensemble import GradientBoostingClassifier
    from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, classification_report
    
    print("Training Gradient Boosting classifier...")
    
    model = GradientBoostingClassifier(
        n_estimators=n_estimators,
        learning_rate=learning_rate,
        max_depth=max_depth,
        random_state=random_state
    )
    
    model.fit(X_train, y_train)
    
    # Evaluate on validation set
    y_pred = model.predict(X_val)
    
    metrics = {
        'accuracy': accuracy_score(y_val, y_pred),
        'precision': precision_score(y_val, y_pred, average='weighted'),
        'recall': recall_score(y_val, y_pred, average='weighted'),
        'f1_score': f1_score(y_val, y_pred, average='weighted')
    }
    
    print("\nValidation Results:")
    print(f"Accuracy: {metrics['accuracy']:.4f}")
    print(f"Precision: {metrics['precision']:.4f}")
    print(f"Recall: {metrics['recall']:.4f}")
    print(f"F1 Score: {metrics['f1_score']:.4f}")
    
    print("\nClassification Report:")
    print(classification_report(y_val, y_pred))
    
    return model, metrics


def train_neural_network(
    X_train: np.ndarray,
    y_train: np.ndarray,
    X_val: np.ndarray,
    y_val: np.ndarray,
    input_dim: int,
    num_classes: int,
    epochs: int = 50,
    batch_size: int = 32,
    verbose: int = 1
) -> Tuple[Any, Dict[str, list]]:
    """
    Train a simple neural network for road anomaly detection.
    
    Args:
        X_train: Training features
        y_train: Training labels
        X_val: Validation features
        y_val: Validation labels
        input_dim: Number of input features
        num_classes: Number of output classes
        epochs: Number of training epochs
        batch_size: Batch size for training
        verbose: Verbosity mode (0=silent, 1=progress bar, 2=one line per epoch)
        
    Returns:
        Tuple of (trained model, history dictionary)
    """
    import tensorflow as tf
    from tensorflow import keras
    from tensorflow.keras import layers
    from sklearn.preprocessing import StandardScaler
    
    print("Training Neural Network classifier...")
    
    # Normalize features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_val_scaled = scaler.transform(X_val)
    
    # Convert labels to categorical
    y_train_cat = keras.utils.to_categorical(y_train, num_classes)
    y_val_cat = keras.utils.to_categorical(y_val, num_classes)
    
    # Build model
    model = keras.Sequential([
        layers.Input(shape=(input_dim,)),
        layers.Dense(128, activation='relu'),
        layers.Dropout(0.3),
        layers.Dense(64, activation='relu'),
        layers.Dropout(0.3),
        layers.Dense(32, activation='relu'),
        layers.Dense(num_classes, activation='softmax')
    ])
    
    model.compile(
        optimizer='adam',
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    
    # Train model
    history = model.fit(
        X_train_scaled, y_train_cat,
        validation_data=(X_val_scaled, y_val_cat),
        epochs=epochs,
        batch_size=batch_size,
        verbose=verbose,
        callbacks=[
            keras.callbacks.EarlyStopping(
                monitor='val_loss',
                patience=10,
                restore_best_weights=True
            )
        ]
    )
    
    # Evaluate
    val_loss, val_accuracy = model.evaluate(X_val_scaled, y_val_cat, verbose=0)
    print(f"\nValidation Accuracy: {val_accuracy:.4f}")
    
    # Save scaler for later use
    joblib.dump(scaler, 'scaler.pkl')
    
    return model, history.history


def save_model(model: Any, model_path: str, label_mapping: Dict[str, int]) -> None:
    """
    Save trained model and label mapping to disk.
    
    Args:
        model: Trained model object
        model_path: Path to save the model
        label_mapping: Dictionary mapping label names to indices
    """
    output_path = Path(model_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    if hasattr(model, 'save'):
        # TensorFlow/Keras model
        model.save(str(output_path))
    else:
        # Scikit-learn model
        joblib.dump(model, str(output_path))
    
    # Save label mapping
    import json
    mapping_path = output_path.parent / 'label_mapping.json'
    with open(mapping_path, 'w') as f:
        json.dump(label_mapping, f)
    
    print(f"Model saved to {model_path}")
    print(f"Label mapping saved to {mapping_path}")


def load_model(model_path: str) -> Any:
    """
    Load a trained model from disk.
    
    Args:
        model_path: Path to the saved model
        
    Returns:
        Loaded model object
    """
    model_path = Path(model_path)
    
    if model_path.suffix == '.h5' or model_path.suffix == '.keras':
        import tensorflow as tf
        model = tf.keras.models.load_model(str(model_path))
    else:
        model = joblib.load(str(model_path))
    
    print(f"Model loaded from {model_path}")
    return model


if __name__ == "__main__":
    print("Model training module loaded successfully!")
    print("Use the functions in your Jupyter notebook or Python script.")
