import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:doable_todo_list_app/screens/profil_page.dart';
import 'package:doable_todo_list_app/services/firebase_messaging_service.dart';
import 'package:doable_todo_list_app/services/notification_service.dart';
import 'package:doable_todo_list_app/repositories/task_repository.dart';
import 'package:doable_todo_list_app/screens/add_task_page.dart';
import 'package:doable_todo_list_app/screens/edit_task_page.dart';
import 'package:doable_todo_list_app/screens/home_page.dart';
import 'package:doable_todo_list_app/screens/splashscreen.dart';
import 'package:doable_todo_list_app/screens/all_task_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// ==============================================================
// TOP-LEVEL BACKGROUND HANDLER (WAJIB)
// ==============================================================

@pragma("vm:entry-point")
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // safe guard in background: ensure AwesomeNotifications initialized
  try {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'high_importance_channel',
          channelName: 'High Importance Notifications',
          channelDescription: 'Firebase Cloud Messaging push notifications',
          defaultColor: Colors.blue,
          importance: NotificationImportance.Max,
          playSound: true,
          enableVibration: true,
        ),
      ],
    );
  } catch (_) {}

  try {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        channelKey: 'high_importance_channel',
        title: message.notification?.title ?? "New Notification",
        body: message.notification?.body ?? "Background message.",
      ),
    );
  } catch (e) {
    // If background notification fails, just print
    // (Logcat will show this)
    print("🔥 BG notif error: $e");
  }
}

// ==============================================================
// MAIN ENTRY (with robust error handling)
// ==============================================================
Future<void> main() async {
  // Catch any uncaught errors and show/print them instead of white screen.
  FlutterError.onError = (FlutterErrorDetails details) {
    // Send to console
    FlutterError.presentError(details);
  };

  WidgetsFlutterBinding.ensureInitialized();

  // runZonedGuarded to catch all future errors
  await runZonedGuarded<Future<void>>(() async {
    // 1️⃣ INIT FIREBASE (safe)
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print("✅ Firebase initialized");
    } catch (e, st) {
      print("❌ Firebase initialize failed: $e\n$st");
      // don't rethrow — app will continue and show UI (we'll show an error screen later if needed)
    }

    // 2️⃣ REGISTER BACKGROUND HANDLER (must be top-level)
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      print("✅ Registered FCM background handler");
    } catch (e) {
      print("⚠️ Could not register background handler: $e");
    }

    // 3️⃣ SAFE INIT AWESOME NOTIFICATIONS
    try {
      await AwesomeNotifications().initialize(
        null,
        [
          NotificationChannel(
            channelKey: 'task_reminders',
            channelName: 'Task Reminders',
            channelDescription: 'Local notifications for task reminders',
            defaultColor: const Color(0xff4285F4),
            importance: NotificationImportance.High,
          ),
          NotificationChannel(
            channelKey: 'high_importance_channel',
            channelName: 'High Importance Notifications',
            channelDescription: 'Firebase Cloud Messaging push notifications',
            defaultColor: Colors.blue,
            importance: NotificationImportance.Max,
            playSound: true,
            enableVibration: true,
          ),
        ],
        debug: true,
      );
      print("✅ AwesomeNotifications initialized");
    } catch (e) {
      print("❌ AwesomeNotifications init failed: $e");
    }

    // 4️⃣ REQUEST / CHECK PERMISSIONS wrapped in try/catch
    try {
      final hasPermission = await NotificationService.requestPermissions();
      print(hasPermission ? "Local Notif: granted" : "Local Notif: denied");
    } catch (e) {
      print("⚠️ requestPermissions failed: $e");
    }

    // 5️⃣ Init FCM service (foreground listeners, token)
    try {
      await FCMService.initialize();
      print("✅ FCM Service initialized");
    } catch (e) {
      print("⚠️ FCMService.initialize failed: $e");
    }

    // 6️⃣ SYSTEM UI
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    // 7️⃣ run app
    runApp(const DoableApp());
  }, (error, stack) {
    // Any uncaught error will land here
    print("💥 Uncaught zone error: $error\n$stack");
  });
}

// ==============================================================
// ROOT APP
// ==============================================================

class DoableApp extends StatefulWidget {
  const DoableApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  @override
  State<DoableApp> createState() => _DoableAppState();
}

class _DoableAppState extends State<DoableApp> {
  @override
  void initState() {
    super.initState();

    // defensive: wrap listener registration
    try {
      AwesomeNotifications().setListeners(
        onActionReceivedMethod: onActionReceivedMethod,
        onNotificationDisplayedMethod: onNotificationDisplayedMethod,
        onNotificationCreatedMethod: onNotificationCreatedMethod,
        onDismissActionReceivedMethod: onDismissActionReceivedMethod,
      );
    } catch (e) {
      print("⚠️ setListeners failed: $e");
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction action) async {
    try {
      if (action.payload?['task_id'] != null) {
        DoableApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/home',
              (route) => false,
        );
      }
    } catch (e) {
      print("⚠️ onActionReceivedMethod error: $e");
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification notif) async {}

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification notif) async {}

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction action) async {}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: DoableApp.navigatorKey,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: "Inter",
      ),
      onGenerateRoute: (settings) {
        Widget page;

        switch (settings.name) {
          case '/home':
            page = const HomePage();
            break;
          case '/addTask':
            page = const AddTaskPage();
            break;
          case '/editTask':
            final task = settings.arguments;
            return MaterialPageRoute(
              builder: (_) => EditTaskPage(),
              settings: RouteSettings(arguments: task),
            );
          case '/profile':
            page = const ProfilPage();
            break;
          case '/allTasks':
            page = const AllTasksPage();
            break;
          default:
            page = const HomePage();
            break;
        }

        if (settings.name == '/addTask' || settings.name == '/profile') {
          return PageRouteBuilder(
            pageBuilder: (_, __, ___) => page,
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: Tween(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.ease,
                )),
                child: child,
              );
            },
          );
        }

        return MaterialPageRoute(builder: (_) => page);
      },
    );
  }
}
