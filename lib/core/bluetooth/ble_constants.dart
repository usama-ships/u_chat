import 'package:bluetooth_low_energy/bluetooth_low_energy.dart' show UUID;

/// Fixed identifiers of the U Chat Bluetooth protocol.
abstract final class BleConstants {
  // ---- GATT ----

  /// The U Chat GATT service.
  static final serviceUuid = UUID.fromString('b7e3c1a0-4f2d-4c8e-9a51-3d6f8e2b1c70');

  /// Central → peripheral packets (write with response).
  static final rxUuid = UUID.fromString('b7e3c1a1-4f2d-4c8e-9a51-3d6f8e2b1c70');

  /// Peripheral → central packets (notify).
  static final txUuid = UUID.fromString('b7e3c1a2-4f2d-4c8e-9a51-3d6f8e2b1c70');

  /// Requested ATT MTU (Android maximum). Payload per packet = MTU - 3.
  static const requestedMtu = 517;

  /// Maximum simultaneous peer connections.
  static const maxConnections = 4;

  // ---- Timeouts ----
  static const connectTimeout = Duration(seconds: 15);
  static const gattOperationTimeout = Duration(seconds: 10);
  static const packetWriteTimeout = Duration(seconds: 5);
  static const handshakeTimeout = Duration(seconds: 10);
  static const pingInterval = Duration(seconds: 10);

  /// A link with no incoming traffic for this long is considered dead.
  static const linkSilenceTimeout = Duration(seconds: 35);

  /// How long automatic reconnection keeps trying after a link drops.
  static const reconnectWindow = Duration(minutes: 2);

  /// How long the "Connect" button in a chat looks for the peer.
  static const manualConnectTimeout = Duration(seconds: 25);

  // ---- Advertising ----
  /// Manufacturer ID used in advertisements. 0xFFFF is the Bluetooth SIG ID
  /// reserved for testing / unregistered use. A published app should register
  /// its own company ID with the Bluetooth SIG and use it here.
  static const manufacturerId = 0xFFFF;

  /// "UC" — first two payload bytes, so we ignore other 0xFFFF advertisers.
  static const magic = [0x55, 0x43];

  /// Advertisement payload format version.
  static const advertisementVersion = 1;

  /// Number of device-ID characters included in the advertisement.
  static const advertisedIdLength = 8;

  /// Legacy advertising packets are 31 bytes. Android adds 3 bytes of flags
  /// and manufacturer data costs 4 bytes of header, leaving 24 bytes payload.
  static const maxAdvertisementPayload = 24;

  /// Remaining bytes for the (truncated) display name.
  static const maxAdvertisedNameBytes =
      maxAdvertisementPayload - 3 - advertisedIdLength; // 13

  /// A discovered device disappears from the list when not seen for this long.
  static const discoveryStaleAfter = Duration(seconds: 12);

  /// Scans stop automatically after this long to save battery.
  static const scanTimeout = Duration(minutes: 2);
}
