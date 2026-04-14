import 'package:flutter/material.dart';

class ChatTheme {
  static const Color background = Color(0xFF0B0D13);
  static const Color surface = Color(0xFF161922);
  static const Color primary = Color(0xFF00E676); // Advanced Neon Green
  static const Color accent = Color(0xFF2979FF);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8E9297);
  
  static const Color senderBubble = Color(0xFF005C4B);
  static const Color receiverBubble = Color(0xFF20232C);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: accent,
      surface: surface,
      onSurface: textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: textSecondary),
    ),
  );
}
