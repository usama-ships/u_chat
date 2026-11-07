import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'glass.dart';
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

  /// Replaces the icon orb.
  final Widget? illustration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = MediaQuery.paddingOf(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(32, inset.top + 24, 32, inset.bottom + 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Entrance(child: illustration ?? _Orb(icon: icon)),
              const SizedBox(height: 24),
              Entrance(
                delay: const Duration(milliseconds: 80),
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              if (body != null) ...[
                const SizedBox(height: 8),
                Entrance(
                  delay: const Duration(milliseconds: 140),
                  child: Text(
                    body!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.silver300),
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 24),
                Entrance(delay: const Duration(milliseconds: 200), child: action!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Looping(
      period: const Duration(milliseconds: 2600),
      reverse: true,
      restingValue: 0.5,
      child: SizedBox(
        width: 88,
        height: 88,
        child: GlassPanel(
          radius: 44,
          child: Center(child: Icon(icon, size: 36, color: AppColors.silver200)),
        ),
      ),
      builder: (context, t, child) {
        final eased = Curves.easeInOut.transform(t);
        return Transform.translate(offset: Offset(0, -4 * eased), child: child);
      },
    );
  }
}
