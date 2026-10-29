import os
import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

# ============================================================
# TINIGSENYAS - KAGGLE VIDEO CONVERTER
# Extracts pose + hand landmarks into (60, 75, 3) arrays
# ============================================================

SOURCE_DIR = (
    "raw_videos"
)
OUTPUT_DIR = "datasets"

HAND_MODEL = "assets/hand_landmarker.task"
POSE_MODEL = "assets/pose_landmarker_lite.task"

SEQUENCE_LENGTH = 60
TOTAL_JOINTS = 75
COORDINATES = 3
VIDEO_EXTENSIONS = (".mp4", ".mov", ".avi", ".mkv")

# Keep these class names consistent with your original converter.
TWO_HANDED_CLASSES = {
    "Abo", "Abril", "Agosto", "Disyembre", "Enero",
    "Hulyo", "Hunyo", "Kasal na", "Kayumanggi", "Lila",
    "Linggo", "Mabagal", "Madilim", "Malamig", "Marso",
    "Nobyembre", "Ngayon", "Oktubre", "Pebrero", "Sabado",
    "Setyembre", "Tama"
}

INITIAL_MID_SHOULDER = np.array(
    [0.5, 0.5, 0.0], dtype=np.float32
)
INITIAL_SHOULDER_WIDTH = 0.20
MIN_SHOULDER_WIDTH = 0.05


def create_detectors():
    for model_path in (HAND_MODEL, POSE_MODEL):
        if not os.path.isfile(model_path):
            raise FileNotFoundError(
                f"Missing MediaPipe model: {model_path}"
            )

    hand_options = vision.HandLandmarkerOptions(
        base_options=python.BaseOptions(
            model_asset_path=HAND_MODEL
        ),
        num_hands=2,
        running_mode=vision.RunningMode.IMAGE,
    )

    pose_options = vision.PoseLandmarkerOptions(
        base_options=python.BaseOptions(
            model_asset_path=POSE_MODEL
        ),
        running_mode=vision.RunningMode.IMAGE,
    )

    hand_detector = vision.HandLandmarker.create_from_options(
        hand_options
    )

    try:
        pose_detector = vision.PoseLandmarker.create_from_options(
            pose_options
        )
    except Exception:
        hand_detector.close()
        raise

    return hand_detector, pose_detector


def normalize_points(landmarks, mid_shoulder, shoulder_width):
    points = np.asarray(
        [[lm.x, lm.y, lm.z] for lm in landmarks],
        dtype=np.float32
    )

    scale = max(float(shoulder_width), MIN_SHOULDER_WIDTH)
    return (points - mid_shoulder) / scale


def resample_sequence(sequence):
    if len(sequence) == 0:
        return None

    if len(sequence) == 1:
        return np.repeat(
            sequence, SEQUENCE_LENGTH, axis=0
        ).astype(np.float32)

    positions = np.linspace(
        0, len(sequence) - 1, SEQUENCE_LENGTH
    )
    lower = np.floor(positions).astype(int)
    upper = np.ceil(positions).astype(int)

    alpha = (positions - lower).astype(np.float32)
    alpha = alpha[:, None, None]

    return (
        (1.0 - alpha) * sequence[lower]
        + alpha * sequence[upper]
    ).astype(np.float32)


def convert_video(
    video_path,
    hand_detector,
    pose_detector,
    is_two_handed
):
    cap = cv2.VideoCapture(video_path)

    if not cap.isOpened():
        print(f"WARNING: Cannot open video: {video_path}")
        return None

    frames_joints = []

    mid_shoulder = INITIAL_MID_SHOULDER.copy()
    shoulder_width = INITIAL_SHOULDER_WIDTH

    smoothed_left = None
    smoothed_right = None
    smooth_alpha = 0.75

    frame_index = 0
    cached_pose_joints = np.zeros(
        (33, COORDINATES), dtype=np.float32
    )

    try:
        while True:
            ret, frame = cap.read()

            if not ret:
                break

            frame_index += 1

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(
                image_format=mp.ImageFormat.SRGB,
                data=rgb
            )

            hand_result = hand_detector.detect(mp_image)

            # Run pose detection every fourth frame and on
            # the first frame to reduce conversion time.
            if frame_index % 4 == 0 or frame_index == 1:
                pose_result = pose_detector.detect(mp_image)

                if pose_result.pose_landmarks:
                    pose_lms = pose_result.pose_landmarks[0]

                    left_shoulder = np.array(
                        [
                            pose_lms[11].x,
                            pose_lms[11].y,
                            pose_lms[11].z
                        ],
                        dtype=np.float32
                    )

                    right_shoulder = np.array(
                        [
                            pose_lms[12].x,
                            pose_lms[12].y,
                            pose_lms[12].z
                        ],
                        dtype=np.float32
                    )

                    width = float(
                        np.linalg.norm(
                            left_shoulder - right_shoulder
                        )
                    )

                    if width > MIN_SHOULDER_WIDTH:
                        mid_shoulder = (
                            left_shoulder + right_shoulder
                        ) / 2.0
                        shoulder_width = width

                    cached_pose_joints = normalize_points(
                        pose_lms,
                        mid_shoulder,
                        shoulder_width
                    )

            # 33 pose + 21 left-hand + 21 right-hand joints
            joints = np.zeros(
                (TOTAL_JOINTS, COORDINATES),
                dtype=np.float32
            )

            joints[:33] = cached_pose_joints

            if (
                hand_result.hand_landmarks
                and hand_result.handedness
            ):
                detected = hand_result.hand_landmarks
                handedness = hand_result.handedness

                if is_two_handed and len(detected) >= 2:
                    for hand_lms, hand_info in zip(
                        detected, handedness
                    ):
                        label = hand_info[0].category_name

                        hand_points = normalize_points(
                            hand_lms,
                            mid_shoulder,
                            shoulder_width
                        )

                        if label == "Left":
                            if smoothed_left is None:
                                smoothed_left = hand_points.copy()
                            else:
                                smoothed_left = (
                                    smooth_alpha * hand_points
                                    + (1.0 - smooth_alpha)
                                    * smoothed_left
                                )

                            joints[33:54] = smoothed_left

                        elif label == "Right":
                            if smoothed_right is None:
                                smoothed_right = hand_points.copy()
                            else:
                                smoothed_right = (
                                    smooth_alpha * hand_points
                                    + (1.0 - smooth_alpha)
                                    * smoothed_right
                                )

                            joints[54:75] = smoothed_right

                else:
                    # Preserve the original single-hand behavior.
                    best_hand = min(
                        detected,
                        key=lambda hand: float(
                            np.mean([lm.y for lm in hand])
                        )
                    )

                    hand_points = normalize_points(
                        best_hand,
                        mid_shoulder,
                        shoulder_width
                    )

                    if smoothed_right is None:
                        smoothed_right = hand_points.copy()
                    else:
                        smoothed_right = (
                            smooth_alpha * hand_points
                            + (1.0 - smooth_alpha)
                            * smoothed_right
                        )

                    smoothed_left = None
                    joints[54:75] = smoothed_right

            else:
                smoothed_left = None
                smoothed_right = None

            frames_joints.append(joints)

    finally:
        cap.release()

    if not frames_joints:
        return None

    sequence = np.asarray(
        frames_joints, dtype=np.float32
    )

    return resample_sequence(sequence)


