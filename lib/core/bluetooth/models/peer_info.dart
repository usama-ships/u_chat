import 'dart:typed_data';

/// A peer identified through the HELLO exchange on a live link.
class PeerInfo {
  const PeerInfo({
    required this.id,
    required this.displayName,
    required this.publicKey,
    this.platform,
  });

  /// Device ID, verified to match [publicKey].
  final String id;
  final String displayName;

  /// Ed25519 identity public key (32 bytes).
  final Uint8List publicKey;
  final String? platform;

  String get idPrefix => id.substring(0, 8);

  PeerInfo copyWith({String? displayName}) => PeerInfo(
        id: id,
        displayName: displayName ?? this.displayName,
        publicKey: publicKey,
        platform: platform,
      );
}
