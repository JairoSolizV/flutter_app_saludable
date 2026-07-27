import 'package:flutter_app_saludable/core/database/database_helper.dart';
import 'package:flutter_app_saludable/data/repositories/local_user_repository.dart';
import 'package:flutter_app_saludable/domain/entities/user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/isolated_test_database.dart';

void main() {
  late DatabaseHelper dbHelper;
  late LocalUserRepository repo;

  setUpAll(() async {
    dbHelper = await openIsolatedTestDatabase();
  });

  tearDownAll(() async {
    await closeIsolatedTestDatabase();
  });

  setUp(() async {
    final db = await dbHelper.database;
    await db.delete('users');
    repo = LocalUserRepository(dbHelper);
  });

  tearDown(() async {
    final db = await dbHelper.database;
    await db.delete('users');
  });

  group('getUser', () {
    test('devuelve null si no existe', () async {
      expect(await repo.getUser('1'), isNull);
    });

    test('devuelve el usuario guardado por id', () async {
      await repo.saveUser(User(
          id: '1',
          name: 'Ana',
          email: 'a@a.com',
          role: 'member',
          phone: '123'));
      final user = await repo.getUser('1');
      expect(user!.name, 'Ana');
      expect(user.phone, '123');
    });
  });

  group('saveUser', () {
    test('nunca persiste el token JWT', () async {
      await repo.saveUser(User(
        id: '1',
        name: 'Ana',
        email: 'a@a.com',
        role: 'member',
        token: 'secret-jwt',
      ));
      final db = await dbHelper.database;
      final rows = await db.query('users', where: 'id = ?', whereArgs: ['1']);
      expect(rows.single['token'], isNull);
    });

    test('reemplaza el usuario con el mismo id (conflict replace)', () async {
      await repo.saveUser(
          User(id: '1', name: 'Ana', email: 'a@a.com', role: 'member'));
      await repo.saveUser(
          User(id: '1', name: 'Ana 2', email: 'a2@a.com', role: 'host'));

      final db = await dbHelper.database;
      final rows = await db.query('users');
      expect(rows, hasLength(1));
      expect(rows.single['name'], 'Ana 2');
    });
  });

  group('updateUser', () {
    test('actualiza los campos del usuario existente', () async {
      await repo.saveUser(
          User(id: '1', name: 'Ana', email: 'a@a.com', role: 'member'));
      await repo.updateUser(User(
        id: '1',
        name: 'Ana Actualizada',
        email: 'nueva@a.com',
        role: 'member',
      ));

      final updated = await repo.getUser('1');
      expect(updated!.name, 'Ana Actualizada');
      expect(updated.email, 'nueva@a.com');
    });
  });

  group('logout', () {
    test('elimina todos los usuarios de la BD', () async {
      await repo.saveUser(
          User(id: '1', name: 'Ana', email: 'a@a.com', role: 'member'));
      await repo.saveUser(
          User(id: '2', name: 'Beto', email: 'b@a.com', role: 'host'));

      await repo.logout();

      final db = await dbHelper.database;
      expect(await db.query('users'), isEmpty);
    });
  });

  group('getCurrentUser', () {
    test('sin usuarios devuelve null', () async {
      expect(await repo.getCurrentUser(), isNull);
    });

    test('con usuarios devuelve el primero', () async {
      await repo.saveUser(
          User(id: '1', name: 'Ana', email: 'a@a.com', role: 'member'));
      final current = await repo.getCurrentUser();
      expect(current!.id, '1');
    });
  });

  group('readLegacyToken', () {
    test('sin usuarios devuelve null', () async {
      expect(await repo.readLegacyToken(), isNull);
    });

    test('con token legacy en columna token lo devuelve recortado', () async {
      final db = await dbHelper.database;
      await db.insert('users', {
        'id': '1',
        'name': 'Ana',
        'email': 'a@a.com',
        'role': 'member',
        'token': '  legacy-token  ',
      });
      expect(await repo.readLegacyToken(), 'legacy-token');
    });

    test('token vacío o en blanco devuelve null', () async {
      final db = await dbHelper.database;
      await db.insert('users', {
        'id': '1',
        'name': 'Ana',
        'email': 'a@a.com',
        'role': 'member',
        'token': '   ',
      });
      expect(await repo.readLegacyToken(), isNull);
    });

    test('token no String (null) devuelve null', () async {
      await repo.saveUser(
          User(id: '1', name: 'Ana', email: 'a@a.com', role: 'member'));
      expect(await repo.readLegacyToken(), isNull);
    });
  });

  group('clearPersistedToken', () {
    test('pone la columna token en null sin borrar el perfil', () async {
      final db = await dbHelper.database;
      await db.insert('users', {
        'id': '1',
        'name': 'Ana',
        'email': 'a@a.com',
        'role': 'member',
        'token': 'legacy',
      });

      await repo.clearPersistedToken();

      final rows = await db.query('users');
      expect(rows.single['token'], isNull);
      expect(rows.single['name'], 'Ana');
    });
  });
}
