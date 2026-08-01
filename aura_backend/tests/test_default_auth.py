import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parent))

from aura_backend.app.api.auth import LoginRequest, login_student


class DefaultAuthTests(unittest.TestCase):
    def test_default_credentials_login(self):
        response = login_student(LoginRequest(email="karthik@aura.io", password="Karthik@55"))
        self.assertEqual(response["email"], "karthik@aura.io")
        self.assertTrue(response["uid"])


if __name__ == "__main__":
    unittest.main()
