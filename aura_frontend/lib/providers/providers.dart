import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aura_frontend/models/models.dart';
import 'package:aura_frontend/services/api_service.dart';
import 'package:aura_frontend/services/local_storage.dart';
import 'package:aura_frontend/services/firebase_service.dart';

// --- Authentication & Profile Provider ---
class AuthNotifier extends Notifier<StudentProfile?> {
  @override
  StudentProfile? build() {
    final local = LocalStorageService.getProfile();
    if (local != null) {
      return StudentProfile.fromJson(local);
    }
    return null;
  }

  Future<bool> onboard(Map<String, dynamic> data) async {
    final ok = await ApiService.onboard(data);
    if (ok) {
      state = StudentProfile.fromJson(data);
    }
    return ok;
  }

  void setLocalProfile(Map<String, dynamic> data) {
    LocalStorageService.saveProfile(data);
    final subjects = data['subjects'] as List? ?? [];
    LocalStorageService.initializeSubjectsCache(subjects);
    state = StudentProfile.fromJson(data);
  }

  Future<StudentProfile?> loadProfile(String studentId) async {
    final profile = await ApiService.getProfile(studentId);
    if (profile != null) {
      state = profile;
    } else {
      state = null;
      LocalStorageService.clearProfile();
    }
    return profile;
  }

  void logout() {
    LocalStorageService.clearProfile();
    state = null;
  }
}

final authProvider = NotifierProvider<AuthNotifier, StudentProfile?>(AuthNotifier.new);

// --- Connection Status Provider ---
final onlineProvider = FutureProvider<bool>((ref) async {
  return ApiService.checkConnection();
});

// --- Attendance Provider ---
class AttendanceNotifier extends Notifier<AttendanceAnalysis?> {
  @override
  AttendanceAnalysis? build() {
    return null;
  }

  Future<void> load(String studentId) async {
    final data = await ApiService.getAttendanceSummary(studentId);
    if (data != null) {
      state = data;
    }
  }

  /// Record attendance — only accepts 'present' or 'absent' (leave removed)
  Future<void> record(int subjectId, DateTime date, String status) async {
    assert(status == 'present' || status == 'absent',
        'Status must be "present" or "absent"');
    final student = ref.read(authProvider);
    if (student == null) return;

    // 1. Update daily status log and recalculate cache immediately
    LocalStorageService.saveDailyStatus(subjectId, date, status);
    LocalStorageService.recalculateAndCacheAttendanceForSubject(subjectId);

    // 2. Build and update the state locally immediately (optimistic UI update)
    _updateStateLocally();

    // 3. Trigger network call in background without blocking UI
    ApiService.recordAttendance(subjectId, date, status).then((success) {
      if (success) {
        ApiService.getAttendanceSummary(student.id).then((data) {
          if (data != null) {
            state = data;
          }
        });
      }
    });
  }

  Future<void> clearRecord(int subjectId, DateTime date) async {
    final student = ref.read(authProvider);
    if (student == null) return;

    // 1. Clear daily status log and recalculate cache immediately
    LocalStorageService.clearDailyStatus(subjectId, date);
    LocalStorageService.recalculateAndCacheAttendanceForSubject(subjectId);

    // 2. Build and update the state locally immediately
    _updateStateLocally();

    // 3. Trigger network call in background
    ApiService.clearAttendance(subjectId, date).then((success) {
      if (success) {
        ApiService.getAttendanceSummary(student.id).then((data) {
          if (data != null) {
            state = data;
          }
        });
      }
    });
  }

  void _updateStateLocally() {
    final cachedDetail = LocalStorageService.getCachedAttendance();
    if (cachedDetail.isNotEmpty) {
      final student = ref.read(authProvider);
      final target = student?.attendanceTarget ?? 75.0;

      int totalCredits = 0;
      double weightedScore = 0.0;
      int totalPresent = 0;
      int totalClasses = 0;

      for (var e in cachedDetail) {
        final credits = (e['credits'] as num?)?.toInt() ?? 3;
        totalCredits += credits;
        
        final present = (e['present'] as num?)?.toInt() ?? 0;
        final absent = (e['absent'] as num?)?.toInt() ?? 0;
        totalPresent += present;
        totalClasses += (present + absent);
      }

      if (totalCredits == 0) totalCredits = 1;

      for (var e in cachedDetail) {
        final credits = (e['credits'] as num?)?.toInt() ?? 3;
        final pct = (e['percentage'] as num?)?.toDouble() ?? 100.0;
        final subjScore = target > 0 ? (pct / target) * 100.0 : 100.0;
        weightedScore += (subjScore > 100.0 ? 100.0 : subjScore) * (credits / totalCredits);
      }

      final overall = totalClasses > 0 ? (totalPresent / totalClasses) * 100.0 : 100.0;
      final health = weightedScore;

      // Keep previous AI prediction text to avoid visual jittering
      final prevAi = state?.aiPredictionSummary ?? "Recalculating details...";
      final prevSafe = state?.safeLeaveSummary ?? "Recalculating buffers...";

      state = AttendanceAnalysis(
        healthScore: health,
        overallPercentage: overall,
        subjectsDetail: cachedDetail.map((e) => SubjectAttendanceDetail.fromJson(e)).toList(),
        aiPredictionSummary: prevAi,
        safeLeaveSummary: prevSafe,
      );
    }
  }
}

