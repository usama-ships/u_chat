import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// The slowly drifting brushed-metal background behind every screen.
///
/// The phase comes from the wall clock, so when one screen replaces another
/// the two backdrops line up exactly and the background seems to be shared.
class SilverBackdrop extends StatefulWidget {
  const SilverBackdrop({super.key});

  @override
  State<SilverBackdrop> createState() => _SilverBackdropState();
}

class _SilverBackdropState extends State<SilverBackdrop> with SingleTickerProviderStateMixin {
  /// Motion this slow looks the same at 30 fps, and it halves the work for
  /// the blur layers above it.
  static const _frameInterval = Duration(milliseconds: 33);

  final _phase = ValueNotifier<double>(_now());
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastPaint = Duration.zero;

  static double _now() => DateTime.now().millisecondsSinceEpoch / 1000;

  void _onTick(Duration elapsed) {
    if (elapsed - _lastPaint < _frameInterval) return;
    _lastPaint = elapsed;
    _phase.value = _now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = Motion.isReduced(context);
    if (reduced && _ticker.isActive) {
      _ticker.stop();
    } else if (!reduced && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BackdropPainter(_phase),
        isComplex: true,
        willChange: true,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.phase) : super(repaint: phase);

  final ValueListenable<double> phase;

  static const _base = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.graphite800, AppColors.graphite900, AppColors.graphite950],
    stops: [0, 0.45, 1],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final t = phase.value;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = _base.createShader(rect));

    final span = size.longestSide;
    _glow(
      canvas,
      rect,
      Offset(
        size.width * (0.20 + 0.16 * math.sin(t / 11)),
        size.height * (0.14 + 0.07 * math.cos(t / 13)),
      ),
      span * 0.62,
      AppColors.silver300.withValues(alpha: 0.26),
    );
    _glow(
      canvas,
      rect,
      Offset(
        size.width * (0.86 + 0.12 * math.cos(t / 9)),
        size.height * (0.52 + 0.14 * math.sin(t / 15)),
      ),
      span * 0.50,
      AppColors.silver300.withValues(alpha: 0.15),
    );
    _glow(
      canvas,
      rect,
      Offset(
        size.width * (0.18 + 0.18 * math.cos(t / 17)),
        size.height * (0.94 + 0.05 * math.sin(t / 12)),
      ),
      span * 0.46,
      AppColors.bronze400.withValues(alpha: 0.10),
    );

    // A wide band of light crossing the metal.
    final drift = math.sin(t / 19);
    final sheen = LinearGradient(
      begin: Alignment(-1.2 + drift * 0.5, -1),
      end: Alignment(1.2 + drift * 0.5, 1),
      colors: [
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.05),
        Colors.white.withValues(alpha: 0),
      ],
      stops: const [0.3, 0.5, 0.7],
    );
    canvas.drawRect(rect, Paint()..shader = sheen.createShader(rect));
  }

  void _glow(Canvas canvas, Rect rect, Offset center, double radius, Color color) {
    final shader = RadialGradient(
      colors: [color, color.withValues(alpha: 0)],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => false;
}

/// [Scaffold] on top of the [SilverBackdrop].
///
/// The body draws behind [appBar] and [bottomBar] so content scrolls under
/// the glass. Inside the body, `MediaQuery.paddingOf` gives the clearance.
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomBar,
    this.floatingActionButton,
    this.resizeForKeyboard = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  /// Set to false when [bottomBar] follows the keyboard itself.
  final bool resizeForKeyboard;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const SilverBackdrop(),
          Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            extendBodyBehindAppBar: true,
            resizeToAvoidBottomInset: resizeForKeyboard,
            appBar: appBar,
            bottomNavigationBar: bottomBar,
            floatingActionButton: floatingActionButton,
            body: body,
          ),
        ],
      ),
    );
  }
}
