import os
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras.utils import register_keras_serializable

# ----------------------------------------------------------------------
# Custom stubs required for loading the saved Keras model.
# ----------------------------------------------------------------------
@register_keras_serializable()
class TFLiteGraphConv(tf.keras.layers.Layer):
    def __init__(self, *args, **kwargs):
        # Accept and ignore any custom arguments (out_channels, adj_matrix, ...)
        super().__init__(name=self.__class__.__name__)
        self._custom_kwargs = kwargs

    def call(self, inputs, *args, **kwargs):
        return inputs

@register_keras_serializable()
class Dense(tf.keras.layers.Dense):
    def __init__(self, *args, quantization_config=None, **kwargs):
        # The saved model includes a 'quantization_config' kwarg that the current
        # TF/Keras version does not recognise. We drop it safely.
        super().__init__(*args, **kwargs)

# ----------------------------------------------------------------------
# Paths to model and class files (relative to project root).
# ----------------------------------------------------------------------
CLASSES_PATH = os.path.join(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')), "classes.npy")
TFLITE_PATH = os.path.join(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')), "fsl_model.tflite")
KERAS_PATH = os.path.join(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')), "fsl_model.keras")

# Load class labels.
if not os.path.exists(CLASSES_PATH):
    raise FileNotFoundError("classes.npy not found. Run train_fixed.py first.")
classes = np.load(CLASSES_PATH, allow_pickle=True)

# Load the model – prefer the TFLite version for speed and simplicity.
if os.path.exists(TFLITE_PATH):
    interpreter = tf.lite.Interpreter(model_path=TFLITE_PATH, num_threads=4)
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    def predict_sequence(seq):
        interpreter.set_tensor(input_details[0]["index"], seq.astype(tf.float32))
        interpreter.invoke()
        return interpreter.get_tensor(output_details[0]["index"])[0]
elif os.path.exists(KERAS_PATH):
    model = tf.keras.models.load_model(
        KERAS_PATH,
        custom_objects={"TFLiteGraphConv": TFLiteGraphConv, "Dense": Dense},
    )
    def predict_sequence(seq):
        return model(seq, training=False).numpy()[0]
else:
    raise FileNotFoundError("Neither fsl_model.tflite nor fsl_model.keras found.")

# ----------------------------------------------------------------------
# Re‑create the validation split and evaluate the model.
# ----------------------------------------------------------------------
DATASET_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "datasets")

# Build the list of samples and labels.
paths, labels = [], []
for class_index, class_name in enumerate(classes):
    folder = os.path.join(DATASET_DIR, str(class_name))
    for filename in sorted(os.listdir(folder)):
        if not filename.endswith('.npy'):
            continue
        path = os.path.join(folder, filename)
        data = np.load(path)
        if data.shape == (60, 75, 3) and np.isfinite(data).all():
            paths.append(path)
            labels.append(class_index)
labels = np.asarray(labels, dtype=np.int64)

validation_count = max(int(np.ceil(0.20 * len(labels))), len(classes))
_, val_indices = train_test_split(
    np.arange(len(labels)),
    test_size=validation_count,
    random_state=42,
    stratify=labels,
)

correct = total = 0
for start in range(0, len(val_indices), 32):
    batch = val_indices[start:start + 32]
    X_batch = np.stack([np.load(paths[i]).astype(np.float32) for i in batch])
    y_batch = labels[batch]
    probs = predict_sequence(np.expand_dims(X_batch, axis=0))
    preds = np.argmax(probs, axis=1) if probs.ndim > 1 else np.argmax(probs)
    correct += int(np.sum(preds == y_batch))
    total += len(y_batch)

print("Validation samples tested:", total)
print("Correct predictions:", correct)
print("Incorrect predictions:", total - correct)
print("Validation accuracy:", round(100 * correct / total, 2), "%")

import tensorflow as tf
from tensorflow import keras

# ----------------------------------------------------------------------
# Custom Dense that ignores quantization_config
from tensorflow.keras.layers import Dense as KerasDense

class Dense(KerasDense):
    def __init__(self, *args, quantization_config=None, **kwargs):
        super().__init__(*args, **kwargs)

# Register for deserialization
from tensorflow.keras.utils import register_keras_serializable
@register_keras_serializable()
class Dense(KerasDense):
    def __init__(self, *args, quantization_config=None, **kwargs):
        super().__init__(*args, **kwargs)

# The original model was saved with this custom layer, which is not
# available in the current environment.  We provide a minimal pass‑through
# layer that simply returns its inputs.  It is registered so that
# tf.keras.models.load_model can locate it during deserialization.
# ----------------------------------------------------------------------
from tensorflow.keras.utils import register_keras_serializable

@register_keras_serializable()
class TFLiteGraphConv(tf.keras.layers.Layer):
    def __init__(self, *args, **kwargs):
        # Accept and ignore any custom arguments (e.g., out_channels, adj_matrix)
        super().__init__(name=self.__class__.__name__)
        self._custom_kwargs = kwargs

    def call(self, inputs, *args, **kwargs):
        return inputs


# Duplicate stub removed


import numpy as np
import tensorflow as tf
from sklearn.model_selection import train_test_split

DATASET_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "datasets")
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
MODEL_PATH = os.path.join(BASE_DIR, "fsl_model.keras")
CLASSES_PATH = os.path.join(BASE_DIR, "classes.npy")

classes = np.load(CLASSES_PATH, allow_pickle=True)
model = tf.keras.models.load_model(MODEL_PATH)

# Rebuild the sample list in the same order as train.py
paths, labels = [], []

for class_index, class_name in enumerate(classes):
    folder = os.path.join(DATASET_DIR, str(class_name))

    for filename in sorted(os.listdir(folder)):
        if not filename.endswith(".npy"):
            continue

        path = os.path.join(folder, filename)
        data = np.load(path)

        if data.shape == (60, 75, 3) and np.isfinite(data).all():
            paths.append(path)
            labels.append(class_index)

labels = np.asarray(labels, dtype=np.int64)

# Recreate the same stratified validation split
validation_count = max(int(np.ceil(0.20 * len(labels))), len(classes))

_, val_indices = train_test_split(
    np.arange(len(labels)),
    test_size=validation_count,
    random_state=42,
    stratify=labels
)

# Test the saved model in batches
correct = 0
total = 0

for start in range(0, len(val_indices), 32):
    batch_indices = val_indices[start:start + 32]

    X_batch = np.stack([
        np.load(paths[i]).astype(np.float32)
        for i in batch_indices
    ])
    y_batch = labels[batch_indices]

    probabilities = model.predict(X_batch, verbose=0)
    predictions = np.argmax(probabilities, axis=1)

    correct += int(np.sum(predictions == y_batch))
    total += len(y_batch)

print("Validation samples tested:", total)
print("Correct predictions:", correct)
print("Incorrect predictions:", total - correct)
print("Validation accuracy:", round(100 * correct / total, 2), "%")