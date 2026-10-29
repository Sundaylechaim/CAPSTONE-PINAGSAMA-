"""
TinigSenyas Interactive Hand Validation and Left-to-Right FOV Benchmark Tool.
Used to evaluate camera performance, handedness classification (Left vs. Right),
and landmark continuity across the horizontal signing space.

Run via:
    python validate_hand_tracking.py
"""

import json
import time
from datetime import datetime
import cv2
from hand_tracker import HandTracker


def run_hand_validation(camera_id: int = 0):
    print("=" * 65)
    print("  TinigSenyas: Real-Time Hand & FOV Validation Tool")
    print("=" * 65)
    print("Controls:")
    print("  [s] - Save Validation Report to 'hand_validation_report.json'")
    print("  [r] - Reset tracking counters")
    print("  [q] - Quit and print summary")
    print("=" * 65)

    cap = cv2.VideoCapture(camera_id)
    if not cap.isOpened():
        print(f"Error: Could not open camera {camera_id}.")
        return

    tracker = HandTracker(
        max_num_hands=2,
        min_detection_confidence=0.6,
        min_tracking_confidence=0.5,
        mirror_camera=True,
    )

    stats = {
        "started_at": datetime.now().isoformat(),
        "total_frames": 0,
        "frames_no_hand": 0,
        "frames_left_hand_only": 0,
        "frames_right_hand_only": 0,
        "frames_both_hands": 0,
        "zones_detected": {
            "Left Zone": 0,
            "Center Zone": 0,
            "Right Zone": 0,
        },
        "edge_clipping_events": 0,
    }

    start_time = time.time()

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                print("Failed to grab frame from camera.")
                break

            processed_frame, result = tracker.process_frame(frame)
            stats["total_frames"] += 1

            # Accumulate statistics
            if result.hands_count == 0:
                stats["frames_no_hand"] += 1
            elif result.hands_count == 1:
                if result.has_left_hand:
                    stats["frames_left_hand_only"] += 1
                elif result.has_right_hand:
                    stats["frames_right_hand_only"] += 1
            elif result.hands_count >= 2:
                stats["frames_both_hands"] += 1

            if result.edge_warning:
                stats["edge_clipping_events"] += 1

            for hand in result.hands:
                if hand.zone in stats["zones_detected"]:
                    stats["zones_detected"][hand.zone] += 1

            cv2.imshow("TinigSenyas - Hand FOV & Left-to-Right Validation", processed_frame)
            key = cv2.waitKey(1) & 0xFF

            if key == ord("q"):
                break
            elif key == ord("s"):
                _save_report(stats, tracker.fps, start_time)
            elif key == ord("r"):
                stats["total_frames"] = 0
                stats["frames_no_hand"] = 0
                stats["frames_left_hand_only"] = 0
                stats["frames_right_hand_only"] = 0
                stats["frames_both_hands"] = 0
                stats["zones_detected"] = {"Left Zone": 0, "Center Zone": 0, "Right Zone": 0}
                stats["edge_clipping_events"] = 0
                print("\n[Reset] Validation counters reset to 0.")

    finally:
        cap.release()
        tracker.close()
        cv2.destroyAllWindows()
        _print_summary(stats, tracker.fps, start_time)


def _compute_metrics(stats: dict, fps: float, start_time: float) -> dict:
    total = max(1, stats["total_frames"])
    elapsed = max(0.1, time.time() - start_time)

    hand_detection_rate = round(
        ((total - stats["frames_no_hand"]) / total) * 100, 2
    )
    both_hands_rate = round((stats["frames_both_hands"] / total) * 100, 2)
    clipping_rate = round((stats["edge_clipping_events"] / total) * 100, 2)

    return {
        "evaluation_duration_seconds": round(elapsed, 1),
        "average_fps": round(fps, 1),
        "total_frames_evaluated": total,
        "hand_detection_rate_pct": hand_detection_rate,
        "bilateral_two_hand_rate_pct": both_hands_rate,
        "edge_clipping_rate_pct": clipping_rate,
        "hand_distribution": {
            "no_hand_frames": stats["frames_no_hand"],
            "left_hand_only_frames": stats["frames_left_hand_only"],
            "right_hand_only_frames": stats["frames_right_hand_only"],
            "both_hands_frames": stats["frames_both_hands"],
        },
        "zone_distribution": stats["zones_detected"],
    }


def _save_report(stats: dict, fps: float, start_time: float, filename: str = "hand_validation_report.json"):
    report = {
        "title": "TinigSenyas Camera & Hand FOV Validation Benchmark",
        "timestamp": datetime.now().isoformat(),
        "metrics": _compute_metrics(stats, fps, start_time),
    }
    with open(filename, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print(f"\n[Saved] Validation report successfully saved to {filename}")


def _print_summary(stats: dict, fps: float, start_time: float):
    metrics = _compute_metrics(stats, fps, start_time)
    print("\n" + "=" * 65)
    print("  VALIDATION BENCHMARK SUMMARY")
    print("=" * 65)
    print(f"  Duration:            {metrics['evaluation_duration_seconds']}s")
    print(f"  Average FPS:         {metrics['average_fps']}")
    print(f"  Frames Evaluated:    {metrics['total_frames_evaluated']}")
    print(f"  Hand Detection Rate: {metrics['hand_detection_rate_pct']}%")
    print(f"  Two-Hand Rate:       {metrics['bilateral_two_hand_rate_pct']}%")
    print(f"  Edge Clipping Rate:  {metrics['edge_clipping_rate_pct']}%")
    print("-" * 65)
    print(f"  Horizontal Zone Coverage:")
    for zone, count in metrics["zone_distribution"].items():
        print(f"    - {zone}: {count} occurrences")
    print("=" * 65)


if __name__ == "__main__":
    run_hand_validation()

