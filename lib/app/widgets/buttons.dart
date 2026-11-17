import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'pressable.dart';

/// The main action on a screen: a lavender pill.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final height = dense ? 38.0 : 52.0;
    final enabled = onPressed != null;
    return Pressable(
      onTap: onPressed,
      pressedScale: 0.96,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: enabled ? 1 : 0.45,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: dense ? 16 : 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            gradient: AppColors.accentGradient,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: _Label(label: label, icon: icon, dense: dense, color: AppColors.onAccent),
        ),
      ),
    );
  }
}

/// A quieter action next to or instead of a [PrimaryButton].
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.dense = false,
    this.color = AppColors.accent,
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
      pressedScale: 0.96,
      child: AnimatedOpacity(
        duration: Motion.fast,
        opacity: onPressed != null ? 1 : 0.45,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: AppColors.accentBorder.withValues(alpha: 0.35)),
          ),
          child: _Label(label: label, icon: icon, dense: dense, color: color),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.label, required this.icon, required this.dense, required this.color});

  final String label;
  final IconData? icon;
  final bool dense;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: dense ? 17 : 20, color: color),
          SizedBox(width: dense ? 6 : 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 13.5 : 15,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small spinner used wherever something is connecting.
class BusySpinner extends StatelessWidget {
  const BusySpinner({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.accentLight),
    );
  }
}
