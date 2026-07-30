import 'dart:convert';

class StudentProfile {
  final String id;
  final String name;
  final String university;
  final String branch;
  final String year;
  final String semester;
  final DateTime semesterStart;
  final DateTime semesterEnd;
  final double attendanceTarget;
  final double dailyStudyGoalHours;
  final String? careerGoal;
  final List<String> weakSubjects;
  final List<String> strongSubjects;

  StudentProfile({
    required this.id,
    required this.name,
    required this.university,
    required this.branch,
    required this.year,
    required this.semester,
    required this.semesterStart,
    required this.semesterEnd,
    required this.attendanceTarget,
    required this.dailyStudyGoalHours,
    this.careerGoal,
    required this.weakSubjects,
    required this.strongSubjects,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    final weakRaw = json['weak_subjects'];
    List<String> parsedWeak = [];
    if (weakRaw is List) {
      parsedWeak = weakRaw.map((e) => e.toString()).toList();
    } else if (weakRaw is String) {
      parsedWeak = weakRaw.split(',').where((e) => e.isNotEmpty).toList();
    }

    final strongRaw = json['strong_subjects'];
    List<String> parsedStrong = [];
    if (strongRaw is List) {
      parsedStrong = strongRaw.map((e) => e.toString()).toList();
    } else if (strongRaw is String) {
      parsedStrong = strongRaw.split(',').where((e) => e.isNotEmpty).toList();
    }

    DateTime parseDate(dynamic val) {
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return StudentProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      university: json['university'] ?? '',
      branch: json['branch'] ?? '',
      year: json['year'] ?? '',
      semester: json['semester'] ?? '',
      semesterStart: parseDate(json['semester_start']),
      semesterEnd: parseDate(json['semester_end']),
      attendanceTarget: (json['attendance_target'] as num?)?.toDouble() ?? 75.0,
      dailyStudyGoalHours: (json['daily_study_goal_hours'] as num?)?.toDouble() ?? 2.0,
      careerGoal: json['career_goal'],
      weakSubjects: parsedWeak,
      strongSubjects: parsedStrong,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'university': university,
      'branch': branch,
      'year': year,
      'semester': semester,
      'semester_start': semesterStart.toIso8601String().substring(0, 10),
      'semester_end': semesterEnd.toIso8601String().substring(0, 10),
      'attendance_target': attendanceTarget,
      'daily_study_goal_hours': dailyStudyGoalHours,
      'career_goal': careerGoal,
      'weak_subjects': weakSubjects.join(','),
      'strong_subjects': strongSubjects.join(','),
    };
  }
}

class Subject {
  final int id;
  final String studentId;
  final String name;
  final int credits;
  final String? faculty;
  final String color;
  final String subtitle;

  Subject({
    required this.id,
    required this.studentId,
    required this.name,
    required this.credits,
    this.faculty,
    required this.color,
    required this.subtitle,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] ?? 0,
      studentId: json['student_id'] ?? '',
      name: json['name'] ?? '',
      credits: json['credits'] ?? 0,
      faculty: json['faculty'],
      color: json['color'] ?? '0xFF4A90E2',
      subtitle: json['subtitle'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'name': name,
      'credits': credits,
      'faculty': faculty,
      'color': color,
      'subtitle': subtitle,
    };
  }
}

class AttendanceRecord {
  final int? id;
  final int subjectId;
  final DateTime date;
  final String status; // 'present', 'absent' only (leave removed)

  AttendanceRecord({
    this.id,
    required this.subjectId,
    required this.date,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'],
      subjectId: json['subject_id'] ?? 0,
      date: DateTime.parse(json['date']),
      status: json['status'] ?? 'present',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_id': subjectId,
      'date': date.toIso8601String().substring(0, 10),
      'status': status,
    };
  }
}

class SyllabusUnit {
  final int id;
  final int subjectId;
  final int unitNumber;
  final String title;
  final String status; // 'completed', 'learning', 'pending'
  final String description;
  final String? completionDate;

  SyllabusUnit({
    required this.id,
    required this.subjectId,
    required this.unitNumber,
    required this.title,
    required this.status,
    required this.description,
    this.completionDate,
  });

  factory SyllabusUnit.fromJson(Map<String, dynamic> json) {
    return SyllabusUnit(
      id: json['id'] ?? 0,
      subjectId: json['subject_id'] ?? 0,
      unitNumber: json['unit_number'] ?? 1,
      title: json['title'] ?? '',
      status: json['status'] ?? 'pending',
      description: json['description'] ?? '',
      completionDate: json['completion_date'],
    );
  }
}

class SubjectSyllabus {
  final int subjectId;
  final String subjectName;
  final List<SyllabusUnit> units;

  SubjectSyllabus({
    required this.subjectId,
    required this.subjectName,
    required this.units,
  });

