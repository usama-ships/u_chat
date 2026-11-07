import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/buttons.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/overlays.dart';
import '../../../app/widgets/peer_avatar.dart';
import '../../../app/widgets/pressable.dart';
import '../../../app/widgets/responsive.dart';
import '../../../app/widgets/silver_backdrop.dart';
import '../../../app/widgets/status_view.dart';
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
    return GlassScaffold(
      resizeForKeyboard: false,
      appBar: GlassBar(
        title: const _ChatTitle(),
        actions: [
          Obx(() {
            // Read here, not in itemBuilder: that runs later, outside this Obx.
            final connected = controller.isConnected;
            return PopupMenuButton<void>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert_rounded, color: AppColors.silver200),
              itemBuilder: (_) => [
                PopupMenuItem(onTap: controller.openContact, child: const Text('Contact info')),
                if (connected)
                  PopupMenuItem(onTap: controller.disconnect, child: const Text('Disconnect')),
              ],
            );
          }),
        ],
      ),
      bottomBar: Obx(() {
        final ready = controller.isLoaded.value && controller.conversation.value != null;
        return AnimatedSwitcher(
          duration: Motion.medium,
          transitionBuilder: fadeLiftTransition,
          child: !ready
              ? const SizedBox.shrink()
              : controller.isBlocked
              ? const _BlockedBar(key: ValueKey('blocked'))
              : const _Composer(key: ValueKey('composer')),
        );
      }),
      body: Obx(() {
        if (!controller.isLoaded.value) {
          return const Center(child: BusySpinner(size: 26));
        }
        if (!controller.hasValidConversation || controller.conversation.value == null) {
          return const StatusView(icon: Icons.forum_outlined, title: 'Conversation not found');
        }
        return const Stack(
          children: [
            Positioned.fill(child: _MessageList()),
            _ConnectionBanner(),
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
    return Pressable(
      onTap: controller.openContact,
      pressedScale: 0.985,
      semanticLabel: 'Contact info',
      child: Obx(() {
        final peer = controller.conversation.value?.peer;
        final connected = controller.isConnected;
        final latency = controller.latencyMs;
        final status = connected
            ? (latency == null ? 'Connected · encrypted' : 'Connected · encrypted · $latency ms')
            : controller.isConnecting
            ? 'Connecting…'
            : 'Not connected';
        return Row(
          children: [
            if (peer != null) ...[
              PeerAvatar(
                seed: peer.id,
                name: peer.displayName,
                size: 38,
                online: connected,
                heroTag: 'avatar-${peer.id}',
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          peer?.displayName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (peer?.verified ?? false) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: AppColors.bronze400,
                          semanticLabel: 'Verified',
                        ),
                      ],
                    ],
                  ),
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    layoutBuilder: startAlignedLayout,
                    transitionBuilder: fadeLiftTransition,
                    child: Text(
                      status,
                      key: ValueKey(status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: connected ? AppColors.bronze300 : AppColors.silver400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Floating notice shown while the contact isn't connected.
class _ConnectionBanner extends GetView<ChatController> {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gutter = Responsive.gutter(context);
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 10,
      left: gutter,
      right: gutter,
      child: Obx(() {
        final hidden = controller.isConnected || controller.isBlocked;
        final connecting = controller.isConnecting;
        return AnimatedSwitcher(
          duration: Motion.medium,
          switchInCurve: Motion.ease,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, child: child),
          ),
          child: hidden
              ? const SizedBox(key: ValueKey('hidden'), width: double.infinity)
              : GlassPanel(
                  key: const ValueKey('banner'),
                  radius: 18,
                  blur: true,
                  fill: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.graphite700.withValues(alpha: 0.94),
                      AppColors.graphite800.withValues(alpha: 0.90),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bluetooth_disabled_rounded,
                        size: 18,
                        color: AppColors.silver300,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: Motion.medium,
                          layoutBuilder: startAlignedLayout,
                          child: Text(
                            connecting
                                ? 'Looking for this device nearby…'
                                : 'Messages send automatically once connected.',
                            key: ValueKey(connecting),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: Motion.medium,
                        transitionBuilder: popTransition,
                        child: connecting
                            ? const Padding(
                                key: ValueKey('busy'),
                                padding: EdgeInsets.all(9),
                                child: BusySpinner(),
                              )
                            : ChromeButton(
                                key: const ValueKey('connect'),
                                label: 'Connect',
                                dense: true,
                                onPressed: controller.connect,
                              ),
                      ),
                    ],
                  ),
                ),
        );
      }),
    );
  }
}

class _MessageList extends StatefulWidget {
  const _MessageList();

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  /// Consecutive messages this close together read as one group.
  static const _groupWindowMs = 3 * 60 * 1000;
  static const _introCount = 10;

  final controller = Get.find<ChatController>();

  // Each message animates once, not every time it scrolls back into view.
  final _known = <String>{};
  final _arriving = <String>{};
  final _intro = <String, int>{};
  bool _primed = false;
  int _newestAt = 0;

  void _trackArrivals(List<Message> items) {
    if (items.isEmpty) return;
    if (!_primed) {
      _primed = true;
      final start = math.max(0, items.length - _introCount);
      for (var i = start; i < items.length; i++) {
        _intro[items[i].id] = items.length - 1 - i;
      }
    } else {
      for (final message in items) {
        // Older pages being loaded in are not arrivals.
        if (!_known.contains(message.id) && message.sortAt >= _newestAt) {
          _arriving.add(message.id);
        }
      }
    }
    _known.addAll(items.map((m) => m.id));
    _newestAt = math.max(_newestAt, items.last.sortAt);
  }

  bool _sameGroup(Message a, Message b) =>
      a.isOutgoing == b.isOutgoing &&
      (a.sortAt - b.sortAt).abs() < _groupWindowMs &&
      isSameDay(a.sortAt, b.sortAt);

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    final gutter = Responsive.gutter(context);
    return Obx(() {
      final items = controller.messages;
      _trackArrivals(items);
      if (items.isEmpty) return const _EmptyChat();

      final hasMore = controller.hasMore.value;
      final notConnected = !controller.isConnected && !controller.isBlocked;
      final indexById = <String, int>{
        for (var i = 0; i < items.length; i++) items[i].id: items.length - 1 - i,
      };

      // reverse: true keeps the list anchored to the newest message.
      return ListView.builder(
        reverse: true,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.fromLTRB(
          gutter,
          inset.top + (notConnected ? 76 : 12),
          gutter,
          inset.bottom + 10,
        ),
        itemCount: items.length + (hasMore ? 1 : 0),
        findChildIndexCallback: (key) {
          final value = (key as ValueKey<String>).value;
          return indexById[value];
        },
        itemBuilder: (context, index) {
          if (index == items.length) {
            return Center(
              key: const ValueKey('load-more'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: GhostButton(
                  label: 'Load earlier messages',
                  dense: true,
                  onPressed: controller.loadMore,
                ),
              ),
            );
          }
          final position = items.length - 1 - index; // chronological index
          final message = items[position];
          final previous = position > 0 ? items[position - 1] : null;
          final next = position < items.length - 1 ? items[position + 1] : null;
          final showDay = previous == null || !isSameDay(previous.sortAt, message.sortAt);

          final introOrder = _intro.remove(message.id);
          final bubble = MessageBubble(
            message: message,
            groupedWithPrevious: !showDay && _sameGroup(previous, message),
            groupedWithNext: next != null && _sameGroup(message, next),
            arriving: _arriving.remove(message.id),
            introDelay: introOrder == null ? null : Duration(milliseconds: 32 * introOrder),
            onRetry: () => controller.retry(message),
            onLongPress: () => _showActions(context, message),
          );
          return KeyedSubtree(
            key: ValueKey(message.id),
            child: showDay
                ? Column(
                    children: [
                      _DayChip(label: formatDayLabel(message.sortAt)),
                      bubble,
                    ],
                  )
                : bubble,
          );
        },
      );
    });
  }

  void _showActions(BuildContext context, Message message) {
    showGlassSheet(
      context,
      (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTile(
            icon: Icons.copy_rounded,
            title: 'Copy text',
            onTap: () {
              Navigator.pop(sheetContext);
              controller.copy(message);
            },
          ),
          if (message.isOutgoing && message.status == DeliveryStatus.failed)
            GlassTile(
              icon: Icons.refresh_rounded,
              iconColor: AppColors.bronze400,
              title: 'Retry sending',
              onTap: () {
                Navigator.pop(sheetContext);
                controller.retry(message);
              },
            ),
          GlassTile(icon: Icons.info_outline_rounded, title: _details(message)),
        ],
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

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const StatusView(
      icon: Icons.lock_outline_rounded,
      title: 'Say hi',
      body: 'Messages here are end-to-end encrypted and travel directly between phones.',
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: GlassPill(
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.silver300),
        ),
      ),
    );
  }
}

/// Frosted strip along the bottom of the chat. Rides on top of the keyboard.
class _BottomGlass extends StatelessWidget {
  const _BottomGlass({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final gutter = Responsive.gutter(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.graphite800.withValues(alpha: 0.62),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.09))),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: SafeArea(
              top: false,
              bottom: keyboard == 0,
              child: Padding(padding: EdgeInsets.fromLTRB(gutter, 10, gutter, 10), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockedBar extends GetView<ChatController> {
  const _BlockedBar({super.key});

  @override
  Widget build(BuildContext context) {
    return _BottomGlass(
      child: Row(
        children: [
          const Icon(Icons.block_rounded, size: 18, color: AppColors.clay),
          const SizedBox(width: 10),
          const Expanded(child: Text('You blocked this contact.')),
          GhostButton(label: 'Unblock', dense: true, onPressed: controller.unblock),
        ],
      ),
    );
  }
}

class _Composer extends GetView<ChatController> {
  const _Composer({super.key});

  @override
  Widget build(BuildContext context) {
    return _BottomGlass(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: GlassPanel(
              radius: 24,
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: TextField(
                controller: controller.inputController,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(AppConstants.maxTextLength)],
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: const InputDecoration(hintText: 'Message'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Obx(
            () => _SendButton(
              onPressed: controller.canSend.value && !controller.isSending.value
                  ? controller.send
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dormant glass until there's something to send, then turns to polished
/// metal and tilts up, ready to go.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ready = onPressed != null;
    return Tooltip(
      message: 'Send',
      child: Pressable(
        onTap: onPressed,
        pressedScale: 0.86,
        semanticLabel: 'Send',
        child: AnimatedScale(
          duration: Motion.medium,
          curve: Motion.pop,
          scale: ready ? 1 : 0.92,
          child: AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.ease,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: ready ? AppColors.silverMetal : AppColors.glassFill,
              border: Border.all(color: Colors.white.withValues(alpha: ready ? 0.3 : 0.1)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.silver300.withValues(alpha: ready ? 0.28 : 0),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedRotation(
              duration: Motion.medium,
              curve: Motion.pop,
              turns: ready ? -0.08 : 0,
              child: Icon(
                Icons.send_rounded,
                size: 21,
                color: ready ? AppColors.graphite900 : AppColors.silver500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
