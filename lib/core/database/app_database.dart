import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../data/models/delivery_status.dart';
import '../../data/models/message_type.dart';
import 'daos/conversation_dao.dart';
import 'daos/message_dao.dart';
import 'daos/peer_dao.dart';
import 'daos/settings_dao.dart';
import 'tables/app_settings_table.dart';
import 'tables/conversations_table.dart';
import 'tables/messages_table.dart';
import 'tables/peers_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Peers, Conversations, Messages, AppSettings],
  daos: [PeerDao, ConversationDao, MessageDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  /// Pass an [executor] in tests (e.g. `NativeDatabase.memory()`).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() => driftDatabase(name: 'u_chat');
}
