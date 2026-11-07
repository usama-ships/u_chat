import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../security/handshake.dart';
import '../ble_constants.dart';
import '../models/peer_info.dart';
import '../transport/frame.dart';
import '../transport/hello.dart';
import '../transport/packet_codec.dart';
import 'ble_link.dart';

enum SessionState { handshaking, ready, closed }

/// Protocol state for one link: fragmentation, authenticated handshake,
/// encryption, keep-alive and orderly shutdown. Upper layers only see whole,
/// decrypted, validated frames from an authenticated peer.
///
/// Handshake: HELLO ⇄ HELLO, then AUTH ⇄ AUTH (see [Handshake]). After that,
/// every frame in both directions is AES-GCM encrypted inside a `sealed`
/// frame; any plaintext frame other than HELLO/AUTH is a protocol violation.
class PeerSession {
  PeerSession({
    required this.link,
    required this.identity,
    this.expectedIdPrefix,
    this.admit,
    required this.onReady,
    required this.onFrame,
    required this.onClosed,
    this.onLatency,
    this._handshakeTimeout = BleConstants.handshakeTimeout,
    this._pingInterval = BleConstants.pingInterval,
    this._silenceTimeout = BleConstants.linkSilenceTimeout,
  });

  final BleLink link;
  final LocalIdentity identity;

  /// When we connected to a specific discovered device, the peer must be the
  /// device whose ID starts with this prefix.
  final String? expectedIdPrefix;

  /// Final say on an authenticated peer (blocked contacts, unknown devices).
  final Future<bool> Function(PeerInfo peer)? admit;

  final void Function(PeerSession session) onReady;
  final void Function(PeerSession session, Frame frame) onFrame;
  final void Function(PeerSession session) onClosed;
  final void Function(PeerSession session, int millis)? onLatency;

  final Duration _handshakeTimeout;
  final Duration _pingInterval;
  final Duration _silenceTimeout;

  final _fragmenter = Fragmenter();
  final _reassembler = Reassembler();
  final _ready = Completer<PeerInfo>();

  SessionState state = SessionState.handshaking;
  PeerInfo? peer;
  String? closeReason;

  /// The peer sent BYE: it chose to disconnect, so don't auto-reconnect.
  bool byeReceived = false;

  /// This side chose to disconnect (user action, tie-break, policy).
  bool closedLocally = false;

  // Handshake state
  EphemeralKeys? _ephemeral;
  Uint8List? _myHello;
  HelloData? _peerHello;
  Uint8List? _peerHelloBytes;
  Uint8List? _transcript;
  SessionCipher? _cipher;

  StreamSubscription<Uint8List>? _packetSub;
  Timer? _handshakeTimer;
  Timer? _pingTimer;
  DateTime _lastReceived = DateTime.now();
  Future<void> _sendTail = Future.value();
  Future<void> _incomingTail = Future.value();

  Future<PeerInfo> get ready => _ready.future;
  bool get isReady => state == SessionState.ready;

  void start() {
    _packetSub = link.packets.listen(_onPacket);
    link.closed.then((_) => close('link lost'));
    _handshakeTimer = Timer(_handshakeTimeout, () => close('handshake timeout'));
    _pingTimer = Timer.periodic(_pingInterval, (_) => _tick());
    // Sending our HELLO is the first step of the incoming chain, so every
    // received frame is processed after our handshake state exists.
    _enqueue(_sendHello);
  }

  // ------------------------------------------------------------- sending

  /// Sends an application frame, encrypted. Frames are sent one after
  /// another; packets of different frames never interleave.
  Future<void> send(Frame frame) {
    if (frame.type.isPlaintext) throw ArgumentError('use the handshake for ${frame.type}');
    return _serialized(() async {
      final cipher = _cipher;
      if (state != SessionState.ready || cipher == null) throw StateError('session not ready');
      await _transmit(Frame(FrameType.sealed, await cipher.seal(frame.encode())));
    });
  }

  Future<void> _sendPlain(Frame frame) => _serialized(() => _transmit(frame));

