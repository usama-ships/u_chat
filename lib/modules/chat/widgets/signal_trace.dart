import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/voice/voice_meta.dart';

/// A voice note drawn as a radar signal: bars mirrored around a centre line.
/// While playing, a scan head sweeps across and turns the bars behind it
/// bronze, the same way the Nearby radar lights up what it passes.
class SignalTrace extends StatelessWidget {
  const SignalTrace({
    super.key,
    required this.bars,
    required this.color,
    required this.playedColor,
    this.played = 0,
    this.available = 1,
    this.showHead = false,
    this.height = 34,
  });

  /// Heights, 0 to 255.
  final List<int> bars;
  final Color color;
  final Color playedColor;

  /// How far playback has got, 0 to 1.
  final double played;

  /// How much of the audio has arrived. The rest is drawn faintly.
  final double available;

  final bool showHead;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _TracePainter(
            bars: bars,
            color: color,
            playedColor: playedColor,
            played: played,
            available: available,
            showHead: showHead,
          ),
        ),
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  const _TracePainter({
    required this.bars,
    required this.color,
    required this.playedColor,
    required this.played,
    required this.available,
    required this.showHead,
  });

  final List<int> bars;
  final Color color;
  final Color playedColor;
  final double played;
  final double available;
  final bool showHead;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final mid = size.height / 2;
    final slot = size.width / bars.length;
    final barWidth = math.min(slot * 0.62, 3.0);
    final paint = Paint()
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < bars.length; i++) {
      final position = (i + 0.5) / bars.length;
      final x = slot * (i + 0.5);

      // Bars swell slightly as the head passes, like a blip on the radar.
      final distance = (position - played).abs();
      final swell = showHead ? math.max(0.0, 1 - distance * 14) * 0.22 : 0.0;
      final amplitude = (bars[i] / 255) * (1 + swell);
      final half = math.max(1.5, amplitude * (mid - 1));

      final isPlayed = position <= played;
      final arrived = position <= available;
      paint.color = isPlayed ? playedColor : color.withValues(alpha: arrived ? 1 : 0.28);
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half), paint);
    }

    if (showHead) {
      final x = size.width * played;
      canvas.drawRect(
        Rect.fromLTWH(x - 7, 0, 7, size.height),
        Paint()
          ..shader = LinearGradient(
            colors: [playedColor.withValues(alpha: 0), playedColor.withValues(alpha: 0.32)],
          ).createShader(Rect.fromLTWH(x - 7, 0, 7, size.height)),
      );
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..strokeWidth = 1.4
          ..color = playedColor,
      );
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.played != played ||
      old.available != available ||
      old.showHead != showHead ||
      old.bars != bars ||
      old.color != color;
}

/// The trace while recording: newest sound enters at the right and scrolls left.
class LiveTrace extends StatelessWidget {
  const LiveTrace({super.key, required this.levels, this.color = AppColors.bronze300});

  final List<double> levels;
  final Color color;

  static const _visibleBars = VoiceMeta.waveformBars;

  @override
  Widget build(BuildContext context) {
    final tail = levels.length > _visibleBars
        ? levels.sublist(levels.length - _visibleBars)
        : levels;
    final padded = [
      ...List<int>.filled(_visibleBars - tail.length, 0),
      for (final level in tail) (level.clamp(0.0, 1.0) * 255).round(),
    ];
    return SignalTrace(bars: padded, color: color, playedColor: color, height: 28);
  }
}
