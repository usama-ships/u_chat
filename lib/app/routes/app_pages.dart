import 'package:flutter/widgets.dart';
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
import '../theme/app_motion.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static const initial = Routes.home;

  static final pages = <GetPage<dynamic>>[
    _page(Routes.home, () => const HomeView(), HomeBinding()),
    _page(Routes.chat, () => const ChatView(), ChatBinding()),
    _page(Routes.settings, () => const SettingsView(), SettingsBinding()),
    _page(Routes.nearby, () => const NearbyView(), NearbyBinding()),
    _page(Routes.contact, () => const ContactView(), ContactBinding()),
  ];

  static GetPage<dynamic> _page(String name, GetPageBuilder page, Bindings binding) => GetPage(
        name: name,
        page: page,
        binding: binding,
        customTransition: GlassPageTransition(),
        transitionDuration: Motion.page,
      );
}

/// The new screen rises and fades in while the old one recedes.
class GlassPageTransition extends CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(parent: animation, curve: Motion.ease);
    final recede = CurvedAnimation(parent: secondaryAnimation, curve: Motion.ease);
    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 0.95).animate(recede),
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.035), end: Offset.zero).animate(enter),
          child: child,
        ),
      ),
    );
  }
}
