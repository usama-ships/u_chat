// The fake controllers skip the real onInit on purpose: it would open streams
// and touch Bluetooth.
// ignore_for_file: must_call_super

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart' show Peripheral;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:u_chat/app/theme/app_theme.dart';
import 'package:u_chat/core/bluetooth/bluetooth_service.dart';
import 'package:u_chat/core/bluetooth/models/ble_availability.dart';
import 'package:u_chat/core/bluetooth/models/discovered_device.dart';
import 'package:u_chat/core/bluetooth/models/peer_info.dart';
import 'package:u_chat/core/database/app_database.dart';
import 'package:u_chat/core/messaging/messaging_service.dart';
import 'package:u_chat/core/security/identity_service.dart';
import 'package:u_chat/core/voice/voice_meta.dart';
import 'package:u_chat/core/voice/voice_recorder.dart';
import 'package:u_chat/data/models/conversation_with_peer.dart';
import 'package:u_chat/data/models/delivery_status.dart';
import 'package:u_chat/data/models/message_type.dart';
import 'package:u_chat/data/repositories/conversation_repository.dart';
import 'package:u_chat/data/repositories/message_repository.dart';
import 'package:u_chat/data/repositories/settings_repository.dart';
import 'package:u_chat/modules/chat/controllers/chat_controller.dart';
import 'package:u_chat/modules/contact/controllers/contact_controller.dart';
import 'package:u_chat/modules/home/controllers/home_controller.dart';
import 'package:u_chat/modules/nearby_devices/controllers/nearby_controller.dart';
import 'package:u_chat/modules/settings/controllers/settings_controller.dart';

/// Loads the real fonts so text in rendered screens isn't drawn as boxes.
Future<void> loadFonts() async {
  final manrope = FontLoader('Manrope');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    manrope.addFont(_font('assets/fonts/Manrope-$weight.ttf'));
  }
  await manrope.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return;
  final icons = FontLoader('MaterialIcons');
  icons.addFont(_font('$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf'));
  await icons.load();
}

Future<ByteData> _font(String path) async =>
    ByteData.sublistView(Uint8List.fromList(File(path).readAsBytesSync()));

class FakeIdentity extends IdentityService {
  FakeIdentity() : super(const FlutterSecureStorage());

  @override
  String get deviceId => 'k3f9a2c7d1e84b06m5t2q8xv1z';
}

/// Holds reactive Bluetooth state only. It is never registered with Get, so
/// `onInit` doesn't run and nothing touches the radio.
class FakeBluetooth extends BluetoothService {
  FakeBluetooth(super.identity, super.settings);
}

class Fixture {
  Fixture() {
    db = AppDatabase(NativeDatabase.memory());
    identity = FakeIdentity();
    settings = SettingsRepository(db.settingsDao, identity);
    conversations = ConversationRepository(db.conversationDao, db.peerDao, identity);
    messages = MessageRepository(db.messageDao, identity);
    bluetooth = FakeBluetooth(identity, settings);
    bluetooth.availability.value = BleAvailability.ready;
    bluetooth.isAdvertising.value = true;
  }

  late final AppDatabase db;
  late final IdentityService identity;
  late final SettingsRepository settings;
  late final ConversationRepository conversations;
  late final MessageRepository messages;
  late final FakeBluetooth bluetooth;
}

final _now = DateTime.now().millisecondsSinceEpoch;

Peer makePeer(String id, String name, {bool verified = false, bool blocked = false}) => Peer(
  id: id,
  displayName: name,
  identityPublicKey: Uint8List.fromList(List.generate(32, (i) => i * 7 % 256)),
  verified: verified,
  platform: 'android',
  firstSeenAt: _now,
  lastSeenAt: _now - 3600000,
  blocked: blocked,
);

ConversationWithPeer convo(Peer p, String preview, {int unread = 0, int minutesAgo = 5}) =>
    ConversationWithPeer(
      peer: p,
      conversation: Conversation(
        id: 'c-${p.id}',
        peerId: p.id,
        lastMessageId: 'm',
        lastMessagePreview: preview,
        lastMessageAt: _now - minutesAgo * 60000,
        unreadCount: unread,
        createdAt: _now,
      ),
    );

