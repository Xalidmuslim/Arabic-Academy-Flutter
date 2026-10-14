import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// Day/night rendering, without changing the established warm day palette.
ThemeData academyTheme({required bool dark, required String latinFont}) {
  final base = DesignTokens.theme();
  final bg = dark ? const Color(0xFF1C2421) : DesignTokens.ivory;
  final ink = dark ? const Color(0xFFF2F2EB) : DesignTokens.ink;
  final surface = dark ? const Color(0xFF2B3630) : DesignTokens.cardSurface;
  final edge = dark ? const Color(0xFF526457) : DesignTokens.softOutline;
  final scheme = base.colorScheme.copyWith(
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: dark ? const Color(0xFFBBD5A9) : DesignTokens.deepOlive,
    onPrimary: dark ? const Color(0xFF1B2B20) : Colors.white,
    surface: surface, onSurface: ink, outline: edge,
    onSurfaceVariant: dark ? const Color(0xFFCCD6CB) : DesignTokens.secondary,
    surfaceContainerHighest: dark ? const Color(0xFF425047) : DesignTokens.beige,
    onSecondaryContainer: ink,
    secondary: dark ? const Color(0xFFD0C4A9) : DesignTokens.bronze,
  );
  return base.copyWith(
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    dividerColor: edge,
    iconTheme: IconThemeData(color: dark ? const Color(0xFFD5E2D1) : DesignTokens.deepOlive),
    listTileTheme: ListTileThemeData(
      iconColor: dark ? const Color(0xFFCADCC0) : DesignTokens.deepOlive,
      textColor: ink,
      subtitleTextStyle: TextStyle(fontFamily: latinFont, fontSize: 12.5,
        color: dark ? const Color(0xFFCAD3C6) : DesignTokens.secondary),
    ),
    cardTheme: CardThemeData(color: surface, surfaceTintColor: Colors.transparent),
    dialogTheme: DialogThemeData(backgroundColor: surface,
      titleTextStyle: TextStyle(color: ink, fontFamily: latinFont,
        fontSize: 19, fontWeight: FontWeight.w700)),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface,
      modalBackgroundColor: surface),
    popupMenuTheme: PopupMenuThemeData(color: surface,
      textStyle: TextStyle(color: ink, fontFamily: latinFont)),
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
    textButtonTheme: dark
        ? TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: ink))
        : base.textButtonTheme,
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
