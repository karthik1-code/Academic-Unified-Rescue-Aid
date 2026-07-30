from typing import Dict, Any, Optional
from pydantic import BaseModel
from aura_backend.app.core.firestore import db
from aura_backend.app.agents.gemini_client import generate_text, generate_structured, is_ai_enabled
from aura_backend.app.agents.attendance_agent import get_attendance_analysis
from aura_backend.app.agents.planner_agent import generate_daily_study_plan
from aura_backend.app.agents.resource_agent import get_resources_for_topic
from aura_backend.app.agents.knowledge_agent import answer_query_with_vault

class AgentRoute(BaseModel):
    agent: str # 'attendance', 'planner', 'resource', 'knowledge', 'general'
    confidence: float
    reason: str

class OrchestratedResponse(BaseModel):
    response: str
    agent_type: str
    structured_data: Optional[Dict[str, Any]] = None

def classify_query(query: str, has_knowledge_vault: bool = False) -> AgentRoute:
    prompt = (
        f"You are the Router of the AURA AI Academic Operating System. "
        f"Classify the following student query into one of these agent types:\n"
        f"1. 'attendance': For questions about skipping classes, attendance levels, safe leave math, or recovery plans.\n"
        f"2. 'planner': For queries requesting study schedules, tasks lists, study timing, or planning.\n"
        f"3. 'resource': For requests asking for courses, tutorials, web documentation, or links from MIT, NPTEL, Stanford, etc.\n"
        f"4. 'knowledge': For questions relating to uploaded documents, syllabus contents, notes, summaries, or questions about the course material "
        f"(Knowledge Vault database availability: {has_knowledge_vault}).\n"
        f"5. 'general': For general chit-chat, setup advice, motivation, or questions unrelated to specific files or trackers.\n\n"
        f"Student Query: '{query}'\n"
    )
    
    system_instruction = "You are a routing system. Classify the user query and return the specific Route model."
    
    route = generate_structured(
        prompt=prompt,
        response_schema=AgentRoute,
        system_instruction=system_instruction,
        temperature=0.1
    )
    
    if not route:
        # Simple local rule-based routing fallback
        lower_q = query.lower()
        if any(w in lower_q for w in ["skip", "leave", "attendance", "absent", "present", "bunk"]):
            return AgentRoute(agent="attendance", confidence=1.0, reason="Keywords matched")
        elif any(w in lower_q for w in ["plan", "schedule", "timetable", "study plan", "today"]):
            return AgentRoute(agent="planner", confidence=1.0, reason="Keywords matched")
        elif any(w in lower_q for w in ["resource", "tutorial", "course", "nptel", "mit", "learn", "link"]):
            return AgentRoute(agent="resource", confidence=1.0, reason="Keywords matched")
        elif any(w in lower_q for w in ["note", "slide", "pdf", "file", "summarize", "explain"]):
            return AgentRoute(agent="knowledge", confidence=1.0, reason="Keywords matched")
        else:
            return AgentRoute(agent="general", confidence=1.0, reason="Default fallback")
            
    return route

