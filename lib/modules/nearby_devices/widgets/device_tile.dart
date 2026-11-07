import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/buttons.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/peer_avatar.dart';
import '../../../app/widgets/pressable.dart';
import '../../../core/bluetooth/models/discovered_device.dart';
import '../controllers/nearby_controller.dart';

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
    final status = switch (linkState) {
      DeviceLinkState.connected => 'Connected',
      DeviceLinkState.connecting => 'Connecting…',
      DeviceLinkState.available => 'ID ${device.deviceIdPrefix}…',
    };
    return Pressable(
      onTap: linkState == DeviceLinkState.connecting ? null : onAction,
      pressedScale: 0.98,
      child: GlassPanel(
        radius: 22,
        rim: linkState == DeviceLinkState.connected ? AppColors.bronzeRim : null,
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
        child: Row(
          children: [
            PeerAvatar(
              seed: device.deviceIdPrefix,
              name: name,
              size: 46,
              online: linkState == DeviceLinkState.connected,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (isKnown) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.history_rounded,
                          size: 15,
                          color: AppColors.bronze400,
                          semanticLabel: 'Known contact',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _SignalBars(bars: device.signalBars),
                      const SizedBox(width: 7),
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: Motion.medium,
                          layoutBuilder: startAlignedLayout,
                          transitionBuilder: fadeLiftTransition,
                          child: Text(
                            status,
                            key: ValueKey(status),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: linkState == DeviceLinkState.connected
                                  ? AppColors.bronze300
                                  : AppColors.silver400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: Motion.medium,
              transitionBuilder: popTransition,
              child: switch (linkState) {
                DeviceLinkState.connecting => const Padding(
                    key: ValueKey('busy'),
                    padding: EdgeInsets.all(9),
                    child: BusySpinner(),
                  ),
                DeviceLinkState.connected => GhostButton(
                    key: const ValueKey('chat'),
                    label: 'Chat',
                    dense: true,
                    onPressed: onAction,
                  ),
                DeviceLinkState.available => ChromeButton(
                    key: const ValueKey('connect'),
                    label: 'Connect',
                    dense: true,
                    glint: false,
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

/// Four small bars that rise and fall with the signal.
class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.bars});

  final int bars;

  @override
  Widget build(BuildContext context) {
    final label = switch (bars) {
      3 => 'Strong signal',
      2 => 'Good signal',
      1 => 'Weak signal',
      _ => 'Very weak signal',
    };
    return Semantics(
      label: label,
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
                  color: i <= bars ? AppColors.bronze400 : Colors.white.withValues(alpha: 0.14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
