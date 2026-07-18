import 'dart:io';

import 'package:flutter_app_saludable/core/database/database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Inicializa sqflite FFI y abre [DatabaseHelper] sobre un archivo temporal único.
///
/// Evita `database is locked` cuando varios archivos de test corren en paralelo
/// contra el mismo `nutrilife_club.db` de producción.
Future<DatabaseHelper> openIsolatedTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final path = p.join(
    Directory.systemTemp.path,
    'nutrilife_test_${pid}_${DateTime.now().microsecondsSinceEpoch}.db',
  );
  await DatabaseHelper.resetForTest(databasePath: path);
  return DatabaseHelper();
}

Future<void> closeIsolatedTestDatabase() async {
  await DatabaseHelper.resetForTest();
}
