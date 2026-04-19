import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatTheme {
  // Luxurious Champagne & Gold Color Palette
  static const Color background = Color(0xFFFAF9F6); // Soft Linen
  static const Color surface = Color(0xFFFFFFFF);    // Pure White
  static const Color primary = Color(0xFFC5A028);    // Metallic Gold
  static const Color accent = Color(0xFF8E6B15);     // Deep Bronze
  static const Color textPrimary = Color(0xFF1A1A1A); // Onyx Black
  static const Color textSecondary = Color(0xFF6E5E52); // Muted Earth
  
  static const Color senderBubble = Color(0xFFF1E6C5); // Champagne Mist
  static const Color receiverBubble = Color(0xFFFFFFFF); // Pure White

  static ThemeData luxuriousLightSelection = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    brightness: Brightness.light,
    textTheme: GoogleFonts.montserratTextTheme().copyWith(
      displayLarge: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w900, color: textPrimary),
      titleLarge: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: 1.2),
      bodyMedium: GoogleFonts.montserrat(color: textPrimary, fontSize: 15),
      bodySmall: GoogleFonts.montserrat(color: textSecondary, fontSize: 13),
    ),
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: surface,
      onSurface: textPrimary,
      onPrimary: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background.withOpacity(0.8),
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: textPrimary,
        letterSpacing: 1.5,
      ),
      iconTheme: const IconThemeData(color: primary, size: 28),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 8,
      shadowColor: primary.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: 0.5,
      ),
      subtitleTextStyle: GoogleFonts.montserrat(
        fontSize: 13,
        color: textSecondary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: primary, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      hintStyle: GoogleFonts.montserrat(color: textSecondary, fontSize: 14),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 10,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: primary,
      unselectedLabelColor: textSecondary,
      indicatorColor: primary,
      labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w900, letterSpacing: 1.5),
      unselectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
    ),
  );

  static ThemeData get currentTheme => luxuriousLightSelection;
}