Message msg(
  String id,
  String text, {
  bool out = false,
  int minutesAgo = 0,
  DeliveryStatus status = DeliveryStatus.delivered,
}) {
  final at = _now - minutesAgo * 60000;
  return Message(
    id: id,
    conversationId: 'c',
    senderId: out ? 'me' : 'peer',
    receiverId: out ? 'peer' : 'me',
    type: MessageType.text,
    content: text,
    sentAt: at,
    receivedAt: out ? null : at,
    sortAt: at,
    seq: 1,
    status: out ? status : DeliveryStatus.received,
    retryCount: 0,
    isOutgoing: out,
  );
}

/// A voice note with a speech-like waveform.
Message voiceMsg(
  String id, {
  bool out = false,
  int seconds = 14,
  int minutesAgo = 0,
  DeliveryStatus status = DeliveryStatus.delivered,
}) {
  final bars = List.generate(VoiceMeta.waveformBars, (i) {
    final syllable = math.sin(i * 0.9).abs() * math.sin(i * 0.23 + 1).abs();
    return (40 + syllable * 215).round();
  });
  return msg(id, 'x', out: out, minutesAgo: minutesAgo, status: status).copyWith(
    type: MessageType.voice,
    content: VoiceMeta(
      durationMs: seconds * 1000,
      sizeBytes: seconds * 3000,
      sha256: 'a' * 64,
      waveform: bars,
    ).encode(),
  );
}

final samplePeers = [
  makePeer('aa11aa11aaaaaaaaaaaaaaaaaa', 'Ayesha Khan', verified: true),
  makePeer('bb22bb22bbbbbbbbbbbbbbbbbb', 'Bilal Ahmed'),
  makePeer('cc33cc33cccccccccccccccccc', 'Sara Malik'),
  makePeer('dd44dd44dddddddddddddddddd', 'Hamza Raza', blocked: true),
  makePeer('ee55ee55eeeeeeeeeeeeeeeeee', 'A very long display name for layout'),
];

List<ConversationWithPeer> sampleConversations() => [
  convo(samplePeers[0], 'Reached the library. Are you close by?', unread: 3, minutesAgo: 2),
  convo(samplePeers[1], 'Sending the notes over now', unread: 1, minutesAgo: 18),
  convo(samplePeers[2], 'Thanks, see you tomorrow!', minutesAgo: 95),
  convo(samplePeers[3], 'Okay', minutesAgo: 1600),
  convo(samplePeers[4], 'A rather long preview line that has to be cut off', minutesAgo: 9000),
];

List<Message> sampleMessages() => [
  msg('1', 'Hey, are you at the campus today?', minutesAgo: 1500),
  msg('2', 'Yes, near the main gate', out: true, minutesAgo: 1498),
  msg('3', 'There is no signal at all in this building', minutesAgo: 40),
  msg('4', 'That is exactly why this app works so well here', minutesAgo: 39),
  msg('5', 'Ha, true. Bluetooth only, no internet needed.', out: true, minutesAgo: 34),
  msg(
    '6',
    'Can you bring the printed notes for the second half of the lecture? '
        'I left mine at home and the exam is on Monday morning.',
    minutesAgo: 12,
  ),
  msg('7', 'Sure', out: true, minutesAgo: 10),
  msg('8', 'Will be there in ten minutes', out: true, minutesAgo: 10),
  msg('9', 'Queued while out of range', out: true, minutesAgo: 3, status: DeliveryStatus.pending),
  msg('10', 'This one failed', out: true, minutesAgo: 2, status: DeliveryStatus.failed),
];

class FakeHome extends HomeController {
  FakeHome(Fixture f, this.items) : super(f.conversations, f.bluetooth);

  final List<ConversationWithPeer> items;

  @override
  void onInit() {
    conversations.assignAll(items);
    isLoading.value = false;
  }
}

/// Remembers what the chat screen asked it to send.
class RecordingMessaging implements MessagingService {
  final voiceSent = <VoiceRecording>[];

