import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/app_scaffold.dart';
import '../../../app/widgets/buttons.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/overlays.dart';
import '../../../app/widgets/peer_avatar.dart';
import '../../../app/widgets/pressable.dart';
import '../../../app/widgets/radar.dart';
import '../../../app/widgets/responsive.dart';
import '../../../app/widgets/status_view.dart';
import '../../../app/widgets/surfaces.dart';
import '../../../data/models/conversation_with_peer.dart';
import '../controllers/home_controller.dart';
import '../widgets/conversation_tile.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const _HomeHeader(),
      floatingActionButton: Obx(() {
        final show = !controller.isLoading.value && controller.conversations.isNotEmpty;
        return AnimatedScale(
          scale: show ? 1 : 0,
          duration: Motion.medium,
          curve: show ? Motion.pop : Curves.easeIn,
          child: _NewChatButton(onPressed: show ? controller.openNearby : null),
        );
      }),
      body: Obx(() {
        final Widget content;
        final error = controller.errorMessage.value;
        if (controller.isLoading.value) {
          content = const Center(key: ValueKey('loading'), child: BusySpinner(size: 26));
        } else if (error != null) {
          content = StatusView(
            key: const ValueKey('error'),
            icon: Icons.error_outline_rounded,
            title: error,
          );
        } else if (controller.conversations.isEmpty) {
          content = StatusView(
            key: const ValueKey('empty'),
            icon: Icons.forum_outlined,
            illustration: const ExcludeSemantics(
              child: SizedBox(width: 180, child: Radar(scanning: true)),
            ),
            title: 'No conversations yet',
            body: 'Find people around you. No internet, no accounts, nothing leaves your phone.',
            action: PrimaryButton(
              label: 'Find people nearby',
              icon: Icons.person_search_rounded,
              onPressed: controller.openNearby,
            ),
          );
        } else {
          content = const _ConversationList(key: ValueKey('list'));
        }
        return AnimatedSwitcher(duration: Motion.medium, child: content);
      }),
    );
  }
}

/// Greeting, unread count and the row of contacts, on the purple header.
class _HomeHeader extends GetView<HomeController> implements PreferredSizeWidget {
  const _HomeHeader();

