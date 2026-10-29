"""
train_fixed.py
Trains the ST-GCN classifier from datasets/<class_name>/*.npy.
Expected sample shape: (60, 75, 3).
"""
import os
import random
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models, regularizers
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau, ModelCheckpoint
from sklearn.model_selection import train_test_split
from sklearn.utils.class_weight import compute_class_weight

DATASET_DIR = "datasets"
SEQUENCE_LENGTH = 60
TOTAL_JOINTS = 75
COORDINATES = 3
INPUT_SHAPE = (SEQUENCE_LENGTH, TOTAL_JOINTS, COORDINATES)
SEED = 42

random.seed(SEED)
np.random.seed(SEED)
tf.random.set_seed(SEED)

def load_dataset():
    if not os.path.isdir(DATASET_DIR):
        raise FileNotFoundError(f"Dataset folder '{DATASET_DIR}' was not found.")

    X, y, class_names = [], [], []
    class_counts = {}
    class_dirs = sorted(
        d for d in os.listdir(DATASET_DIR)
        if os.path.isdir(os.path.join(DATASET_DIR, d))
    )

    for class_name in class_dirs:
        class_path = os.path.join(DATASET_DIR, class_name)
        valid_samples = []
        for file_name in sorted(os.listdir(class_path)):
            if not file_name.lower().endswith(".npy"):
                continue
            path = os.path.join(class_path, file_name)
            try:
                data = np.load(path, allow_pickle=False)
            except Exception as exc:
                print(f"Skipping unreadable file {path}: {exc}")
                continue
            if data.shape != INPUT_SHAPE:
                print(f"Skipping wrong shape {path}: {data.shape}")
                continue
            if not np.isfinite(data).all():
                print(f"Skipping NaN/Inf file: {path}")
                continue
            valid_samples.append(data.astype(np.float32))

        if not valid_samples:
            print(f"WARNING: Class '{class_name}' has no valid samples and will be excluded.")
            continue

        class_index = len(class_names)
        class_names.append(class_name)
        class_counts[class_name] = len(valid_samples)
        X.extend(valid_samples)
        y.extend([class_index] * len(valid_samples))

    if not X:
        raise ValueError("No valid samples found. Check datasets/ and sample shapes.")

    too_small = {name: count for name, count in class_counts.items() if count < 2}
    if too_small:
        details = ", ".join(f"{name}={count}" for name, count in too_small.items())
        raise ValueError(
            "Each class needs at least 2 valid samples for a stratified train/validation split. "
            f"Classes with fewer than 2: {details}"
        )

    X = np.stack(X).astype(np.float32)
    y = np.asarray(y, dtype=np.int64)
    np.save("classes.npy", np.asarray(class_names))
    print(f"Loaded {len(X)} valid samples across {len(class_names)} classes.")
    print("Per-class sample counts:")
    for name, count in class_counts.items():
        print(f"  {name}: {count}")
    return X, y, class_names

def build_adjacency(num_joints=TOTAL_JOINTS):
    A = np.eye(num_joints, dtype=np.float32)

    # Main body connections used by the original model.
    pose_edges = [
        (11, 12), (11, 13), (13, 15), (12, 14), (14, 16),
        (11, 23), (12, 24), (23, 24),
    ]
    hand_edges = [
        (0, 1), (1, 2), (2, 3), (3, 4),
        (0, 5), (5, 6), (6, 7), (7, 8),
        (5, 9), (9, 10), (10, 11), (11, 12),
        (9, 13), (13, 14), (14, 15), (15, 16),
        (13, 17), (17, 18), (18, 19), (19, 20), (0, 17),
    ]
    for u, v in pose_edges:
        A[u, v] = A[v, u] = 1.0
    for u, v in hand_edges:
        A[33 + u, 33 + v] = A[33 + v, 33 + u] = 1.0
        A[54 + u, 54 + v] = A[54 + v, 54 + u] = 1.0
    A[15, 33] = A[33, 15] = 1.0
    A[16, 54] = A[54, 16] = 1.0

    degree = np.sum(A, axis=1)
    inv_sqrt = np.zeros_like(degree)
    nonzero = degree > 0
    inv_sqrt[nonzero] = degree[nonzero] ** -0.5
    D = np.diag(inv_sqrt)
    return (D @ A @ D).astype(np.float32)

@tf.keras.utils.register_keras_serializable()
class TFLiteGraphConv(layers.Layer):
    def __init__(self, out_channels, adj_matrix, **kwargs):
        super().__init__(**kwargs)
        self.out_channels = int(out_channels)
        self.adj_matrix = np.asarray(adj_matrix, dtype=np.float32)
        self.A = tf.constant(self.adj_matrix, dtype=tf.float32)

    def build(self, input_shape):
        self.dense = layers.Dense(self.out_channels, use_bias=False)
        super().build(input_shape)

    def call(self, inputs):
        x_weight = self.dense(inputs)
        shape = tf.shape(inputs)
        batch_size, frames = shape[0], shape[1]
        x_reshaped = tf.reshape(x_weight, [-1, TOTAL_JOINTS, self.out_channels])
        x_graph = tf.matmul(self.A, x_reshaped)
        return tf.reshape(x_graph, [batch_size, frames, TOTAL_JOINTS, self.out_channels])

    def get_config(self):
        config = super().get_config()
        config.update({
            "out_channels": self.out_channels,
            "adj_matrix": self.adj_matrix.tolist(),
        })
        return config

