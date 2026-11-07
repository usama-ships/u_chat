import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'buttons.dart';
import 'glass.dart';

/// Opens [builder] as a frosted dialog that scales up while the screen
/// behind it blurs out.
Future<T?> showGlassDialog<T>(BuildContext context, WidgetBuilder builder) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: Motion.medium,
    pageBuilder: (context, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              type: MaterialType.transparency,
              child: GlassPanel(
                radius: 26,
                blur: true,
                fill: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.graphite700.withValues(alpha: 0.88),
                    AppColors.graphite800.withValues(alpha: 0.82),
                  ],
                ),
                padding: const EdgeInsets.all(22),
                child: builder(context),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Motion.ease);
      return AnimatedBuilder(
        animation: curved,
        builder: (context, child) {
          final v = curved.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8 * v, sigmaY: 8 * v),
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.45 * v)),
                ),
              ),
              Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.93 + 0.07 * v, child: child),
              ),
            ],
          );
        },
        child: child,
      );
    },
  );
}

/// Yes/no question. Resolves to true only if the user confirmed.
Future<bool> showGlassConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showGlassDialog<bool>(context, (context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.silver300)),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: GhostButton(
                label: 'Cancel',
                dense: true,
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: destructive
                  ? GhostButton(
                      label: confirmLabel,
                      dense: true,
                      color: AppColors.clay,
                      onPressed: () => Navigator.pop(context, true),
                    )
                  : ChromeButton(
                      label: confirmLabel,
                      dense: true,
                      glint: false,
                      onPressed: () => Navigator.pop(context, true),
                    ),
            ),
          ],
        ),
      ],
    );
  });
  return result ?? false;
}

/// Frosted bottom sheet.
Future<void> showGlassSheet(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: SafeArea(
        top: false,
        child: GlassPanel(
          radius: 26,
          blur: true,
          fill: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.graphite700.withValues(alpha: 0.90),
              AppColors.graphite800.withValues(alpha: 0.84),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.silver500,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              builder(context),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Short frosted notice. It drops in from the top so it never covers the
/// composer or the Nearby button.
void showToast(String title, String message, {Duration duration = const Duration(seconds: 3)}) {
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.TOP,
    duration: duration,
    animationDuration: Motion.slow,
    forwardAnimationCurve: Motion.ease,
    reverseAnimationCurve: Curves.easeInCubic,
    backgroundColor: AppColors.graphite700.withValues(alpha: 0.95),
    colorText: AppColors.silver100,
    barBlur: 18,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: Colors.white.withValues(alpha: 0.14),
    margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
    maxWidth: 560,
  );
}
