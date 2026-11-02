/// Whether Bluetooth can be used right now, as far as the app is concerned.
enum BleAvailability {
  /// The plugin hasn't reported a state yet.
  unknown,

  /// The phone has no Bluetooth Low Energy.
  unsupported,

  /// The "Nearby devices" permission (Android 12+) or location permission
  /// (Android 11 and below) hasn't been granted.
  unauthorized,

  /// Bluetooth is switched off.
  poweredOff,

  /// Ready to scan (and to advertise, if the phone supports it).
  ready,
}
