import 'package:drift/drift.dart';

import '../../../data/models/delivery_status.dart';
import '../../../data/models/message_type.dart';
import 'conversations_table.dart';

/// Chat messages. The primary key is the sender-generated UUID, which is also
/// what makes duplicate deliveries harmless: a retransmitted message is
/// detected and ignored on insert.
@TableIndex(name: 'idx_messages_conversation_sort', columns: {#conversationId, #sortAt})
class Messages extends Table {
  TextColumn get id => text()();

  TextColumn get conversationId => text().references(Conversations, #id)();

  TextColumn get senderId => text()();
  TextColumn get receiverId => text()();

  TextColumn get type => textEnum<MessageType>()();
  TextColumn get content => text()();

  /// Sender's clock when the message was created (epoch ms).
  IntColumn get sentAt => integer()();

  /// Local clock when an incoming message was stored (epoch ms).
  IntColumn get receivedAt => integer().nullable()();

  /// Local display-ordering key: creation time for outgoing, receipt time for
  /// incoming. Avoids reordering caused by clock skew between devices.
  IntColumn get sortAt => integer()();

  /// Per-sender, per-conversation monotonic counter (starts at 1).
  IntColumn get seq => integer()();

  TextColumn get status => textEnum<DeliveryStatus>()();

  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  BoolColumn get isOutgoing => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
