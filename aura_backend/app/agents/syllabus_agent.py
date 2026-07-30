import io
import re
import json
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
import google.generativeai as genai
from pypdf import PdfReader
from aura_backend.app.core.config import settings

# Structured Output Schemas
class SyllabusSubject(BaseModel):
    name: str
    credits: int

class SyllabusStructure(BaseModel):
    subjects: List[SyllabusSubject]

class SyllabusAgent:
    DEFAULT_SUBJECTS = [
        {"name": "Network Security and Cryptography", "credits": 4},
        {"name": "Database Management Systems", "credits": 3},
        {"name": "Formal Languages and Automata Theory", "credits": 3},
        {"name": "Professional Elective - I", "credits": 3},
        {"name": "Professional Elective - II", "credits": 3},
        {"name": "Network Security and Cryptography Lab", "credits": 1},
        {"name": "Database Management Systems Lab", "credits": 1},
        {"name": "Advanced English Communication Skills Lab", "credits": 1},
        {"name": "UI design-Flutter", "credits": 1},
        {"name": "Intellectual Property Rights", "credits": 0}
    ]

    @classmethod
    def parse_document(cls, file_bytes: bytes, filename: str) -> Dict[str, Any]:
        """
        Parses a syllabus sheet (either PDF or image) using Gemini if available.
        Falls back to rule-based PDF parsing or standard JNTU III-I syllabus mockup.
        """
        ext = filename.split('.')[-1].lower()
        
        # 1. Process PDF file
        if ext == 'pdf':
            text_content = cls._extract_text_from_pdf(file_bytes)
            if not text_content:
                # Fallback if PDF text extraction returns empty
                return {"subjects": cls.DEFAULT_SUBJECTS}
            
            # Try parsing using Gemini
            if settings.GEMINI_API_KEY:
                try:
                    genai.configure(api_key=settings.GEMINI_API_KEY)
                    model = genai.GenerativeModel("gemini-1.5-flash")
                    
                    prompt = f"""
                    Analyze the following syllabus text extracted from a university course sheet.
                    Identify each subject/course along with its credit score (an integer).
                    
                    Syllabus Text:
                    {text_content}
                    """
                    
                    response = model.generate_content(
                        prompt,
                        generation_config=genai.GenerationConfig(
                            response_mime_type="application/json",
                            response_schema=SyllabusStructure,
                            temperature=0.1
                        )
                    )
                    parsed_data = json.loads(response.text)
                    if "subjects" in parsed_data and parsed_data["subjects"]:
                        return parsed_data
                except Exception as e:
                    print(f"Gemini PDF parsing failed: {e}. Falling back to rule-based parser...")
            
            # Fallback to local rule-based parsing on PDF text
            return cls._rule_based_text_parse(text_content)
            
        # 2. Process Image file
        else:
            if settings.GEMINI_API_KEY:
                try:
                    genai.configure(api_key=settings.GEMINI_API_KEY)
                    model = genai.GenerativeModel("gemini-1.5-flash")
                    
                    mime_type = "image/png"
                    if ext in ['jpg', 'jpeg']:
                        mime_type = "image/jpeg"
                        
                    image_part = {
                        "mime_type": mime_type,
                        "data": file_bytes
                    }
                    
                    prompt = """
                    Extract all subjects/courses from the provided syllabus table image.
                    For each course row in the table, extract:
                    1. Course Name/Title as 'name'.
                    2. Credits as 'credits' (integer, e.g. 1, 2, 3, 4).
                    """
                    
                    response = model.generate_content(
                        [image_part, prompt],
                        generation_config=genai.GenerationConfig(
                            response_mime_type="application/json",
                            response_schema=SyllabusStructure,
                            temperature=0.1
                        )
                    )
                    parsed_data = json.loads(response.text)
                    if "subjects" in parsed_data and parsed_data["subjects"]:
                        return parsed_data
                except Exception as e:
                    print(f"Gemini image parsing failed: {e}")
            
            # Fallback mock subjects
            return {"subjects": cls.DEFAULT_SUBJECTS}

    @classmethod
    def _extract_text_from_pdf(cls, file_bytes: bytes) -> str:
        try:
            reader = PdfReader(io.BytesIO(file_bytes))
            text = ""
            for page in reader.pages:
                text += page.extract_text() or ""
            return text.strip()
        except Exception as e:
            print(f"Error reading PDF bytes: {e}")
            return ""

    @classmethod
    def _rule_based_text_parse(cls, text: str) -> Dict[str, Any]:
        """
        Parses raw text structure looking for courses and credits dynamically.
        """
        subjects = []
        lines = text.split('\n')
        
        for line in lines:
            line_clean = line.strip()
            if not line_clean:
                continue
            
            # Pattern: matches a course name (at least 5 characters) followed by credits (number)
            # e.g., "Network Security and Cryptography 4" or "Database Management Systems Credits: 3"
            match = re.search(r'^([a-zA-Z\s\-\,\&\/]+?)(?:\s+(?:credits|credit|L|T|P|c)?\s*[:\-]?\s*([0-5]))\s*$', line_clean, re.IGNORECASE)
            if match:
                name = match.group(1).strip()
                try:
                    credits = int(match.group(2))
                except ValueError:
                    credits = 3
                if len(name) >= 5 and not name.lower().startswith('semester') and not name.lower().startswith('credits'):
                    subjects.append({"name": name, "credits": credits})
        
        # If we failed to find any structured subjects, scan our default list names in the text
        if not subjects:
            for default_sub in cls.DEFAULT_SUBJECTS:
                # If course keyword is mentioned, add it
                keywords = default_sub["name"].split()
                main_keywords = [w for w in keywords if len(w) > 3 and w.lower() not in ['and', 'with', 'skills', 'lab', 'theory']]
                if main_keywords and any(re.search(r'\b' + re.escape(w) + r'\b', text, re.IGNORECASE) for w in main_keywords):
                    subjects.append(default_sub)
                    
        # Final fallback to defaults if list is still empty
        if not subjects:
            return {"subjects": cls.DEFAULT_SUBJECTS}
            
        return {"subjects": subjects}
