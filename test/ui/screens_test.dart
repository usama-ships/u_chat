import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:u_chat/core/bluetooth/models/ble_availability.dart';
import 'package:u_chat/data/models/conversation_with_peer.dart';
import 'package:u_chat/modules/chat/controllers/chat_controller.dart';
import 'package:u_chat/modules/chat/views/chat_view.dart';
import 'package:u_chat/modules/contact/controllers/contact_controller.dart';
import 'package:u_chat/modules/contact/views/contact_view.dart';
import 'package:u_chat/modules/home/controllers/home_controller.dart';
import 'package:u_chat/modules/home/views/home_view.dart';
import 'package:u_chat/modules/nearby_devices/controllers/nearby_controller.dart';
import 'package:u_chat/modules/nearby_devices/views/nearby_view.dart';
import 'package:u_chat/modules/settings/controllers/settings_controller.dart';
import 'package:u_chat/modules/settings/views/settings_view.dart';

import 'ui_harness.dart';

/// Every screen must lay out cleanly on each of these, at normal and at the
/// largest supported text size. A layout overflow fails the test.
///
/// To see the screens: `UI_SHOTS_DIR=some/dir flutter test test/ui`.
const sizes = <String, Size>{
  'small': Size(320, 568),
  'phone': Size(390, 844),
  'landscape': Size(844, 390),
  'tablet': Size(1024, 768),
};

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Fixture f;

  setUpAll(loadFonts);
  setUp(() {
    Get.testMode = true;
    Get.reset();
    f = Fixture();
  });
  tearDown(() async {
    Get.reset();
    await f.db.close();
  });

  for (final MapEntry(key: label, value: size) in sizes.entries) {
    for (final scale in const [1.0, 1.5]) {
      final tag = '$label${scale == 1 ? '' : '-large-text'}';

      testWidgets('home $tag', (tester) async {
        f.bluetooth.connectedPeers[samplePeers[0].id] = fakePeerInfo();
        Get.put<HomeController>(FakeHome(f, sampleConversations()));
        await pumpScreen(tester, const HomeView(), size: size, textScale: scale);
        await shot(tester, 'home-$tag');
      });

      testWidgets('home empty $tag', (tester) async {
        Get.put<HomeController>(FakeHome(f, const <ConversationWithPeer>[]));
        await pumpScreen(tester, const HomeView(), size: size, textScale: scale);
        await shot(tester, 'home-empty-$tag');
      });

      testWidgets('chat offline $tag', (tester) async {
        Get.put<ChatController>(FakeChat(f, convo(samplePeers[0], 'x'), sampleMessages()));
        await pumpScreen(tester, const ChatView(), size: size, textScale: scale);
        await shot(tester, 'chat-offline-$tag');
      });

      testWidgets('chat connected $tag', (tester) async {
        f.bluetooth.connectedPeers[samplePeers[0].id] = fakePeerInfo();
        f.bluetooth.peerLatencyMs[samplePeers[0].id] = 42;
        final chat = FakeChat(f, convo(samplePeers[0], 'x'), sampleMessages());
        Get.put<ChatController>(chat);
        await pumpScreen(tester, const ChatView(), size: size, textScale: scale);
        chat.inputController.text = 'On my way';
        await pumpFor(tester, 0.6);
        await shot(tester, 'chat-connected-$tag');
      });

      testWidgets('chat empty $tag', (tester) async {
        Get.put<ChatController>(FakeChat(f, convo(samplePeers[1], 'x'), const []));
        await pumpScreen(tester, const ChatView(), size: size, textScale: scale);
        await shot(tester, 'chat-empty-$tag');
      });

      testWidgets('chat blocked $tag', (tester) async {
        Get.put<ChatController>(FakeChat(f, convo(samplePeers[3], 'x'), sampleMessages()));
        await pumpScreen(tester, const ChatView(), size: size, textScale: scale);
        await shot(tester, 'chat-blocked-$tag');
      });

      testWidgets('nearby with devices $tag', (tester) async {
        f.bluetooth.isScanning.value = true;
        f.bluetooth.discovered.assignAll([
          device('aa11aa11', 'Ayesha Khan', -52),
          device('ff66ff66', 'Galaxy of Zain', -70),
          device('gg77gg77', 'Pixel Room 12', -86),
        ]);
        Get.put<NearbyController>(FakeNearby(f));
        await pumpScreen(tester, const NearbyView(), size: size, textScale: scale);
        await shot(tester, 'nearby-$tag');
      });

      testWidgets('nearby scanning $tag', (tester) async {
        f.bluetooth.isScanning.value = true;
        Get.put<NearbyController>(FakeNearby(f));
        await pumpScreen(tester, const NearbyView(), size: size, textScale: scale);
        await shot(tester, 'nearby-scanning-$tag');
      });

      testWidgets('nearby permission $tag', (tester) async {
        f.bluetooth.availability.value = BleAvailability.unauthorized;
        Get.put<NearbyController>(FakeNearby(f));
        await pumpScreen(tester, const NearbyView(), size: size, textScale: scale);
        await shot(tester, 'nearby-permission-$tag');
      });

      testWidgets('contact $tag', (tester) async {
        Get.put<ContactController>(FakeContact(f, samplePeers[0]));
        await pumpScreen(tester, const ContactView(), size: size, textScale: scale);
        await shot(tester, 'contact-$tag');
      });

      testWidgets('settings $tag', (tester) async {
        Get.put<SettingsController>(FakeSettings(f));
        await pumpScreen(tester, const SettingsView(), size: size, textScale: scale);
        await shot(tester, 'settings-$tag');
      });
    }
  }
}
