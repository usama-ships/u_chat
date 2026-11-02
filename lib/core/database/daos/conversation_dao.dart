import 'package:drift/drift.dart';

import '../../../data/models/conversation_with_peer.dart';
import '../app_database.dart';
import '../tables/conversations_table.dart';
import '../tables/messages_table.dart';
import '../tables/peers_table.dart';

part 'conversation_dao.g.dart';

@DriftAccessor(tables: [Conversations, Peers, Messages])
class ConversationDao extends DatabaseAccessor<AppDatabase> with _$ConversationDaoMixin {
  ConversationDao(super.attachedDatabase);

  JoinedSelectStatement<HasResultSet, dynamic> _withPeer() => select(conversations).join([
        innerJoin(peers, peers.id.equalsExp(conversations.peerId)),
      ]);

  ConversationWithPeer _map(TypedResult row) =>
      ConversationWithPeer(conversation: row.readTable(conversations), peer: row.readTable(peers));

  /// All conversations, most recent activity first.
  Stream<List<ConversationWithPeer>> watchAllWithPeers() {
    final query = _withPeer()
      ..orderBy([
        OrderingTerm.desc(coalesce([conversations.lastMessageAt, conversations.createdAt])),
      ]);
    return query.watch().map((rows) => rows.map(_map).toList(growable: false));
  }

  Stream<ConversationWithPeer?> watchWithPeer(String conversationId) {
    final query = _withPeer()..where(conversations.id.equals(conversationId));
    return query.watchSingleOrNull().map((row) => row == null ? null : _map(row));
  }

  /// Returns the conversation, creating it if needed. The peer row must exist.
  Future<Conversation> getOrCreate({
    required String id,
    required String peerId,
    required int now,
  }) async {
    await into(conversations).insert(
      ConversationsCompanion.insert(id: id, peerId: peerId, createdAt: now),
      mode: InsertMode.insertOrIgnore,
    );
    return (select(conversations)..where((c) => c.id.equals(id))).getSingle();
  }

  /// Deletes a conversation and all its messages. The peer is kept (so
  /// verification and block state survive).
  Future<void> deleteWithMessages(String conversationId) => transaction(() async {
        await (delete(messages)..where((m) => m.conversationId.equals(conversationId))).go();
        await (delete(conversations)..where((c) => c.id.equals(conversationId))).go();
      });

  Future<void> markRead(String conversationId) =>
      (update(conversations)..where((c) => c.id.equals(conversationId)))
          .write(const ConversationsCompanion(unreadCount: Value(0)));
}
