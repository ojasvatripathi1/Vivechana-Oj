import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class DesignTokens {
  // ── Brand Colors ────────────────────────────────────────────────
  static const Color primary      = AppColors.primaryDark;
  static const Color primaryDark  = AppColors.primaryDark;
  static const Color primaryLight = AppColors.primaryLight;
  static const Color secondary    = AppColors.accentOrange;
  static const Color accent       = AppColors.accentOrange;
  static const Color error        = AppColors.primaryRed;

  // Surface (use Theme.of(context).cardColor instead in widgets)
  static const Color surface    = AppColors.cardLight;
  static const Color onPrimary  = Colors.white;
  static const Color onSurface  = AppColors.textPrimaryLight;
  static const Color textPrimary = AppColors.textPrimaryLight;

  // Dark mode surfaces
  static const Color darkSurface    = Color(0xFF1E1E1E);
  static const Color darkScaffold   = Color(0xFF121212);

  // ── Spacing ─────────────────────────────────────────────────────
  static const double spacing4  = 4.0;
  static const double spacing8  = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;

  // ── Typography ──────────────────────────────────────────────────
  static const TextStyle displayMedium = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: -0.5,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimaryLight,
    height: 1.2,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimaryLight,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.35,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimaryLight,
    height: 1.7,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryLight,
    height: 1.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondaryLight,
    letterSpacing: 0.3,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
  );

  // ── Border Radius ───────────────────────────────────────────────
  static const double borderRadiusSmall  = 8.0;
  static const double borderRadiusMedium = 14.0;
  static const double borderRadiusLarge  = 20.0;
  static const double borderRadiusXL     = 28.0;

  // ── Elevation ───────────────────────────────────────────────────
  static const double elevationSmall  = 2.0;
  static const double elevationMedium = 6.0;
  static const double elevationLarge  = 12.0;

  // ── Helpers ─────────────────────────────────────────────────────
  static Color textPrimaryOn(bool isDark) =>
      isDark ? const Color(0xFFEEEEEE) : AppColors.textPrimaryLight;

  static Color textSecondaryOn(bool isDark) =>
      isDark ? const Color(0xFF9E9E9E) : AppColors.textSecondaryLight;

  static Color cardColorOn(bool isDark) =>
      isDark ? const Color(0xFF1E1E1E) : AppColors.cardLight;

  static Color scaffoldOn(bool isDark) =>
      isDark ? const Color(0xFF121212) : AppColors.backgroundLight;

  static Color dividerOn(bool isDark) =>
      isDark ? const Color(0xFF333333) : AppColors.dividerLight;

  /// Resolve isDark directly from a widget's BuildContext
  static bool isDarkContext(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}
