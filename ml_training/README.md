# ML Training Pipeline for Road Anomaly Detection

This directory contains the complete Python-based machine learning pipeline for training models to detect road anomalies using accelerometer data collected from the Flutter app.

## Directory Structure

```
ml_training/
├── requirements.txt          # Python dependencies
├── README.md                # This file
├── src/                     # Source code modules
│   ├── data_preprocessing.py    # Data loading and feature engineering
│   └── model_training.py        # Model training functions
├── notebooks/               # Jupyter notebooks
│   └── train_model.ipynb    # Main training notebook (step-by-step guide)
├── data/                    # Data storage
│   ├── raw/                 # Place your CSV files here
│   └── processed/           # Processed features will be saved here
└── models/                  # Trained models will be saved here
```

## Quick Start Guide

### Step 1: Export Data from Flutter App

**For Android:**
```bash
# Connect your device via USB
adb devices

# Pull the sensor data files
adb pull /sdcard/Android/data/com.example.road_anomaly_collector/files/sensor_data_*.csv ./ml_training/data/raw/
```

**For iOS:**
1. Open Xcode and connect your device
2. Go to Window → Devices and Simulators
3. Select your device and find the app
4. Download the container or use File Sharing to export CSV files
5. Copy CSV files to `ml_training/data/raw/`

**Alternative Method (Manual):**
- Use the app's share functionality to email or transfer CSV files to your computer
- Place all CSV files in the `ml_training/data/raw/` folder

### Step 2: Setup Python Environment

```bash
# Navigate to the ml_training directory
cd ml_training

# Create a virtual environment (recommended)
python -m venv venv

# Activate the virtual environment
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Step 3: Run the Training Notebook

```bash
# Start Jupyter Lab
jupyter lab

# Open notebooks/train_model.ipynb
# Follow the step-by-step instructions in the notebook
```

Or run the training script directly:

```bash
python -c "
import sys
sys.path.append('src')
from data_preprocessing import load_csv_data, preprocess_data, create_windowed_features
from model_training import train_random_forest, save_model
import numpy as np
from sklearn.model_selection import train_test_split

# Load data
df = load_csv_data('data/raw')
df_clean = preprocess_data(df)

# Create features
X, y = create_windowed_features(df_clean, window_size=50, overlap=25)

# Split data
X_train, X_val, y_train, y_val = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

# Train model
model, metrics = train_random_forest(X_train, y_train, X_val, y_val)

# Save model
label_mapping = {idx: label for idx, label in enumerate(df['Label'].unique())}
save_model(model, 'models/road_anomaly_model.pkl', label_mapping)
"
```

## Understanding the Pipeline

### 1. Data Preprocessing (`src/data_preprocessing.py`)

The preprocessing module handles:
- **Loading**: Combines multiple CSV files into a single dataset
- **Cleaning**: Removes missing values and sorts by timestamp
- **Feature Engineering**: Creates statistical and frequency-domain features from raw accelerometer data:
  - Time-domain: mean, std, min, max, median, percentiles, variance
  - Frequency-domain: FFT magnitude statistics
  - Multi-axis: X, Y, Z axes plus acceleration magnitude

### 2. Model Training (`src/model_training.py`)

Three model types are available:
- **Random Forest**: Ensemble of decision trees (recommended starting point)
- **Gradient Boosting**: Sequential tree building with error correction
- **Neural Network**: Deep learning approach for complex patterns

### 3. Feature Extraction

Each window of sensor data (default: 50 samples ≈ 1 second) is converted into a feature vector containing:
- 8 statistical features × 4 axes (X, Y, Z, Magnitude) = 32 features
- 3 FFT features × 3 axes (X, Y, Z) = 9 features
- **Total: 41 features per window**

## Data Collection Best Practices

### For Quality Training Data:

1. **Balanced Classes**: Collect roughly equal amounts of data for each road condition
   - Normal/Pothole/Bump/ Rough patches
   - Aim for at least 500-1000 labeled samples per class

2. **Consistent Labeling**: 
   - Use the app's manual labeling feature consistently
   - Label data in real-time or immediately after collection
   - Be precise about when anomalies occur

3. **Diverse Conditions**:
   - Different speeds (20-60 km/h)
   - Various vehicle types
   - Different weather conditions (dry, wet)
   - Multiple road types (highway, city, rural)
   - Different phone positions (mounted, in pocket, in hand)

4. **Sampling Rate**:
   - The app collects at 50Hz (20ms intervals)
   - Maintain consistent sampling during collection
   - Avoid gaps in data recording

5. **Data Quantity**:
   - Minimum: 5,000 labeled samples total
   - Recommended: 20,000+ samples
   - More data generally leads to better model performance

## Model Deployment

### Option 1: Use Scikit-learn Model Directly
If you're building a backend service:
```python
import joblib
model = joblib.load('models/road_anomaly_model.pkl')
predictions = model.predict(new_features)
```

### Option 2: Convert to TensorFlow Lite
For mobile deployment:
```bash
# Install conversion tools
pip install skl2onnx onnx tf2onnx

