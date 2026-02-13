import 'package:sqflite/sqflite.dart';
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
      print('[DEBUG LOCAL_REPO] getUser($id) - Found in DB:');
      print('[DEBUG LOCAL_REPO] Raw map: ${maps.first}');
      final user = User.fromMap(maps.first);
      print('[DEBUG LOCAL_REPO] Parsed User - phone: ${user.phone}');
      return user;
    }
    print('[DEBUG LOCAL_REPO] getUser($id) - NOT found in DB');
    return null;
  }

  @override
  Future<void> saveUser(User user) async {
    print('[DEBUG LOCAL_REPO] saveUser called:');
    print('[DEBUG LOCAL_REPO]   - id: ${user.id}');
    print('[DEBUG LOCAL_REPO]   - name: ${user.name}');
    print('[DEBUG LOCAL_REPO]   - phone: ${user.phone}');
    print('[DEBUG LOCAL_REPO]   - email: ${user.email}');
    
    final userMap = user.toMap();
    print('[DEBUG LOCAL_REPO] User.toMap() result:');
    print('[DEBUG LOCAL_REPO] Map: $userMap');
    print('[DEBUG LOCAL_REPO] phone key in map: ${userMap['phone']}');
    
    final db = await _dbHelper.database;
    await db.insert(
      'users',
      userMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    print('[DEBUG LOCAL_REPO] User saved to database successfully');
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
    final db = await _dbHelper.database;
    await db.delete('users'); // Borrar todo al cerrar sesión para mantener sesión única limpia
  }

  Future<User?> getCurrentUser() async {
    final db = await _dbHelper.database;
    final maps = await db.query('users', limit: 1);
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }
}
