import os
import uuid
from typing import List, Dict, Any, Optional
from pypdf import PdfReader
from docx import Document
from qdrant_client.models import PointStruct, Filter, FieldCondition, MatchValue
from aura_backend.app.core.vector_db import qdrant_client, COLLECTION_NAME
from aura_backend.app.agents.gemini_client import get_embedding, generate_text, generate_structured
from pydantic import BaseModel

class Flashcard(BaseModel):
    front: str
    back: str

class MCQOption(BaseModel):
    key: str # 'A', 'B', 'C', 'D'
    text: str

class MCQ(BaseModel):
    question: str
    options: List[MCQOption]
    correct_key: str # 'A', 'B', 'C', or 'D'
    explanation: str

class VaultStudyMaterials(BaseModel):
    summary: str
    flashcards: List[Flashcard]
    mcqs: List[MCQ]

def extract_text_from_file(file_path: str) -> str:
    """Extracts text from PDF, DOCX, TXT, or MD files."""
    _, ext = os.path.splitext(file_path.lower())
    
    if ext == ".pdf":
        reader = PdfReader(file_path)
        text = ""
        for page in reader.pages:
            text += (page.extract_text() or "") + "\n"
        return text
    elif ext == ".docx":
        doc = Document(file_path)
        return "\n".join([para.text for para in doc.paragraphs])
    elif ext in [".txt", ".md"]:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            return f.read()
    else:
        raise ValueError(f"Unsupported file type: {ext}")

def chunk_text(text: str, chunk_size: int = 1000, overlap: int = 200) -> List[str]:
    """Chunks text with overlap."""
    if not text:
        return []
    chunks = []
    start = 0
    while start < len(text):
        end = start + chunk_size
        chunks.append(text[start:end])
        start += (chunk_size - overlap)
    return chunks

def ingest_document(file_path: str, student_id: str, filename: str, file_id: str):
    """Extracts, chunks, embeds, and uploads document to vector database."""
    try:
        text = extract_text_from_file(file_path)
        chunks = chunk_text(text)
        
        points = []
        for i, chunk in enumerate(chunks):
            embedding = get_embedding(chunk)
            point_id = str(uuid.uuid4())
            payload = {
                "student_id": student_id,
                "file_id": file_id,
                "filename": filename,
                "chunk_index": i,
                "content": chunk
            }
            points.append(
                PointStruct(
                    id=point_id,
                    vector=embedding,
                    payload=payload
                )
            )
            
        if points:
            qdrant_client.upsert(
                collection_name=COLLECTION_NAME,
                points=points
            )
        print(f"Successfully ingested {filename} with {len(points)} vector chunks.")
    except Exception as e:
        print(f"Error ingesting document {filename}: {e}")
        raise e

def delete_document_vectors(file_id: str):
    """Deletes vectors associated with a specific file ID."""
    try:
        qdrant_client.delete(
            collection_name=COLLECTION_NAME,
            points_selector=Filter(
                must=[
                    FieldCondition(
                        key="file_id",
                        match=MatchValue(value=file_id)
                    )
                ]
            )
        )
    except Exception as e:
        print(f"Error deleting vectors for file {file_id}: {e}")

def query_knowledge_vault(student_id: str, query: str, limit: int = 4) -> List[Dict[str, Any]]:
    """Performs semantic search across a student's uploaded notes."""
    try:
        query_vector = get_embedding(query)
        
        results = qdrant_client.search(
            collection_name=COLLECTION_NAME,
            query_vector=query_vector,
            query_filter=Filter(
                must=[
                    FieldCondition(
                        key="student_id",
                        match=MatchValue(value=student_id)
                    )
                ]
            ),
            limit=limit
        )
        
        return [
            {
                "content": r.payload["content"],
                "filename": r.payload["filename"],
                "score": r.score
            } for r in results
        ]
    except Exception as e:
        print(f"Error querying vector DB: {e}")
        return []

def answer_query_with_vault(student_id: str, query: str) -> str:
    """Answers query using RAG from the knowledge base."""
    matches = query_knowledge_vault(student_id, query)
    
    if not matches:
        return generate_text(
            prompt=query,
            system_instruction="You are AURA AI, an academic assistant. Mention that you couldn't find matching notes in the vault, and answer based on general knowledge."
        )
        
    context_str = "\n---\n".join([f"Source [{m['filename']}]: {m['content']}" for m in matches])
    
    prompt = (
        f"You are the Knowledge Agent of AURA, a student's RAG-enabled academic OS companion.\n"
        f"The student asked: '{query}'\n\n"
        f"Answer their question using the following context from their uploaded lecture notes/files. "
        f"Be precise, directly address the concepts, and credit the source filename when appropriate.\n\n"
        f"Retrieved Context:\n{context_str}"
    )
    
    return generate_text(
        prompt=prompt,
        system_instruction="You are an expert tutor. Rely heavily on the context provided, clarify details cleanly, and format outputs in structured Markdown."
    )

def generate_study_materials(student_id: str, file_path: str, filename: str) -> VaultStudyMaterials:
    """Generates study guide, flashcards, and MCQs for a newly uploaded document."""
    try:
        text = extract_text_from_file(file_path)
        # Take up to the first 12000 characters to prevent token limits on prompt
        sample_text = text[:12000]
        
        prompt = (
            f"You are the Knowledge Agent of AURA.\n"
            f"Analyze the following excerpt from the student's uploaded document: '{filename}'.\n"
            f"Generate academic study materials including:\n"
            f"1. A comprehensive markdown summary of key topics.\n"
            f"2. A list of 4 core flashcards (front/back questions and definitions).\n"
            f"3. A list of 3 high-quality multiple choice questions (MCQs) with options A, B, C, D, the correct key, and explanations.\n\n"
            f"Document excerpt:\n{sample_text}"
        )
        
        materials = generate_structured(
            prompt=prompt,
            response_schema=VaultStudyMaterials,
            system_instruction="Create accurate, clean study summaries, flashcards, and practice MCQs. Ensure options maps clearly to A, B, C, D.",
            temperature=0.3
        )
        
        if materials:
            return materials
            
    except Exception as e:
        print(f"Error generating study materials: {e}")
        
    # Return basic mockup if fails or runs in mock mode
    return VaultStudyMaterials(
        summary=f"# Quick Summary of {filename}\nUnable to generate full summary. Please check your AI API key.",
        flashcards=[
            Flashcard(front=f"What is {filename}?", back="This is your uploaded document. Ask questions in the chat to dive deeper.")
        ],
        mcqs=[
            MCQ(
                question="Is your document loaded?",
                options=[MCQOption(key="A", text="Yes"), MCQOption(key="B", text="No")],
                correct_key="A",
                explanation="Your document has been indexed and is searchable via vector similarity."
            )
        ]
    )
