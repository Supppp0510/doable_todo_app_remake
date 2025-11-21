import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'package:doable_todo_list_app/models/task_entity.dart';
import 'package:doable_todo_list_app/repositories/task_repository.dart';
import 'package:doable_todo_list_app/services/notification_service.dart';

class EditTaskPage extends StatefulWidget {
  const EditTaskPage({super.key});

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  TaskEntity? _task;

  bool _reminder = false;
  String? _repeatRule;
  final Set<int> _repeatWeekdays = {};
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  String _username = "Pengguna";

  static const Color blueColor = Color(0xFF2563EB);

  EdgeInsets get _screenHPad {
    final w = MediaQuery.of(context).size.width;
    return EdgeInsets.symmetric(horizontal: (w * 0.05).clamp(16.0, 24.0));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final arg = ModalRoute.of(context)!.settings.arguments;
      if (arg is TaskEntity) {
        _task = arg;

        _titleCtrl.text = _task!.title;
        _descCtrl.text = _task!.description ?? '';

        _reminder = _task!.hasNotification;
        _repeatRule = _task!.repeatRule;
        _hydrateWeekdaysFromRule(_repeatRule);

        _selectedDate = _parseDateOrNull(_task!.date);
        _selectedTime = _parseTimeOrNull(_task!.time);
      } else {
        Navigator.pop(context, false);
        return;
      }

      await _loadUsername();
      setState(() {});
    });
  }

  Future<void> _loadUsername() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey("username")) {
          _username = data["username"] ?? _username;
        } else if (user.displayName != null && user.displayName!.isNotEmpty) {
          _username = user.displayName!;
        }
      } else if (user.displayName != null && user.displayName!.isNotEmpty) {
        _username = user.displayName!;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  String _formatTime(TimeOfDay t) {
    final dt = DateTime(0, 1, 1, t.hour, t.minute);
    return DateFormat('h:mm a').format(dt);
  }

  DateTime? _parseDateOrNull(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(s);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseTimeOrNull(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      final dt = DateFormat('h:mm a').parseStrict(s);
      return TimeOfDay.fromDateTime(dt);
    } catch (_) {
      return null;
    }
  }

  void _hydrateWeekdaysFromRule(String? rule) {
    _repeatWeekdays.clear();
    if (rule == null) return;
    if (!rule.startsWith('Weekly')) return;

    final exp = RegExp(r'(\d+)');
    for (final m in exp.allMatches(rule)) {
      final v = int.tryParse(m.group(1)!);
      if (v != null) _repeatWeekdays.add(v);
    }
  }

  void _selectRepeatRule(String rule) {
    setState(() {
      _repeatRule = rule;
      if (rule != 'Weekly') _repeatWeekdays.clear();
    });
  }

  void _toggleWeekday(int weekday) {
    setState(() {
      if (_repeatWeekdays.contains(weekday)) {
        _repeatWeekdays.remove(weekday);
      } else {
        _repeatWeekdays.add(weekday);
      }
      if (_repeatWeekdays.isNotEmpty) _repeatRule = 'Weekly';
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _toggleReminder() async {
    final enabled = await NotificationService.areNotificationsEnabledByUser();
    if (!enabled) return;
    setState(() => _reminder = !_reminder);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    if (_task == null) return;

    final dateStr = _selectedDate != null ? _formatDate(_selectedDate!) : null;
    final timeStr = _selectedTime != null ? _formatTime(_selectedTime!) : null;

    String? normalizedRepeat;
    if (_repeatRule == null || _repeatRule == 'No repeat') {
      normalizedRepeat = null;
    } else if (_repeatRule == 'Weekly' && _repeatWeekdays.isNotEmpty) {
      final list = _repeatWeekdays.toList()..sort();
      normalizedRepeat = 'Weekly:${list.toString()}';
    } else {
      normalizedRepeat = _repeatRule;
    }

    final updated = TaskEntity(
      notificationId: _task!.notificationId,
      firestoreId: _task!.firestoreId,
      title: title,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      time: timeStr,
      date: dateStr,
      hasNotification: _reminder,
      repeatRule: normalizedRepeat,
      completed: _task!.completed,
      createdAt: _task!.createdAt,
    );

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await TaskRepository().update(uid, updated);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan')),
      );
      return;
    }

    if (!mounted) return;
    await _showSavedDialogAndPop();
  }

  Future<void> _showSavedDialogAndPop() async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 220,
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF5B8CFF), Color(0xFF00A823)],
                      ),
                    ),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 42),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Edit disimpan',
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Navigator.pop(context);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_task == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    final spacing = 12.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.arrow_back, color: Colors.black),
        ),
        title: Center(
          child: Image.asset(
            'assets/img/DoAbleBiru.png',
            height: 32,
          ),
        ),
        actions: const [SizedBox(width: 48)],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: _screenHPad.add(const EdgeInsets.only(bottom: 36, top: 8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                  'Edit apa nih $_username? 🤔',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Colors.black87),
                ),
              ),
              const SizedBox(height: 18),

              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nama',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleCtrl,
                      decoration: _inputDeco(),
                    ),
                    SizedBox(height: spacing * 1.2),

                    const Text('Deskripsi',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descCtrl,
                      maxLines: 5,
                      decoration: _inputDeco(),
                    ),

                    SizedBox(height: spacing * 1.2),
                    const Text('Tanggal',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _PickerField(
                      iconAsset: "assets/calendar.svg",
                      hint: "Pilih tanggal",
                      valueText: _selectedDate != null
                          ? _formatDate(_selectedDate!)
                          : _task!.date,
                      onTap: _pickDate,
                      onClear: _selectedDate != null
                          ? () => setState(() => _selectedDate = null)
                          : null,
                    ),

                    SizedBox(height: spacing * 1.2),
                    const Text('Jam',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _PickerField(
                      iconAsset: "assets/clock.svg",
                      hint: "Pilih jam",
                      valueText: _selectedTime != null
                          ? _formatTime(_selectedTime!)
                          : _task!.time,
                      onTap: _pickTime,
                      onClear: _selectedTime != null
                          ? () => setState(() => _selectedTime = null)
                          : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),
              Row(
                children: [
                  const Spacer(),
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      width: 140,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5B8CFF), Color(0xFF5690FF)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Simpan',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}

/* ================= Reusable updated widget ================= */

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.hint,
    required this.iconAsset,
    required this.onTap,
    this.valueText,
    this.onClear,
  });

  final String hint;
  final String iconAsset;
  final String? valueText;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasValue = valueText != null && valueText!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              iconAsset,
              height: 20,
              width: 20,
              colorFilter:
              const ColorFilter.mode(Colors.black87, BlendMode.srcIn),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                hasValue ? valueText! : hint,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                  color: hasValue ? Colors.black87 : Colors.black54,
                ),
              ),
            ),

            Icon(
              iconAsset.contains("calendar")
                  ? Icons.calendar_today
                  : Icons.access_time,
              size: 20,
              color: Colors.black87,
            ),
          ],
        ),
      ),
    );
  }
}
