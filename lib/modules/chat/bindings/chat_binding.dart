import 'package:get/get.dart';

import '../../../core/voice/voice_recorder.dart';
import '../controllers/chat_controller.dart';

class ChatBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => ChatController(
        Get.find(),
        Get.find(),
        Get.find(),
        Get.find(),
        recorder: DeviceVoiceRecorder(),
        player: Get.find(),
        transfer: Get.find(),
        store: Get.find(),
      ),
    );
  }
}
