import time
import uuid
from fastapi import APIRouter, HTTPException, status, Query
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
from aura_backend.app.core.firestore import db

router = APIRouter(tags=["Custom MongoDB Resources"])

# --- Models ---
class ExamModel(BaseModel):
    id: Optional[str] = None
    student_id: str
    name: str
    subject: str
    date: str  # ISO string
    description: Optional[str] = ""
    reminder_set: Optional[bool] = False
    reminder_time: Optional[str] = ""

class AssignmentModel(BaseModel):
    id: Optional[str] = None
    student_id: str
    title: str
    subject: str
    due_date: str  # ISO string
    priority: str
    status: str  # 'pending', 'submitted'
    reminder_set: Optional[bool] = False
    reminder_time: Optional[str] = ""

class FileMetadataModel(BaseModel):
    id: Optional[str] = None
    student_id: str
    filename: str
    file_path: str
    download_url: str
    subject: str
    file_size: int

class FileRenameRequest(BaseModel):
    filename: str

# --- Exams ---
@router.get("/exams", response_model=List[ExamModel])
def get_exams(student_id: str):
    docs = db.collection("exams").where("student_id", "==", student_id).get()
    exams = []
    for doc in docs:
        d = doc.to_dict()
        d["id"] = doc.id
        exams.append(ExamModel(**d))
    # Sort by date
    exams.sort(key=lambda x: x.date)
    return exams

@router.post("/exams", response_model=ExamModel)
def save_exam(exam: ExamModel):
    exam_id = exam.id or ("exam_" + str(uuid.uuid4()))
    exam_data = exam.model_dump()
    exam_data["id"] = exam_id
    db.collection("exams").document(exam_id).set(exam_data)
    return ExamModel(**exam_data)

@router.delete("/exams/{exam_id}")
def delete_exam(exam_id: str):
    db.collection("exams").document(exam_id).delete()
    return {"status": "success", "message": "Exam deleted successfully"}

# --- Assignments ---
@router.get("/assignments", response_model=List[AssignmentModel])
def get_assignments(student_id: str):
    docs = db.collection("assignments").where("student_id", "==", student_id).get()
    assignments = []
    for doc in docs:
        d = doc.to_dict()
        d["id"] = doc.id
        assignments.append(AssignmentModel(**d))
    # Sort by due_date
    assignments.sort(key=lambda x: x.due_date)
    return assignments

@router.post("/assignments", response_model=AssignmentModel)
def save_assignment(assignment: AssignmentModel):
    assignment_id = assignment.id or ("assignment_" + str(uuid.uuid4()))
    assignment_data = assignment.model_dump()
    assignment_data["id"] = assignment_id
    db.collection("assignments").document(assignment_id).set(assignment_data)
    return AssignmentModel(**assignment_data)

@router.put("/assignments/{assignment_id}/toggle")
def toggle_assignment(assignment_id: str, current_status: str):
    doc_ref = db.collection("assignments").document(assignment_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Assignment not found")
    new_status = "submitted" if current_status == "pending" else "pending"
    doc_ref.update({"status": new_status})
    return {"status": "success", "new_status": new_status}

@router.delete("/assignments/{assignment_id}")
def delete_assignment(assignment_id: str):
    db.collection("assignments").document(assignment_id).delete()
    return {"status": "success", "message": "Assignment deleted successfully"}

# --- Files (Vault) ---
@router.get("/vault/files", response_model=List[FileMetadataModel])
def get_vault_files(student_id: str, subject: Optional[str] = None):
    query = db.collection("knowledge_files").where("student_id", "==", student_id)
    docs = query.get()
    files = []
    for doc in docs:
        d = doc.to_dict()
        d["id"] = doc.id
        
        # Apply local subject filter if requested (ignoring 'general')
        if subject and subject.lower() != 'general':
            if d.get("subject", "").lower() != subject.lower():
                continue
                
        files.append(FileMetadataModel(**d))
    return files

@router.post("/vault/files", response_model=FileMetadataModel)
def save_file_metadata(file: FileMetadataModel):
    file_id = file.id or ("file_" + str(uuid.uuid4()))
    file_data = file.model_dump()
    file_data["id"] = file_id
    db.collection("knowledge_files").document(file_id).set(file_data)
    return FileMetadataModel(**file_data)

@router.put("/vault/files/{file_id}/rename")
def rename_file(file_id: str, request: FileRenameRequest):
    doc_ref = db.collection("knowledge_files").document(file_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="File metadata not found")
    doc_ref.update({"filename": request.filename})
    return {"status": "success", "message": "File renamed successfully"}

@router.delete("/vault/files/{file_id}")
def delete_file(file_id: str):
    db.collection("knowledge_files").document(file_id).delete()
    return {"status": "success", "message": "File deleted successfully"}
