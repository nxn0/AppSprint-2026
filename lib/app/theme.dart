import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xff1e1e2e),
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
    colorScheme: const ColorScheme.dark(
      surface: Color(0xff1e1e2e),
      primary: AppColors.mauve,
      secondary: AppColors.teal,
      onSurface: AppColors.text,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.text, fontSize: 14, height: 1.35),
      bodySmall: TextStyle(color: AppColors.muted, fontSize: 12),
      titleLarge: TextStyle(
        color: AppColors.text,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: AppColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xff181825),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.mauve),
      ),
    ),
  );
}
