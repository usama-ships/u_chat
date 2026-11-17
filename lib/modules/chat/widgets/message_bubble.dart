import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/pressable.dart';
import '../../../app/widgets/responsive.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/voice/voice_meta.dart';
import '../../../data/models/delivery_status.dart';
import '../../../data/models/message_type.dart';
import 'voice_bubble.dart';

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.avatar,
    this.groupedWithPrevious = false,
    this.groupedWithNext = false,
    this.arriving = false,
    this.introDelay,
    this.onRetry,
    this.onLongPress,
  });

  final Message message;

  /// The sender's picture, shown beside the last of their messages in a group.
  final Widget? avatar;

  /// Same sender, moments before: tightens the gap and the corner above.
  final bool groupedWithPrevious;

  /// Same sender, moments after: tightens the corner below.
  final bool groupedWithNext;

  /// True for a message that has just appeared in an open chat. It grows into
  /// the list, gently pushing the older messages up.
  final bool arriving;

  /// Set for the newest messages when the chat first opens.
  final Duration? introDelay;

  /// Called when the user taps a failed outgoing message.
  final VoidCallback? onRetry;

  /// Opens the message actions (copy, retry, details).
  final VoidCallback? onLongPress;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> with SingleTickerProviderStateMixin {
  // Decided once: later rebuilds must keep the same widget tree, or everything
  // inside the bubble would restart.
  late final bool _grows = widget.arriving;
  late final Duration? _introDelay = widget.introDelay;

  late final AnimationController _arrival = AnimationController(
    vsync: this,
    duration: Motion.slow,
    value: _grows ? 0 : 1,
  );
  late final Animation<double> _grow = CurvedAnimation(parent: _arrival, curve: Motion.ease);
  late final Animation<double> _pop = CurvedAnimation(parent: _arrival, curve: Motion.pop);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_grows) return;
    if (Motion.isReduced(context)) {
      _arrival.value = 1;
    } else if (!_arrival.isAnimating && _arrival.value == 0) {
      _arrival.forward();
    }
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final outgoing = message.isOutgoing;
    final failed = outgoing && message.status == DeliveryStatus.failed;
    final side = outgoing ? Alignment.bottomRight : Alignment.bottomLeft;

    Widget content = Column(
      crossAxisAlignment: outgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Pressable(
          onLongPress: widget.onLongPress,
          onTap: failed ? widget.onRetry : null,
          pressedScale: 0.98,
          child: _Bubble(
            message: message,
            groupedWithPrevious: widget.groupedWithPrevious,
            groupedWithNext: widget.groupedWithNext,
          ),
        ),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.ease,
          alignment: Alignment.topRight,
          child: failed
              ? ShakeOnce(child: _RetryHint(onTap: widget.onRetry))
              : const SizedBox(width: double.infinity),
        ),
      ],
    );

    final avatar = widget.avatar;
    if (!outgoing && avatar != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: 30, child: widget.groupedWithNext ? null : avatar),
          const SizedBox(width: 8),
          Flexible(child: content),
        ],
      );
    }

    content = Padding(
      padding: EdgeInsets.only(top: widget.groupedWithPrevious ? 3 : 10),
      child: Align(
        alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: content,
      ),
    );

    if (_introDelay != null) {
      return Entrance(
        delay: _introDelay,
        offset: const Offset(0, 14),
        duration: Motion.medium,
        child: content,
      );
    }
    if (!_grows) return content;
    return SizeTransition(
      sizeFactor: _grow,
      alignment: Alignment.bottomCenter,
      child: FadeTransition(
        opacity: _grow,
        child: ScaleTransition(scale: _pop, alignment: side, child: content),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.groupedWithPrevious,
    required this.groupedWithNext,
  });

  final Message message;
  final bool groupedWithPrevious;
  final bool groupedWithNext;

  @override
  Widget build(BuildContext context) {
    final outgoing = message.isOutgoing;
    const full = Radius.circular(22);
    const tight = Radius.circular(8);
    // The corner nearest the sender points at them, sharpest on the last message.
    final tail = Radius.circular(groupedWithNext ? 8 : 6);
    final radius = BorderRadius.only(
      topLeft: !outgoing && groupedWithPrevious ? tight : full,
      topRight: outgoing && groupedWithPrevious ? tight : full,
      bottomLeft: outgoing ? full : tail,
      bottomRight: outgoing ? tail : full,
    );
    final ink = outgoing ? AppColors.onAccent : AppColors.text;
    final meta = outgoing ? AppColors.onAccent.withValues(alpha: 0.72) : AppColors.textMuted;
    final voice = _voiceMeta(message);
    final footer = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatMessageTime(message.sortAt),
          style: TextStyle(color: meta, fontSize: 11, fontWeight: FontWeight.w500),
        ),
        if (outgoing) ...[
          const SizedBox(width: 4),
          _StatusIcon(status: message.status, color: meta),
        ],
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: Responsive.bubbleWidth(context)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: outgoing ? AppColors.accentGradient : null,
          color: outgoing ? null : AppColors.bubbleIn,
          border: outgoing ? null : Border.all(color: AppColors.glassBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 10, 12, 8),
          // Short messages keep the time on the same line; long ones wrap it
          // to the bottom right.
          child: voice != null
              ? VoiceBubble(message: message, meta: voice, footer: footer)
              : Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 10,
                  runSpacing: 2,
                  children: [
                    Text(
                      message.content,
                      style: TextStyle(
                        color: ink,
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: outgoing ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                    footer,
                  ],
                ),
        ),
      ),
    );
  }
}

/// Null for anything but a readable voice message.
VoiceMeta? _voiceMeta(Message message) {
  if (message.type != MessageType.voice) return null;
  try {
    return VoiceMeta.decode(message.content);
  } on FormatException {
    return null;
  }
}

class _RetryHint extends StatelessWidget {
  const _RetryHint({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.only(top: 4, right: 4, bottom: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, size: 14, color: AppColors.danger),
            SizedBox(width: 4),
            Text(
              'Not delivered · Tap to retry',
              style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
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
      DeliveryStatus.pending => (Icons.schedule_rounded, 'Pending', color),
      DeliveryStatus.sending => (Icons.arrow_upward_rounded, 'Sending', color),
      DeliveryStatus.sent => (Icons.done_rounded, 'Sent', color),
      DeliveryStatus.transferring => (Icons.done_rounded, 'Sending audio', color),
      DeliveryStatus.delivered => (Icons.done_all_rounded, 'Delivered', AppColors.onAccent),
      DeliveryStatus.failed => (Icons.error_outline_rounded, 'Failed', const Color(0xFFFFD1DA)),
      DeliveryStatus.received => (Icons.done_rounded, 'Received', color),
    };
    return AnimatedSwitcher(
      duration: Motion.medium,
      transitionBuilder: popTransition,
      child: Icon(icon, key: ValueKey(status), size: 15, color: tint, semanticLabel: label),
    );
  }
}
