import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/peer_avatar.dart';
import '../../../app/widgets/pressable.dart';
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
    final preview = conversation.lastMessagePreview ?? 'No messages yet';

    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      pressedScale: 0.98,
      child: GlassPanel(
        radius: 22,
        rim: unread > 0 ? AppColors.bronzeRim : null,
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        child: Row(
          children: [
            PeerAvatar(
              seed: item.peer.id,
              name: name,
              size: 50,
              online: isConnected,
              heroTag: 'avatar-${item.peer.id}',
            ),
            const SizedBox(width: 10),
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
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            if (item.peer.verified) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: AppColors.bronze400,
                                semanticLabel: 'Verified',
                              ),
                            ],
                            if (item.peer.blocked) ...[
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.block_rounded,
                                size: 16,
                                color: AppColors.clay,
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
                            color: unread > 0 ? AppColors.bronze300 : AppColors.silver400,
                          ),
                          child: Text(formatConversationTime(lastAt)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
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
                              color: unread > 0 ? AppColors.silver100 : AppColors.silver300,
                              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
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
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        gradient: AppColors.bronzeMetal,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [BoxShadow(color: AppColors.bronze400.withValues(alpha: 0.35), blurRadius: 10)],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: AppColors.graphite950,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
