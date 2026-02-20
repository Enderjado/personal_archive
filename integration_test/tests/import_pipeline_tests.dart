import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart';
import '../helpers/test_database.dart';
import '../helpers/test_storage.dart';

void main() {
  late Directory storageDir;
  late sqlite.Database db;
  late MigrationDb migrationDb;

  group('Import Pipeline Integration Tests', () {
    setUp(() async {
      storageDir = await setupTestStorage();
      final result = await setupTestDatabase();
      db = result.db;
      migrationDb = result.migrationDb;
    });

    tearDown(() async {
      await cleanupTestStorage(storageDir);
      db.dispose();
    });

    testWidgets('Verify Test Environment Setup', (WidgetTester tester) async {
      // Verify storage exists
      expect(storageDir.existsSync(), isTrue);
      
      // Verify DB has migrations applied
      final result = db.select('SELECT count(*) as count FROM schema_migrations');
      // We expect at least 1 migration (init_core_schema)
      expect(result.first['count'], greaterThan(0)); 
    });
  });
}
