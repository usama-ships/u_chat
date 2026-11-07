import 'dart:convert';
import 'dart:typed_data';

import 'message_protocol.dart';

/// Body of a `voiceRequest` frame: the receiver asks for the audio of [id]
/// starting at [offset]. Because the receiver always says where it is,
/// resuming after a dropped link needs no extra protocol.
class VoiceRequest {
  const VoiceRequest(this.id, this.offset);

  final String id;
  final int offset;

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode({'id': id, 'o': offset})));

  static VoiceRequest decode(Uint8List body) {
    final json = _object(body);
    final id = json['id'];
    final offset = json['o'];
    if (id is! String || !ChatMessagePayload.isValidId(id)) {
      throw const FormatException('bad voice id');
    }
    if (offset is! int || offset < 0) throw const FormatException('bad voice offset');
    return VoiceRequest(id, offset);
  }
}

/// Body of a `voiceDone` frame: the audio of [id] arrived and passed its hash.
class VoiceDone {
  const VoiceDone(this.id);

  final String id;

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode({'id': id})));

  static VoiceDone decode(Uint8List body) {
    final id = _object(body)['id'];
    if (id is! String || !ChatMessagePayload.isValidId(id)) {
      throw const FormatException('bad voice id');
    }
    return VoiceDone(id);
  }
}

/// Body of a `voiceChunk` frame, binary to avoid base64's 33% overhead on a
/// slow link: `[36-byte id][4-byte big-endian offset][audio]`.
///
/// Empty [bytes] means the sender no longer has the audio.
class VoiceChunk {
  const VoiceChunk(this.id, this.offset, this.bytes);

  static const _idLength = 36;
  static const _headerLength = _idLength + 4;

  /// Well under the 64 KB frame limit, and small enough that a text message
  /// never waits long for the link.
  static const maxBytes = 8 * 1024;

  final String id;
  final int offset;
  final Uint8List bytes;

  Uint8List encode() {
    final out = Uint8List(_headerLength + bytes.length)
      ..setRange(0, _idLength, ascii.encode(id))
      ..setRange(_headerLength, _headerLength + bytes.length, bytes);
    ByteData.sublistView(out).setUint32(_idLength, offset);
    return out;
  }

  static VoiceChunk decode(Uint8List body) {
    if (body.length < _headerLength || body.length > _headerLength + maxBytes) {
      throw const FormatException('bad voice chunk size');
    }
    final String id;
    try {
      id = ascii.decode(Uint8List.sublistView(body, 0, _idLength));
    } on FormatException {
      throw const FormatException('bad voice id');
    }
    if (!ChatMessagePayload.isValidId(id)) throw const FormatException('bad voice id');
    return VoiceChunk(
      id,
      ByteData.sublistView(body).getUint32(_idLength),
      Uint8List.sublistView(body, _headerLength),
    );
  }
}

Map<String, Object?> _object(Uint8List body) {
  if (body.length > 256) throw const FormatException('body too large');
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(body));
  } catch (_) {
    throw const FormatException('body is not valid JSON');
  }
  if (json is! Map<String, Object?>) throw const FormatException('body is not an object');
  return json;
}
