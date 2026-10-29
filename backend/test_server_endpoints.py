import unittest
from fastapi.testclient import TestClient
from server import app


class ServerEndpointTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

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


if __name__ == "__main__":
    unittest.main()

