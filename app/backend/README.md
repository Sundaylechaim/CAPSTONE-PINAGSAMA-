# TinigSenyas Backend API (FastAPI)

High-performance, asynchronous REST API serving text-to-speech synthesis, alpha camera landmark streaming, and Over-The-Air (OTA) FSL vocabulary and model synchronization for **TinigSenyas**.

Aligned with the architecture specified in **Chapters 1, 2, and 3** for the Capstone Project at Eulogio "Amang" Rodriguez Institute of Science and Technology (EARIST).

---

## Tech Stack Alignment

* **Framework**: FastAPI (Asynchronous ASGI Web Framework)
* **ASGI Server**: Uvicorn
* **Data Validation**: Pydantic v2
* **Computer Vision**: Google MediaPipe (Hands / Skeletal Topologies) & OpenCV
* **Speech Synthesis**: Edge-TTS (local loopback) & Azure Cognitive Speech Services

---

## Interactive API Documentation (Swagger / OpenAPI)

Once the backend is running, open your browser to view the interactive documentation:
* **Swagger UI**: [http://127.0.0.1:5000/docs](http://127.0.0.1:5000/docs)
* **ReDoc**: [http://127.0.0.1:5000/redoc](http://127.0.0.1:5000/redoc)

---

## Key Endpoints

### 1. Health & Status
* `GET /tts/health`: Validates that the backend service is alive and ready.

### 2. Auditory Synthesis
* `POST /tts/synthesize`: Generates high-quality synthesized Filipino speech (`fil-PH-BlessicaNeural` or `fil-PH-AngeloNeural`) via SSML/Edge-TTS.

### 3. Over-The-Air (OTA) Updates (Chapter 3 Specification)
* `GET /api/v1/ota/manifest`: Returns model versioning, SHA-256 integrity hash, and download URL for the quantized ST-GCN mobile package.
* `GET /api/v1/ota/vocabulary`: Asynchronously synchronizes validated FSL transactional phrases directly into the mobile SQLite database without disrupting offline translation.

### 4. Alpha Camera Tracking Stream
* `GET /video_feed`: Streams webcam frames with real-time MediaPipe skeletal landmark overlays for alpha testing.

### 5. Trained FSL Recognition
* `GET /api/v1/recognition/status`: Confirms that the trained FSL classifier and its landmark models are available.
* `POST /api/v1/recognition/frame`: Accepts one JPEG frame per request with an `X-Session-ID` header. The backend extracts 33 pose and 42 hand landmarks, applies the training-time shoulder normalization, buffers a 60-frame sequence, and returns a label once the model is confident.
* `DELETE /api/v1/recognition/session`: Releases the per-client landmark detectors and buffered frames when recognition stops.

The backend packages only the inference artifacts from `TinigSenyas_FULL_PROJECT/TinigSenyas`: `fsl_model.tflite`, `classes.npy`, and the two MediaPipe task models. The raw training videos and datasets are not needed at runtime. The app uses the configured backend URL in Settings for both recognition and speech.
Frames are processed in memory and are not written to disk. Recognition requests use the same backend token/origin checks as online speech; configure `TTS_API_TOKEN` for a mobile client or configure the hosted app origin with `TTS_ALLOWED_ORIGINS`. Use HTTPS for hosted deployments.

For Android local testing, set the app's Backend URL to `http://10.0.2.2:5000` in the emulator, or to the development computer's private LAN IP on a physical device. Non-loopback clients need the same `TTS_API_TOKEN` configured in the app's Backend access token field. The Android debug build permits local HTTP; release builds should use HTTPS.

---

## How to Run Locally

### Option A: Via the Web Launcher
From the repository root, start both the FastAPI backend and Flutter web application:
```powershell
powershell -ExecutionPolicy Bypass -File .\frontend\run_web.ps1
```

### Option B: Directly with Uvicorn
From the `backend` folder:
```powershell
.\.venv\Scripts\activate
uvicorn server:app --host 0.0.0.0 --port 5000 --reload
```

---

## Running Automated Tests
```powershell
.\.venv\Scripts\python.exe -m unittest test_tts_api.py
```
