import 'package:bluetooth_low_energy/bluetooth_low_energy.dart' show Peripheral;

/// A nearby phone running U Chat, seen in a scan.
class DiscoveredDevice {
  const DiscoveredDevice({
    required this.deviceIdPrefix,
    required this.displayName,
    required this.rssi,
    required this.lastSeen,
    required this.peripheral,
  });

  /// First 8 characters of the device ID. Stable across Android's rotating
  /// Bluetooth addresses, so it's the key for this device in the list.
  final String deviceIdPrefix;

  /// Possibly truncated (13 bytes); the full name arrives after connecting.
  final String displayName;

  /// Signal strength in dBm (higher = closer).
  final int rssi;

  final DateTime lastSeen;

  /// Platform handle used to connect (Phase 3).
  final Peripheral peripheral;

  /// 0–3 bars for display.
  int get signalBars {
    if (rssi >= -60) return 3;
    if (rssi >= -75) return 2;
    if (rssi >= -90) return 1;
    return 0;
  }
}
