import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:u_chat/core/bluetooth/models/incoming_frame.dart';
import 'package:u_chat/core/bluetooth/models/peer_info.dart';
import 'package:u_chat/core/bluetooth/transport/frame.dart';
import 'package:u_chat/core/bluetooth/transport/hello.dart';
import 'package:u_chat/core/security/peer_policy.dart';
import 'package:u_chat/data/repositories/settings_repository.dart';
import 'package:u_chat/core/database/app_database.dart';
import 'package:u_chat/core/messaging/message_protocol.dart';
import 'package:u_chat/core/messaging/messaging_service.dart';
import 'package:u_chat/core/messaging/peer_transport.dart';
import 'package:u_chat/core/security/identity_service.dart';
import 'package:u_chat/data/models/conversation_with_peer.dart';
import 'package:u_chat/data/models/delivery_status.dart';
import 'package:u_chat/data/models/message_type.dart';
import 'package:u_chat/data/repositories/conversation_repository.dart';
import 'package:u_chat/data/repositories/message_repository.dart';

/// In-memory stand-in for BluetoothService, wired to a partner.
class FakeTransport implements PeerTransport {
  FakeTransport(this.self);

  final PeerInfo self;
  late FakeTransport other;
  bool connected = false;
  bool dropAcks = false;
  bool dropMessages = false;
  int connectRequests = 0;
  final sent = <Frame>[];

  final _ready = StreamController<PeerInfo>.broadcast();
  final _lost = StreamController<String>.broadcast();
  final _frames = StreamController<IncomingFrame>.broadcast();

  void connect() {
    connected = other.connected = true;
    _ready.add(other.self);
    other._ready.add(self);
  }

  void disconnect() {
    connected = other.connected = false;
    _lost.add(other.self.id);
    other._lost.add(self.id);
  }

  /// Delivers a frame to this side as if [other] had sent it.
  void inject(Frame frame) => _frames.add(IncomingFrame(other.self, frame));

  @override
  Stream<PeerInfo> get peerReady => _ready.stream;
  @override
  Stream<String> get peerLost => _lost.stream;
  @override
  Stream<IncomingFrame> get frames => _frames.stream;

  @override
  bool isPeerConnected(String peerId) => connected && peerId == other.self.id;

  @override
  Future<void> sendFrame(String peerId, Frame frame) async {
    if (!connected) throw StateError('not connected');
    sent.add(frame);
    if (dropAcks && frame.type == FrameType.ack) return;
    if (dropMessages && frame.type == FrameType.message) return;
    scheduleMicrotask(() => other.inject(frame));
  }

  @override
  Future<bool> connectToKnownPeer(String peerId) async {
    connectRequests++;
    return false;
  }
}

class Phone {
  Phone._(this.name, this.identity, this.db);

  final String name;
  final IdentityService identity;
  final AppDatabase db;
  late final ConversationRepository conversations;
  late final MessageRepository messages;
  late final FakeTransport transport;
  late final MessagingService messaging;

  static Future<Phone> create(String name) async {
    FlutterSecureStorage.setMockInitialValues({});
    final identity = await IdentityService(const FlutterSecureStorage()).init();
    final phone = Phone._(name, identity, AppDatabase(NativeDatabase.memory()));
    phone.conversations = ConversationRepository(
      phone.db.conversationDao,
      phone.db.peerDao,
      identity,
    );
    phone.messages = MessageRepository(phone.db.messageDao, identity);
    phone.transport = FakeTransport(phone.info);
    return phone;
  }

  PeerInfo get info => PeerInfo(
        id: identity.deviceId,
        displayName: name,
        publicKey: Uint8List.fromList(identity.publicKey.bytes),
      );

  Future<void> start() async {
    messaging = MessagingService(
      transport,
      conversations,
      messages,
      ackTimeout: const Duration(milliseconds: 60),
    );
    await messaging.init();
  }

