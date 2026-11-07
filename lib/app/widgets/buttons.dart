import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'glass.dart';
import 'motion.dart';
import 'pressable.dart';

/// The primary action: polished metal, with light glinting across it.
class ChromeButton extends StatelessWidget {
  const ChromeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.dense = false,
    this.glint = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dense;

  /// The periodic glint draws the eye. Turn it off where several of these
  /// appear at once, such as list rows.
  final bool glint;

  @override
  Widget build(BuildContext context) {
    final height = dense ? 38.0 : 52.0;
    final enabled = onPressed != null;
    final face = Padding(
      padding: EdgeInsets.symmetric(horizontal: dense ? 16 : 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 17 : 20, color: AppColors.graphite900),
            SizedBox(width: dense ? 6 : 9),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.graphite900,
                fontWeight: FontWeight.w800,
                fontSize: dense ? 13 : 15,
              ),
            ),
          ),
        ],
      ),
    );

    return Pressable(
      onTap: onPressed,
      pressedScale: 0.95,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: enabled ? 1 : 0.45,
        child: Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            gradient: AppColors.silverMetal,
            boxShadow: [
              BoxShadow(
                color: AppColors.silver300.withValues(alpha: enabled ? 0.20 : 0),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: glint && enabled ? _Glint(child: face) : face,
        ),
      ),
    );
  }
}

class _Glint extends StatelessWidget {
  const _Glint({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Looping(
      period: const Duration(milliseconds: 4200),
      restingValue: 1,
      child: child,
      builder: (context, t, child) {
        final travel = (t / 0.28).clamp(0.0, 1.0);
        return CustomPaint(
          foregroundPainter: t < 0.28 ? _GlintPainter(Curves.easeInOut.transform(travel)) : null,
          child: child,
        );
      },
    );
  }
}

class _GlintPainter extends CustomPainter {
  const _GlintPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final x = -0.3 * size.width + 1.6 * size.width * progress;
    final rect = Rect.fromLTWH(x - 40, 0, 80, size.height);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.75),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlintPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Secondary action on glass.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.dense = false,
    this.color = AppColors.silver100,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dense;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final height = dense ? 38.0 : 52.0;
    return Pressable(
      onTap: onPressed,
      pressedScale: 0.95,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: onPressed != null ? 1 : 0.45,
        child: SizedBox(
          height: height,
          child: GlassPanel(
            radius: height / 2,
            shadow: false,
            padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: dense ? 17 : 20, color: color),
                  SizedBox(width: dense ? 6 : 9),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: dense ? 13 : 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small bronze spinner used wherever something is connecting.
class BusySpinner extends StatelessWidget {
  const BusySpinner({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.bronze400),
    );
  }
}
