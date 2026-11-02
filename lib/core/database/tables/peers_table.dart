import 'package:drift/drift.dart';

/// Remote devices we have connected to. Timestamps are Unix epoch milliseconds.
class Peers extends Table {
  /// Device ID derived from the peer's identity public key.
  TextColumn get id => text()();

  TextColumn get displayName => text().withLength(min: 1, max: 64)();

  /// Ed25519 identity key pinned on first authenticated contact (TOFU).
  /// Null until the Phase 6 handshake has run with this peer.
  BlobColumn get identityPublicKey => blob().nullable()();

  /// True once the user compared safety numbers with this peer.
  BoolColumn get verified => boolean().withDefault(const Constant(false))();

  /// Free-form device info reported by the peer (e.g. "android").
  TextColumn get platform => text().nullable()();

  IntColumn get firstSeenAt => integer()();
  IntColumn get lastSeenAt => integer()();

  BoolColumn get blocked => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
