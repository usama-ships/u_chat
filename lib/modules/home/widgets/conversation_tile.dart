import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/peer_avatar.dart';
import '../../../app/widgets/surfaces.dart';
import '../../../core/utils/time_format.dart';
import '../../../data/models/conversation_with_peer.dart';

/// One conversation in the home list: a full-width row that tints lavender
/// when pressed, like the chat lists people already know.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.isConnected = false,
    this.horizontalPadding = 16,
  });

  final ConversationWithPeer item;
  final bool isConnected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conversation = item.conversation;
    final unread = conversation.unreadCount;
    final lastAt = conversation.lastMessageAt;
    final name = item.peer.displayName;
    final preview = conversation.lastMessagePreview ?? 'No messages yet';

    return TapHighlight(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 11),
        child: Row(
          children: [
            PeerAvatar(
              seed: item.peer.id,
              name: name,
              size: 50,
              online: isConnected,
              heroTag: 'avatar-${item.peer.id}',
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
                              ),
                            ),
                            if (item.peer.verified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: AppColors.accentLight,
                                semanticLabel: 'Verified',
                              ),
                            ],
                            if (item.peer.blocked) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.block_rounded,
                                size: 15,
                                color: AppColors.danger,
                                semanticLabel: 'Blocked',
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (lastAt != null) ...[
                        const SizedBox(width: 8),
                        AnimatedDefaultTextStyle(
                          duration: Motion.medium,
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: unread > 0 ? AppColors.accent : AppColors.textMuted,
                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                          ),
                          child: Text(formatConversationTime(lastAt)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: Motion.medium,
                          layoutBuilder: startAlignedLayout,
                          transitionBuilder: fadeLiftTransition,
                          child: Text(
                            preview,
                            key: ValueKey(preview),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: unread > 0 ? AppColors.textSecondary : AppColors.textMuted,
                              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: Motion.medium,
                        transitionBuilder: popTransition,
                        child: unread > 0
                            ? Padding(
                                key: ValueKey(unread),
                                padding: const EdgeInsets.only(left: 8),
                                child: _UnreadBadge(count: unread),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(11),
        boxShadow: const [BoxShadow(color: Color(0x40F0506E), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: AppColors.onAccent,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
