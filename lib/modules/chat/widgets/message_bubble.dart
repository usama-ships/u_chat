import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/time_format.dart';
import '../../../data/models/delivery_status.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.onRetry, this.onLongPress});

  final Message message;

  /// Called when the user taps a failed outgoing message.
  final VoidCallback? onRetry;

  /// Opens the message actions (copy, retry, details).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outgoing = message.isOutgoing;
    final failed = outgoing && message.status == DeliveryStatus.failed;
    final background = outgoing ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final foreground = outgoing ? scheme.onPrimaryContainer : scheme.onSurface;

    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: _bubble(context, background, foreground, outgoing),
    );
    if (!failed) return bubble;
    return GestureDetector(
      onTap: onRetry,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          bubble,
          Padding(
            padding: const EdgeInsets.only(bottom: 4, right: 4),
            child: Text(
              'Not delivered · Tap to retry',
              style: TextStyle(color: scheme.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, Color background, Color foreground, bool outgoing) {
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(outgoing ? 16 : 4),
              bottomRight: Radius.circular(outgoing ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(message.content, style: TextStyle(color: foreground, fontSize: 15)),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatMessageTime(message.sortAt),
                    style: TextStyle(color: foreground.withValues(alpha: 0.7), fontSize: 11),
                  ),
                  if (outgoing) ...[
                    const SizedBox(width: 4),
                    _StatusIcon(status: message.status, color: foreground.withValues(alpha: 0.7)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status, required this.color});

  final DeliveryStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color tint) = switch (status) {
      DeliveryStatus.pending => (Icons.schedule, 'Pending', color),
      DeliveryStatus.sending => (Icons.upload, 'Sending', color),
      DeliveryStatus.sent => (Icons.done, 'Sent', color),
      DeliveryStatus.delivered => (Icons.done_all, 'Delivered', Theme.of(context).colorScheme.primary),
      DeliveryStatus.failed => (Icons.error_outline, 'Failed', Theme.of(context).colorScheme.error),
      DeliveryStatus.received => (Icons.done, 'Received', color),
    };
    return Icon(icon, size: 14, color: tint, semanticLabel: label);
  }
}
