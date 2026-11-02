import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:u_chat/core/bluetooth/advertisement_codec.dart';
import 'package:u_chat/core/bluetooth/ble_constants.dart';

void main() {
  const prefix = 'abcd2345';

  test('round-trips id prefix and short name', () {
    final bytes = const AdvertisementPayload(deviceIdPrefix: prefix, displayName: 'Alice').encode();
    final decoded = AdvertisementPayload.tryDecode(bytes)!;
    expect(decoded.deviceIdPrefix, prefix);
    expect(decoded.displayName, 'Alice');
  });

  test('payload never exceeds the advertising budget', () {
    final bytes = AdvertisementPayload(deviceIdPrefix: prefix, displayName: 'x' * 100).encode();
    expect(bytes.length, BleConstants.maxAdvertisementPayload);
    expect(AdvertisementPayload.tryDecode(bytes)!.displayName, 'x' * 13);
  });

  test('truncation never splits a multi-byte character', () {
    // Each emoji is 4 bytes in UTF-8; 13 bytes fit 3 of them.
    final bytes = const AdvertisementPayload(deviceIdPrefix: prefix, displayName: '😀😀😀😀').encode();
    expect(AdvertisementPayload.tryDecode(bytes)!.displayName, '😀😀😀');
    expect(AdvertisementPayload.truncateUtf8('héllo', 2), utf8.encode('h'));
  });

  test('rejects foreign or malformed data', () {
    final valid = const AdvertisementPayload(deviceIdPrefix: prefix, displayName: 'A').encode();
    expect(AdvertisementPayload.tryDecode([1, 2, 3]), isNull);
    expect(AdvertisementPayload.tryDecode([0x00, ...valid.sublist(1)]), isNull); // bad magic
    expect(AdvertisementPayload.tryDecode([...valid.sublist(0, 2), 9, ...valid.sublist(3)]), isNull); // version
    expect(AdvertisementPayload.tryDecode([...valid.sublist(0, 3), ...ascii.encode('ABCD!!!!'), 65]), isNull);
    expect(AdvertisementPayload.tryDecode([...valid, 0xff]), isNull); // invalid UTF-8
    expect(AdvertisementPayload.tryDecode(List.filled(30, 0x55)), isNull); // too long
  });

  test('encode rejects bad prefixes', () {
    expect(() => const AdvertisementPayload(deviceIdPrefix: 'short', displayName: 'A').encode(),
        throwsArgumentError);
    expect(() => const AdvertisementPayload(deviceIdPrefix: 'ABCDEFGH', displayName: 'A').encode(),
        throwsArgumentError);
  });
}
