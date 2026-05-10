import 'package:flutter/material.dart';

class AppColors {
  // ── Brand Palette ───────────────────────────────────────────────
  /// Deep maroon – headlines, AppBar gradient start
  static const Color primaryDark = Color(0xFF1A0000);
  /// Rich crimson – AppBar gradient end, accent blocks
  static const Color primaryLight = Color(0xFF9B0B1E);
  /// Vivid orange – tags, badges, CTAs
  static const Color accentOrange = Color(0xFFE8501B);
  /// Punchy red – break-news strip, FABs
  static const Color primaryRed = Color(0xFFBF1A2F);

  // ── Backgrounds ─────────────────────────────────────────────────
  /// Light mode scaffold
  static const Color backgroundLight = Color(0xFFF8F5F0);

  // ── Surface / Card ───────────────────────────────────────────────
  static const Color cardLight = Colors.white;

  // ── Text ─────────────────────────────────────────────────────────
  static const Color textPrimaryLight   = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF6B7280);

  // ── Divider / Border ────────────────────────────────────────────
  static const Color dividerLight = Color(0xFFE5E0D8);

  // ── Gradients ───────────────────────────────────────────────────
  static const LinearGradient appbarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primaryLight],
  );

  static const LinearGradient magazineGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primaryRed],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.45, 1.0],
    colors: [
      Colors.transparent,
      Color(0x661A0000),
      Color(0xDD1A0000),
    ],
  );
}
