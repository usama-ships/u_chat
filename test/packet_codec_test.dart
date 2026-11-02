import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:u_chat/core/bluetooth/transport/frame.dart';
import 'package:u_chat/core/bluetooth/transport/packet_codec.dart';

Uint8List randomBytes(int n, [int seed = 1]) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
}

void main() {
  test('frame larger than one packet is split and reassembled', () {
    final frame = randomBytes(1000);
    final packets = Fragmenter().split(frame, 20); // default-MTU payload
    expect(packets.length, (1000 / 13).ceil());
    expect(packets.every((p) => p.length <= 20), isTrue);

    final r = Reassembler();
    Uint8List? out;
    for (final p in packets) {
      out = r.add(p);
    }
    expect(out, frame);
    expect(r.pendingTransfers, 0);
  });

  test('small and empty frames use a single packet', () {
    final packets = Fragmenter().split(Uint8List(0), 512);
    expect(packets, hasLength(1));
    expect(Reassembler().add(packets.single), isEmpty);
  });

  test('out-of-order and duplicate packets are handled', () {
    final frame = randomBytes(300, 7);
    final packets = Fragmenter().split(frame, 50);
    final shuffled = [...packets.reversed, packets.first, packets.last];
    final r = Reassembler();
    final results = shuffled.map(r.add).whereType<Uint8List>().toList();
    expect(results, hasLength(1));
    expect(results.single, frame);
  });

  test('interleaved transfers reassemble independently', () {
    final f = Fragmenter();
    final a = f.split(randomBytes(100, 1), 30);
    final b = f.split(randomBytes(100, 2), 30);
    final r = Reassembler();
    final out = <Uint8List>[];
    for (var i = 0; i < a.length; i++) {
      final x = r.add(a[i]);
      final y = r.add(b[i]);
      if (x != null) out.add(x);
      if (y != null) out.add(y);
    }
    expect(out, [randomBytes(100, 1), randomBytes(100, 2)]);
  });

  test('rejects malformed packets', () {
    final r = Reassembler();
    expect(() => r.add(Uint8List(3)), throwsA(isA<PacketFormatException>()));
    // wrong version
    expect(() => r.add(Uint8List.fromList([0x23, 0, 0, 0, 0, 0, 1, 9])),
        throwsA(isA<PacketFormatException>()));
    // index >= total
    expect(() => r.add(Uint8List.fromList([0x13, 0, 0, 0, 2, 0, 1, 9])),
        throwsA(isA<PacketFormatException>()));
    // total == 0
    expect(() => r.add(Uint8List.fromList([0x13, 0, 0, 0, 0, 0, 0, 9])),
        throwsA(isA<PacketFormatException>()));
  });

  test('rejects frames over the size limit', () {
    final packets = Fragmenter().split(randomBytes(5000), 100);
    final r = Reassembler(maxFrameBytes: 4096);
    expect(() => packets.forEach(r.add), throwsA(isA<PacketFormatException>()));
  });

  test('limits concurrent incomplete transfers', () {
    final f = Fragmenter();
    final r = Reassembler(maxConcurrentTransfers: 2);
    r.add(f.split(randomBytes(50), 20).first);
    r.add(f.split(randomBytes(50), 20).first);
    expect(() => r.add(f.split(randomBytes(50), 20).first), throwsA(isA<PacketFormatException>()));
  });

  test('stale incomplete transfers expire', () {
    var now = DateTime(2026);
    final f = Fragmenter();
    final r = Reassembler(maxConcurrentTransfers: 1, clock: () => now);
    r.add(f.split(randomBytes(50), 20).first);
    now = now.add(const Duration(seconds: 30));
    expect(r.add(f.split(Uint8List(1), 20).single), hasLength(1));
  });

  test('frame encode/decode', () {
    final frame = Frame(FrameType.ping, Uint8List.fromList([1, 2, 3]));
    final decoded = Frame.decode(frame.encode());
    expect(decoded.type, FrameType.ping);
    expect(decoded.body, [1, 2, 3]);
    expect(() => Frame.decode(Uint8List(0)), throwsFormatException);
    expect(() => Frame.decode(Uint8List.fromList([0x7f])), throwsFormatException);
  });
}
