# TinigSenyas: Filipino Sign Language (FSL) Translation & E-Learning Module

TinigSenyas is an interactive capstone project designed to bridge communication gaps for the Filipino deaf and hard-of-hearing community using real-time AI tracking and speech translation.

## 🚀 Key Features
- **Sign-to-Text:** FSL gesture recognition using MediaPipe landmarks and the trained TFLite model in the FastAPI backend.
- **Speech-to-Text:** Live browser-native voice transcription rendered into interactive chat bubbles.
- **Local Database:** SQLite integration for seamless translation history tracking.
- **Accessibility:** Built-in dark mode and adjustable typography scaling.

## 🛠️ Tech Stack
- **Frontend:** Flutter (Web/Desktop)
- **Backend:** Python, Flask, OpenCV, MediaPipe
- **Database:** SQLite

## FSL Recognition and Text-to-Speech

FSL recognition runs the trained TFLite model in the FastAPI backend. The app
sends sampled camera frames to the configured backend; frames are processed in
memory and are not saved. From the repository root, run
`powershell -ExecutionPolicy Bypass -File .\frontend\run_web.ps1` to start the
backend and web app. Local browser access detects the backend automatically.
Keep that PowerShell window open while using the app; closing it stops the
backend. Recognition waits until it detects a hand, collects a 60-frame sign
sequence, and then shows whether the result is recognized or uncertain. The
camera preview draws the MediaPipe 21-point hand skeleton as detection updates;
this tracking remains live while the classifier builds its sign sequence.
standalone `TinigSenyas_FULL_PROJECT\TinigSenyas\scripts\predict_fixed.py`
script is a webcam diagnostic; the app uses the same trained artifacts through
the FastAPI inference engine rather than launching that script.
For Android or a hosted deployment, configure the backend URL in Settings and
provide the backend access token when required. Use HTTPS for hosted servers.

On Chrome, Settings automatically detects the local speech backend. Run
`powershell -ExecutionPolicy Bypass -File .\frontend\run_web.ps1` from the
repository root to start the backend and app; no per-user Azure key, server
URL, or token is needed for local development.
Online Filipino speech uses Microsoft's Filipino neural voices and requires
internet access. Speech text is sent to Microsoft's service through the
backend; the fallback `edge-tts` client is unofficial and may stop working if
the provider changes its service. For hosted deployments, configure the backend
with the app's origin so users do not need to enter connection settings. Azure
Speech credentials stay on the backend.
Offline playback uses Filipino voices installed in the device's system TTS
engine. Android can optionally download the Kokoro English neural voice pack
from Settings (about 147 MB; about 194 MB installed). After download it works
offline and offers three female English voices alongside the system voices.
Select English (US) and the English female source to use it; it does not replace
the Filipino device voice. Kokoro-82M-v1.1-zh's weights are licensed under
Apache-2.0; the pack is published by the
[sherpa-onnx project](https://github.com/k2-fsa/sherpa-onnx) and downloaded on
demand rather than bundled in the APK.