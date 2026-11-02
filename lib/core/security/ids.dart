import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Derives the public device ID from an Ed25519 identity public key.
///
/// The ID is the first 128 bits of SHA-256(publicKey), base32-encoded
/// (26 lowercase chars). Because it is derived from the key, a peer cannot
/// claim another device's ID without holding that device's private key.
String deviceIdFromPublicKey(List<int> publicKey) {
  if (publicKey.length != 32) {
    throw ArgumentError.value(publicKey.length, 'publicKey', 'Ed25519 public keys are 32 bytes');
  }
  return base32Encode(sha256.convert(publicKey).bytes.sublist(0, 16));
}

/// Deterministic 1:1 conversation ID. Both devices compute the same value
/// regardless of who initiated, so their conversation rows line up.
String conversationIdFor(String deviceIdA, String deviceIdB) {
  final ids = [deviceIdA, deviceIdB]..sort();
  final digest = sha256.convert(utf8.encode(ids.join(':')));
  return base32Encode(digest.bytes.sublist(0, 16));
}

const _base32Alphabet = 'abcdefghijklmnopqrstuvwxyz234567';

/// RFC 4648 base32, lowercase, without padding.
String base32Encode(List<int> bytes) {
  final out = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final byte in bytes) {
    buffer = (buffer << 8) | (byte & 0xff);
    bits += 8;
    while (bits >= 5) {
      out.write(_base32Alphabet[(buffer >> (bits - 5)) & 31]);
      bits -= 5;
    }
    buffer &= (1 << bits) - 1;
  }
  if (bits > 0) {
    out.write(_base32Alphabet[(buffer << (5 - bits)) & 31]);
  }
  return out.toString();
}
