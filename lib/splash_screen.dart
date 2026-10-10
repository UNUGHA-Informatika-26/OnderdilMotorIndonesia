import 'dart:async';
import 'package:flutter/material.dart';

/// Splash screen sederhana yang muncul tiap kali aplikasi dibuka,
/// lalu otomatis pindah ke [next] setelah beberapa detik.
/// Belum pakai logo khusus — pakai ikon bawaan dulu.
class SplashScreen extends StatefulWidget {
  final Widget next;
  const SplashScreen({super.key, required this.next});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.next),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.two_wheeler, size: 80, color: scheme.onPrimary),
            const SizedBox(height: 16),
            Text(
              'OEM Parts Catalog',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 28),
            CircularProgressIndicator(color: scheme.onPrimary),
          ],
        ),
      ),
    );
  }
}