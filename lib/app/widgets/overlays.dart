import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'buttons.dart';
import 'surfaces.dart';

/// Opens [builder] in a dialog that fades and scales in over a dimmed screen.
Future<T?> showAppDialog<T>(BuildContext context, WidgetBuilder builder) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0xFF1A1A2E).withValues(alpha: 0.45),
    transitionDuration: Motion.medium,
    // Lifts the dialog above the keyboard, as Material's Dialog does.
    pageBuilder: (context, _, _) => AnimatedPadding(
      duration: Motion.fast,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Material(
                type: MaterialType.transparency,
                child: Panel(
                  radius: 28,
                  color: AppColors.surfaceRaised,
                  shadow: true,
                  padding: const EdgeInsets.all(22),
                  child: builder(context),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Motion.ease);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Yes/no question. Resolves to true only if the user confirmed.
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showAppDialog<bool>(context, (context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Cancel',
                dense: true,
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: destructive
                  ? SecondaryButton(
                      label: confirmLabel,
                      dense: true,
                      color: AppColors.danger,
                      onPressed: () => Navigator.pop(context, true),
                    )
                  : PrimaryButton(
                      label: confirmLabel,
                      dense: true,
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

/// Bottom sheet of actions.
Future<void> showActionSheet(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: const Color(0xFF1A1A2E).withValues(alpha: 0.4),
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: SafeArea(
        top: false,
        child: Panel(
          radius: 28,
          color: AppColors.surfaceRaised,
          shadow: true,
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 4, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.textFaint,
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

/// Short notice. It drops in from the top so it never covers the composer or
/// the Nearby button.
void showToast(String title, String message, {Duration duration = const Duration(seconds: 3)}) {
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.TOP,
    duration: duration,
    animationDuration: Motion.slow,
    forwardAnimationCurve: Motion.ease,
    reverseAnimationCurve: Curves.easeInCubic,
    backgroundColor: AppColors.text,
    colorText: Colors.white,
    borderRadius: 18,
    boxShadows: const [BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 8))],
    margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
    maxWidth: 560,
  );
}
