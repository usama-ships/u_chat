import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/widgets/overlays.dart';
import '../../../core/bluetooth/bluetooth_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/messaging/messaging_service.dart';
import '../../../core/messaging/voice_transfer_service.dart';
import '../../../core/voice/voice_meta.dart';
import '../../../core/voice/voice_player.dart';
import '../../../core/voice/voice_recorder.dart';
import '../../../core/voice/voice_store.dart';
import '../../../data/models/conversation_with_peer.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/message_repository.dart';

enum RecordingMode { idle, holding, locked }

class ChatController extends GetxController {
  ChatController(
    this._conversations,
    this._messages,
    this._bluetooth,
    this._messaging, {
    this._recorder,
    this._player,
    this._transfer,
    this._store,
  });

  static const pageSize = 100;

  final ConversationRepository _conversations;
  final MessageRepository _messages;
  final BluetoothService _bluetooth;
  final MessagingService _messaging;
  final VoiceRecorder? _recorder;
  final VoicePlayer? _player;
  final VoiceTransferService? _transfer;
  final VoiceStore? _store;

  final inputController = TextEditingController();

  final conversation = Rxn<ConversationWithPeer>();
  final messages = <Message>[].obs;
  final isLoaded = false.obs;
  final canSend = false.obs;
  final isSending = false.obs;

  /// True when older messages exist beyond the loaded page(s).
  final hasMore = false.obs;

  final recordingMode = RecordingMode.idle.obs;
  final recordingMs = 0.obs;
  final liveLevels = <double>[].obs;

  /// How far the finger has slid towards cancelling and locking, 0 to 1.
  final recordingDrag = (cancel: 0.0, lock: 0.0).obs;

  String? _conversationId;
  int _limit = pageSize;
  StreamSubscription<ConversationWithPeer?>? _conversationSub;
  StreamSubscription<List<Message>>? _messagesSub;

  String? get peerId => conversation.value?.peer.id;
  bool get isBlocked => conversation.value?.peer.blocked ?? false;

  // Reactive getters: read inside Obx.
  bool get isConnected => peerId != null && _bluetooth.connectedPeers.containsKey(peerId);
  bool get isConnecting => peerId != null && _bluetooth.isConnectingTo(peerId!);
  int? get latencyMs => peerId == null ? null : _bluetooth.peerLatencyMs[peerId];

  @override
  void onInit() {
    super.onInit();
    inputController.addListener(_onInputChanged);

    final args = Get.arguments;
    if (args is! String) {
      isLoaded.value = true;
      return;
    }
    _conversationId = args;
    _messaging.activeConversationId = args;

    _conversationSub = _conversations.watchConversation(args).listen((item) {
      conversation.value = item;
      isLoaded.value = true;
      if (item != null && item.conversation.unreadCount > 0) {
        _conversations.markRead(args);
      }
    });
    _watchMessages();
  }

  void _watchMessages() {
    _messagesSub?.cancel();
    _messagesSub = _messages.watchRecentMessages(_conversationId!, limit: _limit).listen((items) {
      messages.assignAll(items);
      hasMore.value = items.length >= _limit;
    });
  }

  /// Loads the next page of older messages.
  void loadMore() {
    if (!hasMore.value || _conversationId == null) return;
    _limit += pageSize;
    _watchMessages();
  }

  void _onInputChanged() => canSend.value = inputController.text.trim().isNotEmpty;

  void openContact() {
    final id = peerId;
    if (id != null) Get.toNamed<void>(Routes.contact, arguments: id);
  }

  Future<void> connect() async {
    final peer = conversation.value?.peer;
    if (peer == null || isConnected || isConnecting) return;
    final ok = await _bluetooth.connectToKnownPeer(peer.id);
    if (!ok && !isClosed) {
      showToast(
        'Could not connect',
        "${peer.displayName} wasn't found nearby. Make sure U Chat is open on their phone "
            'with Bluetooth on.',
      );
    }
  }

  Future<void> disconnect() async {
    final id = peerId;
    if (id != null) await _bluetooth.disconnectPeer(id);
  }

  Future<void> unblock() async {
    final id = peerId;
    if (id != null) await _conversations.setBlocked(id, false);
  }

  Future<void> send() async {
    final item = conversation.value;
    final text = inputController.text;
    if (item == null || text.trim().isEmpty || isSending.value || isBlocked) return;

    isSending.value = true;
    try {
      await _messaging.sendText(item, text);
      inputController.clear();
    } on ArgumentError catch (e) {
      showToast('Cannot send', '${e.message}');
    } catch (_) {
      showToast('Cannot send', 'The message could not be saved.');
    } finally {
      isSending.value = false;
    }
  }

  Future<void> retry(Message message) => _messaging.retry(message);

