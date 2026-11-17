// Draws the Blue Chat launcher icon and writes every Android density into
// `res/`, plus a 512px store icon next to this file.
//
//   flutter test tool/render_app_icon.dart
//
// The mark, redrawn from tool/brand/blue_chat_logo_source.png: a black chat
// bubble with two dots behind a lavender bubble holding the Bluetooth rune,
// circled by a glowing orbit, with two sparks and a twinkle, on a light
// tile with a lavender wave at the top-left and a lemon wave at the bottom-right.
//
// All shapes are drawn in "design space", the 920x900 frame the source logo
// was traced in, and scaled to each target.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _res = 'android/app/src/main/res';

/// Density folder, with the classic icon size and the adaptive layer size.
const _densities = <String, (int, int)>{
  'mdpi': (48, 108),
  'hdpi': (72, 162),
  'xhdpi': (96, 216),
  'xxhdpi': (144, 324),
  'xxxhdpi': (192, 432),
};

// Brand colours.
const _ink = Color(0xFF17171A);
const _lavender = Color(0xFF6A5BC2);
const _lavenderLight = Color(0xFFA497F5);
const _lemon = Color(0xFFF4E85A);

/// The tile in design space.
const _tile = Rect.fromLTRB(20, 30, 900, 870);

/// Centre and size of the square an adaptive layer covers in design space.
/// Android shows the middle 72/108 and guarantees the middle 66/108, so the
/// mark (about 830 wide) sits inside the guaranteed part.
const _layerCentre = Offset(460, 425);
const _layerSide = 1520.0;

/// Draws [paint] with design space mapped onto a [size] square showing
/// [design].
void _mapped(Canvas canvas, double size, Rect design, void Function(Canvas) paint) {
  final scale = size / design.longestSide;
  canvas.save();
  canvas.translate(size / 2, size / 2);
  canvas.scale(scale);
  canvas.translate(-design.center.dx, -design.center.dy);
  paint(canvas);
  canvas.restore();
}

final _layerRect = Rect.fromCenter(center: _layerCentre, width: _layerSide, height: _layerSide);
final _tileSquare = Rect.fromCenter(center: _tile.center, width: 880, height: 880);

// ---------------------------------------------------------------------------
// Background.

void _paintBackground(Canvas canvas) {
  const far = Rect.fromLTRB(-400, -400, 1320, 1300);
  canvas.drawRect(
    far,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF3F0FD), Color(0xFFFFFFFF), Color(0xFFFCFAEE)],
      ).createShader(_tile),
  );

  // Soft lavender glow behind the bubbles.
  canvas.drawCircle(
    const Offset(480, 430),
    420,
    Paint()
      ..shader = RadialGradient(
        colors: [_lavender.withValues(alpha: 0.16), _lavender.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: const Offset(480, 430), radius: 420)),
  );

  // Lavender wave, top-left.
  final wave = Path()
    ..moveTo(-400, -400)
    ..lineTo(340, -400)
    ..lineTo(340, 30)
    ..cubicTo(290, 95, 200, 105, 150, 165)
    ..cubicTo(105, 220, 70, 255, -400, 300)
    ..close();
  canvas.drawPath(
    wave,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8676E6), Color(0xFFB8AEF7)],
      ).createShader(const Rect.fromLTRB(20, 30, 340, 300)),
  );

  // Lemon wave, bottom-right.
  final lemon = Path()
    ..moveTo(1320, 560)
    ..cubicTo(880, 570, 840, 690, 720, 755)
    ..cubicTo(610, 815, 480, 810, 400, 1300)
    ..lineTo(1320, 1300)
    ..close();
  canvas.drawPath(
    lemon,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFBF5B5), Color(0xFFF6EC86)],
      ).createShader(const Rect.fromLTRB(400, 560, 900, 870)),
  );

  // Faint ring around everything.
  canvas.drawCircle(
    const Offset(440, 440),
    340,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = _lavender.withValues(alpha: 0.16),
  );
}

// ---------------------------------------------------------------------------
// The mark.

const _orbitCentre = Offset(460, 490);
const _orbitTilt = -18 * math.pi / 180;
final _orbitOval = Rect.fromCenter(center: Offset.zero, width: 860, height: 230);

