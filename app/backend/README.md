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
