import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../data/models/conversation_with_peer.dart';
import '../../data/models/delivery_status.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../bluetooth/models/incoming_frame.dart';
import '../bluetooth/models/peer_info.dart';
import '../bluetooth/transport/frame.dart';
import '../bluetooth/transport/hello.dart';
import '../database/app_database.dart';
import 'message_protocol.dart';
import 'peer_transport.dart';

/// Reliable, ordered message delivery on top of [PeerTransport].
///
/// Sending is stop-and-wait per peer: one message is in flight at a time, and
/// the next is sent only after the previous one is ACKed or gives up. That
/// keeps messages in order on the receiver without reordering logic.
///
/// Status lifecycle (outgoing):
///   pending → sending → sent (all packets written) → delivered (ACK received)
///   no ACK within [ackTimeout] → pending again (resent); after [maxAttempts]
///   → failed (user can retry). A dropped link resets `sending` to `pending`;
///   `sent`-but-unacked messages are resent on reconnect.
///
/// Receiving: validate → store (duplicates ignored by message ID) → ACK.
/// The ACK is sent only after the message is stored, and is re-sent for
/// duplicates, so a lost ACK just causes a harmless retransmission.
class MessagingService extends GetxService {
  MessagingService(
    this._transport,
    this._conversations,
    this._messages, {
    this.ackTimeout = const Duration(seconds: 10),
    this.maxAttempts = 3,
  });

  final PeerTransport _transport;
  final ConversationRepository _conversations;
  final MessageRepository _messages;
  final Duration ackTimeout;
  final int maxAttempts;

  /// Conversation currently on screen; its incoming messages aren't counted
  /// as unread.
  String? activeConversationId;

  final _subscriptions = <StreamSubscription<Object?>>[];
  final _inFlight = <String, _InFlight>{}; // by peer ID
  final _flushing = <String>{};
  final _flushAgain = <String>{};
  final _recentlyAcked = <String>{};
  final _peerStored = <String, Future<void>>{};
  final _incomingChain = <String, Future<void>>{};

  Future<MessagingService> init() async {
    // Anything that was mid-send when the app last stopped is pending again.
    await _messages.resetInterrupted();
    _subscriptions
      ..add(_transport.peerReady.listen(_onPeerReady))
      ..add(_transport.peerLost.listen(_onPeerLost))
      ..add(_transport.frames.listen(_onFrame));
    return this;
  }

  // ------------------------------------------------------------- public API

  /// Stores a text message and sends it as soon as the peer is connected.
  /// If it isn't, tries to connect in the background. Throws [ArgumentError]
  /// for empty / oversized text.
  Future<void> sendText(ConversationWithPeer conversation, String text) async {
    await _messages.queueOutgoingText(
      conversationId: conversation.conversation.id,
      receiverId: conversation.peer.id,
      text: text,
    );
    _kick(conversation.peer.id);
  }

  /// Requeues a failed message.
  Future<void> retry(Message message) async {
    if (!message.isOutgoing) return;
    if (await _messages.retryFailed(message.id)) _kick(message.receiverId);
  }

  void _kick(String peerId) {
    if (_transport.isPeerConnected(peerId)) {
      _flush(peerId);
    } else {
      _transport.connectToKnownPeer(peerId).ignore();
    }
  }

  // ---------------------------------------------------------------- events

  void _onPeerReady(PeerInfo peer) {
    final stored = _conversations.openConversationWithPeer(peer).then<void>((_) {}).catchError(
      (Object e) => debugPrint('Storing peer ${peer.id} failed: $e'),
    );
    _peerStored[peer.id] = stored;
    stored.then((_) => _flush(peer.id));
  }

  Future<void> _onPeerLost(String peerId) async {
    _inFlight.remove(peerId)?.timer.cancel();
    await _messages.resetInterrupted(conversationId: _conversations.conversationIdForPeer(peerId));
  }

  void _onFrame(IncomingFrame incoming) {
    final peerId = incoming.peer.id;
    // Handle each peer's frames strictly in arrival order.
    final previous = _incomingChain[peerId] ?? Future.value();
    _incomingChain[peerId] = previous.then((_) => _handleFrame(incoming)).catchError(
          (Object e) => debugPrint('Handling frame from $peerId failed: $e'),
        );
  }

  Future<void> _handleFrame(IncomingFrame incoming) async {
    await _peerStored[incoming.peer.id];
    switch (incoming.frame.type) {
      case FrameType.message:
        await _handleMessage(incoming.peer, incoming.frame);
      case FrameType.ack:
        await _handleAck(incoming.peer, incoming.frame);
      case FrameType.profile:
        try {
          final name = ProfileCodec.decode(incoming.frame.body);
          await _conversations.updatePeerName(incoming.peer.id, name);
        } on FormatException catch (e) {
          debugPrint('Rejected profile from ${incoming.peer.id}: ${e.message}');
        }
      default:
        break;
    }
  }

