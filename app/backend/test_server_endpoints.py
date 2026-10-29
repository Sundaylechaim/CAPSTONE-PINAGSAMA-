import os
import cv2
import unittest
import numpy as np
from fastapi.testclient import TestClient
from server import app
from unittest.mock import patch


class ServerEndpointTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app, client=("127.0.0.1", 50000))

    def test_ota_manifest(self):
        response = self.client.get("/api/v1/ota/manifest")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("version", data)
        self.assertIn("url", data)

    def test_ota_vocabulary(self):
        response = self.client.get("/api/v1/ota/vocabulary")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIsInstance(data, list)
        self.assertGreater(len(data), 0)

    def test_hands_status_idle(self):
        response = self.client.get("/api/v1/hands/status")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("hands_count", data)
        self.assertIn("has_left_hand", data)
        self.assertIn("has_right_hand", data)

    def test_hands_features_idle(self):
        response = self.client.get("/api/v1/hands/features")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("hands_count", data)
        self.assertIn("zones_covered", data)

    def test_fsl_recognition_status(self):
        response = self.client.get("/api/v1/recognition/status")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data["ready"])
        self.assertEqual(data["sequence_length"], 60)
        self.assertEqual(data["class_count"], 127)

    def test_recognition_rejects_non_jpeg_frame(self):
        response = self.client.post(
            "/api/v1/recognition/frame",
            headers={
                "X-Session-ID": "0123456789abcdef",
                "Content-Type": "application/octet-stream",
            },
            content=b"not a jpeg",
        )
        self.assertEqual(response.status_code, 415)

    def test_recognition_requires_authorization_for_remote_clients(self):
        remote_client = TestClient(app, client=("192.0.2.25", 50000))
        with patch.dict(os.environ, {"TTS_API_TOKEN": "", "TTS_ALLOWED_ORIGINS": ""}):
            response = remote_client.post(
                "/api/v1/recognition/frame",
                headers={
                    "X-Session-ID": "0123456789abcdef",
                    "Content-Type": "image/jpeg",
                },
                content=b"not a jpeg",
            )
        self.assertEqual(response.status_code, 401)

    def test_recognition_rejects_invalid_jpeg(self):
        response = self.client.post(
            "/api/v1/recognition/frame",
            headers={
                "X-Session-ID": "0123456789abcdef",
                "Content-Type": "image/jpeg",
            },
            content=b"not a jpeg",
        )
        self.assertEqual(response.status_code, 400)

    def test_recognition_processes_camera_frame_and_resets_session(self):
        success, encoded = cv2.imencode(
            ".jpg", np.zeros((240, 320, 3), dtype=np.uint8)
        )
        self.assertTrue(success)
        session_id = "0123456789abcdef"
        headers = {
            "X-Session-ID": session_id,
            "Content-Type": "image/jpeg",
        }

        response = self.client.post(
            "/api/v1/recognition/frame",
            headers=headers,
            content=encoded.tobytes(),
        )

        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["status"], "idle")
        self.assertEqual(response.json()["frames_collected"], 1)
        self.assertEqual(response.json()["hand_landmarks"], [])
        self.assertEqual(response.json()["frame_width"], 320)
        self.assertEqual(response.json()["frame_height"], 240)
        reset_response = self.client.delete(
            "/api/v1/recognition/session",
            headers={"X-Session-ID": session_id},
        )
        self.assertEqual(reset_response.status_code, 204)


if __name__ == "__main__":
    unittest.main()
