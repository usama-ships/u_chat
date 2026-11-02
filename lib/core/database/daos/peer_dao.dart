import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/peers_table.dart';

part 'peer_dao.g.dart';

@DriftAccessor(tables: [Peers])
class PeerDao extends DatabaseAccessor<AppDatabase> with _$PeerDaoMixin {
  PeerDao(super.attachedDatabase);

  /// Inserts a newly seen peer, or refreshes name / last-seen / platform of a
  /// known one without touching `firstSeenAt`, trust or block state.
  Future<void> upsertSeen({
    required String id,
    required String displayName,
    String? platform,
    Uint8List? identityPublicKey,
    required int now,
  }) {
    return into(peers).insert(
      PeersCompanion.insert(
        id: id,
        displayName: displayName,
        platform: Value(platform),
        identityPublicKey: Value(identityPublicKey),
        firstSeenAt: now,
        lastSeenAt: now,
      ),
      onConflict: DoUpdate(
        (old) => PeersCompanion(
          displayName: Value(displayName),
          lastSeenAt: Value(now),
          platform: platform == null ? const Value.absent() : Value(platform),
          // The ID is derived from the key, so a known ID always has the same
          // key; storing it again is safe.
          identityPublicKey:
              identityPublicKey == null ? const Value.absent() : Value(identityPublicKey),
        ),
      ),
    );
  }

  Future<Peer?> findById(String id) =>
      (select(peers)..where((p) => p.id.equals(id))).getSingleOrNull();

  Stream<Peer?> watchById(String id) =>
      (select(peers)..where((p) => p.id.equals(id))).watchSingleOrNull();

  Future<void> updateDisplayName(String id, String displayName) =>
      (update(peers)..where((p) => p.id.equals(id)))
          .write(PeersCompanion(displayName: Value(displayName)));

  Future<void> setVerified(String id, bool verified) =>
      (update(peers)..where((p) => p.id.equals(id))).write(PeersCompanion(verified: Value(verified)));

  Future<void> setBlocked(String id, bool blocked) =>
      (update(peers)..where((p) => p.id.equals(id))).write(PeersCompanion(blocked: Value(blocked)));
}
