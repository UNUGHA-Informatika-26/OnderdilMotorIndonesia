import 'package:flutter/material.dart';

/// Design tokens dan konfigurasi tema aplikasi berdasarkan Figma (app.tsx & index.css).
class AppTheme {
  // Brand Colors (Figma: --red, --red-dark, --tint)
  static const Color red = Color(0xFFD32F2F);
  static const Color redDark = Color(0xFFB71C1C);
  static const Color tint = Color(0xFFFFEBEE);

  // Neutral Colors (Figma: --bg, --surface, --border, --heading, --sub)
  static const Color bg = Color(0xFFF5F5F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE3E3E0);
  static const Color heading = Color(0xFF1A1C1E);
  static const Color sub = Color(0xFF6C757D);

  // Status & Accent Colors (Figma: --green, --green-bg, --amber, --amber-bg, --info)
  static const Color green = Color(0xFF2E7D32);
  static const Color greenBg = Color(0xFFE8F5E9);
  static const Color amber = Color(0xFFA35B00);
  static const Color amberBg = Color(0xFFFFF4DF);
  static const Color info = Color(0xFF315FBD);
  static const Color infoBg = Color(0xFFE8F0FE);

  /// Global ThemeData Material 3 disesuaikan dengan token Figma
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.light(
        primary: red,
        onPrimary: Colors.white,
        primaryContainer: tint,
        onPrimaryContainer: redDark,
        surface: surface,
        onSurface: heading,
        error: red,
        onError: Colors.white,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: heading,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: heading,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: heading),
        shape: Border(
          bottom: BorderSide(color: border, width: 1),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: red,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 42),
          elevation: 0,
          shadowColor: const Color(0x33D32F2F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: heading,
          backgroundColor: surface,
          minimumSize: const Size(double.infinity, 42),
          elevation: 0,
          side: const BorderSide(color: border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: sub, fontSize: 13),
        labelStyle: const TextStyle(color: Color(0xFF4F5357), fontSize: 12, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: red, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: red),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: red,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Helper untuk status pill chip (Menunggu / Selesai / Dibatalkan) sesuai .status di index.css
  static Widget statusBadge(String label, {String type = 'waiting'}) {
    Color bg;
    Color fg;
    switch (type.toLowerCase()) {
      case 'success':
      case 'selesai':
      case 'verifikasi':
        bg = greenBg;
        fg = green;
        break;
      case 'danger':
      case 'dibatalkan':
      case 'tolak':
        bg = tint;
        fg = red;
        break;
      case 'info':
        bg = infoBg;
        fg = info;
        break;
      case 'waiting':
      case 'menunggu':
      default:
        bg = amberBg;
        fg = amber;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// Format angka ke format Rupiah standar Indonesia: Rp 185.000 (sesuai figma app.tsx)
  static String formatRupiah(num price) {
    final str = price.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp $str';
  }
}
