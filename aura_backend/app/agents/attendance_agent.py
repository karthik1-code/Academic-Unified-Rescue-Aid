import math
from datetime import date
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from aura_backend.app.core.firestore import db
from aura_backend.app.agents.gemini_client import generate_text, is_ai_enabled

class SubjectAttendanceDetail(BaseModel):
    subject_id: int
    subject_name: str
    credits: int
    present: int
    absent: int
    leave: int
    total_classes: int
    percentage: float
    status_label: str # 'Excellent', 'Safe', 'Critical'
    safe_leaves: int # classes they can skip
    required_to_recover: int # classes they must attend
    recovery_suggestion: str
    subtitle: Optional[str] = ""

class AttendanceAnalysis(BaseModel):
    health_score: float # 0 to 100
    overall_percentage: float
    subjects_detail: List[SubjectAttendanceDetail]
    ai_prediction_summary: str
    safe_leave_summary: str

def calculate_subject_attendance(
    present: int, absent: int, leave: int, target: float
) -> tuple[float, str, int, int]:
    # Exclude leaves from total evaluated classes
    total = present + absent
    if total == 0:
        return 100.0, "Safe", 0, 0
        
    percentage = (present / total) * 100.0
    
    # Labeling based on target
    if percentage >= target + 10:
        status_label = "Excellent"
    elif percentage >= target:
        status_label = "Safe"
    else:
        status_label = "Critical"
        
    safe_leaves = 0
    required_to_recover = 0
    
    target_fraction = target / 100.0
    
    if percentage >= target:
        if target_fraction > 0:
            val = present / target_fraction - total
            safe_leaves = max(0, math.floor(val))
    else:
        denom = 1.0 - target_fraction
        if denom > 0:
            val = (target_fraction * total - present) / denom
            required_to_recover = max(0, math.ceil(val))
            
    return percentage, status_label, safe_leaves, required_to_recover

def get_attendance_analysis(student_id: str) -> AttendanceAnalysis:
    # 1. Fetch student profile from Firestore
    profile_doc = db.collection("student_profiles").document(student_id).get()
    if not profile_doc.exists:
        raise ValueError("Student profile not found")
        
    student_data = profile_doc.to_dict()
    target = student_data.get("attendance_target", 75.0)
    
    # 2. Fetch subjects
    subjects_docs = db.collection("subjects").where("student_id", "==", student_id).get()
    
    total_present_all = 0
    total_classes_all = 0
    subjects_detail = []
    
    for doc in subjects_docs:
        sub = doc.to_dict()
        sub_id = sub.get("id")
        
        # Get attendance records
        records_docs = db.collection("attendance_records").where("subject_id", "==", int(sub_id)).get()
        records = [r.to_dict() for r in records_docs]
        
        present = sum(1 for r in records if r.get("status") == 'present')
        absent = sum(1 for r in records if r.get("status") == 'absent')
        leave = sum(1 for r in records if r.get("status") == 'leave')
        
        total = present + absent
        pct, label, safe_l, recover_c = calculate_subject_attendance(present, absent, leave, target)
        
        total_present_all += present
        total_classes_all += total
        
        if label == "Critical":
            sugg = f"Below target ({target}%). You must attend the next {recover_c} classes consecutively to recover."
        elif safe_l > 0:
            sugg = f"Safe to leave {safe_l} classes. Your current attendance is {pct:.1f}%."
        else:
            sugg = "You are right on the limit. Avoid skipping any class to maintain attendance status."
            
        subjects_detail.append(SubjectAttendanceDetail(
            subject_id=int(sub_id),
            subject_name=sub.get("name", ""),
            credits=sub.get("credits", 3),
            present=present,
            absent=absent,
            leave=leave,
            total_classes=total,
            percentage=pct,
            status_label=label,
            safe_leaves=safe_l,
            required_to_recover=recover_c,
            recovery_suggestion=sugg,
            subtitle=sub.get("subtitle", "")
        ))
        
    overall_percentage = (total_present_all / total_classes_all * 100.0) if total_classes_all > 0 else 100.0
    
    # Calculate health score: base on how many subjects are safe, credit weighted
    total_credits = sum(sd.credits for sd in subjects_detail) or 1
    weighted_score = 0.0
    for sd in subjects_detail:
        subj_pct = sd.percentage
        subj_score = min(100.0, (subj_pct / target) * 100.0) if target > 0 else 100.0
        weighted_score += subj_score * (sd.credits / total_credits)
        
    health_score = round(weighted_score, 1)
    
    # Generate AI insights based on the analysis
    data_summary = f"Student Target: {target}%\n"
    data_summary += f"Overall Attendance: {overall_percentage:.1f}%\n"
    data_summary += f"Health Score: {health_score}/100\n"
    for sd in subjects_detail:
        data_summary += f"- {sd.subject_name}: {sd.percentage:.1f}% ({sd.status_label}). Safe leaves: {sd.safe_leaves}, Needed to recover: {sd.required_to_recover}\n"
        
    if not is_ai_enabled():
        critical_names = [sd.subject_name for sd in subjects_detail if sd.status_label == "Critical"]
        if critical_names:
            ai_prediction = f"⚠️ Attendance alert: You are currently falling below your target in {', '.join(critical_names)}. Focus on attending the upcoming classes to rebuild your safety buffer."
            safe_leave_summary = "Please do not skip any upcoming classes in critical subjects."
        else:
            ai_prediction = "🎉 Great job! Your attendance is in excellent health across all enrolled subjects. Keep up the consistent schedule to maintain this record."
            safe_leave_summary = "All subjects have safe margins. You have cushions for skips if needed."
    else:
        ai_prompt = (
            f"You are the Attendance Agent of AURA, an AI academic assistant.\n"
            f"Analyze this student's attendance data and write a highly personalized, "
            f"encouraging yet realistic prediction and recommendation summary (max 3 sentences).\n"
            f"Discuss which subjects need attention and project their risk of falling below attendance limits.\n\n"
            f"Data:\n{data_summary}"
        )
        
        ai_prediction = generate_text(
            prompt=ai_prompt,
            system_instruction="You are an expert academic mentor analyzing attendance records. Be concise, direct, and supportive.",
            temperature=0.3
        )
        
        # Generate safe leave quick summary
        safe_leave_p = (
            f"You are the Attendance Agent of AURA.\n"
            f"Create a summary of the safe leave status (consecutive classes the student can skip or needs to attend) "
            f"for tomorrow. Keep it short and actionable (max 2 sentences).\n\n"
            f"Data:\n{data_summary}"
        )
        safe_leave_summary = generate_text(
            prompt=safe_leave_p,
            system_instruction="Be brief and focus on safe leaves and recovery details.",
            temperature=0.2
        )
    
    return AttendanceAnalysis(
        health_score=health_score,
        overall_percentage=round(overall_percentage, 1),
        subjects_detail=subjects_detail,
        ai_prediction_summary=ai_prediction,
        safe_leave_summary=safe_leave_summary
    )
