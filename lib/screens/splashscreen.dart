import 'dart:async';
import 'package:doable_todo_list_app/screens/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Timer 2 detik untuk splash
    Timer(const Duration(seconds: 2), () async {
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // USER MASIH LOGIN → ke HomePage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        // USER BELUM LOGIN → ke LoginPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0033FF), Color(0xFF99A8FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SizedBox.expand(
            child: Center(
              child: Image(
                image: AssetImage('assets/img/DoAble.png'),
                height: 150,
                width: 150,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
