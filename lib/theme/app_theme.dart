import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KidsPalette {
  static const cream = Color(0xFFFFFAE8);
  static const paper = Color(0xFFFFFDF4);
  static const sage = Color(0xFF697C58);
  static const olive = Color(0xFF967E58);
  static const ink = Color(0xFF3B2017);
  static const cocoa = Color(0xFF3F2118);
  static const cocoaSoft = Color(0xFF684235);
  static const butter = Color(0xFFFFEDBC);
  static const lemon = Color(0xFFFFD86B);
  static const coral = Color(0xFFE94B3C);
  static const mint = Color(0xFFDCEEC8);
  static const apricot = Color(0xFFF7C58D);
  static const line = Color(0xFFF0E6C9);
}

ThemeData buildKidsTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: KidsPalette.sage,
    brightness: Brightness.light,
  ).copyWith(
    primary: KidsPalette.sage,
    onPrimary: Colors.white,
    primaryContainer: KidsPalette.butter,
    onPrimaryContainer: KidsPalette.ink,
    secondary: KidsPalette.cocoa,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFF0E3C3),
    onSecondaryContainer: KidsPalette.ink,
    tertiary: KidsPalette.apricot,
    onTertiary: KidsPalette.ink,
    tertiaryContainer: const Color(0xFFFFE2AE),
    surface: KidsPalette.paper,
    onSurface: KidsPalette.ink,
    surfaceContainerLowest: KidsPalette.cream,
    surfaceContainerLow: const Color(0xFFF4ECD7),
    surfaceContainer: const Color(0xFFEFE4C8),
    surfaceContainerHigh: const Color(0xFFE7D8B8),
    outline: const Color(0xFFD1C19E),
    outlineVariant: KidsPalette.line,
  );

  final textTheme = GoogleFonts.notoSansKrTextTheme().copyWith(
    displaySmall: GoogleFonts.poorStory(
      color: KidsPalette.cocoa,
      fontSize: 43,
      fontWeight: FontWeight.w400,
      height: 1.02,
    ),
    titleLarge: GoogleFonts.poorStory(
      color: KidsPalette.cocoa,
      fontSize: 27,
      fontWeight: FontWeight.w400,
    ),
    titleMedium: GoogleFonts.poorStory(
      color: KidsPalette.cocoa,
      fontSize: 22,
      fontWeight: FontWeight.w400,
    ),
    bodyLarge: GoogleFonts.notoSansKr(
      color: KidsPalette.ink,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    bodyMedium: GoogleFonts.notoSansKr(
      color: KidsPalette.ink,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    labelLarge: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: KidsPalette.cream,
    useMaterial3: true,
    textTheme: textTheme,
    fontFamily: GoogleFonts.notoSansKr().fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: KidsPalette.cocoa,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.poorStory(
        color: KidsPalette.cocoa,
        fontSize: 27,
        fontWeight: FontWeight.w400,
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: KidsPalette.cocoa,
      unselectedLabelColor: KidsPalette.olive,
      indicatorColor: KidsPalette.cocoa,
      labelStyle: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
      unselectedLabelStyle: GoogleFonts.notoSansKr(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: KidsPalette.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: KidsPalette.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: KidsPalette.cocoa,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KidsPalette.cocoa,
        side: const BorderSide(color: KidsPalette.cocoa, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF2E5C6),
      selectedColor: KidsPalette.butter,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: const TextStyle(
        color: KidsPalette.ink,
        fontWeight: FontWeight.w800,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KidsPalette.paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: KidsPalette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: KidsPalette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: KidsPalette.sage, width: 1.5),
      ),
    ),
    dividerTheme: const DividerThemeData(color: KidsPalette.line, space: 32),
  );
}
