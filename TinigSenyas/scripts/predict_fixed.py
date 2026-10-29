
"""
predict_fixed.py
Live webcam inference for TinigSenyas.

Requires:
- classes.npy
- fsl_model.tflite (preferred) or fsl_model.keras
- hand_landmarker.task
- pose_landmarker_lite.task
"""

import os
import cv2
import numpy as np
import tensorflow as tf
import mediapipe as mp
from collections import deque
from mediapipe.tasks import python
from mediapipe.tasks.python import vision


# ---------------------------------------------------------
# Configuration
# ---------------------------------------------------------
SEQUENCE_LENGTH = 60
TOTAL_JOINTS = 75

BASE_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..")
)

CLASSES_PATH = os.path.join(BASE_DIR, "classes.npy")
TFLITE_PATH = os.path.join(BASE_DIR, "fsl_model.tflite")
KERAS_PATH = os.path.join(BASE_DIR, "fsl_model.keras")
HAND_LANDMARKER_PATH = os.path.join(
    BASE_DIR, "hand_landmarker.task"
)
POSE_LANDMARKER_PATH = os.path.join(
    BASE_DIR, "pose_landmarker_lite.task"
)

INITIAL_MID_SHOULDER = np.array(
    [0.5, 0.5, 0.0], dtype=np.float32
)
INITIAL_SHOULDER_WIDTH = 0.20
MIN_SHOULDER_WIDTH = 0.05

CONFIDENCE_THRESHOLD = 0.50
PREDICT_EVERY_N_FRAMES = 3
PROB_HISTORY_SIZE = 4
HAND_SMOOTH_ALPHA = 0.75

HAND_CONNECTIONS = [
    (0, 1), (1, 2), (2, 3), (3, 4),
    (0, 5), (5, 6), (6, 7), (7, 8),
    (5, 9), (9, 10), (10, 11), (11, 12),
    (9, 13), (13, 14), (14, 15), (15, 16),
    (13, 17), (17, 18), (18, 19), (19, 20),
    (0, 17),
]


def normalize_points(landmarks, mid_shoulder, shoulder_width):
    """Normalize landmarks relative to shoulder position and width."""
    pts = np.asarray(
        [[lm.x, lm.y, lm.z] for lm in landmarks],
        dtype=np.float32,
    )
    width = max(float(shoulder_width), MIN_SHOULDER_WIDTH)
    return (pts - mid_shoulder) / width


# ---------------------------------------------------------
# Check required files
# ---------------------------------------------------------
for path in (CLASSES_PATH, HAND_LANDMARKER_PATH,
             POSE_LANDMARKER_PATH):
    if not os.path.isfile(path):
        raise FileNotFoundError(
            f"Required file not found: {path}"
        )

classes = np.load(CLASSES_PATH, allow_pickle=True)

# ---------------------------------------------------------
# Load trained model
# ---------------------------------------------------------
if os.path.isfile(TFLITE_PATH):
    interpreter = tf.lite.Interpreter(
        model_path=TFLITE_PATH,
        num_threads=4,
    )
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    def predict_sequence(seq):
        interpreter.set_tensor(
            input_details[0]["index"],
            seq.astype(np.float32),
        )
        interpreter.invoke()
        return interpreter.get_tensor(
            output_details[0]["index"]
        )[0]

elif os.path.isfile(KERAS_PATH):
    # This fallback requires train_fixed.py and its custom layer.
    import sys
    sys.path.insert(0, os.path.dirname(__file__))
    from train_fixed import TFLiteGraphConv

    keras_model = tf.keras.models.load_model(
        KERAS_PATH,
        custom_objects={"TFLiteGraphConv": TFLiteGraphConv},
    )

    def predict_sequence(seq):
        return keras_model(
            seq, training=False
        ).numpy()[0]

else:
    raise FileNotFoundError(
        "Neither fsl_model.tflite nor fsl_model.keras was found."
    )


