import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/time_format.dart';
import '../controllers/contact_controller.dart';

class ContactView extends GetView<ContactController> {
  const ContactView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Contact')),
      body: Obx(() {
        if (!controller.isLoaded.value) return const Center(child: CircularProgressIndicator());
        final peer = controller.peer.value;
        if (peer == null) return const Center(child: Text('Contact not found'));
        final safety = controller.safetyNumberText;
        final connected = controller.isConnected;

        return ListView(
          children: [
            const SizedBox(height: 24),
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Text(peer.displayName.characters.first.toUpperCase(),
                    style: const TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(peer.displayName,
                      style: theme.textTheme.headlineSmall, overflow: TextOverflow.ellipsis),
                ),
                if (peer.verified) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified, color: theme.colorScheme.primary, semanticLabel: 'Verified'),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                connected
                    ? 'Connected'
                    : controller.isConnecting
                        ? 'Connecting…'
                        : 'Last seen ${formatConversationTime(peer.lastSeenAt)}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: peer.blocked
                  ? const SizedBox.shrink()
                  : connected
                      ? OutlinedButton.icon(
                          onPressed: controller.disconnect,
                          icon: const Icon(Icons.bluetooth_disabled),
                          label: const Text('Disconnect'),
                        )
                      : FilledButton.icon(
                          onPressed: controller.isConnecting ? null : controller.connect,
                          icon: const Icon(Icons.bluetooth),
                          label: const Text('Connect'),
                        ),
            ),
            const Divider(height: 40),
            _Section(title: 'Safety number', children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: safety == null
                    ? const Text('Available after the first secure connection with this contact.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            safety,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontFamily: 'monospace',
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Compare this number with the one on ${peer.displayName}\'s phone, in person. '
                            'If they match, your connection is not being intercepted and you can '
                            'mark the contact as verified.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
              ),
              if (safety != null)
                SwitchListTile(
                  title: const Text('Verified'),
                  subtitle: const Text('I compared the safety numbers and they match'),
                  value: peer.verified,
                  onChanged: controller.setVerified,
                ),
            ]),
            _Section(title: 'Device', children: [
              ListTile(
                title: const Text('Device ID'),
                subtitle: SelectableText(peer.id, style: const TextStyle(fontFamily: 'monospace')),
              ),
            ]),
            _Section(title: 'Privacy', children: [
              SwitchListTile(
                secondary: const Icon(Icons.block),
                title: const Text('Block contact'),
                subtitle: const Text('Blocked contacts cannot connect or send you messages'),
                value: peer.blocked,
                onChanged: controller.setBlocked,
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                title: Text('Delete conversation', style: TextStyle(color: theme.colorScheme.error)),
                subtitle: const Text('Removes all messages with this contact from this phone'),
                onTap: () => _confirmDelete(context, peer.displayName),
              ),
            ]),
            const SizedBox(height: 24),
          ],
        );
      }),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text('All messages with $name will be removed from this phone. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteConversation();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        ),
        ...children,
      ],
    );
  }
}
