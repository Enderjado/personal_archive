import 'package:flutter_test/flutter_test.dart';
import 'package:personal_archive/infrastructure/sqlite/sqlite_place_repository.dart';
import 'package:personal_archive/infrastructure/sqlite/migrations/migration_runner.dart'
    show MigrationDb;
import 'sqlite_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SqlitePlaceRepository', () {
    late MigrationDb db;
    late SqlitePlaceRepository repo;

    setUp(() async {
      db = await createMigratedTestDb();
      repo = SqlitePlaceRepository(db);
    });

    test('getOrCreate returns new place with correct name and timestamps',
        () async {
      final place = await repo.getOrCreate('Banking');
      expect(place.name, 'Banking');
      expect(place.id, isNotEmpty);
      expect(place.description, isNull);
      expect(place.createdAt, isNotNull);
      expect(place.updatedAt, isNotNull);
    });

    test('getOrCreate with same name returns same place (reuse)', () async {
      final p1 = await repo.getOrCreate('University');
      final p2 = await repo.getOrCreate('University');
      expect(p2.id, p1.id);
      expect(p2.name, p1.name);
    });

    test('listAll returns places in stable order by name', () async {
      await repo.getOrCreate('Zebra');
      await repo.getOrCreate('Alpha');
      await repo.getOrCreate('Middle');

      final all = await repo.listAll();
      expect(all.length, 3);
      expect(all[0].name, 'Alpha');
      expect(all[1].name, 'Middle');
      expect(all[2].name, 'Zebra');
    });
  });
}
