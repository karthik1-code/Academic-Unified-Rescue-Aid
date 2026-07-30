import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from aura_backend.app.core.config import settings
from aura_backend.app.core.database import create_db_and_tables
from aura_backend.app.core.vector_db import init_vector_db

# Import routers
from aura_backend.app.api.auth import router as auth_router
from aura_backend.app.api.attendance import router as attendance_router
from aura_backend.app.api.syllabus import router as syllabus_router
from aura_backend.app.api.goals import router as goals_router
from aura_backend.app.api.knowledge import router as knowledge_router
from aura_backend.app.api.ai_assistant import router as ai_router
from aura_backend.app.api.tasks import router as tasks_router
from aura_backend.app.api.resources import router as resources_router

app = FastAPI(
    title="AURA API",
    description="Backend services for AURA: AI Academic Operating System",
    version="1.0.0"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register event handlers
@app.on_event("startup")
def on_startup():
    print("Starting up AURA backend services...")
    # 1. Initialize SQLite Database Tables
    create_db_and_tables()
    # 2. Initialize Qdrant Collection
    init_vector_db()
    print("Startup checks complete. AURA is online.")

# Register routers
app.include_router(auth_router, prefix="/api")
app.include_router(attendance_router, prefix="/api")
app.include_router(syllabus_router, prefix="/api")
app.include_router(goals_router, prefix="/api")
app.include_router(knowledge_router, prefix="/api")
app.include_router(ai_router, prefix="/api")
app.include_router(tasks_router, prefix="/api")
app.include_router(resources_router, prefix="/api")

@app.get("/")
def read_root():
    return {
        "status": "online",
        "service": "AURA AI Academic Operating System API",
        "docs_url": "/docs"
    }

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
