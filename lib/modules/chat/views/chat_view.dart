import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/time_format.dart';
import '../../../data/models/delivery_status.dart';
import '../controllers/chat_controller.dart';
import '../widgets/message_bubble.dart';

class ChatView extends GetView<ChatController> {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const _ChatTitle(),
        actions: [
          Obx(() => PopupMenuButton<void>(
                itemBuilder: (_) => [
                  PopupMenuItem(onTap: controller.openContact, child: const Text('Contact info')),
                  if (controller.isConnected)
                    PopupMenuItem(onTap: controller.disconnect, child: const Text('Disconnect')),
                ],
              )),
        ],
      ),
      body: Obx(() {
        if (!controller.isLoaded.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!controller.hasValidConversation || controller.conversation.value == null) {
          return const Center(child: Text('Conversation not found'));
        }
        return Column(
          children: [
            const _ConnectionBanner(),
            const Expanded(child: _MessageList()),
            controller.isBlocked ? const _BlockedBar() : const _Composer(),
          ],
        );
      }),
    );
  }
}

class _ChatTitle extends GetView<ChatController> {
  const _ChatTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: controller.openContact,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Obx(() {
          final peer = controller.conversation.value?.peer;
          final connected = controller.isConnected;
          final latency = controller.latencyMs;
          final status = connected
              ? (latency == null ? 'Connected · encrypted' : 'Connected · encrypted · $latency ms')
              : controller.isConnecting
                  ? 'Connecting…'
                  : 'Not connected';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(peer?.displayName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (peer?.verified ?? false) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.verified, size: 18, color: theme.colorScheme.primary, semanticLabel: 'Verified'),
                  ],
                ],
              ),
              Text(
                status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: connected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _ConnectionBanner extends GetView<ChatController> {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      if (controller.isConnected || controller.isBlocked) return const SizedBox.shrink();
      final connecting = controller.isConnecting;
      return Material(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: Row(
            children: [
              Icon(Icons.bluetooth_disabled, size: 18, color: scheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  connecting
                      ? 'Looking for this device nearby…'
                      : 'Not connected. Messages are sent automatically once connected.',
                  style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 13),
                ),
              ),
              if (connecting)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                TextButton(onPressed: controller.connect, child: const Text('Connect')),
            ],
          ),
        ),
      );
    });
  }
}

class _MessageList extends GetView<ChatController> {
  const _MessageList();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = controller.messages;
      if (items.isEmpty) {
        return const Center(child: Text('No messages yet. Say hi!'));
      }
      final hasMore = controller.hasMore.value;
      // reverse: true keeps the list anchored to the newest message.
      return ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: items.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return Center(
              child: TextButton(onPressed: controller.loadMore, child: const Text('Load earlier messages')),
            );
          }
          final position = items.length - 1 - index; // chronological index
          final message = items[position];
          final showDay = position == 0 || !isSameDay(items[position - 1].sortAt, message.sortAt);
          final bubble = MessageBubble(
            message: message,
            onRetry: () => controller.retry(message),
            onLongPress: () => _showActions(context, message),
          );
          if (!showDay) return bubble;
          return Column(children: [_DayChip(label: formatDayLabel(message.sortAt)), bubble]);
        },
      );
    });
  }

  void _showActions(BuildContext context, Message message) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy text'),
              onTap: () {
                Navigator.pop(sheetContext);
                controller.copy(message);
              },
            ),
            if (message.isOutgoing && message.status == DeliveryStatus.failed)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Retry sending'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  controller.retry(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(_details(message)),
            ),
          ],
        ),
      ),
    );
  }

  String _details(Message m) {
    final when = '${formatDayLabel(m.sortAt)} ${formatMessageTime(m.sortAt)}';
    if (!m.isOutgoing) return 'Received $when';
    final status = switch (m.status) {
      DeliveryStatus.pending => 'Waiting for connection',
      DeliveryStatus.sending => 'Sending',
      DeliveryStatus.sent => 'Sent, waiting for confirmation',
      DeliveryStatus.delivered => 'Delivered',
      DeliveryStatus.failed => 'Not delivered',
      DeliveryStatus.received => 'Received',
    };
    return '$status · $when';
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ),
      ),
    );
  }
}

class _BlockedBar extends GetView<ChatController> {
  const _BlockedBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Expanded(child: Text('You blocked this contact.')),
            TextButton(onPressed: controller.unblock, child: const Text('Unblock')),
          ],
        ),
      ),
    );
  }
}

class _Composer extends GetView<ChatController> {
  const _Composer();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller.inputController,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(AppConstants.maxTextLength)],
                decoration: const InputDecoration(hintText: 'Message'),
              ),
            ),
            const SizedBox(width: 8),
            Obx(() => IconButton.filled(
                  tooltip: 'Send',
                  icon: const Icon(Icons.send),
                  onPressed: controller.canSend.value && !controller.isSending.value
                      ? controller.send
                      : null,
                )),
          ],
        ),
      ),
    );
  }
}
