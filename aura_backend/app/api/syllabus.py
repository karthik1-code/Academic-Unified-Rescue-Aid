from fastapi import APIRouter, HTTPException, UploadFile, File
from typing import List, Optional
from pydantic import BaseModel
import json
from aura_backend.app.core.firestore import db

router = APIRouter(prefix="/syllabus", tags=["Syllabus Tracker"])

@router.post("/parse")
async def parse_syllabus(file: UploadFile = File(...)):
    content = await file.read()
    from aura_backend.app.agents.syllabus_agent import SyllabusAgent
    return SyllabusAgent.parse_document(content, file.filename)

class UnitUpdateRequest(BaseModel):
    unit_id: int
    status: str # 'completed', 'learning', 'pending'

class UnitEditRequest(BaseModel):
    unit_id: int
    title: str
    description: Optional[str] = ""
    status: Optional[str] = "pending"
    completion_date: Optional[str] = ""

class SyllabusUnitResponse(BaseModel):
    id: int
    subject_id: int
    unit_number: int
    title: str
    description: Optional[str] = ""
    status: str
    completion_date: Optional[str] = ""

class SubjectSyllabusResponse(BaseModel):
    subject_id: int
    subject_name: str
    units: List[SyllabusUnitResponse]

@router.get("/tracker/{student_id}", response_model=List[SubjectSyllabusResponse])
def get_tracker(student_id: str):
    # Fetch subjects
    subjects_docs = db.collection("subjects").where("student_id", "==", student_id).get()
    
    response = []
    for doc in subjects_docs:
        sub = doc.to_dict()
        sub_id = sub.get("id")
        
        # Fetch units
        units_docs = db.collection("syllabus_units").where("subject_id", "==", int(sub_id)).get()
        units = []
        for u_doc in units_docs:
            u = u_doc.to_dict()
            units.append(SyllabusUnitResponse(
                id=int(u.get("id", 0)),
                subject_id=int(u.get("subject_id", 0)),
                unit_number=int(u.get("unit_number", 1)),
                title=u.get("title", ""),
                description=u.get("description", ""),
                status=u.get("status", "pending"),
                completion_date=u.get("completion_date", "")
            ))
            
        # Sort units by unit_number
        units.sort(key=lambda x: x.unit_number)

        response.append(SubjectSyllabusResponse(
            subject_id=int(sub_id),
            subject_name=sub.get("name", ""),
            units=units
        ))
    return response

@router.post("/unit/update")
def update_unit_status(request: UnitUpdateRequest):
    doc_ref = db.collection("syllabus_units").document(str(request.unit_id))
    snapshot = doc_ref.get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Syllabus unit not found")
        
    if request.status not in ['completed', 'learning', 'pending']:
        raise HTTPException(status_code=400, detail="Invalid unit status. Must be completed, learning, or pending.")
        
    doc_ref.update({"status": request.status})
    return {"status": "success", "message": f"Unit status updated to {request.status}."}

@router.post("/unit/edit")
def edit_unit(request: UnitEditRequest):
    doc_ref = db.collection("syllabus_units").document(str(request.unit_id))
    snapshot = doc_ref.get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Syllabus unit not found")
        
    update_data = {
        "title": request.title,
        "description": request.description,
        "status": request.status,
        "completion_date": request.completion_date or ""
    }
    doc_ref.update(update_data)
    return {"status": "success", "message": "Unit details updated successfully in Firestore."}