  /// The conversation with [other], as the chat screen would have it.
  Future<ConversationWithPeer> chatWith(Phone other) async {
    final c = await conversations.openConversationWithPeer(other.info);
    return (await conversations.watchConversation(c.id).first)!;
  }

  Future<List<Message>> messagesWith(Phone other) =>
      messages.watchMessages(conversations.conversationIdForPeer(other.identity.deviceId)).first;
}

Future<void> settle([int ms = 150]) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Phone a;
  late Phone b;

  setUp(() async {
    a = await Phone.create('Alice');
    b = await Phone.create('Bob');
    a.transport.other = b.transport;
    b.transport.other = a.transport;
    await a.start();
    await b.start();
  });

  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  test('message queued offline is delivered after connecting', () async {
    await a.messaging.sendText(await a.chatWith(b), 'Hello Bob');
    expect((await a.messagesWith(b)).single.status, DeliveryStatus.pending);
    expect(a.transport.connectRequests, 1); // tried to connect in the background

    a.transport.connect();
    await settle();

    expect((await a.messagesWith(b)).single.status, DeliveryStatus.delivered);
    final received = (await b.messagesWith(a)).single;
    expect(received.content, 'Hello Bob');
    expect(received.status, DeliveryStatus.received);
    expect(received.senderId, a.identity.deviceId);
    final bConversation = await b.chatWith(a);
    expect(bConversation.peer.displayName, 'Alice');
    expect(bConversation.conversation.unreadCount, 1);
  });

  test('rapid messages arrive in order and are all delivered', () async {
    a.transport.connect();
    await settle(30);
    final chat = await a.chatWith(b);
    for (var i = 1; i <= 5; i++) {
      await a.messaging.sendText(chat, 'm$i');
    }
    await settle(400);

    final received = await b.messagesWith(a);
    expect(received.map((m) => m.content), ['m1', 'm2', 'm3', 'm4', 'm5']);
    expect(received.map((m) => m.seq), [1, 2, 3, 4, 5]);
    expect((await a.messagesWith(b)).every((m) => m.status == DeliveryStatus.delivered), isTrue);
    // Stop-and-wait: exactly one transmission per message, no spurious resends.
    expect(a.transport.sent.where((f) => f.type == FrameType.message), hasLength(5));
  });

  test('duplicate frames are stored once but acknowledged every time', () async {
    a.transport.connect();
    await settle(30);
    final payload = ChatMessagePayload(
      id: '0b8e7c1a-1111-4222-8333-944455556666',
      senderId: a.identity.deviceId,
      receiverId: b.identity.deviceId,
      type: MessageType.text,
      content: 'once',
      timestamp: 1,
      seq: 1,
    );
    b.transport.inject(Frame(FrameType.message, payload.encode()));
    b.transport.inject(Frame(FrameType.message, payload.encode()));
    await settle();

    expect(await b.messagesWith(a), hasLength(1));
    expect(b.transport.sent.where((f) => f.type == FrameType.ack), hasLength(2));
  });

  test('missing ACKs lead to retries, then failed; manual retry delivers', () async {
    a.transport.connect();
    await settle(30);
    b.transport.dropAcks = true;
    await a.messaging.sendText(await a.chatWith(b), 'are you there?');
    await settle(500);

    final failed = (await a.messagesWith(b)).single;
    expect(failed.status, DeliveryStatus.failed);
    expect(failed.retryCount, 3);
    expect(a.transport.sent.where((f) => f.type == FrameType.message), hasLength(3));
    expect(await b.messagesWith(a), hasLength(1)); // retransmissions deduplicated

    b.transport.dropAcks = false;
    await a.messaging.retry(failed);
    await settle();
    expect((await a.messagesWith(b)).single.status, DeliveryStatus.delivered);
  });

  test('a message lost during a disconnect is resent after reconnecting', () async {
    a.transport.connect();
    await settle(30);
    a.transport.dropMessages = true; // the frame vanishes on the way
    await a.messaging.sendText(await a.chatWith(b), 'lost in the air');
    await settle(20);
    expect((await a.messagesWith(b)).single.status, DeliveryStatus.sent);

    a.transport.disconnect();
    a.transport.dropMessages = false;
    await settle(20);
    a.transport.connect();
    await settle();

    expect((await a.messagesWith(b)).single.status, DeliveryStatus.delivered);
    expect((await b.messagesWith(a)).single.content, 'lost in the air');
  });

  test('messages claiming another sender are rejected without ACK', () async {
    a.transport.connect();
    await settle(30);
    final spoofed = ChatMessagePayload(
      id: '0b8e7c1a-1111-4222-8333-944455550000',
      senderId: 'aaaaaaaaaaaaaaaaaaaaaaaaaa', // not the link peer
      receiverId: b.identity.deviceId,
      type: MessageType.text,
      content: 'fake',
      timestamp: 1,
      seq: 1,
    );
    b.transport.inject(Frame(FrameType.message, spoofed.encode()));
    b.transport.inject(Frame(FrameType.message, Uint8List.fromList([1, 2, 3]))); // garbage
    await settle();
    expect(await b.messagesWith(a), isEmpty);
    expect(b.transport.sent.where((f) => f.type == FrameType.ack), isEmpty);
  });

  test('ACKs for messages sent to someone else are ignored', () async {
    final chat = await a.chatWith(b);
    await a.messaging.sendText(chat, 'pending');
    final id = (await a.messagesWith(b)).single.id;
    // Delivered only when acknowledged by the actual receiver.
    expect(await a.messages.markDelivered(id, 'zzzzzzzzzzzzzzzzzzzzzzzzzz'), isFalse);
    expect(await a.messages.markDelivered(id, b.identity.deviceId), isTrue);
  });

  test('messages for the open chat do not count as unread', () async {
    a.transport.connect();
    await settle(30);
    b.messaging.activeConversationId = b.conversations.conversationIdForPeer(a.identity.deviceId);
    await a.messaging.sendText(await a.chatWith(b), 'seen');
    await settle();
    expect((await b.chatWith(a)).conversation.unreadCount, 0);
  });

  test('a deleted conversation comes back when the contact writes again', () async {
    a.transport.connect();
    await settle(30);
    await b.conversations.deleteConversation(b.conversations.conversationIdForPeer(a.identity.deviceId));
    await a.messaging.sendText(await a.chatWith(b), 'still there?');
    await settle();
    expect((await b.messagesWith(a)).single.content, 'still there?');
    expect((await a.messagesWith(b)).single.status, DeliveryStatus.delivered);
  });

  test('profile frames update the contact name', () async {
    a.transport.connect();
    await settle(30);
    b.transport.inject(Frame(FrameType.profile, ProfileCodec.encode('Alice Cooper')));
    await settle();
    expect((await b.conversations.findPeer(a.identity.deviceId))!.displayName, 'Alice Cooper');
  });

  test('peer policy: blocked refused, unknown follows the setting', () async {
    final settings = SettingsRepository(b.db.settingsDao, b.identity);
    final policy = PeerPolicy(b.conversations, settings);
    final stranger = (await Phone.create('Stranger')).info;

    expect(await policy.admit(stranger), isTrue); // default: accept new devices
    await settings.setAcceptUnknownDevices(false);
    expect(await policy.admit(stranger), isFalse);

    await b.chatWith(a); // Alice becomes a known contact
    expect(await policy.admit(a.info), isTrue);
    await b.conversations.setBlocked(a.identity.deviceId, true);
    expect(await policy.admit(a.info), isFalse);
  });

  test('protocol rejects malformed payloads', () {
    Uint8List json(String s) => Uint8List.fromList(s.codeUnits);
    expect(() => ChatMessagePayload.decode(json('[]')), throwsFormatException);
    expect(() => ChatMessagePayload.decode(json('{"v":1,"id":"x"}')), throwsFormatException);
    expect(() => AckPayload.decode(json('{"ids":[]}')), throwsFormatException);
    expect(() => AckPayload.decode(json('{"ids":["not-a-uuid"]}')), throwsFormatException);
  });
}