  factory SubjectSyllabus.fromJson(Map<String, dynamic> json) {
    return SubjectSyllabus(
      subjectId: json['subject_id'] ?? 0,
      subjectName: json['subject_name'] ?? '',
      units: (json['units'] as List? ?? [])
          .map((e) => SyllabusUnit.fromJson(e))
          .toList(),
    );
  }
}

class Goal {
  final int id;
  final String studentId;
  final String title;
  final String timeframe; // 'daily', 'weekly', 'monthly', 'semester', 'career'
  final String status; // 'pending', 'completed'
  final DateTime dateCreated;

  Goal({
    required this.id,
    required this.studentId,
    required this.title,
    required this.timeframe,
    required this.status,
    required this.dateCreated,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return Goal(
      id: json['id'] ?? 0,
      studentId: json['student_id'] ?? '',
      title: json['title'] ?? '',
      timeframe: json['timeframe'] ?? 'daily',
      status: json['status'] ?? 'pending',
      dateCreated: parseDate(json['date_created']),
    );
  }
}

/// KnowledgeFile — updated with Firebase Storage fields
class KnowledgeFile {
  final String id; // Firestore document ID (changed from int)
  final String studentId;
  final String filename;
  final String filePath; // Storage path (used for deletion)
  final String? downloadUrl; // Firebase Storage download URL
  final String subject; // Subject tag for organizing PDFs
  final int? fileSize; // File size in bytes
  final DateTime uploadTime;

  KnowledgeFile({
    required this.id,
    required this.studentId,
    required this.filename,
    required this.filePath,
    this.downloadUrl,
    required this.subject,
    this.fileSize,
    required this.uploadTime,
  });

  factory KnowledgeFile.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return KnowledgeFile(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id'] ?? '',
      filename: json['filename'] ?? '',
      filePath: json['file_path'] ?? '',
      downloadUrl: json['download_url'],
      subject: json['subject'] ?? 'General',
      fileSize: (json['file_size'] as num?)?.toInt(),
      uploadTime: parseDate(json['upload_time']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'filename': filename,
      'file_path': filePath,
      'download_url': downloadUrl,
      'subject': subject,
      'file_size': fileSize,
      'upload_time': uploadTime.toIso8601String(),
    };
  }
}

class DailyPlanTask {
  final String title;
  final int durationMinutes;
  final String category; // 'Study', 'Attendance', 'Goal', 'Revision'
  final String priority; // 'High', 'Medium', 'Low'
  final String reason;

  DailyPlanTask({
    required this.title,
    required this.durationMinutes,
    required this.category,
    required this.priority,
    required this.reason,
  });

  factory DailyPlanTask.fromJson(Map<String, dynamic> json) {
    return DailyPlanTask(
      title: json['title'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 0,
      category: json['category'] ?? 'Study',
      priority: json['priority'] ?? 'Medium',
      reason: json['reason'] ?? '',
    );
  }
}

class StudyPlan {
  final String date;
  final List<DailyPlanTask> tasks;
  final List<String> prioritySubjects;
  final List<String> revisionSuggestions;
  final String motivationMessage;

  StudyPlan({
    required this.date,
    required this.tasks,
    required this.prioritySubjects,
    required this.revisionSuggestions,
    required this.motivationMessage,
  });

  factory StudyPlan.fromJson(Map<String, dynamic> json) {
    return StudyPlan(
      date: json['date'] ?? '',
      tasks: (json['tasks'] as List? ?? [])
          .map((e) => DailyPlanTask.fromJson(e))
          .toList(),
      prioritySubjects: List<String>.from(json['priority_subjects'] ?? []),
      revisionSuggestions: List<String>.from(json['revision_suggestions'] ?? []),
      motivationMessage: json['motivation_message'] ?? '',
    );
  }
}

class SubjectAttendanceDetail {
  final int subjectId;
  final String subjectName;
  final int credits;
  final int present;
  final int absent;
  // 'leave' removed — attendance = present / (present + absent) only
  final int totalClasses; // present + absent
  final double percentage;
  final String statusLabel;
  final int safeLeaves;
  final int requiredToRecover;
  final String recoverySuggestion;
  final String subtitle;

  SubjectAttendanceDetail({
    required this.subjectId,
    required this.subjectName,
    required this.credits,
    required this.present,
    required this.absent,
    required this.totalClasses,
    required this.percentage,
    required this.statusLabel,
    required this.safeLeaves,
    required this.requiredToRecover,
    required this.recoverySuggestion,
    required this.subtitle,
  });

  factory SubjectAttendanceDetail.fromJson(Map<String, dynamic> json) {
    final present = (json['present'] as num?)?.toInt() ?? 0;
    final absent = (json['absent'] as num?)?.toInt() ?? 0;
    // Recalculate percentage excluding leave
    final total = present + absent;
    final pct = total > 0 ? (present / total) * 100.0 : 100.0;

    return SubjectAttendanceDetail(
      subjectId: json['subject_id'] ?? 0,
      subjectName: json['subject_name'] ?? '',
      credits: json['credits'] ?? 0,
      present: present,
      absent: absent,
      totalClasses: total,
      percentage: (json['percentage'] as num?)?.toDouble() ?? pct,
      statusLabel: json['status_label'] ?? 'Safe',
      safeLeaves: json['safe_leaves'] ?? 0,
      requiredToRecover: json['required_to_recover'] ?? 0,
      recoverySuggestion: json['recovery_suggestion'] ?? '',
      subtitle: json['subtitle'] ?? '',
    );
  }
}

class AttendanceAnalysis {
  final double healthScore;
  final double overallPercentage;
  final List<SubjectAttendanceDetail> subjectsDetail;
  final String aiPredictionSummary;
  final String safeLeaveSummary;

