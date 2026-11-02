import 'package:get/get.dart';

import '../../modules/chat/bindings/chat_binding.dart';
import '../../modules/chat/views/chat_view.dart';
import '../../modules/contact/bindings/contact_binding.dart';
import '../../modules/contact/views/contact_view.dart';
import '../../modules/home/bindings/home_binding.dart';
import '../../modules/home/views/home_view.dart';
import '../../modules/nearby_devices/bindings/nearby_binding.dart';
import '../../modules/nearby_devices/views/nearby_view.dart';
import '../../modules/settings/bindings/settings_binding.dart';
import '../../modules/settings/views/settings_view.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static const initial = Routes.home;

  static final pages = <GetPage<dynamic>>[
    GetPage(name: Routes.home, page: () => const HomeView(), binding: HomeBinding()),
    GetPage(name: Routes.chat, page: () => const ChatView(), binding: ChatBinding()),
    GetPage(name: Routes.settings, page: () => const SettingsView(), binding: SettingsBinding()),
    GetPage(name: Routes.nearby, page: () => const NearbyView(), binding: NearbyBinding()),
    GetPage(name: Routes.contact, page: () => const ContactView(), binding: ContactBinding()),
  ];
}
