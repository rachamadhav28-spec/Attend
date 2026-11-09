import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two brand colors: ink (#18251D) and lime (#B7FF72).
/// Everything else is a tint of those two.
class Pal {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color text;
  final Color muted;
  final Color line;
  final Color accent;
  final Color onAccent;
  final Color good;
  final Color onGood;
  final Color bad;
  final Color onBad;
  final Color hero;
  final Color onHero;
  final Color heroMuted;
  final Color heroAccent;

  const Pal({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.text,
    required this.muted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.good,
    required this.onGood,
    required this.bad,
    required this.onBad,
    required this.hero,
    required this.onHero,
    required this.heroMuted,
    required this.heroAccent,
  });

  static const Color ink = Color(0xFF18251D);
  static const Color lime = Color(0xFFB7FF72);

  static const Pal light = Pal(
    bg: Color(0xFFF3F6EF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE8EFE2),
    text: ink,
    muted: Color(0xFF5B685F),
    line: Color(0xFFDCE4D6),
    accent: ink,
    onAccent: lime,
    good: Color(0xFF2E7D4F),
    onGood: Color(0xFFFFFFFF),
    bad: Color(0xFFC0392B),
    onBad: Color(0xFFFFFFFF),
    hero: ink,
    onHero: Color(0xFFF1F6EE),
    heroMuted: Color(0xFFA3B1A8),
    heroAccent: lime,
  );

  static const Pal dark = Pal(
    bg: Color(0xFF0E1511),
    surface: ink,
    surfaceAlt: Color(0xFF223229),
    text: Color(0xFFF1F6EE),
    muted: Color(0xFFA3B1A8),
    line: Color(0xFF2C3C33),
    accent: lime,
    onAccent: ink,
    good: lime,
    onGood: ink,
    bad: Color(0xFFFF8A80),
    onBad: ink,
    hero: Color(0xFF223229),
    onHero: Color(0xFFF1F6EE),
    heroMuted: Color(0xFFA3B1A8),
    heroAccent: lime,
  );

  static Pal of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class AppTheme {
  static ThemeData get lightTheme => _build(Pal.light, Brightness.light);
  static ThemeData get darkTheme => _build(Pal.dark, Brightness.dark);

  static ThemeData _build(Pal p, Brightness b) {
    final shape14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Pal.ink,
        brightness: b,
      ).copyWith(
        primary: p.accent,
        onPrimary: p.onAccent,
        surface: p.surface,
        onSurface: p.text,
        error: p.bad,
      ),
      scaffoldBackgroundColor: p.bg,
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          minimumSize: const Size(0, 48),
          shape: shape14,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: p.line),
          shape: shape14,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.text,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.text, width: 2),
        ),
        hintStyle: TextStyle(color: p.muted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceAlt,
        selectedColor: p.accent,
        side: BorderSide.none,
        showCheckmark: false,
        labelStyle: TextStyle(fontSize: 12, color: p.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        elevation: 0,
        height: 72,
        indicatorColor: p.accent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return IconThemeData(color: sel ? p.onAccent : p.muted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final sel = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: sel ? p.text : p.muted,
          );
        }),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? p.accent : p.surface),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? p.onAccent : p.text),
          side: WidgetStatePropertyAll(BorderSide(color: p.line)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.text,
        contentTextStyle: TextStyle(color: p.bg, fontSize: 14),
        shape: shape14,
      ),
      dividerTheme: DividerThemeData(color: p.line, space: 24),
    );
  }
}

/// Light / dark choice, picked in Profile and remembered on the phone.
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> loadThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString('theme_mode')) {
      case 'light':
        themeModeNotifier.value = ThemeMode.light;
        break;
      case 'dark':
        themeModeNotifier.value = ThemeMode.dark;
        break;
      default:
        themeModeNotifier.value = ThemeMode.system;
    }
  } catch (_) {}
}

Future<void> saveThemeMode(ThemeMode mode) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  } catch (_) {}
}
