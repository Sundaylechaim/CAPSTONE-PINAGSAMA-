# TinigSenyas: Filipino Sign Language (FSL) Translation & E-Learning Module

TinigSenyas is an interactive capstone project designed to bridge communication gaps for the Filipino deaf and hard-of-hearing community using real-time AI tracking and speech translation.

## Authors & Project Team
- **Ambuyo, Joycce Bernadeth** — Thesis Leader
- **Lagapa, John Laurence** — AI / Data Engineer
- **Nadonga, Sunday Le'chaim L.** — Mobile Developer
- **Suarilla, Ynewson** — UI/UX Designer

---

## Key Features
- **Sign-to-Text:** Real-time computer vision tracking for hand gestures via Python backend and Flask streaming.
- **Speech-to-Text:** Live browser-native voice transcription rendered into interactive chat bubbles.
- **Local Database:** SQLite integration for seamless translation history tracking.
- **Accessibility:** Built-in dark mode and adjustable typography scaling.

## Tech Stack & Dependencies

### Backend Dependencies (Python / Flask)
Managed via `pip`:
- **Flask** (Web server framework)
- **OpenCV-Python** (`opencv-python` - Computer vision and video processing)
- **MediaPipe** (`mediapipe` - Real-time hand, face, and posture tracking)

### Frontend Dependencies (Flutter / Dart)
Configured in `pubspec.yaml`:
- **`flutter`** (SDK Framework)
- **`speech_to_text`** (^6.6.2 - Browser-native voice transcription)
- **`sqflite`** (Local SQLite database storage for translation history)
- **`camera`** (Hardware camera interface)
- **`vector_math`** (Mathematical operations for UI components)

---

## How to Clone and Run

### Prerequisites
Make sure you have the following installed on your machine:
- [Git](https://git-scm.com/)
- [Python](https://www.python.org/) (with pip)
- [Flutter SDK](https://flutter.dev/)

### 1. Clone the Repository
Open your terminal and run:
```bash
git clone [https://github.com/Sundaylechaim/TinigSenyas.git](https://github.com/Sundaylechaim/TinigSenyas.git)
cd tinigsenyas


---

## Free Deployment, Offline & OTA Guide (No App Store Fees)

For community testing and sharing with KAINAKAP members via Google Drive:
- See the complete step-by-step guide: [docs/FREE_DEPLOYMENT_AND_OTA_GUIDE.md](docs/FREE_DEPLOYMENT_AND_OTA_GUIDE.md)
- **One-Click Android Build**: Run `frontend/build_android_apk.ps1` to compile the release APK and automatically open the file to upload to Google Drive.
- **iOS Free Installation**: Run as a PWA via Safari ("Add to Home Screen") or sideload via Sideloadly with a free Apple ID.
