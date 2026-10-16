import 'package:flutter/material.dart';

class AppColors {
  // Japanese traditional color inspirations
  static const Color primary = Color(0xFFC0392B); // Vermilion / Shinku / Crimson
  static const Color primaryLight = Color(0xFFE74C3C);
  static const Color primaryDark = Color(0xFF962D22);

  static const Color strokeCorrect = Color(0xFF2E7D32); // Lush green
  static const Color strokeCorrectBg = Color(0xFFE8F5E9);
  static const Color strokeWrong = Color(0xFFC62828);   // Vivid red
  static const Color strokeWrongBg = Color(0xFFFFEBEE);
  static const Color strokeHint = Color(0xFFF57F17);    // Amber gold
  static const Color strokeTrace = Color(0xFFB0BEC5);   // Subtle blue-grey for trace background

  // Mastery border colors
  static const Color masteryNotStarted = Color(0xFFCFD8DC);
  static const Color masteryPracticing = Color(0xFFFFB300);
  static const Color masteryMastered = Color(0xFF43A047);

  // Canvas background
  static const Color canvasPaperLight = Color(0xFFFAF9F6);
  static const Color canvasPaperDark = Color(0xFF1E1E1E);
  static const Color gridLineLight = Color(0xFFE0D8CE);
  static const Color gridLineDark = Color(0xFF333333);
}

class AppTheme {
  static const String fontFamily = 'Noto Sans JP';

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: const Color(0xFFFDFBF7),
    ),
    scaffoldBackgroundColor: const Color(0xFFF7F5F0),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFDFBF7),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2C3E50),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE8E5DD)),
      ),
      color: Colors.white,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      surface: const Color(0xFF1E1E24),
    ),
    scaffoldBackgroundColor: const Color(0xFF141419),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E24),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 19,
        fontWeight: FontWeight.bold,
        color: Color(0xFFECEFF1),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF2C2C35)),
      ),
      color: const Color(0xFF1E1E24),
    ),
  );
}
