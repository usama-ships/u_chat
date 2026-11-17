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

/// Why connecting can't start right now, in words for the user. Null when ready.
String? connectBlocker(BleAvailability availability) => switch (availability) {
  BleAvailability.ready => null,
  BleAvailability.poweredOff => 'Bluetooth is off. Turn it on from the quick settings panel.',
  BleAvailability.unauthorized =>
    'Blue Chat needs the Nearby devices permission. Open Nearby to allow it.',
  BleAvailability.unsupported => 'This phone has no Bluetooth Low Energy.',
  BleAvailability.unknown => 'Bluetooth is still starting. Try again in a moment.',
};
