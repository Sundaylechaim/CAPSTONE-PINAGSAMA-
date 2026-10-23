import asyncio
import html
import hmac
import os
import re
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

from flask import Blueprint, Response, current_app, jsonify, request

tts_api = Blueprint("tts_api", __name__)

_ALLOWED_VOICES = {
    "fil-PH-BlessicaNeural",
    "fil-PH-AngeloNeural",
}
_REGION_PATTERN = re.compile(r"^[a-z0-9-]+$")
_MAX_TEXT_LENGTH = 2000


@tts_api.get("/tts/health")
def tts_health():
    return jsonify(status="ok")


def _is_loopback_origin(origin: str | None) -> bool:
    if not origin:
        return True
    try:
        parsed_origin = urlsplit(origin)
    except ValueError:
        return False
    return (
        parsed_origin.scheme in {"http", "https"}
        and parsed_origin.hostname in {"localhost", "127.0.0.1", "::1"}
        and parsed_origin.username is None
        and parsed_origin.password is None
        and parsed_origin.path in {"", "/"}
        and not parsed_origin.query
        and not parsed_origin.fragment
    )


class TtsProviderError(RuntimeError):
    pass


def _synthesize_edge_tts_audio(text: str, voice: str, rate: int) -> bytes:
    import edge_tts

    async def synthesize() -> bytes:
        communicate = edge_tts.Communicate(
            text,
            voice,
            rate=f"{rate:+d}%",
        )
        audio = bytearray()
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio.extend(chunk["data"])
        return bytes(audio)

    try:
        return asyncio.run(asyncio.wait_for(synthesize(), timeout=45))
    except (
        edge_tts.exceptions.EdgeTTSException,
        OSError,
        asyncio.TimeoutError,
        TimeoutError,
    ) as error:
        raise TtsProviderError(str(error)) from error


@tts_api.post("/tts/synthesize")
def synthesize_speech():
    expected_token = os.environ.get("TTS_API_TOKEN", "")
    supplied_token = request.headers.get("Authorization", "")
    is_local_client = (
        request.remote_addr in {"127.0.0.1", "::1"}
        and _is_loopback_origin(request.headers.get("Origin"))
    )
    if not is_local_client:
        if expected_token:
            if not hmac.compare_digest(
                supplied_token,
                f"Bearer {expected_token}",
            ):
                return jsonify(error="Unauthorized TTS request."), 401
        else:
            allowed_origins = {
                origin.strip()
                for origin in os.environ.get("TTS_ALLOWED_ORIGINS", "").split(",")
                if origin.strip()
            }
            if request.headers.get("Origin") not in allowed_origins:
                return jsonify(error="A TTS access token is required."), 401

    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        return jsonify(error="Expected a JSON request body."), 400

    text = payload.get("text")
    voice = payload.get("voice", "fil-PH-BlessicaNeural")
    rate = payload.get("rate", 0)
    if not isinstance(text, str) or not text.strip():
        return jsonify(error="Text must not be empty."), 400
    if len(text) > _MAX_TEXT_LENGTH:
        return jsonify(error=f"Text must not exceed {_MAX_TEXT_LENGTH} characters."), 413
    if not isinstance(voice, str) or voice not in _ALLOWED_VOICES:
        return jsonify(error="Unsupported Filipino voice."), 400
    if isinstance(rate, bool) or not isinstance(rate, int) or not -50 <= rate <= 50:
        return jsonify(error="Rate must be an integer from -50 to 50."), 400

    speech_key = os.environ.get("AZURE_SPEECH_KEY", "")
    region = os.environ.get("AZURE_SPEECH_REGION", "")
    if not speech_key or not _REGION_PATTERN.fullmatch(region):
        try:
            audio = _synthesize_edge_tts_audio(text, voice, rate)
        except TtsProviderError as error:
            current_app.logger.warning(
                "Microsoft Edge TTS request failed: %s",
                error,
            )
            return jsonify(error="The speech provider is currently unavailable."), 502
        if not audio:
            return jsonify(error="The speech provider returned empty audio."), 502
        return Response(
            audio,
            mimetype="audio/mpeg",
            headers={"Cache-Control": "no-store"},
        )

    ssml = (
        '<speak version="1.0" xml:lang="fil-PH">'
        f'<voice name="{voice}"><prosody rate="{rate}%">'
        f"{html.escape(text)}"
        "</prosody></voice></speak>"
    )
    upstream = Request(
        f"https://{region}.tts.speech.microsoft.com/cognitiveservices/v1",
        data=ssml.encode("utf-8"),
        headers={
            "Ocp-Apim-Subscription-Key": speech_key,
            "Content-Type": "application/ssml+xml",
            "X-Microsoft-OutputFormat": "audio-24khz-48kbitrate-mono-mp3",
        },
        method="POST",
    )

    try:
        with urlopen(upstream, timeout=20) as response:
            audio = response.read()
    except HTTPError as error:
        current_app.logger.warning("Azure Speech returned HTTP %s", error.code)
        return jsonify(error="The speech provider rejected the request."), 502
    except (URLError, TimeoutError) as error:
        current_app.logger.warning("Azure Speech request failed: %s", error)
        return jsonify(error="The speech provider is currently unavailable."), 502

    if not audio:
        return jsonify(error="The speech provider returned empty audio."), 502
    return Response(audio, mimetype="audio/mpeg", headers={"Cache-Control": "no-store"})
