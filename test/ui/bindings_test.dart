import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:u_chat/core/bluetooth/bluetooth_service.dart';
import 'package:u_chat/core/messaging/messaging_service.dart';
import 'package:u_chat/core/messaging/voice_transfer_service.dart';
import 'package:u_chat/core/voice/voice_player.dart';
import 'package:u_chat/core/voice/voice_store.dart';
import 'package:u_chat/data/repositories/conversation_repository.dart';
import 'package:u_chat/data/repositories/message_repository.dart';
import 'package:u_chat/modules/chat/bindings/chat_binding.dart';
import 'package:u_chat/modules/chat/controllers/chat_controller.dart';

import 'ui_harness.dart';

/// Builds controllers the way the app does, through each screen's binding,
/// with services registered the way `AppDependencies` registers them.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Fixture f;
  late Directory dir;

  setUp(() async {
    Get.testMode = true;
    Get.reset();
    f = Fixture();
    dir = await Directory.systemTemp.createTemp('bindings-test');
    final store = VoiceStore(dir);
    Get
      ..put<ConversationRepository>(f.conversations)
      ..put<MessageRepository>(f.messages)
      ..put<BluetoothService>(f.bluetooth)
      ..put(MessagingService(f.bluetooth, f.conversations, f.messages))
      ..put(store)
      ..put(VoicePlayer())
      ..put(VoiceTransferService(f.bluetooth, f.messages, store));
  });

  tearDown(() async {
    Get.reset();
    await f.db.close();
    await dir.delete(recursive: true);
  });

  test('the chat binding finds every voice service', () {
    final player = Get.find<VoicePlayer>()..speed.value = 2;
    ChatBinding(recorder: FakeRecorder.new).dependencies();

    final controller = Get.find<ChatController>();

    // Reads through to the registered player, so a missing lookup shows here.
    expect(controller.voiceSpeed, 2);
    player.speed.value = 1.5;
    expect(controller.voiceSpeed, 1.5);
  });
}
