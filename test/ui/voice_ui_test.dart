import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:u_chat/core/database/app_database.dart';
import 'package:u_chat/core/voice/voice_meta.dart';
import 'package:u_chat/data/models/delivery_status.dart';
import 'package:u_chat/modules/chat/controllers/chat_controller.dart';
import 'package:u_chat/modules/chat/views/chat_view.dart';
import 'package:u_chat/modules/chat/widgets/voice_composer.dart';

import 'ui_harness.dart';

List<Message> voiceChat() => [
  msg('1', 'Can you hear this?', minutesAgo: 30),
  voiceMsg('2', seconds: 14, minutesAgo: 28),
  voiceMsg('3', out: true, seconds: 8, minutesAgo: 20),
  voiceMsg('4', seconds: 96, minutesAgo: 12),
  voiceMsg('5', out: true, seconds: 41, minutesAgo: 6, status: DeliveryStatus.transferring),
  voiceMsg('6', seconds: 22, minutesAgo: 3),
  voiceMsg('7', seconds: 5, minutesAgo: 1),
];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Fixture f;
  late FakeRecorder recorder;
  late RecordingMessaging messaging;

  setUpAll(loadFonts);
  setUp(() {
    Get.testMode = true;
    Get.reset();
    f = Fixture();
    recorder = FakeRecorder();
    messaging = RecordingMessaging();
  });
  tearDown(() async {
    Get.reset();
    await f.db.close();
  });

  FakeChat chat(List<Message> messages) {
    final controller = FakeChat(
      f,
      convo(samplePeers[0], 'x'),
      messages,
      recorder: recorder,
      messaging: messaging,
    );
    Get.put<ChatController>(controller);
    return controller;
  }

  FakeChat fullVoiceChat() {
    f.bluetooth.connectedPeers[samplePeers[0].id] = fakePeerInfo();
    return chat(voiceChat())
      ..voicePathById.addAll({'2': '/a.m4a', '3': '/b.m4a', '4': '/c.m4a', '5': '/d.m4a'})
      ..voiceProgressById.addAll({'5': 0.62, '6': 0.35})
      ..voiceFailedIds.add('7')
      ..fakeCurrentId.value = '4'
      ..fakePlaying.value = true
      ..fakePosition.value = const Duration(seconds: 38);
  }

  Offset micCentre(WidgetTester tester) => tester.getCenter(find.byType(MicButton));

  group('voice bubbles', () {
    const sizes = {
      'small': Size(320, 568),
      'phone': Size(390, 844),
      'landscape': Size(844, 390),
      'tablet': Size(1024, 768),
    };

    for (final MapEntry(key: label, value: size) in sizes.entries) {
      for (final scale in const [1.0, 1.5]) {
        testWidgets('every state lays out on $label at ${scale}x text', (tester) async {
          fullVoiceChat();
          await pumpScreen(tester, const ChatView(), size: size, textScale: scale);
          await shot(tester, 'voice-$label${scale == 1 ? '' : '-large-text'}');
        });
      }
    }

    testWidgets('shows what each transfer is doing', (tester) async {
      fullVoiceChat();
      await pumpScreen(tester, const ChatView(), size: const Size(390, 1100));
      expect(find.text('62%'), findsOneWidget);
      expect(find.text('35%'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await shot(tester, 'x-voice-states');
    });

    testWidgets('only the loaded note shows speed and position', (tester) async {
      fullVoiceChat();
      await pumpScreen(tester, const ChatView(), size: const Size(390, 1100));
      expect(find.text('1×'), findsOneWidget);
      expect(find.text('0:38'), findsOneWidget);
      expect(find.text('1:36'), findsNothing, reason: 'shows position while loaded');
      await shot(tester, 'x-voice-loaded');
    });

    testWidgets('voice notes have no copy action', (tester) async {
      chat(voiceChat()).voicePathById['2'] = '/a.m4a';
      await pumpScreen(tester, const ChatView(), size: const Size(390, 1100));
      await tester.longPress(find.text('0:14'));
      await pumpFor(tester, 0.6);
      expect(find.text('Copy text'), findsNothing);
      await shot(tester, 'x-voice-sheet');
    });

    testWidgets('a corrupt row falls back to plain text, not a crash', (tester) async {
      chat([voiceMsg('1').copyWith(content: 'broken')]);
      await pumpScreen(tester, const ChatView());
      expect(find.text('broken'), findsOneWidget);
      await shot(tester, 'x-voice-corrupt');
    });
  });

  group('recording', () {
    testWidgets('the mic shows when there is no text, send when there is', (tester) async {
      final controller = chat(const []);
      await pumpScreen(tester, const ChatView());
      expect(find.byType(MicButton), findsOneWidget);
      controller.inputController.text = 'hello';
      await pumpFor(tester, 0.4);
      expect(find.byType(MicButton), findsNothing);
      await shot(tester, 'x-mic-swap');
    });

    testWidgets('hold to record, release to send', (tester) async {
      final controller = chat(sampleMessages());
      await pumpScreen(tester, const ChatView());

      final gesture = await tester.startGesture(micCentre(tester));
      await pumpFor(tester, 1.2);
      expect(recorder.recording, isTrue);
      expect(find.byType(RecordingPanel), findsOneWidget);
      expect(find.text('0:01'), findsOneWidget);

      for (final level in const [0.2, 0.9, 0.4, 0.7, 0.3, 0.8, 0.5]) {
        recorder.speak(level);
        await tester.pump(const Duration(milliseconds: 80));
      }
      await pumpFor(tester, 0.2);
      await shot(tester, 'x-recording');
      debugDisableShadows = false;

      await gesture.up();
      await pumpFor(tester, 0.5);
      expect(controller.recordingMode.value, RecordingMode.idle);
      expect(messaging.voiceSent, hasLength(1));
      expect(find.byType(RecordingPanel), findsNothing);
      await shot(tester, 'x-recording-done');
    });

    testWidgets('a quick tap sends nothing and explains why', (tester) async {
      chat(const []);
      await pumpScreen(tester, const ChatView());
      await tester.tap(find.byType(MicButton));
      await pumpFor(tester, 0.7);
      expect(messaging.voiceSent, isEmpty);
      expect(find.text('Hold to record'), findsOneWidget);
      await shot(tester, 'x-too-short');
      debugDisableShadows = false;
      await pumpFor(tester, 4);
      await shot(tester, 'x-too-short-after');
    });

    testWidgets('sliding left cancels', (tester) async {
      chat(const []);
      await pumpScreen(tester, const ChatView());
      final gesture = await tester.startGesture(micCentre(tester));
      await pumpFor(tester, 1);
      await gesture.moveBy(const Offset(-70, 0));
      await pumpFor(tester, 0.1);
      expect(recorder.recording, isTrue);
      await shot(tester, 'x-cancel-drag');
      debugDisableShadows = false;

      await gesture.moveBy(const Offset(-60, 0));
      await pumpFor(tester, 0.5);
      expect(recorder.recording, isFalse);
      expect(recorder.cancels, 1);

      await gesture.up();
      await pumpFor(tester, 0.3);
      expect(messaging.voiceSent, isEmpty);
      await shot(tester, 'x-cancelled');
    });

    testWidgets('sliding up locks, then send finishes it', (tester) async {
      final controller = chat(const []);
      await pumpScreen(tester, const ChatView());
      final gesture = await tester.startGesture(micCentre(tester));
      await pumpFor(tester, 1);
      await gesture.moveBy(const Offset(0, -80));
      await pumpFor(tester, 0.3);
      await gesture.up();
      await pumpFor(tester, 0.5);

      expect(controller.recordingMode.value, RecordingMode.locked);
      expect(recorder.recording, isTrue, reason: 'lifting the finger must not stop it');
      await shot(tester, 'x-locked');
      debugDisableShadows = false;

      await tester.tap(find.byTooltip('Send'));
      await pumpFor(tester, 0.5);
      expect(messaging.voiceSent, hasLength(1));
      await shot(tester, 'x-locked-sent');
    });

    testWidgets('a locked recording can be discarded', (tester) async {
      final controller = chat(const []);
      await pumpScreen(tester, const ChatView());
      await controller.startRecording(locked: true);
      await pumpFor(tester, 1);
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await pumpFor(tester, 0.5);
      expect(recorder.cancels, 1);
      expect(messaging.voiceSent, isEmpty);
      await shot(tester, 'x-discarded');
    });

    testWidgets('stops itself at the two minute limit and sends', (tester) async {
      final controller = chat(const []);
      await pumpScreen(tester, const ChatView());
      await controller.startRecording(locked: true);
      await tester.pump(const Duration(milliseconds: VoiceMeta.maxRecordingMs - 1000));
      expect(recorder.recording, isTrue);
      await tester.pump(const Duration(milliseconds: 1200));
      await pumpFor(tester, 0.5);
      expect(recorder.recording, isFalse);
      expect(messaging.voiceSent, hasLength(1));
      await shot(tester, 'x-limit');
    });

    testWidgets('warns near the limit', (tester) async {
      final controller = chat(const []);
      await pumpScreen(tester, const ChatView());
      await controller.startRecording(locked: true);
      await tester.pump(const Duration(milliseconds: VoiceMeta.maxRecordingMs - 5000));
      await pumpFor(tester, 0.3);
      await shot(tester, 'x-near-limit');
      debugDisableShadows = false;
      await controller.cancelRecording();
      await pumpFor(tester, 0.4);
      await shot(tester, 'x-near-limit-after');
    });

    testWidgets('refused microphone explains itself and records nothing', (tester) async {
      recorder.granted = false;
      chat(const []);
      await pumpScreen(tester, const ChatView());
      final gesture = await tester.startGesture(micCentre(tester));
      await pumpFor(tester, 0.7);
      expect(recorder.recording, isFalse);
      expect(find.text('Microphone needed'), findsOneWidget);
      await gesture.up();
      await pumpFor(tester, 4);
      await shot(tester, 'x-mic-refused');
    });

    testWidgets('a failing microphone recovers cleanly', (tester) async {
      recorder.failToStart = true;
      final controller = chat(const []);
      await pumpScreen(tester, const ChatView());
      final gesture = await tester.startGesture(micCentre(tester));
      await pumpFor(tester, 0.7);
      expect(controller.recordingMode.value, RecordingMode.idle);
      expect(find.text('Cannot record'), findsOneWidget);
      await gesture.up();
      await pumpFor(tester, 4);
      expect(messaging.voiceSent, isEmpty);
      await shot(tester, 'x-mic-failed');
    });

    testWidgets('screen readers can record without holding', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = chat(const []);
      await pumpScreen(tester, const ChatView());
      tester.semantics.tap(find.semantics.byLabel('Record a voice message'));
      await pumpFor(tester, 0.5);
      expect(controller.recordingMode.value, RecordingMode.locked);
      await controller.cancelRecording();
      await pumpFor(tester, 0.3);
      await shot(tester, 'x-semantics');
      handle.dispose();
    });
  });
}
