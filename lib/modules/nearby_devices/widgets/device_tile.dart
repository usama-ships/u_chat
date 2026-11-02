import 'package:flutter/material.dart';

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
    return ListTile(
      leading: Badge(
        isLabelVisible: linkState == DeviceLinkState.connected,
        backgroundColor: Colors.green,
        smallSize: 12,
        alignment: AlignmentDirectional.bottomEnd,
        child: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          foregroundColor: theme.colorScheme.onSecondaryContainer,
          child: Text(name.characters.first.toUpperCase()),
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (isKnown) ...[
            const SizedBox(width: 8),
            Icon(Icons.history, size: 16, color: theme.colorScheme.primary, semanticLabel: 'Known contact'),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          _SignalIcon(bars: device.signalBars),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              switch (linkState) {
                DeviceLinkState.connected => 'Connected',
                DeviceLinkState.connecting => 'Connecting…',
                DeviceLinkState.available => 'ID ${device.deviceIdPrefix}…',
              },
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
      trailing: switch (linkState) {
        DeviceLinkState.connecting => const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        DeviceLinkState.connected => FilledButton.tonal(onPressed: onAction, child: const Text('Chat')),
        DeviceLinkState.available => FilledButton(onPressed: onAction, child: const Text('Connect')),
      },
      onTap: linkState == DeviceLinkState.connecting ? null : onAction,
    );
  }
}

class _SignalIcon extends StatelessWidget {
  const _SignalIcon({required this.bars});

  final int bars;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (bars) {
      3 => (Icons.signal_cellular_alt, 'Strong signal'),
      2 => (Icons.signal_cellular_alt_2_bar, 'Good signal'),
      1 => (Icons.signal_cellular_alt_1_bar, 'Weak signal'),
      _ => (Icons.signal_cellular_0_bar, 'Very weak signal'),
    };
    return Icon(icon, size: 16, semanticLabel: label, color: Theme.of(context).colorScheme.primary);
  }
}
