import 'dart:async';

import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/widgets/overlays.dart';
import '../../../core/bluetooth/bluetooth_service.dart';
import '../../../core/bluetooth/models/ble_availability.dart';
import '../../../core/bluetooth/models/discovered_device.dart';
import '../../../core/bluetooth/models/peer_info.dart';
import '../../../data/models/conversation_with_peer.dart';
import '../../../data/repositories/conversation_repository.dart';

enum DeviceLinkState { available, connecting, connected }

/// Nearby screen: scans while open, connects to a chosen device and opens
/// the chat. All Bluetooth work is done by [BluetoothService].
class NearbyController extends GetxController {
  NearbyController(this.bluetooth, this._conversations);

  final BluetoothService bluetooth;
  final ConversationRepository _conversations;

  final _knownPeerIds = <String>{}.obs;
  StreamSubscription<List<ConversationWithPeer>>? _knownSub;

  BleAvailability get availability => bluetooth.availability.value;
  List<DiscoveredDevice> get devices => bluetooth.discovered;

  @override
  void onInit() {
    super.onInit();
    _knownSub = _conversations.watchConversations().listen(
          (items) => _knownPeerIds.assignAll(items.map((c) => c.peer.id)),
        );
  }

  @override
  void onReady() {
    super.onReady();
    _start();
  }

  Future<void> _start() async {
    if (bluetooth.availability.value == BleAvailability.unauthorized &&
        !bluetooth.permissionDenied.value) {
      await bluetooth.requestPermissions();
    }
    await bluetooth.ensureVisible();
    await bluetooth.startScan();
  }

  Future<void> grantPermission() async {
    if (bluetooth.permissionDenied.value) {
      await bluetooth.openAppSettings();
    } else {
      await bluetooth.requestPermissions();
    }
  }

  Future<void> rescan() => bluetooth.startScan();

  bool isKnown(DiscoveredDevice device) =>
      _knownPeerIds.any((id) => id.startsWith(device.deviceIdPrefix));

  /// Reactive: call inside Obx.
  DeviceLinkState linkStateOf(DiscoveredDevice device) {
    if (_connectedPeer(device) != null) return DeviceLinkState.connected;
    if (bluetooth.connectingPrefixes.contains(device.deviceIdPrefix)) {
      return DeviceLinkState.connecting;
    }
    return DeviceLinkState.available;
  }

  PeerInfo? _connectedPeer(DiscoveredDevice device) {
    for (final peer in bluetooth.connectedPeers.values) {
      if (peer.id.startsWith(device.deviceIdPrefix)) return peer;
    }
    return null;
  }

  /// Connects (if needed) and opens the chat with the device.
  Future<void> connectAndOpenChat(DiscoveredDevice device) async {
    try {
      final peer = _connectedPeer(device) ?? await bluetooth.connect(device);
      final conversation = await _conversations.openConversationWithPeer(peer);
      Get.toNamed<void>(Routes.chat, arguments: conversation.id);
    } on BleConnectException catch (e) {
      showToast('Could not connect to ${device.displayName}', e.message);
    } catch (e) {
      showToast('Could not connect to ${device.displayName}', '$e');
    }
  }

  @override
  void onClose() {
    _knownSub?.cancel();
    bluetooth.stopScan();
    super.onClose();
  }
}
