class TaskEntity {
  /// ID lokal (integer) untuk keperluan notifikasi
  int? notificationId;

  /// ID dokumen Firestore (string)
  String? firestoreId;

  String title;
  String? description;
  String? time; // contoh: "08:30" atau "8:30 AM" tergantung formatmu
  String? date; // contoh: "2025-11-13" (yyyy-MM-dd)
  bool hasNotification;
  String? repeatRule;
  bool completed;
  DateTime createdAt;

  TaskEntity({
    this.notificationId,
    this.firestoreId,
    required this.title,
    this.description,
    this.time,
    this.date,
    this.hasNotification = false,
    this.repeatRule,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'title': title,
      'description': description,
      'time': time,
      'date': date,
      'hasNotification': hasNotification,
      'repeatRule': repeatRule,
      'completed': completed,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TaskEntity.fromMap(Map<String, dynamic> map, String? firestoreId) {
    return TaskEntity(
      notificationId: map['notificationId'] is int ? map['notificationId'] as int : (map['notificationId'] != null ? int.tryParse(map['notificationId'].toString()) : null),
      firestoreId: firestoreId,
      title: map['title'] ?? '',
      description: map['description'],
      time: map['time'],
      date: map['date'],
      hasNotification: map['hasNotification'] ?? false,
      repeatRule: map['repeatRule'],
      completed: map['completed'] ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
