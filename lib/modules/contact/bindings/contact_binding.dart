import 'package:get/get.dart';

import '../controllers/contact_controller.dart';

class ContactBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ContactController(Get.find(), Get.find(), Get.find()));
  }
}
