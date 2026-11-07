import 'package:drift/drift.dart';

import '../../../data/models/delivery_status.dart';
import '../../../data/models/message_type.dart';
import '../app_database.dart';
import '../tables/conversations_table.dart';
import '../tables/messages_table.dart';

part 'message_dao.g.dart';

@DriftAccessor(tables: [Messages, Conversations])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  MessageDao(super.attachedDatabase);

  /// Messages of a conversation in display order (oldest first).
  Stream<List<Message>> watchForConversation(String conversationId) {
    return (select(messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.sortAt), (m) => OrderingTerm.asc(m.seq)]))
        .watch();
  }

  /// The newest [limit] messages of a conversation, in display order
  /// (oldest first). Used for paging long chats.
  Stream<List<Message>> watchRecent(String conversationId, {required int limit}) {
    return (select(messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.desc(m.sortAt), (m) => OrderingTerm.desc(m.seq)])
          ..limit(limit))
        .watch()
        .map((rows) => rows.reversed.toList(growable: false));
  }

  Future<Message?> findById(String id) =>
      (select(messages)..where((m) => m.id.equals(id))).getSingleOrNull();

  /// Stores a new outgoing message with status [DeliveryStatus.pending].
  ///
  /// The sequence number is allocated inside the transaction, so two rapid
  /// sends can never receive the same `seq`.
  Future<Message> insertOutgoing({
    required String id,
    required String conversationId,
    required String senderId,
    required String receiverId,
    required MessageType type,
    required String content,
    required int now,
    String? preview,
  }) {
    return transaction(() async {
      final maxSeq = messages.seq.max();
      final seqQuery = selectOnly(messages)
        ..addColumns([maxSeq])
        ..where(messages.conversationId.equals(conversationId) & messages.isOutgoing.equals(true));
      final seq = ((await seqQuery.map((r) => r.read(maxSeq)).getSingle()) ?? 0) + 1;

      final row = MessagesCompanion.insert(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        type: type,
        content: content,
        sentAt: now,
        sortAt: now,
        seq: seq,
        status: DeliveryStatus.pending,
        isOutgoing: true,
      );
      await into(messages).insert(row);
      await _applyToSummary(
        conversationId: conversationId,
        messageId: id,
        preview: preview ?? content,
        at: now,
        incrementUnread: false,
      );
      return (await findById(id))!;
    });
  }

  /// Stores an incoming message. Returns `false` (and changes nothing) if a
  /// message with the same ID already exists — i.e. a retransmission.
  Future<bool> insertIncoming({
    required String id,
    required String conversationId,
    required String senderId,
    required String receiverId,
    required MessageType type,
    required String content,
    required int sentAt,
    required int seq,
    required int now,
    required bool incrementUnread,
    String? preview,
  }) {
    return transaction(() async {
      if (await findById(id) != null) return false;
      await into(messages).insert(
        MessagesCompanion.insert(
          id: id,
          conversationId: conversationId,
          senderId: senderId,
          receiverId: receiverId,
          type: type,
          content: content,
          sentAt: sentAt,
          receivedAt: Value(now),
          sortAt: now,
          seq: seq,
          status: DeliveryStatus.received,
          isOutgoing: false,
        ),
      );
      await _applyToSummary(
        conversationId: conversationId,
        messageId: id,
        preview: preview ?? content,
        at: now,
        incrementUnread: incrementUnread,
      );
      return true;
    });
  }

  /// Sets the status of a message. When [onlyFrom] is given, the update only
  /// applies if the current status is in that set (prevents e.g. a late
  /// "sent" overwriting "delivered"). Returns whether a row changed.
  Future<bool> updateStatus(
    String id,
    DeliveryStatus status, {
    Set<DeliveryStatus>? onlyFrom,
  }) async {
    final query = update(messages)..where((m) => m.id.equals(id));
    if (onlyFrom != null) {
      query.where((m) => m.status.isInValues(onlyFrom.toList()));
    }
    final changed = await query.write(MessagesCompanion(status: Value(status)));
    return changed > 0;
  }

  static const _undelivered = [DeliveryStatus.pending, DeliveryStatus.sending, DeliveryStatus.sent];

  /// Oldest outgoing message of the conversation that still needs sending
  /// (pending, interrupted while sending, or sent without ACK), by `seq`.
  Future<Message?> nextUndeliveredOutgoing(String conversationId) {
    return (select(messages)
          ..where(
            (m) =>
                m.conversationId.equals(conversationId) &
                m.isOutgoing.equals(true) &
                m.status.isInValues(_undelivered),
          )
          ..orderBy([(m) => OrderingTerm.asc(m.seq)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Messages interrupted mid-send (app killed, link lost) go back to pending.
  /// Limited to one conversation when [conversationId] is given.
  Future<int> resetSendingToPending({String? conversationId}) {
    final query = update(messages)
      ..where((m) => m.isOutgoing.equals(true) & m.status.equalsValue(DeliveryStatus.sending));
    if (conversationId != null) {
      query.where((m) => m.conversationId.equals(conversationId));
    }
    return query.write(const MessagesCompanion(status: Value(DeliveryStatus.pending)));
  }

  /// Marks an outgoing message delivered, only if it was really sent to
  /// [peerId] (a peer can't acknowledge someone else's messages).
  Future<bool> markDelivered(String id, String peerId) async {
    final changed =
        await (update(messages)..where(
              (m) =>
                  m.id.equals(id) &
                  m.isOutgoing.equals(true) &
                  m.receiverId.equals(peerId) &
                  m.status.isInValues([
                    ..._undelivered,
                    DeliveryStatus.transferring,
                    DeliveryStatus.failed,
                  ]),
            ))
            .write(const MessagesCompanion(status: Value(DeliveryStatus.delivered)));
    return changed > 0;
  }

  /// The peer stored a voice message and will now fetch its audio. Only moves
  /// forward: a repeated ACK can't undo `delivered`.
  Future<bool> markTransferring(String id, String peerId) async {
    final changed =
        await (update(messages)..where(
              (m) =>
                  m.id.equals(id) &
                  m.isOutgoing.equals(true) &
                  m.receiverId.equals(peerId) &
                  m.status.isInValues([..._undelivered, DeliveryStatus.failed]),
            ))
            .write(const MessagesCompanion(status: Value(DeliveryStatus.transferring)));
    return changed > 0;
  }

  /// Voice messages received from [peerId], oldest first.
  Future<List<Message>> incomingVoiceFrom(String peerId) {
    return (select(messages)
          ..where(
            (m) =>
                m.senderId.equals(peerId) &
                m.isOutgoing.equals(false) &
                m.type.equalsValue(MessageType.voice),
          )
          ..orderBy([(m) => OrderingTerm.asc(m.sortAt)]))
        .get();
  }

  /// Records a missing ACK. Returns the new status: `pending` (will be resent)
  /// or `failed` after [maxAttempts]; null if the message was no longer
  /// awaiting an ACK (e.g. delivered meanwhile).
  Future<DeliveryStatus?> recordAckTimeout(String id, {required int maxAttempts}) {
    return transaction(() async {
      final message = await findById(id);
      if (message == null ||
          !(message.status == DeliveryStatus.sending || message.status == DeliveryStatus.sent)) {
        return null;
      }
      final attempts = message.retryCount + 1;
      final status = attempts >= maxAttempts ? DeliveryStatus.failed : DeliveryStatus.pending;
      await (update(messages)..where((m) => m.id.equals(id))).write(
        MessagesCompanion(status: Value(status), retryCount: Value(attempts)),
      );
      return status;
    });
  }

  /// User asked to retry a failed message.
  Future<bool> retryFailed(String id) async {
    final changed =
        await (update(
          messages,
        )..where((m) => m.id.equals(id) & m.status.equalsValue(DeliveryStatus.failed))).write(
          const MessagesCompanion(status: Value(DeliveryStatus.pending), retryCount: Value(0)),
        );
    return changed > 0;
  }

  Future<void> _applyToSummary({
    required String conversationId,
    required String messageId,
    required String preview,
    required int at,
    required bool incrementUnread,
  }) async {
    final conversation = await (select(
      conversations,
    )..where((c) => c.id.equals(conversationId))).getSingle();
    final isNewest = conversation.lastMessageAt == null || at >= conversation.lastMessageAt!;
    if (!isNewest && !incrementUnread) return;

    await (update(conversations)..where((c) => c.id.equals(conversationId))).write(
      ConversationsCompanion(
        lastMessageId: isNewest ? Value(messageId) : const Value.absent(),
        lastMessagePreview: isNewest ? Value(_preview(preview)) : const Value.absent(),
        lastMessageAt: isNewest ? Value(at) : const Value.absent(),
        unreadCount: incrementUnread ? Value(conversation.unreadCount + 1) : const Value.absent(),
      ),
    );
  }

  static String _preview(String content) {
    final singleLine = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return singleLine.length <= 120 ? singleLine : '${singleLine.substring(0, 120)}…';
  }
}
