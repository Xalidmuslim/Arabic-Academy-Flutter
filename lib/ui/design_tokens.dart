import 'package:flutter/material.dart';

abstract final class DesignTokens {
  static const ivory = Color(0xFFF8F4E8);
  static const beige = Color(0xFFEADFCB);
  static const sand = Color(0xFFD6C8AE);
  static const sage = Color(0xFFA7A68D);
  static const olive = Color(0xFF5F7A47);
  static const deepOlive = Color(0xFF3E5B33);
  static const emerald = Color(0xFF234A3A);
  static const bronze = Color(0xFF8B6F47);
  static const gold = Color(0xFFC9A06B);
  static const ink = Color(0xFF27382D);
  static const secondary = Color(0xFF746B5A);
  static const radius = 22.0;
  static const buttonRadius = 24.0;
  static const cardPadding = 16.0;
  static const minimumTarget = 48.0;
  static const shadows = [
    BoxShadow(color: Color(0x76FFFFFF), offset: Offset(-2, -2), blurRadius: 7),
    BoxShadow(
      color: Color(0x485A4A36),
      offset: Offset(3, 5),
      blurRadius: 6,
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x225A4A36),
      offset: Offset(0, 12),
      blurRadius: 19,
      spreadRadius: -5,
    ),
  ];

  static ThemeData theme() => ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    fontFamilyFallback: const ['NotoNaskhArabic'],
    scaffoldBackgroundColor: ivory,
    colorScheme: ColorScheme.fromSeed(
      seedColor: olive,
      primary: deepOlive,
      secondary: bronze,
      surface: ivory,
      onSurface: ink,
      onPrimary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ivory,
      foregroundColor: emerald,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        color: ink,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        fontVariations: [FontVariation('wght', 800)],
      ),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        fontVariations: [FontVariation('wght', 800)],
        color: emerald,
      ),
      headlineSmall: TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w800,
        fontVariations: [FontVariation('wght', 800)],
        color: emerald,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        fontVariations: [FontVariation('wght', 800)],
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontVariations: [FontVariation('wght', 700)],
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        color: ink,
        fontVariations: [FontVariation('wght', 400)],
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        color: ink,
        fontVariations: [FontVariation('wght', 400)],
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: secondary,
        fontVariations: [FontVariation('wght', 400)],
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: olive,
        elevation: 3,
        shadowColor: const Color(0x66475637),
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontFamilyFallback: ['NotoNaskhArabic'],
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontVariations: [FontVariation('wght', 700)],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: deepOlive,
        side: const BorderSide(color: sand),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFFCF4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: sand),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: sand),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ivory,
      indicatorColor: const Color(0xFFDDE3CB),
      height: 68,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(
          fontFamily: 'Manrope',
          color: ink,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          fontVariations: [FontVariation('wght', 600)],
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ivory,
      selectedColor: olive,
      side: const BorderSide(color: sand),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
