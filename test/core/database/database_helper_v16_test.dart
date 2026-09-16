import 'dart:io';

import 'package:flutter_app_saludable/core/database/database_helper.dart';
import 'package:flutter_app_saludable/data/repositories/local_user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseHelper.resetForTest();
  });

  test('instalación nueva v16 incluye columna codigo_sorteo', () async {
    final path = p.join(
      Directory.systemTemp.path,
      'raffle_v16_new_${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await DatabaseHelper.resetForTest(databasePath: path);
    final helper = DatabaseHelper();
    final db = await helper.database;

    final info = await db.rawQuery('PRAGMA table_info(users)');
    final columns = info.map((r) => r['name']).toSet();
    expect(columns, contains('codigo_sorteo'));

    final version = await db.getVersion();
    expect(version, 16);
  });

  test('upgrade v15 -> v16 agrega codigo_sorteo y conserva datos', () async {
    final path = p.join(
      Directory.systemTemp.path,
      'raffle_v15_to_v16_${DateTime.now().microsecondsSinceEpoch}.db',
    );

    // Crear BD en esquema v15 (users sin codigo_sorteo).
    final v15 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 15,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE users(
              id TEXT PRIMARY KEY,
              name TEXT,
              email TEXT,
              role TEXT,
              token TEXT,
              phone TEXT,
              photo_url TEXT,
              birth_date TEXT,
              social_media TEXT,
              is_synced INTEGER DEFAULT 1
            )
          ''');
          await db.execute('''
            CREATE TABLE products(
              id TEXT PRIMARY KEY,
              name TEXT,
              description TEXT,
              price REAL,
              puntosValor INTEGER DEFAULT 0,
              category TEXT,
              image_url TEXT,
              hubId INTEGER,
              clubCreadorId INTEGER,
              tipo TEXT,
              estadoAprobacion TEXT,
              active INTEGER DEFAULT 1,
              disponible INTEGER DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE orders(
              id TEXT PRIMARY KEY,
              user_id TEXT,
              club_id INTEGER,
              membresia_id INTEGER,
              tipo_consumo TEXT,
              observaciones TEXT,
              status TEXT,
              created_at TEXT,
              is_synced INTEGER DEFAULT 0,
              sync_status TEXT NOT NULL DEFAULT 'PENDING',
              sync_error_code TEXT,
              sync_error_message TEXT,
              tiempoEstimadoMinutos INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE order_items(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              order_id TEXT,
              product_id TEXT,
              quantity INTEGER,
              note TEXT,
              combo_id INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE order_item_options(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              order_item_id INTEGER NOT NULL,
              group_id INTEGER,
              group_name TEXT,
              option_id INTEGER,
              option_name TEXT,
              price_delta REAL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE pending_email_verification(
              id INTEGER PRIMARY KEY CHECK (id = 1),
              email TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );

    await v15.insert('users', {
      'id': '7',
      'name': 'Legacy User',
      'email': 'legacy@test.com',
      'role': 'member',
      'phone': '70000000',
    });
    await v15.close();

    await DatabaseHelper.resetForTest(databasePath: path);
    final helper = DatabaseHelper();
    final db = await helper.database;

    expect(await db.getVersion(), 16);

    final info = await db.rawQuery('PRAGMA table_info(users)');
    expect(info.map((r) => r['name']), contains('codigo_sorteo'));

    final rows = await db.query('users', where: 'id = ?', whereArgs: ['7']);
    expect(rows, hasLength(1));
    expect(rows.single['name'], 'Legacy User');
    expect(rows.single['codigo_sorteo'], isNull);

    final repo = LocalUserRepository(helper);
    final loaded = await repo.getUser('7');
    expect(loaded!.codigoSorteo, isNull);

    await repo.saveUser(loaded.copyWith(codigoSorteo: '4827'));
    final synced = await repo.getUser('7');
    expect(synced!.codigoSorteo, '4827');
    expect(synced.name, 'Legacy User');
  });
}
