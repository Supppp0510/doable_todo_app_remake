import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:doable_todo_list_app/models/task_entity.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;
  String username = "Pengguna";

  // Search
  bool _showSearch = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  // Motivasi
  String? motivationText;
  bool _editingMotivation = false;
  final TextEditingController _motivationCtrl = TextEditingController();

  // Filter state
  String _selectedFilter = "Semua"; // options: Semua, Hari Ini, Minggu Ini, Bulan Ini, Selesai, Belum

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadMotivation();

    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim();
      });
    });
  }

  // didChangeDependencies Dihapus: Pembaruan username hanya dipicu saat navigasi balik di _buildBottomNav.

  @override
  void dispose() {
    _searchCtrl.dispose();
    _motivationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    try {
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey("username")) {
          // Hanya panggil setState jika nama pengguna benar-benar berubah
          if (username != data["username"]) {
            username = data["username"];
            setState(() {});
          }
        } else if (user!.displayName != null) {
          if (username != user!.displayName!) {
            username = user!.displayName!;
            setState(() {});
          }
        }
      } else {
        // Jika dokumen user tidak ada, set default
        if (username != "Pengguna") {
          username = "Pengguna";
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error loading username: $e');
      // Jika error, set default dan panggil setState jika perlu
      if (username != "Pengguna") {
        username = "Pengguna";
        setState(() {});
      }
    }
  }


  Future<void> _loadMotivation() async {
    try {
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection("motivasi")
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        motivationText = doc["text"];
        _motivationCtrl.text = motivationText ?? "";
      }
    } catch (e) {
      debugPrint('Error loading motivation: $e');
    }
    setState(() {});
  }

  Future<void> _saveMotivation() async {
    if (user == null) return;
    await FirebaseFirestore.instance.collection("motivasi").doc(user!.uid).set({
      "text": _motivationCtrl.text.trim(),
      "createdAt": FieldValue.serverTimestamp(),
    });

    await _loadMotivation();

    _editingMotivation = false;
  }

  Widget _buildFilterDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Filter Task",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[900],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            _buildFilterTile("Semua"),
            _buildFilterTile("Hari Ini"),
            _buildFilterTile("Minggu Ini"),
            _buildFilterTile("Bulan Ini"),
            _buildFilterTile("Sudah Selesai"),
            _buildFilterTile("Belum Selesai"),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "Filter aktif: $_selectedFilter",
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTile(String label) {
    final selected = _selectedFilter == label;
    return ListTile(
      title: Text(label),
      trailing: selected ? const Icon(Icons.check, color: Color(0xFF0046FF)) : null,
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
        // close drawer
        Navigator.of(context).maybePop();
      },
    );
  }

  // Utility: parse dd/MM/yyyy -> DateTime (midnight)
  // returns null on parse error or null input
  DateTime? _parseDateString(String? dateStr) {
    if (dateStr == null) return null;
    try {
      final parts = (dateStr as String).split("/");
      if (parts.length != 3) return null;
      final d = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final y = int.parse(parts[2]);
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  bool _matchesFilter(Map<String, dynamic> task) {
    // Filter by _selectedFilter and _searchQuery
    // search applied separately
    final now = DateTime.now();
    final date = _parseDateString(task["date"]);
    final completed = task["completed"] == true;

    switch (_selectedFilter) {
      case "Hari Ini":
        if (date == null) return false;
        return date.year == now.year && date.month == now.month && date.day == now.day;
      case "Minggu Ini":
        if (date == null) return false;
        // ISO week: we'll consider week starting Monday
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        final dateOnly = DateTime(date.year, date.month, date.day);
        return !dateOnly.isBefore(DateTime(monday.year, monday.month, monday.day)) &&
            !dateOnly.isAfter(DateTime(sunday.year, sunday.month, sunday.day));
      case "Bulan Ini":
        if (date == null) return false;
        return date.year == now.year && date.month == now.month;
      case "Sudah Selesai":
        return completed;
      case "Belum Selesai":
        return !completed;
      case "Semua":
      default:
        return true;
    }
  }

  bool _matchesSearch(Map<String, dynamic> task) {
    if (_searchQuery.isEmpty) return true;
    final title = (task["title"] ?? "").toString().toLowerCase();
    return title.contains(_searchQuery.toLowerCase());
  }


  // BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildFilterDrawer(), // side sheet
      backgroundColor: Colors.grey[100],

      //TOP NAVBAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // Hamburger
            Builder(
              builder: (ctx) => Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    // buka drawer (side sheet)
                    Scaffold.of(ctx).openDrawer();
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(6.0),
                    child: Icon(Icons.menu, size: 26),
                  ),
                ),
              ),
            ),

            const Spacer(),

            Image.asset(
              "assets/img/DoAbleBiru.png",
              height: 30,
            ),

            const Spacer(),

            //
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) {
                    _searchCtrl.clear();
                    _searchQuery = "";
                  }
                }),
                child: const Padding(
                  padding: EdgeInsets.all(6.0),
                  child: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 16),

            //
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _openNotificationBottomSheet,
                child: const Padding(
                  padding: EdgeInsets.all(6.0),
                  child: Icon(Icons.notifications_none),
                ),
              ),
            ),
          ],
        ),
      ),

      //BODY
      body: Stack(
        children: [
          _buildMainBody(),
          if (_showSearch) _buildSearchOverlay(),
        ],
      ),

      //BOTTOM NAV
      bottomNavigationBar: _buildBottomNav(),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0046FF),
        shape: const CircleBorder(),
        onPressed: () {
          Navigator.pushNamed(context, "/addTask");
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // MAIN BODY
  Widget _buildMainBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),

          // Greeting
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Selamat datang, $username 👋",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 20),

          //MOTIVASI
          _buildMotivationCard(),

          const SizedBox(height: 30),

          //JADWAL HARI INI
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  "Jadwalmu hari ini",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),

                //Lihat lengkap
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.pushNamed(context, "/allTasks");
                    },
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: Colors.blue[800]),
                        const SizedBox(width: 6),
                        Text(
                          "Lihat lengkap",
                          style: TextStyle(
                              color: Colors.blue[800], fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue[800]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          //TASK LIST
          SizedBox(
            height: 150,
            child: StreamBuilder<QuerySnapshot>(
              //
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(user!.uid)
                  .collection("tasks")
                  .orderBy("date")
              // BARIS .orderBy("completed") DIHAPUS UNTUK MENGHENTIKAN LOADING LOOP
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // docs raw dari firestore
                final docs = snapshot.data!.docs;

                //filter
                final filtered = docs.where((ds) {
                  final task = ds.data() as Map<String, dynamic>;
                  return _matchesFilter(task) && _matchesSearch(task);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text("Belum ada task."),
                  );
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final taskDoc = filtered[index];
                    return buildTaskCard(taskDoc);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // SEARCH BAR OVERLAY
  Widget _buildSearchOverlay() {
    return Container(
      color: Colors.white,
      height: 65,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Center(
        child: TextField(
          controller: _searchCtrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Cari task berdasarkan judul...",
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    _showSearch = false;
                    _searchCtrl.clear();
                    _searchQuery = "";
                  });
                },
                child: const Icon(Icons.close),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // MOTIVATION CARD
  Widget _buildMotivationCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B8CFF), Color(0xFF0046FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Motivasi Hari Ini",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),

            if (!_editingMotivation)
              Text(
                motivationText ??
                    "Sepertinya kamu belum memiliki motivasi apapun hari ini.\nTambahkan motivasi untuk menghiasi hari-harimu!",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

            if (_editingMotivation)
              TextField(
                controller: _motivationCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Tulis motivasi...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              ),

            const SizedBox(height: 14),

            GestureDetector(
              onTap: () {
                if (_editingMotivation) {
                  _saveMotivation();
                } else {
                  setState(() => _editingMotivation = true);
                }
              },
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _editingMotivation ? "Simpan" : "Edit",
                      style: const TextStyle(
                        color: Color(0xFF0046FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _editingMotivation ? Icons.check : Icons.edit,
                      size: 16,
                      color: const Color(0xFF0046FF),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TASK CARD (tetap sesuai desainmu)
  Widget buildTaskCard(DocumentSnapshot doc) {
    final task = doc.data() as Map<String, dynamic>;
    final bool done = task["completed"] ?? false;

    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER BIRU
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
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task["title"] ?? "",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: done ? Colors.grey : Colors.black,
                    decoration: done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${task["date"]} ${task["time"] ?? ""}",
                  style: TextStyle(
                    fontSize: 12,
                    color: done ? Colors.grey : Colors.grey[600],
                    decoration: done
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ceklis
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          // update path sesuai users/{uid}/tasks
                          FirebaseFirestore.instance
                              .collection("users")
                              .doc(user!.uid)
                              .collection("tasks")
                              .doc(doc.id)
                              .update({"completed": !done});
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
                                  color: done
                                      ? const Color(0xFF0046FF)
                                      : Colors.grey,
                                  width: 2,
                                ),
                                color:
                                done ? const Color(0xFF0046FF) : Colors.white,
                              ),
                              child: done
                                  ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Tandai Selesai",
                              style: TextStyle(
                                fontSize: 12,
                                color: done ? Colors.grey : const Color(0xFF0046FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // edit
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          final taskEntity = TaskEntity(
                            firestoreId: doc.id,
                            title: task["title"] ?? "",
                            description: task["description"],
                            date: task["date"],
                            time: task["time"],
                            hasNotification: task["hasNotification"] ?? false,
                            repeatRule: task["repeatRule"], // Tambahkan repeatRule
                            completed: task["completed"] ?? false,
                          );

                          Navigator.pushNamed(
                            context,
                            "/editTask",
                            arguments: taskEntity,
                          );
                          // ------------------------------------------
                        },
                        child: const Row(
                          children: [
                            Text("Edit", style: TextStyle(fontSize: 12)),
                            SizedBox(width: 4),
                            Icon(Icons.edit, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // NOTIFICATION BOTTOM SHEET
  void _openNotificationBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return SizedBox(
          height: 320,
          child: Column(
            children: [
              const Text(
                "Daftar Notifikasi",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),

              // Sebentar lagi & Terlewat
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("users")
                      .doc(user!.uid)
                      .collection("tasks")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data!.docs;

                    // Logika: terlewat & mendekati
                    final now = DateTime.now();
                    List<DocumentSnapshot> approaching = [];
                    List<DocumentSnapshot> missed = [];

                    for (var doc in docs) {
                      final task = doc.data() as Map<String, dynamic>;
                      if (task["date"] == null) continue;

                      try {
                        final dateParts = (task["date"] as String).split("/");
                        final d = DateTime(
                          int.parse(dateParts[2]),
                          int.parse(dateParts[1]),
                          int.parse(dateParts[0]),
                        );

                        if (d.isBefore(now)) {
                          missed.add(doc);
                        } else if (d.difference(now).inDays <= 3) {
                          approaching.add(doc);
                        }
                      } catch (_) {
                        // skip parsing errors
                      }
                    }

                    return ListView(
                      children: [
                        if (approaching.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Mendekati Deadline",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ...approaching.map((e) => ListTile(
                          title: Text((e.data() as Map<String, dynamic>)["title"] ?? ""),
                          subtitle: Text((e.data() as Map<String, dynamic>)["date"] ?? ""),
                        )),

                        if (missed.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              "Terlewat",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ...missed.map((e) => ListTile(
                          title: Text((e.data() as Map<String, dynamic>)["title"] ?? ""),
                          subtitle: Text((e.data() as Map<String, dynamic>)["date"] ?? ""),
                        )),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // BOTTOM NAV UI
  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: BottomAppBar(
        color: Colors.white,
        notchMargin: 8,
        elevation: 0,
        shape: const CircularNotchedRectangle(),
        child: SizedBox(
          height: 65,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              GestureDetector(
                onTap: () {},
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.home, color: Colors.blue),
                    Text("Beranda",
                        style: TextStyle(fontSize: 12, color: Colors.blue)),
                  ],
                ),
              ),
              const SizedBox(width: 40),
              GestureDetector(
                onTap: () {
                  // --- KOREKSI: Panggil _loadUsername() setelah navigasi kembali dari ProfilPage ---
                  Navigator.pushNamed(context, "/profile").then((_) {
                    _loadUsername();
                  });
                  // -----------------------------------------------------------------------------------------
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.person_outline, color: Colors.grey),
                    Text("Profil",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}