import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:aura_frontend/models/models.dart';
import 'package:aura_frontend/services/local_storage.dart';

class ApiService {
  static final String baseUrl = kIsWeb
      ? 'http://localhost:8000/api'
      : (defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8000/api'
          : 'http://localhost:8000/api');
  
  static Future<List<Map<String, dynamic>>?> parseSyllabusFile(Uint8List bytes, String filename) async {
    try {
      final uri = Uri.parse('$baseUrl/syllabus/parse');
      debugPrint("Calling parse syllabus API: $uri");
      final request = http.MultipartRequest('POST', uri);
      
      final ext = filename.split('.').last.toLowerCase();
      final MediaType mediaType;
      if (ext == 'pdf') {
        mediaType = MediaType('application', 'pdf');
      } else if (ext == 'png') {
        mediaType = MediaType('image', 'png');
      } else {
        mediaType = MediaType('image', 'jpeg');
      }
      
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: mediaType,
      );
      request.files.add(multipartFile);
      
      final responseStream = await request.send();
      final response = await http.Response.fromStream(responseStream);
      
      debugPrint("Syllabus parse status: ${response.statusCode}");
      debugPrint("Syllabus parse body: ${response.body}");
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['subjects'] != null) {
          return List<Map<String, dynamic>>.from(decoded['subjects']);
        }
      }
    } catch (e) {
      debugPrint("Error calling parse syllabus API: $e");
    }
    return null;
  }
  
  static Future<bool> checkConnection() async {
    return true;
  }

  // --- Auth & Profile ---
  static Future<bool> onboard(Map<String, dynamic> onboardData) async {
    // Save locally immediately
    LocalStorageService.saveProfile(onboardData);
    
    final subjects = onboardData['subjects'] as List? ?? [];
    LocalStorageService.initializeSubjectsCache(subjects);
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/onboard'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(onboardData),
      );
      if (response.statusCode != 201) {
        debugPrint('Onboarding sync returned status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Onboarding sync exception (running offline): $e');
    }
    return true; // Always return true to run in local-first mode and never block navigation
  }

  static Future<StudentProfile?> getProfile(String studentId) async {
    final online = await checkConnection();
    if (online) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/auth/profile/$studentId'));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          LocalStorageService.saveProfile(data);
          return StudentProfile.fromJson(data);
        }
      } catch (_) {}
    }
    
    // Offline / fallback
    final local = LocalStorageService.getProfile();
    if (local != null) {
      return StudentProfile.fromJson(local);
    }
    return null;
  }

  // --- Attendance ---
  static Future<AttendanceAnalysis?> getAttendanceSummary(String studentId) async {
    final online = await checkConnection();
    if (online) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/attendance/summary/$studentId'));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          // Cache subject summary
          if (data['subjects_detail'] != null) {
            LocalStorageService.cacheAttendance(List<Map<String, dynamic>>.from(data['subjects_detail']));
          }
          return AttendanceAnalysis.fromJson(data);
        }
      } catch (_) {}
    }

    // Cache Fallback
    final cachedDetail = LocalStorageService.getCachedAttendance();
    if (cachedDetail.isNotEmpty) {
      final profile = LocalStorageService.getProfile();
      final target = (profile != null && profile['attendance_target'] != null)
          ? (profile['attendance_target'] as num).toDouble()
          : 75.0;

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

      return AttendanceAnalysis(
        healthScore: health,
        overallPercentage: overall,
        subjectsDetail: cachedDetail.map((e) => SubjectAttendanceDetail.fromJson(e)).toList(),
        aiPredictionSummary: "Offline Mode. Displaying cached attendance logs. Sync to get AI projections.",
        safeLeaveSummary: "Offline mode active.",
      );
    }
    return null;
  }

  static Future<bool> recordAttendance(int subjectId, DateTime date, String status) async {
    final online = await checkConnection();
    final dateStr = date.toIso8601String().substring(0, 10);
    
    // 1. Save daily status log locally in Hive
    LocalStorageService.saveDailyStatus(subjectId, date, status);
    
    // 2. Recalculate local subject summary cache
    LocalStorageService.recalculateAndCacheAttendanceForSubject(subjectId);

    final payload = {
      'subject_id': subjectId,
      'date': dateStr,
      'status': status
    };

    if (online) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/attendance/record'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (response.statusCode == 200 || response.statusCode == 201) {
          return true;
        }
      } catch (_) {}
    }
    // Queue offline/failed action
    LocalStorageService.queueAction('record_attendance', payload);
    return true;
  }

  static Future<bool> clearAttendance(int subjectId, DateTime date) async {
    final online = await checkConnection();
    final dateStr = date.toIso8601String().substring(0, 10);

    // 1. Clear daily status log locally in Hive
    LocalStorageService.clearDailyStatus(subjectId, date);

    // 2. Recalculate local subject summary cache
    LocalStorageService.recalculateAndCacheAttendanceForSubject(subjectId);

    final payload = {
      'subject_id': subjectId,
      'date': dateStr,
    };

    if (online) {
      try {
        final response = await http.delete(
          Uri.parse('$baseUrl/attendance/record/$subjectId/$dateStr'),
        );
        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }
    // Queue offline/failed action
    LocalStorageService.queueAction('clear_attendance', payload);
    return true;
  }

  // --- Syllabus ---
  static Future<List<SubjectSyllabus>> getSyllabusTracker(String studentId) async {
    final online = await checkConnection();
    if (online) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/syllabus/tracker/$studentId'));
        if (response.statusCode == 200) {
          final List data = jsonDecode(response.body);
          LocalStorageService.cacheSyllabus(List<Map<String, dynamic>>.from(data));
          return data.map((e) => SubjectSyllabus.fromJson(e)).toList();
        }
      } catch (_) {}
    }

    final local = LocalStorageService.getCachedSyllabus();
    return local.map((e) => SubjectSyllabus.fromJson(e)).toList();
  }

  static Future<bool> updateSyllabusUnit(int unitId, String status) async {
    final online = await checkConnection();
    
    // Apply locally
    final localSyllabus = LocalStorageService.getCachedSyllabus();
    final updated = localSyllabus.map((subj) {
      final List units = subj['units'] ?? [];
      final updatedUnits = units.map((u) {
        if (u['id'] == unitId) {
          return {...u, 'status': status};
        }
        return u;
      }).toList();
      return {...subj, 'units': updatedUnits};
    }).toList();
    LocalStorageService.cacheSyllabus(updated);

    final payload = {
      'unit_id': unitId,
      'status': status,
    };

    if (online) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/syllabus/unit/update'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }
    // Queue offline
    LocalStorageService.queueAction('update_syllabus', payload);
    return true;
  }

  static Future<bool> editSyllabusUnit(int unitId, String title, String description, String status, String completionDate) async {
    final online = await checkConnection();
    
    // Apply locally
    final localSyllabus = LocalStorageService.getCachedSyllabus();
    final updated = localSyllabus.map((subj) {
      final List units = subj['units'] ?? [];
      final updatedUnits = units.map((u) {
        if (u['id'] == unitId) {
          return {
            ...u, 
            'title': title, 
            'description': description, 
            'status': status,
            'completion_date': completionDate,
          };
        }
        return u;
      }).toList();
      return {...subj, 'units': updatedUnits};
    }).toList();
    LocalStorageService.cacheSyllabus(updated);

    final payload = {
      'unit_id': unitId,
      'title': title,
      'description': description,
      'status': status,
      'completion_date': completionDate,
    };

    if (online) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/syllabus/unit/edit'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }
    // Queue offline
    LocalStorageService.queueAction('edit_syllabus', payload);
    return true;
  }

  // --- Goals ---
  static Future<List<Goal>> getGoals(String studentId) async {
    final online = await checkConnection();
    if (online) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/goals/student/$studentId'));
        if (response.statusCode == 200) {
          final List data = jsonDecode(response.body);
          LocalStorageService.cacheGoals(List<Map<String, dynamic>>.from(data));
          return data.map((e) => Goal.fromJson(e)).toList();
        }
      } catch (_) {}
    }

    final local = LocalStorageService.getCachedGoals();
    return local.map((e) => Goal.fromJson(e)).toList();
  }

  static Future<Goal?> createGoal(String studentId, String title, String timeframe) async {
    final online = await checkConnection();
    final payload = {
      'student_id': studentId,
      'title': title,
      'timeframe': timeframe,
    };

    if (online) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/goals/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (response.statusCode == 201) {
          final created = Goal.fromJson(jsonDecode(response.body));
          
          final list = LocalStorageService.getCachedGoals();
          list.add(jsonDecode(response.body));
          LocalStorageService.cacheGoals(list);
          
          return created;
        }
      } catch (_) {}
    }
    
    // Offline simulated goal creation (mock ID)
    final mockGoal = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'student_id': studentId,
      'title': title,
      'timeframe': timeframe,
      'status': 'pending',
      'date_created': DateTime.now().toIso8601String().substring(0, 10),
    };
    final list = LocalStorageService.getCachedGoals();
    list.add(mockGoal);
    LocalStorageService.cacheGoals(list);

    LocalStorageService.queueAction('create_goal', payload);
    return Goal.fromJson(mockGoal);
  }

  static Future<bool> toggleGoal(int goalId) async {
    final online = await checkConnection();
    
    // Toggle locally
    final list = LocalStorageService.getCachedGoals();
    final updated = list.map((e) {
      if (e['id'] == goalId) {
        return {...e, 'status': e['status'] == 'completed' ? 'pending' : 'completed'};
      }
      return e;
    }).toList();
    LocalStorageService.cacheGoals(updated);

    final payload = {'goal_id': goalId};

    if (online) {
      try {
        final response = await http.post(Uri.parse('$baseUrl/goals/$goalId/toggle'));
        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }
    LocalStorageService.queueAction('toggle_goal', payload);
    return true;
  }

  static Future<bool> deleteGoal(int goalId) async {
    final online = await checkConnection();
    
    // Delete locally
    final list = LocalStorageService.getCachedGoals();
    list.removeWhere((e) => e['id'] == goalId);
    LocalStorageService.cacheGoals(list);

    final payload = {'goal_id': goalId};

    if (online) {
      try {
        final response = await http.delete(Uri.parse('$baseUrl/goals/$goalId'));
        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }
    LocalStorageService.queueAction('delete_goal', payload);
    return true;
  }

  // --- Tasks ---
  static Future<List<Task>> getTasks(String studentId) async {
    final online = await checkConnection();
    if (online) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/tasks/student/$studentId'));
        if (response.statusCode == 200) {
          final List data = jsonDecode(response.body);
          LocalStorageService.cacheTasks(List<Map<String, dynamic>>.from(data));
          return data.map((e) => Task.fromJson(e)).toList();
        }
      } catch (_) {}
    }

    final local = LocalStorageService.getCachedTasks();
    return local.map((e) => Task.fromJson(e)).toList();
  }

  static Future<Task?> createTask(Map<String, dynamic> payload) async {
    final online = await checkConnection();
    if (online) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/tasks/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (response.statusCode == 201) {
          final created = Task.fromJson(jsonDecode(response.body));
          final list = LocalStorageService.getCachedTasks();
          list.add(jsonDecode(response.body));
          LocalStorageService.cacheTasks(list);
          return created;
        }
      } catch (_) {}
    }
    
    // Offline fallback
    final mockTask = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'student_id': payload['student_id'],
      'title': payload['title'],
      'description': payload['description'] ?? '',
      'priority': payload['priority'] ?? 'Medium',
      'category': payload['category'] ?? 'Study',
      'date': payload['date'] ?? DateTime.now().toIso8601String().substring(0, 10),
      'start_time': payload['start_time'] ?? '',
      'end_time': payload['end_time'] ?? '',
      'is_completed': false,
      'reminder': payload['reminder'] == true,
      'repeat': payload['repeat'] ?? 'None',
    };
    final list = LocalStorageService.getCachedTasks();
    list.add(mockTask);
    LocalStorageService.cacheTasks(list);
    LocalStorageService.queueAction('create_task', payload);
    return Task.fromJson(mockTask);
  }

  static Future<bool> toggleTask(int taskId) async {
    final online = await checkConnection();
    final list = LocalStorageService.getCachedTasks();
    final updated = list.map((e) {
      if (e['id'] == taskId) {
        final bool completed = e['is_completed'] == true;
        return {...e, 'is_completed': !completed};
      }
      return e;
    }).toList();
    LocalStorageService.cacheTasks(updated);

    final payload = {'task_id': taskId};
    if (online) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/tasks/$taskId/toggle'),
          headers: {'Content-Type': 'application/json'},
        );
        if (response.statusCode == 200) return true;
      } catch (_) {}
    }
    LocalStorageService.queueAction('toggle_task', payload);
    return true;
  }

  static Future<bool> deleteTask(int taskId) async {
    final online = await checkConnection();
    final list = LocalStorageService.getCachedTasks();
    list.removeWhere((e) => e['id'] == taskId);
    LocalStorageService.cacheTasks(list);

    final payload = {'task_id': taskId};
    if (online) {
      try {
        final response = await http.delete(Uri.parse('$baseUrl/tasks/$taskId'));
        if (response.statusCode == 200) return true;
      } catch (_) {}
    }
    LocalStorageService.queueAction('delete_task', payload);
    return true;
  }

  // --- AI Chat ---
  static Future<Map<String, dynamic>?> sendMessage(String studentId, String text) async {
    final online = await checkConnection();
    if (!online) {
      return {
        'response': "Offline Mode: AI chat is unavailable without an internet connection.",
        'agent_type': 'general',
        'structured_data': null
      };
    }
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ai/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_id': studentId, 'query': text}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // --- Knowledge Vault (RAG) ---
  static Future<bool> uploadNote(String studentId, String fileId, String filename, {String? filepath, List<int>? fileBytes}) async {
    final online = await checkConnection();
    if (!online) return false;
    
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/knowledge/upload'));
      request.fields['student_id'] = studentId;
      request.fields['file_id'] = fileId;

      if (fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file', 
          fileBytes,
          filename: filename,
          contentType: MediaType('application', 'pdf')
        ));
      } else if (filepath != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'file', 
          filepath,
          filename: filename,
          contentType: MediaType('application', 'pdf')
        ));
      } else {
        return false;
      }
      
      final response = await request.send();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<KnowledgeFile>> getUploadedFiles(String studentId) async {
    final online = await checkConnection();
    if (online) {
      try {
        final response = await http.get(Uri.parse('$baseUrl/knowledge/files/$studentId'));
        if (response.statusCode == 200) {
          final List data = jsonDecode(response.body);
          return data.map((e) => KnowledgeFile.fromJson(e)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getStudyMaterials(String fileId) async {
    final online = await checkConnection();
    if (!online) return null;
    
    try {
      final response = await http.get(Uri.parse('$baseUrl/knowledge/study-materials/$fileId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
