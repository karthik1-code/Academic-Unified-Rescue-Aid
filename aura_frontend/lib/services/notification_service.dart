import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:aura_frontend/models/models.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:math';
import 'package:aura_frontend/services/web_notification_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initNotifications() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      if (kIsWeb) {
        try {
          requestWebNotificationPermission();
        } catch (_) {}
        return;
      }

      try {
        tz.initializeTimeZones();
        try {
          var _ = tz.local;
        } catch (_) {
          tz.setLocalLocation(tz.getLocation('UTC'));
        }
      } catch (_) {}

      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {},
      ).catchError((_) => false);
    } catch (e) {
      debugPrint("Notification initialization safely handled: $e");
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await initNotifications();

    if (kIsWeb) {
      showWebNotification(title, body);
      return;
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'aura_alerts_channel',
      'AURA OS Alerts',
      channelDescription: 'Alert notifications for attendance and planning limits',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint("Failed to show notification: $e");
    }
  }

  /// Schedule a local notification at a specific date and time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_isInitialized) await initNotifications();

    // Only schedule if scheduledDate is in the future
    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) return;

    if (kIsWeb) {
      final delay = scheduledDate.difference(now);
      Future.delayed(delay, () {
        showWebNotification(title, body);
      });
      return;
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'aura_alerts_channel',
            'AURA OS Alerts',
            channelDescription: 'Scheduled reminders for exams and assignments',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint("Failed to schedule notification: $e");
    }
  }

  /// Schedule notifications for an exam (6, 5, 4, 3, 2, 1 days before)
  Future<void> scheduleExamReminders(Exam exam) async {
    if (!_isInitialized) await initNotifications();

    // Clear existing notifications for this exam first
    for (int i = 1; i <= 6; i++) {
      await _notificationsPlugin.cancel(exam.id.hashCode + i);
    }

    final examDateTime = exam.date;
    final now = DateTime.now();

    final parts = (exam.reminderTime ?? '09:00').split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    for (int daysBefore = 1; daysBefore <= 6; daysBefore++) {
      final scheduleTime = DateTime(
        examDateTime.year,
        examDateTime.month,
        examDateTime.day - daysBefore,
        hour,
        minute,
      );

      if (scheduleTime.isAfter(now)) {
        await scheduleNotification(
          id: exam.id.hashCode + daysBefore,
          title: 'Upcoming Exam: ${exam.name}',
          body: '${exam.name} is in $daysBefore days! Keep studying.',
          scheduledDate: scheduleTime,
        );
      }
    }
  }

  /// Cancel reminders for a deleted exam
  Future<void> cancelExamReminders(String examId) async {
    if (!_isInitialized) await initNotifications();
    for (int i = 1; i <= 6; i++) {
      await _notificationsPlugin.cancel(examId.hashCode + i);
    }
  }

  /// Schedule notifications for an assignment based on priority level
  Future<void> scheduleAssignmentReminders(Assignment assignment) async {
    if (!_isInitialized) await initNotifications();

    // Clear existing notifications for this assignment first
    for (int i = 1; i <= 6; i++) {
      await _notificationsPlugin.cancel(assignment.id.hashCode + i);
    }

    final dueDateTime = assignment.dueDate;
    final now = DateTime.now();

    List<int> reminderDays = [];
    if (assignment.priority == 'High') {
      reminderDays = [1, 2, 3, 4, 5, 6];
    } else if (assignment.priority == 'Medium') {
      reminderDays = [1, 3];
    } else {
      reminderDays = [1];
    }

    final parts = (assignment.reminderTime ?? '09:00').split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    for (int daysBefore in reminderDays) {
      final scheduleTime = DateTime(
        dueDateTime.year,
        dueDateTime.month,
        dueDateTime.day - daysBefore,
        hour,
        minute,
      );

      if (scheduleTime.isAfter(now)) {
        await scheduleNotification(
          id: assignment.id.hashCode + daysBefore,
          title: 'Assignment Due: ${assignment.title}',
          body: 'Your assignment for ${assignment.subject} is due in $daysBefore days.',
          scheduledDate: scheduleTime,
        );
      }
    }
  }

  /// Cancel reminders for a deleted assignment
  Future<void> cancelAssignmentReminders(String assignmentId) async {
    if (!_isInitialized) await initNotifications();
    for (int i = 1; i <= 6; i++) {
      await _notificationsPlugin.cancel(assignmentId.hashCode + i);
    }
  }

  /// Schedule notification for a task
  Future<void> scheduleTaskReminder(Task task) async {
    if (!_isInitialized) await initNotifications();

    // Cancel existing task reminder
    await _notificationsPlugin.cancel(task.id.hashCode);

    final dateParts = task.date.split('-');
    if (dateParts.length < 3) return;
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);

    final timeStr = (task.reminderTime != null && task.reminderTime!.isNotEmpty)
        ? task.reminderTime!
        : (task.startTime.isNotEmpty ? task.startTime : '09:00');
    final timeParts = timeStr.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    final scheduleTime = DateTime(year, month, day, hour, minute);
    final now = DateTime.now();

    if (scheduleTime.isAfter(now)) {
      await scheduleNotification(
        id: task.id.hashCode,
        title: 'Task Reminder: ${task.title}',
        body: task.description.isNotEmpty ? task.description : 'Your task is scheduled for today.',
        scheduledDate: scheduleTime,
      );
    }
  }

  Future<void> cancelTaskReminder(int taskId) async {
    if (!_isInitialized) await initNotifications();
    await _notificationsPlugin.cancel(taskId.hashCode);
  }

  /// Automatically monitors attendance metrics and triggers non-spam alerts.
  void checkAndTriggerAttendanceAlerts(AttendanceAnalysis analysis, double target) async {
    final box = await Hive.openBox('aura_notification_flags');
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    for (final sub in analysis.subjectsDetail) {
      final pct = sub.percentage;
      final subKey = sub.subjectName.toLowerCase().replaceAll(' ', '_');

      if (pct < 65.0) {
        // Under 65%: Notify twice a day (Previous Evening + Morning)
        final eveningFlagKey = '${subKey}_65_evening_$todayStr';
        final morningFlagKey = '${subKey}_65_morning_$todayStr';

        final nowHour = DateTime.now().hour;

        // Evening alert
        if (nowHour >= 17 && !box.containsKey(eveningFlagKey)) {
          showNotification(
            id: sub.subjectId * 100 + 1,
            title: 'Critical Attendance Alert',
            body: 'Your ${sub.subjectName} attendance is critically low ($pct%). Attend tomorrow\'s lecture.',
          );
          box.put(eveningFlagKey, true);
        }

        // Morning alert
        if (nowHour >= 6 && nowHour < 12 && !box.containsKey(morningFlagKey)) {
          showNotification(
            id: sub.subjectId * 100 + 2,
            title: 'Urgent Lecture Warning',
            body: 'Your ${sub.subjectName} attendance is at $pct%. You must attend today\'s lecture to recover.',
          );
          box.put(morningFlagKey, true);
        }
      } else if (pct < target) {
        // Under Target (e.g. 75%): Notify once on that day
        final targetFlagKey = '${subKey}_target_$todayStr';

        if (!box.containsKey(targetFlagKey)) {
          showNotification(
            id: sub.subjectId * 100 + 3,
            title: 'Attendance Below Target',
            body: 'Your ${sub.subjectName} attendance is below your ${target.round()}% target. Attend today\'s lecture.',
          );
          box.put(targetFlagKey, true);
        }
      }
    }
  }
}
