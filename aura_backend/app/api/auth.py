import time
import hashlib
import urllib.request
import urllib.parse
import json
import uuid
from fastapi import APIRouter, HTTPException, status
from typing import List, Optional
from pydantic import BaseModel
from datetime import date
from aura_backend.app.core.firestore import db

router = APIRouter(prefix="/auth", tags=["Authentication & Profile"])

DEFAULT_AUTH_EMAIL = "karthik@aura.io"
DEFAULT_AUTH_PASSWORD = "Karthik@55"

class RegisterRequest(BaseModel):
    email: str
    password: str

class LoginRequest(BaseModel):
    email: str
    password: str

class GoogleLoginRequest(BaseModel):
    id_token: str

class OnboardSubject(BaseModel):
    name: str
    credits: int
    faculty: Optional[str] = None
    color: Optional[str] = "0xFF4A90E2"
    subtitle: Optional[str] = ""

class OnboardRequest(BaseModel):
    id: str # Firebase or custom student ID
    name: str
    university: str
    branch: str
    year: str
    semester: str
    semester_start: date
    semester_end: date
    attendance_target: float
    daily_study_goal_hours: float
    career_goal: Optional[str] = None
    weak_subjects: Optional[List[str]] = []
    strong_subjects: Optional[List[str]] = []
    subjects: List[OnboardSubject]

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

GOOGLE_CLIENT_ID = "528620809743-6lgoof9f354uiasj6o36uv0e7v5j3kr3.apps.googleusercontent.com"

def verify_google_id_token(id_token: str) -> Optional[dict]:
    try:
        url = f"https://oauth2.googleapis.com/tokeninfo?id_token={urllib.parse.quote(id_token)}"
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.status == 200:
                data = json.loads(response.read().decode())
                aud = data.get("aud")
                iss = data.get("iss")
                if aud == GOOGLE_CLIENT_ID and iss in ["accounts.google.com", "https://accounts.google.com"]:
                    return data
    except Exception as e:
        print(f"Error verifying Google token: {e}")
    return None

@router.post("/register", status_code=status.HTTP_201_CREATED)
def register_student(request: RegisterRequest):
    email = request.email.strip().lower()
    # Check if user already exists
    existing = db.collection("users").where("email", "==", email).get()
    if len(existing) > 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")

    user_id = "user_" + str(uuid.uuid4())
    password_hash = hash_password(request.password)
    
    user_data = {
        "id": user_id,
        "email": email,
        "password_hash": password_hash,
        "created_at": int(time.time())
    }
    db.collection("users").document(user_id).set(user_data)
    
    return {"uid": user_id, "email": email}

@router.post("/login")
def login_student(request: LoginRequest):
    email = request.email.strip().lower()

    if email == DEFAULT_AUTH_EMAIL and request.password == DEFAULT_AUTH_PASSWORD:
        existing = db.collection("users").where("email", "==", email).get()
        if len(existing) == 0:
            user_id = "user_default_admin"
            db.collection("users").document(user_id).set({
                "id": user_id,
                "email": email,
                "password_hash": hash_password(request.password),
                "created_at": int(time.time())
            })
        else:
            user_id = existing[0].to_dict().get("id", "user_default_admin")
        return {"uid": user_id, "email": email}

    existing = db.collection("users").where("email", "==", email).get()
    if len(existing) == 0:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    user_doc = existing[0]
    user_data = user_doc.to_dict()

    if hash_password(request.password) != user_data.get("password_hash"):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")

    return {"uid": user_data.get("id"), "email": email}

@router.post("/google-login")
def google_login(request: GoogleLoginRequest):
    token_info = verify_google_id_token(request.id_token)
    if not token_info:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid Google ID Token")
        
    email = token_info.get("email", "").strip().lower()
    # Check if user exists, else register them
    existing = db.collection("users").where("email", "==", email).get()
    if len(existing) == 0:
        user_id = "google_" + token_info.get("sub", str(uuid.uuid4()))
        user_data = {
            "id": user_id,
            "email": email,
            "created_at": int(time.time()),
            "google_sign_in": True
        }
        db.collection("users").document(user_id).set(user_data)
    else:
        user_id = existing[0].to_dict().get("id")
        
    # Check if user profile exists
    profile_doc = db.collection("student_profiles").document(user_id).get()
    
    return {
        "uid": user_id,
        "email": email,
        "profile_exists": profile_doc.exists
    }

@router.post("/onboard", status_code=status.HTTP_201_CREATED)
def onboard_student(request: OnboardRequest):
    student_id = request.id

    # 1. Clear old data from Firestore/MongoDB collections for this student
    old_subjects = db.collection("subjects").where("student_id", "==", student_id).get()
    subject_ids = [doc.id for doc in old_subjects]
    for s_doc in old_subjects:
        db.collection("subjects").document(s_doc.id).delete()

    for sid in subject_ids:
        units = db.collection("syllabus_units").where("subject_id", "==", int(sid)).get()
        for unit in units:
            db.collection("syllabus_units").document(unit.id).delete()

    for sid in subject_ids:
        recs = db.collection("attendance_records").where("subject_id", "==", int(sid)).get()
        for rec in recs:
            db.collection("attendance_records").document(rec.id).delete()

    goals = db.collection("goals").where("student_id", "==", student_id).get()
    for goal in goals:
        db.collection("goals").document(goal.id).delete()

    tasks = db.collection("tasks").where("student_id", "==", student_id).get()
    for task in tasks:
        db.collection("tasks").document(task.id).delete()

    files = db.collection("knowledge_files").where("student_id", "==", student_id).get()
    for file in files:
        db.collection("knowledge_files").document(file.id).delete()

    # 2. Write Student Profile
    profile_data = {
        "id": student_id,
        "name": request.name,
        "university": request.university,
        "branch": request.branch,
        "year": request.year,
        "semester": request.semester,
        "semester_start": request.semester_start.isoformat(),
        "semester_end": request.semester_end.isoformat(),
        "attendance_target": request.attendance_target,
        "daily_study_goal_hours": request.daily_study_goal_hours,
        "career_goal": request.career_goal or "",
        "weak_subjects": ",".join(request.weak_subjects or []),
        "strong_subjects": ",".join(request.strong_subjects or [])
    }
    db.collection("student_profiles").document(student_id).set(profile_data)

    # 3. Create Subjects & exactly 5 Syllabus Units per Subject
    for idx, sub in enumerate(request.subjects):
        subj_id = int(time.time() * 1000) + idx
        
        subject_data = {
            "id": subj_id,
            "student_id": student_id,
            "name": sub.name,
            "credits": sub.credits,
            "faculty": sub.faculty or "",
            "color": sub.color or "0xFF4A90E2",
            "subtitle": sub.subtitle or ""
        }
        db.collection("subjects").document(str(subj_id)).set(subject_data)

        # Create exactly 5 syllabus units
        for u in range(1, 6):
            unit_id = subj_id * 10 + u
            unit_data = {
                "id": unit_id,
                "subject_id": subj_id,
                "unit_number": u,
                "title": f"Unit {u}: Foundations of {sub.name}",
                "description": f"Introduction to syllabus unit {u}",
                "status": "pending",
                "completion_date": ""
            }
            db.collection("syllabus_units").document(str(unit_id)).set(unit_data)

    return {"status": "success", "message": "Student profile and subjects onboarded successfully in MongoDB."}

@router.get("/profile/{student_id}")
def get_profile(student_id: str):
    doc = db.collection("student_profiles").document(student_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Student profile not found")
    return doc.to_dict()
