import 'package:drift/drift.dart';

/// Simple key/value store for local preferences (e.g. display name).
/// Secrets never go here; they live in secure storage.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
