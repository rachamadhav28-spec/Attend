// Shared look for AttendTrack: "Premium and bold" (blue).
// Colors, theme, and small animation helpers (all under 300 ms).

import 'dart:math' as _math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Palette {
  final String name;
  final Color primary, primarySoft, ink, muted, bg, tint, line, accent, peach, surface;
  final bool dark;
  const Palette(this.name,
      {this.surface = Colors.white,
      this.dark = false,
      required this.primary,
      required this.primarySoft,
      required this.ink,
      required this.muted,
      required this.bg,
      required this.tint,
      required this.line,
      required this.accent,
      required this.peach});
}

const List<Palette> kPalettes = [
  Palette('Forest & Ivory',
      primary: Color(0xFF1F4A32),
      primarySoft: Color(0xFF356B4C),
      ink: Color(0xFF14291C),
      muted: Color(0xFF5F6F63),
      bg: Color(0xFFF6F1E1),
      tint: Color(0xFFEBE5CF),
      line: Color(0xFFD9D3BD),
      accent: Color(0xFFF6F1E1),
      peach: Color(0xFF9DBB9F)),
];

class AppColors {
  static int index = 0;
  static Palette get _p => kPalettes[index];
  static Color get primary => _p.primary;
  static Color get primarySoft => _p.primarySoft;
  static Color get accent => _p.accent;
  static Color get peach => _p.peach;
  static Color get navy => _p.ink;
  static Color get ink => _p.ink;
  static Color get muted => _p.muted;
  static Color get bg => _p.bg;
  static Color get tint => _p.tint;
  static Color get line => _p.line;
  static Color get surface => _p.surface;
  static bool get isDark => _p.dark;
  static const Color good = Color(0xFF2E6B3A);
  static const Color goodSoft = Color(0xFFE4EFDF);
  static const Color bad = Color(0xFFB3261E);
  static const Color badSoft = Color(0xFFF9E3DC);
}

/// Switch palette, remember it, and repaint the whole app in place.
Future<void> setPalette(int i) async {
  AppColors.index = i;
  try {
    (await SharedPreferences.getInstance()).setInt('palette', i);
  } catch (_) {}
  void mark(Element e) {
    e.markNeedsBuild();
    e.visitChildren(mark);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(mark);
}

Future<void> loadPalette() async {
  try {
    final i = (await SharedPreferences.getInstance()).getInt('palette') ?? 0;
    AppColors.index = 0;
  } catch (_) {}
}

const Duration kFast = Duration(milliseconds: 160);
const Duration kMed = Duration(milliseconds: 260);

bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: AppColors.isDark ? Brightness.dark : Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    );
    final base = ThemeData(brightness: scheme.brightness).textTheme;
    final body = GoogleFonts.interTextTheme(base).apply(
        bodyColor: AppColors.ink, displayColor: AppColors.ink);
    final heads = GoogleFonts.plusJakartaSansTextTheme(base);
    final text = body.copyWith(
      displayLarge: heads.displayLarge?.copyWith(color: AppColors.ink),
      displayMedium: heads.displayMedium?.copyWith(color: AppColors.ink),
      displaySmall: heads.displaySmall?.copyWith(color: AppColors.ink),
      headlineLarge: heads.headlineLarge?.copyWith(
          color: AppColors.ink, fontWeight: FontWeight.w700),
      headlineMedium: heads.headlineMedium?.copyWith(
          color: AppColors.ink, fontWeight: FontWeight.w700),
      headlineSmall: heads.headlineSmall?.copyWith(
          color: AppColors.ink, fontWeight: FontWeight.w700),
      titleLarge: heads.titleLarge?.copyWith(
          color: AppColors.ink, fontWeight: FontWeight.w700),
      titleMedium: heads.titleMedium?.copyWith(
          color: AppColors.ink, fontWeight: FontWeight.w600),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: AppColors.bg,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.line),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
            color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle:
            TextStyle(color: AppColors.muted, fontSize: 14),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.tint,
        side: BorderSide.none,
        labelStyle: TextStyle(fontSize: 13, color: AppColors.ink),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Fade + small slide up. [index] staggers the start (each item moves 260 ms).
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final step = index.clamp(0, 8);
    final total = 260 + step * 50;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, t, child) {
        final p = Interval(step * 50 / total, 1, curve: Curves.easeOutCubic)
            .transform(t);
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, 16 * (1 - p)), child: child),
        );
      },
      child: child,
    );
  }
}

/// Shrinks slightly while a finger is down. Does not take the tap itself.
class PressScale extends StatefulWidget {
  final Widget child;
  const PressScale({super.key, required this.child});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Number that counts to its value.
class CountUp extends StatelessWidget {
  final num value;
  final int decimals;
  final String suffix;
  final TextStyle? style;
  const CountUp({
    super.key,
    required this.value,
    this.decimals = 0,
    this.suffix = '',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) {
      return Text('${value.toStringAsFixed(decimals)}$suffix', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: value.toDouble()),
      duration: kMed,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) =>
          Text('${v.toStringAsFixed(decimals)}$suffix', style: style),
    );
  }
}

/// Round percentage ring that fills smoothly.
class PctRing extends StatelessWidget {
  final double pct;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final TextStyle? textStyle;
  PctRing({
    super.key,
    required this.pct,
    this.size = 112,
    this.stroke = 10,
    Color? color,
    Color? track,
    this.textStyle,
  })  : color = color ?? AppColors.accent,
        track = track ?? AppColors.primarySoft;

