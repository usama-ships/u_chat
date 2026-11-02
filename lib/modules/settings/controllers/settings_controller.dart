import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/bluetooth/bluetooth_service.dart';
import '../../../core/security/identity_service.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../data/repositories/settings_repository.dart';

class SettingsController extends GetxController {
  SettingsController(this._identity, this._settings, this._conversations, this.bluetooth);

  final BluetoothService bluetooth;
  final IdentityService _identity;
  final SettingsRepository _settings;
  final ConversationRepository _conversations;

  final displayName = ''.obs;
  final acceptUnknownDevices = true.obs;
  StreamSubscription<String>? _subscription;
  StreamSubscription<bool>? _acceptSub;

  String get deviceId => _identity.deviceId;

  @override
  void onInit() {
    super.onInit();
    _subscription = _settings.watchDisplayName().listen(displayName.call);
    _acceptSub = _settings.watchAcceptUnknownDevices().listen(acceptUnknownDevices.call);
  }

  Future<void> setAcceptUnknownDevices(bool accept) => _settings.setAcceptUnknownDevices(accept);

  /// Returns a validation error, or null on success.
  Future<String?> updateDisplayName(String name) async {
    final error = SettingsRepository.validateDisplayName(name);
    if (error != null) return error;
    try {
      await _settings.setDisplayName(name);
      return null;
    } catch (_) {
      return 'Could not save the name';
    }
  }

  Future<void> fixBluetoothPermission() async {
    if (bluetooth.permissionDenied.value) {
      await bluetooth.openAppSettings();
    } else {
      await bluetooth.requestPermissions();
    }
  }

  Future<void> copyDeviceId() async {
    await Clipboard.setData(ClipboardData(text: deviceId));
    Get.snackbar('Copied', 'Device ID copied to clipboard', snackPosition: SnackPosition.BOTTOM);
  }

  /// Debug builds only: creates a local conversation with a fake peer so the
  /// chat UI and persistence can be exercised before Bluetooth exists.
  /// Messages sent there remain `pending` because the peer doesn't exist.
  Future<void> createDebugConversation() async {
    await _conversations.openConversationWith(
      peerId: 'debugpeer00000000000000000',
      peerDisplayName: 'Test Device (debug)',
      platform: 'debug',
    );
    Get.snackbar('Created', 'Debug conversation added to the home screen',
        snackPosition: SnackPosition.BOTTOM);
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _acceptSub?.cancel();
    super.onClose();
  }
}
