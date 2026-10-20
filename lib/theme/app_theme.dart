import 'package:flutter/material.dart';

/// Centralized theme constants for the SDBS application.
/// All colors, gradients, and reusable styles live here — no more
/// hardcoded hex values scattered across individual widgets.
class AppTheme {
  AppTheme._(); // prevent instantiation

  // ── Brand Colors ───────────────────────────────────────────────
  static const Color maroon = Color(0xFF8B2E4E);
  static const Color maroonLight = Color(0xFFB03060);
  static const Color background = Color(0xFFF5F5F7);

  // Decision Engine Colors
  static const Color stopGreen = Color(0xFF4CAF50);
  static const Color skipRed = Color(0xFFE91E63);
  static const Color earlyAmber = Color(0xFFFFC107);

  // Accent Colors (Quick Actions grid)
  static const Color accentPurple = Color(0xFF6B4EFF);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGreen = Color(0xFF10B981);

  // ── Gradients ──────────────────────────────────────────────────
  static LinearGradient get maroonGradient => const LinearGradient(
        colors: [maroon, maroonLight, Color(0xD98B2E4E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // ── Shared ThemeData ───────────────────────────────────────────
  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        primaryColor: maroon,
        colorScheme: ColorScheme.fromSeed(seedColor: maroon),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: maroon,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      );

  // ── Reusable Input Decoration ──────────────────────────────────
  static InputDecoration inputDecoration(String hint, {Widget? suffixIcon}) =>
      InputDecoration(
        labelText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
      );

  // ── Standard Button Style ──────────────────────────────────────
  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      );
}
