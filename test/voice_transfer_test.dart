import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:u_chat/core/bluetooth/models/incoming_frame.dart';
import 'package:u_chat/core/bluetooth/models/peer_info.dart';
import 'package:u_chat/core/bluetooth/transport/frame.dart';
import 'package:u_chat/core/database/app_database.dart';
import 'package:u_chat/core/messaging/message_protocol.dart';
import 'package:u_chat/core/messaging/messaging_service.dart';
import 'package:u_chat/core/messaging/peer_transport.dart';
import 'package:u_chat/core/messaging/voice_protocol.dart';
import 'package:u_chat/core/messaging/voice_transfer_service.dart';
import 'package:u_chat/core/security/identity_service.dart';
import 'package:u_chat/core/voice/voice_meta.dart';
import 'package:u_chat/core/voice/voice_recorder.dart';
import 'package:u_chat/core/voice/voice_store.dart';
import 'package:u_chat/data/models/conversation_with_peer.dart';
import 'package:u_chat/data/models/delivery_status.dart';
import 'package:u_chat/data/models/message_type.dart';
import 'package:u_chat/data/repositories/conversation_repository.dart';
import 'package:u_chat/data/repositories/message_repository.dart';

class Wire implements PeerTransport {
  Wire(this.self);

  final PeerInfo self;
  late Wire other;
  bool connected = false;

  /// Lets a test cut or tamper with traffic. Return null to drop the frame.
  Frame? Function(Frame frame)? filter;
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
    final out = filter == null ? frame : filter!(frame);
    if (out != null) scheduleMicrotask(() => other.inject(out));
  }

  @override
  Future<bool> connectToKnownPeer(String peerId) async => false;
}

class Phone {
  Phone._(this.name, this.identity, this.db, this.dir);

  final String name;
  final IdentityService identity;
  final AppDatabase db;
  final Directory dir;
  late final VoiceStore store;
  late final ConversationRepository conversations;
  late final MessageRepository messages;
  late final Wire wire;
  late final VoiceTransferService voice;
  late final MessagingService messaging;

  static Future<Phone> create(String name) async {
    FlutterSecureStorage.setMockInitialValues({});
    final identity = await IdentityService(const FlutterSecureStorage()).init();
    final dir = await Directory.systemTemp.createTemp('voice-test');
    final phone = Phone._(name, identity, AppDatabase(NativeDatabase.memory()), dir);
    phone.store = VoiceStore(dir);
    phone.conversations = ConversationRepository(
      phone.db.conversationDao,
      phone.db.peerDao,
      identity,
      voiceStore: phone.store,
    );
    phone.messages = MessageRepository(phone.db.messageDao, identity);
    phone.wire = Wire(phone.info);
    return phone;
  }

  PeerInfo get info => PeerInfo(
    id: identity.deviceId,
    displayName: name,
    publicKey: Uint8List.fromList(identity.publicKey.bytes),
  );

  Future<void> start() async {
    voice = VoiceTransferService(
      wire,
      messages,
      store,
      requestTimeout: const Duration(milliseconds: 400),
    );
    messaging = MessagingService(
      wire,
      conversations,
      messages,
      ackTimeout: const Duration(milliseconds: 80),
      voice: voice,
      voiceStore: store,
    );
    await messaging.init();
  }

  Future<ConversationWithPeer> chatWith(Phone other) async {
    final c = await conversations.openConversationWithPeer(other.info);
    return (await conversations.watchConversation(c.id).first)!;
  }

  String conversationWith(Phone other) =>
      conversations.conversationIdForPeer(other.identity.deviceId);

  Future<List<Message>> messagesWith(Phone other) =>
      messages.watchMessages(conversationWith(other)).first;

  /// Writes a fake recording of [size] bytes and sends it.
  Future<Uint8List> sendVoiceTo(Phone other, int size) async {
    final bytes = Uint8List.fromList(List.generate(size, (i) => (i * 31 + i ~/ 256) % 256));
    final file = File('${dir.path}/rec-${DateTime.now().microsecondsSinceEpoch}.m4a');
    await file.writeAsBytes(bytes);
    await messaging.sendVoice(
      await chatWith(other),
      VoiceRecording(path: file.path, durationMs: 12400, levels: const [0.2, 0.8, 0.5]),
    );
    return bytes;
  }

  Future<void> dispose() async {
    voice.onClose();
    messaging.onClose();
    await db.close();
    await dir.delete(recursive: true);
  }
}

Future<void> settle([int ms = 200]) => Future<void>.delayed(Duration(milliseconds: ms));