  Future<void> _handleMessage(PeerInfo peer, Frame frame) async {
    final ChatMessagePayload payload;
    try {
      payload = ChatMessagePayload.decode(frame.body);
    } on FormatException catch (e) {
      debugPrint('Rejected message from ${peer.id}: ${e.message}');
      return;
    }
    // Only accept messages the authenticated link peer sent, addressed to us.
    if (payload.senderId != peer.id || payload.receiverId != _messages.myId) {
      debugPrint('Rejected message from ${peer.id}: sender/receiver mismatch');
      return;
    }

    // Recreates the conversation if the user deleted it while connected.
    final conversationId = (await _conversations.openConversationWithPeer(peer)).id;
    await _messages.storeIncoming(
      id: payload.id,
      conversationId: conversationId,
      senderId: peer.id,
      type: payload.type,
      content: payload.content,
      sentAt: payload.timestamp,
      seq: payload.seq,
      incrementUnread: activeConversationId != conversationId,
    );
    // ACK new and duplicate messages alike: the sender may have missed our
    // previous ACK.
    try {
      await _transport.sendFrame(peer.id, Frame(FrameType.ack, AckPayload([payload.id]).encode()));
    } catch (e) {
      debugPrint('Sending ACK to ${peer.id} failed: $e');
    }
  }

  Future<void> _handleAck(PeerInfo peer, Frame frame) async {
    final AckPayload ack;
    try {
      ack = AckPayload.decode(frame.body);
    } on FormatException catch (e) {
      debugPrint('Rejected ack from ${peer.id}: ${e.message}');
      return;
    }
    for (final id in ack.ids) {
      await _messages.markDelivered(id, peer.id);
      final inFlight = _inFlight[peer.id];
      if (inFlight != null && inFlight.messageId == id) {
        inFlight.timer.cancel();
        _inFlight.remove(peer.id);
      } else {
        // The ACK may beat the sender's own bookkeeping; see _sendNext.
        _recentlyAcked.add(id);
      }
    }
    _flush(peer.id);
  }

  // ---------------------------------------------------------------- sending

  Future<void> _flush(String peerId) async {
    if (!_flushing.add(peerId)) {
      _flushAgain.add(peerId);
      return;
    }
    try {
      do {
        _flushAgain.remove(peerId);
        await _sendNext(peerId);
      } while (_flushAgain.remove(peerId));
    } catch (e) {
      debugPrint('Flush for $peerId failed: $e');
    } finally {
      _flushing.remove(peerId);
    }
  }

  Future<void> _sendNext(String peerId) async {
    if (_inFlight.containsKey(peerId) || !_transport.isPeerConnected(peerId)) return;
    await _peerStored[peerId];

    final next = await _messages.nextToSend(_conversations.conversationIdForPeer(peerId));
    if (next == null) return;

    await _messages.setStatus(next.id, DeliveryStatus.sending);
    try {
      final payload = ChatMessagePayload(
        id: next.id,
        senderId: next.senderId,
        receiverId: next.receiverId,
        type: next.type,
        content: next.content,
        timestamp: next.sentAt,
        seq: next.seq,
      );
      await _transport.sendFrame(peerId, Frame(FrameType.message, payload.encode()));
    } catch (e) {
      // Link trouble: the session will drop and reconnect logic takes over.
      debugPrint('Sending ${next.id} failed: $e');
      await _messages.setStatus(next.id, DeliveryStatus.pending, onlyFrom: {DeliveryStatus.sending});
      return;
    }

    final markedSent = await _messages.setStatus(
      next.id,
      DeliveryStatus.sent,
      onlyFrom: {DeliveryStatus.sending},
    );
    if (!markedSent || _recentlyAcked.remove(next.id)) {
      // Already delivered (ACK arrived during the write): move on.
      _flushAgain.add(peerId);
      return;
    }
    _inFlight[peerId] = _InFlight(
      next.id,
      Timer(ackTimeout, () => _onAckTimeout(peerId, next.id)),
    );
  }

  Future<void> _onAckTimeout(String peerId, String messageId) async {
    if (_inFlight[peerId]?.messageId != messageId) return;
    _inFlight.remove(peerId);
    final status = await _messages.recordAckTimeout(messageId, maxAttempts: maxAttempts);
    debugPrint('No ACK for $messageId → $status');
    _flush(peerId);
  }

  @override
  void onClose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    for (final f in _inFlight.values) {
      f.timer.cancel();
    }
    super.onClose();
  }
}

class _InFlight {
  _InFlight(this.messageId, this.timer);
  final String messageId;
  final Timer timer;
}
