import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:doable_todo_list_app/screens/login_page.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert'; // Import ini untuk Base64
import 'package:image_picker/image_picker.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance; // Instance Firestore

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = true;
  String? _profilePhotoBase64; // Ganti _profileImageUrl

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ==========================
  // 🔥 UTILITY: Tampilkan Pop-up Berhasil
  // ==========================
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Berhasil!"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK", style: TextStyle(color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  // ==========================
  // 🔥 PICK & SIMPAN FOTO (Menggunakan Base64 ke Firestore)
  // ==========================
  Future<void> _pickAndUploadImage() async {
    if (user == null) return;

    final picker = ImagePicker();
    XFile? pickedFile;

    try {
      pickedFile = await picker.pickImage(source: ImageSource.gallery);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal membuka galeri")),
        );
      }
      return;
    }

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final file = File(pickedFile.path);
      List<int> imageBytes = await file.readAsBytes();

      // 1. Konversi ke Base64
      String base64Image = base64Encode(imageBytes);

      // --- PERINGATAN UKURAN ---
      // Cek apakah Base64 string terlalu besar (melebihi 1MB batas Firestore)
      if (base64Image.length > 800 * 1024) { // Estimasi: 800KB string mentah untuk aman
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Foto terlalu besar! Maksimal 1MB.")),
          );
          return;
        }
      }

      // 2. Simpan string Base64 ke Firestore
      await _firestore.collection('users')
          .doc(user!.uid)
          .set({'profilePhotoBase64': base64Image}, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _profilePhotoBase64 = base64Image;
        });
        _showSuccessDialog("Foto profil berhasil diubah!");
      }
    } catch (e) {
      debugPrint("Upload error (Base64): $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan foto: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================
  // 🔥 LOAD FIREBASE DATA
  // ==========================
  Future<void> _loadUserProfile() async {
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _emailCtrl.text = user!.email ?? 'Email tidak ditemukan';

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user!.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        _nameCtrl.text = data?['username'] ?? user!.displayName ?? 'Pengguna';
        // Ambil string Base64
        _profilePhotoBase64 = data?['profilePhotoBase64'];
      } else {
        _nameCtrl.text = user!.displayName ?? 'Pengguna';
        _profilePhotoBase64 = null;
      }
    } catch (e) {
      debugPrint("Error loading user profile: $e");
      _nameCtrl.text = user!.displayName ?? 'Pengguna Error';
      _profilePhotoBase64 = null;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ==========================
  // 🔥 SAVE USERNAME (Tidak Berubah)
  // ==========================
  Future<void> _saveUsername() async {
    if (user == null || _nameCtrl.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final newUsername = _nameCtrl.text.trim();

    try {
      await _firestore.collection('users')
          .doc(user!.uid)
          .set({'username': newUsername}, SetOptions(merge: true));

      user!.updateDisplayName(newUsername).catchError((e) => debugPrint("Error updating auth name: $e"));

      if (mounted) {
        _showSuccessDialog('Nama berhasil disimpan!');
      }
    } catch (e) {
      debugPrint("Error saving username: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan nama. Coba lagi.')),
        );
      }
    }

    setState(() {
      _isEditing = false;
      _isLoading = false;
    });
  }

  // ==========================
  // 🔥 POPUP KONFIRMASI LOGOUT (Tidak Berubah)
  // ==========================
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Konfirmasi"),
          content: const Text("Yakin ingin keluar dari akun?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Tidak",
                style: TextStyle(color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();

                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                        (route) => false,
                  );
                }
              },
              child: const Text(
                "Ya",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF2F2F2),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Tentukan avatar image
    ImageProvider? avatarImage;
    if (_profilePhotoBase64 != null) {
      // Konversi Base64 string menjadi ImageProvider
      try {
        final decodedBytes = base64Decode(_profilePhotoBase64!);
        avatarImage = MemoryImage(decodedBytes);
      } catch (e) {
        debugPrint("Error decoding Base64: $e");
        avatarImage = null; // Gagal decode, kembali ke default
      }
    }


    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Image.asset("assets/img/DoAbleBiru.png", height: 28),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text(
              "Profil Anda",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            // --- FOTO PROFIL DAN TOMBOL UBAH ---
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey[300],
                  // Gunakan avatarImage yang sudah didefinisikan
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(Icons.person, size: 55, color: Colors.white)
                      : null,
                ),
                // Tombol ubah foto
                Positioned(
                  child: GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: const CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            // ------------------------------------

            const SizedBox(height: 10),

            // Tombol Edit/Save (untuk Nama)
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _saveUsername();
                } else {
                  setState(() => _isEditing = true);
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isEditing ? "Simpan" : "Edit",
                    style: const TextStyle(color: Colors.blue, fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isEditing ? Icons.check : Icons.edit,
                    size: 15,
                    color: Colors.blue,
                  )
                ],
              ),
            ),

            const SizedBox(height: 25),

            // ======== CARD PUTIH ========
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Nama",
                      style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameCtrl,
                    enabled: _isEditing,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: _isEditing
                            ? const BorderSide(color: Colors.blue, width: 2)
                            : BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: _isEditing
                            ? const BorderSide(color: Colors.blue, width: 2)
                            : BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.blue, width: 2),
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),

                  const SizedBox(height: 18),

                  const Text("Email",
                      style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailCtrl,
                    enabled: false,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ======== LOGOUT BUTTON DENGAN INKWELL ========
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _showLogoutDialog,
                child: Container(
                  width: double.infinity,
                  padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2D2D), Color(0xFFFF7A7A)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      "Logout",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}