/// Half the orbit: the far half (behind the bubbles) or the near half.
void _orbit(Canvas canvas, Paint paint, {required bool near}) {
  canvas.save();
  canvas.translate(_orbitCentre.dx, _orbitCentre.dy);
  canvas.rotate(_orbitTilt);
  canvas.drawArc(_orbitOval, near ? 0 : math.pi, math.pi, false, paint);
  canvas.restore();
}

Path _blackBubble() => Path.combine(
  PathOperation.union,
  Path()..addOval(Rect.fromCenter(center: const Offset(300, 430), width: 350, height: 330)),
  Path()
    ..moveTo(190, 530)
    ..lineTo(172, 642)
    ..quadraticBezierTo(178, 650, 190, 644)
    ..lineTo(300, 585)
    ..close(),
);

Path _lavenderBubble() => Path.combine(
  PathOperation.union,
  Path()..addOval(Rect.fromCenter(center: const Offset(565, 390), width: 456, height: 400)),
  Path()
    ..moveTo(630, 578)
    ..lineTo(738, 620)
    ..quadraticBezierTo(750, 622, 748, 610)
    ..lineTo(728, 510)
    ..close(),
);

Path _bluetooth() {
  const c = Offset(567, 392);
  Offset p(double x, double y) => c + Offset(x, y);
  return Path()
    ..moveTo(p(-72, -62).dx, p(-72, -62).dy)
    ..lineTo(p(72, 56).dx, p(72, 56).dy)
    ..lineTo(p(0, 124).dx, p(0, 124).dy)
    ..lineTo(p(0, -124).dx, p(0, -124).dy)
    ..lineTo(p(72, -56).dx, p(72, -56).dy)
    ..lineTo(p(-72, 62).dx, p(-72, 62).dy);
}

const _dots = [Offset(224, 447), Offset(292, 433)];

Path _twinkle() {
  const c = Offset(600, 742);
  const outer = 38.0;
  const inner = 9.0;
  final path = Path();
  for (var i = 0; i < 8; i++) {
    final r = i.isEven ? outer : inner;
    final a = -math.pi / 2 + i * math.pi / 4;
    final point = c + Offset(math.cos(a) * r, math.sin(a) * r);
    i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
  }
  return path..close();
}

Paint _stroke(double width, Color color) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..color = color;

void _paintMark(Canvas canvas) {
  // Far half of the orbit, behind everything.
  _orbit(canvas, _stroke(15, const Color(0xFF8A7BE0).withValues(alpha: 0.85)), near: false);

  // Black bubble, with a soft shadow.
  final black = _blackBubble();
  canvas.drawPath(
    black.shift(const Offset(0, 24)),
    Paint()
      ..color = _lavender.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
  );
  canvas.drawPath(
    black,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF3A3A42), _ink],
      ).createShader(const Rect.fromLTRB(125, 265, 475, 650)),
  );
  for (final dot in _dots) {
    canvas.drawCircle(dot, 22, Paint()..color = Colors.white);
  }

  // Lavender bubble, casting a shadow over the black one.
  final lavender = _lavenderBubble();
  canvas.drawPath(
    lavender.shift(const Offset(-14, 18)),
    Paint()
      ..color = const Color(0xFF3B2F86).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
  );
  canvas.drawPath(
    lavender,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_lavenderLight, Color(0xFF7B6BDB), Color(0xFF5E4FC0)],
      ).createShader(const Rect.fromLTRB(337, 190, 793, 620)),
  );
  // Light catching the top edge.
  canvas.save();
  canvas.clipPath(lavender);
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(545, 300), width: 400, height: 220),
    Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)],
      ).createShader(Rect.fromCenter(center: const Offset(545, 300), width: 400, height: 220)),
  );
  canvas.restore();
  canvas.drawPath(_bluetooth(), _stroke(28, Colors.white));

  // Near half of the orbit: lavender at the ends, glowing white-gold in front.
  const orbitBounds = Rect.fromLTRB(40, 330, 880, 640);
  const glow = LinearGradient(
    colors: [Color(0x00FFF3B0), Color(0x99FFF3B0), Color(0x00FFF3B0)],
    stops: [0.2, 0.5, 0.8],
  );
  _orbit(
    canvas,
    _stroke(34, Colors.white)
      ..shader = glow.createShader(orbitBounds)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    near: true,
  );
  _orbit(
    canvas,
    _stroke(15, Colors.white)
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF7A6BD6),
          Color(0xFFC9C1FA),
          Color(0xFFFFFFFF),
          Color(0xFFFFF0A0),
          Color(0xFF8A7BE0),
        ],
        stops: [0, 0.3, 0.48, 0.62, 1],
      ).createShader(orbitBounds),
    near: true,
  );

  // Sparks and twinkle.
  canvas.drawLine(
    const Offset(713, 98),
    const Offset(696, 168),
    _stroke(26, const Color(0xFF6C5CE0)),
  );
  canvas.drawLine(const Offset(788, 152), const Offset(745, 204), _stroke(26, _lemon));
  canvas.drawPath(_twinkle(), Paint()..color = const Color(0xFF7565DE));
}

