import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:u_chat/core/bluetooth/link/ble_link.dart';
import 'package:u_chat/core/bluetooth/link/peer_session.dart';
import 'package:u_chat/core/bluetooth/models/peer_info.dart';
import 'package:u_chat/core/bluetooth/transport/frame.dart';
import 'package:u_chat/core/bluetooth/transport/packet_codec.dart';
import 'package:u_chat/core/security/handshake.dart';
import 'package:u_chat/core/security/ids.dart';

/// In-memory link; packets written on one end arrive at the other.
class FakeLink extends BleLink {
  FakeLink(super.id, {required this.central, this.packetSize = 20});

  final bool central;
  final int packetSize;
  FakeLink? other;
  bool disconnected = false;
  final sentPackets = <Uint8List>[];

  /// Lets a test modify packets in flight.
  Uint8List Function(Uint8List packet)? tamper;

  static (FakeLink, FakeLink) pair({int packetSize = 20}) {
    final a = FakeLink('c:a', central: true, packetSize: packetSize);
    final b = FakeLink('p:b', central: false, packetSize: packetSize);
    a.other = b;
    b.other = a;
    return (a, b);
  }

  @override
  bool get isCentralRole => central;

  @override
  Future<int> maxPacketSize() async => packetSize;

  @override
  Future<void> sendPacket(Uint8List packet) async {
    if (isClosed) throw StateError('closed');
    final copy = Uint8List.fromList(packet);
    sentPackets.add(copy);
    final delivered = tamper?.call(copy) ?? copy;
    scheduleMicrotask(() => other?.deliver(delivered));
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
    markClosed();
    other?.markClosed();
  }
}

class TestIdentity {
  TestIdentity._(this.keyPair, this.publicKey, this.id);

  final SimpleKeyPair keyPair;
  final List<int> publicKey;
  final String id;

  static Future<TestIdentity> create() async {
    final kp = await Ed25519().newKeyPair();
    final pk = (await kp.extractPublicKey()).bytes;
    return TestIdentity._(kp, pk, deviceIdFromPublicKey(pk));
  }

  /// [claim] lets an impostor present someone else's ID and public key while
  /// still signing with its own private key.
  LocalIdentity local(String name, {TestIdentity? claim}) => LocalIdentity(
        deviceId: (claim ?? this).id,
        publicKey: (claim ?? this).publicKey,
        displayName: name,
        sign: (m) async => (await Ed25519().sign(m, keyPair: keyPair)).bytes,
      );
}

class Harness {
  Harness(this.link, LocalIdentity identity,
      {String? expectedPrefix, Future<bool> Function(PeerInfo)? admit}) {
    session = PeerSession(
      link: link,
      identity: identity,
      expectedIdPrefix: expectedPrefix,
      admit: admit,
      onReady: (_) => readyCount++,
      onFrame: (_, f) => frames.add(f),
      onClosed: (_) => closed.complete(),
      onLatency: (_, ms) => latencies.add(ms),
      pingInterval: const Duration(milliseconds: 50),
      handshakeTimeout: const Duration(milliseconds: 600),
    );
  }

  final FakeLink link;
  late final PeerSession session;
  int readyCount = 0;
  final frames = <Frame>[];
  final latencies = <int>[];
  final closed = Completer<void>();
}

Future<(Harness, Harness)> connected(
  TestIdentity a,
  TestIdentity b, {
  int packetSize = 20,
}) async {
  final (la, lb) = FakeLink.pair(packetSize: packetSize);
  final ha = Harness(la, a.local('Alice'));
  final hb = Harness(lb, b.local('Bob'));
  ha.session.start();
  hb.session.start();
  await Future.wait([ha.session.ready, hb.session.ready]);
  return (ha, hb);
}

