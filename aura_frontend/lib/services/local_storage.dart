import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String _profileBox = 'aura_profile';
  static const String _attendanceBox = 'aura_attendance';
  static const String _syllabusBox = 'aura_syllabus';
  static const String _goalsBox = 'aura_goals';
  static const String _planBox = 'aura_plan';
  static const String _tasksBox = 'aura_tasks';
  static const String _syncQueueBox = 'aura_sync_queue';
  static const String _attendanceDailyLogsBox = 'aura_attendance_daily_logs';
  static const String _vaultFilesBox = 'aura_vault_files';
  static const String _reviewLaterBox = 'aura_syllabus_review_later';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_profileBox);
    await Hive.openBox(_attendanceBox);
    await Hive.openBox(_syllabusBox);
    await Hive.openBox(_goalsBox);
    await Hive.openBox(_planBox);
    await Hive.openBox(_tasksBox);
    await Hive.openBox(_syncQueueBox);
    await Hive.openBox(_attendanceDailyLogsBox);
    await Hive.openBox(_vaultFilesBox);
    await Hive.openBox(_reviewLaterBox);
  }

  // --- Local Review Later State ---
  static void toggleReviewLater(int unitId, bool value) {
    Hive.box(_reviewLaterBox).put(unitId, value);
  }

  static bool isReviewLater(int unitId) {
    return Hive.box(_reviewLaterBox).get(unitId) ?? false;
  }

  // --- Local Vault File Bytes Storage ---
  static void saveVaultFileBytes(String id, List<int> bytes) {
    Hive.box(_vaultFilesBox).put(id, bytes);
  }

  static List<int>? getVaultFileBytes(String id) {
    final raw = Hive.box(_vaultFilesBox).get(id);
    if (raw == null) return null;
    return List<int>.from(raw);
  }

  static void deleteVaultFileBytes(String id) {
    Hive.box(_vaultFilesBox).delete(id);
  }

  // --- Daily Attendance Status Logs ---
  static void saveDailyStatus(int subjectId, DateTime date, String status) {
    final dateStr = date.toIso8601String().substring(0, 10);
    Hive.box(_attendanceDailyLogsBox).put('${subjectId}_$dateStr', status);
  }

  static String? getDailyStatus(int subjectId, DateTime date) {
    final dateStr = date.toIso8601String().substring(0, 10);
    return Hive.box(_attendanceDailyLogsBox).get('${subjectId}_$dateStr');
  }

  static void clearDailyStatus(int subjectId, DateTime date) {
    final dateStr = date.toIso8601String().substring(0, 10);
    Hive.box(_attendanceDailyLogsBox).delete('${subjectId}_$dateStr');
  }

  static Map<String, int> recalculateSubjectAttendance(int subjectId) {
    final box = Hive.box(_attendanceDailyLogsBox);
    int present = 0;
    int absent = 0;
    for (final key in box.keys) {
      if (key.toString().startsWith('${subjectId}_')) {
        final val = box.get(key);
        if (val == 'present') {
          present++;
        } else if (val == 'absent') {
          absent++;
        }
      }
    }
    return {'present': present, 'absent': absent};
  }

  static void recalculateAndCacheAttendanceForSubject(int subjectId) {
    final counts = recalculateSubjectAttendance(subjectId);
    final present = counts['present'] ?? 0;
    final absent = counts['absent'] ?? 0;
    final total = present + absent;
    final pct = total > 0 ? (present / total) * 100.0 : 100.0;

    final profileJson = getProfile();
    double target = 75.0;
    if (profileJson != null && profileJson['attendance_target'] != null) {
      target = (profileJson['attendance_target'] as num).toDouble();
    }

    String statusLabel = 'Safe';
    if (pct >= target + 10) {
      statusLabel = 'Excellent';
    } else if (pct >= target) {
      statusLabel = 'Safe';
    } else {
      statusLabel = 'Critical';
    }

    int safeLeaves = 0;
    int requiredToRecover = 0;
    final targetFraction = target / 100.0;

    if (pct >= target) {
      if (targetFraction > 0) {
        final val = present / targetFraction - total;
        safeLeaves = val >= 0 ? val.floor() : 0;
      }
    } else {
      final denom = 1.0 - targetFraction;
      if (denom > 0) {
        final val = (targetFraction * total - present) / denom;
        requiredToRecover = val >= 0 ? val.ceil() : 0;
      }
    }

    String sugg = '';
    if (statusLabel == 'Critical') {
      sugg = 'Below target ($target%). You must attend the next $requiredToRecover classes consecutively to recover.';
    } else if (safeLeaves > 0) {
      sugg = 'Safe to leave $safeLeaves classes. Your current attendance is ${pct.toStringAsFixed(1)}%.';
    } else {
      sugg = 'You are right on the limit. Avoid skipping any class to maintain attendance status.';
    }

    final localLogs = getCachedAttendance();
    final updatedLogs = localLogs.map((e) {
      if (e['subject_id'] == subjectId) {
        return {
          ...e,
          'present': present,
          'absent': absent,
          'total_classes': total,
          'percentage': pct,
          'status_label': statusLabel,
          'safe_leaves': safeLeaves,
          'required_to_recover': requiredToRecover,
          'recovery_suggestion': sugg,
        };
      }
      return e;
    }).toList();
    cacheAttendance(updatedLogs);
  }

  // --- Student Profile ---
  static void saveProfile(Map<String, dynamic> json) {
    Hive.box(_profileBox).put('profile', jsonEncode(json));
    if (json['id'] != null) {
      saveAuthUser(json['id'], json['email'] ?? getAuthUser()?['email']);
    }
  }

  static Map<String, dynamic>? getProfile() {
    final raw = Hive.box(_profileBox).get('profile');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static void saveAuthUser(String uid, String? email) {
    Hive.box(_profileBox).put('auth_uid', uid);
    Hive.box(_profileBox).put('auth_email', email);
  }

  static Map<String, String?>? getAuthUser() {
    final uid = Hive.box(_profileBox).get('auth_uid');
    final email = Hive.box(_profileBox).get('auth_email');
    if (uid == null) return null;
    return {'uid': uid, 'email': email};
  }

  static void clearProfile() {
    Hive.box(_profileBox).clear();
    Hive.box(_attendanceBox).clear();
    Hive.box(_syllabusBox).clear();
    Hive.box(_goalsBox).clear();
    Hive.box(_planBox).clear();
    Hive.box(_tasksBox).clear();
    Hive.box(_syncQueueBox).clear();
  }

  // --- Offline Sync Queue ---
  static void queueAction(String action, Map<String, dynamic> data) {
    final box = Hive.box(_syncQueueBox);
    final queue = getSyncQueue();
    queue.add({
      'action': action,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    box.put('queue', jsonEncode(queue));
  }

  static List<Map<String, dynamic>> getSyncQueue() {
    final box = Hive.box(_syncQueueBox);
    final raw = box.get('queue');
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  static void clearSyncQueue() {
    Hive.box(_syncQueueBox).delete('queue');
  }

  static void updateSyncQueue(List<Map<String, dynamic>> queue) {
    Hive.box(_syncQueueBox).put('queue', jsonEncode(queue));
  }

  // --- Attendance ---
  static void cacheAttendance(List<Map<String, dynamic>> list) {
    Hive.box(_attendanceBox).put('records', jsonEncode(list));
  }

  static List<Map<String, dynamic>> getCachedAttendance() {
    final raw = Hive.box(_attendanceBox).get('records');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  // --- Syllabus ---
  static void cacheSyllabus(List<Map<String, dynamic>> list) {
    Hive.box(_syllabusBox).put('tracker', jsonEncode(list));
  }

  static List<Map<String, dynamic>> getCachedSyllabus() {
    final raw = Hive.box(_syllabusBox).get('tracker');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  // --- Goals ---
  static void cacheGoals(List<Map<String, dynamic>> list) {
    Hive.box(_goalsBox).put('items', jsonEncode(list));
  }

  static List<Map<String, dynamic>> getCachedGoals() {
    final raw = Hive.box(_goalsBox).get('items');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  // --- Tasks ---
  static void cacheTasks(List<Map<String, dynamic>> list) {
    Hive.box(_tasksBox).put('items', jsonEncode(list));
  }

  static List<Map<String, dynamic>> getCachedTasks() {
    final raw = Hive.box(_tasksBox).get('items');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  // --- Study Plan ---
  static void cacheStudyPlan(Map<String, dynamic> json) {
    Hive.box(_planBox).put('today_plan', jsonEncode(json));
  }

  static Map<String, dynamic>? getCachedStudyPlan() {
    final raw = Hive.box(_planBox).get('today_plan');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // --- Goal Alarms ---
  static void saveGoalAlarms(Map<String, String> alarms) {
    Hive.box(_goalsBox).put('goal_alarms', jsonEncode(alarms));
  }

  static Map<String, String> getGoalAlarms() {
    final raw = Hive.box(_goalsBox).get('goal_alarms');
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map;
      return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (_) {
      return {};
    }
  }

  // --- Onboarding Initial Cache Populator ---
  static void initializeSubjectsCache(List<dynamic> subjects) {
    final syllabusList = subjects.asMap().entries.map((entry) {
      final idx = entry.key;
      final sub = entry.value;
      return {
        'subject_id': idx + 1,
        'subject_name': sub['name'],
        'units': List.generate(5, (uIdx) => {
          'id': (idx + 1) * 10 + (uIdx + 1),
          'subject_id': idx + 1,
          'unit_number': uIdx + 1,
          'title': 'Unit ${uIdx + 1}: Fundamental Concepts',
          'description': 'Details and key study topics for Unit ${uIdx + 1}',
          'status': 'pending',
          'completion_date': '',
        }),
      };
    }).toList();
    cacheSyllabus(syllabusList);

    final attendanceList = subjects.asMap().entries.map((entry) {
      final idx = entry.key;
      final sub = entry.value;
      return {
        'subject_id': idx + 1,
        'subject_name': sub['name'],
        'subtitle': sub['subtitle'] ?? '',
        'credits': sub['credits'] ?? 3,
        'present': 0,
        'absent': 0,
        'leave': 0,
        'total_classes': 0,
        'percentage': 100.0,
        'status_label': 'Safe',
        'safe_leaves': 0,
        'required_to_recover': 0,
        'recovery_suggestion': 'Safe to skip classes.'
      };
    }).toList();
    cacheAttendance(attendanceList);
  }
}
