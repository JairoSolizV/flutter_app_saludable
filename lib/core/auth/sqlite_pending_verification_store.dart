import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../utils/validators.dart';
import 'pending_verification_store.dart';

/// Email pendiente de OTP en SQLite (no es secreto; no va al Keychain).
class SqlitePendingVerificationStore implements PendingVerificationStore {
  SqlitePendingVerificationStore(this._dbHelper);

  static const table = 'app_settings';
  static const key = 'pending_verification_email';

  final DatabaseHelper _dbHelper;

  @override
  Future<void> save(String email) async {
    final normalized = Validators.normalizeEmail(email);
    if (normalized.isEmpty) return;

    final db = await _dbHelper.database;
    await db.insert(
      table,
      {'key': key, 'value': normalized},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<String?> read() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      table,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'];
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  @override
  Future<void> clear() async {
    final db = await _dbHelper.database;
    await db.delete(
      table,
      where: 'key = ?',
      whereArgs: [key],
    );
  }
}

/// Implementación en memoria para tests unitarios.
class InMemoryPendingVerificationStore implements PendingVerificationStore {
  String? _email;

  @override
  Future<void> clear() async {
    _email = null;
  }

  @override
  Future<String?> read() async => _email;

  @override
  Future<void> save(String email) async {
    _email = Validators.normalizeEmail(email);
  }
}
