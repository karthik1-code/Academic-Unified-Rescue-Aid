from typing import List
from pydantic import BaseModel
from aura_backend.app.agents.gemini_client import generate_structured

class VerifiedResource(BaseModel):
    title: str
    platform: str # 'NPTEL', 'MIT OCW', 'Stanford Online', 'MDN', 'GeeksforGeeks', 'Google Developers', etc.
    url: str
    description: str

class ResourceRecommendations(BaseModel):
    topic: str
    recommendations: List[VerifiedResource]

def get_resources_for_topic(topic: str, subject_name: str = "") -> ResourceRecommendations:
    prompt = (
        f"You are the Resource Agent of AURA, an AI academic assistant.\n"
        f"The student needs verified, high-quality learning resources for the topic: '{topic}'"
        f"{f' in the subject: {subject_name}' if subject_name else ''}.\n\n"
        f"Provide a list of 3-4 highly relevant, actual learning resources from the following approved platforms:\n"
        f"- NPTEL (Indian Institutes of Technology)\n"
        f"- MIT OpenCourseWare (MIT OCW)\n"
        f"- Stanford Online\n"
        f"- MDN Web Docs (for web dev)\n"
        f"- GeeksforGeeks\n"
        f"- freeCodeCamp\n"
        f"- Google Developers / Microsoft Learn (for software/dev subjects)\n"
        f"- Coursera / edX\n\n"
        f"Ensure the URLs are valid domain URLs for these resources and describe why the resource is excellent for mastering this specific topic."
    )
    
    system_instruction = (
        "You are an academic resource curator. You recommend only high-quality, verified materials "
        "and avoid generic search engine pages. Return exactly structured ResourceRecommendations."
    )
    
    recommendations = generate_structured(
        prompt=prompt,
        response_schema=ResourceRecommendations,
        system_instruction=system_instruction,
        temperature=0.2
    )
    
    if not recommendations:
        # Fallback recommendations if AI is disabled or fails
        fallback_rec = []
        if "web" in topic.lower() or "javascript" in topic.lower() or "html" in topic.lower():
            fallback_rec.append(VerifiedResource(
                title="MDN Web Docs - Learning Web Development",
                platform="MDN",
                url="https://developer.mozilla.org/en-US/docs/Learn",
                description="The absolute gold standard for web standards, HTML, CSS, and JavaScript tutorials."
            ))
        else:
            fallback_rec.append(VerifiedResource(
                title="MIT OpenCourseWare - Computer Science Courses",
                platform="MIT OCW",
                url="https://ocw.mit.edu/search/?q=" + topic,
                description="Comprehensive lectures, assignments, and lecture notes directly from MIT."
            ))
            fallback_rec.append(VerifiedResource(
                title="GeeksforGeeks - " + topic + " Tutorial",
                platform="GeeksforGeeks",
                url="https://www.geeksforgeeks.org/search/?q=" + topic,
                description="Excellent step-by-step explanations, code examples, and interview questions."
            ))
            
        recommendations = ResourceRecommendations(
            topic=topic,
            recommendations=fallback_rec
        )
        
    return recommendations
