import 'dart:convert';
import 'dart:typed_data';

import 'ble_constants.dart';

/// Data a U Chat device puts in its BLE advertisement.
///
/// Layout (manufacturer data, ≤ 24 bytes):
/// ```
/// [0..1]  magic "UC"
/// [2]     version (1)
/// [3..10] first 8 chars of the device ID (ASCII base32)
/// [11..]  display name, UTF-8, truncated to 13 bytes on a character boundary
/// ```
/// This is unauthenticated, public data used only to list nearby devices.
/// Identity is established after connecting (Phase 3+).
class AdvertisementPayload {
  const AdvertisementPayload({required this.deviceIdPrefix, required this.displayName});

  final String deviceIdPrefix;
  final String displayName;

  static final _idPattern = RegExp(r'^[a-z2-7]+$');

  Uint8List encode() {
    if (deviceIdPrefix.length != BleConstants.advertisedIdLength ||
        !_idPattern.hasMatch(deviceIdPrefix)) {
      throw ArgumentError.value(deviceIdPrefix, 'deviceIdPrefix');
    }
    return Uint8List.fromList([
      ...BleConstants.magic,
      BleConstants.advertisementVersion,
      ...ascii.encode(deviceIdPrefix),
      ...truncateUtf8(displayName, BleConstants.maxAdvertisedNameBytes),
    ]);
  }

  /// Returns null for anything that isn't a valid U Chat advertisement.
  static AdvertisementPayload? tryDecode(List<int> data) {
    const headerLength = 3 + BleConstants.advertisedIdLength;
    if (data.length < headerLength || data.length > BleConstants.maxAdvertisementPayload) {
      return null;
    }
    if (data[0] != BleConstants.magic[0] || data[1] != BleConstants.magic[1]) return null;
    if (data[2] != BleConstants.advertisementVersion) return null;
    try {
      final prefix = ascii.decode(data.sublist(3, headerLength));
      if (!_idPattern.hasMatch(prefix)) return null;
      final name = utf8.decode(data.sublist(headerLength)).trim();
      return AdvertisementPayload(deviceIdPrefix: prefix, displayName: name);
    } on FormatException {
      return null;
    }
  }

  /// UTF-8 encodes [text], keeping at most [maxBytes] bytes without
  /// splitting a character.
  static List<int> truncateUtf8(String text, int maxBytes) {
    final out = <int>[];
    for (final rune in text.runes) {
      final bytes = utf8.encode(String.fromCharCode(rune));
      if (out.length + bytes.length > maxBytes) break;
      out.addAll(bytes);
    }
    return out;
  }
}