  static const _height = 236.0;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Good night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gutter = Responsive.gutter(context);
    // The header has a fixed height, so its text grows only a little.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: OnHeader(
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: _height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 6, gutter - 4, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Align(alignment: Alignment.centerLeft, child: _PresenceChip()),
                      ),
                      RoundIconButton(
                        icon: Icons.tune_rounded,
                        tooltip: 'Settings',
                        filled: true,
                        onPressed: controller.openSettings,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
                  child: Entrance(
                    offset: const Offset(0, 12),
                    child: Obx(() {
                      final items = controller.conversations;
                      final unread = items.fold<int>(
                        0,
                        (sum, c) => sum + c.conversation.unreadCount,
                      );
                      final (String lead, String big) = unread > 0
                          ? (
                              '${_greeting()}, you received',
                              '$unread ${unread == 1 ? 'Message' : 'Messages'}',
                            )
                          : items.isEmpty
                          ? ('${_greeting()}, welcome to', 'Blue Chat')
                          : (
                              '${_greeting()}, you have',
                              '${items.length} ${items.length == 1 ? 'Chat' : 'Chats'}',
                            );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lead,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.onHeaderMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: Motion.medium,
                            layoutBuilder: startAlignedLayout,
                            transitionBuilder: fadeLiftTransition,
                            child: FittedBox(
                              key: ValueKey(big),
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                big,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: AppColors.onHeader,
                                  fontSize: 30,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 14),
                const Expanded(child: _ContactStrip()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted chip on the header: whether this phone can be found.
class _PresenceChip extends GetView<HomeController> {
  const _PresenceChip();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = controller.isPresent;
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
        decoration: BoxDecoration(
          color: AppColors.headerGlass,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.headerGlassBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseDot(
              active: active,
              size: 7,
              color: active ? AppColors.highlight : AppColors.onHeaderMuted,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: AnimatedSwitcher(
                duration: Motion.medium,
                layoutBuilder: startAlignedLayout,
                transitionBuilder: fadeLiftTransition,
                child: Text(
                  controller.presenceLabel,
                  key: ValueKey(controller.presenceLabel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onHeader,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// "Contacts": a sideways row of the people you chat with, after a button
/// to find someone new.
class _ContactStrip extends GetView<HomeController> {
  const _ContactStrip();

  @override
  Widget build(BuildContext context) {
    final gutter = Responsive.gutter(context);
    final stagger = Stagger(step: const Duration(milliseconds: 45));
    return Obx(() {
      final items = controller.conversations.take(12).toList();
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: gutter),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final Widget child;
          if (index == 0) {
            child = _StripItem(
              label: 'Nearby',
              onTap: controller.openNearby,
              avatar: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.headerGlass,
                  border: Border.all(color: AppColors.headerGlassBorder, width: 1.5),
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.onHeader, size: 26),
              ),
            );
          } else {
            final item = items[index - 1];
            final name = item.peer.displayName;
            child = Obx(
              () => _StripItem(
                label: name.split(' ').first,
                onTap: () => controller.openConversation(item),
                avatar: PeerAvatar(
                  seed: item.peer.id,
                  name: name,
                  size: 56,
                  online: controller.isConnected(item.peer.id),
                ),
              ),
            );
          }
          return Entrance(
            key: ValueKey(index == 0 ? 'nearby' : items[index - 1].conversation.id),
            delay: stagger.delayFor(index),
            offset: const Offset(18, 0),
            duration: Motion.medium,
            child: child,
          );
        },
      );
    });
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({required this.label, required this.avatar, required this.onTap});

  final String label;
  final Widget avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.92,
      semanticLabel: label,
      child: SizedBox(
        width: 60,
        child: Column(
          children: [
            avatar,
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.onHeader,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round "+" in the corner, for finding someone new.
class _NewChatButton extends StatelessWidget {
  const _NewChatButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Find people nearby',
      child: Pressable(
        onTap: onPressed,
        pressedScale: 0.9,
        semanticLabel: 'Find people nearby',
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.accentGradient,
            border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: AppColors.onAccent, size: 28),
        ),
      ),
    );
  }
}

enum _Filter { all, unread, online }

class _ConversationList extends StatefulWidget {
  const _ConversationList({super.key});

  @override
  State<_ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<_ConversationList> {
  final _stagger = Stagger(step: const Duration(milliseconds: 35));
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final inset = MediaQuery.paddingOf(context);
    final gutter = Responsive.gutter(context);
    return Obx(() {
      final all = controller.conversations;
      final unread = all.where((c) => c.conversation.unreadCount > 0).toList();
      final online = all.where((c) => controller.isConnected(c.peer.id)).toList();
      final items = switch (_filter) {
        _Filter.all => all.toList(),
        _Filter.unread => unread,
        _Filter.online => online,
      };
      final title = switch (_filter) {
        _Filter.all => 'All messages',
        _Filter.unread => 'Unread',
        _Filter.online => 'Online now',
      };
      return ListView.builder(
        // The bottom space keeps the last row clear of the "+" button.
        padding: EdgeInsets.only(top: 18, bottom: inset.bottom + 100),
        itemCount: items.isEmpty ? 3 : items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FilterBar(
              selected: _filter,
              counts: {
                _Filter.all: all.length,
                _Filter.unread: unread.length,
                _Filter.online: online.length,
              },
              onSelected: (value) => setState(() => _filter = value),
              padding: EdgeInsets.symmetric(horizontal: gutter),
            );
          }
          if (index == 1) {
            return Padding(
              padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 6),
              child: AnimatedSwitcher(
                duration: Motion.medium,
                layoutBuilder: startAlignedLayout,
                transitionBuilder: fadeLiftTransition,
                child: Text(
                  '$title (${items.length})',
                  key: ValueKey('$title${items.length}'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            );
          }
          if (items.isEmpty) {
            return Entrance(
              key: ValueKey('none-$_filter'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                child: Column(
                  children: [
                    Icon(
                      _filter == _Filter.unread
                          ? Icons.mark_chat_read_outlined
                          : Icons.bluetooth_disabled_rounded,
                      size: 34,
                      color: AppColors.textFaint,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _filter == _Filter.unread
                          ? 'You are all caught up'
                          : 'Nobody is connected right now',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }
          final item = items[index - 2];
          return Entrance(
            key: ValueKey('${_filter.name}-${item.conversation.id}'),
            delay: _stagger.delayFor(index - 2),
            offset: const Offset(0, 14),
            duration: Motion.medium,
            child: Obx(
              () => ConversationTile(
                item: item,
                horizontalPadding: gutter,
                isConnected: controller.isConnected(item.peer.id),
                onTap: () => controller.openConversation(item),
                onLongPress: () => _confirmDelete(context, item),
              ),
            ),
          );
        },
      );
    });
  }
}

/// All / Unread / Online pills. The selected one turns lemon.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.counts,
    required this.onSelected,
    required this.padding,
  });

  final _Filter selected;
  final Map<_Filter, int> counts;
  final ValueChanged<_Filter> onSelected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final filter in _Filter.values) ...[
            if (filter != _Filter.all) const SizedBox(width: 10),
            _FilterPill(
              label: switch (filter) {
                _Filter.all => 'All chats',
                _Filter.unread => 'Unread',
                _Filter.online => 'Online',
              },
              count: counts[filter] ?? 0,
              selected: filter == selected,
              onTap: () => onSelected(filter),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.94,
      semanticLabel: '$label, $count',
      child: AnimatedContainer(
        duration: Motion.medium,
        curve: Motion.ease,
        height: 40,
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
        decoration: BoxDecoration(
          color: selected ? AppColors.highlight : AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? const Color(0x1A1A1A1A) : AppColors.border),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x33E3DE4A), blurRadius: 14, offset: Offset(0, 5))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.onHighlight : AppColors.textSecondary,
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: Motion.medium,
              constraints: const BoxConstraints(minWidth: 24),
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.text : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmDelete(BuildContext context, ConversationWithPeer item) async {
  final controller = Get.find<HomeController>();
  final confirmed = await showConfirm(
    context,
    title: 'Delete conversation?',
    message:
        'All messages with ${item.peer.displayName} will be removed from this phone. '
        'This cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (confirmed) await controller.deleteConversation(item);
}
