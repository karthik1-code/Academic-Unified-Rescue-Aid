import os
import json
import time
from datetime import datetime
from fastapi import APIRouter, HTTPException, UploadFile, File, Form, BackgroundTasks
from typing import List, Optional
from pydantic import BaseModel
from aura_backend.app.core.firestore import db
from aura_backend.app.core.config import settings
from aura_backend.app.agents.knowledge_agent import ingest_document, generate_study_materials, delete_document_vectors, VaultStudyMaterials

router = APIRouter(prefix="/knowledge", tags=["Knowledge Vault (RAG)"])

STUDY_GUIDES_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 
    "data", 
    "study_guides"
)
os.makedirs(STUDY_GUIDES_DIR, exist_ok=True)

class KnowledgeFileResponse(BaseModel):
    id: str
    student_id: str
    filename: str
    file_path: str
    upload_time: str

def background_ingest_and_cache(file_path: str, student_id: str, filename: str, file_id: str):
    try:
        ingest_document(file_path, student_id, filename, file_id)
        materials = generate_study_materials(student_id, file_path, filename)
        
        cache_path = os.path.join(STUDY_GUIDES_DIR, f"{file_id}.json")
        with open(cache_path, "w", encoding="utf-8") as f:
            json.dump(materials.model_dump(), f, indent=4)
            
        print(f"Pre-cached study materials for file {file_id} ({filename})")
    except Exception as e:
        print(f"Background processing failed for file {file_id}: {e}")

@router.post("/upload")
def upload_file(
    background_tasks: BackgroundTasks,
    student_id: str = Form(...),
    file_id: str = Form(...),
    file: UploadFile = File(...)
):
    # Verify student exists in Firestore
    student_doc = db.collection("student_profiles").document(student_id).get()
    if not student_doc.exists:
        raise HTTPException(status_code=404, detail="Student profile not found")

    filename = file.filename
    _, ext = os.path.splitext(filename.lower())
    if ext not in ['.pdf', '.docx', '.txt', '.md', '.ppt', '.pptx', '.jpg', '.png', '.jpeg']:
        raise HTTPException(status_code=400, detail="Unsupported format. Upload PDF, DOCX, PPT, JPG, PNG or TXT.")

    saved_filename = f"{file_id}_{filename}"
    file_path = os.path.join(settings.UPLOAD_DIR, saved_filename)
    
    try:
        with open(file_path, "wb") as buffer:
            buffer.write(file.file.read())
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to write file to disk: {e}")

    file_data = {
        "id": file_id,
        "student_id": student_id,
        "filename": filename,
        "file_path": file_path,
        "upload_time": datetime.utcnow().isoformat()
    }
    db.collection("knowledge_files").document(file_id).set(file_data)
    
    background_tasks.add_task(
        background_ingest_and_cache, 
        file_path, 
        student_id, 
        filename, 
        file_id
    )

    return {
        "status": "success", 
        "message": "File uploaded and scheduled for AI indexing & analysis in background.",
        "file": file_data
    }

@router.get("/files/{student_id}", response_model=List[KnowledgeFileResponse])
def get_files(student_id: str):
    docs = db.collection("knowledge_files").where("student_id", "==", student_id).get()
    files = []
    for doc in docs:
        data = doc.to_dict()
        files.append(KnowledgeFileResponse(
            id=doc.id,
            student_id=data.get("student_id", student_id),
            filename=data.get("filename", ""),
            file_path=data.get("file_path", ""),
            upload_time=data.get("upload_time", datetime.utcnow().isoformat())
        ))
    return files

@router.get("/study-materials/{file_id}", response_model=VaultStudyMaterials)
def get_materials(file_id: str):
    doc = db.collection("knowledge_files").document(file_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Uploaded file not found")
        
    data = doc.to_dict()
    file_path = data.get("file_path", "")
    student_id = data.get("student_id", "")
    filename = data.get("filename", "")

    cache_path = os.path.join(STUDY_GUIDES_DIR, f"{file_id}.json")
    if os.path.exists(cache_path):
        with open(cache_path, "r", encoding="utf-8") as f:
            c_data = json.load(f)
            return VaultStudyMaterials.model_validate(c_data)
            
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Raw file missing from server storage")
        
    materials = generate_study_materials(student_id, file_path, filename)
    
    with open(cache_path, "w", encoding="utf-8") as f:
        json.dump(materials.model_dump(), f, indent=4)
        
    return materials

@router.delete("/files/{file_id}")
def delete_file(file_id: str):
    doc_ref = db.collection("knowledge_files").document(file_id)
    snapshot = doc_ref.get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="File not found")
        
    data = snapshot.to_dict()
    file_path = data.get("file_path", "")

    if os.path.exists(file_path):
        try:
            os.remove(file_path)
        except Exception as e:
            print(f"Error removing physical file: {e}")
            
    cache_path = os.path.join(STUDY_GUIDES_DIR, f"{file_id}.json")
    if os.path.exists(cache_path):
        try:
            os.remove(cache_path)
        except Exception as e:
            print(f"Error removing cached materials: {e}")
            
    try:
        delete_document_vectors(file_id)
    except Exception as e:
        print(f"Error deleting vectors: {e}")
    
    doc_ref.delete()
    return {"status": "success", "message": "File and vectors successfully deleted."}
