import 'package:flutter_app_saludable/core/auth/sqlite_pending_verification_store.dart';
import 'package:flutter_app_saludable/core/database/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/isolated_test_database.dart';

void main() {
  group('SqlitePendingVerificationStore', () {
    late DatabaseHelper db;
    late SqlitePendingVerificationStore store;

    setUp(() async {
      db = await openIsolatedTestDatabase();
      store = SqlitePendingVerificationStore(db);
    });

    tearDown(() async {
      await DatabaseHelper.resetForTest();
    });

    test('save normaliza y read devuelve email', () async {
      await store.save('  User@Mail.COM  ');
      expect(await store.read(), 'user@mail.com');
    });

    test('clear elimina el email', () async {
      await store.save('a@b.com');
      await store.clear();
      expect(await store.read(), isNull);
    });

    test('app_settings no contiene claves de OTP ni password', () async {
      await store.save('user@gmail.com');
      final database = await db.database;
      final rows = await database.query('app_settings');
      expect(rows.length, 1);
      expect(rows.first['key'], 'pending_verification_email');
      expect(rows.first['value'], 'user@gmail.com');
      final serialized = rows.toString();
      expect(serialized.contains('password'), isFalse);
      expect(serialized.contains('otp'), isFalse);
    });
  });
}
