"""
Data preprocessing module for road anomaly detection.
Handles loading, cleaning, and feature engineering from CSV sensor data.
"""

import pandas as pd
import numpy as np
from pathlib import Path
from typing import List, Tuple, Optional


def load_csv_data(data_dir: str) -> pd.DataFrame:
    """
    Load all CSV files from the specified directory and combine them into a single DataFrame.
    
    Args:
        data_dir: Path to directory containing CSV files
        
    Returns:
        Combined DataFrame with all sensor data
    """
    data_path = Path(data_dir)
    csv_files = list(data_path.glob("*.csv"))
    
    if not csv_files:
        raise FileNotFoundError(f"No CSV files found in {data_dir}")
    
    dfs = []
    for file in csv_files:
        print(f"Loading {file.name}...")
        df = pd.read_csv(file)
        dfs.append(df)
    
    combined_df = pd.concat(dfs, ignore_index=True)
    print(f"Loaded {len(combined_df)} total records from {len(csv_files)} files")
    
    return combined_df


def preprocess_data(df: pd.DataFrame) -> pd.DataFrame:
    """
    Clean and preprocess the sensor data.
    
    Args:
        df: Raw sensor data DataFrame
        
    Returns:
        Preprocessed DataFrame
    """
    # Convert timestamp to datetime if it's a string
    if df['Timestamp'].dtype == 'object':
        df['Timestamp'] = pd.to_datetime(df['Timestamp'])
    
    # Remove any rows with missing values
    df = df.dropna()
    
    # Sort by timestamp
    df = df.sort_values('Timestamp').reset_index(drop=True)
    
    # Calculate time differences (useful for checking sampling rate)
    df['time_diff'] = df['Timestamp'].diff().dt.total_seconds()
    
    print(f"Preprocessed data shape: {df.shape}")
    print(f"Label distribution:\n{df['Label'].value_counts()}")
    
    return df


def create_windowed_features(
    df: pd.DataFrame,
    window_size: int = 50,
    overlap: int = 25
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Create windowed features from continuous sensor data for ML model training.
    
    Args:
        df: Preprocessed DataFrame
        window_size: Number of samples per window
        overlap: Number of overlapping samples between windows
        
    Returns:
        Tuple of (features, labels) arrays
    """
    features = []
    labels = []
    
    # Get unique labels and create mapping
    label_mapping = {label: idx for idx, label in enumerate(df['Label'].unique())}
    
    step = window_size - overlap
    i = 0
    
    while i + window_size <= len(df):
        window = df.iloc[i:i + window_size]
        
        # Extract acceleration components
        x_accel = window['X'].values
        y_accel = window['Y'].values
        z_accel = window['Z'].values
        
        # Calculate magnitude of acceleration
        magnitude = np.sqrt(x_accel**2 + y_accel**2 + z_accel**2)
        
        # Create feature vector with statistical features
        feature_vector = []
        
        # Raw statistics for each axis
        for axis_data in [x_accel, y_accel, z_accel, magnitude]:
            feature_vector.extend([
                np.mean(axis_data),
                np.std(axis_data),
                np.min(axis_data),
                np.max(axis_data),
                np.median(axis_data),
                np.percentile(axis_data, 25),
                np.percentile(axis_data, 75),
                np.var(axis_data),
            ])
        
        # Add frequency domain features (FFT)
        for axis_data in [x_accel, y_accel, z_accel]:
            fft_coeffs = np.fft.fft(axis_data)
            fft_magnitude = np.abs(fft_coeffs)
            feature_vector.extend([
                np.mean(fft_magnitude[:window_size//2]),
                np.max(fft_magnitude[:window_size//2]),
                np.std(fft_magnitude[:window_size//2]),
            ])
        
        features.append(feature_vector)
        
        # Determine dominant label in window (most common)
        window_labels = window['Label'].value_counts()
        dominant_label = window_labels.index[0]
        labels.append(label_mapping[dominant_label])
        
        i += step
    
    return np.array(features), np.array(labels)


def save_processed_data(
    X: np.ndarray,
    y: np.ndarray,
    label_mapping: dict,
    output_dir: str
) -> None:
    """
    Save processed features and labels to disk.
    
    Args:
        X: Feature array
        y: Label array
        label_mapping: Dictionary mapping label names to indices
        output_dir: Directory to save processed data
    """
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    np.save(output_path / 'X_features.npy', X)
    np.save(output_path / 'y_labels.npy', y)
    
    # Save label mapping
    import json
    with open(output_path / 'label_mapping.json', 'w') as f:
        json.dump(label_mapping, f)
    
    print(f"Saved processed data to {output_dir}")
    print(f"Features shape: {X.shape}")
    print(f"Labels shape: {y.shape}")


if __name__ == "__main__":
    # Example usage
    print("Data preprocessing module loaded successfully!")
    print("Use the functions in your Jupyter notebook or Python script.")