  @override
  Future<void> sendVoice(ConversationWithPeer conversation, VoiceRecording recording) async {
    voiceSent.add(recording);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A microphone that records nothing, with a switch for each outcome.
class FakeRecorder implements VoiceRecorder {
  bool granted = true;
  bool failToStart = false;
  bool recording = false;
  int cancels = 0;
  final _levels = StreamController<double>.broadcast();

  void speak(double level) => _levels.add(level);

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<bool> ensurePermission() async => granted;

  @override
  Future<void> start() async {
    if (failToStart) throw StateError('no microphone');
    recording = true;
  }

  @override
  Future<VoiceRecording?> stop() async {
    recording = false;
    final file = File(
      '${Directory.systemTemp.path}/fake-${DateTime.now().microsecondsSinceEpoch}.m4a',
    )..writeAsBytesSync([1, 2, 3]);
    return VoiceRecording(path: file.path, durationMs: 4000, levels: const [0.5]);
  }

  @override
  Future<void> cancel() async {
    recording = false;
    cancels++;
  }

  @override
  Future<void> dispose() async {}
}

class FakeChat extends ChatController {
  FakeChat(
    Fixture f,
    this.item,
    this.items, {
    FakeRecorder? recorder,
    RecordingMessaging? messaging,
  }) : super(
         f.conversations,
         f.messages,
         f.bluetooth,
         messaging ?? RecordingMessaging(),
         recorder: recorder,
       );

  final ConversationWithPeer item;
  final List<Message> items;

  @override
  void onInit() {
    inputController.addListener(() => canSend.value = inputController.text.trim().isNotEmpty);
    conversation.value = item;
    messages.assignAll(items);
    isLoaded.value = true;
  }

  @override
  bool get hasValidConversation => true;

  // Audio state for voice bubbles, set by each test.
  final voiceProgressById = <String, double>{};
  final voicePathById = <String, String>{};
  final voiceFailedIds = <String>{};
  final progressTick = 0.obs;
  final fakeCurrentId = RxnString();
  final fakePlaying = false.obs;
  final fakePosition = Duration.zero.obs;

  @override
  double? voiceProgress(String id) {
    progressTick.value;
    return voiceProgressById[id];
  }

  @override
  bool voiceFailed(String id) => voiceFailedIds.contains(id);

  @override
  String? voicePath(Message message) => voicePathById[message.id];

  @override
  String? get currentVoiceId => fakeCurrentId.value;

  @override
  bool get isVoicePlaying => fakePlaying.value;

  @override
  Duration get voicePosition => fakePosition.value;

  @override
  void onClose() {}
}

class FakeContact extends ContactController {
  FakeContact(Fixture f, this.p) : super(f.conversations, f.bluetooth, f.identity);

  final Peer p;

  @override
  void onInit() {
    peerId = p.id;
    super.peer.value = p;
    isLoaded.value = true;
  }

  @override
  String? get safetyNumberText => '48213 90175 66302 18847 05921 73460';
}

class FakeSettings extends SettingsController {
  FakeSettings(Fixture f) : super(f.identity, f.settings, f.conversations, f.bluetooth);

  @override
  void onInit() => displayName.value = 'Usama';
}

class FakeNearby extends NearbyController {
  FakeNearby(Fixture f) : super(f.bluetooth, f.conversations);

  @override
  void onInit() {}

  @override
  void onReady() {}

  @override
  void onClose() {}
}

class _NoPeripheral implements Peripheral {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

DiscoveredDevice device(String prefix, String name, int rssi) => DiscoveredDevice(
  deviceIdPrefix: prefix,
  displayName: name,
  rssi: rssi,
  lastSeen: DateTime(2026),
  peripheral: _NoPeripheral(),
);

PeerInfo fakePeerInfo() => PeerInfo(
  id: samplePeers[0].id,
  displayName: samplePeers[0].displayName,
  publicKey: Uint8List(32),
);

final shotKey = GlobalKey();

/// Pumps [screen] at a device size inside the real theme.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 844),
  double textScale = 1,
  double settle = 1.4,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 36 * 3, bottom: 16 * 3);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  // Flutter tests draw hard-edged shadows unless told otherwise.
  debugDisableShadows = false;
  await tester.pumpWidget(
    GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: screen,
      // Above the Navigator, so shots include dialogs and sheets.
      builder: (context, child) => RepaintBoundary(key: shotKey, child: child!),
    ),
  );
  await pumpFor(tester, settle);
}

/// Advances time frame by frame. Looping animations mean `pumpAndSettle`
/// would never return.
Future<void> pumpFor(WidgetTester tester, double seconds) async {
  final frames = (seconds * 30).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 33));
  }
}

/// Writes the current frame to `$UI_SHOTS_DIR/<name>.png` when that variable
/// is set. Every test must end with this: it also restores the shadow flag,
/// which the test framework checks before tear-down.
Future<void> shot(WidgetTester tester, String name) async {
  final dir = Platform.environment['UI_SHOTS_DIR'];
  if (dir != null) {
    await tester.runAsync(() async {
      final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }
  debugDisableShadows = true;
}
