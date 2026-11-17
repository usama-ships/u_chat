import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/models/message_type.dart';
import '../../data/repositories/message_repository.dart';
import '../bluetooth/models/incoming_frame.dart';
import '../bluetooth/transport/frame.dart';
import '../database/app_database.dart';
import '../voice/voice_meta.dart';
import '../voice/voice_store.dart';
import 'peer_transport.dart';
import 'voice_protocol.dart';

/// Moves voice audio between phones, after its `message` frame has arrived.
///
/// The receiver drives: it asks for one [VoiceChunk] at a time and says where
/// to continue from, so the sender keeps no state and an interrupted transfer
/// resumes by simply asking again. Between chunks the link is free, so text
/// messages never queue behind audio.
///
/// A sender's message becomes `delivered` only on [VoiceDone], which the
/// receiver sends once the whole file has passed its SHA-256 check.
class VoiceTransferService extends GetxService {
  VoiceTransferService(
    this._transport,
    this._messages,
    this._store, {
    this.requestTimeout = const Duration(seconds: 15),
    this.maxTimeouts = 3,
  });

  final PeerTransport _transport;
  final MessageRepository _messages;
  final VoiceStore _store;
  final Duration requestTimeout;
  final int maxTimeouts;

  /// 0 to 1 for transfers under way, in either direction, by message ID.
  final progress = <String, double>{}.obs;

  /// Incoming audio that couldn't be fetched. Tapping the bubble retries.
  final failed = <String>{}.obs;

  final _active = <String, _Pull>{}; // by peer ID
  final _starting = <String>{};

  /// Fetches the next missing audio from [peerId], if there is any and
  /// nothing is being fetched from that peer yet.
  Future<void> pull(String peerId) async {
    if (_active.containsKey(peerId) || !_transport.isPeerConnected(peerId)) return;
    if (!_starting.add(peerId)) return;
    try {
      final next = await _nextMissing(peerId);
      if (next == null) return;
      final (message, meta) = next;
      var offset = await _store.partialLength(message.conversationId, message.id);
      if (offset > meta.sizeBytes) {
        await _store.discardPartial(message.conversationId, message.id);
        offset = 0;
      }
      final pull = _Pull(peerId, message, meta, offset);
      _active[peerId] = pull;
      _setProgress(message.id, offset, meta.sizeBytes);
      _request(pull);
    } finally {
      _starting.remove(peerId);
    }
  }

