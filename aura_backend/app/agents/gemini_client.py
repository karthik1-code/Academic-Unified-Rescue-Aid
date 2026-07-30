import os
import google.generativeai as genai
from typing import Any, Dict, List, Optional, Type
from pydantic import BaseModel
from aura_backend.app.core.config import settings

# Configure Gemini
api_key = settings.GEMINI_API_KEY
if api_key:
    genai.configure(api_key=api_key)
else:
    print("Warning: GEMINI_API_KEY is not set. AI features will run in mock mode.")

def is_ai_enabled() -> bool:
    return bool(settings.GEMINI_API_KEY)

def get_embedding(text: str) -> List[float]:
    """Generates text embeddings using text-embedding-004."""
    if not is_ai_enabled():
        # Mock embedding (768 dimensions)
        import random
        return [random.uniform(-0.1, 0.1) for _ in range(768)]
        
    try:
        response = genai.embed_content(
            model="models/text-embedding-004",
            content=text,
            task_type="retrieval_document"
        )
        return response["embedding"]
    except Exception as e:
        print(f"Error generating embedding: {e}")
        # Fallback to random embedding to keep app running
        import random
        return [random.uniform(-0.1, 0.1) for _ in range(768)]

def generate_text(
    prompt: str, 
    system_instruction: Optional[str] = None, 
    model_name: str = "gemini-1.5-flash",
    temperature: float = 0.7
) -> str:
    """Generates standard text using Gemini."""
    if not is_ai_enabled():
        return "[MOCK AI MODE] Gemini API Key is missing. Here is a simulated response to: " + prompt[:100]
        
    try:
        model = genai.GenerativeModel(
            model_name=model_name,
            system_instruction=system_instruction
        )
        response = model.generate_content(
            prompt,
            generation_config=genai.GenerationConfig(
                temperature=temperature
            )
        )
        return response.text
    except Exception as e:
        return f"Error communicating with Gemini: {str(e)}"

def generate_structured(
    prompt: str,
    response_schema: Type[BaseModel],
    system_instruction: Optional[str] = None,
    model_name: str = "gemini-1.5-flash",
    temperature: float = 0.2
) -> Any:
    """Generates structured outputs using Gemini with a Pydantic model schema."""
    if not is_ai_enabled():
        import datetime
        schema_name = response_schema.__name__
        if schema_name == 'AgentRoute':
            lower_prompt = prompt.lower()
            agent = 'general'
            if any(w in lower_prompt for w in ['attendance', 'absent', 'present', 'bunk', 'skip', 'leave']):
                agent = 'attendance'
            elif any(w in lower_prompt for w in ['syllabus', 'unit', 'learn', 'subject', 'course']):
                agent = 'syllabus'
            elif any(w in lower_prompt for w in ['study plan', 'schedule', 'todo', 'tasks', 'plan']):
                agent = 'planner'
            return response_schema(agent=agent, confidence=1.0, reason="Local semantic rule matching active")
        elif schema_name == 'StudyPlan':
            tasks_list = [
                {
                    "title": "Complete Operating Systems assignment notes",
                    "duration_minutes": 45,
                    "category": "Study",
                    "priority": "High",
                    "reason": "OS has a higher priority target requirement"
                },
                {
                    "title": "Solve 3 database normalization equations",
                    "duration_minutes": 30,
                    "category": "Revision",
                    "priority": "Medium",
                    "reason": "Practice makes DBMS queries faster"
                },
                {
                    "title": "Attend all classes today to maintain attendance",
                    "duration_minutes": 180,
                    "category": "Attendance",
                    "priority": "High",
                    "reason": "Class attendance keeps health indicators in green zone"
                }
            ]
            return response_schema(
                date=datetime.date.today().isoformat(),
                tasks=tasks_list,
                priority_subjects=["Operating Systems"],
                revision_suggestions=["Practice active recall on memory management"],
                motivation_message="Consistency is key. Small progress daily adds up to massive semester results!"
            )
        else:
            try:
                # Attempt to return empty constructor
                return response_schema()
            except Exception:
                return None
        
    try:
        model = genai.GenerativeModel(
            model_name=model_name,
            system_instruction=system_instruction
        )
        response = model.generate_content(
            prompt,
            generation_config=genai.GenerationConfig(
                response_mime_type="application/json",
                response_schema=response_schema,
                temperature=temperature
            )
        )
        # Parse output as schema
        return response_schema.model_validate_json(response.text)
    except Exception as e:
        print(f"Structured output error: {e}")
        return None
