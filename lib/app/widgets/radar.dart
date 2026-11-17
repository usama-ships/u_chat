import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

/// One device on the [Radar].
class RadarBlip {
  const RadarBlip({
    required this.id,
    required this.strength,
    this.label = '',
    this.colors = const [],
  });

  final String id;

  /// Initial drawn on the blip. Empty for a plain dot.
  final String label;

  /// The person's avatar gradient, so the blip matches their card.
  final List<Color> colors;

  /// 0 (far, at the edge) to 1 (close, near the centre).
  final double strength;
}

/// Sweeping radar with nearby devices plotted by signal strength.
class Radar extends StatefulWidget {
  const Radar({super.key, required this.scanning, this.blips = const []});

  final bool scanning;
  final List<RadarBlip> blips;

  @override
  State<Radar> createState() => _RadarState();
}

class _RadarState extends State<Radar> with TickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  late final AnimationController _power = AnimationController(vsync: this, duration: Motion.slow);

  /// When each blip was first drawn, in sweep turns, so it can pop in.
  final _firstSeen = <String, DateTime>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Radar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scanning != widget.scanning) _sync();
  }

  void _sync() {
    if (Motion.isReduced(context)) {
      _sweep.stop();
      _power.value = widget.scanning ? 1 : 0;
      return;
    }
    if (widget.scanning) {
      _power.forward();
      if (!_sweep.isAnimating) _sweep.repeat();
    } else {
      // Stops the sweep once it has faded: no ticking while idle.
      _power.reverse().whenCompleteOrCancel(() {
        if (mounted && !widget.scanning) _sweep.stop();
      });
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    _power.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    for (final blip in widget.blips) {
      _firstSeen.putIfAbsent(blip.id, () => now);
    }
    return Semantics(
      label: widget.scanning ? 'Scanning for nearby devices' : 'Scan stopped',
      child: AspectRatio(
        aspectRatio: 1,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _RadarPainter(
              sweep: _sweep,
              power: _power,
              blips: widget.blips,
              firstSeen: _firstSeen,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.sweep,
    required this.power,
    required this.blips,
    required this.firstSeen,
  }) : super(repaint: Listenable.merge([sweep, power]));

  final Animation<double> sweep;
  final Animation<double> power;
  final List<RadarBlip> blips;
  final Map<String, DateTime> firstSeen;

  late final Map<String, TextPainter> _labels = {
    for (final blip in blips)
      if (blip.label.isNotEmpty)
        blip.id: TextPainter(
          text: TextSpan(
            text: blip.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'Manrope',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    final on = power.value;
    final angle = sweep.value * 2 * math.pi;

    // Halo.
    canvas.drawCircle(
      center,
      radius * 1.25,
      Paint()
        ..shader = RadialGradient(
          colors: [AppColors.accent.withValues(alpha: 0.22), AppColors.accent.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.25)),
    );

    // Dish.
    final dish = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.10),
            AppColors.accent.withValues(alpha: 0.02),
          ],
        ).createShader(dish),
    );

    // Range rings and crosshair.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.textFaint.withValues(alpha: 0.35);
    for (final fraction in const [0.34, 0.67]) {
      canvas.drawCircle(center, radius * fraction, line);
    }
    canvas.drawLine(center - Offset(radius, 0), center + Offset(radius, 0), line);
    canvas.drawLine(center - Offset(0, radius), center + Offset(0, radius), line);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.borderStrong,
    );

    if (on > 0) {
      // Two rings travelling outward.
      for (final offset in const [0.0, 0.5]) {
        final p = (sweep.value * 2 + offset) % 1;
        canvas.drawCircle(
          center,
          radius * p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = AppColors.accentLight.withValues(alpha: 0.28 * (1 - p) * on),
        );
      }

      // The beam: a wedge that trails behind the leading edge.
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = SweepGradient(
            center: Alignment.center,
            startAngle: 0,
            endAngle: 2 * math.pi,
            colors: [
              AppColors.accent.withValues(alpha: 0),
              AppColors.accent.withValues(alpha: 0),
              AppColors.accent.withValues(alpha: 0.34 * on),
            ],
            stops: const [0, 0.68, 1],
          ).createShader(dish),
      );
      canvas.drawLine(
        center,
        center + Offset(radius, 0),
        Paint()
          ..strokeWidth = 1.4
          ..color = AppColors.accentLight.withValues(alpha: 0.75 * on),
      );
      canvas.restore();
    }

    final now = DateTime.now();
    for (final blip in blips) {
      final seed = _hash(blip.id);
      final theta = (seed % 360) * math.pi / 180;
      final distance = radius * (0.92 - 0.62 * blip.strength.clamp(0.0, 1.0));
      final position = center + Offset(math.cos(theta), math.sin(theta)) * distance;

      final age = now.difference(firstSeen[blip.id] ?? now).inMilliseconds / 500;
      final appear = Curves.easeOutBack.transform(age.clamp(0.0, 1.0));

      // Flares as the beam passes over, then cools down.
      final sinceBeam = ((angle - theta) % (2 * math.pi)) / (2 * math.pi);
      final flare = on * math.pow(1 - sinceBeam, 3).toDouble();

      final colors = blip.colors.isEmpty ? const [AppColors.accent, AppColors.violet] : blip.colors;
      canvas.drawCircle(
        position,
        (16 + 10 * flare) * appear,
        Paint()..color = colors.last.withValues(alpha: 0.16 + 0.30 * flare),
      );
      final dot = 13.0 * appear;
      if (dot <= 0) continue;
      canvas.drawCircle(
        position,
        dot,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ).createShader(Rect.fromCircle(center: position, radius: dot)),
      );
      canvas.drawCircle(
        position,
        dot,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.85),
      );
      final label = _labels[blip.id];
      if (label != null && appear > 0.6) {
        label.paint(canvas, position - Offset(label.width / 2, label.height / 2));
      }
    }

    // You, in the middle.
    canvas.drawCircle(center, 14, Paint()..color = AppColors.accent.withValues(alpha: 0.25));
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..shader = AppColors.accentGradient.createShader(
          Rect.fromCircle(center: center, radius: 7),
        ),
    );
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  int _hash(String value) {
    var hash = 7;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => oldDelegate.blips != blips;
}

/// Maps a signal reading in dBm to the [RadarBlip.strength] scale.
double radarStrength(int rssi) => ((rssi + 100) / 60).clamp(0.0, 1.0);
