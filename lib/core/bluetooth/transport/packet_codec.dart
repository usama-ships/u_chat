import 'dart:math' as math;
import 'dart:typed_data';

/// Splits frames into BLE-sized packets and reassembles them.
///
/// Every packet carries a 7-byte header:
/// ```
/// [0]    version (high 4 bits) | flags (low 4 bits: 0x1 FIRST, 0x2 LAST)
/// [1-2]  transferId  uint16 big-endian (one per frame, wraps around)
/// [3-4]  index       uint16 big-endian
/// [5-6]  total       uint16 big-endian (number of packets in the frame)
/// [7..]  chunk of the frame
/// ```
/// A whole frame is never assumed to fit in one packet.
abstract final class PacketHeader {
  static const length = 7;
  static const version = 1;
  static const flagFirst = 0x1;
  static const flagLast = 0x2;
}

class PacketFormatException implements Exception {
  PacketFormatException(this.message);
  final String message;
  @override
  String toString() => 'PacketFormatException: $message';
}

class Fragmenter {
  int _nextTransferId = 0;

  /// Splits [frame] into packets of at most [maxPacketSize] bytes.
  List<Uint8List> split(Uint8List frame, int maxPacketSize) {
    final chunkSize = maxPacketSize - PacketHeader.length;
    if (chunkSize < 1) {
      throw ArgumentError.value(maxPacketSize, 'maxPacketSize', 'too small for the header');
    }
    final total = math.max(1, (frame.length / chunkSize).ceil());
    if (total > 0xFFFF) throw ArgumentError('Frame too large: ${frame.length} bytes');

    final transferId = _nextTransferId;
    _nextTransferId = (_nextTransferId + 1) & 0xFFFF;

    return List.generate(total, (index) {
      final start = index * chunkSize;
      final end = math.min(start + chunkSize, frame.length);
      final packet = Uint8List(PacketHeader.length + (end - start));
      var flags = 0;
      if (index == 0) flags |= PacketHeader.flagFirst;
      if (index == total - 1) flags |= PacketHeader.flagLast;
      final header = ByteData.sublistView(packet, 0, PacketHeader.length)
        ..setUint8(0, (PacketHeader.version << 4) | flags)
        ..setUint16(1, transferId)
        ..setUint16(3, index)
        ..setUint16(5, total);
      assert(header.lengthInBytes == PacketHeader.length);
      packet.setRange(PacketHeader.length, packet.length, frame, start);
      return packet;
    });
  }
}

class Reassembler {
  Reassembler({
    this.maxFrameBytes = 64 * 1024,
    this.maxConcurrentTransfers = 4,
    this.transferTimeout = const Duration(seconds: 15),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int maxFrameBytes;
  final int maxConcurrentTransfers;
  final Duration transferTimeout;
  final DateTime Function() _clock;

  final _transfers = <int, _Transfer>{};

  /// Adds a packet. Returns the complete frame when its last missing packet
  /// arrives, otherwise null. Duplicate packets are ignored. Throws
  /// [PacketFormatException] for malformed or oversized input.
  Uint8List? add(Uint8List packet) {
    if (packet.length < PacketHeader.length) {
      throw PacketFormatException('packet shorter than header');
    }
    final header = ByteData.sublistView(packet, 0, PacketHeader.length);
    final version = header.getUint8(0) >> 4;
    if (version != PacketHeader.version) {
      throw PacketFormatException('unsupported version $version');
    }
    final transferId = header.getUint16(1);
    final index = header.getUint16(3);
    final total = header.getUint16(5);
    if (total == 0 || index >= total) {
      throw PacketFormatException('bad index $index / $total');
    }

    final now = _clock();
    _transfers.removeWhere((_, t) => now.difference(t.startedAt) > transferTimeout);

    var transfer = _transfers[transferId];
    if (transfer == null) {
      if (_transfers.length >= maxConcurrentTransfers) {
        throw PacketFormatException('too many concurrent transfers');
      }
      transfer = _transfers[transferId] = _Transfer(total, now);
    } else if (transfer.parts.length != total) {
      throw PacketFormatException('total changed within transfer');
    }

    if (transfer.parts[index] != null) return null; // duplicate
    final chunk = Uint8List.sublistView(packet, PacketHeader.length);
    transfer.bytes += chunk.length;
    if (transfer.bytes > maxFrameBytes) {
      _transfers.remove(transferId);
      throw PacketFormatException('frame exceeds $maxFrameBytes bytes');
    }
    transfer.parts[index] = Uint8List.fromList(chunk);
    transfer.received++;

    if (transfer.received < total) return null;
    _transfers.remove(transferId);
    final builder = BytesBuilder(copy: false);
    for (final part in transfer.parts) {
      builder.add(part!);
    }
    return builder.takeBytes();
  }

  int get pendingTransfers => _transfers.length;
}

class _Transfer {
  _Transfer(int total, this.startedAt) : parts = List<Uint8List?>.filled(total, null);

  final List<Uint8List?> parts;
  final DateTime startedAt;
  int received = 0;
  int bytes = 0;
}
