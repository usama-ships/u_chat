import 'dart:typed_data';

import '../../core/bluetooth/models/peer_info.dart';
import '../../core/database/app_database.dart';
import '../../core/database/daos/conversation_dao.dart';
import '../../core/database/daos/peer_dao.dart';
import '../../core/security/identity_service.dart';
import '../../core/security/ids.dart';
import '../../core/voice/voice_store.dart';
import '../models/conversation_with_peer.dart';

/// Conversations and the peers they belong to.
class ConversationRepository {
  ConversationRepository(this._conversationDao, this._peerDao, this._identity, {this._voiceStore});

  final ConversationDao _conversationDao;
  final PeerDao _peerDao;
  final IdentityService _identity;
  final VoiceStore? _voiceStore;

  Stream<List<ConversationWithPeer>> watchConversations() => _conversationDao.watchAllWithPeers();

  Stream<ConversationWithPeer?> watchConversation(String conversationId) =>
      _conversationDao.watchWithPeer(conversationId);

  Future<void> markRead(String conversationId) => _conversationDao.markRead(conversationId);

  /// Records a peer as seen and returns the 1:1 conversation with it,
  /// creating both rows if needed. Called once a peer is identified over
  /// Bluetooth (Phase 3).
  Future<Conversation> openConversationWith({
    required String peerId,
    required String peerDisplayName,
    String? platform,
    Uint8List? identityPublicKey,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _peerDao.upsertSeen(
      id: peerId,
      displayName: peerDisplayName,
      platform: platform,
      identityPublicKey: identityPublicKey,
      now: now,
    );
    return _conversationDao.getOrCreate(
      id: conversationIdFor(_identity.deviceId, peerId),
      peerId: peerId,
      now: now,
    );
  }

  /// Same as [openConversationWith], from a peer identified over Bluetooth.
  Future<Conversation> openConversationWithPeer(PeerInfo peer) => openConversationWith(
    peerId: peer.id,
    peerDisplayName: peer.displayName,
    platform: peer.platform,
    identityPublicKey: peer.publicKey,
  );

  String conversationIdForPeer(String peerId) => conversationIdFor(_identity.deviceId, peerId);

  Stream<Peer?> watchPeer(String peerId) => _peerDao.watchById(peerId);

  Future<Peer?> findPeer(String peerId) => _peerDao.findById(peerId);

  Future<void> updatePeerName(String peerId, String displayName) =>
      _peerDao.updateDisplayName(peerId, displayName);

  Future<void> setVerified(String peerId, bool verified) => _peerDao.setVerified(peerId, verified);

  Future<void> setBlocked(String peerId, bool blocked) => _peerDao.setBlocked(peerId, blocked);

  /// Removes the messages and their audio files.
  Future<void> deleteConversation(String conversationId) async {
    await _conversationDao.deleteWithMessages(conversationId);
    await _voiceStore?.deleteConversation(conversationId);
  }
}