bool containsBytes(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

void main() {
  late TestIdentity alice;
  late TestIdentity bob;
  late TestIdentity mallory;

  setUpAll(() async {
    alice = await TestIdentity.create();
    bob = await TestIdentity.create();
    mallory = await TestIdentity.create();
  });

  test('authenticated handshake identifies both peers over 20-byte packets', () async {
    final (ha, hb) = await connected(alice, bob);
    expect(ha.session.peer!.id, bob.id);
    expect(ha.session.peer!.displayName, 'Bob');
    expect(hb.session.peer!.id, alice.id);
    expect(ha.link.sentPackets.length, greaterThan(2)); // needed fragmentation
  });

  test('application frames are encrypted on the wire and decrypted on arrival', () async {
    final (ha, hb) = await connected(alice, bob, packetSize: 512);
    final secret = utf8.encode('the eagle lands at noon');
    final before = ha.link.sentPackets.length;
    await ha.session.send(Frame(FrameType.message, Uint8List.fromList(secret)));
    await hb.session.send(Frame(FrameType.ack, Uint8List.fromList([7])));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(hb.frames.single.body, secret);
    expect(ha.frames.single.type, FrameType.ack);
    final onWire = ha.link.sentPackets.skip(before).expand((p) => p).toList();
    expect(containsBytes(onWire, secret), isFalse);
    expect(ha.latencies, isNotEmpty); // encrypted ping/pong works
  });

  test('impostor presenting a copied identity fails the identity proof', () async {
    final (la, lb) = FakeLink.pair();
    final ha = Harness(la, alice.local('Alice'));
    final hm = Harness(lb, mallory.local('Bob', claim: bob)); // Bob's ID + key, Mallory's signature
    ha.session.start();
    hm.session.start();
    await expectLater(ha.session.ready, throwsStateError);
    expect(ha.session.closeReason, 'identity proof failed');
    expect(ha.readyCount, 0);
  });

  test('HELLO whose ID does not match its key is rejected', () async {
    final (la, lb) = FakeLink.pair();
    final forged = LocalIdentity(
      deviceId: alice.id,
      publicKey: bob.publicKey,
      displayName: 'X',
      sign: (m) async => (await Ed25519().sign(m, keyPair: bob.keyPair)).bytes,
    );
    final ha = Harness(la, alice.local('Alice'));
    final hb = Harness(lb, forged);
    ha.session.start();
    hb.session.start();
    await expectLater(ha.session.ready, throwsStateError);
    expect(ha.session.closeReason, contains('invalid hello'));
  });

  test('tampered encrypted frame closes the session', () async {
    final (ha, hb) = await connected(alice, bob, packetSize: 512);
    ha.link.tamper = (p) => p..[p.length - 1] ^= 0x01; // flip a bit in the tag
    await ha.session.send(Frame(FrameType.message, Uint8List.fromList([1, 2, 3])));
    await hb.closed.future;
    expect(hb.session.closeReason, contains('rejected encrypted frame'));
    expect(hb.frames, isEmpty);
  });

  test('replayed encrypted frame closes the session', () async {
    final (ha, hb) = await connected(alice, bob, packetSize: 512);
    await ha.session.send(Frame(FrameType.message, Uint8List.fromList([1])));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final captured = ha.link.sentPackets.last;
    hb.link.deliver(captured); // attacker re-sends a recorded packet
    await hb.closed.future;
    expect(hb.session.closeReason, contains('replayed'));
    expect(hb.frames, hasLength(1));
  });

  test('plaintext application frames after the handshake are rejected', () async {
    final (_, hb) = await connected(alice, bob, packetSize: 512);
    final injected = Fragmenter().split(Frame(FrameType.message, Uint8List(3)).encode(), 512);
    hb.link.deliver(injected.single);
    await hb.closed.future;
    expect(hb.session.closeReason, contains('unencrypted'));
  });

  test('wrong expected device closes and disconnects', () async {
    final (la, lb) = FakeLink.pair();
    final ha = Harness(la, alice.local('Alice'), expectedPrefix: 'zzzzzzzz');
    final hb = Harness(lb, bob.local('Bob'));
    ha.session.start();
    hb.session.start();
    await expectLater(ha.session.ready, throwsStateError);
    expect(la.disconnected, isTrue);
  });

  test('a refused (e.g. blocked) peer is told BYE and never becomes ready', () async {
    final (la, lb) = FakeLink.pair();
    final ha = Harness(la, alice.local('Alice'));
    final hb = Harness(lb, bob.local('Bob'), admit: (_) async => false);
    ha.session.start();
    hb.session.start();
    await expectLater(hb.session.ready, throwsStateError);
    expect(hb.session.closeReason, 'peer not allowed');
    expect(hb.readyCount, 0);
    await ha.closed.future;
  });

  test('incompatible protocol version is reported clearly', () async {
    final (la, lb) = FakeLink.pair(packetSize: 512);
    final ha = Harness(la, alice.local('Alice'));
    ha.session.start();
    final oldHello = utf8.encode(jsonEncode({'v': 1, 'id': bob.id, 'name': 'Bob', 'pk': base64Encode(bob.publicKey)}));
    lb.sendPacket(Fragmenter().split(Frame(FrameType.hello, Uint8List.fromList(oldHello)).encode(), 512).single);
    await expectLater(ha.session.ready, throwsStateError);
    expect(ha.session.closeReason, contains('incompatible version'));
  });

  test('handshake times out if the peer never answers', () async {
    final (la, _) = FakeLink.pair();
    la.other = null;
    final ha = Harness(la, alice.local('Alice'));
    ha.session.start();
    await expectLater(ha.session.ready, throwsStateError);
    expect(ha.session.closeReason, 'handshake timeout');
  });

  test('BYE closes the other side and marks it as intentional', () async {
    final (ha, hb) = await connected(alice, bob);
    await hb.session.disconnectGracefully();
    await ha.closed.future;
    expect(ha.session.byeReceived, isTrue);
    expect(hb.session.closedLocally, isTrue);
  });

  test('link loss closes the session', () async {
    final (ha, hb) = await connected(alice, bob);
    ha.link.markClosed();
    await ha.closed.future;
    expect(ha.session.closeReason, 'link lost');
    expect(ha.session.byeReceived, isFalse);
    await hb.session.close('done');
  });
}
