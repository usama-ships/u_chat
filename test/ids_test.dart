import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:u_chat/core/security/ids.dart';
import 'package:u_chat/data/repositories/settings_repository.dart';

void main() {
  test('base32 matches RFC 4648 test vectors (lowercase, unpadded)', () {
    expect(base32Encode(utf8.encode('')), '');
    expect(base32Encode(utf8.encode('f')), 'my');
    expect(base32Encode(utf8.encode('fo')), 'mzxq');
    expect(base32Encode(utf8.encode('foo')), 'mzxw6');
    expect(base32Encode(utf8.encode('foobar')), 'mzxw6ytboi');
  });

  test('deviceId is deterministic, 26 chars, and differs per key', () async {
    final ed = Ed25519();
    final k1 = await (await ed.newKeyPair()).extractPublicKey();
    final k2 = await (await ed.newKeyPair()).extractPublicKey();

    final id1 = deviceIdFromPublicKey(k1.bytes);
    expect(id1, hasLength(26));
    expect(deviceIdFromPublicKey(k1.bytes), id1);
    expect(deviceIdFromPublicKey(k2.bytes), isNot(id1));
  });

  test('deviceId rejects wrong key length', () {
    expect(() => deviceIdFromPublicKey([1, 2, 3]), throwsArgumentError);
  });

  test('conversationId is symmetric', () {
    expect(conversationIdFor('aaa', 'bbb'), conversationIdFor('bbb', 'aaa'));
    expect(conversationIdFor('aaa', 'bbb'), isNot(conversationIdFor('aaa', 'ccc')));
  });

  test('display name validation', () {
    expect(SettingsRepository.validateDisplayName('  Bob  '), isNull);
    expect(SettingsRepository.validateDisplayName('   '), isNotNull);
    expect(SettingsRepository.validateDisplayName('x' * 33), isNotNull);
    expect(SettingsRepository.validateDisplayName('bad\nname'), isNotNull);
  });
}
