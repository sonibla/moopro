import 'package:flutter/material.dart';

abstract class AppTheme {
  static const Color _paperLight = Color(0xFFF6F3EC);
  static const Color _paperDark = Color(0xFF000000);
  static const Color _cardLight = Color(0xFFFFFFFF);
  static const Color _cardDark = Color(0xFF262320);
  static const Color _inkLight = Color(0xFF1B2333);
  static const Color _inkDark = Color(0xFFEDE8DD);
  static const Color _inkSoftLight = Color(0xFF726C5E);
  static const Color _inkSoftDark = Color(0xFFB7AFA0);
  static const Color _inkFaintLight = Color(0xFFA39C8A);
  static const Color _inkFaintDark = Color(0xFF8A8172);
  static const Color _lineLight = Color(0xFFE4DFD0);
  static const Color _lineDark = Color(0xFF3A362E);
  static const Color _lineStrongLight = Color(0xFFD3CDB9);
  static const Color _lineStrongDark = Color(0xFF4A4436);
  static const Color _accentLight = Color(0xFF95600F);
  static const Color _accentDark = Color(0xFFD9A44E);
  static const Color _accentSoftLight = Color(0xFFF3E4C3);
  static const Color _accentSoftDark = Color(0xFF4A3B1F);
  static const Color _accentInkLight = Color(0xFF5C3B0F);
  static const Color _accentInkDark = Color(0xFFF3E4C3);

  static Color paper(Brightness b) =>
      b == Brightness.dark ? _paperDark : _paperLight;
  static Color card(Brightness b) =>
      b == Brightness.dark ? _cardDark : _cardLight;
  static Color ink(Brightness b) => b == Brightness.dark ? _inkDark : _inkLight;
  static Color inkSoft(Brightness b) =>
      b == Brightness.dark ? _inkSoftDark : _inkSoftLight;
  static Color inkFaint(Brightness b) =>
      b == Brightness.dark ? _inkFaintDark : _inkFaintLight;
  static Color line(Brightness b) =>
      b == Brightness.dark ? _lineDark : _lineLight;
  static Color lineStrong(Brightness b) =>
      b == Brightness.dark ? _lineStrongDark : _lineStrongLight;
  static Color accent(Brightness b) =>
      b == Brightness.dark ? _accentDark : _accentLight;

  static Color onAccent(Brightness b) =>
      b == Brightness.dark ? _paperDark : Colors.white;
  static Color accentSoft(Brightness b) =>
      b == Brightness.dark ? _accentSoftDark : _accentSoftLight;
  static Color accentInk(Brightness b) =>
      b == Brightness.dark ? _accentInkDark : _accentInkLight;

  static const double cardRadius = 16;
  static const double inputRadius = 10;
  static const double avatarTileRadius = 10;
  static const double spacingUnit = 8;

  static const Color positiveAmountLight = Color(0xFF1F6F5C);
  static const Color positiveAmountDark = Color(0xFF6FBFA4);
  static const Color negativeAmountLight = Color(0xFFB54A34);
  static const Color negativeAmountDark = Color(0xFFE08669);

  static Color positiveAmountColor(Brightness brightness) =>
      brightness == Brightness.dark ? positiveAmountDark : positiveAmountLight;

  static Color negativeAmountColor(Brightness brightness) =>
      brightness == Brightness.dark ? negativeAmountDark : negativeAmountLight;

  static TextStyle amountTextStyle(TextStyle? base) =>
      (base ?? const TextStyle()).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: accent(brightness),
      brightness: brightness,
    );
    final colorScheme = baseScheme.copyWith(
      primary: accent(brightness),
      onPrimary: onAccent(brightness),
      primaryContainer: accentSoft(brightness),
      onPrimaryContainer: accentInk(brightness),
      surface: card(brightness),
      onSurface: ink(brightness),
      onSurfaceVariant: inkSoft(brightness),
      outline: lineStrong(brightness),
      outlineVariant: line(brightness),
      error: negativeAmountColor(brightness),
      onError: Colors.white,
      errorContainer: isDark
          ? const Color(0xFF3C2620)
          : const Color(0xFFF5E4DE),
      onErrorContainer: negativeAmountColor(brightness),
    );

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cardRadius),
    );
    const pillShape = StadiumBorder();
    final buttonStyle = ButtonStyle(
      shape: const WidgetStatePropertyAll(pillShape),
      minimumSize: const WidgetStatePropertyAll(
        Size(64, kMinInteractiveDimension),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: paper(brightness),
      canvasColor: paper(brightness),
      appBarTheme: AppBarThemeData(
        elevation: 0,
        scrolledUnderElevation: 3,
        backgroundColor: paper(brightness),
        foregroundColor: ink(brightness),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: card(brightness),
        shape: cardShape,
        elevation: 3,
        shadowColor: ink(brightness).withValues(alpha: 0.25),
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(
          horizontal: spacingUnit * 2,
          vertical: spacingUnit,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card(brightness),
        shape: cardShape,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card(brightness),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(cardRadius)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: line(brightness),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        shape: cardShape,
        minVerticalPadding: spacingUnit,
        textColor: ink(brightness),
        iconColor: inkSoft(brightness),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: card(brightness),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: lineStrong(brightness)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: lineStrong(brightness)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: BorderSide(color: accent(brightness), width: 2),
        ),
        labelStyle: TextStyle(color: inkSoft(brightness)),
        hintStyle: TextStyle(color: inkFaint(brightness)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingUnit * 2,
          vertical: spacingUnit * 1.5,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonStyle.copyWith(
          side: WidgetStatePropertyAll(
            BorderSide(color: lineStrong(brightness)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent(brightness),
        foregroundColor: onAccent(brightness),
        shape: const CircleBorder(),
      ),
      chipTheme: ChipThemeData(
        shape: pillShape,
        side: BorderSide.none,
        backgroundColor: isDark ? _lineDark : _lineLight,
        selectedColor: accentSoft(brightness),
        labelStyle: TextStyle(color: ink(brightness)),
        secondaryLabelStyle: TextStyle(color: accentInk(brightness)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(pillShape),
          side: WidgetStatePropertyAll(
            BorderSide(color: lineStrong(brightness)),
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: paper(brightness),
        indicatorColor: accentSoft(brightness),
        selectedIconTheme: IconThemeData(color: accentInk(brightness)),
        selectedLabelTextStyle: TextStyle(color: accentInk(brightness)),
        unselectedIconTheme: IconThemeData(color: inkSoft(brightness)),
        unselectedLabelTextStyle: TextStyle(color: inkSoft(brightness)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card(brightness),
        indicatorColor: accentSoft(brightness),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
