import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// Full-area message for empty, error and permission states.
class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.illustration,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  /// Replaces the icon badge.
  final Widget? illustration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = MediaQuery.paddingOf(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(32, inset.top + 24, 32, inset.bottom + 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Entrance(child: illustration ?? _Badge(icon: icon)),
              const SizedBox(height: 24),
              Entrance(
                delay: const Duration(milliseconds: 60),
                child: Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              ),
              if (body != null) ...[
                const SizedBox(height: 8),
                Entrance(
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    body!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 26),
                Entrance(delay: const Duration(milliseconds: 140), child: action!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accentSoft),
      child: Icon(icon, size: 36, color: AppColors.accentLight),
    );
  }
}