final attendanceProvider = NotifierProvider<AttendanceNotifier, AttendanceAnalysis?>(AttendanceNotifier.new);

// --- Syllabus Tracker Provider ---
class SyllabusNotifier extends Notifier<List<SubjectSyllabus>> {
  @override
  List<SubjectSyllabus> build() {
    return [];
  }

  Future<void> load(String studentId) async {
    final data = await ApiService.getSyllabusTracker(studentId);
    state = data;
  }

  Future<void> updateUnit(int unitId, String status, String studentId) async {
    // Optimistically update the list in memory
    state = state.map((subj) {
      final updatedUnits = subj.units.map((u) {
        if (u.id == unitId) {
          return SyllabusUnit(
            id: u.id,
            subjectId: u.subjectId,
            unitNumber: u.unitNumber,
            title: u.title,
            status: status,
            description: u.description,
            completionDate: u.completionDate,
          );
        }
        return u;
      }).toList();
      return SubjectSyllabus(
        subjectId: subj.subjectId,
        subjectName: subj.subjectName,
        units: updatedUnits,
      );
    }).toList();

    // Call API in the background
    ApiService.updateSyllabusUnit(unitId, status).then((success) {
      if (!success) {
        // If background update fails, reload from server
        load(studentId);
      }
    });
  }

  Future<void> editUnit(int unitId, String title, String description, String status, String completionDate, String studentId) async {
    final success = await ApiService.editSyllabusUnit(unitId, title, description, status, completionDate);
    if (success) {
      await load(studentId);
    }
  }
}

final syllabusProvider = NotifierProvider<SyllabusNotifier, List<SubjectSyllabus>>(SyllabusNotifier.new);

// --- Goals Provider ---
class GoalsNotifier extends Notifier<List<Goal>> {
  @override
  List<Goal> build() {
    return [];
  }

  Future<void> load(String studentId) async {
    final data = await ApiService.getGoals(studentId);
    state = data;
  }

  Future<void> add(String studentId, String title, String timeframe) async {
    final newGoal = await ApiService.createGoal(studentId, title, timeframe);
    if (newGoal != null) {
      await load(studentId);
    }
  }

  Future<void> toggle(int goalId, String studentId) async {
    final success = await ApiService.toggleGoal(goalId);
    if (success) {
      await load(studentId);
    }
  }

  Future<void> delete(int goalId, String studentId) async {
    final success = await ApiService.deleteGoal(goalId);
    if (success) {
      await load(studentId);
    }
  }
}

final goalsProvider = NotifierProvider<GoalsNotifier, List<Goal>>(GoalsNotifier.new);

// --- AI Chat History Provider --- (kept for backward compat, but command-based UI used)
class Message {
  final String text;
  final bool isUser;
  final String? agentType;
  final Map<String, dynamic>? structuredData;
  final DateTime timestamp;

  Message({
    required this.text,
    required this.isUser,
    this.agentType,
    this.structuredData,
    DateTime? timestamp,
  }) : this.timestamp = timestamp ?? DateTime.now();
}

class ChatNotifier extends Notifier<List<Message>> {
  @override
  List<Message> build() {
    return [
      Message(
        text: "Hello! I am AURA, your Academic AI Assistant. Tap a command below to get personalized insights.",
        isUser: false,
        agentType: 'general'
      )
    ];
  }

