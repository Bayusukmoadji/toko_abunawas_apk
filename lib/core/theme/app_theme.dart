import 'package:flutter/material.dart';

class AppTheme {
  // Warna utama sesuai token Figma
  static const Color primaryGreen = Color(0xFF015816);
  static const Color mediumGreen = Color(0xFF038E1B);
  static const Color lightGreenGradient = Color(0xFF84E977);

  static const Color lightGreenBg = Color(0xFFE8F5E9);
  static const Color background = Color(0xFFF5F5F5); // Sesuai request F5F5F5
  static const Color warning = Color(0xFFFFA000);
  static const Color danger = Color(0xFFD32F2F);

  // Gradasi utama untuk Header dan tombol Logout
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGreen, mediumGreen, lightGreenGradient],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primaryGreen,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: warning,
        error: danger,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0, // Menggunakan shadow manual dari Figma agar presisi
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
    );
  }
}
