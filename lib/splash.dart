import 'package:flutter/material.dart';
import 'ui_kit.dart';


class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) {
      _c.value = 1;
      Future.delayed(const Duration(milliseconds: 500), _finish);
    } else {
      _c.forward().then((_) =>
          Future.delayed(const Duration(milliseconds: 450), _finish));
    }
  }

  void _finish() {
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _iv(double a, double b, [Curve curve = Curves.easeOut]) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: curve));

  @override
  Widget build(BuildContext context) {
    final tile = _iv(0.0, 0.22, Curves.easeOutBack);
    final badge = _iv(0.14, 0.30, Curves.easeOutBack);
    final tick = _iv(0.28, 0.42);
    final name = _iv(0.40, 0.62);
    final tag = _iv(0.50, 0.72);
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: _iv(0.0, 0.1).value,
                  child: Transform.scale(
                    scale: 0.6 + 0.4 * tile.value,
                    child: SizedBox(
                      width: 168,
                      height: 168,
                      child: CustomPaint(
                          painter:
                              LogoPainter(badge.value, tick.value)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Opacity(
                  opacity: name.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - name.value)),
                    child: const Text('Attend',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: tag.value.clamp(0.0, 1.0),
                  child: const Text('Stay above 75%',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class LogoPainter extends CustomPainter {
  final double badge;
  final double tick;
  LogoPainter(this.badge, this.tick);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 200;
    canvas.save();
    canvas.scale(k);
    final fill = Paint()..style = PaintingStyle.fill;
    RRect rr(double x, double y, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));
    canvas.drawRRect(rr(0, 0, 200, 200, 46), fill..color = AppColors.accent);
    canvas.drawRRect(rr(44, 52, 112, 104, 16), fill..color = Colors.white);
    canvas.drawRRect(
        RRect.fromRectAndCorners(const Rect.fromLTWH(44, 52, 112, 30),
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16)),
        fill..color = AppColors.primary);
    for (final x in [72.0, 118.0]) {
      canvas.drawRRect(rr(x, 40, 10, 24, 5), fill..color = AppColors.peach);
    }
    fill.color = AppColors.line;
    for (final o in const [
      Offset(70, 104), Offset(100, 104), Offset(130, 104),
      Offset(70, 130), Offset(100, 130)
    ]) {
      canvas.drawCircle(o, 6, fill);
    }
    if (badge > 0) {
      final s = badge.clamp(0.0, 1.3);
      canvas.save();
      canvas.translate(150, 150);
      canvas.scale(s);
      canvas.drawCircle(Offset.zero, 33, fill..color = Colors.white);
      canvas.drawCircle(Offset.zero, 30, fill..color = AppColors.ink);
      if (tick > 0) {
        final path = Path()
          ..moveTo(-14, 0)
          ..relativeLineTo(10, 10)
          ..relativeLineTo(18, -20);
        final m = path.computeMetrics().first;
        canvas.drawPath(
            m.extractPath(0, m.length * tick.clamp(0.0, 1.0)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LogoPainter o) => o.badge != badge || o.tick != tick;
}
