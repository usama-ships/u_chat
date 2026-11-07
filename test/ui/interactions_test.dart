import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:u_chat/app/routes/app_pages.dart';
import 'package:u_chat/app/theme/app_motion.dart';
import 'package:u_chat/app/theme/app_theme.dart';
import 'package:u_chat/app/widgets/overlays.dart';
import 'package:u_chat/modules/chat/controllers/chat_controller.dart';
import 'package:u_chat/modules/chat/views/chat_view.dart';
import 'package:u_chat/modules/chat/widgets/message_bubble.dart';
import 'package:u_chat/modules/home/controllers/home_controller.dart';
import 'package:u_chat/modules/home/views/home_view.dart';
import 'package:u_chat/modules/nearby_devices/controllers/nearby_controller.dart';
import 'package:u_chat/modules/nearby_devices/views/nearby_view.dart';
import 'package:u_chat/modules/settings/controllers/settings_controller.dart';
import 'package:u_chat/modules/settings/views/settings_view.dart';

import 'ui_harness.dart';

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

  testWidgets('a new message grows in and older ones stay put', (tester) async {
    final chat = FakeChat(f, convo(samplePeers[0], 'x'), sampleMessages());
    Get.put<ChatController>(chat);
    await pumpScreen(tester, const ChatView());

    final bubblesBefore = find.byType(MessageBubble).evaluate().length;
    chat.messages.add(msg('new', 'Just arrived'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    // Part way through, it's on screen but not yet at full height.
    final textFinder = find.text('Just arrived');
    expect(textFinder, findsOneWidget);
    final grow = find.ancestor(of: textFinder, matching: find.byType(SizeTransition)).first;
    expect(tester.widget<SizeTransition>(grow).sizeFactor.value, inExclusiveRange(0, 1));
    await shot(tester, 'x-message-arriving');

    await pumpFor(tester, 0.7);
    expect(tester.widget<SizeTransition>(grow).sizeFactor.value, 1);
    expect(find.byType(MessageBubble).evaluate().length, greaterThanOrEqualTo(bubblesBefore));
    await shot(tester, 'x-message-arrived');
  });

  testWidgets('loading older messages does not animate them as new', (tester) async {
    final chat = FakeChat(f, convo(samplePeers[0], 'x'), sampleMessages());
    Get.put<ChatController>(chat);
    await pumpScreen(tester, const ChatView(), size: const Size(390, 2000));

    chat.messages.insert(0, msg('old', 'From last week', minutesAgo: 9000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    final oldText = find.text('From last week');
    expect(oldText, findsOneWidget);
    expect(find.ancestor(of: oldText, matching: find.byType(SizeTransition)), findsNothing);
    await shot(tester, 'x-older-loaded');
  });

  testWidgets('composer rides on top of the keyboard', (tester) async {
    Get.put<ChatController>(FakeChat(f, convo(samplePeers[0], 'x'), sampleMessages()));
    await pumpScreen(tester, const ChatView());
    final restingTop = tester.getTopLeft(find.byType(TextField)).dy;

    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
    addTearDown(tester.view.resetViewInsets);
    await pumpFor(tester, 0.2);

    final raisedBottom = tester.getBottomLeft(find.byType(TextField)).dy;
    expect(tester.getTopLeft(find.byType(TextField)).dy, lessThan(restingTop));
    expect(raisedBottom, lessThanOrEqualTo(844 - 300));
    await shot(tester, 'x-keyboard');
  });

  testWidgets('send button wakes up when there is text', (tester) async {
    final chat = FakeChat(f, convo(samplePeers[0], 'x'), const []);
    Get.put<ChatController>(chat);
    await pumpScreen(tester, const ChatView());
    expect(chat.canSend.value, isFalse);
    await tester.enterText(find.byType(TextField), 'hello');
    await pumpFor(tester, 0.4);
    expect(chat.canSend.value, isTrue);
    await shot(tester, 'x-send-ready');
  });

  testWidgets('delete confirmation resolves with the choice', (tester) async {
    Get.put<HomeController>(FakeHome(f, sampleConversations()));
    await pumpScreen(tester, const HomeView());
    final context = tester.element(find.byType(HomeView));

    final first = showGlassConfirm(
      context,
      title: 'Delete conversation?',
      message:
          'All messages with Ayesha Khan will be removed from this phone. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    await pumpFor(tester, 0.5);
    await shot(tester, 'x-dialog');
    await tester.tap(find.text('Delete'));
    await pumpFor(tester, 0.5);
    expect(await first, isTrue);

    final second = showGlassConfirm(
      context,
      title: 'Delete conversation?',
      message: 'Sure?',
      confirmLabel: 'Delete',
    );
    await pumpFor(tester, 0.5);
    await tester.tap(find.text('Cancel'));
    await pumpFor(tester, 0.5);
    expect(await second, isFalse);
    await shot(tester, 'x-after-dialog');
  });

  testWidgets('long-pressing a message opens its actions', (tester) async {
    Get.put<ChatController>(FakeChat(f, convo(samplePeers[0], 'x'), sampleMessages()));
    await pumpScreen(tester, const ChatView());
    await tester.longPress(find.text('This one failed'));
    await pumpFor(tester, 0.6);
    expect(find.text('Copy text'), findsOneWidget);
    expect(find.text('Retry sending'), findsOneWidget);
    await shot(tester, 'x-sheet');
  });

  testWidgets('display name dialog opens from the profile card', (tester) async {
    Get.put<SettingsController>(FakeSettings(f));
    await pumpScreen(tester, const SettingsView());
    await tester.tap(find.text('Usama'));
    await pumpFor(tester, 0.5);
    expect(find.text('Display name'), findsOneWidget);
    await shot(tester, 'x-edit-name');
  });

  testWidgets('toast shows and clears', (tester) async {
    Get.put<HomeController>(FakeHome(f, sampleConversations()));
    await pumpScreen(tester, const HomeView());
    showToast('Could not connect', "Ayesha Khan wasn't found nearby.");
    await pumpFor(tester, 0.7);
    expect(find.text('Could not connect'), findsOneWidget);
    await shot(tester, 'x-toast');
    await pumpFor(tester, 4);
    expect(find.text('Could not connect'), findsNothing);
  });

  testWidgets('pages use the glass transition and get a back button', (tester) async {
    Get.put<HomeController>(FakeHome(f, sampleConversations()));
    Get.put<SettingsController>(FakeSettings(f));
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 36 * 3, bottom: 16 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        getPages: [
          GetPage(
            name: '/',
            page: () => const HomeView(),
            customTransition: GlassPageTransition(),
            transitionDuration: Motion.page,
          ),
          GetPage(
            name: '/settings',
            page: () => const SettingsView(),
            customTransition: GlassPageTransition(),
            transitionDuration: Motion.page,
          ),
        ],
        builder: (context, child) => RepaintBoundary(key: shotKey, child: child!),
      ),
    );
    await pumpFor(tester, 1);
    expect(find.byTooltip('Back'), findsNothing);

    Get.toNamed<void>('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(find.byType(FadeTransition), findsWidgets);
    await shot(tester, 'x-transition-mid');
    debugDisableShadows = false;

    await pumpFor(tester, 1);
    await shot(tester, 'x-settings-with-back');
    expect(find.byTooltip('Back'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await pumpFor(tester, 1);
    expect(find.byType(SettingsView), findsNothing);
    expect(find.byType(HomeView), findsOneWidget);
  });

  testWidgets('nothing keeps animating when Android animations are off', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    Get.put<HomeController>(FakeHome(f, sampleConversations()));
    await pumpScreen(tester, const HomeView());

    // pumpAndSettle times out if any ticker is still running.
    await tester.pumpAndSettle();
    expect(find.text('Ayesha Khan'), findsOneWidget);
    await shot(tester, 'x-reduced-motion');
  });

  testWidgets('radar stops ticking once a scan ends', (tester) async {
    f.bluetooth.isScanning.value = true;
    f.bluetooth.discovered.assign(device('aa11aa11', 'Ayesha Khan', -52));
    Get.put<NearbyController>(FakeNearby(f));
    await pumpScreen(tester, const NearbyView());
    f.bluetooth.isScanning.value = false;
    await pumpFor(tester, 1);
    expect(find.text('Scan again'), findsOneWidget);
    await shot(tester, 'x-scan-ended');
  });
}
