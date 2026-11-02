import 'dart:async';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/foundation.dart';

import 'advertisement_codec.dart';
import 'ble_constants.dart';
import 'models/discovered_device.dart';

/// Scans for nearby U Chat devices and keeps a de-duplicated, self-expiring
/// list of them.
///
/// The scan has no OS-level filter, because our advertisement carries no
/// service UUID (it doesn't fit next to the name). Results are filtered in Dart
/// by manufacturer ID and the "UC" magic bytes instead. Scanning only runs
/// while needed (Nearby screen open), and stops after [BleConstants.scanTimeout].
class BleScanner {
  BleScanner(this._manager, {required this.ownDeviceIdPrefix});

  final CentralManager _manager;
  final String ownDeviceIdPrefix;

  final _devices = <String, DiscoveredDevice>{};
  final _changes = StreamController<List<DiscoveredDevice>>.broadcast();

  StreamSubscription<DiscoveredEventArgs>? _discoveredSub;
  Timer? _pruneTimer;
  Timer? _timeoutTimer;
  Timer? _emitTimer;
  bool _scanning = false;

  bool get isScanning => _scanning;

  /// Emits the current device list (sorted by signal) whenever it changes,
  /// at most about once per second.
  Stream<List<DiscoveredDevice>> get devices => _changes.stream;

  List<DiscoveredDevice> get currentDevices => _sorted();

  /// Starts scanning. [onTimeout] is called if the scan stops by itself.
  Future<void> start({VoidCallback? onTimeout}) async {
    if (_scanning) return;
    _discoveredSub ??= _manager.discovered.listen(_onDiscovered);
    await _manager.startDiscovery();
    _scanning = true;
    _pruneTimer = Timer.periodic(const Duration(seconds: 2), (_) => _prune());
    _timeoutTimer = Timer(BleConstants.scanTimeout, () async {
      await stop();
      onTimeout?.call();
    });
  }

  Future<void> stop() async {
    _timeoutTimer?.cancel();
    _pruneTimer?.cancel();
    if (!_scanning) return;
    _scanning = false;
    try {
      await _manager.stopDiscovery();
    } catch (e) {
      debugPrint('BleScanner.stop failed: $e');
    }
  }

  /// Bluetooth went off / permission lost: OS already stopped the scan.
  void markStopped() {
    _timeoutTimer?.cancel();
    _pruneTimer?.cancel();
    _scanning = false;
  }

  void clear() {
    _devices.clear();
    _emitNow();
  }

  void _onDiscovered(DiscoveredEventArgs event) {
    AdvertisementPayload? payload;
    for (final data in event.advertisement.manufacturerSpecificData) {
      if (data.id == BleConstants.manufacturerId) {
        payload = AdvertisementPayload.tryDecode(data.data);
        if (payload != null) break;
      }
    }
    if (payload == null || payload.deviceIdPrefix == ownDeviceIdPrefix) return;

    final isNew = !_devices.containsKey(payload.deviceIdPrefix);
    _devices[payload.deviceIdPrefix] = DiscoveredDevice(
      deviceIdPrefix: payload.deviceIdPrefix,
      displayName: payload.displayName.isEmpty ? 'Unknown' : payload.displayName,
      rssi: event.rssi,
      lastSeen: DateTime.now(),
      peripheral: event.peripheral,
    );
    // New devices show up immediately; RSSI updates are batched.
    if (isNew) {
      _emitNow();
    } else {
      _emitTimer ??= Timer(const Duration(seconds: 1), _emitNow);
    }
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(BleConstants.discoveryStaleAfter);
    final before = _devices.length;
    _devices.removeWhere((_, d) => d.lastSeen.isBefore(cutoff));
    if (_devices.length != before) _emitNow();
  }

  void _emitNow() {
    _emitTimer?.cancel();
    _emitTimer = null;
    if (!_changes.isClosed) _changes.add(_sorted());
  }

  List<DiscoveredDevice> _sorted() =>
      _devices.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));

  Future<void> dispose() async {
    await stop();
    _emitTimer?.cancel();
    await _discoveredSub?.cancel();
    await _changes.close();
  }
}
