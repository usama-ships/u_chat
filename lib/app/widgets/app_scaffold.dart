import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'motion.dart';

/// The purple header behind every screen, with two big frosted rings for
/// depth. Painted once and cached, so it costs nothing per frame.
class HeaderBackground extends StatelessWidget {
  const HeaderBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(painter: _HeaderPainter(), child: SizedBox.expand()),
    );
  }
}

class _HeaderPainter extends CustomPainter {
  const _HeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = AppColors.headerGradient.createShader(rect));
    paintGlow(canvas, size, const Offset(0.1, 0.0), 0.45, const Color(0xFF9A8CF0), 0.55);

    // Frosted rings, like light caught in glass.
    final w = size.width;
    _orb(canvas, Offset(w * 0.95, 30), w * 0.42);
    _orb(canvas, Offset(w * 0.05, 250), w * 0.30);
  }

  void _orb(Canvas canvas, Offset centre, double radius) {
    final bounds = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.02)],
        ).createShader(bounds),
    );
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.14),
    );
  }

  @override
  bool shouldRepaint(_HeaderPainter oldDelegate) => false;
}

/// Paints one soft coloured glow. [at] is a fraction of the size, [radius] a
/// fraction of the longest side.
void paintGlow(Canvas canvas, Size size, Offset at, double radius, Color color, double alpha) {
  final centre = Offset(size.width * at.dx, size.height * at.dy);
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: centre, radius: size.longestSide * radius)),
  );
}

/// The light sheet most screens sit on: mist, with a faint lavender and lemon
/// glow so the frosted cards on top have something to catch.
class SheetBackground extends StatelessWidget {
  const SheetBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(painter: _SheetPainter(), child: SizedBox.expand()),
    );
  }
}

class _SheetPainter extends CustomPainter {
  const _SheetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bg);
    paintGlow(canvas, size, const Offset(1.0, 0.1), 0.55, AppColors.accent, 0.10);
    paintGlow(canvas, size, const Offset(0.0, 0.95), 0.50, AppColors.highlight, 0.28);
  }

  @override
  bool shouldRepaint(_SheetPainter oldDelegate) => false;
}

/// The chat sheet: mist fading to a hint of lavender, with a faint dot
/// pattern. Static and cached, so it never costs anything while messages
/// scroll over it.
class ChatBackground extends StatelessWidget {
  const ChatBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(painter: _ChatBackgroundPainter(), child: SizedBox.expand()),
    );
  }
}

class _ChatBackgroundPainter extends CustomPainter {
  const _ChatBackgroundPainter();

  static const _spacing = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bg, AppColors.chatBottom],
        ).createShader(rect),
    );
    paintGlow(canvas, size, const Offset(1.0, 0.0), 0.50, AppColors.accent, 0.08);
    paintGlow(canvas, size, const Offset(0.0, 1.0), 0.45, AppColors.highlight, 0.22);

    // Staggered dots, a little stronger towards the bottom.
    final dot = Paint();
    var row = 0;
    for (var y = _spacing / 2; y < size.height; y += _spacing, row++) {
      dot.color = AppColors.accent.withValues(alpha: 0.04 + 0.04 * (y / size.height));
      final shift = row.isOdd ? _spacing / 2 : 0.0;
      for (var x = _spacing / 2 + shift; x < size.width; x += _spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_ChatBackgroundPainter oldDelegate) => false;
}

/// A screen: the purple [HeaderBackground] with [appBar] on it, and [body]
/// on a light sheet with rounded top corners that rises into place.
///
/// The sheet runs behind [bottomBar], so lists scroll under it. Inside the
/// body, `MediaQuery.paddingOf` gives the clearance.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomBar,
    this.floatingActionButton,
    this.resizeForKeyboard = true,
    this.background = const SheetBackground(),
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  /// Set to false when [bottomBar] follows the keyboard itself.
  final bool resizeForKeyboard;

  /// Painted on the sheet, behind [body]. Chats use [ChatBackground].
  final Widget background;

  static const sheetRadius = 32.0;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const HeaderBackground(),
          Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            resizeToAvoidBottomInset: resizeForKeyboard,
            appBar: appBar,
            bottomNavigationBar: bottomBar,
            floatingActionButton: floatingActionButton,
            body: Entrance(
              offset: const Offset(0, 48),
              duration: Motion.slow,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(sheetRadius)),
                child: Stack(fit: StackFit.expand, children: [background, body]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
