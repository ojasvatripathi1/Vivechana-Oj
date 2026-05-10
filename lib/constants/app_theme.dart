import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // Light Mode Preferences
  static const Color lightScaffoldBg = AppColors.backgroundLight;
  static const Color lightCardBg = AppColors.cardLight;
  static const Color lightPrimaryText = AppColors.textPrimaryLight;
  static const Color lightSecondaryText = AppColors.textSecondaryLight;

  // Dark Mode Colors
  static const Color darkScaffoldBg   = Color(0xFF121212);
  static const Color darkCardBg       = Color(0xFF1E1E1E);
  static const Color darkSurfaceBg    = Color(0xFF2A2A2A);
  static const Color darkPrimaryText  = Color(0xFFEEEEEE);
  static const Color darkSecondaryText = Color(0xFF9E9E9E);
  static const Color darkDivider      = Color(0xFF333333);

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightScaffoldBg,
    primaryColor: AppColors.primaryLight,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: AppColors.primaryLight,
      foregroundColor: Colors.white,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: lightCardBg,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    colorScheme: ColorScheme.light(
      primary: AppColors.primaryLight,
      secondary: AppColors.accentOrange,
      surface: lightCardBg,
      error: AppColors.primaryRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightPrimaryText,
      onError: Colors.white,
    ),
    dividerColor: AppColors.dividerLight,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: lightPrimaryText),
      bodyMedium: TextStyle(color: lightPrimaryText),
      bodySmall: TextStyle(color: lightSecondaryText),
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkScaffoldBg,
    primaryColor: AppColors.primaryLight,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: Color(0xFF1A0000),
      foregroundColor: Colors.white,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: darkCardBg,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    colorScheme: ColorScheme.dark(
      primary: AppColors.primaryLight,
      secondary: AppColors.accentOrange,
      surface: darkCardBg,
      error: AppColors.primaryRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: darkPrimaryText,
      onError: Colors.white,
    ),
    dividerColor: darkDivider,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: darkPrimaryText),
      bodyMedium: TextStyle(color: darkPrimaryText),
      bodySmall: TextStyle(color: darkSecondaryText),
    ),
  );
}