# ---------------------------------------------------------
# Initialize MediaPipe Tasks detectors
# ---------------------------------------------------------
hand_options = vision.HandLandmarkerOptions(
    base_options=python.BaseOptions(
        model_asset_path=HAND_LANDMARKER_PATH
    ),
    running_mode=vision.RunningMode.VIDEO,
    num_hands=2,
    min_hand_detection_confidence=0.5,
    min_hand_presence_confidence=0.5,
    min_tracking_confidence=0.5,
)

pose_options = vision.PoseLandmarkerOptions(
    base_options=python.BaseOptions(
        model_asset_path=POSE_LANDMARKER_PATH
    ),
    running_mode=vision.RunningMode.VIDEO,
    num_poses=1,
    min_pose_detection_confidence=0.5,
    min_pose_presence_confidence=0.5,
    min_tracking_confidence=0.5,
)

hand_detector = vision.HandLandmarker.create_from_options(
    hand_options
)
pose_detector = vision.PoseLandmarker.create_from_options(
    pose_options
)

# ---------------------------------------------------------
# Open webcam
# ---------------------------------------------------------
cap = cv2.VideoCapture(0)

if not cap.isOpened():
    hand_detector.close()
    pose_detector.close()
    raise RuntimeError(
        "Could not open webcam. Check camera access or try camera index 1."
    )

cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

frame_buffer = deque(maxlen=SEQUENCE_LENGTH)
prob_history = deque(maxlen=PROB_HISTORY_SIZE)

smoothed_left = None
smoothed_right = None

mid_shoulder = INITIAL_MID_SHOULDER.copy()
shoulder_width = INITIAL_SHOULDER_WIDTH
cached_pose_joints = np.zeros((33, 3), dtype=np.float32)

frame_idx = 0
missing_hand_count = 0
pred_label = "Status: Ready"
confidence_text = "Show a sign to the camera"

print("Model loaded successfully.")
print("MediaPipe hand and pose detectors initialized.")
print("Live FSL detection running. Press 'q' to quit.")

