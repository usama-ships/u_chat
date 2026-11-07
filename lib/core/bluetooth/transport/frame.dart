import 'dart:typed_data';

/// Kinds of frame exchanged over a link. Codes are part of the wire format.
///
/// Only [hello], [auth] and [sealed] travel in the clear. Everything else is
/// sent inside a [sealed] frame (encrypted) once the handshake has finished.
enum FrameType {
  /// Identity + ephemeral key exchange (plaintext).
  hello(0x01),

  /// Liveness probe; body is echoed back in [pong].
  ping(0x02),
  pong(0x03),

  /// Polite disconnect: the peer should not auto-reconnect.
  bye(0x04),

  /// Signature proving the identity key and binding the handshake (plaintext).
  auth(0x05),

  /// Display name update while connected.
  profile(0x06),

  /// Chat message.
  message(0x10),

  /// Delivery acknowledgement.
  ack(0x11),

  /// Receiver asks for voice audio from an offset.
  voiceRequest(0x12),

  /// A piece of voice audio.
  voiceChunk(0x13),

  /// Receiver has all the audio and verified it.
  voiceDone(0x14),

  /// Encrypted container for any other frame.
  sealed(0x20);

  const FrameType(this.code);
  final int code;

  static FrameType? fromCode(int code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }

  /// May appear outside encryption.
  bool get isPlaintext => this == hello || this == auth || this == sealed;
}

/// A protocol frame: `[type byte][body]`.
class Frame {
  Frame(this.type, [Uint8List? body]) : body = body ?? Uint8List(0);

  final FrameType type;
  final Uint8List body;

  Uint8List encode() => Uint8List(1 + body.length)
    ..[0] = type.code
    ..setRange(1, 1 + body.length, body);

  /// Throws [FormatException] for empty input or unknown types.
  static Frame decode(Uint8List bytes) {
    if (bytes.isEmpty) throw const FormatException('empty frame');
    final type = FrameType.fromCode(bytes[0]);
    if (type == null) throw FormatException('unknown frame type ${bytes[0]}');
    return Frame(type, Uint8List.sublistView(bytes, 1));
  }
}
