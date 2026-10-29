"""
TinigSenyas Hand Tracking and Field-of-View (FOV) Validation Module.
Provides robust multi-hand detection, handedness validation (Left vs. Right),
per-hand jitter smoothing, horizontal zone analysis (Left to Right),
and boundary clipping alerts for Filipino Sign Language (FSL) translation.
"""

from dataclasses import dataclass, field
import time
from typing import Dict, List, Optional, Tuple
import cv2
import mediapipe as mp
import numpy as np


@dataclass
class HandInfo:
    handedness: str  # "Left" or "Right"
    confidence: float
    zone: str  # "Left Zone", "Center Zone", or "Right Zone"
    bbox: Tuple[int, int, int, int]  # (xmin, ymin, xmax, ymax) in pixels
    center: Tuple[float, float]  # Normalized (cx, cy)
    is_clipped: bool
    landmarks: List[Dict[str, float]]  # 21 points with x, y, z


@dataclass
class HandValidationResult:
    detected: bool
    hands_count: int
    hands: List[HandInfo] = field(default_factory=list)
    has_left_hand: bool = False
    has_right_hand: bool = False
    fps: float = 0.0
    edge_warning: bool = False
    zones_covered: List[str] = field(default_factory=list)


class HandTracker:
    def __init__(
        self,
        max_num_hands: int = 2,
        min_detection_confidence: float = 0.6,
        min_tracking_confidence: float = 0.5,
        smoothing_alpha: float = 0.7,
        mirror_camera: bool = True,
    ):
        self.max_num_hands = max_num_hands
        self.min_detection_confidence = min_detection_confidence
        self.min_tracking_confidence = min_tracking_confidence
        self.smoothing_alpha = smoothing_alpha
        self.mirror_camera = mirror_camera

        self.mp_hands = mp.solutions.hands
        self.mp_draw = mp.solutions.drawing_utils
        self.hands_detector = self.mp_hands.Hands(
            static_image_mode=False,
            max_num_hands=self.max_num_hands,
            min_detection_confidence=self.min_detection_confidence,
            min_tracking_confidence=self.min_tracking_confidence,
        )

        # Independent landmark history per hand to avoid cross-hand jitter
        self.prev_landmarks: Dict[str, Optional[List[Tuple[float, float, float]]]] = {
            "Left": None,
            "Right": None,
        }
        self.missed_frames: Dict[str, int] = {"Left": 0, "Right": 0}

        # FPS tracking
        self._prev_time = time.time()
        self.fps = 0.0

    def process_frame(self, frame: np.ndarray) -> Tuple[np.ndarray, HandValidationResult]:
        """
        Processes a single BGR camera frame:
        1. Mirrors frame if enabled.
        2. Detects hands and extracts landmarks.
        3. Identifies Left vs Right hand with independent smoothing.
        4. Validates horizontal position (Left, Center, Right zones).
        5. Returns the processed frame and structured validation result.
        """
        current_time = time.time()
        dt = current_time - self._prev_time
        if dt > 0:
            self.fps = 0.9 * self.fps + 0.1 * (1.0 / dt) if self.fps > 0 else 1.0 / dt
        self._prev_time = current_time

        if self.mirror_camera:
            frame = cv2.flip(frame, 1)

        h, w, _ = frame.shape
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = self.hands_detector.process(rgb_frame)

        validation_result = HandValidationResult(
            detected=False,
            hands_count=0,
            hands=[],
            fps=round(self.fps, 1),
        )

        seen_hands = set()

        if results.multi_hand_landmarks and results.multi_handedness:
            validation_result.detected = True
            validation_result.hands_count = len(results.multi_hand_landmarks)

            for idx, hand_landmarks in enumerate(results.multi_hand_landmarks):
                # Retrieve handedness label
                classification = results.multi_handedness[idx].classification[0]
                handedness = classification.label  # "Left" or "Right"
                confidence = float(classification.score)
                seen_hands.add(handedness)

                # Smooth landmarks per hand
                smoothed_coords = self._smooth_landmarks(handedness, hand_landmarks.landmark)

                # Calculate bounding box & horizontal zone
                xs = [lm[0] for lm in smoothed_coords]
                ys = [lm[1] for lm in smoothed_coords]

                xmin_norm, xmax_norm = min(xs), max(xs)
                ymin_norm, ymax_norm = min(ys), max(ys)
                cx = (xmin_norm + xmax_norm) / 2.0
                cy = (ymin_norm + ymax_norm) / 2.0

                xmin_px = int(max(0, xmin_norm * w))
                xmax_px = int(min(w, xmax_norm * w))
                ymin_px = int(max(0, ymin_norm * h))
                ymax_px = int(min(h, ymax_norm * h))

                # Determine zone across horizontal field of view
                if cx < 0.35:
                    zone = "Left Zone"
                elif cx > 0.65:
                    zone = "Right Zone"
                else:
                    zone = "Center Zone"

                # Check edge clipping (within 4% of screen edges)
                is_clipped = (
                    xmin_norm < 0.04
                    or xmax_norm > 0.96
                    or ymin_norm < 0.04
                    or ymax_norm > 0.96
                )
                if is_clipped:
                    validation_result.edge_warning = True

                if zone not in validation_result.zones_covered:
                    validation_result.zones_covered.append(zone)

                landmarks_data = [
                    {"x": round(lm[0], 4), "y": round(lm[1], 4), "z": round(lm[2], 4)}
                    for lm in smoothed_coords
                ]

                hand_info = HandInfo(
                    handedness=handedness,
                    confidence=round(confidence, 3),
                    zone=zone,
                    bbox=(xmin_px, ymin_px, xmax_px, ymax_px),
                    center=(round(cx, 3), round(cy, 3)),
                    is_clipped=is_clipped,
                    landmarks=landmarks_data,
                )
                validation_result.hands.append(hand_info)

                if handedness == "Left":
                    validation_result.has_left_hand = True
                elif handedness == "Right":
                    validation_result.has_right_hand = True

                # Draw hand landmarks & boundary overlays onto frame
                self._draw_hand_overlay(frame, smoothed_coords, hand_info, w, h)

        # Reset history for hands that were not seen
        for hand_label in ["Left", "Right"]:
            if hand_label not in seen_hands:
                self.missed_frames[hand_label] += 1
                if self.missed_frames[hand_label] > 5:
                    self.prev_landmarks[hand_label] = None
            else:
                self.missed_frames[hand_label] = 0

        # Draw HUD diagnostic overlays (FOV zones, status header)
        self._draw_hud(frame, validation_result, w, h)

        return frame, validation_result

    def _smooth_landmarks(
        self, handedness: str, raw_landmarks
    ) -> List[Tuple[float, float, float]]:
        """
        Applies exponential moving average to hand landmarks independently.
        """
        prev = self.prev_landmarks[handedness]
        smoothed = []
        alpha = self.smoothing_alpha

        for i, lm in enumerate(raw_landmarks):
            curr_x, curr_y, curr_z = lm.x, lm.y, lm.z
            if prev is not None and i < len(prev):
                prev_x, prev_y, prev_z = prev[i]
                sx = prev_x * (1 - alpha) + curr_x * alpha
                sy = prev_y * (1 - alpha) + curr_y * alpha
                sz = prev_z * (1 - alpha) + curr_z * alpha
            else:
                sx, sy, sz = curr_x, curr_y, curr_z
            smoothed.append((sx, sy, sz))

        self.prev_landmarks[handedness] = smoothed
        return smoothed

    def _draw_hand_overlay(
        self,
        frame: np.ndarray,
        landmarks: List[Tuple[float, float, float]],
        hand_info: HandInfo,
        w: int,
        h: int,
    ):
        """
        Draws distinctive landmarks, bounding box, and handedness label.
        Blue for Left Hand, Amber/Yellow for Right Hand (TinigSenyas palette).
        """
        # BGR Colors
        if hand_info.handedness == "Left":
            primary_color = (255, 60, 0)  # Bright Blue / Azure
            accent_color = (0, 200, 255)
        else:
            primary_color = (0, 200, 255)  # Bright Yellow / Gold
            accent_color = (255, 60, 0)

        if hand_info.is_clipped:
            primary_color = (0, 0, 255)  # Alert Red for boundary clipping

        # Draw skeletal connections manually using smoothed landmarks
        connections = self.mp_hands.HAND_CONNECTIONS
        for connection in connections:
            start_idx, end_idx = connection
            if start_idx < len(landmarks) and end_idx < len(landmarks):
                p1 = (int(landmarks[start_idx][0] * w), int(landmarks[start_idx][1] * h))
                p2 = (int(landmarks[end_idx][0] * w), int(landmarks[end_idx][1] * h))
                cv2.line(frame, p1, p2, primary_color, 2, cv2.LINE_AA)

        # Draw landmark points
        for i, lm in enumerate(landmarks):
            px = int(lm[0] * w)
            py = int(lm[1] * h)
            # Make wrist (0) and fingertips (4, 8, 12, 16, 20) slightly larger
            radius = 5 if i in (0, 4, 8, 12, 16, 20) else 3
            pt_color = accent_color if i in (0, 4, 8, 12, 16, 20) else (255, 255, 255)
            cv2.circle(frame, (px, py), radius, pt_color, -1, cv2.LINE_AA)

        # Draw bounding box with padding
        xmin, ymin, xmax, ymax = hand_info.bbox
        pad = 12
        b_xmin = max(0, xmin - pad)
        b_ymin = max(0, ymin - pad)
        b_xmax = min(w, xmax + pad)
        b_ymax = min(h, ymax + pad)

        cv2.rectangle(frame, (b_xmin, b_ymin), (b_xmax, b_ymax), primary_color, 2, cv2.LINE_AA)

        # Label tag
        confidence_pct = int(hand_info.confidence * 100)
        label_text = f"{hand_info.handedness.upper()} HAND ({confidence_pct}%) - {hand_info.zone}"
        if hand_info.is_clipped:
            label_text = f"CLIPPED! {label_text}"

        (tw, th), _ = cv2.getTextSize(label_text, cv2.FONT_HERSHEY_SIMPLEX, 0.45, 1)
        tag_ymin = max(0, b_ymin - th - 8)
        cv2.rectangle(
            frame,
            (b_xmin, tag_ymin),
            (min(w, b_xmin + tw + 10), b_ymin),
            primary_color,
            -1,
        )
        text_color = (0, 0, 0) if hand_info.handedness == "Right" else (255, 255, 255)
        cv2.putText(
            frame,
            label_text,
            (b_xmin + 5, tag_ymin + th + 2),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.45,
            text_color,
            1,
            cv2.LINE_AA,
        )

    def _draw_hud(self, frame: np.ndarray, result: HandValidationResult, w: int, h: int):
        """
        Draws horizontal Left-to-Right zone guidelines and top diagnostic bar.
        """
        # Vertical guidelines dividing signing space (Left 35% | Center 30% | Right 35%)
        x_left = int(w * 0.35)
        x_right = int(w * 0.65)

        overlay = frame.copy()
        # Draw subtle dashed/transparent zone delimiters
        cv2.line(overlay, (x_left, 36), (x_left, h), (180, 180, 180), 1, cv2.LINE_AA)
        cv2.line(overlay, (x_right, 36), (x_right, h), (180, 180, 180), 1, cv2.LINE_AA)

        # Semi-transparent top bar
        cv2.rectangle(overlay, (0, 0), (w, 36), (20, 24, 33), -1)
        cv2.addWeighted(overlay, 0.6, frame, 0.4, 0, frame)

        # Zone titles at top
        zone_color = (200, 200, 200)
        cv2.putText(frame, "LEFT ZONE", (int(w * 0.10), 24), cv2.FONT_HERSHEY_SIMPLEX, 0.4, zone_color, 1, cv2.LINE_AA)
        cv2.putText(frame, "PRIMARY SIGNING SPACE", (int(w * 0.41), 24), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 200, 255), 1, cv2.LINE_AA)
        cv2.putText(frame, "RIGHT ZONE", (int(w * 0.75), 24), cv2.FONT_HERSHEY_SIMPLEX, 0.4, zone_color, 1, cv2.LINE_AA)

        # Bottom status bar
        bot_overlay = frame.copy()
        cv2.rectangle(bot_overlay, (0, h - 30), (w, h), (15, 18, 25), -1)
        cv2.addWeighted(bot_overlay, 0.7, frame, 0.3, 0, frame)

        status_left = "DETECTED" if result.has_left_hand else "None"
        status_right = "DETECTED" if result.has_right_hand else "None"

        status_text = (
            f"Hands: {result.hands_count} | "
            f"Left: {status_left} | "
            f"Right: {status_right} | "
            f"FPS: {result.fps}"
        )

        cv2.putText(
            frame,
            status_text,
            (14, h - 10),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.45,
            (255, 255, 255),
            1,
            cv2.LINE_AA,
        )

        if result.edge_warning:
            alert_text = "WARNING: Hand near camera edge! Move toward center."
            (atw, _), _ = cv2.getTextSize(alert_text, cv2.FONT_HERSHEY_SIMPLEX, 0.45, 1)
            cv2.putText(
                frame,
                alert_text,
                (w - atw - 14, h - 10),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.45,
                (0, 80, 255),
                1,
                cv2.LINE_AA,
            )

    def extract_model_features(self, result: HandValidationResult) -> Dict:
        """
        Exports a normalized landmark representation ready for FSL gesture
        classification models (e.g. ST-GCN / LSTM / TFLite).
        Ensures consistent ordering: Left Hand (slot 0) and Right Hand (slot 1).
        """
        left_hand_data = None
        right_hand_data = None

        for hand in result.hands:
            if hand.handedness == "Left":
                left_hand_data = hand.landmarks
            elif hand.handedness == "Right":
                right_hand_data = hand.landmarks

        return {
            "hands_count": result.hands_count,
            "has_left_hand": result.has_left_hand,
            "has_right_hand": result.has_right_hand,
            "zones_covered": result.zones_covered,
            "left_hand": left_hand_data,
            "right_hand": right_hand_data,
        }

    def close(self):
        self.hands_detector.close()