  @override
  Widget build(BuildContext context) {
    final target = (pct / 100).clamp(0.0, 1.0);
    final instant = reduceMotion(context);
    return Semantics(
      label: '${pct.toStringAsFixed(0)} percent attendance',
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: target),
          duration: instant ? Duration.zero : const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => CustomPaint(
            painter: _RingPainter(v, stroke, color, track),
            child: Center(
              child: Text('${(v * 100).toStringAsFixed(0)}%', style: textStyle),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  final double stroke;
  final Color color;
  final Color track;
  _RingPainter(this.v, this.stroke, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track
      ..isAntiAlias = true;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color
      ..isAntiAlias = true;
    canvas.drawArc(r, 0, 6.2831853, false, base);
    canvas.drawArc(r, -1.5707963, 6.2831853 * v, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.v != v || old.color != color || old.track != track;
}

/// Thin progress bar that animates.
class AnimatedBar extends StatelessWidget {
  final double value;
  final Color color;
  final Color track;
  final double height;
  AnimatedBar({
    super.key,
    required this.value,
    required this.color,
    Color? track,
    this.height = 6,
  }) : track = track ?? AppColors.line;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: value.clamp(0.0, 1.0)),
        duration: reduceMotion(context) ? Duration.zero : kMed,
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: track,
          color: color,
        ),
      ),
    );
  }
}

/// White rounded block used for most content.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: kMed,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

/// Small selectable pill (day picker, course picker).
class AppPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const AppPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: kFast,
          curve: Curves.easeOut,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.tint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedDefaultTextStyle(
            duration: kFast,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : AppColors.ink,
            ),
            child: Text(label),
          ),
        ),
      ),
        ),
      ),
    );
  }
}

/// Tab content switch: fade plus a small slide.
Widget tabTransition(Widget child, Animation<double> anim) {
  return FadeTransition(
    opacity: anim,
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
          .animate(anim),
      child: child,
    ),
  );
}

/// Dark bottom bar with an animated active pill.
class AppNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const AppNavBar({super.key, required this.index, required this.onTap});

  static const _icons = [
    Icons.home_rounded,
    Icons.calendar_month_rounded,
    Icons.qr_code_2_rounded,
    Icons.person_rounded,
  ];
  static const _labels = ['Home', 'History', 'Holidays', 'QR', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: List.generate(_labels.length, (i) {
              final selected = i == index;
              final color = selected ? AppColors.primary : AppColors.muted;
              Widget iconWidget;
              if (i == 2) {
                // Beach holiday icon
                iconWidget = Image.asset('assets/holiday.png',
                    width: 28, height: 28, color: color);
              } else {
                final iconIdx = i < 2 ? i : i - 1;
                iconWidget = Icon(_icons[iconIdx], size: 24, color: color);
              }
              return Expanded(
                child: PressScale(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: kFast,
                          curve: Curves.easeOut,
                          width: selected ? 56 : 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.tint
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(child: iconWidget),
                        ),
                        const SizedBox(height: 2),
                        AnimatedDefaultTextStyle(
                          duration: kFast,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected
                                ? AppColors.primary
                                : AppColors.muted,
                          ),
                          child: Text(_labels[i]),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Beach scene icon painter for the Holidays tab.
/// Blue top area with a rounded sheet over it. Scrolls as one page.
class BoldPage extends StatefulWidget {
  final Widget header;
  final List<Widget> children;
  const BoldPage({super.key, required this.header, required this.children});

  @override
  State<BoldPage> createState() => _BoldPageState();
}

class _BoldPageState extends State<BoldPage> {
  final _ctrl = ScrollController();
  final _headerKey = GlobalKey();
  bool _snapping = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// How far the page scrolls before only a thin green strip is left.
  double get _collapse {
    final h = _headerKey.currentContext?.size?.height ?? 0;
    final top = MediaQuery.of(context).padding.top;
    return (h - top - 8).clamp(0.0, double.infinity);
  }

  // A small scroll snaps the header closed (or back open) with an animation.
  bool _onScroll(ScrollNotification n) {
    if (n is ScrollEndNotification && !_snapping && _ctrl.hasClients) {
      final max = _collapse;
      final o = _ctrl.offset;
      if (max > 0 && o > 0 && o < max) {
        _snapping = true;
        _ctrl
            .animateTo(o > max * 0.15 ? max : 0,
                duration: reduceMotion(context) ? Duration.zero : kMed,
                curve: Curves.easeOutCubic)
            .whenComplete(() => _snapping = false);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        color: AppColors.primary,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: CustomScrollView(
            controller: _ctrl,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  key: _headerKey,
                  padding: EdgeInsets.fromLTRB(
                      16, MediaQuery.of(context).padding.top + 16, 16, 24),
                  child: widget.header,
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet body with the same title / content / actions shape as AlertDialog.
class SheetDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget> actions;
  const SheetDialog(
      {super.key,
      required this.title,
      required this.content,
      this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            DefaultTextStyle(
              style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
              child: title,
            ),
            const SizedBox(height: 16),
            Flexible(child: SingleChildScrollView(child: content)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}
