import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_motion.dart';
import '../../../app/widgets/glass.dart';
import '../../../app/widgets/motion.dart';
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
                gradient: recording ? AppColors.bronzeMetal : AppColors.silverMetal,
                boxShadow: [
                  BoxShadow(
                    color: (recording ? AppColors.bronze400 : AppColors.silver300).withValues(
                      alpha: recording ? 0.5 : 0.22,
                    ),
                    blurRadius: recording ? 22 : 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.mic_rounded, size: 23, color: AppColors.graphite900),
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
    return GlassPanel(
      radius: 24,
      shadow: false,
      rim: AppColors.bronzeRim,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: 48,
        child: Obx(() {
          final locked = controller.recordingMode.value == RecordingMode.locked;
          final drag = controller.recordingDrag.value;
          final remaining = VoiceMeta.maxRecordingMs - controller.recordingMs.value;
          final nearLimit = remaining < 10000;
          return Row(
            children: [
              if (locked)
                GestureDetector(
                  onTap: controller.cancelRecording,
                  behavior: HitTestBehavior.opaque,
                  child: Semantics(
                    button: true,
                    label: 'Discard recording',
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.delete_outline_rounded, size: 22, color: AppColors.clay),
                    ),
                  ),
                )
              else
                const PulseDot(size: 8),
              const SizedBox(width: 4),
              Text(
                formatVoiceDuration(controller.recordingMs.value),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: nearLimit ? AppColors.clay : AppColors.silver100,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: locked || drag.cancel == 0
                    ? LiveTrace(levels: controller.liveLevels.toList())
                    : const SizedBox.shrink(),
              ),
              if (!locked) ...[
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
                          color: AppColors.silver300,
                        ),
                        Text(
                          'Cancel',
                          style: theme.textTheme.labelMedium?.copyWith(color: AppColors.silver300),
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
                    color: Color.lerp(AppColors.silver400, AppColors.bronze300, drag.lock),
                    semanticLabel: 'Slide up to lock',
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ],
          );
        }),
      ),
    );
  }
}
