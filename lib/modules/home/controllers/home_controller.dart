import 'dart:async';

import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/bluetooth/bluetooth_service.dart';
import '../../../core/bluetooth/models/ble_availability.dart';
import '../../../data/models/conversation_with_peer.dart';
import '../../../data/repositories/conversation_repository.dart';

class HomeController extends GetxController {
  HomeController(this._conversations, this._bluetooth);

  final ConversationRepository _conversations;
  final BluetoothService _bluetooth;

  /// Reactive: call inside Obx.
  bool isConnected(String peerId) => _bluetooth.connectedPeers.containsKey(peerId);

  /// Reactive: call inside Obx. Short status for the home header.
  String get presenceLabel {
    final connected = _bluetooth.connectedPeers.length;
    if (connected > 0) return '$connected connected';
    return switch (_bluetooth.availability.value) {
      BleAvailability.unknown => 'Starting up',
      BleAvailability.unsupported => 'Bluetooth not supported',
      BleAvailability.unauthorized => 'Permission needed',
      BleAvailability.poweredOff => 'Bluetooth off',
      BleAvailability.ready => _bluetooth.isAdvertising.value ? 'Visible nearby' : 'Not visible',
    };
  }

  /// Reactive: call inside Obx. True when other phones can reach this one.
  bool get isPresent => _bluetooth.connectedPeers.isNotEmpty || _bluetooth.isAdvertising.value;

  final conversations = <ConversationWithPeer>[].obs;
  final isLoading = true.obs;
  final errorMessage = RxnString();

  StreamSubscription<List<ConversationWithPeer>>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _subscription = _conversations.watchConversations().listen(
      (items) {
        conversations.assignAll(items);
        errorMessage.value = null;
        isLoading.value = false;
      },
      onError: (Object error) {
        errorMessage.value = 'Could not load conversations';
        isLoading.value = false;
      },
    );
  }

  void openConversation(ConversationWithPeer item) =>
      Get.toNamed<void>(Routes.chat, arguments: item.conversation.id);

  void openSettings() => Get.toNamed<void>(Routes.settings);

  void openNearby() => Get.toNamed<void>(Routes.nearby);

  Future<void> deleteConversation(ConversationWithPeer item) =>
      _conversations.deleteConversation(item.conversation.id);

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
