from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from aura_backend.app.agents.orchestrator import process_student_query, OrchestratedResponse
from aura_backend.app.agents.resource_agent import get_resources_for_topic, ResourceRecommendations

router = APIRouter(prefix="/ai", tags=["AI Academic Assistant"])

class ChatRequest(BaseModel):
    student_id: str
    query: str

@router.post("/chat", response_model=OrchestratedResponse)
def assistant_chat(request: ChatRequest):
    try:
        return process_student_query(request.student_id, request.query)
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Orchestration processing error: {e}")

@router.get("/resources", response_model=ResourceRecommendations)
def topic_resources(topic: str, subject_name: str = ""):
    try:
        return get_resources_for_topic(topic, subject_name)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Resource fetching error: {e}")
