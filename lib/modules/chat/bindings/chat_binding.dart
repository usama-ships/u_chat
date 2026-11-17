import 'package:get/get.dart';

import '../../../core/messaging/voice_transfer_service.dart';
import '../../../core/voice/voice_player.dart';
import '../../../core/voice/voice_recorder.dart';
import '../../../core/voice/voice_store.dart';
import '../controllers/chat_controller.dart';

class ChatBinding extends Bindings {
  ChatBinding({VoiceRecorder Function()? recorder})
    : _recorder = recorder ?? DeviceVoiceRecorder.new;

  /// Swapped in tests, which have no microphone.
  final VoiceRecorder Function() _recorder;

  @override
  void dependencies() {
    Get.lazyPut(
      () => ChatController(
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        // These parameters are nullable, so the type must be spelled out:
        // a bare Get.find() would look up `VoicePlayer?`, which is never
        // registered.
        recorder: _recorder(),
        player: Get.find<VoicePlayer>(),
        transfer: Get.find<VoiceTransferService>(),
        store: Get.find<VoiceStore>(),
      ),
    );
  }
}