/// Polls until [condition] holds, since a transfer takes many round trips.
Future<void> until(Future<bool> Function() condition) async {
  for (var i = 0; i < 400; i++) {
    if (await condition()) return;
    await settle(10);
  }
  fail('condition not reached in time');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('VoiceMeta', () {
    final valid = VoiceMeta(
      durationMs: 12400,
      sizeBytes: 37200,
      sha256: 'a' * 64,
      waveform: const [0, 12, 255],
    );

    test('survives a round trip', () {
      final decoded = VoiceMeta.decode(valid.encode());
      expect(decoded.durationMs, 12400);
      expect(decoded.sizeBytes, 37200);
      expect(decoded.sha256, 'a' * 64);
      expect(decoded.waveform, [0, 12, 255]);
    });

    test('fits inside a message', () {
      final full = VoiceMeta(
        durationMs: VoiceMeta.maxRecordingMs,
        sizeBytes: VoiceMeta.maxBytes,
        sha256: 'f' * 64,
        waveform: List.filled(VoiceMeta.waveformBars, 255),
      );
      expect(full.encode().length, lessThan(4000));
    });

    test('rejects anything malformed or oversized', () {
      Map<String, Object?> json() => jsonDecode(valid.encode()) as Map<String, Object?>;
      for (final bad in [
        'not json',
        '[]',
        jsonEncode(json()..['d'] = 0),
        jsonEncode(json()..['d'] = 10 * 60 * 1000),
        jsonEncode(json()..['s'] = VoiceMeta.maxBytes + 1),
        jsonEncode(json()..['s'] = -1),
        jsonEncode(json()..['h'] = 'nothex'),
        jsonEncode(json()..['w'] = 'zz'),
        jsonEncode(json()..['w'] = 'ab' * (VoiceMeta.waveformBars + 1)),
      ]) {
        expect(() => VoiceMeta.decode(bad), throwsFormatException, reason: bad);
      }
    });

    test('squeezes any recording into the same number of bars, keeping peaks', () {
      expect(VoiceMeta.barsFrom(const []), hasLength(VoiceMeta.waveformBars));
      expect(VoiceMeta.barsFrom(const [1.0]), hasLength(VoiceMeta.waveformBars));
      final long = List.generate(1500, (i) => i == 700 ? 1.0 : 0.1);
      final bars = VoiceMeta.barsFrom(long);
      expect(bars, hasLength(VoiceMeta.waveformBars));
      expect(bars.reduce((a, b) => a > b ? a : b), 255);
    });

    test('formats durations', () {
      expect(formatVoiceDuration(7200), '0:07');
      expect(formatVoiceDuration(102000), '1:42');
    });
  });

  group('voice frames', () {
    const id = '11111111-2222-4333-8444-555555555555';

    test('chunks survive a round trip', () {
      final bytes = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final decoded = VoiceChunk.decode(VoiceChunk(id, 8192, bytes).encode());
      expect(decoded.id, id);
      expect(decoded.offset, 8192);
      expect(decoded.bytes, bytes);
    });

    test('malformed frames are rejected', () {
      expect(() => VoiceChunk.decode(Uint8List(5)), throwsFormatException);
      expect(() => VoiceChunk.decode(Uint8List(40)), throwsFormatException);
      expect(
        () => VoiceChunk.decode(Uint8List(40 + VoiceChunk.maxBytes + 1)),
        throwsFormatException,
      );
      expect(
        () => VoiceRequest.decode(Uint8List.fromList(utf8.encode('{"id":"x","o":1}'))),
        throwsFormatException,
      );
      expect(() => VoiceRequest.decode(VoiceRequest(id, -1).encode()), throwsFormatException);
    });
  });

  group('transfer', () {
    late Phone a;
    late Phone b;

    setUp(() async {
      a = await Phone.create('Alice');
      b = await Phone.create('Bob');
      a.wire.other = b.wire;
      b.wire.other = a.wire;
      await a.start();
      await b.start();
      await a.chatWith(b);
      await b.chatWith(a);
    });

    tearDown(() async {
      await a.dispose();
      await b.dispose();
    });

    Future<Message> sentMessage() async => (await a.messagesWith(b)).last;
    Future<Message> receivedMessage() async => (await b.messagesWith(a)).last;

    Future<bool> delivered() async => (await sentMessage()).status == DeliveryStatus.delivered;

    File receivedFile(Message m) => b.store.audioFile(m.conversationId, m.id);

    test('a voice note arrives intact and only then counts as delivered', () async {
      a.wire.connect();
      final bytes = await a.sendVoiceTo(b, 30000); // four chunks
      await until(delivered);

      final received = await receivedMessage();
      expect(received.type, MessageType.voice);
      expect(await receivedFile(received).readAsBytes(), bytes);
      expect(a.voice.progress, isEmpty);
      expect(b.voice.progress, isEmpty);

      final chunks = a.wire.sent.where((f) => f.type == FrameType.voiceChunk);
      expect(chunks.length, 4);
    });

    test('stays out of delivered until the audio is all there', () async {
      a.wire.connect();
      // The receiver never gets chunks, so it can never finish.
      a.wire.filter = (f) => f.type == FrameType.voiceChunk ? null : f;
      await a.sendVoiceTo(b, 20000);
      await until(() async => (await sentMessage()).status == DeliveryStatus.transferring);
      await settle(120);
      expect((await sentMessage()).status, DeliveryStatus.transferring);
    });

    test('shows a readable preview, not metadata', () async {
      a.wire.connect();
      await a.sendVoiceTo(b, 1000);
      await until(delivered);
      final preview = (await b.chatWith(a)).conversation.lastMessagePreview;
      expect(preview, 'Voice message · 0:12');
      expect((await a.chatWith(b)).conversation.lastMessagePreview, 'Voice message · 0:12');
    });

    test('a dropped link resumes where it stopped, without resending', () async {
      a.wire.connect();
      var chunksSeen = 0;
      a.wire.filter = (f) {
        if (f.type == FrameType.voiceChunk && ++chunksSeen == 3) {
          scheduleMicrotask(a.wire.disconnect);
          return null;
        }
        return f;
      };
      final bytes = await a.sendVoiceTo(b, 40000); // five chunks
      await until(() async => !a.wire.connected);
      await settle(50);

      final received = await receivedMessage();
      final partial = await b.store.partialLength(received.conversationId, received.id);
      expect(partial, 2 * VoiceChunk.maxBytes);
      expect(b.store.hasAudio(received.conversationId, received.id), isFalse);

      a.wire.filter = null;
      final offsets = <int>[];
      b.wire.filter = (f) {
        if (f.type == FrameType.voiceRequest) offsets.add(VoiceRequest.decode(f.body).offset);
        return f;
      };
      a.wire.connect();
      await until(delivered);

      expect(offsets.first, partial, reason: 'must not start from zero');
      expect(await receivedFile(received).readAsBytes(), bytes);
    });

    test('text gets through in the middle of a transfer', () async {
      a.wire.connect();
      // Freeze the audio part way through, so the overlap can't be down to luck.
      var chunks = 0;
      var frozen = true;
      Frame? held;
      a.wire.filter = (f) {
        if (f.type == FrameType.voiceChunk && frozen && ++chunks > 2) {
          held = f;
          return null;
        }
        return f;
      };
      final audio = await a.sendVoiceTo(b, 60000);
      final note = await sentMessage();
      await until(() async => held != null);

      await a.messaging.sendText(await a.chatWith(b), 'Quick question');
      await until(delivered);

      // The text is through while the note is still only part way there.
      final contents = (await b.messagesWith(a)).map((m) => m.content);
      expect(contents, contains('Quick question'));
      expect((await a.messages.find(note.id))!.status, DeliveryStatus.transferring);

      frozen = false;
      b.wire.inject(held!);
      await until(
        () async => (await a.messages.find(note.id))!.status == DeliveryStatus.delivered,
      );
      final received = (await b.messagesWith(a)).firstWhere((m) => m.id == note.id);
      expect(await receivedFile(received).readAsBytes(), audio);
    });

    test('tampered audio is thrown away and never delivered', () async {
      a.wire.connect();
      a.wire.filter = (f) {
        if (f.type != FrameType.voiceChunk) return f;
        final chunk = VoiceChunk.decode(f.body);
        final bytes = Uint8List.fromList(chunk.bytes);
        if (bytes.isNotEmpty) bytes[0] ^= 0xff;
        return Frame(FrameType.voiceChunk, VoiceChunk(chunk.id, chunk.offset, bytes).encode());
      };
      await a.sendVoiceTo(b, 5000);
      await until(() async => b.voice.failed.isNotEmpty);

      final received = await receivedMessage();
      expect(b.store.hasAudio(received.conversationId, received.id), isFalse);
      expect(await b.store.partialLength(received.conversationId, received.id), 0);
      expect((await sentMessage()).status, isNot(DeliveryStatus.delivered));
    });

    test('a failed download can be retried', () async {
      a.wire.connect();
      a.wire.filter = (f) => f.type == FrameType.voiceChunk ? null : f;
      final bytes = await a.sendVoiceTo(b, 3000);
      await until(() async => b.voice.failed.isNotEmpty);

      a.wire.filter = null;
      final received = await receivedMessage();
      await b.voice.retry(received);
      await until(delivered);
      expect(b.voice.failed, isEmpty);
      expect(await receivedFile(received).readAsBytes(), bytes);
    });

    test('audio is only served to the phone it was sent to', () async {
      final c = await Phone.create('Carol');
      addTearDown(() async {
        await c.db.close();
        await c.dir.delete(recursive: true);
      });
      a.wire.connect();
      a.wire.filter = (f) => f.type == FrameType.voiceChunk ? null : f;
      await a.sendVoiceTo(b, 3000);
      await until(() async => a.wire.sent.any((f) => f.type == FrameType.voiceChunk));
      final message = await sentMessage();
      a.wire.sent.clear();

      await a.voice.handle(
        IncomingFrame(c.info, Frame(FrameType.voiceRequest, VoiceRequest(message.id, 0).encode())),
      );
      await settle(20);
      expect(a.wire.sent.where((f) => f.type == FrameType.voiceChunk), isEmpty);
    });

    test('a stranger cannot mark a voice note delivered', () async {
      final c = await Phone.create('Carol');
      addTearDown(() async {
        await c.db.close();
        await c.dir.delete(recursive: true);
      });
      a.wire.connect();
      a.wire.filter = (f) => f.type == FrameType.voiceChunk ? null : f;
      await a.sendVoiceTo(b, 3000);
      await until(() async => (await sentMessage()).status == DeliveryStatus.transferring);
      final message = await sentMessage();

      await a.voice.handle(
        IncomingFrame(c.info, Frame(FrameType.voiceDone, VoiceDone(message.id).encode())),
      );
      expect((await sentMessage()).status, DeliveryStatus.transferring);
    });

    test('a peer cannot make us accept more bytes than announced', () async {
      a.wire.connect();
      a.wire.filter = (f) {
        if (f.type != FrameType.voiceChunk) return f;
        final chunk = VoiceChunk.decode(f.body);
        final bloated = Uint8List(chunk.bytes.length + 100);
        return Frame(FrameType.voiceChunk, VoiceChunk(chunk.id, chunk.offset, bloated).encode());
      };
      await a.sendVoiceTo(b, 500);
      await until(() async => b.voice.failed.isNotEmpty);
      final received = await receivedMessage();
      expect(await b.store.partialLength(received.conversationId, received.id), 0);
    });

    test('malformed voice metadata is refused and not stored', () async {
      a.wire.connect();
      final badHash = jsonEncode({'d': 1000, 's': 100, 'h': 'nope', 'w': ''});
      final conversation = await a.chatWith(b);
      b.wire.inject(
        Frame(
          FrameType.message,
          ChatMessagePayload(
            id: '11111111-2222-4333-8444-555555555555',
            senderId: conversation.peer.id == b.info.id ? a.info.id : b.info.id,
            receiverId: b.info.id,
            type: MessageType.voice,
            content: badHash,
            timestamp: 1000,
            seq: 1,
          ).encode(),
        ),
      );
      await settle(50);
      expect(await b.messagesWith(a), isEmpty);
    });

    test('deleting a conversation deletes its audio', () async {
      a.wire.connect();
      await a.sendVoiceTo(b, 2000);
      await until(delivered);
      final sent = await sentMessage();
      final received = await receivedMessage();
      expect(a.store.hasAudio(sent.conversationId, sent.id), isTrue);
      expect(b.store.hasAudio(received.conversationId, received.id), isTrue);

      await a.conversations.deleteConversation(sent.conversationId);
      await b.conversations.deleteConversation(received.conversationId);

      expect(a.store.hasAudio(sent.conversationId, sent.id), isFalse);
      expect(b.store.hasAudio(received.conversationId, received.id), isFalse);
    });

    test('deleting mid-transfer stops cleanly', () async {
      a.wire.connect();
      var chunks = 0;
      a.wire.filter = (f) {
        if (f.type == FrameType.voiceChunk && ++chunks == 2) return null;
        return f;
      };
      await a.sendVoiceTo(b, 30000);
      await until(() async => chunks >= 2);
      final received = await receivedMessage();
      await b.conversations.deleteConversation(received.conversationId);
      a.wire.filter = null;
      await settle(600);
      expect(b.store.hasAudio(received.conversationId, received.id), isFalse);
      expect(await b.store.partialLength(received.conversationId, received.id), 0);
    });

    test('voice notes wait for a connection like text does', () async {
      await a.sendVoiceTo(b, 2000);
      expect((await sentMessage()).status, DeliveryStatus.pending);
      a.wire.connect();
      await until(delivered);
    });

    test('resent metadata does not duplicate the note', () async {
      a.wire.connect();
      var acks = 0;
      b.wire.filter = (f) => f.type == FrameType.ack && ++acks == 1 ? null : f;
      await a.sendVoiceTo(b, 2000);
      await until(delivered);
      expect(await b.messagesWith(a), hasLength(1));
    });

    test('the file on disk matches its announced hash', () async {
      a.wire.connect();
      final bytes = await a.sendVoiceTo(b, 1234);
      await until(delivered);
      final meta = VoiceMeta.decode((await receivedMessage()).content);
      expect(meta.sizeBytes, 1234);
      expect(meta.sha256, crypto.sha256.convert(bytes).toString());
      expect(meta.waveform, hasLength(VoiceMeta.waveformBars));
    });
  });
}
