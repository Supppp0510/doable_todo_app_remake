import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:doable_todo_list_app/models/task_entity.dart';
import 'package:doable_todo_list_app/services/notification_service.dart';

class AllTasksPage extends StatefulWidget {
  const AllTasksPage({super.key});

  @override
  State<AllTasksPage> createState() => _AllTasksPageState();
}

class _AllTasksPageState extends State<AllTasksPage> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 120,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 26),
                  ),
                  const Spacer(),
                  Image.asset("assets/img/DoAbleBiru.png", height: 30),
                  const Spacer(),
                  const SizedBox(width: 50),
                ],
              ),
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          const SizedBox(height: 12),
          const Text("Semua Task",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(user!.uid)
                  .collection("tasks")
                  .orderBy("date")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text("Belum ada task."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(context, docs[index]);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 10),
          const Text("<< Geser ke kiri untuk menghapus task",
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ========================= TASK CARD =========================

  Widget _buildTaskCard(BuildContext context, DocumentSnapshot doc) {
    final rawTask = doc.data() as Map<String, dynamic>;
    final isDone = rawTask["completed"] ?? false;

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,

      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),

      confirmDismiss: (direction) async {
        final bool? confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("Konfirmasi Hapus"),
            content: const Text("Yakin ingin menghapus task ini?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Batal")),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Hapus",
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );

        if (confirm != true) return false;

        final String docId = doc.id;
        final int notifId = docId.hashCode.abs(); // 🔥 Notif ID konsisten

        final backupTask = Map<String, dynamic>.from(rawTask);

        // Hapus dari Firestore
        await FirebaseFirestore.instance
            .collection("users")
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .collection("tasks")
            .doc(docId)
            .delete();

        // Batalkan notifikasi
        await NotificationService.cancelTaskNotification(notifId);

        // SNACKBAR UNDO
        Future.microtask(() {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Task berhasil dihapus — Undo Changes?"),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: "UNDO",
                onPressed: () async {
                  // 1. Restore Firestore
                  await FirebaseFirestore.instance
                      .collection("users")
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .collection("tasks")
                      .doc(docId)
                      .set(backupTask);

                  // 2. Buat ulang entity untuk jadwalkan notifikasi
                  final restoredTask = TaskEntity(
                    notificationId: notifId, // 🔥 FIX bagian error!
                    firestoreId: docId,
                    title: backupTask["title"] ?? "",
                    description: backupTask["description"],
                    date: backupTask["date"],
                    time: backupTask["time"],
                    hasNotification: backupTask["hasNotification"] ?? false,
                    repeatRule: backupTask["repeatRule"],
                    completed: backupTask["completed"] ?? false,
                  );

                  if (restoredTask.hasNotification && !restoredTask.completed) {
                    await NotificationService.scheduleTaskNotification(restoredTask);
                  }
                },
              ),
            ),
          );
        });

        return true;
      },

      child: _taskCardUI(context, rawTask, isDone, doc.id),
    );
  }

  Widget _taskCardUI(
      BuildContext context, Map<String, dynamic> rawTask, bool isDone, String docId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5B8CFF), Color(0xFF0046FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rawTask["title"] ?? "",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDone ? Colors.grey : Colors.black,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  "${rawTask["date"]} ${rawTask["time"] ?? ""}",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDone ? Colors.grey : Colors.black54,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        FirebaseFirestore.instance
                            .collection("users")
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .collection("tasks")
                            .doc(docId)
                            .update({"completed": !isDone});
                      },
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                width: 2,
                                color: isDone
                                    ? const Color(0xFF0046FF)
                                    : Colors.grey,
                              ),
                              color: isDone
                                  ? const Color(0xFF0046FF)
                                  : Colors.white,
                            ),
                            child: isDone
                                ? const Icon(Icons.check,
                                color: Colors.white, size: 14)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Tandai Selesai",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDone
                                  ? Colors.grey
                                  : const Color(0xFF0046FF),
                            ),
                          ),
                        ],
                      ),
                    ),

                    GestureDetector(
                      onTap: () {
                        final taskEntity = TaskEntity(
                          firestoreId: docId,
                          title: rawTask["title"] ?? "",
                          description: rawTask["description"],
                          date: rawTask["date"],
                          time: rawTask["time"],
                          hasNotification: rawTask["hasNotification"] ?? false,
                          repeatRule: rawTask["repeatRule"],
                          completed: rawTask["completed"] ?? false,
                        );

                        Navigator.pushNamed(
                          context,
                          "/editTask",
                          arguments: taskEntity,
                        );
                      },
                      child: Row(
                        children: const [
                          Text("Edit", style: TextStyle(fontSize: 12)),
                          SizedBox(width: 4),
                          Icon(Icons.edit, size: 16),
                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