def process_student_query(student_id: str, query: str) -> OrchestratedResponse:
    # Check if student has uploaded any files
    files_docs = db.collection("knowledge_files").where("student_id", "==", student_id).get()
    has_files = len(files_docs) > 0
    
    # Route query
    route = classify_query(query, has_knowledge_vault=has_files)
    agent = route.agent
    
    if agent == "knowledge" and not has_files:
        agent = "general"
        
    if agent == "attendance":
        try:
            analysis = get_attendance_analysis(student_id)
            profile_doc = db.collection("student_profiles").document(student_id).get()
            student_data = profile_doc.to_dict() if profile_doc.exists else {}
            target = student_data.get("attendance_target", 75.0)
            
            if not is_ai_enabled():
                critical_subs = [s for s in analysis.subjects_detail if s.percentage < target]
                if critical_subs:
                    crit_text = "\n".join([f"- **{s.subject_name}**: {s.percentage:.1f}% (Needs {s.required_to_recover} classes to recover)" for s in critical_subs])
                    response_text = f"Your overall attendance is **{analysis.overall_percentage:.1f}%** with a health score of **{analysis.health_score}/100**.\n\n⚠️ **Action Required**: The following subjects are below your target of {target:.0f}%:\n{crit_text}\n\nAvoid skipping classes in these modules to recover your attendance status."
                else:
                    safe_subs = [s for s in analysis.subjects_detail if s.safe_leaves > 0]
                    if safe_subs:
                        safe_text = ", ".join([f"**{s.subject_name}** ({s.safe_leaves} classes)" for s in safe_subs])
                        response_text = f"Your overall attendance is in excellent health (**{analysis.overall_percentage:.1f}%**). You have safe skip cushions available for: {safe_text}."
                    else:
                        response_text = f"Your overall attendance is **{analysis.overall_percentage:.1f}%**. All subjects are currently safe, but you are close to the limit. Try not to skip any more classes today!"
                return OrchestratedResponse(
                    response=response_text,
                    agent_type="attendance",
                    structured_data=analysis.model_dump()
                )
            
            prompt = (
                f"You are the Attendance Agent of AURA.\n"
                f"A student asked: '{query}'\n\n"
                f"Here is their current attendance database status:\n"
                f"- Overall Percentage: {analysis.overall_percentage}%\n"
                f"- Health Score: {analysis.health_score}/100\n"
                f"Details per subject:\n"
            )
            for s in analysis.subjects_detail:
                prompt += f"  * {s.subject_name}: {s.percentage:.1f}% ({s.status_label}). Safe leaves remaining: {s.safe_leaves}. Recovery lectures required: {s.required_to_recover}.\n"
                
            prompt += f"\nAnswer the student's query precisely, displaying the mathematical facts. Keep it concise."
            
            response_text = generate_text(
                prompt=prompt,
                system_instruction="You are an attendance expert. Use absolute numbers and percentages, giving direct advice. Format with Markdown tables or lists.",
                temperature=0.3
            )
            return OrchestratedResponse(
                response=response_text,
                agent_type="attendance",
                structured_data=analysis.model_dump()
            )
        except Exception as e:
            return OrchestratedResponse(
                response=f"I couldn't load your attendance records. Make sure your profile has subjects onboarded! (Details: {e})",
                agent_type="attendance"
            )
            
    elif agent == "planner":
        try:
            plan = generate_daily_study_plan(student_id)
            tasks_str = "\n".join([f"- **[{t.priority} Priority]** {t.title} ({t.duration_minutes}m) - *{t.reason}*" for t in plan.tasks])
            response_text = (
                f"### Today's AI Academic Plan\n\n"
                f"*{plan.motivation_message}*\n\n"
                f"**Tasks for Today:**\n{tasks_str}\n\n"
                f"**Priority Subjects:** {', '.join(plan.priority_subjects) if plan.priority_subjects else 'None'}\n"
                f"**Revision Suggestion:** {', '.join(plan.revision_suggestions) if plan.revision_suggestions else 'None'}"
            )
            return OrchestratedResponse(
                response=response_text,
                agent_type="planner",
                structured_data=plan.model_dump()
            )
        except Exception as e:
            return OrchestratedResponse(
                response=f"I couldn't build your study schedule. Make sure onboarding is completed! (Details: {e})",
                agent_type="planner"
            )
            
    elif agent == "resource":
        try:
            subjects_docs = db.collection("subjects").where("student_id", "==", student_id).get()
            subject_names = [s.to_dict().get("name") for s in subjects_docs]
            
            topic = "Computer Science"
            if subject_names:
                topic = subject_names[0]
            for s_name in subject_names:
                if s_name.lower() in query.lower():
                    topic = s_name
                    break
                    
            if is_ai_enabled():
                topic_prompt = f"Extract the core academic subject or topic from the following query. Return only the topic string (e.g. 'Operating Systems', 'Paging', 'Linear Algebra'):\nQuery: '{query}'"
                topic = generate_text(topic_prompt, system_instruction="Return only the raw topic name.", temperature=0.1).strip()
                
            resources = get_resources_for_topic(topic)
            rec_list = []
            for r in resources.recommendations:
                rec_list.append(f"- **[{r.platform}]** [{r.title}]({r.url}): {r.description}")
            
            response_text = (
                f"Here are top verified resources I found for **{topic}**:\n\n"
                + "\n".join(rec_list)
            )
            return OrchestratedResponse(
                response=response_text,
                agent_type="resource",
                structured_data=resources.model_dump()
            )
        except Exception as e:
            return OrchestratedResponse(
                response=f"Could not fetch study resources. (Details: {e})",
                agent_type="resource"
            )
        
    elif agent == "knowledge":
        response_text = answer_query_with_vault(student_id, query)
        return OrchestratedResponse(
            response=response_text,
            agent_type="knowledge"
        )
        
    else:
        profile_doc = db.collection("student_profiles").document(student_id).get()
        student = profile_doc.to_dict() if profile_doc.exists else {}
        student_desc = f"Student Name: {student.get('name')}, Branch: {student.get('branch')}, Semester: {student.get('semester')}" if student else "New user"
        
        # Pull full real-time state for context enrichment
        subjects_docs = db.collection("subjects").where("student_id", "==", student_id).get()
        subjects = [s.to_dict() for s in subjects_docs]
        
        goals_docs = db.collection("goals").where("student_id", "==", student_id).get()
        goals = [g.to_dict() for g in goals_docs]
        
        tasks_docs = db.collection("tasks").where("student_id", "==", student_id).get()
        tasks = [t.to_dict() for t in tasks_docs]
        
        state_summary = f"Student Profile: {student_desc}\n"
        if subjects:
            state_summary += "Subjects Enrolled:\n"
            for s in subjects:
                state_summary += f"  - {s.get('name')} (Credits: {s.get('credits')})\n"
        if goals:
            state_summary += "Active Goals:\n"
            for g in goals:
                state_summary += f"  - {g.get('title')} ({g.get('timeframe')}) - Status: {g.get('status')}\n"
        if tasks:
            state_summary += "To-Do List items:\n"
            for t in tasks:
                state_summary += f"  - {t.get('title')} (Priority: {t.get('priority')}) - Completed: {t.get('is_completed')}\n"

        if not is_ai_enabled():
            name = student.get("name", "Student")
            subj_list_str = ", ".join([s.get("name", "") for s in subjects]) if subjects else "no subjects registered yet"
            response_text = (
                f"Hello {name}! I am AURA, your Academic Operating System.\n\n"
                f"I am running in local mock mode. I detected the following subjects in your profile: **{subj_list_str}**.\n\n"
                f"Feel free to ask me to write a study plan, check your skip calculator limits, or recommend course links."
            )
            return OrchestratedResponse(
                response=response_text,
                agent_type="general"
            )
            
        prompt = (
            f"You are AURA AI, the Academic Operating System companion. Help the student.\n"
            f"Current Student State Context:\n{state_summary}\n\n"
            f"Query: '{query}'\n"
        )
        
        response_text = generate_text(
            prompt=prompt,
            system_instruction="You are AURA, an AI academic mentor. You are professional, engaging, clear, and design-minded. Use markdown and bullet points.",
            temperature=0.7
        )
        return OrchestratedResponse(
            response=response_text,
            agent_type="general"
        )
