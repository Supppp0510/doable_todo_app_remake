import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/success_dialog.dart';
import '../services/notification_service.dart'; // 🔵 tambahkan ini

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _reminder3Days = false;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .get();

    if (doc.exists && mounted) {
      setState(() {
        _username = doc.data()!["username"] ?? "Kamu";
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 4),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  // ============================================================
  // 🔵 SAVE TASK + FIRESTORE + REMINDER 3 HARI
  // ============================================================
  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama task tidak boleh kosong")),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Buat docRef agar dapat taskId
    final docRef = FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("tasks")
        .doc();

    DateTime? taskDateTime;
    DateTime? reminderDateTime;

    // Jika user memilih tanggal + jam → gabungkan jadi DateTime
    if (_selectedDate != null && _selectedTime != null) {
      taskDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      if (_reminder3Days) {
        reminderDateTime = taskDateTime.subtract(const Duration(days: 3));
      }
    }

    final taskData = {
      "taskId": docRef.id,
      "title": _nameCtrl.text.trim(),
      "description": _descCtrl.text.trim(),
      "date": _selectedDate != null
          ? DateFormat("dd/MM/yyyy").format(_selectedDate!)
          : null,
      "time": _selectedTime != null
          ? _selectedTime!.format(context)
          : null,
      "completed": false,
      "hasNotification": _reminder3Days,
      "reminderTimestamp": reminderDateTime?.millisecondsSinceEpoch,
      "createdAt": FieldValue.serverTimestamp(),
    };

    // Simpan task
    await docRef.set(taskData);

    // ============================================================
    // 🔵 Jadwalkan reminder (Awesome Notifications)
    // ============================================================
    if (_reminder3Days && reminderDateTime != null) {
      await NotificationService.scheduleTaskReminder(
        id: reminderDateTime.millisecondsSinceEpoch ~/ 1000,
        title: _nameCtrl.text.trim(),
        body: "Jangan lupa, task ini tinggal 3 hari lagi!",
        scheduledDate: reminderDateTime,
      );
    }

    // Tampilkan dialog sukses
    await SuccessDialog.show(context, "Task Ditambahkan!");

    if (mounted) Navigator.pop(context, true);
  }

  // ============================================================
  // 🔵 UI (TIDAK DIUBAH)
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffEFEFEF),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: SizedBox(
          height: 40,
          child: Image.asset(
            'assets/img/DoAbleBiru.png',
            fit: BoxFit.contain,
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          children: [
            const SizedBox(height: 10),

            Text(
              "Tambahin apa nih ${_username ?? '...'}? 🤭",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 24),
            const Text("Nama", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              decoration: _inputDecoration(),
            ),

            const SizedBox(height: 20),
            const Text("Deskripsi", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: _inputDecoration(),
            ),

            const SizedBox(height: 20),
            const Text("Tanggal", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),

            InkWell(
              onTap: _pickDate,
              child: _pickerBox(
                _selectedDate != null
                    ? DateFormat("dd/MM/yyyy").format(_selectedDate!)
                    : "Pilih tanggal",
                Icons.calendar_today,
              ),
            ),

            const SizedBox(height: 20),
            const Text("Jam", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),

            InkWell(
              onTap: _pickTime,
              child: _pickerBox(
                _selectedTime != null
                    ? _selectedTime!.format(context)
                    : "Pilih jam",
                Icons.access_time,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Checkbox(
                  value: _reminder3Days,
                  onChanged: (v) => setState(() => _reminder3Days = v ?? false),
                  activeColor: const Color(0xff4285F4),
                ),
                const SizedBox(width: 4),
                const Text(
                  "Ingatkan Saya 3 Hari Sebelumnya",
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SizedBox(
          height: 50,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff4285F4), Color(0xff6FA8FF)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _save,
              child: const Center(
                child: Text(
                  "Tambah Task",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper Decorations
  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  Widget _pickerBox(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Text(text, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Icon(icon, size: 20),
        ],
      ),
    );
  }
}
