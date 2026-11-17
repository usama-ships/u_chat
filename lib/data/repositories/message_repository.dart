import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/database/daos/message_dao.dart';
import '../../core/security/identity_service.dart';
import '../../core/voice/voice_meta.dart';
import '../models/delivery_status.dart';
import '../models/message_type.dart';

/// Local message storage and delivery-state transitions. The transmission
/// itself is driven by `MessagingService`.
class MessageRepository {
  MessageRepository(this._dao, this._identity, {this._uuid = const Uuid()});

  final MessageDao _dao;
  final IdentityService _identity;
  final Uuid _uuid;

  String get myId => _identity.deviceId;

  Stream<List<Message>> watchMessages(String conversationId) =>
      _dao.watchForConversation(conversationId);

  /// Newest [limit] messages, oldest first.
  Stream<List<Message>> watchRecentMessages(String conversationId, {required int limit}) =>
      _dao.watchRecent(conversationId, limit: limit);

  /// Stores an outgoing text message with status `pending`.
  /// Throws [ArgumentError] if the text is empty or too long.
  Future<Message> queueOutgoingText({
    required String conversationId,
    required String receiverId,
    required String text,
  }) {
    final content = text.trim();
    if (content.isEmpty) throw ArgumentError('Message is empty');
    if (content.length > AppConstants.maxTextLength) {
      throw ArgumentError('Message exceeds ${AppConstants.maxTextLength} characters');
    }
    return _dao.insertOutgoing(
      id: _uuid.v4(),
      conversationId: conversationId,
      senderId: myId,
      receiverId: receiverId,
      type: MessageType.text,
      content: content,
      now: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// A fresh ID, for files that must exist before their message row.
  String newMessageId() => _uuid.v4();

  /// Stores an outgoing voice message with status `pending`. Its audio must
  /// already be in the `VoiceStore` under [id].
  Future<Message> queueOutgoingVoice({
    required String id,
    required String conversationId,
    required String receiverId,
    required VoiceMeta meta,
  }) {
    return _dao.insertOutgoing(
      id: id,
      conversationId: conversationId,
      senderId: myId,
      receiverId: receiverId,
      type: MessageType.voice,
      content: meta.encode(),
      preview: meta.previewLabel,
      now: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Stores a received message. Returns false if it was a duplicate.
  Future<bool> storeIncoming({
    required String id,
    required String conversationId,
    required String senderId,
    required MessageType type,
    required String content,
    required int sentAt,
    required int seq,
    required bool incrementUnread,
  }) => _dao.insertIncoming(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    receiverId: myId,
    type: type,
    content: content,
    sentAt: sentAt,
    seq: seq,
    now: DateTime.now().millisecondsSinceEpoch,
    incrementUnread: incrementUnread,
    preview: type == MessageType.voice ? VoiceMeta.decode(content).previewLabel : null,
  );

  Future<Message?> find(String id) => _dao.findById(id);

  Future<List<Message>> incomingVoiceFrom(String peerId) => _dao.incomingVoiceFrom(peerId);

  Future<bool> markTransferring(String id, String peerId) => _dao.markTransferring(id, peerId);

  Future<Message?> nextToSend(String conversationId) =>
      _dao.nextUndeliveredOutgoing(conversationId);

  Future<bool> setStatus(String id, DeliveryStatus status, {Set<DeliveryStatus>? onlyFrom}) =>
      _dao.updateStatus(id, status, onlyFrom: onlyFrom);

  Future<bool> markDelivered(String id, String peerId) => _dao.markDelivered(id, peerId);

  Future<DeliveryStatus?> recordAckTimeout(String id, {required int maxAttempts}) =>
      _dao.recordAckTimeout(id, maxAttempts: maxAttempts);

  Future<bool> retryFailed(String id) => _dao.retryFailed(id);

  Future<int> resetInterrupted({String? conversationId}) =>
      _dao.resetSendingToPending(conversationId: conversationId);
}
