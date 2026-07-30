import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:aura_frontend/models/models.dart';
import 'package:aura_frontend/services/local_storage.dart';
import 'package:aura_frontend/services/api_service.dart';
import 'package:aura_frontend/services/cloudinary_service.dart';

/// FirebaseService — acts as the gateway to exams, assignments, and files stored on MongoDB.
class FirebaseService {
  static final String _baseUrl = ApiService.baseUrl;

  // ─────────────────────────────────────────────
  // RESOURCE VAULT — Cloudinary + MongoDB Metadata
  // ─────────────────────────────────────────────

  /// Upload a file to Cloudinary and save metadata to MongoDB.
  /// Returns the KnowledgeFile with downloadUrl on success, null on failure.
  static Future<KnowledgeFile?> uploadFile({
    required String userId,
    required String subject,
    required String fileName,
    Uint8List? fileBytes,
    String? filePath,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = fileName.replaceAll(RegExp(r'[^\w\s\.\-]'), '_');
      final storagePath = 'users/$userId/vault/$subject/$timestamp\_$safeName';

      int fileSize = fileBytes?.length ?? 0;
      if (fileBytes == null && filePath != null) {
        if (!kIsWeb) {
          final file = File(filePath);
          fileSize = await file.length();
          fileBytes = await file.readAsBytes();
        }
      }

      if (fileBytes == null) {
        throw Exception("File bytes are null");
      }

      // Upload directly to Cloudinary
      final cloudinaryUrl = await CloudinaryService.uploadFile(
        fileBytes: fileBytes,
        fileName: fileName,
      );

      final downloadUrl = cloudinaryUrl ?? 'local';

      // Save metadata to backend (stored in MongoDB)
      final response = await http.post(
        Uri.parse('$_baseUrl/vault/files'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': userId,
          'filename': fileName,
          'file_path': storagePath,
          'download_url': downloadUrl,
          'subject': subject,
          'file_size': fileSize,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception("Failed to sync file metadata with backend: ${response.statusCode}");
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final fileId = responseData['id'] ?? 'file_${uuid()}';

      // Save file bytes locally in Hive
      LocalStorageService.saveVaultFileBytes(fileId, fileBytes);

      return KnowledgeFile(
        id: fileId,
        studentId: userId,
        filename: fileName,
        filePath: storagePath,
        downloadUrl: downloadUrl,
        subject: subject,
        fileSize: fileSize,
        uploadTime: DateTime.now(),
      );
    } catch (e) {
      debugPrint('FirebaseService.uploadFile error: $e');
      return null;
    }
  }

  /// Get a stream of files for a user, optionally filtered by subject.
  static Stream<List<KnowledgeFile>> getFilesStream(String userId, {String? subject}) async* {
    while (true) {
      try {
        final queryParams = subject != null ? '&subject=${Uri.encodeComponent(subject)}' : '';
        final response = await http.get(
          Uri.parse('$_baseUrl/vault/files?student_id=$userId$queryParams'),
        );
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final files = data.map((json) {
            json['upload_time'] = DateTime.now().toIso8601String(); // Default format compat
            return KnowledgeFile.fromJson(json);
          }).toList();
          yield files;
        }
      } catch (e) {
        debugPrint('getFilesStream error: $e');
      }
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  /// Delete a file from MongoDB.
  static Future<bool> deleteFile(String userId, String fileId, String storagePath) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/vault/files/$fileId'),
      );

      if (response.statusCode == 200) {
        LocalStorageService.deleteVaultFileBytes(fileId);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('FirebaseService.deleteFile error: $e');
      return false;
    }
  }

  /// Rename a file in MongoDB.
  static Future<bool> renameFile(String userId, String fileId, String newName) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/vault/files/$fileId/rename'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'filename': newName}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('FirebaseService.renameFile error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // EXAMS
  // ─────────────────────────────────────────────

  /// Save an exam to MongoDB.
  static Future<Exam?> saveExam(String userId, Exam exam) async {
    try {
      final data = exam.toJson();
      data['student_id'] = userId;
      // Convert DateTime to ISO string
      data['date'] = exam.date.toIso8601String();

      final response = await http.post(
        Uri.parse('$_baseUrl/exams'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return Exam.fromJson(responseData);
      }
      return null;
    } catch (e) {
      debugPrint('FirebaseService.saveExam error: $e');
      return null;
    }
  }

  /// Get a stream of exams from MongoDB.
  static Stream<List<Exam>> getExamsStream(String userId) async* {
    while (true) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/exams?student_id=$userId'),
        );
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final exams = data.map((json) => Exam.fromJson(json)).toList();
          yield exams;
        }
      } catch (e) {
        debugPrint('getExamsStream error: $e');
      }
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  /// Delete an exam from MongoDB.
  static Future<bool> deleteExam(String userId, String examId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/exams/$examId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('FirebaseService.deleteExam error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // ASSIGNMENTS
  // ─────────────────────────────────────────────

  /// Save an assignment to MongoDB.
  static Future<Assignment?> saveAssignment(String userId, Assignment assignment) async {
    try {
      final data = assignment.toJson();
      data['student_id'] = userId;
      data['due_date'] = assignment.dueDate.toIso8601String();

      final response = await http.post(
        Uri.parse('$_baseUrl/assignments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return Assignment.fromJson(responseData);
      }
      return null;
    } catch (e) {
      debugPrint('FirebaseService.saveAssignment error: $e');
      return null;
    }
  }

  /// Get a stream of assignments from MongoDB.
  static Stream<List<Assignment>> getAssignmentsStream(String userId) async* {
    while (true) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/assignments?student_id=$userId'),
        );
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final assignments = data.map((json) => Assignment.fromJson(json)).toList();
          yield assignments;
        }
      } catch (e) {
        debugPrint('getAssignmentsStream error: $e');
      }
      await Future.delayed(const Duration(seconds: 4));
    }
  }

  /// Toggle assignment status in MongoDB.
  static Future<bool> toggleAssignment(String userId, String assignmentId, String currentStatus) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/assignments/$assignmentId/toggle?current_status=$currentStatus'),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('FirebaseService.toggleAssignment error: $e');
      return false;
    }
  }

  /// Delete an assignment from MongoDB.
  static Future<bool> deleteAssignment(String userId, String assignmentId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/assignments/$assignmentId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('FirebaseService.deleteAssignment error: $e');
      return false;
    }
  }

  // Helper uuid generator
  static String uuid() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Format file size for display.
  static String formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
