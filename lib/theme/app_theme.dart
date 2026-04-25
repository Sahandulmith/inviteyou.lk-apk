import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Wedding color palette - Elegant Sapphire & Gold
  static const Color rosePrimary = Color(0xFF0F172A); // Deep Sapphire
  static const Color roseLight = Color(0xFF334155); // Lighter Sapphire
  static const Color roseDark = Color(0xFF020617); // Dark Sapphire
  static const Color champagne = Color(0xFFF8FAFC); // Slate 50
  static const Color ivory = Color(0xFFF1F5F9); // Slate 100
  static const Color gold = Color(0xFFD4AF37); // Metallic Gold
  static const Color textDark = Color(0xFF0F172A); // Dark Slate
  static const Color textMid = Color(0xFF475569); // Mid Slate
  static const Color surface = Color(0xFFFFFFFF); // White
  static const Color cardBg = Color(0xFFFFFFFF); // Clean White
  
  // Role colors
  static const Color groomBlue = Color(0xFF2196F3);
  static const Color bridePink = Color(0xFFE91E63);

  // Status colors
  static const Color attending = Color(0xFF4CAF50);
  static const Color pending = Color(0xFFFF9800);
  static const Color declined = Color(0xFFF44336);
  static const Color invited = Color(0xFF2196F3);

  static ThemeData get theme {
    return _buildTheme(Brightness.light);
  }

  static ThemeData get darkTheme {
    return _buildTheme(Brightness.dark);
  }

  static ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    
    final Color primaryColor = isDark ? gold : rosePrimary;
    final Color scaffoldBg = isDark ? const Color(0xFF0F172A) : ivory;
    final Color cardColor = isDark ? const Color(0xFF1E293B) : surface;
    final Color textColor = isDark ? Colors.white : textDark;
    final Color textSecondary = isDark ? const Color(0xFF94A3B8) : textMid;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: rosePrimary,
        brightness: brightness,
        primary: primaryColor,
        secondary: gold,
        surface: cardColor,
        background: scaffoldBg,
        onSurface: textColor,
        onBackground: textColor,
      ),
      textTheme: GoogleFonts.playfairDisplayTextTheme(
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
      ).copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
            fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
        displayMedium: GoogleFonts.playfairDisplay(
            fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
        titleLarge: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
        titleMedium: GoogleFonts.inter(
            fontSize: 16, fontWeight: FontWeight.w500, color: textColor),
        bodyLarge: GoogleFonts.inter(fontSize: 14, color: textColor),
        bodyMedium: GoogleFonts.inter(fontSize: 13, color: textSecondary),
        labelLarge: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1E293B) : rosePrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: isDark ? 0 : 2,
        shadowColor: rosePrimary.withOpacity(0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF334155).withOpacity(0.2) : cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white24 : roseLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white24 : roseLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? gold : rosePrimary, width: 2),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? gold : rosePrimary,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle:
              GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        indicatorColor: primaryColor.withOpacity(0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryColor);
          }
          return IconThemeData(color: textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor);
          }
          return GoogleFonts.inter(fontSize: 12, color: textSecondary);
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      scaffoldBackgroundColor: scaffoldBg,
    );
  }
}
