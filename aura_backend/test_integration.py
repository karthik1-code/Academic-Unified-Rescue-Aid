import requests
import time
import subprocess
import os

def test():
    print("Starting backend...")
    env = os.environ.copy()
    env["PYTHONPATH"] = ".."
    process = subprocess.Popen(
        ["python", "main.py"],
        cwd="C:/Users/karth/OneDrive/Desktop/AURAOS/aura_backend/",
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    time.sleep(5)

    try:
        print("Checking backend health...")
        resp = requests.get("http://localhost:8000/")
        print(f"Health check: {resp.status_code} - {resp.json()}")

        # Test a simple route
        print("Checking AI Chat (General)...")
        chat_resp = requests.post(
            "http://localhost:8000/api/ai/chat",
            json={"student_id": "test_student", "query": "Hello AURA"}
        )
        print(f"Chat response: {chat_resp.status_code} - {chat_resp.json().get('response')[:50]}...")

    except Exception as e:
        print(f"Test failed: {e}")
    finally:
        process.terminate()
        print("Backend stopped.")

if __name__ == "__main__":
    test()
