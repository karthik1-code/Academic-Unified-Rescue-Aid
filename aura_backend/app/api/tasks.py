import time
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from typing import Optional, List
from aura_backend.app.core.firestore import db

router = APIRouter(prefix="/tasks", tags=["Productivity Tasks"])

class TaskCreateRequest(BaseModel):
    student_id: str
    title: str
    description: Optional[str] = ""
    priority: Optional[str] = "Medium"
    category: Optional[str] = "Study"
    date: Optional[str] = None
    start_time: Optional[str] = ""
    end_time: Optional[str] = ""
    reminder: Optional[bool] = False
    repeat: Optional[str] = "None"
    reminder_time: Optional[str] = ""

@router.get("/student/{student_id}")
def get_tasks(student_id: str):
    docs = db.collection("tasks").where("student_id", "==", student_id).get()
    tasks = []
    for doc in docs:
        data = doc.to_dict()
        data["id"] = int(doc.id) if doc.id.isdigit() else doc.id
        tasks.append(data)
    # Sort by priority or ID
    return tasks

@router.post("/", status_code=status.HTTP_201_CREATED)
def create_task(request: TaskCreateRequest):
    task_id = str(int(time.time() * 1000))
    task_data = {
        "student_id": request.student_id,
        "title": request.title,
        "description": request.description,
        "priority": request.priority,
        "category": request.category,
        "date": request.date,
        "start_time": request.start_time,
        "end_time": request.end_time,
        "is_completed": False,
        "reminder": request.reminder,
        "repeat": request.repeat,
        "reminder_time": request.reminder_time or "",
    }
    db.collection("tasks").document(task_id).set(task_data)
    task_data["id"] = int(task_id)
    return task_data

@router.post("/{task_id}/toggle")
def toggle_task(task_id: str):
    doc_ref = db.collection("tasks").document(task_id)
    snapshot = doc_ref.get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Task not found")
    data = snapshot.to_dict()
    completed = data.get("is_completed", False)
    doc_ref.update({"is_completed": not completed})
    return {"status": "success", "is_completed": not completed}

@router.delete("/{task_id}")
def delete_task(task_id: str):
    doc_ref = db.collection("tasks").document(task_id)
    if not doc_ref.get().exists:
        raise HTTPException(status_code=404, detail="Task not found")
    doc_ref.delete()
    return {"status": "success", "message": "Task deleted"}
