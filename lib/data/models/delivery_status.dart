/// Lifecycle of a message. Stored by name (not index) so reordering the enum
/// never corrupts existing rows.
enum DeliveryStatus {
  /// Outgoing: stored locally, waiting for a ready Bluetooth link.
  pending,

  /// Outgoing: fragments are being written to the peer.
  sending,

  /// Outgoing: every fragment was accepted by the peer's GATT server.
  /// This does NOT mean the peer app processed it; see [delivered].
  sent,

  /// Outgoing: the peer app stored the message and returned an ACK.
  delivered,

  /// Outgoing: no ACK after all retries. Can be retried manually.
  failed,

  /// Incoming: received from a peer and stored.
  received;

  bool get isTerminalSuccess => this == delivered || this == received;
}
