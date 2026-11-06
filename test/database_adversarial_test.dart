import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/database/database_helper.dart';
import 'package:fuel_tracker/services/vehicle_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTransaction implements Transaction {
  final List<String> operations = [];
  bool failOnVehicleDelete = false;

  @override
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    operations.add('DELETE table=$table where="$where" args=$whereArgs');
    if (table == 'vehicles' && failOnVehicleDelete) {
      throw Exception('Simulated failure during vehicles delete');
    }
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDatabase implements Database {
  final MockTransaction mockTxn = MockTransaction();
  final List<String> rawQueries = [];
  final List<List<Object?>?> rawQueryArgs = [];
  int countResult = 0;
  bool transactionInvoked = false;

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    rawQueries.add(sql);
    rawQueryArgs.add(arguments);
    return [
      {'count': countResult}
    ];
  }

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action, {bool? exclusive}) async {
    transactionInvoked = true;
    return await action(mockTxn);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabase mockDb;
  late DatabaseHelper dbHelper;

  setUp(() {
    mockDb = MockDatabase();
    DatabaseHelper.setDatabaseForTesting(mockDb);
    dbHelper = DatabaseHelper.instance;
  });

  tearDown(() {
    DatabaseHelper.setDatabaseForTesting(null);
  });

  group('DatabaseHelper Adversarial Verification', () {
    test('getFuelRecordCountForVehicle uses parameterized query and never interpolates SQL', () async {
      mockDb.countResult = 42;
      final count = await dbHelper.getFuelRecordCountForVehicle(12345);

      expect(count, equals(42));
      expect(mockDb.rawQueries.length, equals(1));
      expect(
        mockDb.rawQueries.first,
        equals('SELECT COUNT(*) as count FROM fuel_records WHERE vehicleId = ?'),
        reason: 'SQL query must use ? placeholder to prevent SQL injection',
      );
      expect(mockDb.rawQueryArgs.first, equals([12345]));
    });

    test('getFuelRecordCountForVehicle returns 0 when result is 0 or empty', () async {
      mockDb.countResult = 0;
      final count = await dbHelper.getFuelRecordCountForVehicle(999);
      expect(count, equals(0));
    });

    test('deleteVehicleCascade executes in transaction and deletes child records before parent', () async {
      await dbHelper.deleteVehicleCascade(77);

      expect(mockDb.transactionInvoked, isTrue, reason: 'Must wrap deletion in db.transaction');
      expect(mockDb.mockTxn.operations.length, equals(2));
      
      // Strict deletion order: fuel_records FIRST, then vehicles SECOND
      expect(
        mockDb.mockTxn.operations[0],
        equals('DELETE table=fuel_records where="vehicleId = ?" args=[77]'),
        reason: 'fuel_records must be deleted first to prevent SQLITE_CONSTRAINT_FOREIGNKEY',
      );
      expect(
        mockDb.mockTxn.operations[1],
        equals('DELETE table=vehicles where="id = ?" args=[77]'),
        reason: 'vehicles must be deleted after child records',
      );
    });

    test('deleteVehicleCascade propagates exceptions to trigger transaction rollback', () async {
      mockDb.mockTxn.failOnVehicleDelete = true;

      expect(
        () async => await dbHelper.deleteVehicleCascade(77),
        throwsA(isA<Exception>()),
        reason: 'Exception must bubble up out of transaction callback so SQLite rolls back',
      );
    });
  });

  group('VehicleService Cascade & Default Vehicle Fallback', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'default_vehicle_id': 1,
      });
    });

    test('VehicleService.getRecordCountForVehicle delegates to DatabaseHelper', () async {
      mockDb.countResult = 5;
      final service = VehicleService(dbHelper: dbHelper);
      final count = await service.getRecordCountForVehicle(1);
      expect(count, equals(5));
    });
  });
}