  Future<(Message, VoiceMeta)?> _nextMissing(String peerId) async {
    for (final message in await _messages.incomingVoiceFrom(peerId)) {
      if (failed.contains(message.id) || _store.hasAudio(message.conversationId, message.id)) {
        continue;
      }
      try {
        return (message, VoiceMeta.decode(message.content));
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  /// Tries a failed download again.
  Future<void> retry(Message message) async {
    failed.remove(message.id);
    await pull(message.senderId);
  }

  void _request(_Pull pull) {
    pull.timer?.cancel();
    pull.timer = Timer(requestTimeout, () => _onRequestTimeout(pull));
    _transport
        .sendFrame(
          pull.peerId,
          Frame(FrameType.voiceRequest, VoiceRequest(pull.message.id, pull.offset).encode()),
        )
        .catchError((Object e) => debugPrint('Requesting voice chunk failed: $e'));
  }

  void _onRequestTimeout(_Pull pull) {
    if (_active[pull.peerId] != pull) return;
    pull.timeouts++;
    if (pull.timeouts >= maxTimeouts) {
      _giveUp(pull);
      _pullNext(pull.peerId);
    } else {
      _request(pull);
    }
  }

  void _pullNext(String peerId) => pull(peerId).ignore();

  void _giveUp(_Pull pull) {
    pull.timer?.cancel();
    _active.remove(pull.peerId);
    progress.remove(pull.message.id);
    failed.add(pull.message.id);
  }

  /// The link dropped: stop waiting. What arrived stays on disk, and the next
  /// [pull] continues from there.
  void onPeerLost(String peerId) {
    _active.remove(peerId)?.timer?.cancel();
  }

  /// Handles a voice frame. Await this to keep a peer's frames in order.
  Future<void> handle(IncomingFrame incoming) async {
    final peerId = incoming.peer.id;
    try {
      switch (incoming.frame.type) {
        case FrameType.voiceRequest:
          await _serve(peerId, VoiceRequest.decode(incoming.frame.body));
        case FrameType.voiceChunk:
          await receiveChunk(peerId, VoiceChunk.decode(incoming.frame.body));
        case FrameType.voiceDone:
          await _finishSending(peerId, VoiceDone.decode(incoming.frame.body));
        default:
          break;
      }
    } on FormatException catch (e) {
      debugPrint('Rejected voice frame from $peerId: ${e.message}');
    }
  }

  // ---------------------------------------------------------------- sending

  Future<void> _serve(String peerId, VoiceRequest request) async {
    final message = await _messages.find(request.id);
    // Only the phone this message was addressed to may read its audio.
    if (message == null ||
        !message.isOutgoing ||
        message.receiverId != peerId ||
        message.type != MessageType.voice) {
      debugPrint('Refused voice request from $peerId');
      return;
    }
    final meta = VoiceMeta.decode(message.content);
    if (request.offset > meta.sizeBytes) return;

    final bytes = await _store.read(
      message.conversationId,
      message.id,
      request.offset,
      VoiceChunk.maxBytes,
    );
    _setProgress(message.id, request.offset + (bytes?.length ?? 0), meta.sizeBytes);
    // Not awaited: the write takes a while and mustn't hold up incoming frames.
    _transport
        .sendFrame(
          peerId,
          Frame(
            FrameType.voiceChunk,
            VoiceChunk(request.id, request.offset, bytes ?? Uint8List(0)).encode(),
          ),
        )
        .catchError((Object e) => debugPrint('Sending voice chunk failed: $e'));
  }

  Future<void> _finishSending(String peerId, VoiceDone done) async {
    await _messages.markDelivered(done.id, peerId);
    progress.remove(done.id);
  }

  // -------------------------------------------------------------- receiving

  @visibleForTesting
  Future<void> receiveChunk(String peerId, VoiceChunk chunk) async {
    final pull = _active[peerId];
    if (pull == null || pull.message.id != chunk.id || pull.offset != chunk.offset) return;
    final message = pull.message;

    // The conversation may have been deleted while this was under way.
    if (await _messages.find(message.id) == null) {
      pull.timer?.cancel();
      _active.remove(peerId);
      progress.remove(message.id);
      _pullNext(peerId);
      return;
    }
    if (chunk.bytes.isEmpty || pull.offset + chunk.bytes.length > pull.meta.sizeBytes) {
      debugPrint('Voice transfer of ${message.id} failed: bad chunk');
      await _store.discardPartial(message.conversationId, message.id);
      _giveUp(pull);
      _pullNext(peerId);
      return;
    }

    await _store.appendPartial(message.conversationId, message.id, chunk.bytes);
    pull
      ..offset += chunk.bytes.length
      ..timeouts = 0;
    _setProgress(message.id, pull.offset, pull.meta.sizeBytes);

    if (pull.offset < pull.meta.sizeBytes) {
      _request(pull);
      return;
    }

    if (!await _store.completePartial(message.conversationId, message.id, pull.meta)) {
      debugPrint('Voice transfer of ${message.id} failed: hash mismatch');
      _giveUp(pull);
      _pullNext(peerId);
      return;
    }
    pull.timer?.cancel();
    _active.remove(peerId);
    progress.remove(message.id);
    _transport
        .sendFrame(peerId, Frame(FrameType.voiceDone, VoiceDone(message.id).encode()))
        .catchError((Object e) => debugPrint('Sending voice done failed: $e'));
    _pullNext(peerId);
  }

  void _setProgress(String id, int done, int total) => progress[id] = done / total;

  @override
  void onClose() {
    for (final pull in _active.values) {
      pull.timer?.cancel();
    }
    super.onClose();
  }
}

class _Pull {
  _Pull(this.peerId, this.message, this.meta, this.offset);

  final String peerId;
  final Message message;
  final VoiceMeta meta;
  int offset;
  int timeouts = 0;
  Timer? timer;
}
