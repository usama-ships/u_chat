import '../transport/frame.dart';
import 'peer_info.dart';

/// A frame received from an identified peer.
class IncomingFrame {
  const IncomingFrame(this.peer, this.frame);
  final PeerInfo peer;
  final Frame frame;
}
