import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/buttons.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/peer_avatar.dart';
import '../../../app/widgets/pressable.dart';
import '../../../app/widgets/surfaces.dart';
import '../../../core/bluetooth/models/discovered_device.dart';
import '../controllers/nearby_controller.dart';

/// How far away a phone seems, in words, from its signal bars.
String distanceLabel(int bars) => switch (bars) {
  3 => 'Very close',
  2 => 'Nearby',
  1 => 'In range',
  _ => 'Far away',
};

/// One discovered phone with its connect / chat action.
class DeviceTile extends StatelessWidget {
  const DeviceTile({
    super.key,
    required this.device,
    required this.isKnown,
    required this.linkState,
    required this.onAction,
  });

  final DiscoveredDevice device;
  final bool isKnown;
  final DeviceLinkState linkState;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = device.displayName;
    final connected = linkState == DeviceLinkState.connected;
    final status = switch (linkState) {
      DeviceLinkState.connected => 'Connected',
      DeviceLinkState.connecting => 'Connecting…',
      DeviceLinkState.available => distanceLabel(device.signalBars),
    };
    return Pressable(
      onTap: linkState == DeviceLinkState.connecting ? null : onAction,
      pressedScale: 0.98,
      child: Panel(
        radius: 20,
        borderColor: connected ? AppColors.accentBorder : AppColors.glassBorder,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            PeerAvatar(seed: device.deviceIdPrefix, name: name, size: 48, online: connected),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SignalBars(bars: device.signalBars),
                          const SizedBox(width: 6),
                          Flexible(
                            child: AnimatedSwitcher(
                              duration: Motion.medium,
                              transitionBuilder: fadeLiftTransition,
                              child: Text(
                                status,
                                key: ValueKey(status),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: connected ? AppColors.success : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isKnown) const _Tag(label: 'In your chats'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: Motion.medium,
              transitionBuilder: popTransition,
              child: switch (linkState) {
                DeviceLinkState.connecting => const Padding(
                  key: ValueKey('busy'),
                  padding: EdgeInsets.all(9),
                  child: BusySpinner(),
                ),
                DeviceLinkState.connected => SecondaryButton(
                  key: const ValueKey('chat'),
                  label: 'Chat',
                  icon: Icons.chat_bubble_outline_rounded,
                  dense: true,
                  onPressed: onAction,
                ),
                DeviceLinkState.available => PrimaryButton(
                  key: const ValueKey('connect'),
                  label: 'Connect',
                  dense: true,
                  onPressed: onAction,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.accentLight,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Four small bars that rise and fall with the signal.
class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.bars});

  final int bars;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 12,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 4; i++)
              AnimatedContainer(
                duration: Motion.medium,
                curve: Motion.ease,
                margin: const EdgeInsets.only(right: 2),
                width: 3,
                height: 3.0 + i * 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  color: i <= bars ? AppColors.accentLight : AppColors.glassBorder,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
