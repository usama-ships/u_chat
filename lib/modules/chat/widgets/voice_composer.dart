import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/surfaces.dart';
import '../../../app/widgets/motion.dart';
import '../../../app/widgets/pressable.dart';
import '../../../core/voice/voice_meta.dart';
import '../controllers/chat_controller.dart';
import 'signal_trace.dart';

/// Hold to record. Sliding left cancels, sliding up locks so the finger can
/// let go. Uses raw pointer events because the recording has to start the
/// moment the finger lands, not after a long-press delay.
class MicButton extends StatefulWidget {
  const MicButton({super.key});

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> {
  static const _cancelDistance = 120.0;
  static const _lockDistance = 70.0;

  final controller = Get.find<ChatController>();
  Offset? _origin;

  void _onDown(PointerDownEvent event) {
    _origin = event.position;
    controller.startRecording();
  }

  void _onMove(PointerMoveEvent event) {
    final origin = _origin;
    if (origin == null) return;
    final delta = event.position - origin;
    final cancel = (-delta.dx / _cancelDistance).clamp(0.0, 1.0);
    final lock = (-delta.dy / _lockDistance).clamp(0.0, 1.0);
    controller.recordingDrag.value = (cancel: cancel, lock: lock);
    if (cancel >= 1) {
      _origin = null;
      controller.cancelRecording();
    } else if (lock >= 1) {
      _origin = null;
      controller.lockRecording();
    }
  }

  void _onUp(PointerUpEvent event) {
    if (_origin == null) return;
    _origin = null;
    controller.finishRecording();
  }

  void _onCancel(PointerCancelEvent event) {
    if (_origin == null) return;
    _origin = null;
    controller.cancelRecording();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Record a voice message',
      hint: 'Hold to record, or double tap to start and stop',
      onTap: () => controller.startRecording(locked: true),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onCancel,
        child: Obx(() {
          final recording = controller.recordingMode.value == RecordingMode.holding;
          return AnimatedScale(
            duration: Motion.medium,
            curve: Motion.pop,
            scale: recording ? 1.12 : 1,
            child: AnimatedContainer(
              duration: Motion.medium,
              curve: Motion.ease,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: recording ? 0.5 : 0.22),
                    blurRadius: recording ? 22 : 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.mic_rounded, size: 23, color: AppColors.onAccent),
            ),
          );
        }),
      ),
    );
  }
}

/// Takes the place of the text field while recording.
class RecordingPanel extends GetView<ChatController> {
  const RecordingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      radius: 26,
      color: AppColors.surface,
      shadow: true,
      borderColor: AppColors.accentBorder,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: 48,
        child: Obx(() {
          final drag = controller.recordingDrag.value;
          final remaining = VoiceMeta.maxRecordingMs - controller.recordingMs.value;
          final nearLimit = remaining < 10000;
          return Row(
            children: [
              const PulseDot(size: 8, color: AppColors.danger),
              const SizedBox(width: 4),
              Text(
                formatVoiceDuration(controller.recordingMs.value),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: nearLimit ? AppColors.danger : AppColors.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: drag.cancel == 0
                    ? LiveTrace(levels: controller.liveLevels.toList())
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 8),
              Transform.translate(
                offset: Offset(-40 * drag.cancel, 0),
                child: Opacity(
                  opacity: (1 - drag.cancel).clamp(0.25, 1.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.chevron_left_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      Text(
                        'Cancel',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Transform.translate(
                offset: Offset(0, -6 * drag.lock),
                child: Icon(
                  drag.lock > 0 ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 17,
                  color: Color.lerp(AppColors.textMuted, AppColors.accent, drag.lock),
                  semanticLabel: 'Slide up to lock',
                ),
              ),
              const SizedBox(width: 4),
            ],
          );
        }),
      ),
    );
  }
}

/// The hands-free recorder: a card that rises over the composer once a
/// recording is locked, with a big trace, the time, and discard / send.
class VoiceNoteCard extends GetView<ChatController> {
  const VoiceNoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Panel(
      radius: 30,
      color: AppColors.surface,
      shadow: true,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Obx(() {
        final remaining = VoiceMeta.maxRecordingMs - controller.recordingMs.value;
        final nearLimit = remaining < 10000;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Voice ',
                    style: theme.textTheme.titleMedium?.copyWith(color: AppColors.text),
                  ),
                  TextSpan(
                    text: 'Note',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ExcludeSemantics(
              child: LiveTrace(levels: controller.liveLevels.toList(), color: AppColors.accent),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PulseDot(size: 7, color: AppColors.danger),
                const SizedBox(width: 6),
                Text(
                  formatVoiceDuration(controller.recordingMs.value),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: nearLimit ? AppColors.danger : AppColors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CardAction(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Discard recording',
                  color: AppColors.textSecondary,
                  onTap: controller.cancelRecording,
                ),
                const _RecordingOrb(),
                _CardAction(
                  icon: Icons.send_rounded,
                  tooltip: 'Send',
                  color: AppColors.accent,
                  onTap: controller.finishRecording,
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.88,
        semanticLabel: tooltip,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.08)),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

/// The big lavender mic in the middle, breathing while it listens.
class _RecordingOrb extends StatelessWidget {
  const _RecordingOrb();

  @override
  Widget build(BuildContext context) {
    final core = Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.accentGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.mic_rounded, size: 28, color: AppColors.onAccent),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: 92,
        height: 92,
        child: Looping(
          period: const Duration(milliseconds: 1600),
          reverse: true,
          restingValue: 0.5,
          child: core,
          builder: (context, value, child) => Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 74 + 18 * value,
                height: 74 + 18 * value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.10 - 0.05 * value),
                ),
              ),
              child!,
            ],
          ),
        ),
      ),
    );
  }
}
