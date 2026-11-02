import 'dart:convert';
import 'dart:typed_data';

import '../../../data/repositories/settings_repository.dart';
import '../../security/ids.dart';
import '../models/peer_info.dart';

/// A decoded, validated HELLO.
class HelloData {
  const HelloData({required this.peer, required this.ephemeralPublicKey, required this.nonce});
  final PeerInfo peer;
  final Uint8List ephemeralPublicKey;
  final Uint8List nonce;
}

class IncompatibleVersionException extends FormatException {
  const IncompatibleVersionException()
      : super('The other phone runs an incompatible version of U Chat. Update both phones.');
}

/// HELLO frame body.
///
/// ```json
/// {"v":2,"id":"<deviceId>","name":"Alice","pk":"<Ed25519, base64>",
///  "eph":"<X25519, base64>","nonce":"<16 bytes, base64>","platform":"android"}
/// ```
/// The receiver checks that `id` is derived from `pk`. Possession of the
/// matching private key is proven by the AUTH frame that follows.
abstract final class HelloCodec {
  static const protocolVersion = 2;
  static const maxBodyBytes = 512;

  static Uint8List encode({
    required String deviceId,
    required String displayName,
    required List<int> publicKey,
    required List<int> ephemeralPublicKey,
    required List<int> nonce,
    String platform = 'android',
  }) {
    return Uint8List.fromList(utf8.encode(jsonEncode({
      'v': protocolVersion,
      'id': deviceId,
      'name': displayName,
      'pk': base64Encode(publicKey),
      'eph': base64Encode(ephemeralPublicKey),
      'nonce': base64Encode(nonce),
      'platform': platform,
    })));
  }

  /// Validates and decodes a HELLO body. Throws [FormatException]
  /// ([IncompatibleVersionException] for other protocol versions).
  static HelloData decode(Uint8List body) {
    if (body.length > maxBodyBytes) throw const FormatException('hello too large');
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(body));
    } catch (_) {
      throw const FormatException('hello is not valid JSON');
    }
    if (json is! Map<String, Object?>) throw const FormatException('hello is not an object');
    if (json['v'] != protocolVersion) throw const IncompatibleVersionException();

    final id = json['id'];
    final name = json['name'];
    final platform = json['platform'];
    if (id is! String || name is! String) throw const FormatException('hello is missing fields');
    if (platform != null && (platform is! String || platform.length > 16)) {
      throw const FormatException('bad platform');
    }

    final publicKey = _bytes(json['pk'], 32, 'public key');
    final ephemeral = _bytes(json['eph'], 32, 'ephemeral key');
    final nonce = _bytes(json['nonce'], 16, 'nonce');
    if (deviceIdFromPublicKey(publicKey) != id) {
      throw const FormatException('device ID does not match public key');
    }
    if (SettingsRepository.validateDisplayName(name) != null) {
      throw const FormatException('bad display name');
    }

    return HelloData(
      peer: PeerInfo(
        id: id,
        displayName: name.trim(),
        publicKey: publicKey,
        platform: platform as String?,
      ),
      ephemeralPublicKey: ephemeral,
      nonce: nonce,
    );
  }

  static Uint8List _bytes(Object? value, int length, String what) {
    if (value is! String) throw FormatException('missing $what');
    final Uint8List bytes;
    try {
      bytes = base64Decode(value);
    } catch (_) {
      throw FormatException('bad $what encoding');
    }
    if (bytes.length != length) throw FormatException('bad $what length');
    return bytes;
  }
}

/// PROFILE frame body: `{"name":"New name"}`.
abstract final class ProfileCodec {
  static Uint8List encode(String displayName) =>
      Uint8List.fromList(utf8.encode(jsonEncode({'name': displayName})));

  /// Returns the validated, trimmed name. Throws [FormatException].
  static String decode(Uint8List body) {
    if (body.length > 256) throw const FormatException('profile too large');
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(body));
    } catch (_) {
      throw const FormatException('profile is not valid JSON');
    }
    final name = json is Map<String, Object?> ? json['name'] : null;
    if (name is! String || SettingsRepository.validateDisplayName(name) != null) {
      throw const FormatException('bad display name');
    }
    return name.trim();
  }
}