try:
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            print("Could not read a frame from the webcam.")
            break

        frame_idx += 1

        # MediaPipe Tasks expects an RGB image.
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_image = mp.Image(
            image_format=mp.ImageFormat.SRGB,
            data=rgb,
        )

        # VIDEO mode requires a monotonically increasing timestamp.
        timestamp_ms = int(frame_idx * 1000 / 30)

        # ---------------- Hand detection ----------------
        hand_result = hand_detector.detect_for_video(
            mp_image, timestamp_ms
        )

        detected_hands = hand_result.hand_landmarks or []
        handedness = hand_result.handedness or []

        # ---------------- Pose detection ----------------
        if frame_idx % 4 == 0 or frame_idx == 1:
            pose_result = pose_detector.detect_for_video(
                mp_image, timestamp_ms
            )

            if pose_result.pose_landmarks:
                pose_lms = pose_result.pose_landmarks[0]

                left_sh = np.array(
                    [
                        pose_lms[11].x,
                        pose_lms[11].y,
                        pose_lms[11].z,
                    ],
                    dtype=np.float32,
                )
                right_sh = np.array(
                    [
                        pose_lms[12].x,
                        pose_lms[12].y,
                        pose_lms[12].z,
                    ],
                    dtype=np.float32,
                )

                width = float(np.linalg.norm(left_sh - right_sh))

                if width > MIN_SHOULDER_WIDTH:
                    mid_shoulder = (left_sh + right_sh) / 2.0
                    shoulder_width = width

                cached_pose_joints = normalize_points(
                    pose_lms,
                    mid_shoulder,
                    shoulder_width,
                )

        # Assemble 33 pose + 21 left-hand + 21 right-hand points.
        joints = np.zeros((TOTAL_JOINTS, 3), dtype=np.float32)
        joints[:33] = cached_pose_joints

        h, w = frame.shape[:2]
        preview = cv2.flip(frame, 1)

        # Draw detected hands and their landmarks.
        for hand_lms, hand_info in zip(detected_hands, handedness):
            label = (
                hand_info[0].category_name
                if hand_info else "Unknown"
            )
            color = (
                (0, 255, 255)
                if label == "Right"
                else (255, 100, 0)
            )

            points = [
                (int((1.0 - lm.x) * w), int(lm.y * h))
                for lm in hand_lms
            ]

            for point in points:
                cv2.circle(preview, point, 3, color, -1)

            for a, b in HAND_CONNECTIONS:
                cv2.line(
                    preview, points[a], points[b], color, 2
                )

        # ---------------- Assemble hand slots ----------------
        if detected_hands:
            if len(detected_hands) >= 2:
                for hand_lms, hand_info in zip(
                    detected_hands, handedness
                ):
                    label = (
                        hand_info[0].category_name
                        if hand_info else "Unknown"
                    )

                    pts = normalize_points(
                        hand_lms, mid_shoulder, shoulder_width
                    )

                    if label == "Left":
                        smoothed_left = (
                            pts if smoothed_left is None
                            else HAND_SMOOTH_ALPHA * pts
                            + (1 - HAND_SMOOTH_ALPHA) * smoothed_left
                        )
                        joints[33:54] = smoothed_left
                    else:
                        smoothed_right = (
                            pts if smoothed_right is None
                            else HAND_SMOOTH_ALPHA * pts
                            + (1 - HAND_SMOOTH_ALPHA) * smoothed_right
                        )
                        joints[54:75] = smoothed_right

            else:
                # Single-hand signs are stored in the right-hand slot.
                hand_lms = detected_hands[0]
                pts = normalize_points(
                    hand_lms, mid_shoulder, shoulder_width
                )

                smoothed_right = (
                    pts if smoothed_right is None
                    else HAND_SMOOTH_ALPHA * pts
                    + (1 - HAND_SMOOTH_ALPHA) * smoothed_right
                )
                smoothed_left = None
                joints[54:75] = smoothed_right

            frame_buffer.append(joints)
            missing_hand_count = 0

            # Predict after collecting a full 60-frame sequence.
            if (
                len(frame_buffer) == SEQUENCE_LENGTH
                and frame_idx % PREDICT_EVERY_N_FRAMES == 0
            ):
                seq = np.expand_dims(
                    np.asarray(frame_buffer, dtype=np.float32),
                    axis=0,
                )

                probs = predict_sequence(seq)
                prob_history.append(probs)

                smoothed_probs = np.mean(
                    np.asarray(prob_history), axis=0
                )
                top_idxs = np.argsort(smoothed_probs)[::-1]

                top1 = int(top_idxs[0])
                top2 = int(
                    top_idxs[1] if len(top_idxs) > 1 else top1
                )

                conf1 = float(smoothed_probs[top1])
                conf2 = float(smoothed_probs[top2])

                name1 = str(classes[top1])
                name2 = str(classes[top2])

                pred_label = (
                    f"Sign: {name1}"
                    if conf1 >= CONFIDENCE_THRESHOLD
                    else f"Uncertain: {name1}"
                )
                confidence_text = (
                    f"Top: {conf1 * 100:.1f}% | "
                    f"Next: {name2} {conf2 * 100:.1f}%"
                )

        else:
            missing_hand_count += 1
            smoothed_left = None
            smoothed_right = None

            if missing_hand_count >= 8:
                frame_buffer.clear()
                prob_history.clear()
                pred_label = "Status: Idle (No hands)"
                confidence_text = "Show your hand to the camera"

        # ---------------- UI overlay ----------------
        cv2.rectangle(
            preview, (12, 12), (620, 104), (20, 20, 20), -1
        )
        cv2.putText(
            preview, pred_label, (22, 43),
            cv2.FONT_HERSHEY_SIMPLEX, 0.68, (0, 255, 0), 2,
        )
        cv2.putText(
            preview, confidence_text[:75], (22, 72),
            cv2.FONT_HERSHEY_SIMPLEX, 0.48, (230, 230, 230), 1,
        )
        cv2.putText(
            preview,
            f"Hands: {len(detected_hands)} | "
            f"Frames: {len(frame_buffer)}/{SEQUENCE_LENGTH}",
            (22, 94),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.42,
            (0, 255, 128),
            1,
        )

        cv2.imshow("TinigSenyas - Live FSL Prediction", preview)

        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

finally:
    cap.release()
    hand_detector.close()
    pose_detector.close()
    cv2.destroyAllWindows()
