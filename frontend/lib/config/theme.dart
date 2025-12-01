import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Palette Colori "Dark FinTech"
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color primaryGreen = Color(0xFF00E676); // Ricchezza
  static const Color accentBlue = Color(0xFF2979FF);   // Salute/Scienza
  static const Color errorRed = Color(0xFFCF6679);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;

  // Definizione del Tema Globale
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primaryGreen,
      
      // Configurazione Colori
      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: accentBlue,
        surface: surface,
        error: errorRed,
        background: background,
      ),

      // Configurazione Testi (Google Fonts)
      textTheme: TextTheme(
        displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
        displayMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: textSecondary),
      ),

      // Stile Bottoni
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.black,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),

      // Stile App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18, 
          fontWeight: FontWeight.bold, 
          letterSpacing: 1.5,
          color: textPrimary
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
    );
  }
}