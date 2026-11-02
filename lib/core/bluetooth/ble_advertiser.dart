import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';

import 'advertisement_codec.dart';
import 'ble_constants.dart';

/// Makes this phone discoverable by advertising U Chat manufacturer data.
///
/// We deliberately never pass `name` to `startAdvertising`: on Android the
/// plugin implements that by renaming the phone's system-wide Bluetooth name.
class BleAdvertiser {
  BleAdvertiser(this._manager);

  final PeripheralManager _manager;
  bool _advertising = false;
  AdvertisementPayload? _current;

  /// Android `AdvertiseCallback.ADVERTISE_FAILED_ALREADY_STARTED`.
  static const _errorAlreadyStarted = 3;

  bool get isAdvertising => _advertising;

  /// Starts (or restarts with new data) advertising. Throws on failure.
  Future<void> start(AdvertisementPayload payload) async {
    if (_advertising &&
        _current?.displayName == payload.displayName &&
        _current?.deviceIdPrefix == payload.deviceIdPrefix) {
      return;
    }
    // Always stop first, even if we believe nothing is running. Android keeps
    // the advertisement registered independently of our flag, and starting
    // again while it is registered fails with "already started" (code 3).
    await _stopNative();
    _advertising = false;
    _current = null;

    final advertisement = Advertisement(
      manufacturerSpecificData: [
        ManufacturerSpecificData(id: BleConstants.manufacturerId, data: payload.encode()),
      ],
    );
    try {
      await _manager.startAdvertising(advertisement);
    } catch (e) {
      if (errorCode(e) != _errorAlreadyStarted) rethrow;
      debugPrint('Advertising already registered; stopping and retrying once');
      await _stopNative();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _manager.startAdvertising(advertisement);
    }
    _advertising = true;
    _current = payload;
  }

  Future<void> stop() async {
    final wasAdvertising = _advertising;
    _advertising = false;
    _current = null;
    if (wasAdvertising) await _stopNative();
  }

  Future<void> _stopNative() async {
    try {
      await _manager.stopAdvertising();
    } catch (e) {
      debugPrint('stopAdvertising failed: $e');
    }
  }

  /// Bluetooth turned off or permission revoked: the OS already stopped it.
  void markStopped() {
    _advertising = false;
    _current = null;
  }

  /// Extracts Android's AdvertiseCallback error code from a plugin exception.
  static int? errorCode(Object error) {
    final match = RegExp(r'error code: (\d+)').firstMatch('$error');
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  /// Short, user-facing explanation of an advertising failure.
  static String describeError(Object error) => switch (errorCode(error)) {
        1 => 'Could not make this phone visible: advertising data too large.',
        2 => 'Could not make this phone visible: too many apps are advertising over '
            'Bluetooth. Close other Bluetooth apps or restart Bluetooth.',
        3 => 'Could not make this phone visible. Turn Bluetooth off and on, then reopen this screen.',
        4 => "Could not make this phone visible: Android's Bluetooth stack reported an "
            'internal error. Restarting Bluetooth usually fixes it.',
        5 => "This phone's Bluetooth doesn't support advertising. You can find others, "
            "but they can't find you.",
        _ => 'Could not make this phone visible. Turn Bluetooth off and on, then reopen this screen.',
      };
}