  Future<void> copy(Message message) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    showToast('Copied', 'Message copied to clipboard', duration: const Duration(seconds: 1));
  }

  bool get hasValidConversation => _conversationId != null;

  // ------------------------------------------------------- voice: recording

  /// Anything shorter is almost certainly a tap, not a message.
  static const _minRecordingMs = 600;

  bool _micGranted = false;
  bool _fingerDown = false;
  Future<void>? _recorderStarting;
  Timer? _recordingTicker;
  StreamSubscription<double>? _levelsSub;

  /// Starts recording. With [locked] it keeps going without a finger on the
  /// button, which is how screen-reader users record.
  Future<void> startRecording({bool locked = false}) async {
    final recorder = _recorder;
    if (recorder == null || recordingMode.value != RecordingMode.idle) return;
    _fingerDown = !locked;
    if (!_micGranted) {
      _micGranted = await recorder.ensurePermission();
      if (!_micGranted) {
        _fingerDown = false;
        showToast('Microphone needed', 'Allow the microphone to send voice messages.');
        return;
      }
      // The finger lifted while we were asking: it was a tap, not a hold.
      if (!_fingerDown && !locked) {
        _showHoldHint();
        return;
      }
    }
    await _player?.stop();
    HapticFeedback.mediumImpact();
    recordingDrag.value = (cancel: 0.0, lock: 0.0);
    recordingMs.value = 0;
    liveLevels.clear();
    recordingMode.value = locked ? RecordingMode.locked : RecordingMode.holding;

    _levelsSub = recorder.levels.listen(liveLevels.add);
    _recorderStarting = recorder.start().catchError((Object e) {
      debugPrint('Starting recording failed: $e');
      _endRecordingState();
      showToast('Cannot record', 'The microphone is not available right now.');
    });
    _recordingTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      recordingMs.value += 100;
      if (recordingMs.value >= VoiceMeta.maxRecordingMs) finishRecording();
    });
  }

  /// The finger slid far enough up: recording carries on without it.
  void lockRecording() {
    if (recordingMode.value != RecordingMode.holding) return;
    _fingerDown = false;
    HapticFeedback.lightImpact();
    recordingMode.value = RecordingMode.locked;
  }

  /// Stops recording and sends the note.
  Future<void> finishRecording() async {
    _fingerDown = false;
    if (recordingMode.value == RecordingMode.idle) return;
    final elapsed = recordingMs.value;
    _endRecordingState();
    await _recorderStarting;
    final recording = await _recorder!.stop();
    final item = conversation.value;
    if (recording == null || item == null) return;
    if (elapsed < _minRecordingMs) {
      _showHoldHint();
      await _deleteTemp(recording.path);
      return;
    }
    HapticFeedback.lightImpact();
    try {
      await _messaging.sendVoice(item, recording);
    } catch (e) {
      debugPrint('Sending voice message failed: $e');
      showToast('Cannot send', 'The voice message could not be saved.');
    }
  }

  void _showHoldHint() =>
      showToast('Hold to record', 'Keep the mic button pressed while you speak.');

  /// Stops recording and throws it away.
  Future<void> cancelRecording() async {
    _fingerDown = false;
    if (recordingMode.value == RecordingMode.idle) return;
    _endRecordingState();
    HapticFeedback.lightImpact();
    await _recorderStarting;
    await _recorder!.cancel();
  }

  void _endRecordingState() {
    _recordingTicker?.cancel();
    _levelsSub?.cancel();
    recordingMode.value = RecordingMode.idle;
    recordingDrag.value = (cancel: 0.0, lock: 0.0);
  }

  Future<void> _deleteTemp(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException catch (e) {
      debugPrint('Removing recording failed: $e');
    }
  }

  // -------------------------------------------------------- voice: playback

  // Reactive getters: read inside Obx.
  String? get currentVoiceId => _player?.currentId.value;
  bool get isVoicePlaying => _player?.isPlaying.value ?? false;
  Duration get voicePosition => _player?.position.value ?? Duration.zero;
  double get voiceSpeed => _player?.speed.value ?? 1;

  /// Reactive: 0 to 1 while [id] is moving between phones, otherwise null.
  double? voiceProgress(String id) => _transfer?.progress[id];

  /// Reactive: the audio of [id] couldn't be fetched.
  bool voiceFailed(String id) => _transfer?.failed.contains(id) ?? false;

  /// Where the audio is, or null if it hasn't fully arrived.
  String? voicePath(Message message) {
    final store = _store;
    if (store == null || !store.hasAudio(message.conversationId, message.id)) return null;
    return store.audioFile(message.conversationId, message.id).path;
  }

  void toggleVoice(Message message) {
    final path = voicePath(message);
    if (path != null) _player?.toggle(message.id, path);
  }

  void seekVoice(Message message, VoiceMeta meta, double fraction) {
    if (currentVoiceId != message.id) return;
    _player?.seek(Duration(milliseconds: (meta.durationMs * fraction).round()));
  }

  void cycleVoiceSpeed() => _player?.cycleSpeed();

  void retryVoiceDownload(Message message) => _transfer?.retry(message);

  @override
  void onClose() {
    if (_messaging.activeConversationId == _conversationId) {
      _messaging.activeConversationId = null;
    }
    _conversationSub?.cancel();
    _messagesSub?.cancel();
    inputController.dispose();
    if (recordingMode.value != RecordingMode.idle) cancelRecording();
    _player?.stop();
    _recorder?.dispose();
    super.onClose();
  }
}