def main():
    if not os.path.isdir(SOURCE_DIR):
        raise FileNotFoundError(
            f"Dataset folder not found: {SOURCE_DIR}"
        )

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    classes = sorted(
        name for name in os.listdir(SOURCE_DIR)
        if os.path.isdir(os.path.join(SOURCE_DIR, name))
    )

    total_videos = sum(
        1
        for class_name in classes
        for filename in os.listdir(
            os.path.join(SOURCE_DIR, class_name)
        )
        if filename.lower().endswith(VIDEO_EXTENSIONS)
    )

    print(f"Classes found: {len(classes)}")
    print(f"Videos found: {total_videos}")
    print(f"Output directory: {OUTPUT_DIR}")
    print("Starting conversion...\n")

    hand_detector, pose_detector = create_detectors()

    saved = 0
    skipped_existing = 0
    failed = 0
    processed = 0

    try:
        for class_name in classes:
            class_path = os.path.join(SOURCE_DIR, class_name)
            save_dir = os.path.join(OUTPUT_DIR, class_name)
            os.makedirs(save_dir, exist_ok=True)

            is_two_handed = (
                class_name in TWO_HANDED_CLASSES
            )

            video_files = sorted(
                filename
                for filename in os.listdir(class_path)
                if filename.lower().endswith(
                    VIDEO_EXTENSIONS
                )
            )

            for video_file in video_files:
                processed += 1

                stem = os.path.splitext(video_file)[0]
                output_path = os.path.join(
                    save_dir, f"{stem}.npy"
                )

                if os.path.exists(output_path):
                    skipped_existing += 1
                    continue

                video_path = os.path.join(
                    class_path, video_file
                )

                try:
                    sequence = convert_video(
                        video_path,
                        hand_detector,
                        pose_detector,
                        is_two_handed
                    )

                    if sequence is None:
                        failed += 1
                        continue

                    expected_shape = (
                        SEQUENCE_LENGTH,
                        TOTAL_JOINTS,
                        COORDINATES
                    )

                    if sequence.shape != expected_shape:
                        print(
                            f"WARNING: Unexpected shape "
                            f"{sequence.shape}: {video_path}"
                        )
                        failed += 1
                        continue

                    if not np.isfinite(sequence).all():
                        print(
                            f"WARNING: NaN/Inf found: "
                            f"{video_path}"
                        )
                        failed += 1
                        continue

                    np.save(output_path, sequence)
                    saved += 1

                except Exception as exc:
                    failed += 1
                    print(
                        f"\nERROR processing {video_path}: "
                        f"{type(exc).__name__}: {exc}"
                    )

                if processed % 25 == 0:
                    print(
                        f"Progress: {processed}/{total_videos} "
                        f"| Newly saved: {saved} "
                        f"| Existing skipped: {skipped_existing} "
                        f"| Failed: {failed}"
                    )

    finally:
        hand_detector.close()
        pose_detector.close()

    print("\n========== CONVERSION SUMMARY ==========")
    print(f"Videos discovered: {total_videos}")
    print(f"New sequences saved: {saved}")
    print(f"Existing sequences skipped: {skipped_existing}")
    print(f"Failed videos: {failed}")
    print(f"Output: {OUTPUT_DIR}")
    print("Expected sequence shape: (60, 75, 3)")


if __name__ == "__main__":
    main()