import 'package:flutter/material.dart';

class AppTheme {
  // Light theme colors
  static const Color lightPrimary = Colors.purple;
  static const Color lightBackground = Colors.white;
  static const Color lightSurface = Color(0xFFF5F5F5);
  static const Color lightText = Colors.black;
  static const Color lightTextSecondary = Colors.black87;

  // Dark theme colors
  static const Color darkPrimary = Colors.purpleAccent;
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkText = Colors.white;
  static const Color darkTextSecondary = Colors.white70;

  /// Light Theme Configuration
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: lightPrimary,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: const ColorScheme.light(
      primary: lightPrimary,
      secondary: lightPrimary,
      surface: lightSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: lightText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: lightText),
      titleTextStyle: TextStyle(
        color: lightPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardColor: lightSurface,
    dividerColor: Colors.grey.shade300,
    iconTheme: const IconThemeData(color: lightText),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: lightText, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: lightText, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: lightText, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: lightText, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: lightText, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: lightText),
      bodyMedium: TextStyle(color: lightTextSecondary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black, width: 1.3),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black, width: 1.3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: lightPrimary, width: 2),
      ),
    ),
  );

  /// Dark Theme Configuration
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: darkPrimary,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      secondary: darkPrimary,
      surface: darkSurface,
      onPrimary: darkBackground,
      onSecondary: darkBackground,
      onSurface: darkText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: darkText),
      titleTextStyle: TextStyle(
        color: darkPrimary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardColor: darkSurface,
    dividerColor: Colors.grey.shade700,
    iconTheme: const IconThemeData(color: darkText),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: darkText, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: darkText, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: darkText, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: darkText, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: darkText),
      bodyMedium: TextStyle(color: darkTextSecondary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white54, width: 1.3),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white54, width: 1.3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: darkPrimary, width: 2),
      ),
    ),
  );
}