# Convert scikit-learn → ONNX → TFLite
# See notebook cell for detailed steps
```

### Option 3: Retrain Keras Model
Train a Keras model directly for easier TFLite conversion:
```python
from model_training import train_neural_network
model, history = train_neural_network(X_train, y_train, X_val, y_val, 
                                       input_dim=41, num_classes=4)
model.save('models/road_anomaly.keras')

# Convert to TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()
with open('models/road_anomaly.tflite', 'wb') as f:
    f.write(tflite_model)
```

## Troubleshooting

### Common Issues:

**No CSV files found:**
- Ensure you've exported data from the Flutter app
- Check that files are in `data/raw/` directory
- Verify file names contain `.csv` extension

**Imbalanced classes warning:**
- Collect more data for underrepresented classes
- Use SMOTE or other oversampling techniques
- The Random Forest model uses `class_weight='balanced'` to handle this

**Low model accuracy:**
- Increase training data size
- Tune hyperparameters (n_estimators, max_depth, etc.)
- Try different models (Gradient Boosting, Neural Network)
- Review feature importance to understand what matters

**Memory errors:**
- Reduce window overlap
- Decrease window size
- Process data in batches

## Advanced Usage

### Hyperparameter Tuning

```python
from sklearn.model_selection import GridSearchCV

param_grid = {
    'n_estimators': [50, 100, 200],
    'max_depth': [10, 20, 30, None],
    'min_samples_split': [2, 5, 10]
}

grid_search = GridSearchCV(
    RandomForestClassifier(random_state=42),
    param_grid,
    cv=5,
    scoring='f1_weighted',
    n_jobs=-1
)

grid_search.fit(X_train, y_train)
print(f"Best parameters: {grid_search.best_params_}")
```

### Cross-Validation

```python
from sklearn.model_selection import cross_val_score

scores = cross_val_score(model, X, y, cv=5, scoring='f1_weighted')
print(f"Cross-validation scores: {scores}")
print(f"Mean F1: {scores.mean():.4f} (+/- {scores.std() * 2:.4f})")
```

## Next Steps

After training your model:

1. **Evaluate Performance**: Check precision, recall, and F1-score for each class
2. **Analyze Errors**: Look at misclassified samples to understand weaknesses
3. **Iterate**: Collect more targeted data based on error analysis
4. **Deploy**: Integrate the trained model back into your Flutter app
5. **Monitor**: Track model performance in production and retrain as needed

## Additional Resources

- [Scikit-learn Documentation](https://scikit-learn.org/)
- [TensorFlow Lite Guide](https://www.tensorflow.org/lite/guide)
- [Feature Engineering Best Practices](https://www.kaggle.com/learn/feature-engineering)
- [Imbalanced Learning](https://imbalanced-learn.org/stable/)

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review the Jupyter notebook for detailed examples
3. Examine error messages carefully
4. Ensure your data format matches the expected CSV structure

---

**Happy Training! 🚀**
