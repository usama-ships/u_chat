import 'package:flutter/material.dart';

import '../../../core/utils/time_format.dart';
import '../../../data/models/conversation_with_peer.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.isConnected = false,
  });

  final ConversationWithPeer item;
  final bool isConnected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conversation = item.conversation;
    final unread = conversation.unreadCount;
    final lastAt = conversation.lastMessageAt;
    final name = item.peer.displayName;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: Badge(
        isLabelVisible: isConnected,
        backgroundColor: Colors.green,
        smallSize: 12,
        alignment: AlignmentDirectional.bottomEnd,
        child: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase()),
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (item.peer.verified) ...[
            const SizedBox(width: 4),
            Icon(Icons.verified, size: 16, color: theme.colorScheme.primary, semanticLabel: 'Verified'),
          ],
          if (item.peer.blocked) ...[
            const SizedBox(width: 4),
            Icon(Icons.block, size: 16, color: theme.colorScheme.error, semanticLabel: 'Blocked'),
          ],
        ],
      ),
      subtitle: Text(
        conversation.lastMessagePreview ?? 'No messages yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: unread > 0 ? const TextStyle(fontWeight: FontWeight.w600) : null,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastAt != null)
            Text(
              formatConversationTime(lastAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: unread > 0 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Badge(
              label: Text(unread > 99 ? '99+' : '$unread'),
              backgroundColor: theme.colorScheme.primary,
              textColor: theme.colorScheme.onPrimary,
            ),
          ],
        ],
      ),
    );
  }
}