  Future<void> _serialized(Future<void> Function() action) {
    final result = _sendTail.then((_) {
      if (state == SessionState.closed) throw StateError('session closed');
      return action();
    });
    _sendTail = result.catchError((_) {});
    return result;
  }

  Future<void> _transmit(Frame frame) async {
    final maxPacket = await link.maxPacketSize();
    for (final packet in _fragmenter.split(frame.encode(), maxPacket)) {
      await link.sendPacket(packet).timeout(BleConstants.packetWriteTimeout);
    }
  }

  // ----------------------------------------------------------- receiving

  void _enqueue(Future<void> Function() step) {
    _incomingTail = _incomingTail.then((_) {
      if (state == SessionState.closed) return null;
      return step();
    }).catchError((Object e) {
      close('internal error: $e', disconnect: true);
    });
  }

  void _onPacket(Uint8List packet) {
    _lastReceived = DateTime.now();
    final Frame frame;
    try {
      final bytes = _reassembler.add(packet);
      if (bytes == null) return;
      frame = Frame.decode(bytes);
    } on PacketFormatException catch (e) {
      close('bad packet: ${e.message}', disconnect: true);
      return;
    } on FormatException catch (e) {
      close('bad frame: ${e.message}', disconnect: true);
      return;
    }
    _enqueue(() => _handleOuter(frame));
  }

  Future<void> _handleOuter(Frame frame) async {
    switch (frame.type) {
      case FrameType.hello:
        await _onHello(frame.body);
      case FrameType.auth:
        await _onAuth(frame.body);
      case FrameType.sealed:
        final cipher = _cipher;
        if (state != SessionState.ready || cipher == null) {
          await close('encrypted frame before handshake', disconnect: true);
          return;
        }
        final Frame inner;
        try {
          inner = Frame.decode(await cipher.open(frame.body));
        } on SealedFrameException catch (e) {
          await close('rejected encrypted frame: ${e.message}', disconnect: true);
          return;
        } on FormatException catch (e) {
          await close('bad inner frame: ${e.message}', disconnect: true);
          return;
        }
        _onInner(inner);
      default:
        await close('unencrypted ${frame.type.name} frame', disconnect: true);
    }
  }

  // ----------------------------------------------------------- handshake

  Future<void> _sendHello() async {
    final ephemeral = await EphemeralKeys.generate();
    _ephemeral = ephemeral;
    final hello = HelloCodec.encode(
      deviceId: identity.deviceId,
      displayName: identity.displayName,
      publicKey: identity.publicKey,
      ephemeralPublicKey: ephemeral.publicKey,
      nonce: ephemeral.nonce,
    );
    _myHello = hello;
    await _sendPlain(Frame(FrameType.hello, hello));
  }

  Future<void> _onHello(Uint8List body) async {
    if (_peerHello != null || state != SessionState.handshaking) {
      await close('unexpected hello', disconnect: true);
      return;
    }
    final HelloData hello;
    try {
      hello = HelloCodec.decode(body);
    } on IncompatibleVersionException catch (e) {
      await close(e.message, disconnect: true);
      return;
    } on FormatException catch (e) {
      await close('invalid hello: ${e.message}', disconnect: true);
      return;
    }
    final expected = expectedIdPrefix;
    if (expected != null && !hello.peer.id.startsWith(expected)) {
      await close('connected to a different device than expected', disconnect: true);
      return;
    }
    if (hello.peer.id == identity.deviceId) {
      await close('connected to itself', disconnect: true);
      return;
    }
    _peerHello = hello;
    _peerHelloBytes = Uint8List.fromList(body);

    // Our HELLO is always sent first in the chain, so both are known now.
    final transcript = Handshake.transcript(
      idA: identity.deviceId,
      helloA: _myHello!,
      idB: hello.peer.id,
      helloB: _peerHelloBytes!,
    );
    _transcript = transcript;
    try {
      _cipher = await Handshake.deriveCipher(
        myEphemeral: _ephemeral!.keyPair,
        peerEphemeral: hello.ephemeralPublicKey,
        transcript: transcript,
        iAmLow: identity.deviceId.compareTo(hello.peer.id) < 0,
      );
    } on HandshakeException catch (e) {
      await close('key agreement failed: ${e.message}', disconnect: true);
      return;
    }
    final signature = await identity.sign(Handshake.authMessage(identity.deviceId, transcript));
    await _sendPlain(Frame(FrameType.auth, Uint8List.fromList(signature)));
  }

