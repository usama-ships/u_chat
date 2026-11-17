import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/painting.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:u_chat/app/widgets/buttons.dart';
import 'package:u_chat/core/bluetooth/models/ble_availability.dart';
import 'package:u_chat/modules/chat/controllers/chat_controller.dart';
import 'package:u_chat/modules/chat/views/chat_view.dart';
import 'package:u_chat/modules/contact/controllers/contact_controller.dart';
import 'package:u_chat/modules/contact/views/contact_view.dart';

import 'ui_harness.dart';

/// Tapping Connect must show it's working straight away, even while the other
/// phone is still being looked for, which can take up to 25 seconds.
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

  group('chat', () {
    Future<void> openChat(WidgetTester tester) async {
      Get.put<ChatController>(FakeChat(f, convo(samplePeers[0], 'x'), sampleMessages()));
      await pumpScreen(tester, const ChatView());
    }

    testWidgets('shows the search at once, then says if nobody was found', (tester) async {
      await openChat(tester);
      await tester.tap(find.text('Connect'));
      await pumpFor(tester, 0.5);

      expect(f.bluetooth.connectCalls, 1);
      expect(find.text('Looking for this device nearby…'), findsOneWidget);
      expect(find.text('Connecting…'), findsOneWidget);
      expect(find.byType(BusySpinner), findsOneWidget);
      await shot(tester, 'x-connect-searching');
      debugDisableShadows = false;

      // A second tap while searching doesn't start another attempt.
      expect(find.text('Connect'), findsNothing);

      f.bluetooth.pendingConnect!.complete(false);
      await pumpFor(tester, 0.7);
      expect(find.text('Could not connect'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget, reason: 'the button comes back to try again');
      await shot(tester, 'x-connect-not-found');
      debugDisableShadows = false;
      await pumpFor(tester, 4);
      await shot(tester, 'x-connect-after');
    });

    testWidgets('Bluetooth off says so instead of searching', (tester) async {
      await openChat(tester);
      f.bluetooth.availability.value = BleAvailability.poweredOff;
      await tester.tap(find.text('Connect'));
      await pumpFor(tester, 0.7);

      expect(f.bluetooth.connectCalls, 0);
      expect(find.textContaining('Bluetooth is off'), findsOneWidget);
      await shot(tester, 'x-connect-bluetooth-off');
      debugDisableShadows = false;
      await pumpFor(tester, 4);
      await shot(tester, 'x-connect-bluetooth-off-after');
    });

    testWidgets('a successful search clears the searching state', (tester) async {
      await openChat(tester);
      await tester.tap(find.text('Connect'));
      await pumpFor(tester, 0.3);
      f.bluetooth.connectedPeers[samplePeers[0].id] = fakePeerInfo();
      f.bluetooth.pendingConnect!.complete(true);
      await pumpFor(tester, 0.7);

      expect(Get.find<ChatController>().isSearching.value, isFalse);
      expect(find.text('Looking for this device nearby…'), findsNothing);
      expect(find.textContaining('Connected'), findsOneWidget);
      await shot(tester, 'x-connect-done');
    });
  });

  group('contact', () {
    testWidgets('the Connect button shows the search too', (tester) async {
      Get.put<ContactController>(FakeContact(f, samplePeers[0]));
      await pumpScreen(tester, const ContactView());
      await tester.tap(find.text('Connect'));
      await pumpFor(tester, 0.5);

      expect(f.bluetooth.connectCalls, 1);
      expect(find.text('Connecting…'), findsOneWidget);
      await shot(tester, 'x-contact-searching');
      debugDisableShadows = false;

      f.bluetooth.pendingConnect!.complete(false);
      await pumpFor(tester, 0.7);
      expect(find.text('Could not connect'), findsOneWidget);
      await pumpFor(tester, 4);
      await shot(tester, 'x-contact-not-found');
    });
  });
}
