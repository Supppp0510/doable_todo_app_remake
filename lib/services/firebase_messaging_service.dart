import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class FCMService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // ============================
  // INITIALIZATION
  // ============================
  static Future<void> initialize() async {
    // Request permission iOS / Android 13+
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Ambil token
    String? token = await _fcm.getToken();
    debugPrint("🔥 FCM TOKEN: $token");

    // Foreground message
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // App dibuka dari notifikasi
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint("📌 App opened from notification: ${message.data}");
    });

    // Notification channel
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'high_importance_channel',
          channelName: 'High Importance Notifications',
          channelDescription: 'Channel for important notifications',
          defaultColor: Colors.blue,
          importance: NotificationImportance.Max,
          playSound: true,
          enableVibration: true,
        ),
      ],
    );
  }

  // ============================
  // FOREGROUND HANDLER
  // ============================
  static Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint("📩 Foreground FCM: ${message.notification?.title}");

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'high_importance_channel',
        title: message.notification?.title ?? "New Notification",
        body: message.notification?.body ?? "You have a new message.",
      ),
    );
  }
}

// ==============================
// BACKGROUND HANDLER (TOP-LEVEL)
// ==============================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("📩 Background FCM: ${message.notification?.title}");

  await AwesomeNotifications().createNotification(
    content: NotificationContent(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      channelKey: 'high_importance_channel',
      title: message.notification?.title,
      body: message.notification?.body ?? "Background message.",
    ),
  );
}
