abstract final class Routes {
  static const home = '/home';

  /// Expects the conversation ID (String) as `Get.arguments`.
  static const chat = '/chat';

  static const settings = '/settings';

  static const nearby = '/nearby';

  /// Expects the peer's device ID (String) as `Get.arguments`.
  static const contact = '/contact';
}
