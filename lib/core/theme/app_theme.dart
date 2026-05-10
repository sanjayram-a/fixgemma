import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palette ────────────────────────────────────────────────────────────────
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);

  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate400 = Color(0xFF94A3B8);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate50  = Color(0xFFF8FAFC);

  static const green400 = Color(0xFF34D399);
  static const green500 = Color(0xFF10B981);
  static const red400   = Color(0xFFF87171);
  static const red500   = Color(0xFFEF4444);

  // ── Text Styles ────────────────────────────────────────────────────────────
  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge:  GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: primary),
      displayMedium: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w700, color: primary),
      displaySmall:  GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: primary),
      headlineMedium: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: primary),
      headlineSmall:  GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: primary),
      titleLarge:  GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
      titleMedium: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500, color: primary),
      titleSmall:  GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: secondary),
      bodyLarge:   GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w400, color: primary),
      bodyMedium:  GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: primary),
      bodySmall:   GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w400, color: secondary),
      labelLarge:  GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      labelSmall:  GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: secondary),
    );
  }

  // ── Dark Theme (default) ───────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary:    amber400,
      onPrimary:  slate900,
      secondary:  amber600,
      surface:    slate900,
      onSurface:  slate100,
      surfaceContainerHighest: slate800,
      error:      red400,
      onError:    slate900,
    ),
    scaffoldBackgroundColor: slate900,
    textTheme: _buildTextTheme(slate100, slate400),
    appBarTheme: AppBarTheme(
      backgroundColor: slate900,
      foregroundColor: slate100,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 20, fontWeight: FontWeight.w700, color: slate100),
    ),
    cardTheme: CardThemeData(
      color: slate800,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: slate700, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: slate900,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: slate700, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: slate800,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: slate700),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: slate700),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: amber400, width: 1.5),
      ),
      hintStyle: GoogleFonts.outfit(color: slate400, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: amber400,
        foregroundColor: slate900,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: amber400,
        foregroundColor: slate900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: amber400,
        side: const BorderSide(color: amber400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: slate400),
    ),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      textColor: slate100,
      iconColor: slate400,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? slate900 : slate400),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? amber400 : slate700),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: amber400,
      thumbColor: amber400,
      inactiveTrackColor: slate700,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: slate800,
      contentTextStyle: GoogleFonts.outfit(color: slate100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: slate800,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: amber400),
  );
}
