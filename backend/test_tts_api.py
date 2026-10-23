import json
import os
import unittest
from unittest.mock import patch

from flask import Flask

from tts_api import tts_api


class TtsApiTests(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        self.app.register_blueprint(tts_api)
        self.client = self.app.test_client()
        self.environment = patch.dict(
            os.environ,
            {
                "TTS_API_TOKEN": "test-token",
                "AZURE_SPEECH_KEY": "speech-key",
                "AZURE_SPEECH_REGION": "eastus",
            },
        )
        self.environment.start()

    def tearDown(self):
        self.environment.stop()

    def test_rejects_requests_without_access_token(self):
        response = self.client.post(
            "/tts/synthesize",
            json={"text": "Kumusta"},
            environ_base={"REMOTE_ADDR": "192.0.2.25"},
        )

        self.assertEqual(response.status_code, 401)
    def test_rejects_incorrect_access_token(self):
        response = self.client.post(
            "/tts/synthesize",
            headers={"Authorization": "Bearer wrong-token"},
            json={"text": "Kumusta"},
            environ_base={"REMOTE_ADDR": "192.0.2.25"},
        )

        self.assertEqual(response.status_code, 401)
    def test_allows_local_edge_tts_without_azure_credentials_or_client_token(self):
        with (
            patch.dict(
                os.environ,
                {
                    "TTS_API_TOKEN": "",
                    "AZURE_SPEECH_KEY": "",
                    "AZURE_SPEECH_REGION": "",
                },
            ),
            patch(
                "tts_api._synthesize_edge_tts_audio",
                return_value=b"edge-mp3",
            ) as synthesize,
        ):
            response = self.client.post(
                "/tts/synthesize",
                json={
                    "text": "Kumusta",
                    "voice": "fil-PH-BlessicaNeural",
                    "rate": 10,
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.mimetype, "audio/mpeg")
        self.assertEqual(response.data, b"edge-mp3")
        synthesize.assert_called_once_with(
            "Kumusta",
            "fil-PH-BlessicaNeural",
            10,
        )

    def test_requires_token_for_nonlocal_clients_without_server_token(self):
        with patch.dict(os.environ, {"TTS_API_TOKEN": ""}):
            response = self.client.post(
                "/tts/synthesize",
                json={"text": "Kumusta"},
                environ_base={"REMOTE_ADDR": "192.0.2.25"},
            )

        self.assertEqual(response.status_code, 401)

    def test_rejects_cross_origin_requests_without_server_token(self):
        with patch.dict(os.environ, {"TTS_API_TOKEN": ""}):
            response = self.client.post(
                "/tts/synthesize",
                headers={"Origin": "https://attacker.example"},
                json={"text": "Kumusta"},
            )

        self.assertEqual(response.status_code, 401)

    def test_allows_configured_web_origin_without_client_token(self):
        with (
            patch.dict(
                os.environ,
                {
                    "TTS_API_TOKEN": "",
                    "TTS_ALLOWED_ORIGINS": "https://app.example.com",
                    "AZURE_SPEECH_KEY": "",
                    "AZURE_SPEECH_REGION": "",
                },
            ),
            patch(
                "tts_api._synthesize_edge_tts_audio",
                return_value=b"edge-mp3",
            ),
        ):
            response = self.client.post(
                "/tts/synthesize",
                headers={"Origin": "https://app.example.com"},
                json={"text": "Kumusta"},
                environ_base={"REMOTE_ADDR": "192.0.2.25"},
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data, b"edge-mp3")

    def test_rejects_unsupported_voice_without_calling_provider(self):
        with patch("tts_api.urlopen") as urlopen:
            response = self.client.post(
                "/tts/synthesize",
                headers={"Authorization": "Bearer test-token"},
                json={"text": "Kumusta", "voice": "en-US"},
            )

        self.assertEqual(response.status_code, 400)
        urlopen.assert_not_called()

    def test_synthesizes_filipino_voice_as_mp3(self):
        fake_response = unittest.mock.MagicMock()
        fake_response.__enter__.return_value.read.return_value = b"mp3-audio"
        with patch("tts_api.urlopen", return_value=fake_response) as urlopen:
            response = self.client.post(
                "/tts/synthesize",
                headers={"Authorization": "Bearer test-token"},
                json={
                    "text": 'Kumusta & <kaibigan>',
                    "voice": "fil-PH-BlessicaNeural",
                    "rate": -10,
                },
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.mimetype, "audio/mpeg")
        self.assertEqual(response.data, b"mp3-audio")
        provider_request = urlopen.call_args.args[0]
        self.assertEqual(
            provider_request.get_header("Ocp-apim-subscription-key"),
            "speech-key",
        )
        ssml = provider_request.data.decode("utf-8")
        self.assertIn('voice name="fil-PH-BlessicaNeural"', ssml)
        self.assertIn("Kumusta &amp; &lt;kaibigan&gt;", ssml)
        self.assertIn('rate="-10%"', ssml)

    def test_maps_edge_provider_errors_to_bad_gateway(self):
        from tts_api import TtsProviderError

        with (
            patch.dict(
                os.environ,
                {"AZURE_SPEECH_KEY": "", "AZURE_SPEECH_REGION": ""},
            ),
            patch(
                "tts_api._synthesize_edge_tts_audio",
                side_effect=TtsProviderError("provider unavailable"),
            ),
        ):
            response = self.client.post(
                "/tts/synthesize",
                headers={"Authorization": "Bearer test-token"},
                json={"text": "Kumusta"},
            )

        self.assertEqual(response.status_code, 502)
        self.assertEqual(
            json.loads(response.data)["error"],
            "The speech provider is currently unavailable.",
        )

if __name__ == "__main__":
    unittest.main()
