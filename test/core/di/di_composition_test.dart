import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app_saludable/app.dart';
import 'package:flutter_app_saludable/core/api/api_client.dart';
import 'package:flutter_app_saludable/core/auth/session_expiration_handler.dart';
import 'package:flutter_app_saludable/core/auth/token_store.dart';
import 'package:flutter_app_saludable/core/database/database_helper.dart';
import 'package:flutter_app_saludable/core/di/app_dependencies.dart';
import 'package:flutter_app_saludable/core/services/connectivity_service.dart';
import 'package:flutter_app_saludable/core/services/sync_service.dart';
import 'package:flutter_app_saludable/data/datasources/remote/auth_remote_data_source.dart';
import 'package:flutter_app_saludable/data/datasources/remote/club_remote_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../helpers/test_app_dependencies.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDependencies deps;

  setUp(() async {
    deps = await buildTestDependencies();
  });

  tearDown(() {
    deps.dispose();
  });

  group('AppDependencies identidad', () {
    test('TokenStore único compartido con ApiClient y handler', () {
      expect(
          identical(deps.tokenStore, deps.apiClient.tokenStoreForTest), isTrue);
      expect(
        identical(
          deps.sessionExpirationHandler,
          deps.apiClient.sessionHandlerForTest,
        ),
        isTrue,
      );
    });

    test('remote data sources comparten el mismo Dio de ApiClient', () {
      final dio = deps.apiClient.client;
      expect(
        identical(
          (deps.authRemoteDataSource as AuthRemoteDataSourceImpl).clientForTest,
          dio,
        ),
        isTrue,
      );
    });

    test('DatabaseHelper factory es singleton', () {
      expect(identical(deps.dbHelper, DatabaseHelper()), isTrue);
    });

    test('SyncService y ConnectivityService son las del grafo', () {
      expect(deps.syncService, isA<SyncService>());
      expect(deps.connectivityService, isA<ConnectivityService>());
      expect(identical(deps.syncService, deps.syncService), isTrue);
    });
  });

  group('ExpandeApp Provider tree', () {
    testWidgets('resuelve servicios principales con la misma identidad',
        (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('ok')),
          ),
        ],
      );

      await tester.pumpWidget(
        ExpandeApp(dependencies: deps, router: router),
      );
      await tester.pump();

      final context = tester.element(find.text('ok'));
      expect(
        identical(context.read<TokenStore>(), deps.tokenStore),
        isTrue,
      );
      expect(
        identical(context.read<ApiClient>(), deps.apiClient),
        isTrue,
      );
      expect(
        identical(
          context.read<SessionExpirationHandler>(),
          deps.sessionExpirationHandler,
        ),
        isTrue,
      );
      expect(
        identical(context.read<SyncService>(), deps.syncService),
        isTrue,
      );
      expect(
        identical(
          context.read<ConnectivityService>(),
          deps.connectivityService,
        ),
        isTrue,
      );
      expect(
        identical(context.read<DatabaseHelper>(), deps.dbHelper),
        isTrue,
      );
      expect(
        identical(
          context.read<ClubRemoteDataSource>(),
          deps.clubRemoteDataSource,
        ),
        isTrue,
      );
      expect(
        identical(
          context.read<AppDependencies>(),
          deps,
        ),
        isTrue,
      );
    });

    testWidgets('rebuild con las mismas deps no duplica TokenStore',
        (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('ok')),
          ),
        ],
      );

      await tester.pumpWidget(
        ExpandeApp(dependencies: deps, router: router),
      );
      await tester.pump();
      final first = tester.element(find.text('ok')).read<TokenStore>();

      await tester.pumpWidget(
        ExpandeApp(dependencies: deps, router: router),
      );
      await tester.pump();
      final second = tester.element(find.text('ok')).read<TokenStore>();

      expect(identical(first, second), isTrue);
      expect(identical(first, deps.tokenStore), isTrue);
    });

    testWidgets('SessionBinding usa el mismo SessionExpirationHandler',
        (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('ok')),
          ),
        ],
      );

      await tester.pumpWidget(
        ExpandeApp(dependencies: deps, router: router),
      );
      await tester.pump();

      final handler =
          tester.element(find.text('ok')).read<SessionExpirationHandler>();
      expect(identical(handler, deps.sessionExpirationHandler), isTrue);
      expect(identical(handler, deps.apiClient.sessionHandlerForTest), isTrue);
    });
  });

  group('búsqueda estática DI', () {
    test('lib/main.dart no declara late final', () {
      final src = File('lib/main.dart').readAsStringSync();
      expect(src.contains('late final'), isFalse);
    });

    test('ningún archivo en lib/ importa main.dart', () {
      final lib = Directory('lib');
      final offenders = <String>[];
      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('lib/main.dart')) continue;
        final text = entity.readAsStringSync();
        if (text.contains("import '../../../main.dart'") ||
            text.contains("import '../../../../main.dart'") ||
            text.contains("package:flutter_app_saludable/main.dart")) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });
}
