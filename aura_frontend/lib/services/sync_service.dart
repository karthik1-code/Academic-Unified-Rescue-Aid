import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:aura_frontend/services/local_storage.dart';
import 'package:aura_frontend/services/api_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isSyncing = false;

  void startListening() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        // Trigger sync when back online
        syncPendingData();
      }
    });
  }

  void stopListening() {
    _connectivitySubscription?.cancel();
  }

  Future<void> syncPendingData() async {
    if (_isSyncing) return;
    
    final hasInternet = await ApiService.checkConnection();
    if (!hasInternet) return;

    final queue = LocalStorageService.getSyncQueue();
    if (queue.isEmpty) return;

    _isSyncing = true;
    debugPrint("AURA Sync: Starting background upload of ${queue.length} offline operations...");

    final List<Map<String, dynamic>> remainingQueue = [];

    for (final task in queue) {
      final action = task['action'] as String;
      final data = task['data'] as Map<String, dynamic>;
      bool success = false;

      try {
        if (action == 'record_attendance') {
          success = await ApiService.recordAttendance(
            data['subject_id'] as int,
            DateTime.parse(data['date'] as String),
            data['status'] as String,
          );
        } else if (action == 'update_syllabus') {
          success = await ApiService.updateSyllabusUnit(
            data['unit_id'] as int,
            data['status'] as String,
          );
        } else if (action == 'edit_syllabus') {
          success = await ApiService.editSyllabusUnit(
            data['unit_id'] as int,
            data['title'] as String,
            data['description'] as String,
            data['status'] as String,
            data['completion_date'] as String,
          );
        } else if (action == 'create_goal') {
          final created = await ApiService.createGoal(
            data['student_id'] as String,
            data['title'] as String,
            data['timeframe'] as String,
          );
          success = created != null;
        } else if (action == 'toggle_goal') {
          success = await ApiService.toggleGoal(
            data['goal_id'] as int,
          );
        } else if (action == 'delete_goal') {
          success = await ApiService.deleteGoal(
            data['goal_id'] as int,
          );
        } else if (action == 'create_task') {
          final created = await ApiService.createTask(data);
          success = created != null;
        } else if (action == 'toggle_task') {
          success = await ApiService.toggleTask(
            data['task_id'] as int,
          );
        } else if (action == 'delete_task') {
          success = await ApiService.deleteTask(
            data['task_id'] as int,
          );
        }
      } catch (e) {
        debugPrint("AURA Sync Error replaying action $action: $e");
      }

      if (!success) {
        remainingQueue.add(task);
      }
    }

    LocalStorageService.updateSyncQueue(remainingQueue);
    _isSyncing = false;
    debugPrint("AURA Sync complete. Remaining operations in queue: ${remainingQueue.length}");
  }
}
