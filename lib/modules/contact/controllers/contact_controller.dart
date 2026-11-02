import 'dart:async';

import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/bluetooth/bluetooth_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/security/identity_service.dart';
import '../../../core/security/safety_number.dart';
import '../../../data/repositories/conversation_repository.dart';

/// Contact details: identity, safety number, verification, blocking.
class ContactController extends GetxController {
  ContactController(this._conversations, this._bluetooth, this._identity);

  final ConversationRepository _conversations;
  final BluetoothService _bluetooth;
  final IdentityService _identity;

  final peer = Rxn<Peer>();
  final isLoaded = false.obs;
  late final String peerId;
  StreamSubscription<Peer?>? _sub;

  // Reactive getters: read inside Obx.
  bool get isConnected => _bluetooth.connectedPeers.containsKey(peerId);
  bool get isConnecting => _bluetooth.isConnectingTo(peerId);

  /// Null when the peer's key isn't known (never completed a handshake).
  String? get safetyNumberText {
    final key = peer.value?.identityPublicKey;
    if (key == null) return null;
    return safetyNumber(_identity.publicKey.bytes, key);
  }

  @override
  void onInit() {
    super.onInit();
    peerId = Get.arguments as String? ?? '';
    _sub = _conversations.watchPeer(peerId).listen((p) {
      peer.value = p;
      isLoaded.value = true;
    });
  }

  Future<void> setVerified(bool verified) => _conversations.setVerified(peerId, verified);

  Future<void> setBlocked(bool blocked) async {
    await _conversations.setBlocked(peerId, blocked);
    if (blocked && isConnected) await _bluetooth.disconnectPeer(peerId);
  }

  Future<void> connect() async {
    final ok = await _bluetooth.connectToKnownPeer(peerId);
    if (!ok && !isClosed) {
      Get.snackbar('Could not connect', "${peer.value?.displayName ?? 'The contact'} wasn't found nearby.",
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> disconnect() => _bluetooth.disconnectPeer(peerId);

  Future<void> deleteConversation() async {
    await _conversations.deleteConversation(_conversations.conversationIdForPeer(peerId));
    Get.until((route) => route.settings.name == Routes.home);
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
