import logging
import os
import cv2
import mediapipe as mp
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional

from tts_api import tts_api
from hand_tracker import HandTracker, HandValidationResult

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("tinigsenyas.backend")

app = FastAPI(
    title="TinigSenyas Backend API",
    description="Multimodal Sign Language Translation & Asynchronous OTA Synchronization Backend for KAINAKAP Inclusive and Opportunity Inc.",
    version="1.0.0",
)

# Enable CORS for Flutter web / mobile clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount TTS Router
app.include_router(tts_api)

# ---------------------------------------------------------------------------
# Over-The-Air (OTA) Synchronization Endpoints (Chapters 1 & 3 Specification)
# ---------------------------------------------------------------------------

class FSLVocabularyItem(BaseModel):
    fsl_id: int
    word: str
    meaning: str
    gesture_label: str
    video_path: Optional[str] = None
    created_at: Optional[str] = None

class ModelManifest(BaseModel):
    version: str
    url: str
    sha256: str
    min_app_version: str
    notes: str

# Default seeded FSL transactional vocabulary as described in Scope
_DEFAULT_VOCABULARY: List[FSLVocabularyItem] = [
    FSLVocabularyItem(fsl_id=1, word="Salamat", meaning="Pagpapahayag ng pasasalamat (Thank you)", gesture_label="salamat"),
    FSLVocabularyItem(fsl_id=2, word="Magkano", meaning="Pagtatanong ng presyo o bayad (How much)", gesture_label="magkano"),
    FSLVocabularyItem(fsl_id=3, word="Tulong", meaning="Humihingi ng saklolo o tulong (Help)", gesture_label="tulong"),
    FSLVocabularyItem(fsl_id=4, word="Kumusta", meaning="Pambungad na pagbati (Hello / How are you)", gesture_label="kumusta"),
    FSLVocabularyItem(fsl_id=5, word="Oo", meaning="Pagsang-ayon (Yes)", gesture_label="oo"),
    FSLVocabularyItem(fsl_id=6, word="Hindi", meaning="Pagtanggi (No)", gesture_label="hindi"),
    FSLVocabularyItem(fsl_id=7, word="Saan", meaning="Pagtatanong ng lokasyon o direksyon (Where)", gesture_label="saan"),
    FSLVocabularyItem(fsl_id=8, word="Pakiusap", meaning="Magalang na kahilingan (Please)", gesture_label="pakiusap"),
]

@app.get("/api/v1/ota/manifest", response_model=ModelManifest, tags=["OTA Updates"])
async def get_model_manifest():
    """
    Returns the latest ST-GCN quantized model metadata for mobile Over-The-Air deployment.
    """
    return ModelManifest(
        version="1.0.1",
        url="https://github.com/tinigsenyas/models/releases/download/v1.0.1/st_gcn_fsl_quantized.tflite",
        sha256="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        min_app_version="1.0.0",
        notes="Optimized ST-GCN quantized model for transactional FSL isolated gestures.",
    )

@app.get("/api/v1/ota/vocabulary", response_model=List[FSLVocabularyItem], tags=["OTA Updates"])
async def get_vocabulary_sync():
    """
    Asynchronous OTA dictionary synchronization endpoint.
    Updates the mobile client's localized SQLite database without disrupting core offline translation.
    """
    return _DEFAULT_VOCABULARY

# ---------------------------------------------------------------------------
# MediaPipe Camera Stream & Hand Tracking Diagnostics
# ---------------------------------------------------------------------------

latest_hand_result: Optional[HandValidationResult] = None
latest_hand_features: dict = {}
global_hand_tracker: Optional[HandTracker] = None


def generate_frames():
    global latest_hand_result, latest_hand_features, global_hand_tracker
    camera = cv2.VideoCapture(0)
    tracker = HandTracker(
        max_num_hands=2,
        min_detection_confidence=0.6,
        min_tracking_confidence=0.5,
        smoothing_alpha=0.7,
        mirror_camera=True,
    )
    global_hand_tracker = tracker

    try:
        while True:
            success, frame = camera.read()
            if not success:
                break

            processed_frame, result = tracker.process_frame(frame)
            latest_hand_result = result
            latest_hand_features = tracker.extract_model_features(result)

            ret, buffer = cv2.imencode(".jpg", processed_frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
            if not ret:
                continue
            frame_bytes = buffer.tobytes()

            yield (
                b"--frame\r\n"
                b"Content-Type: image/jpeg\r\n\r\n" + frame_bytes + b"\r\n"
            )
    finally:
        camera.release()
        tracker.close()


@app.get("/video_feed", tags=["Camera Stream"])
def video_feed():
    """
    Live MJPEG stream with MediaPipe multi-hand tracking, handedness classification,
    and horizontal Left-to-Right FOV diagnostic guidelines.
    """
    return StreamingResponse(
        generate_frames(),
        media_type="multipart/x-mixed-replace; boundary=frame",
    )


@app.get("/api/v1/hands/status", tags=["Hand Validation"])
def get_hand_status():
    """
    Real-time status of detected hands, left-to-right signing zones, and boundary warnings.
    """
    if latest_hand_result is None:
        return {
            "status": "idle",
            "hands_count": 0,
            "has_left_hand": False,
            "has_right_hand": False,
            "zones_covered": [],
            "edge_warning": False,
            "fps": 0.0,
        }

    return {
        "status": "tracking",
        "hands_count": latest_hand_result.hands_count,
        "has_left_hand": latest_hand_result.has_left_hand,
        "has_right_hand": latest_hand_result.has_right_hand,
        "zones_covered": latest_hand_result.zones_covered,
        "edge_warning": latest_hand_result.edge_warning,
        "fps": latest_hand_result.fps,
        "hands": [
            {
                "handedness": h.handedness,
                "confidence": h.confidence,
                "zone": h.zone,
                "center": h.center,
                "is_clipped": h.is_clipped,
            }
            for h in latest_hand_result.hands
        ],
    }


@app.get("/api/v1/hands/features", tags=["Hand Validation"])
def get_hand_features():
    """
    Structured landmark extraction coordinates for ST-GCN or FSL gesture classification models.
    """
    return latest_hand_features or {
        "hands_count": 0,
        "has_left_hand": False,
        "has_right_hand": False,
        "zones_covered": [],
        "left_hand": None,
        "right_hand": None,
    }

if __name__ == "__main__":
    uvicorn.run("server:app", host="0.0.0.0", port=5000, reload=False)
