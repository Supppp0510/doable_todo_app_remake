import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_entity.dart';
import '../services/notification_service.dart';


class TaskRepository {
  final _firestore = FirebaseFirestore.instance;

  // ============================================
  // Helper users/{uid}/tasks
  // ============================================
  CollectionReference<Map<String, dynamic>> _taskRef(String uid) {
    return _firestore.collection("users").doc(uid).collection("tasks");
  }

  // ====================================================
  // Fetch all tasks
  // ====================================================
  Future<List<TaskEntity>> fetchAll(String uid) async {
    try {
      final snapshot =
      await _taskRef(uid).orderBy('createdAt', descending: true).get();

      return snapshot.docs
          .map((doc) => TaskEntity.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print("❌ Error fetching tasks: $e");
      return [];
    }
  }

  // ====================================================
  // Add new task
  // ====================================================
  Future<String> add(String uid, TaskEntity t) async {
    try {
      final data = t.toMap();
      data['createdAt'] = DateTime.now().toIso8601String();

      final docRef = await _taskRef(uid).add(data);
      t.firestoreId = docRef.id;

      // 🔥 jadikan notificationId otomatis dari firestoreId hashCode
      t.notificationId = docRef.id.hashCode;

      if (t.hasNotification) {
        await NotificationService.scheduleTaskNotification(t);
      }

      print("✅ Task added: ${t.title}");
      return docRef.id;
    } catch (e) {
      print("❌ Error adding task: $e");
      rethrow;
    }
  }

  // ====================================================
  // UPDATE TASK
  // ====================================================
  Future<void> update(String uid, TaskEntity t) async {
    if (t.firestoreId == null) return;

    try {
      await _taskRef(uid).doc(t.firestoreId).update({
        "title": t.title,
        "description": t.description,
        "date": t.date,
        "time": t.time,
        "hasNotification": t.hasNotification,
        "repeatRule": t.repeatRule,
        "completed": t.completed,
        "notificationId": t.notificationId,
        "updatedAt": DateTime.now().toIso8601String(),
      });

      // 🔥 Update notifikasi
      await NotificationService.cancelTaskNotification(t.notificationId);

      if (t.hasNotification && !t.completed) {
        await NotificationService.scheduleTaskNotification(t);
      }

      print("✅ Task updated: ${t.firestoreId}");
    } catch (e) {
      print("❌ Error updating task: $e");
    }
  }

  // ====================================================
  // DELETE
  // ====================================================
  Future<void> delete(String uid, String firestoreId, int notificationId) async {
    try {
      await NotificationService.cancelTaskNotification(notificationId);
      await _taskRef(uid).doc(firestoreId).delete();
      print("🗑️ Task deleted: $firestoreId");
    } catch (e) {
      print("❌ Error deleting task: $e");
    }
  }

  // ====================================================
  // TOGGLE COMPLETE
  // ====================================================
  Future<void> toggle(
      String uid, String firestoreId, int notificationId, bool value) async {
    try {
      await _taskRef(uid).doc(firestoreId).update({'completed': value});

      if (value) {
        await NotificationService.cancelTaskNotification(notificationId);
      } else {
        final doc = await _taskRef(uid).doc(firestoreId).get();
        if (doc.exists) {
          final task = TaskEntity.fromMap(doc.data()!, firestoreId);

          if (task.hasNotification) {
            await NotificationService.scheduleTaskNotification(task);
          }
        }
      }

      print("✅ Task toggled: $firestoreId → $value");
    } catch (e) {
      print("❌ Error toggling task: $e");
    }
  }

  // ====================================================
  // CLEAR ALL TASKS
  // ====================================================
  Future<void> clearAll(String uid) async {
    try {
      final snapshot = await _taskRef(uid).get();

      for (var doc in snapshot.docs) {
        final task = TaskEntity.fromMap(doc.data(), doc.id);

        await NotificationService.cancelTaskNotification(task.notificationId);
        await doc.reference.delete();
      }

      print("🧹 All tasks cleared.");
    } catch (e) {
      print("❌ Error clearing tasks: $e");
    }
  }
}