/// One white silhouette, for Android 13 themed icons.
void _paintMonochrome(Canvas canvas) {
  final white = Paint()..color = Colors.white;
  canvas.saveLayer(const Rect.fromLTRB(-400, -400, 1320, 1300), Paint());
  _orbit(canvas, _stroke(15, Colors.white), near: false);
  canvas.drawPath(_blackBubble(), white);
  // A gap where the front bubble overlaps the back one.
  canvas.drawPath(_lavenderBubble(), _stroke(26, Colors.white)..blendMode = BlendMode.clear);
  canvas.drawPath(_lavenderBubble(), white);
  final clear = Paint()..blendMode = BlendMode.clear;
  for (final dot in _dots) {
    canvas.drawCircle(dot, 22, clear);
  }
  canvas.drawPath(_bluetooth(), _stroke(28, Colors.white)..blendMode = BlendMode.clear);
  _orbit(canvas, _stroke(15, Colors.white), near: true);
  canvas.drawLine(const Offset(713, 98), const Offset(696, 168), _stroke(26, Colors.white));
  canvas.drawLine(const Offset(788, 152), const Offset(745, 204), _stroke(26, Colors.white));
  canvas.drawPath(_twinkle(), white);
  canvas.restore();
}

/// The whole rounded tile, for Android 7 and the store.
void _paintTile(Canvas canvas, double size) {
  final shape = RRect.fromRectAndRadius(
    (Offset.zero & Size.square(size)).deflate(size * 0.03),
    Radius.circular(size * 0.23),
  );
  canvas.save();
  canvas.clipRRect(shape);
  _mapped(canvas, size, _tileSquare.inflate(28), (canvas) {
    _paintBackground(canvas);
    _paintMark(canvas);
  });
  canvas.restore();
  canvas.drawRRect(
    shape.deflate(size * 0.006),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.012
      ..color = Colors.white.withValues(alpha: 0.7),
  );
}

Future<void> _write(String path, int size, void Function(Canvas canvas, double size) paint) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder), size.toDouble());
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('render', (tester) async {
    await tester.runAsync(() async {
      for (final MapEntry(key: density, value: (classic, adaptive)) in _densities.entries) {
        final dir = '$_res/mipmap-$density';

        // Android 7: a ready-made rounded tile.
        await _write('$dir/ic_launcher.png', classic, _paintTile);

        // Android 8+: layers the launcher shapes and animates itself.
        await _write(
          '$dir/ic_launcher_background.png',
          adaptive,
          (canvas, size) => _mapped(canvas, size, _layerRect, _paintBackground),
        );
        await _write(
          '$dir/ic_launcher_foreground.png',
          adaptive,
          (canvas, size) => _mapped(canvas, size, _layerRect, _paintMark),
        );

        // Android 13+: themed icons tint this single-colour version.
        await _write(
          '$dir/ic_launcher_monochrome.png',
          adaptive,
          (canvas, size) => _mapped(canvas, size, _layerRect, _paintMonochrome),
        );
      }

      await _write('tool/brand/blue_chat_icon_512.png', 512, _paintTile);
    });
  });
}
