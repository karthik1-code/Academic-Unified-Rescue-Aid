import time
from fastapi import APIRouter, HTTPException, status
from typing import List
from datetime import date
from pydantic import BaseModel
from aura_backend.app.core.firestore import db

router = APIRouter(prefix="/goals", tags=["Goal Management"])

class CreateGoalRequest(BaseModel):
    student_id: str
    title: str
    timeframe: str # 'daily', 'weekly', 'monthly', 'semester', 'career'

class GoalResponse(BaseModel):
    id: int
    student_id: str
    title: str
    timeframe: str
    status: str
    date_created: str

@router.get("/student/{student_id}", response_model=List[GoalResponse])
def get_goals(student_id: str):
    docs = db.collection("goals").where("student_id", "==", student_id).get()
    goals = []
    for doc in docs:
        data = doc.to_dict()
        goals.append(GoalResponse(
            id=int(doc.id) if doc.id.isdigit() else int(time.time()),
            student_id=data.get("student_id", student_id),
            title=data.get("title", ""),
            timeframe=data.get("timeframe", "daily"),
            status=data.get("status", "pending"),
            date_created=data.get("date_created", date.today().isoformat())
        ))
    return goals

@router.post("/", status_code=status.HTTP_201_CREATED, response_model=GoalResponse)
def create_goal(request: CreateGoalRequest):
    if request.timeframe not in ['todo', 'daily', 'weekly', 'monthly', 'semester', 'career']:
        raise HTTPException(status_code=400, detail="Invalid timeframe.")
        
    goal_id = str(int(time.time() * 1000))
    goal_data = {
        "student_id": request.student_id,
        "title": request.title,
        "timeframe": request.timeframe,
        "status": "pending",
        "date_created": date.today().isoformat()
    }
    db.collection("goals").document(goal_id).set(goal_data)
    
    return GoalResponse(
        id=int(goal_id),
        student_id=request.student_id,
        title=request.title,
        timeframe=request.timeframe,
        status="pending",
        date_created=date.today().isoformat()
    )

@router.post("/{goal_id}/toggle")
def toggle_goal(goal_id: str):
    doc_ref = db.collection("goals").document(goal_id)
    snapshot = doc_ref.get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Goal not found")
        
    data = snapshot.to_dict()
    current_status = data.get("status", "pending")
    new_status = "completed" if current_status == "pending" else "pending"
    doc_ref.update({"status": new_status})
    return {"status": "success", "message": f"Goal marked as {new_status}."}

@router.delete("/{goal_id}")
def delete_goal(goal_id: str):
    doc_ref = db.collection("goals").document(goal_id)
    if not doc_ref.get().exists:
        raise HTTPException(status_code=404, detail="Goal not found")
        
    doc_ref.delete()
    return {"status": "success", "message": "Goal deleted successfully."}