  Future<void> _onAuth(Uint8List body) async {
    final hello = _peerHello;
    final transcript = _transcript;
    if (hello == null || transcript == null || state != SessionState.handshaking) {
      await close('auth out of order', disconnect: true);
      return;
    }
    final valid = await Handshake.verifyAuth(
      peerPublicKey: hello.peer.publicKey,
      peerId: hello.peer.id,
      transcript: transcript,
      signature: body,
    );
    if (!valid) {
      await close('identity proof failed', disconnect: true);
      return;
    }
    final check = admit;
    if (check != null && !await check(hello.peer)) {
      closedLocally = true;
      // Tell the peer not to reconnect, then hang up.
      state = SessionState.ready;
      try {
        await send(Frame(FrameType.bye)).timeout(const Duration(seconds: 2));
      } catch (_) {}
      await close('peer not allowed', disconnect: true);
      return;
    }
    _handshakeTimer?.cancel();
    peer = hello.peer;
    state = SessionState.ready;
    _ready.complete(hello.peer);
    onReady(this);
  }

  // -------------------------------------------------------- inner frames

  void _onInner(Frame frame) {
    switch (frame.type) {
      case FrameType.ping:
        send(Frame(FrameType.pong, frame.body)).catchError((_) {});
      case FrameType.pong:
        if (frame.body.length == 8) {
          final sentAt = ByteData.sublistView(frame.body).getInt64(0);
          final rtt = DateTime.now().millisecondsSinceEpoch - sentAt;
          if (rtt >= 0 && rtt < 60000) onLatency?.call(this, rtt);
        }
      case FrameType.bye:
        byeReceived = true;
        // The GATT client owns the connection, so it is the one to drop it.
        close('peer said bye', disconnect: link.isCentralRole);
      case FrameType.message ||
          FrameType.ack ||
          FrameType.profile ||
          FrameType.voiceRequest ||
          FrameType.voiceChunk ||
          FrameType.voiceDone:
        onFrame(this, frame);
      case FrameType.hello || FrameType.auth || FrameType.sealed:
        close('protocol violation: nested ${frame.type.name}', disconnect: true);
    }
  }

  void _tick() {
    if (state != SessionState.ready) return;
    if (DateTime.now().difference(_lastReceived) > _silenceTimeout) {
      close('peer silent', disconnect: true);
      return;
    }
    final body = ByteData(8)..setInt64(0, DateTime.now().millisecondsSinceEpoch);
    send(Frame(FrameType.ping, body.buffer.asUint8List())).catchError((_) {});
  }

  // ------------------------------------------------------------ shutdown

  /// Sends BYE (best effort) and closes, dropping the connection.
  Future<void> disconnectGracefully() async {
    closedLocally = true;
    if (state == SessionState.ready) {
      try {
        await send(Frame(FrameType.bye)).timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    await close('disconnected by user', disconnect: true);
  }

  /// Closes the session. With [disconnect], also drops the connection;
  /// otherwise only stops using it.
  Future<void> close(String reason, {bool disconnect = false}) async {
    if (state == SessionState.closed) return;
    state = SessionState.closed;
    closeReason = reason;
    debugPrint('PeerSession ${link.id} closed: $reason');
    _handshakeTimer?.cancel();
    _pingTimer?.cancel();
    await _packetSub?.cancel();
    if (!_ready.isCompleted) {
      _ready.completeError(StateError(reason));
      _ready.future.ignore();
    }
    if (disconnect) {
      await link.disconnect();
    } else {
      link.dispose();
    }
    onClosed(this);
  }
}
