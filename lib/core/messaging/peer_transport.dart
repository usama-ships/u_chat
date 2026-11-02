import '../bluetooth/models/incoming_frame.dart';
import '../bluetooth/models/peer_info.dart';
import '../bluetooth/transport/frame.dart';

/// What the messaging layer needs from the connection layer.
/// Implemented by `BluetoothService`; faked in tests.
abstract interface class PeerTransport {
  /// A peer finished the HELLO exchange and can receive frames.
  Stream<PeerInfo> get peerReady;

  /// A previously ready peer is no longer connected.
  Stream<String> get peerLost;

  /// Validated frames (message / ack) from ready peers.
  Stream<IncomingFrame> get frames;

  bool isPeerConnected(String peerId);

  /// Throws if the peer isn't connected or the link fails mid-frame.
  Future<void> sendFrame(String peerId, Frame frame);

  /// Best effort: look for the peer nearby and connect.
  Future<bool> connectToKnownPeer(String peerId);
}
