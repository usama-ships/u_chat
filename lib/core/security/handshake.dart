import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';

/// What a session needs to know about this device to run the handshake.
class LocalIdentity {
  const LocalIdentity({
    required this.deviceId,
    required this.publicKey,
    required this.displayName,
    required this.sign,
  });

  final String deviceId;
  final List<int> publicKey;
  final String displayName;

  /// Ed25519 signature with the long-term identity key.
  final Future<List<int>> Function(List<int> message) sign;
}

/// Per-connection X25519 key pair and nonce, sent in HELLO.
class EphemeralKeys {
  EphemeralKeys._(this.keyPair, this.publicKey, this.nonce);

  final SimpleKeyPair keyPair;
  final Uint8List publicKey;
  final Uint8List nonce;

  static final _random = Random.secure();

  static Future<EphemeralKeys> generate() async {
    final keyPair = await X25519().newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final nonce = Uint8List.fromList(List.generate(16, (_) => _random.nextInt(256)));
    return EphemeralKeys._(keyPair, Uint8List.fromList(publicKey.bytes), nonce);
  }
}

class HandshakeException implements Exception {
  HandshakeException(this.message);
  final String message;
  @override
  String toString() => 'HandshakeException: $message';
}

/// Authenticated key agreement, following the standard "signed ephemeral
/// Diffie-Hellman over the transcript" pattern (SIGMA / TLS 1.3 style), built
/// only from library primitives (X25519, Ed25519, HKDF-SHA256, AES-256-GCM):
///
/// 1. Both sides send HELLO: identity public key, fresh X25519 key, nonce.
/// 2. Transcript T = SHA-256(label ‖ SHA-256(HELLO_low) ‖ SHA-256(HELLO_high)),
///    ordered by device ID so both sides compute the same T.
/// 3. Each side sends AUTH = Ed25519_sign(identityKey, label ‖ "auth" ‖ ownId ‖ T).
///    This proves possession of the identity key and binds both ephemeral keys,
///    so a man-in-the-middle can't substitute its own keys.
/// 4. Session keys = HKDF(X25519(eph_mine, eph_peer), salt = T) → one AES-256
///    key per direction. Fresh ephemerals give forward secrecy per connection.
abstract final class Handshake {
  static const label = 'uchat-v2';

  static Uint8List transcript({
    required String idA,
    required List<int> helloA,
    required String idB,
    required List<int> helloB,
  }) {
    final aFirst = idA.compareTo(idB) < 0;
    final first = aFirst ? helloA : helloB;
    final second = aFirst ? helloB : helloA;
    return Uint8List.fromList(hash.sha256.convert([
      ...utf8.encode(label),
      ...hash.sha256.convert(first).bytes,
      ...hash.sha256.convert(second).bytes,
    ]).bytes);
  }

  static Uint8List authMessage(String signerId, List<int> transcript) =>
      Uint8List.fromList([...utf8.encode('$label|auth|$signerId|'), ...transcript]);

  static Future<bool> verifyAuth({
    required List<int> peerPublicKey,
    required String peerId,
    required List<int> transcript,
    required List<int> signature,
  }) async {
    if (signature.length != 64) return false;
    return Ed25519().verify(
      authMessage(peerId, transcript),
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(peerPublicKey, type: KeyPairType.ed25519),
      ),
    );
  }

  static Future<SessionCipher> deriveCipher({
    required SimpleKeyPair myEphemeral,
    required List<int> peerEphemeral,
    required List<int> transcript,
    required bool iAmLow,
  }) async {
    final shared = await X25519().sharedSecretKey(
      keyPair: myEphemeral,
      remotePublicKey: SimplePublicKey(peerEphemeral, type: KeyPairType.x25519),
    );
    final sharedBytes = await shared.extractBytes();
    if (sharedBytes.every((b) => b == 0)) {
      throw HandshakeException('invalid ephemeral key'); // low-order point
    }
    final okm = await Hkdf(hmac: Hmac.sha256(), outputLength: 64).deriveKey(
      secretKey: SecretKey(sharedBytes),
      nonce: transcript,
      info: utf8.encode('$label|session-keys'),
    );
    final bytes = await okm.extractBytes();
    final lowToHigh = bytes.sublist(0, 32);
    final highToLow = bytes.sublist(32, 64);
    return SessionCipher(
      sendKey: iAmLow ? lowToHigh : highToLow,
      receiveKey: iAmLow ? highToLow : lowToHigh,
    );
  }
}

class SealedFrameException implements Exception {
  SealedFrameException(this.message);
  final String message;
  @override
  String toString() => 'SealedFrameException: $message';
}

/// AES-256-GCM with a separate key per direction.
///
/// Wire format: `counter (8 bytes, big-endian) ‖ ciphertext ‖ tag (16 bytes)`.
/// Nonce = 4 zero bytes ‖ counter. The counter is also authenticated (AAD).
/// Counters must strictly increase, so replayed or reordered frames are
/// rejected — the link delivers in order, so legitimate frames always do.
class SessionCipher {
  SessionCipher({required List<int> sendKey, required List<int> receiveKey})
      : _sendKey = SecretKey(sendKey),
        _receiveKey = SecretKey(receiveKey);

  static const overhead = 8 + 16;

  final SecretKey _sendKey;
  final SecretKey _receiveKey;
  final _aes = AesGcm.with256bits();
  int _sendCounter = 0;
  int _lastReceived = -1;

  static Uint8List _counterBytes(int counter) =>
      (ByteData(8)..setInt64(0, counter)).buffer.asUint8List();

  static Uint8List _nonce(Uint8List counterBytes) =>
      Uint8List(12)..setRange(4, 12, counterBytes);

  /// Must be called in send order (the session serializes sends).
  Future<Uint8List> seal(Uint8List plaintext) async {
    final counterBytes = _counterBytes(_sendCounter++);
    final box = await _aes.encrypt(
      plaintext,
      secretKey: _sendKey,
      nonce: _nonce(counterBytes),
      aad: counterBytes,
    );
    return Uint8List.fromList([...counterBytes, ...box.cipherText, ...box.mac.bytes]);
  }

  /// Must be called in receive order. Throws [SealedFrameException].
  Future<Uint8List> open(Uint8List sealed) async {
    if (sealed.length < overhead) throw SealedFrameException('too short');
    final counterBytes = Uint8List.sublistView(sealed, 0, 8);
    final counter = ByteData.sublistView(counterBytes).getInt64(0);
    if (counter <= _lastReceived) throw SealedFrameException('replayed or out of order');
    final List<int> plaintext;
    try {
      plaintext = await _aes.decrypt(
        SecretBox(
          Uint8List.sublistView(sealed, 8, sealed.length - 16),
          nonce: _nonce(Uint8List.fromList(counterBytes)),
          mac: Mac(Uint8List.sublistView(sealed, sealed.length - 16)),
        ),
        secretKey: _receiveKey,
        aad: Uint8List.fromList(counterBytes),
      );
    } on SecretBoxAuthenticationError {
      throw SealedFrameException('authentication failed');
    }
    _lastReceived = counter;
    return Uint8List.fromList(plaintext);
  }
}