  Future<void> sendMessage(String studentId, String text) async {
    state = [...state, Message(text: text, isUser: true)];

    final response = await ApiService.sendMessage(studentId, text);
    if (response != null) {
      state = [
        ...state,
        Message(
          text: response['response'] ?? '',
          isUser: false,
          agentType: response['agent_type'],
          structuredData: response['structured_data']
        )
      ];
    } else {
      state = [
        ...state,
        Message(
          text: "I couldn't reach the AI Agents right now. Check your internet connection or backend services.",
          isUser: false,
          agentType: 'general'
        )
      ];
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<Message>>(ChatNotifier.new);

// --- Tasks Provider ---
class TasksNotifier extends Notifier<List<Task>> {
  @override
  List<Task> build() {
    return [];
  }

  Future<void> load(String studentId) async {
    final data = await ApiService.getTasks(studentId);
    state = data;
  }

  Future<void> add(Map<String, dynamic> payload) async {
    final newTask = await ApiService.createTask(payload);
    if (newTask != null) {
      await load(payload['student_id']);
    }
  }

  Future<void> toggle(int taskId, String studentId) async {
    final success = await ApiService.toggleTask(taskId);
    if (success) {
      await load(studentId);
    }
  }

  Future<void> delete(int taskId, String studentId) async {
    final success = await ApiService.deleteTask(taskId);
    if (success) {
      state = state.where((t) => t.id != taskId).toList();
    }
  }
}

final tasksProvider = NotifierProvider<TasksNotifier, List<Task>>(TasksNotifier.new);

// --- Resource Vault Provider (Firebase-backed) ---
class ResourcesNotifier extends Notifier<List<KnowledgeFile>> {
  @override
  List<KnowledgeFile> build() {
    return [];
  }

  void listenToStream(String userId, {String? subject}) {
    FirebaseService.getFilesStream(userId, subject: subject).listen((files) {
      state = files;
    });
  }

  Future<KnowledgeFile?> upload({
    required String userId,
    required String subject,
    required String fileName,
    List<int>? fileBytes,
    String? filePath,
  }) async {
    final Uint8List? typedBytes = fileBytes != null
        ? Uint8List.fromList(fileBytes)
        : null;

    final result = await FirebaseService.uploadFile(
      userId: userId,
      subject: subject,
      fileName: fileName,
      fileBytes: typedBytes,
      filePath: filePath,
    );

    if (result != null) {
      // Notify Backend for RAG Ingestion
      ApiService.uploadNote(
        userId,
        result.id,
        fileName,
        fileBytes: fileBytes,
        filepath: filePath,
      );

      state = [result, ...state];
    }
    return result;
  }

  Future<bool> delete(String userId, String fileId, String storagePath) async {
    final ok = await FirebaseService.deleteFile(userId, fileId, storagePath);
    if (ok) {
      state = state.where((f) => f.id != fileId).toList();
    }
    return ok;
  }

  Future<bool> rename(String userId, String fileId, String newName) async {
    final ok = await FirebaseService.renameFile(userId, fileId, newName);
    if (ok) {
      state = state.map((f) {
        if (f.id == fileId) {
          return KnowledgeFile(
            id: f.id,
            studentId: f.studentId,
            filename: newName,
            filePath: f.filePath,
            downloadUrl: f.downloadUrl,
            subject: f.subject,
            fileSize: f.fileSize,
            uploadTime: f.uploadTime,
          );
        }
        return f;
      }).toList();
    }
    return ok;
  }
}

final resourcesProvider = NotifierProvider<ResourcesNotifier, List<KnowledgeFile>>(ResourcesNotifier.new);

// --- Exams Provider (Firebase-backed) ---
class ExamsNotifier extends Notifier<List<Exam>> {
  @override
  List<Exam> build() {
    return [];
  }

  void listenToStream(String userId) {
    FirebaseService.getExamsStream(userId).listen((exams) {
      state = exams;
    });
  }

  Future<Exam?> add(String userId, Exam exam) async {
    final saved = await FirebaseService.saveExam(userId, exam);
    if (saved != null) {
      state = [...state, saved];
    }
    return saved;
  }

  Future<bool> delete(String userId, String examId) async {
    final ok = await FirebaseService.deleteExam(userId, examId);
    if (ok) {
      state = state.where((e) => e.id != examId).toList();
    }
    return ok;
  }
}

final examsProvider = NotifierProvider<ExamsNotifier, List<Exam>>(ExamsNotifier.new);

// --- Assignments Provider (Firebase-backed) ---
class AssignmentsNotifier extends Notifier<List<Assignment>> {
  @override
  List<Assignment> build() {
    return [];
  }

  void listenToStream(String userId) {
    FirebaseService.getAssignmentsStream(userId).listen((assignments) {
      state = assignments;
    });
  }

  Future<Assignment?> add(String userId, Assignment assignment) async {
    final saved = await FirebaseService.saveAssignment(userId, assignment);
    if (saved != null) {
      state = [...state, saved];
    }
    return saved;
  }

  Future<bool> toggle(String userId, String assignmentId, String currentStatus) async {
    final ok = await FirebaseService.toggleAssignment(userId, assignmentId, currentStatus);
    if (ok) {
      final newStatus = currentStatus == 'submitted' ? 'pending' : 'submitted';
      state = state.map((a) {
        if (a.id == assignmentId) {
          return Assignment(
            id: a.id,
            studentId: a.studentId,
            title: a.title,
            subject: a.subject,
            dueDate: a.dueDate,
            priority: a.priority,
            status: newStatus,
            reminderSet: a.reminderSet,
          );
        }
        return a;
      }).toList();
    }
    return ok;
  }

  Future<bool> delete(String userId, String assignmentId) async {
    final ok = await FirebaseService.deleteAssignment(userId, assignmentId);
    if (ok) {
      state = state.where((a) => a.id != assignmentId).toList();
    }
    return ok;
  }
}

final assignmentsProvider = NotifierProvider<AssignmentsNotifier, List<Assignment>>(AssignmentsNotifier.new);
