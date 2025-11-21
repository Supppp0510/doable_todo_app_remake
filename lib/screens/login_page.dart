import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// --- TAMBAH INI ---
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ------------------
import 'register_page.dart';
import 'home_page.dart';

// TOAST
void showToastTopRight(BuildContext context, String message, {bool success = false}) {
  OverlayEntry overlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      top: 40,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: success ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    ),
  );

  Overlay.of(context).insert(overlayEntry);

  Future.delayed(const Duration(seconds: 2)).then((_) {
    overlayEntry.remove();
  });
}



class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;
  bool _isLoading = false; // Tambahkan state loading

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _firestore = FirebaseFirestore.instance; // Tambahkan firestore instance

  //FUNGSI LOGIN MANUAL
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      showToastTopRight(context, "Email dan password wajib diisi");
      return;
    }

    setState(() => _isLoading = true); // Mulai loading

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        showToastTopRight(context, "Login berhasil!", success: true);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Email atau Password mungkin error!";

      if (e.code == 'user-not-found') {
        msg = "Email tidak terdaftar";
      } else if (e.code == 'wrong-password') {
        msg = "Password salah";
      } else if (e.code == 'invalid-email') {
        msg = "Format email tidak valid";
      }

      if (mounted) {
        showToastTopRight(context, msg);
      }
    } finally {
      setState(() => _isLoading = false); // Hentikan loading
    }
  }


  // --- FUNGSI BARU: LOGIN DENGAN GOOGLE ---
  Future<void> _signInWithGoogle() async {
    try {
      setState(() => _isLoading = true);

      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // batal login
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          // Jika ini adalah akun Google yang baru mendaftar
          await _firestore.collection('users').doc(user.uid).set({
            'username': user.displayName ?? '',
            'email': user.email,
            'photo_url': user.photoURL,
            'created_at': DateTime.now(),
            'auth_method': 'google',
          });
        }
      }

      if (mounted) {
        showToastTopRight(context, "Berhasil masuk dengan Google!", success: true);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      if (mounted) {
        showToastTopRight(context, 'Gagal masuk dengan Google: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // === BACKGROUND GRADIENT ===
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0046FF),
              Color(0xFF5B8CFF),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              width: 360,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // === HEADER BIRU ===
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF5B8CFF),
                          Color(0xFF1A59FF),
                        ],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "Masuk",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 30),
                    child: Column(
                      children: [
                        //WELCOME + LOGO
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Welcome to ",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Image.asset(
                              'assets/img/DoAbleBiru.png',
                              height: 28,
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        //EMAIL FIELD
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Masukkan alamat email',
                            labelStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF0046FF),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        //PASSWORD FIELD
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Masukkan kata sandi',
                            labelStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xFF0046FF),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        //BUTTON LOGIN
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login, // Gunakan _isLoading
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0046FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                              "Masuk",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        //PEMBATAS
                        Row(
                          children: const [
                            Expanded(child: Divider(thickness: 1)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                "atau",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            Expanded(child: Divider(thickness: 1)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        //GOOGLE LOGIN
                        Container(
                          width: double.infinity,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: InkWell(
                            onTap: _isLoading ? null : _signInWithGoogle,
                            borderRadius: BorderRadius.circular(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/img/Google.png',
                                  height: 22,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Masuk dengan Google",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        //DAFTAR
                        RichText(
                          text: TextSpan(
                            text: "Belum punya akun? ",
                            style: const TextStyle(color: Colors.black87),
                            children: [
                              TextSpan(
                                text: "Daftar di sini",
                                style: const TextStyle(
                                  color: Color(0xFF0046FF),
                                  fontWeight: FontWeight.w600,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                        const RegisterPage(),
                                      ),
                                    );
                                  },
                              ),
                            ],
                          ),
                        ),

                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}