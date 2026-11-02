import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:u_chat/core/bluetooth/transport/hello.dart';
import 'package:u_chat/core/security/handshake.dart';
import 'package:u_chat/core/security/ids.dart';
import 'package:u_chat/core/security/safety_number.dart';

Future<(SessionCipher, SessionCipher)> cipherPair() async {
  final a = await EphemeralKeys.generate();
  final b = await EphemeralKeys.generate();
  final t = Handshake.transcript(idA: 'aaa', helloA: [1], idB: 'bbb', helloB: [2]);
  final ca = await Handshake.deriveCipher(
      myEphemeral: a.keyPair, peerEphemeral: b.publicKey, transcript: t, iAmLow: true);
  final cb = await Handshake.deriveCipher(
      myEphemeral: b.keyPair, peerEphemeral: a.publicKey, transcript: t, iAmLow: false);
  return (ca, cb);
}

void main() {
  test('transcript is identical on both sides', () {
    final t1 = Handshake.transcript(idA: 'aaa', helloA: [1, 2], idB: 'bbb', helloB: [3, 4]);
    final t2 = Handshake.transcript(idA: 'bbb', helloA: [3, 4], idB: 'aaa', helloB: [1, 2]);
    expect(t1, t2);
    expect(Handshake.transcript(idA: 'aaa', helloA: [9], idB: 'bbb', helloB: [3, 4]), isNot(t1));
  });

  test('both sides derive matching directional keys', () async {
    final (a, b) = await cipherPair();
    final msg = Uint8List.fromList([1, 2, 3, 4]);
    expect(await b.open(await a.seal(msg)), msg);
    expect(await a.open(await b.seal(msg)), msg);
  });

  test('a frame cannot be decrypted with the sender\'s own receive key', () async {
    final (a, _) = await cipherPair();
    final sealed = await a.seal(Uint8List.fromList([1]));
    expect(() => a.open(sealed), throwsA(isA<SealedFrameException>()));
  });

  test('replays, reordering and tampering are rejected', () async {
    final (a, b) = await cipherPair();
    final first = await a.seal(Uint8List.fromList([1]));
    final second = await a.seal(Uint8List.fromList([2]));
    await b.open(second);
    expect(() => b.open(first), throwsA(isA<SealedFrameException>())); // older counter
    expect(() => b.open(second), throwsA(isA<SealedFrameException>())); // replay

    final third = await a.seal(Uint8List.fromList([3]));
    final tampered = Uint8List.fromList(third)..[9] ^= 0xff;
    expect(() => b.open(tampered), throwsA(isA<SealedFrameException>()));
    expect(() => b.open(Uint8List(5)), throwsA(isA<SealedFrameException>()));
  });

  test('auth signature verifies only for the right key, ID and transcript', () async {
    final kp = await Ed25519().newKeyPair();
    final pk = (await kp.extractPublicKey()).bytes;
    final id = deviceIdFromPublicKey(pk);
    final t = Handshake.transcript(idA: id, helloA: [1], idB: 'zzz', helloB: [2]);
    final sig = (await Ed25519().sign(Handshake.authMessage(id, t), keyPair: kp)).bytes;

    expect(await Handshake.verifyAuth(peerPublicKey: pk, peerId: id, transcript: t, signature: sig), isTrue);
    final otherT = Handshake.transcript(idA: id, helloA: [9], idB: 'zzz', helloB: [2]);
    expect(await Handshake.verifyAuth(peerPublicKey: pk, peerId: id, transcript: otherT, signature: sig), isFalse);
    expect(await Handshake.verifyAuth(peerPublicKey: pk, peerId: 'zzz', transcript: t, signature: sig), isFalse);
    expect(await Handshake.verifyAuth(peerPublicKey: pk, peerId: id, transcript: t, signature: [1, 2]), isFalse);
  });

  test('safety number is symmetric, stable and unique per pair', () {
    final a = List.generate(32, (i) => i);
    final b = List.generate(32, (i) => 255 - i);
    final c = List.generate(32, (i) => (i * 7) % 256);
    expect(safetyNumber(a, b), safetyNumber(b, a));
    expect(safetyNumber(a, b), matches(RegExp(r'^\d{5}( \d{5}){5}$')));
    expect(safetyNumber(a, c), isNot(safetyNumber(a, b)));
  });

  test('hello requires ephemeral key and nonce of the right size', () async {
    final kp = await Ed25519().newKeyPair();
    final pk = (await kp.extractPublicKey()).bytes;
    final id = deviceIdFromPublicKey(pk);
    final ok = HelloCodec.encode(
        deviceId: id, displayName: 'A', publicKey: pk, ephemeralPublicKey: List.filled(32, 1), nonce: List.filled(16, 2));
    expect(HelloCodec.decode(ok).peer.id, id);
    final badEph = HelloCodec.encode(
        deviceId: id, displayName: 'A', publicKey: pk, ephemeralPublicKey: [1, 2], nonce: List.filled(16, 2));
    expect(() => HelloCodec.decode(badEph), throwsFormatException);
  });

  test('profile codec validates names', () {
    expect(ProfileCodec.decode(ProfileCodec.encode('  Zed ')), 'Zed');
    expect(() => ProfileCodec.decode(ProfileCodec.encode('')), throwsFormatException);
    expect(() => ProfileCodec.decode(Uint8List.fromList([1, 2])), throwsFormatException);
  });
}
