import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:u_chat/core/database/app_database.dart';
import 'package:u_chat/data/models/delivery_status.dart';
import 'package:u_chat/data/models/message_type.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  const me = 'me000000000000000000000000';
  const peer = 'peer0000000000000000000000';
  const convId = 'conv000000000000000000000';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.peerDao.upsertSeen(id: peer, displayName: 'Alice', now: 1000);
    await db.conversationDao.getOrCreate(id: convId, peerId: peer, now: 1000);
  });

  tearDown(() => db.close());

  Future<Conversation> conversation() async =>
      (await db.conversationDao.watchWithPeer(convId).first)!.conversation;

  Future<Message> sendOut(String id, String text, int now) => db.messageDao.insertOutgoing(
        id: id,
        conversationId: convId,
        senderId: me,
        receiverId: peer,
        type: MessageType.text,
        content: text,
        now: now,
      );

  Future<bool> receive(String id, String text, int now, {bool unread = true}) =>
      db.messageDao.insertIncoming(
        id: id,
        conversationId: convId,
        senderId: peer,
        receiverId: me,
        type: MessageType.text,
        content: text,
        sentAt: now - 5,
        seq: 1,
        now: now,
        incrementUnread: unread,
      );

  test('peer upsert keeps firstSeenAt and refreshes name/lastSeen', () async {
    await db.peerDao.upsertSeen(id: peer, displayName: 'Alice 2', now: 5000);
    final p = (await db.peerDao.findById(peer))!;
    expect(p.displayName, 'Alice 2');
    expect(p.firstSeenAt, 1000);
    expect(p.lastSeenAt, 5000);
  });

  test('getOrCreate is idempotent', () async {
    await db.conversationDao.getOrCreate(id: convId, peerId: peer, now: 9999);
    final list = await db.conversationDao.watchAllWithPeers().first;
    expect(list, hasLength(1));
    expect(list.single.conversation.createdAt, 1000);
  });

  test('outgoing messages get increasing seq, pending status, and update summary', () async {
    final a = await sendOut('m1', 'Hello', 2000);
    final b = await sendOut('m2', 'World', 3000);
    expect(a.seq, 1);
    expect(b.seq, 2);
    expect(a.status, DeliveryStatus.pending);

    final c = await conversation();
    expect(c.lastMessageId, 'm2');
    expect(c.lastMessagePreview, 'World');
    expect(c.lastMessageAt, 3000);
    expect(c.unreadCount, 0);
  });

  test('incoming duplicate is ignored and does not double-count unread', () async {
    expect(await receive('x1', 'Hi', 2000), isTrue);
    expect(await receive('x1', 'Hi', 2500), isFalse);

    final msgs = await db.messageDao.watchForConversation(convId).first;
    expect(msgs, hasLength(1));
    expect(msgs.single.status, DeliveryStatus.received);
    expect((await conversation()).unreadCount, 1);
  });

  test('markRead resets unread count', () async {
    await receive('x1', 'a', 2000);
    await receive('x2', 'b', 2100);
    expect((await conversation()).unreadCount, 2);
    await db.conversationDao.markRead(convId);
    expect((await conversation()).unreadCount, 0);
  });

  test('messages are ordered by local sortAt', () async {
    await sendOut('m1', 'first', 2000);
    await receive('x1', 'second', 3000);
    await sendOut('m2', 'third', 4000);
    final ids = (await db.messageDao.watchForConversation(convId).first).map((m) => m.id);
    expect(ids, ['m1', 'x1', 'm2']);
  });

  test('updateStatus with onlyFrom does not downgrade delivered', () async {
    await sendOut('m1', 'hi', 2000);
    expect(await db.messageDao.updateStatus('m1', DeliveryStatus.delivered), isTrue);
    final changed = await db.messageDao.updateStatus(
      'm1',
      DeliveryStatus.sent,
      onlyFrom: {DeliveryStatus.pending, DeliveryStatus.sending},
    );
    expect(changed, isFalse);
    expect((await db.messageDao.findById('m1'))!.status, DeliveryStatus.delivered);
  });

  test('foreign keys reject messages for unknown conversations', () async {
    expect(
      () => db.messageDao.insertIncoming(
        id: 'z',
        conversationId: 'missing',
        senderId: peer,
        receiverId: me,
        type: MessageType.text,
        content: 'x',
        sentAt: 1,
        seq: 1,
        now: 1,
        incrementUnread: true,
      ),
      throwsA(anything),
    );
  });

  test('watchRecent pages from the newest message, in display order', () async {
    for (var i = 1; i <= 5; i++) {
      await sendOut('m$i', 'msg $i', 1000 + i);
    }
    final page = await db.messageDao.watchRecent(convId, limit: 3).first;
    expect(page.map((m) => m.id), ['m3', 'm4', 'm5']);
  });

  test('deleting a conversation removes its messages but keeps the peer', () async {
    await sendOut('m1', 'bye', 2000);
    await db.conversationDao.deleteWithMessages(convId);
    expect(await db.messageDao.findById('m1'), isNull);
    expect(await db.conversationDao.watchAllWithPeers().first, isEmpty);
    expect(await db.peerDao.findById(peer), isNotNull);
  });

  test('verified, blocked and name updates persist', () async {
    await db.peerDao.setVerified(peer, true);
    await db.peerDao.setBlocked(peer, true);
    await db.peerDao.updateDisplayName(peer, 'Alicia');
    final p = (await db.peerDao.findById(peer))!;
    expect(p.verified, isTrue);
    expect(p.blocked, isTrue);
    expect(p.displayName, 'Alicia');
  });

  test('settings round-trip', () async {
    expect(await db.settingsDao.getValue('display_name'), isNull);
    await db.settingsDao.setValue('display_name', 'Bob');
    await db.settingsDao.setValue('display_name', 'Bobby');
    expect(await db.settingsDao.getValue('display_name'), 'Bobby');
  });
}
