import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── New Blue Palette ───────────────────────────────────────────────────────
  static const primary   = Color(0xFF0784B5); // rgba(7,132,181)
  static const secondary = Color(0xFF39ACE7); // rgba(57,172,231)
  static const tertiary  = Color(0xFF9BD4E4); // rgba(155,212,228)
  static const bgColor   = Color(0xFFD6EEF5); // light pale blue bg
  static const surface   = Color(0xFFFFFFFF); // white surfaces/cards

  // Text on surface
  static const onSurface    = Color(0xFF1A2D3D);
  static const onSurfaceSub = Color(0xFF4A6B7C);

  // Status colours (kept for compatibility)
  static const green400 = Color(0xFF34D399);
  static const red400   = Color(0xFFF87171);
  static const red500   = Color(0xFFEF4444);

  // ── Frosted Glass helpers ──────────────────────────────────────────────────
  static const frostedBg     = Color(0x99FFFFFF);  // 60% white
  static const frostedBorder = Color(0x66FFFFFF);  // 40% white border

  // ── Text Styles ─────────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge:   GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: onSurface),
      displayMedium:  GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w700, color: onSurface),
      displaySmall:   GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: onSurface),
      headlineMedium: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: onSurface),
      headlineSmall:  GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: onSurface),
      titleLarge:   GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: onSurface),
      titleMedium:  GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500, color: onSurface),
      titleSmall:   GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: onSurfaceSub),
      bodyLarge:    GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w400, color: onSurface),
      bodyMedium:   GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: onSurface),
      bodySmall:    GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w400, color: onSurfaceSub),
      labelLarge:   GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
      labelSmall:   GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: onSurfaceSub),
    );
  }

  // ── Light Theme ─────────────────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary:    primary,
      onPrimary:  surface,
      secondary:  secondary,
      onSecondary: surface,
      tertiary:   tertiary,
      surface:    surface,
      onSurface:  onSurface,
      error:      red400,
    ),
    scaffoldBackgroundColor: bgColor,
    textTheme: _buildTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.w700, color: onSurface),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 2,
      shadowColor: primary.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: tertiary.withValues(alpha: 0.5), width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: tertiary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: tertiary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      hintStyle: GoogleFonts.outfit(color: onSurfaceSub, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: surface,
        elevation: 3,
        shadowColor: primary.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? surface : onSurfaceSub),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? primary : tertiary),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: primary,
      thumbColor: primary,
      inactiveTrackColor: tertiary,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: onSurface,
      contentTextStyle: GoogleFonts.outfit(color: surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(color: tertiary.withValues(alpha: 0.5), thickness: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
  );
}
