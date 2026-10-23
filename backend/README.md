# Backend setup

The Flask backend provides the camera stream and Filipino text-to-speech.

## Run the web app locally

From the repository root, start the backend and Flutter web app together:

```powershell
powershell -ExecutionPolicy Bypass -File .\frontend\run_web.ps1
```

On first run, the launcher creates an isolated `backend\.venv` and installs the
backend requirements there. It does not modify packages in the system Python
environment.

This starts the local speech endpoint at `http://127.0.0.1:5000`. The app
detects that address automatically in Chrome; users do not need to enter a
server URL, access token, or Azure credentials. Select Filipino, leave Voice
source on Automatic, and use Test Voice.

Without Azure credentials, the backend uses `edge-tts` to request the selected
Microsoft Edge Filipino voice (`fil-PH-BlessicaNeural` or
`fil-PH-AngeloNeural`). This requires internet access and sends the text being
spoken to Microsoft's online speech service. `edge-tts` is an unofficial
client for that service; Microsoft can change or restrict it. For a configured
Azure Speech resource, set `AZURE_SPEECH_KEY` and `AZURE_SPEECH_REGION` on the
backend host; Azure is then used instead.

## Hosting

For a hosted web app, serve the speech endpoint on the same origin as the app
and set `TTS_ALLOWED_ORIGINS` on the backend to that exact HTTPS origin (for
example, `https://app.example.com`). The app will detect its service URL, so
end users do not need to enter a URL or token. For other remote clients, set a
long random `TTS_API_TOKEN` and configure it in advanced app settings. Requests
without a token are accepted only from loopback clients or an explicitly
allowlisted web origin. Origin checks are not a substitute for authentication;
use HTTPS and request quotas for public deployments.

## Offline speech

The app's offline mode uses Filipino speech voices installed in Android's
system text-to-speech engine. Use **Install** in app Settings to open Android's
voice-data installer, install Filipino speech data if the selected engine
offers it, then return to the app and refresh the voice list. The app does not
currently bundle a Tagalog neural model; model integration is a separate
inference task, and the candidate MMS Tagalog checkpoint is CC-BY-NC 4.0
licensed.
