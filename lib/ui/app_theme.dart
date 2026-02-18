import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Soft Luxury Theme - VOGUE.AI Style
/// Exact colors from reference design
class AppTheme {
  // VOGUE.AI Color Palette (exact match)
  static const _creamBackground = Color(0xFFF5F1ED); // Warm cream background
  static const _pureWhite = Color(0xFFFFFFFF); // Pure white cards
  static const _charcoal = Color(0xFF2C2C2C); // Primary text
  static const _softBrown = Color(0xFF8B7355); // Secondary text
  static const _goldAccent = Color(0xFFC9A86A); // Gold accent
  static const _lightGray = Color(0xFFE5E5E5); // Borders

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      
      // Color Scheme - VOGUE.AI
      colorScheme: ColorScheme.light(
        primary: _charcoal,
        secondary: _goldAccent,
        surface: _pureWhite,
        background: _creamBackground,
        onPrimary: _pureWhite,
        onSecondary: _charcoal,
        onSurface: _charcoal,
        onBackground: _charcoal,
      ),

      scaffoldBackgroundColor: _creamBackground,

      // Typography - Elegant Serif + Modern Sans
      textTheme: TextTheme(
        displayLarge: GoogleFonts.playfairDisplay(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: _charcoal,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.playfairDisplay(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: _charcoal,
        ),
        titleLarge: GoogleFonts.playfairDisplay(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: _charcoal,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _charcoal,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: _charcoal,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: _softBrown,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: _softBrown,
        ),
      ),

      // Card Theme - Pure white with soft shadows
      cardTheme: CardThemeData(
        color: _pureWhite,
        elevation: 0,
        shadowColor: _softBrown.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: _creamBackground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _charcoal,
        ),
        iconTheme: const IconThemeData(color: _charcoal),
      ),

      // Elevated Button - VOGUE.AI style
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _charcoal,
          foregroundColor: _pureWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // Filled Button - Same as Elevated
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _charcoal,
          foregroundColor: _pureWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _pureWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _lightGray, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _lightGray, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _goldAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _pureWhite,
        selectedItemColor: _charcoal,
        unselectedItemColor: _softBrown.withOpacity(0.5),
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        elevation: 0,
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _charcoal,
        foregroundColor: _pureWhite,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Premium Transitions (iOS Slide style on all platforms)
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}