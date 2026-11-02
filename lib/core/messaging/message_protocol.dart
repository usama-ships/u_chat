import 'dart:convert';
import 'dart:typed_data';

import '../../data/models/message_type.dart';
import '../constants/app_constants.dart';

/// Body of a `message` frame.
///
/// ```json
/// {"v":1,"id":"<uuid v4>","senderId":"…","receiverId":"…","type":"text",
///  "content":"Hello!","timestamp":1793600000000,"seq":42}
/// ```
/// `timestamp` is the sender's clock (epoch ms); `seq` is the sender's
/// per-conversation counter.
class ChatMessagePayload {
  const ChatMessagePayload({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.content,
    required this.timestamp,
    required this.seq,
  });

  static const version = 1;
  static final _uuidPattern =
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
  static final _deviceIdPattern = RegExp(r'^[a-z2-7]{26}$');

  final String id;
  final String senderId;
  final String receiverId;
  final MessageType type;
  final String content;
  final int timestamp;
  final int seq;

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode({
        'v': version,
        'id': id,
        'senderId': senderId,
        'receiverId': receiverId,
        'type': type.name,
        'content': content,
        'timestamp': timestamp,
        'seq': seq,
      })));

  /// Decodes and validates. Throws [FormatException] for anything malformed.
  static ChatMessagePayload decode(Uint8List body) {
    final json = _decodeObject(body);
    if (json['v'] != version) throw const FormatException('unsupported message version');

    final id = json['id'];
    final senderId = json['senderId'];
    final receiverId = json['receiverId'];
    final typeName = json['type'];
    final content = json['content'];
    final timestamp = json['timestamp'];
    final seq = json['seq'];

    if (id is! String || !_uuidPattern.hasMatch(id)) throw const FormatException('bad id');
    if (senderId is! String || !_deviceIdPattern.hasMatch(senderId)) {
      throw const FormatException('bad senderId');
    }
    if (receiverId is! String || !_deviceIdPattern.hasMatch(receiverId)) {
      throw const FormatException('bad receiverId');
    }
    final type = MessageType.values.where((t) => t.name == typeName).firstOrNull;
    if (type == null) throw const FormatException('unknown message type');
    if (content is! String || content.trim().isEmpty ||
        content.length > AppConstants.maxTextLength) {
      throw const FormatException('bad content');
    }
    if (timestamp is! int || timestamp <= 0) throw const FormatException('bad timestamp');
    if (seq is! int || seq < 1) throw const FormatException('bad seq');

    return ChatMessagePayload(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      type: type,
      content: content,
      timestamp: timestamp,
      seq: seq,
    );
  }
}

/// Body of an `ack` frame: IDs of messages the receiver has stored.
class AckPayload {
  const AckPayload(this.ids);

  static const maxIds = 32;
  final List<String> ids;

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode({'ids': ids})));

  static AckPayload decode(Uint8List body) {
    final json = _decodeObject(body);
    final ids = json['ids'];
    if (ids is! List || ids.isEmpty || ids.length > maxIds) {
      throw const FormatException('bad ack ids');
    }
    final result = <String>[];
    for (final id in ids) {
      if (id is! String || !ChatMessagePayload._uuidPattern.hasMatch(id)) {
        throw const FormatException('bad ack id');
      }
      result.add(id);
    }
    return AckPayload(result);
  }
}

const _maxBodyBytes = 32 * 1024;

Map<String, Object?> _decodeObject(Uint8List body) {
  if (body.length > _maxBodyBytes) throw const FormatException('body too large');
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(body));
  } catch (_) {
    throw const FormatException('body is not valid JSON');
  }
  if (json is! Map<String, Object?>) throw const FormatException('body is not an object');
  return json;
}
