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
      logDebug('[DEBUG LOCAL_REPO] getUser($id) - Found in DB:');
      logDebug('[DEBUG LOCAL_REPO] Raw map: ${maps.first}');
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
    logDebug('[DEBUG LOCAL_REPO]   - token: ${user.token != null ? "PRESENTE (${user.token!.length} chars)" : "NULL"}');
    if (user.token != null && user.token!.length > 20) {
      logDebug('[DEBUG LOCAL_REPO]   - token preview: ${user.token!.substring(0, 20)}...');
    }
    
    final userMap = user.toMap();
    logDebug('[DEBUG LOCAL_REPO] User.toMap() result:');
    logDebug('[DEBUG LOCAL_REPO] Map keys: ${userMap.keys.toList()}');
    logDebug('[DEBUG LOCAL_REPO] token in map: ${userMap['token'] != null ? "PRESENTE" : "NULL"}');
    logDebug('[DEBUG LOCAL_REPO] phone key in map: ${userMap['phone']}');
    
    final db = await _dbHelper.database;
    await db.insert(
      'users',
      userMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    logDebug('[DEBUG LOCAL_REPO] User saved to database successfully');
    
    // Verificar que se guardó correctamente
    final savedUser = await getCurrentUser();
    if (savedUser != null) {
      logDebug('[DEBUG LOCAL_REPO] Verificación post-guardado:');
      logDebug('[DEBUG LOCAL_REPO]   - token guardado: ${savedUser.token != null ? "PRESENTE" : "NULL"}');
    }
  }

  @override
  Future<void> updateUser(User user) async {
    final db = await _dbHelper.database;
    await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  @override
  Future<void> logout() async {
    logDebug('[DEBUG LOCAL_REPO] logout() - Limpiando usuarios de BD');
    final db = await _dbHelper.database;
    final count = await db.delete('users'); // Borrar todo al cerrar sesión para mantener sesión única limpia
    logDebug('[DEBUG LOCAL_REPO] logout() - Usuarios eliminados: $count');
    
    // Verificar que se limpió
    final remaining = await db.query('users');
    logDebug('[DEBUG LOCAL_REPO] logout() - Usuarios restantes en BD: ${remaining.length}');
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
      logDebug('[DEBUG LOCAL_REPO]   - token: ${user.token != null ? "PRESENTE (${user.token!.length} chars)" : "NULL"}');
      if (user.token != null && user.token!.length > 20) {
        logDebug('[DEBUG LOCAL_REPO]   - token preview: ${user.token!.substring(0, 20)}...');
      }
      return user;
    }
    logDebug('[DEBUG LOCAL_REPO] getCurrentUser() - NO se encontró usuario en BD');
    return null;
  }
}
