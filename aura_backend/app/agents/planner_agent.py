from datetime import date
from typing import List, Dict, Any
from pydantic import BaseModel
from aura_backend.app.core.firestore import db
from aura_backend.app.agents.gemini_client import generate_structured
from aura_backend.app.agents.attendance_agent import get_attendance_analysis

class DailyPlanTask(BaseModel):
    title: str
    duration_minutes: int
    category: str # 'Study', 'Attendance', 'Goal', 'Revision'
    priority: str # 'High', 'Medium', 'Low'
    reason: str

class StudyPlan(BaseModel):
    date: str
    tasks: List[DailyPlanTask]
    priority_subjects: List[str]
    revision_suggestions: List[str]
    motivation_message: str

def generate_daily_study_plan(student_id: str) -> StudyPlan:
    # 1. Gather context from Firestore
    profile_doc = db.collection("student_profiles").document(student_id).get()
    if not profile_doc.exists:
        raise ValueError("Student profile not found")
        
    student = profile_doc.to_dict()
    
    # Get subjects
    subjects_docs = db.collection("subjects").where("student_id", "==", student_id).get()
    subjects = [doc.to_dict() for doc in subjects_docs]
    subject_map = {s.get("id"): s.get("name") for s in subjects}
    
    # Get syllabus units
    units = []
    for s_id in subject_map.keys():
        units_docs = db.collection("syllabus_units").where("subject_id", "==", int(s_id)).get()
        units.extend([u.to_dict() for u in units_docs])
    
    # Get goals (pending daily and weekly goals)
    goals_docs = db.collection("goals").where("student_id", "==", student_id).where("status", "==", "pending").get()
    goals = [g.to_dict() for g in goals_docs]
    
    # Get attendance analysis to know priority subjects
    try:
        att_analysis = get_attendance_analysis(student_id)
        critical_subjects = [s.subject_name for s in att_analysis.subjects_detail if s.status_label == "Critical"]
    except Exception:
        critical_subjects = []
        
    # Compile a prompt for Gemini
    context = f"Student Profile:\n"
    context += f"- Name: {student.get('name')}\n"
    context += f"- Branch: {student.get('branch')}, Semester: {student.get('semester')}\n"
    context += f"- Weak Subjects: {student.get('weak_subjects')}\n"
    context += f"- Strong Subjects: {student.get('strong_subjects')}\n"
    context += f"- Daily Study Target: {student.get('daily_study_goal_hours', 2.0)} hours\n\n"
    
    context += "Syllabus Tracker:\n"
    for s_id, s_name in subject_map.items():
        sub_units = [u for u in units if u.get("subject_id") == s_id]
        comp = sum(1 for u in sub_units if u.get("status") == "completed")
        lrn = sum(1 for u in sub_units if u.get("status") == "learning")
        tot = len(sub_units)
        context += f"- {s_name}: Completed {comp}/{tot}, Learning {lrn}/{tot}\n"
        
    context += "\nPending Goals:\n"
    for g in goals:
        context += f"- {g.get('title')} ({g.get('timeframe')})\n"
        
    context += f"\nAttendance Alert (Subjects below {student.get('attendance_target', 75.0)}% target):\n"
    for cs in critical_subjects:
        context += f"- {cs} (Needs urgent attendance!)\n"
        
    prompt = (
        f"You are the Study Planner Agent for AURA. Based on the student's academic profile and progress context, "
        f"generate today's study plan.\n"
        f"The plan must total approximately {student.get('daily_study_goal_hours', 2.0)} hours (or adapt if needed) and fit the StudyPlan structure.\n\n"
        f"Academic context:\n{context}\n"
        f"Make the response engaging, actionable, and mathematically optimized to help the student tackle critical subjects, "
        f"advance current 'learning' units, complete pending daily goals, and revise older units."
    )
    
    system_instruction = (
        "You are an elite academic organizer. You structure study schedules logically, prioritizing weak subjects, "
        f"critical attendance requirements, and ongoing syllabus work. Limit tasks to at most 6 highly relevant items."
    )
    
    # Generate structured plan
    study_plan = generate_structured(
        prompt=prompt,
        response_schema=StudyPlan,
        system_instruction=system_instruction,
        temperature=0.4
    )
    
    if not study_plan:
        # Fallback plan in case API is disabled or error occurs
        study_plan = StudyPlan(
            date=date.today().isoformat(),
            tasks=[
                DailyPlanTask(
                    title="Review weak modules",
                    duration_minutes=45,
                    category="Study",
                    priority="High",
                    reason="Target weak subject areas first."
                ),
                DailyPlanTask(
                    title="Attend upcoming classes",
                    duration_minutes=60,
                    category="Attendance",
                    priority="High",
                    reason="Keep critical attendance metrics secure."
                )
            ],
            priority_subjects=list(subject_map.values())[:2],
            revision_suggestions=["Unit 1 Fundamental Concepts"],
            motivation_message="Consistency builds success. Finish your priority tasks today!"
        )
        
    return study_plan
