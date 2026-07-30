from datetime import date, datetime
from typing import Optional, List
from pydantic import BaseModel

class StudentProfile(BaseModel):
    id: str
    name: str
    university: str
    branch: str
    year: str
    semester: str
    semester_start: date
    semester_end: date
    attendance_target: float = 75.0
    daily_study_goal_hours: float = 2.0
    career_goal: Optional[str] = None
    weak_subjects: Optional[str] = ""
    strong_subjects: Optional[str] = ""

class Subject(BaseModel):
    id: int
    student_id: str
    name: str
    credits: int
    faculty: Optional[str] = None
    color: Optional[str] = "0xFF4A90E2"
    subtitle: Optional[str] = ""

class AttendanceRecord(BaseModel):
    subject_id: int
    date: date
    status: str # 'present', 'absent', 'leave'

class SyllabusUnit(BaseModel):
    id: int
    subject_id: int
    unit_number: int
    title: str
    description: str
    status: str = "pending"
    completion_date: Optional[str] = ""

class Goal(BaseModel):
    id: int
    student_id: str
    title: str
    timeframe: str
    status: str = "pending"
    date_created: date

class KnowledgeFile(BaseModel):
    id: str
    student_id: str
    filename: str
    file_path: str
    upload_time: datetime
