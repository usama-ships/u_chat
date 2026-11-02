import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/bluetooth/bluetooth_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/messaging/messaging_service.dart';
import '../../../data/models/conversation_with_peer.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/message_repository.dart';

class ChatController extends GetxController {
  ChatController(this._conversations, this._messages, this._bluetooth, this._messaging);

  static const pageSize = 100;

  final ConversationRepository _conversations;
  final MessageRepository _messages;
  final BluetoothService _bluetooth;
  final MessagingService _messaging;

  final inputController = TextEditingController();

  final conversation = Rxn<ConversationWithPeer>();
  final messages = <Message>[].obs;
  final isLoaded = false.obs;
  final canSend = false.obs;
  final isSending = false.obs;

  /// True when older messages exist beyond the loaded page(s).
  final hasMore = false.obs;

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
      Get.snackbar(
        'Could not connect',
        "${peer.displayName} wasn't found nearby. Make sure U Chat is open on their phone "
            'with Bluetooth on.',
        snackPosition: SnackPosition.BOTTOM,
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
      Get.snackbar('Cannot send', '${e.message}', snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('Cannot send', 'The message could not be saved.',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSending.value = false;
    }
  }

  Future<void> retry(Message message) => _messaging.retry(message);

  Future<void> copy(Message message) async {
    await Clipboard.setData(ClipboardData(text: message.content));
    Get.snackbar('Copied', 'Message copied to clipboard',
        snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 1));
  }

  bool get hasValidConversation => _conversationId != null;

  @override
  void onClose() {
    if (_messaging.activeConversationId == _conversationId) {
      _messaging.activeConversationId = null;
    }
    _conversationSub?.cancel();
    _messagesSub?.cancel();
    inputController.dispose();
    super.onClose();
  }
}