def augment_sample(sample, rng):
    # Global scale augmentation around the normalized origin.
    result = sample.copy() * np.float32(rng.uniform(0.90, 1.10))

    # Add small noise only to joints that are nonzero in the current representation.
    # Missing landmarks are represented by all-zero joint vectors.
    valid_joint_mask = np.any(np.abs(result) > 1e-8, axis=2, keepdims=True)
    noise = rng.normal(0.0, 0.002, size=result.shape).astype(np.float32)
    result += noise * valid_joint_mask.astype(np.float32)
    return result.astype(np.float32)

def augment_training_data(X_train, y_train):
    rng = np.random.default_rng(SEED)
    X_aug = [sample for sample in X_train]
    y_aug = list(y_train)
    for sample, label in zip(X_train, y_train):
        X_aug.append(augment_sample(sample, rng))
        y_aug.append(label)
    return np.stack(X_aug).astype(np.float32), np.asarray(y_aug, dtype=np.int64)

def build_model(num_classes):
    adjacency = build_adjacency()
    inputs = layers.Input(shape=INPUT_SHAPE)
    x = layers.BatchNormalization()(inputs)
    x = TFLiteGraphConv(32, adjacency)(x)
    x = layers.Conv2D(32, kernel_size=(9, 1), padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.Dropout(0.5)(x)

    x = TFLiteGraphConv(64, adjacency)(x)
    x = layers.Conv2D(64, kernel_size=(9, 1), padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.Dropout(0.5)(x)

    x = layers.AveragePooling2D(pool_size=(1, TOTAL_JOINTS))(x)
    x = layers.Reshape((SEQUENCE_LENGTH, 64))(x)
    x = layers.Conv1D(128, kernel_size=5, padding="same", activation="relu")(x)
    x = layers.BatchNormalization()(x)
    x = layers.Dropout(0.3)(x)
    avg_pool = layers.GlobalAveragePooling1D()(x)
    max_pool = layers.GlobalMaxPooling1D()(x)
    x = layers.Concatenate()([avg_pool, max_pool])
    x = layers.Dense(128, activation="relu", kernel_regularizer=regularizers.l2(0.005))(x)
    x = layers.Dropout(0.4)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)
    return models.Model(inputs, outputs)

def main():
    X, y, class_names = load_dataset()
    num_classes = len(class_names)
    if num_classes < 2:
        raise ValueError("At least two classes with valid samples are required.")

    # Stratification needs enough validation samples to represent every class.
    validation_count = max(int(np.ceil(0.20 * len(y))), num_classes)
    if validation_count >= len(y) - num_classes:
        raise ValueError(
            "Not enough samples for a stratified validation split. Add more samples per class."
        )
    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=validation_count, random_state=SEED, stratify=y
    )
    print(f"Training samples before augmentation: {len(X_train)}")
    print(f"Validation samples: {len(X_val)}")

    X_train, y_train = augment_training_data(X_train, y_train)
    print(f"Training samples after augmentation: {len(X_train)}")

    unique_classes = np.unique(y_train)
    weights = compute_class_weight(class_weight="balanced", classes=unique_classes, y=y_train)
    class_weights = {int(k): float(v) for k, v in zip(unique_classes, weights)}

    model = build_model(num_classes)
    model.summary()
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=5e-4),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"],
    )

    callbacks = [
        ModelCheckpoint("best_fsl_model.keras", monitor="val_loss", save_best_only=True, verbose=1),
        EarlyStopping(monitor="val_loss", patience=12, restore_best_weights=True, verbose=1),
        ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=4, min_lr=1e-6, verbose=1),
    ]
    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=80,
        batch_size=16,
        class_weight=class_weights,
        callbacks=callbacks,
        verbose=1,
    )

    model.save("fsl_model.keras")
    print("Saved fsl_model.keras")
    print("Best checkpoint: best_fsl_model.keras")

    # Basic validation metrics for an initial sanity check.
    val_loss, val_accuracy = model.evaluate(X_val, y_val, verbose=0)
    print(f"Validation loss: {val_loss:.4f}; validation accuracy: {val_accuracy:.4f}")

    try:
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_bytes = converter.convert()
        with open("fsl_model.tflite", "wb") as f:
            f.write(tflite_bytes)
        print("Exported fsl_model.tflite")
    except Exception as exc:
        print(f"WARNING: TFLite conversion failed: {exc}")
        print("Keep fsl_model.keras; test TFLite conversion separately.")

if __name__ == "__main__":
    main()