import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_entity.dart';

class NotificationService {
  static const String channelKey = 'task_reminders';

  // ===================================================
  // INIT
  // ===================================================
  static Future<void> init() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: channelKey,
          channelName: 'Task Reminders',
          channelDescription: 'Reminder for tasks',
          importance: NotificationImportance.High,
          defaultColor: const Color(0xFF9D50DD),
          ledColor: const Color(0xFFFFFFFF),
        ),
      ],
    );
  }

  // ===================================================
  // CHECK PERMISSION
  // ===================================================
  static Future<bool> areNotificationsEnabledByUser() async {
    return await AwesomeNotifications().isNotificationAllowed();
  }

  // ===================================================
  // REQUEST PERMISSIONS
  // ===================================================
  static Future<bool> requestPermissions() async {
    bool allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      allowed = await AwesomeNotifications().requestPermissionToSendNotifications();
    }
    return allowed;
  }

  // ===================================================
  // SCHEDULE TASK NOTIFICATION (UTAMA)
  // ===================================================
  static Future<void> scheduleTaskNotification(TaskEntity task) async {
    if (task.notificationId == null) return;
    if (task.date == null || task.time == null) return;

    final dateString = "${task.date} ${task.time}";
    final dateTime = DateFormat("yyyy-MM-dd HH:mm").parse(dateString);

    if (dateTime.isBefore(DateTime.now())) return;

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: task.notificationId!,
        channelKey: channelKey,
        title: task.title,
        body: task.description ?? "You have a task reminder.",
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        year: dateTime.year,
        month: dateTime.month,
        day: dateTime.day,
        hour: dateTime.hour,
        minute: dateTime.minute,
        second: 0,
        millisecond: 0,
        preciseAlarm: true,
      ),
    );

    print("⏰ Scheduled notification: ${task.notificationId}");
  }

  // ===================================================
  // SIMPLE REMINDER (3 HARI SEBELUM)
  // ===================================================
  static Future<void> scheduleTaskReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelKey,
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar(
        year: scheduledDate.year,
        month: scheduledDate.month,
        day: scheduledDate.day,
        hour: scheduledDate.hour,
        minute: scheduledDate.minute,
        second: 0,
        millisecond: 0,
        preciseAlarm: true,
      ),
    );

    print("⏰ Reminder scheduled at: $scheduledDate (ID: $id)");
  }

  // ===================================================
  // CANCEL SPECIFIC
  // ===================================================
  static Future<void> cancelTaskNotification(int? notificationId) async {
    if (notificationId == null) return;
    await AwesomeNotifications().cancel(notificationId);
    print("❌ Canceled notification: $notificationId");
  }

  // ===================================================
  // CANCEL ALL
  // ===================================================
  static Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
    print("🧹 All notifications cleared.");
  }
}
