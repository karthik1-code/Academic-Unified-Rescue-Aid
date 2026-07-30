from fastapi import APIRouter, HTTPException
from datetime import date
from pydantic import BaseModel
from aura_backend.app.core.firestore import db
from aura_backend.app.agents.attendance_agent import get_attendance_analysis, AttendanceAnalysis

router = APIRouter(prefix="/attendance", tags=["Attendance Intelligence"])

class RecordAttendanceRequest(BaseModel):
    subject_id: int
    date: date
    status: str # 'present', 'absent', 'leave'

@router.get("/summary/{student_id}", response_model=AttendanceAnalysis)
def get_summary(student_id: str):
    try:
        return get_attendance_analysis(student_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.post("/record")
def record_attendance(request: RecordAttendanceRequest):
    # Verify subject exists
    subj_doc = db.collection("subjects").document(str(request.subject_id)).get()
    if not subj_doc.exists:
        raise HTTPException(status_code=404, detail="Subject not found")
        
    if request.status not in ['present', 'absent', 'leave']:
        raise HTTPException(status_code=400, detail="Invalid attendance status. Must be present, absent, or leave.")

    # Unique document key for subject + date to handle upsert
    record_id = f"{request.subject_id}_{request.date.isoformat()}"
    doc_ref = db.collection("attendance_records").document(record_id)
    
    snapshot = doc_ref.get()
    record_data = {
        "subject_id": request.subject_id,
        "date": request.date.isoformat(),
        "status": request.status
    }
    
    if snapshot.exists:
        doc_ref.update({"status": request.status})
        return {"status": "updated", "message": "Attendance record updated successfully in Firestore."}
    else:
        doc_ref.set(record_data)
        return {"status": "created", "message": "Attendance record registered successfully in Firestore."}

@router.delete("/record/{subject_id}/{date_str}")
def clear_attendance(subject_id: int, date_str: str):
    """Clear/remove an attendance record for a given subject and date."""
    record_id = f"{subject_id}_{date_str}"
    doc_ref = db.collection("attendance_records").document(record_id)
    snapshot = doc_ref.get()
    if not snapshot.exists:
        # Not an error - just silently succeed
        return {"status": "not_found", "message": "No attendance record for this date."}
    doc_ref.delete()
    return {"status": "cleared", "message": "Attendance record removed successfully."}

