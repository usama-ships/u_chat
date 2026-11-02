import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import '../../core/bluetooth/bluetooth_service.dart';
import '../../core/database/app_database.dart';
import '../../core/messaging/messaging_service.dart';
import '../../core/security/identity_service.dart';
import '../../core/security/peer_policy.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/repositories/settings_repository.dart';

/// Registers app-lifetime singletons before the first frame.
///
/// These need async initialisation (database, identity key), which GetX
/// `Bindings.dependencies()` can't await, so they're set up here from
/// `main()`. Per-screen controllers are still registered by each module's
/// Binding.
abstract final class AppDependencies {
  static Future<void> init() async {
    final db = Get.put<AppDatabase>(AppDatabase(), permanent: true);

    final identity = await Get.putAsync<IdentityService>(
      () => IdentityService(const FlutterSecureStorage()).init(),
      permanent: true,
    );

    final settings = Get.put(SettingsRepository(db.settingsDao, identity), permanent: true);
    await settings.ensureDefaults();

    final conversations = Get.put(
      ConversationRepository(db.conversationDao, db.peerDao, identity),
      permanent: true,
    );
    final messages = Get.put(MessageRepository(db.messageDao, identity), permanent: true);

    final bluetooth = await Get.putAsync<BluetoothService>(
      () => BluetoothService(identity, settings).init(),
      permanent: true,
    );
    bluetooth.admitPeer = PeerPolicy(conversations, settings).admit;
    await Get.putAsync<MessagingService>(
      () => MessagingService(bluetooth, conversations, messages).init(),
      permanent: true,
    );
  }
}