  AttendanceAnalysis({
    required this.healthScore,
    required this.overallPercentage,
    required this.subjectsDetail,
    required this.aiPredictionSummary,
    required this.safeLeaveSummary,
  });

  factory AttendanceAnalysis.fromJson(Map<String, dynamic> json) {
    return AttendanceAnalysis(
      healthScore: (json['health_score'] as num?)?.toDouble() ?? 100.0,
      overallPercentage: (json['overall_percentage'] as num?)?.toDouble() ?? 100.0,
      subjectsDetail: (json['subjects_detail'] as List? ?? [])
          .map((e) => SubjectAttendanceDetail.fromJson(e))
          .toList(),
      aiPredictionSummary: json['ai_prediction_summary'] ?? '',
      safeLeaveSummary: json['safe_leave_summary'] ?? '',
    );
  }
}

class Task {
  final int id;
  final String studentId;
  final String title;
  final String description;
  final String priority; // 'High', 'Medium', 'Low'
  final String category; // 'Study', 'Exam', 'Assignment', 'Personal'
  final String date; // YYYY-MM-DD
  final String startTime;
  final String endTime;
  final bool isCompleted;
  final bool reminder;
  final String repeat; // 'None', 'Daily', 'Weekly'
  final String? reminderTime;

  Task({
    required this.id,
    required this.studentId,
    required this.title,
    required this.description,
    required this.priority,
    required this.category,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.isCompleted,
    required this.reminder,
    required this.repeat,
    this.reminderTime,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? 0,
      studentId: json['student_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      priority: json['priority'] ?? 'Medium',
      category: json['category'] ?? 'Study',
      date: json['date'] ?? '',
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      isCompleted: json['is_completed'] == true || json['status'] == 'completed',
      reminder: json['reminder'] == true,
      repeat: json['repeat'] ?? 'None',
      reminderTime: json['reminder_time'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'title': title,
      'description': description,
      'priority': priority,
      'category': category,
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'is_completed': isCompleted,
      'reminder': reminder,
      'repeat': repeat,
      'reminder_time': reminderTime,
    };
  }
}

/// Exam — new model for dedicated exams section
class Exam {
  final String id; // Firestore document ID
  final String studentId;
  final String name;
  final String subject;
  final DateTime date;
  final String description;
  final bool reminderSet;
  final String? reminderTime;

  Exam({
    required this.id,
    required this.studentId,
    required this.name,
    required this.subject,
    required this.date,
    required this.description,
    this.reminderSet = true,
    this.reminderTime = '09:00',
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return Exam(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id'] ?? '',
      name: json['name'] ?? '',
      subject: json['subject'] ?? '',
      date: parseDate(json['date']),
      description: json['description'] ?? '',
      reminderSet: json['reminder_set'] ?? true,
      reminderTime: json['reminder_time'] ?? '09:00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'name': name,
      'subject': subject,
      'date': date.toIso8601String(),
      'description': description,
      'reminder_set': reminderSet,
      'reminder_time': reminderTime,
    };
  }
}

/// Assignment — new model for assignments tracking
class Assignment {
  final String id; // Firestore document ID
  final String studentId;
  final String title;
  final String subject;
  final DateTime dueDate;
  final String priority; // 'High', 'Medium', 'Low'
  final String status; // 'pending', 'submitted'
  final bool reminderSet;
  final String? reminderTime;

  Assignment({
    required this.id,
    required this.studentId,
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.priority,
    required this.status,
    this.reminderSet = true,
    this.reminderTime = '09:00',
  });

  bool get isSubmitted => status == 'submitted';

  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  bool get isOverdue => dueDate.isBefore(DateTime.now()) && !isSubmitted;

  factory Assignment.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return DateTime.now().add(const Duration(days: 7));
      }
    }

    return Assignment(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id'] ?? '',
      title: json['title'] ?? '',
      subject: json['subject'] ?? '',
      dueDate: parseDate(json['due_date']),
      priority: json['priority'] ?? 'Medium',
      status: json['status'] ?? 'pending',
      reminderSet: json['reminder_set'] ?? true,
      reminderTime: json['reminder_time'] ?? '09:00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'title': title,
      'subject': subject,
      'due_date': dueDate.toIso8601String(),
      'priority': priority,
      'status': status,
      'reminder_set': reminderSet,
      'reminder_time': reminderTime,
    };
  }
}
