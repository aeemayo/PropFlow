import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// PropFlow design system — premium dark theme with gold/teal accents.
class AppTheme {
  AppTheme._();

  // ── Brand Colors ──
  static const Color primary = Color(0xFF00C9A7); // Teal accent
  static const Color primaryDark = Color(0xFF00A88A);
  static const Color secondary = Color(0xFFFFD700); // Gold
  static const Color secondaryLight = Color(0xFFFFF3CD);

  // ── Surface Colors ──
  static const Color background = Color(0xFF0A0E17);
  static const Color surface = Color(0xFF121829);
  static const Color surfaceLight = Color(0xFF1A2235);
  static const Color surfaceCard = Color(0xFF1E2740);

  // ── Text Colors ──
  static const Color textPrimary = Color(0xFFF5F5F8);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // ── Status Colors ──
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Gradient ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00C9A7), Color(0xFF0891B2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E2740), Color(0xFF121829)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Theme Data ──
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: secondary,
          surface: surface,
          error: error,
          onPrimary: Color(0xFF0A0E17),
          onSecondary: Color(0xFF0A0E17),
          onSurface: textPrimary,
          onError: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
            .copyWith(
              headlineLarge: GoogleFonts.spaceGrotesk(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: textPrimary,
                letterSpacing: -0.5,
              ),
              headlineMedium: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
              headlineSmall: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
              titleLarge: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
              titleMedium: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
              bodyLarge: GoogleFonts.inter(
                fontSize: 16,
                color: textSecondary,
              ),
              bodyMedium: GoogleFonts.inter(
                fontSize: 14,
                color: textSecondary,
              ),
              bodySmall: GoogleFonts.inter(
                fontSize: 12,
                color: textMuted,
              ),
              labelLarge: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
        appBarTheme: AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          iconTheme: const IconThemeData(color: textPrimary),
        ),
        cardTheme: CardThemeData(
          color: surfaceCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2A3352), width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: const Color(0xFF0A0E17),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: primary, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A3352)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2A3352)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: error),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: GoogleFonts.inter(color: textMuted),
          hintStyle: GoogleFonts.inter(color: textMuted),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: primary,
          unselectedItemColor: textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF2A3352),
          thickness: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: surfaceCard,
          contentTextStyle: GoogleFonts.inter(color: textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

  // ── Decoration helpers ──

  static BoxDecoration get glassCard => BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A3352).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration get accentCard => BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2A2A), Color(0xFF0A1628)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      );
}
