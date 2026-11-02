import 'package:flutter/foundation.dart';

import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../bluetooth/models/peer_info.dart';

/// Decides whether an authenticated peer may use a connection.
/// - Blocked contacts are always refused.
/// - Unknown devices are refused when "Accept new devices" is off.
class PeerPolicy {
  PeerPolicy(this._conversations, this._settings);

  final ConversationRepository _conversations;
  final SettingsRepository _settings;

  Future<bool> admit(PeerInfo peer) async {
    try {
      final known = await _conversations.findPeer(peer.id);
      if (known != null) return !known.blocked;
      return await _settings.getAcceptUnknownDevices();
    } catch (e) {
      debugPrint('PeerPolicy failed for ${peer.id}: $e');
      return false; // fail closed
    }
  }
}
