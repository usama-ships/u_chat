import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/pressable.dart';
import '../../../app/widgets/responsive.dart';
import '../../../core/database/app_database.dart';
import '../../../core/voice/voice_meta.dart';
import '../../../data/models/delivery_status.dart';
import '../controllers/chat_controller.dart';
import 'signal_trace.dart';

/// The inside of a voice message bubble. [meta] comes from the message row;
/// everything live (progress, playback) is read from the controller.
class VoiceBubble extends GetView<ChatController> {
  const VoiceBubble({super.key, required this.message, required this.meta, required this.footer});

  final Message message;
  final VoiceMeta meta;

  /// Sent time and delivery ticks.
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final outgoing = message.isOutgoing;
    final ink = outgoing ? AppColors.graphite700 : AppColors.silver300;
    final playedColor = outgoing ? AppColors.bronze700 : AppColors.bronze400;

    return SizedBox(
      width: _width(context),
      child: Obx(() {
        final transfer = controller.voiceProgress(message.id);
        final failed = controller.voiceFailed(message.id);
        final path = controller.voicePath(message);
        final isCurrent = controller.currentVoiceId == message.id;
        final playing = isCurrent && controller.isVoicePlaying;
        final total = meta.durationMs;
        final positionMs = isCurrent ? controller.voicePosition.inMilliseconds : 0;
        final played = isCurrent ? (positionMs / total).clamp(0.0, 1.0) : 0.0;

        // On the receiving side the audio arrives bit by bit, so the trace
        // fills in. The sender has it all already.
        final available = outgoing || path != null ? 1.0 : (transfer ?? 0.0);
        final label = _statusLabel(transfer: transfer, failed: failed, path: path);

        return Row(
          children: [
            _PlayButton(
              outgoing: outgoing,
              playing: playing,
              // Sending shows on the ring too, but doesn't stop you listening.
              progress: _ringProgress(transfer, path),
              failed: failed,
              waiting: path == null && !failed,
              semanticLabel: failed
                  ? 'Retry downloading voice message'
                  : playing
                  ? 'Pause voice message'
                  : 'Play voice message, ${formatVoiceDuration(total)}',
              onTap: failed
                  ? () => controller.retryVoiceDownload(message)
                  : path == null
                  ? null
                  : () => controller.toggleVoice(message),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Scrubber(
                    enabled: isCurrent,
                    onSeek: (fraction) => controller.seekVoice(message, meta, fraction),
                    child: SignalTrace(
                      bars: meta.waveform,
                      color: outgoing ? AppColors.graphite600 : AppColors.silver400,
                      playedColor: playedColor,
                      played: played,
                      available: available,
                      showHead: isCurrent,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        formatVoiceDuration(isCurrent ? positionMs : total),
                        style: TextStyle(
                          color: ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (label == null)
                        const Spacer()
                      else ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: Motion.medium,
                            layoutBuilder: startAlignedLayout,
                            child: Text(
                              label,
                              key: ValueKey(failed),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: failed ? AppColors.clay : ink,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                      AnimatedSwitcher(
                        duration: Motion.medium,
                        transitionBuilder: popTransition,
                        child: isCurrent
                            ? _SpeedChip(
                                key: const ValueKey('speed'),
                                speed: controller.voiceSpeed,
                                outgoing: outgoing,
                                onTap: controller.cycleVoiceSpeed,
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(width: 6),
                      footer,
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  double _width(BuildContext context) {
    // Longer notes get a slightly longer bubble, up to what the screen allows.
    final max = Responsive.bubbleWidth(context) - 24;
    final byLength = 210 + meta.durationMs / 1000 * 2.2;
    return byLength.clamp(210.0, max < 210 ? 210.0 : max);
  }

  double? _ringProgress(double? transfer, String? path) {
    if (message.isOutgoing) {
      return message.status == DeliveryStatus.transferring ? (transfer ?? 0) : null;
    }
    return path == null ? (transfer ?? 0) : null;
  }

  String? _statusLabel({required double? transfer, required bool failed, required String? path}) {
    if (failed) return 'Retry';
    if (message.isOutgoing) {
      if (message.status == DeliveryStatus.transferring) {
        return '${((transfer ?? 0) * 100).round()}%';
      }
      return null;
    }
    if (path != null) return null;
    return transfer == null ? 'Waiting' : '${(transfer * 100).round()}%';
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.outgoing,
    required this.playing,
    required this.progress,
    required this.failed,
    required this.waiting,
    required this.semanticLabel,
    required this.onTap,
  });

  final bool outgoing;
  final bool playing;
  final double? progress;
  final bool failed;
  final bool waiting;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = failed
        ? Icons.refresh_rounded
        : waiting
        ? Icons.south_rounded
        : playing
        ? Icons.pause_rounded
        : Icons.play_arrow_rounded;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      semanticLabel: semanticLabel,
      child: SizedBox(
        width: 46,
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: Motion.medium,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: outgoing ? null : AppColors.silverMetal,
                color: outgoing ? AppColors.graphite800 : null,
              ),
              child: AnimatedSwitcher(
                duration: Motion.fast,
                transitionBuilder: popTransition,
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  size: 24,
                  color: outgoing ? AppColors.silver100 : AppColors.graphite900,
                ),
              ),
            ),
            if (progress != null)
              TweenAnimationBuilder<double>(
                tween: Tween(end: progress),
                duration: Motion.medium,
                curve: Motion.ease,
                builder: (context, value, _) => SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 2.4,
                    strokeCap: StrokeCap.round,
                    color: outgoing ? AppColors.bronze700 : AppColors.bronze400,
                    backgroundColor: (outgoing ? AppColors.graphite700 : Colors.white).withValues(
                      alpha: 0.14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Drag or tap along the trace to jump, once the note is loaded.
class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.enabled, required this.onSeek, required this.child});

  final bool enabled;
  final ValueChanged<double> onSeek;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        void seek(Offset position) => onSeek((position.dx / constraints.maxWidth).clamp(0.0, 1.0));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => seek(details.localPosition),
          onHorizontalDragUpdate: (details) => seek(details.localPosition),
          child: child,
        );
      },
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({super.key, required this.speed, required this.outgoing, required this.onTap});

  final double speed;
  final bool outgoing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = speed == speed.roundToDouble() ? '${speed.round()}×' : '$speed×';
    return Pressable(
      onTap: onTap,
      pressedScale: 0.9,
      semanticLabel: 'Playback speed $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: (outgoing ? AppColors.graphite800 : Colors.white).withValues(alpha: 0.14),
        ),
        child: AnimatedSwitcher(
          duration: Motion.fast,
          transitionBuilder: popTransition,
          child: Text(
            label,
            key: ValueKey(label),
            style: TextStyle(
              color: outgoing ? AppColors.graphite800 : AppColors.silver100,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
