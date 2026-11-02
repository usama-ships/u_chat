import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/models/conversation_with_peer.dart';
import '../controllers/home_controller.dart';
import '../widgets/conversation_tile.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: controller.openSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.openNearby,
        icon: const Icon(Icons.bluetooth_searching),
        label: const Text('Nearby'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final error = controller.errorMessage.value;
        if (error != null) {
          return _CenteredMessage(icon: Icons.error_outline, title: error);
        }
        if (controller.conversations.isEmpty) {
          return const _CenteredMessage(
            icon: Icons.forum_outlined,
            title: 'No conversations yet',
            subtitle: 'Tap "Nearby" to find U Chat users around you.',
          );
        }
        return ListView.separated(
          itemCount: controller.conversations.length,
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
          itemBuilder: (_, index) {
            final item = controller.conversations[index];
            return Obx(() => ConversationTile(
                  item: item,
                  isConnected: controller.isConnected(item.peer.id),
                  onTap: () => controller.openConversation(item),
                  onLongPress: () => _confirmDelete(context, item),
                ));
          },
        );
      }),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, ConversationWithPeer item) async {
  final controller = Get.find<HomeController>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete conversation?'),
      content: Text(
        'All messages with ${item.peer.displayName} will be removed from this phone. '
        'This cannot be undone.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );
  if (confirmed == true) await controller.deleteConversation(item);
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
