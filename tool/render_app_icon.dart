// Draws the launcher icon and writes every Android density into `res/`.
//
//   flutter test tool/render_app_icon.dart
//
// The mark is a metal U holding a bronze signal, inside radar rings.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:u_chat/app/theme/app_colors.dart';

const _res = 'android/app/src/main/res';

/// Density folder, with the classic icon size and the adaptive layer size.
const _densities = <String, (int, int)>{
  'mdpi': (48, 108),
  'hdpi': (72, 162),
  'xhdpi': (96, 216),
  'xxhdpi': (144, 324),
  'xxxhdpi': (192, 432),
};

/// Android crops adaptive layers to the middle 72/108, and only guarantees the
/// middle 66/108 on every launcher shape.
const _adaptiveMarkScale = 0.60;

void _paintBackground(Canvas canvas, double size) {
  final rect = Offset.zero & Size.square(size);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.graphite600, AppColors.graphite900, AppColors.graphite950],
        stops: [0, 0.55, 1],
      ).createShader(rect),
  );
  canvas.drawCircle(
    Offset(size * 0.22, size * 0.14),
    size * 0.8,
    Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.silver300.withValues(alpha: 0.30),
          AppColors.silver300.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(size * 0.22, size * 0.14), radius: size * 0.8)),
  );
}

/// [size] is the box the mark fills, centred on [center].
void _paintMark(Canvas canvas, Offset center, double size, {Color? flat}) {
  final stroke = size * 0.145;
  final halfWidth = size * 0.27;
  final top = center.dy - size * 0.30;
  final bowl = center.dy + size * 0.06;

  if (flat == null) {
    for (final (fraction, alpha) in const [(0.50, 0.16), (0.385, 0.26)]) {
      canvas.drawCircle(
        center,
        size * fraction,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size * 0.012
          ..color = AppColors.silver200.withValues(alpha: alpha),
      );
    }
  }

  final u = Path()
    ..moveTo(center.dx - halfWidth, top)
    ..lineTo(center.dx - halfWidth, bowl)
    ..arcToPoint(
      Offset(center.dx + halfWidth, bowl),
      radius: Radius.circular(halfWidth),
      clockwise: false,
    )
    ..lineTo(center.dx + halfWidth, top);
  final bounds = Rect.fromCenter(center: center, width: size, height: size);
  canvas.drawPath(
    u,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = flat ?? Colors.white
      ..shader = flat == null ? AppColors.silverMetal.createShader(bounds) : null,
  );

  final dot = Offset(center.dx, center.dy - size * 0.13);
  final radius = size * 0.082;
  if (flat == null) {
    canvas.drawCircle(
      dot,
      radius * 2.1,
      Paint()..color = AppColors.bronze400.withValues(alpha: 0.22),
    );
  }
  final dotRect = Rect.fromCircle(center: dot, radius: radius);
  canvas.drawCircle(
    dot,
    radius,
    Paint()
      ..color = flat ?? Colors.white
      ..shader = flat == null ? AppColors.bronzeMetal.createShader(dotRect) : null,
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

        // Android 7: a ready-made rounded square.
        await _write('$dir/ic_launcher.png', classic, (canvas, size) {
          final inset = size * 0.04;
          final shape = RRect.fromRectAndRadius(
            (Offset.zero & Size.square(size)).deflate(inset),
            Radius.circular(size * 0.22),
          );
          canvas.save();
          canvas.clipRRect(shape);
          _paintBackground(canvas, size);
          _paintMark(canvas, Offset(size / 2, size / 2), size * 0.82);
          canvas.restore();
        });

        // Android 8+: layers the launcher crops and animates itself.
        await _write('$dir/ic_launcher_background.png', adaptive, _paintBackground);
        await _write('$dir/ic_launcher_foreground.png', adaptive, (canvas, size) {
          _paintMark(canvas, Offset(size / 2, size / 2), size * _adaptiveMarkScale);
        });

        // Android 13+: themed icons tint this single-colour version.
        await _write('$dir/ic_launcher_monochrome.png', adaptive, (canvas, size) {
          _paintMark(
            canvas,
            Offset(size / 2, size / 2),
            size * _adaptiveMarkScale,
            flat: Colors.white,
          );
        });
      }
    });
  });
}
