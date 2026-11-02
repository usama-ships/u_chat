import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

import 'ids.dart';

/// Owns this device's long-term identity: an Ed25519 key pair.
///
/// The 32-byte private seed is stored in the Android Keystore-backed secure
/// storage, never in SQLite. The public [deviceId] is derived from the public
/// key (see [deviceIdFromPublicKey]). The key pair signs the session handshake
/// in Phase 6, which is what authenticates a device to its peers.
class IdentityService extends GetxService {
  IdentityService(this._storage);

  static const _seedStorageKey = 'u_chat.identity.ed25519_seed.v1';

  final FlutterSecureStorage _storage;
  final Ed25519 _ed25519 = Ed25519();

  late final SimpleKeyPair _keyPair;
  late final SimplePublicKey publicKey;
  late final String deviceId;

  /// Loads the existing identity or creates one on first launch.
  Future<IdentityService> init() async {
    final storedSeed = await _storage.read(key: _seedStorageKey);
    if (storedSeed == null) {
      _keyPair = await _ed25519.newKeyPair();
      final seed = await _keyPair.extractPrivateKeyBytes();
      await _storage.write(key: _seedStorageKey, value: base64Encode(seed));
    } else {
      _keyPair = await _ed25519.newKeyPairFromSeed(base64Decode(storedSeed));
    }
    publicKey = await _keyPair.extractPublicKey();
    deviceId = deviceIdFromPublicKey(publicKey.bytes);
    return this;
  }

  /// Signs [message] with the identity key.
  Future<Signature> sign(List<int> message) => _ed25519.sign(message, keyPair: _keyPair);
}
