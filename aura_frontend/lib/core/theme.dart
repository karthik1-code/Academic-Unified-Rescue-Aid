import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuraColors {
  static const Color background = Color(0xFF090714);
  static const Color cardBg = Color(0x1F1C1830);
  static const Color cardBorder = Color(0x228A2387);
  
  static const Color primary = Color(0xFF00F0FF);      // Neon Cyber Cyan
  static const Color secondary = Color(0xFFB5179E);    // Neon Magenta
  static const Color accent = Color(0xFF7209B7);       // Deep Purple
  static const Color text = Color(0xFFF1F1F7);
  static const Color textMuted = Color(0xFF8B88A5);
  
  static const Color present = Color(0xFF00F5D4);     // Pastel Mint Green
  static const Color absent = Color(0xFFFF5470);      // Soft Red
  static const Color leave = Color(0xFFFFD166);       // Warm Yellow
  
  static const Gradient auroraGradient = LinearGradient(
    colors: [Color(0xFF7209B7), Color(0xFFB5179E), Color(0xFF00F0FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient glassGradient = LinearGradient(
    colors: [Color(0x15FFFFFF), Color(0x05FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AuraTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AuraColors.background,
      primaryColor: AuraColors.primary,
      hintColor: AuraColors.accent,
      cardColor: AuraColors.cardBg,
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme.apply(
          bodyColor: AuraColors.text,
          displayColor: AuraColors.text,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: AuraColors.primary,
        secondary: AuraColors.secondary,
        surface: AuraColors.cardBg,
        background: AuraColors.background,
      ),
    );
  }

  static BoxDecoration glassDecoration({
    double borderRadius = 16.0,
    Color borderColor = AuraColors.cardBorder,
  }) {
    return BoxDecoration(
      color: AuraColors.cardBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor.withOpacity(0.25),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 12,
          offset: const Offset(0, 4),
        )
      ],
    );
  }
}
