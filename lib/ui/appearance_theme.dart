import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Day/night rendering, without changing the established warm day palette.
ThemeData academyTheme({required bool dark, required String latinFont}) {
  final base = DesignTokens.theme();
  final bg = dark ? const Color(0xFF202B25) : DesignTokens.ivory;
  final ink = dark ? const Color(0xFFE9F1E7) : DesignTokens.ink;
  final surface = dark ? const Color(0xFF29372E) : DesignTokens.cardSurface;
  final edge = dark ? const Color(0xFF435848) : DesignTokens.softOutline;
  final scheme = base.colorScheme.copyWith(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: dark ? const Color(0xFFB1CA9F) : DesignTokens.deepOlive,
    onPrimary: dark ? const Color(0xFF1B2B20) : Colors.white,
    surface: bg, onSurface: ink, outline: edge,
  );
  return base.copyWith(
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: base.textTheme.apply(
      fontFamily: latinFont, bodyColor: ink, displayColor: ink),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: bg, foregroundColor: ink,
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        color: ink, fontFamily: latinFont),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: edge),
      ),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: bg,
      indicatorColor: dark ? const Color(0xFF435A3D) : const Color(0xFFDDE3CB),
      labelTextStyle: WidgetStateProperty.all(TextStyle(
        fontFamily: latinFont, fontSize: 11,
        fontWeight: FontWeight.w600, color: ink)),
    ),
    filledButtonTheme: dark
        ? FilledButtonThemeData(style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8DA978),
            foregroundColor: const Color(0xFF18251D),
            minimumSize: const Size(48, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          ))
        : base.filledButtonTheme,
    outlinedButtonTheme: dark
        ? OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
            foregroundColor: ink, side: BorderSide(color: edge)))
        : base.outlinedButtonTheme,
  );
}

class ReadingFontScope extends InheritedWidget {
  const ReadingFontScope({
    super.key, required this.arabicFamily, required super.child,
  });
  final String arabicFamily;
  static String arabicFontOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReadingFontScope>()
          ?.arabicFamily ?? 'NotoNaskhArabic';
  @override
  bool updateShouldNotify(ReadingFontScope oldWidget) =>
      oldWidget.arabicFamily != arabicFamily;
}
