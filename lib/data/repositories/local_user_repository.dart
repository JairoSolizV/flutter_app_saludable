import 'package:sqflite/sqflite.dart';
import 'package:flutter_app_saludable/core/utils/app_logger.dart';
import '../../core/database/database_helper.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';

class LocalUserRepository implements UserRepository {
  final DatabaseHelper _dbHelper;

  LocalUserRepository(this._dbHelper);

  @override
  Future<User?> getUser(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      logDebug('[DEBUG LOCAL_REPO] getUser($id) - Found in DB');
      final user = User.fromMap(maps.first);
      logDebug('[DEBUG LOCAL_REPO] Parsed User - phone: ${user.phone}');
      return user;
    }
    logDebug('[DEBUG LOCAL_REPO] getUser($id) - NOT found in DB');
    return null;
  }

  @override
  Future<void> saveUser(User user) async {
    logDebug('[DEBUG LOCAL_REPO] saveUser called:');
    logDebug('[DEBUG LOCAL_REPO]   - id: ${user.id}');
    logDebug('[DEBUG LOCAL_REPO]   - name: ${user.name}');
    logDebug('[DEBUG LOCAL_REPO]   - phone: ${user.phone}');
    logDebug('[DEBUG LOCAL_REPO]   - email: ${user.email}');

    // Persistir solo perfil; JWT nunca a SQLite.
    final userMap = user.withoutToken().toMap();
    logDebug('[DEBUG LOCAL_REPO] User.toMap() keys: ${userMap.keys.toList()}');

    final db = await _dbHelper.database;
    await db.insert(
      'users',
      userMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    logDebug('[DEBUG LOCAL_REPO] User profile saved (sin JWT en SQLite)');
  }

  @override
  Future<void> updateUser(User user) async {
    final db = await _dbHelper.database;
    await db.update(
      'users',
      user.withoutToken().toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  @override
  Future<void> logout() async {
    logDebug('[DEBUG LOCAL_REPO] logout() - Limpiando usuarios de BD');
    final db = await _dbHelper.database;
    final count = await db.delete('users');
    logDebug('[DEBUG LOCAL_REPO] logout() - Usuarios eliminados: $count');

    final remaining = await db.query('users');
    logDebug(
      '[DEBUG LOCAL_REPO] logout() - Usuarios restantes en BD: ${remaining.length}',
    );
  }

  @override
  Future<User?> getCurrentUser() async {
    final db = await _dbHelper.database;
    final maps = await db.query('users', limit: 1);
    if (maps.isNotEmpty) {
      final user = User.fromMap(maps.first);
      logDebug('[DEBUG LOCAL_REPO] getCurrentUser() - Usuario encontrado:');
      logDebug('[DEBUG LOCAL_REPO]   - id: ${user.id}');
      logDebug('[DEBUG LOCAL_REPO]   - email: ${user.email}');
      return user;
    }
    logDebug(
        '[DEBUG LOCAL_REPO] getCurrentUser() - NO se encontró usuario en BD');
    return null;
  }

  @override
  Future<String?> readLegacyToken() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'users',
      columns: ['token'],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final raw = maps.first['token'];
    if (raw is! String) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  @override
  Future<void> clearPersistedToken() async {
    final db = await _dbHelper.database;
    await db.update('users', {'token': null});
    logDebug('[DEBUG LOCAL_REPO] Columna token SQLite puesta en null');
  }
}
