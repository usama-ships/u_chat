import 'package:drift/drift.dart';

import 'peers_table.dart';

/// One row per 1:1 conversation. The last-message fields are denormalized so
/// the home list needs no aggregate query; they are updated in the same
/// transaction as the message insert.
class Conversations extends Table {
  /// Deterministic ID from both device IDs (see `conversationIdFor`).
  TextColumn get id => text()();

  TextColumn get peerId => text().unique().references(Peers, #id)();

  TextColumn get lastMessageId => text().nullable()();
  TextColumn get lastMessagePreview => text().nullable()();
  IntColumn get lastMessageAt => integer().nullable()();

  IntColumn get unreadCount => integer().withDefault(const Constant(0))();

  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
