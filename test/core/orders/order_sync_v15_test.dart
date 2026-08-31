import 'dart:io';

import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/database/database_helper.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/orders/order_offline_messages.dart';
import 'package:flutter_app_saludable/core/orders/order_sync_backend_codes.dart';
import 'package:flutter_app_saludable/core/orders/order_sync_failure_classifier.dart';
import 'package:flutter_app_saludable/core/orders/order_sync_status.dart';
import 'package:flutter_app_saludable/core/orders/order_submit_outcome.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/core/services/connectivity_service.dart';
import 'package:flutter_app_saludable/core/services/sync_service.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/data/repositories/local_order_repository.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_app_saludable/domain/repositories/order_repository.dart';
import 'package:flutter_app_saludable/presentation/providers/order_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> _openV14Db(String path) async {
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 14,
      onCreate: (db, v) async {
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
            group_order INTEGER DEFAULT 0,
            option_id INTEGER,
            option_name TEXT,
            option_order INTEGER DEFAULT 0,
            quantity INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE order_combos(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id TEXT NOT NULL,
            combo_id INTEGER NOT NULL,
            combo_name TEXT,
            quantity INTEGER NOT NULL DEFAULT 1,
            price_snapshot REAL DEFAULT 0,
            points_snapshot INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE order_combo_components(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_combo_id INTEGER NOT NULL,
            product_id TEXT NOT NULL,
            product_name TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE order_combo_component_options(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            component_id INTEGER NOT NULL,
            group_id INTEGER,
            group_name TEXT,
            group_order INTEGER DEFAULT 0,
            option_id INTEGER,
            option_name TEXT,
            option_order INTEGER DEFAULT 0,
            quantity INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE products(id TEXT PRIMARY KEY, name TEXT)
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 15) {
          await db.execute(
            "ALTER TABLE orders ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'PENDING'",
          );
          await db.execute('ALTER TABLE orders ADD COLUMN sync_error_code TEXT');
          await db.execute('ALTER TABLE orders ADD COLUMN sync_error_message TEXT');
          await db.execute(
            "UPDATE orders SET sync_status = 'SYNCED' WHERE is_synced = 1",
          );
          await db.execute(
            "UPDATE orders SET sync_status = 'PENDING' WHERE is_synced = 0",
          );
        }
      },
    ),
  );
}

OrderEntity _order({
  required String id,
  required String userId,
  bool synced = false,
  OrderSyncStatus? syncStatus,
}) {
  return OrderEntity(
    id: id,
    userId: userId,
    clubId: 3,
    membresiaId: 10,
    status: 'pending',
    createdAt: DateTime(2026, 8, 30),
    isSynced: synced,
    syncStatus: syncStatus,
    items: [OrderItem(orderId: id, productId: '7', quantity: 1)],
  );
}

class _TrackingRepo implements OrderRepository {
  _TrackingRepo(this.inner);

  final LocalOrderRepository inner;
  int deleteCalls = 0;
  int markFailedCalls = 0;
  String? lastFailedCode;

  @override
  Future<void> createOrder(OrderEntity order) => inner.createOrder(order);

  @override
  Future<List<OrderEntity>> getOrdersByUser(String userId) =>
      inner.getOrdersByUser(userId);

  @override
  Future<List<OrderEntity>> getUnsyncedOrdersForUser(String userId) =>
      inner.getUnsyncedOrdersForUser(userId);

  @override
  Future<List<OrderEntity>> getLocalUnsentOrdersForUser(String userId) =>
      inner.getLocalUnsentOrdersForUser(userId);

  @override
  Future<int> countOrphanUnsyncedOrders() =>
      inner.countOrphanUnsyncedOrders();

  @override
  Future<void> markAsSynced(String orderId) => inner.markAsSynced(orderId);

  @override
  Future<void> markOrdersAsSynced(List<String> orderIds) =>
      inner.markOrdersAsSynced(orderIds);

  @override
  Future<void> markSyncFailed(
    String orderId, {
    String? errorCode,
    String? errorMessage,
  }) async {
    markFailedCalls++;
    lastFailedCode = errorCode;
    return inner.markSyncFailed(
      orderId,
      errorCode: errorCode,
      errorMessage: errorMessage,
    );
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) =>
      inner.updateOrderStatus(orderId, status);

  @override
  Future<void> deleteOrder(String orderId) async {
    deleteCalls++;
    return inner.deleteOrder(orderId);
  }

  @override
  Future<void> deleteOrders(List<String> orderIds) => inner.deleteOrders(orderIds);
}

class _RemoteStub implements OrderRemoteDataSource {
  Object? error;

  @override
  Future<void> sendOrder(
    OrderEntity order, {
    required List<OrderItem> items,
    required List<OrderCombo> combos,
  }) async {
    if (error != null) throw error!;
  }

  @override
  Future<void> createCounterSale({
    required int clubId,
    required String tipoPago,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> combos = const [],
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getOrdersBySocio(int membresiaId) async =>
      [];

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersByClubPage(int clubId,
          {int page = 0,
          int size = 20,
          String? estado,
          String? desde,
          String? hasta}) =>
      throw UnimplementedError();

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersBySocioPage(int membresiaId,
          {int page = 0,
          int size = 20,
          String? estado,
          String? desde,
          String? hasta}) =>
      throw UnimplementedError();

  @override
  Future<void> updateOrderStatus(int pedidoId, String newStatus,
          {int? estimatedTime}) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getAllOrders() async => [];
}

class _MemOrderRepo implements OrderRepository {
  final List<OrderEntity> stored = [];

  @override
  Future<void> createOrder(OrderEntity order) async => stored.add(order);

  @override
  Future<List<OrderEntity>> getOrdersByUser(String userId) async =>
      stored.where((o) => o.userId == userId).toList();

  @override
  Future<List<OrderEntity>> getUnsyncedOrdersForUser(String userId) async =>
      stored
          .where(
            (o) =>
                o.userId == userId &&
                !o.isSynced &&
                o.syncStatus == OrderSyncStatus.pending,
          )
          .toList();

  @override
  Future<List<OrderEntity>> getLocalUnsentOrdersForUser(String userId) async =>
      stored
          .where(
            (o) =>
                o.userId == userId &&
                !o.isSynced &&
                (o.syncStatus == OrderSyncStatus.pending ||
                    o.syncStatus == OrderSyncStatus.failedPermanent),
          )
          .toList();

  @override
  Future<int> countOrphanUnsyncedOrders() async => 0;

  @override
  Future<void> markAsSynced(String orderId) async {
    final i = stored.indexWhere((o) => o.id == orderId);
    if (i < 0) return;
    final o = stored[i];
    stored[i] = OrderEntity(
      id: o.id,
      userId: o.userId,
      clubId: o.clubId,
      membresiaId: o.membresiaId,
      tipoConsumo: o.tipoConsumo,
      observaciones: o.observaciones,
      status: o.status,
      createdAt: o.createdAt,
      isSynced: true,
      syncStatus: OrderSyncStatus.synced,
      items: o.items,
      combos: o.combos,
    );
  }

  @override
  Future<void> markOrdersAsSynced(List<String> orderIds) async {
    for (final id in orderIds) {
      await markAsSynced(id);
    }
  }

  @override
  Future<void> markSyncFailed(
    String orderId, {
    String? errorCode,
    String? errorMessage,
  }) async {
    final i = stored.indexWhere((o) => o.id == orderId);
    if (i < 0) return;
    final o = stored[i];
    stored[i] = OrderEntity(
      id: o.id,
      userId: o.userId,
      clubId: o.clubId,
      membresiaId: o.membresiaId,
      tipoConsumo: o.tipoConsumo,
      observaciones: o.observaciones,
      status: o.status,
      createdAt: o.createdAt,
      isSynced: false,
      syncStatus: OrderSyncStatus.failedPermanent,
      syncErrorCode: errorCode,
      syncErrorMessage: errorMessage,
      items: o.items,
      combos: o.combos,
    );
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {}

  @override
  Future<void> deleteOrder(String orderId) async {
    stored.removeWhere((o) => o.id == orderId);
  }

  @override
  Future<void> deleteOrders(List<String> orderIds) async {
    stored.removeWhere((o) => orderIds.contains(o.id));
  }
}

class _FailingRemote implements OrderRemoteDataSource {
  _FailingRemote(this.error);
  final Object error;

  @override
  Future<void> sendOrder(
    OrderEntity order, {
    required List<OrderItem> items,
    required List<OrderCombo> combos,
  }) async {
    throw error;
  }

  @override
  Future<void> createCounterSale({
    required int clubId,
    required String tipoPago,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> combos = const [],
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getOrdersBySocio(int membresiaId) async =>
      [];

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersByClubPage(int clubId,
          {int page = 0,
          int size = 20,
          String? estado,
          String? desde,
          String? hasta}) =>
      throw UnimplementedError();

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersBySocioPage(int membresiaId,
          {int page = 0,
          int size = 20,
          String? estado,
          String? desde,
          String? hasta}) =>
      throw UnimplementedError();

  @override
  Future<void> updateOrderStatus(int pedidoId, String newStatus,
          {int? estimatedTime}) =>
      throw UnimplementedError();

  @override
  Future<List<Map<String, dynamic>>> getAllOrders() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('migración v14→v15', () {
    late String dbPath;

    setUp(() async {
      dbPath = p.join(
        Directory.systemTemp.path,
        'ord_sync_v15_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      final db = await _openV14Db(dbPath);
      await db.insert('orders', {
        'id': 'uuid-pending-1',
        'user_id': 'u1',
        'club_id': 3,
        'membresia_id': 10,
        'status': 'pending',
        'created_at': DateTime(2026, 8, 30).toIso8601String(),
        'is_synced': 0,
      });
      await db.insert('orders', {
        'id': 'uuid-synced-2',
        'user_id': 'u1',
        'club_id': 3,
        'membresia_id': 10,
        'status': 'pending',
        'created_at': DateTime(2026, 8, 30).toIso8601String(),
        'is_synced': 1,
      });
      await db.close();
      await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 15,
          onUpgrade: (db, oldV, newV) async {
            if (oldV < 15) {
              await db.execute(
                "ALTER TABLE orders ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'PENDING'",
              );
              await db.execute(
                  'ALTER TABLE orders ADD COLUMN sync_error_code TEXT');
              await db.execute(
                  'ALTER TABLE orders ADD COLUMN sync_error_message TEXT');
              await db.execute(
                "UPDATE orders SET sync_status = 'SYNCED' WHERE is_synced = 1",
              );
              await db.execute(
                "UPDATE orders SET sync_status = 'PENDING' WHERE is_synced = 0",
              );
            }
          },
        ),
      );
    });

    tearDown(() async {
      try {
        await File(dbPath).delete();
      } catch (_) {}
    });

    test('pending → PENDING y synced → SYNCED preservando UUID', () async {
      final db = await databaseFactoryFfi.openDatabase(dbPath);
      final rows = await db.query('orders', orderBy: 'id');
      expect(rows, hasLength(2));

      final pending = rows.firstWhere((r) => r['id'] == 'uuid-pending-1');
      final synced = rows.firstWhere((r) => r['id'] == 'uuid-synced-2');
      expect(pending['sync_status'], 'PENDING');
      expect(synced['sync_status'], 'SYNCED');
      await db.close();
    });
  });

  group('LocalOrderRepository sync_status', () {
    late DatabaseHelper dbHelper;
    late LocalOrderRepository repo;
    late String path;

    setUp(() async {
      path = p.join(
        Directory.systemTemp.path,
        'ord_sync_repo_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      await DatabaseHelper.resetForTest(databasePath: path);
      dbHelper = DatabaseHelper();
      repo = LocalOrderRepository(dbHelper);
    });

    tearDown(() async {
      await DatabaseHelper.resetForTest();
      try {
        await File(path).delete();
      } catch (_) {}
    });

    test('nuevo pedido → PENDING', () async {
      await repo.createOrder(_order(id: 'new-1', userId: 'u1'));
      final unsent = await repo.getLocalUnsentOrdersForUser('u1');
      expect(unsent.single.syncStatus, OrderSyncStatus.pending);
    });

    test('FAILED no en cola sync pero sí en unsent', () async {
      await repo.createOrder(_order(id: 'fail-1', userId: 'u1'));
      await repo.markSyncFailed(
        'fail-1',
        errorCode: OrderSyncBackendCodes.membershipInactive,
        errorMessage: 'x',
      );
      expect(await repo.getUnsyncedOrdersForUser('u1'), isEmpty);
      final unsent = await repo.getLocalUnsentOrdersForUser('u1');
      expect(unsent.single.syncStatus, OrderSyncStatus.failedPermanent);
    });

    test('markAsSynced limpia errores', () async {
      await repo.createOrder(_order(id: 'ok-1', userId: 'u1'));
      await repo.markSyncFailed('ok-1', errorCode: 'X');
      await repo.markAsSynced('ok-1');
      final all = await repo.getOrdersByUser('u1');
      expect(all.single.isSynced, isTrue);
      expect(all.single.syncStatus, OrderSyncStatus.synced);
      expect(all.single.syncErrorCode, isNull);
    });

    test('aislamiento user A/B', () async {
      await repo.createOrder(_order(id: 'a-fail', userId: 'A'));
      await repo.markSyncFailed('a-fail', errorCode: 'X');
      expect(await repo.getLocalUnsentOrdersForUser('B'), isEmpty);
      expect(await repo.getLocalUnsentOrdersForUser('A'), hasLength(1));
    });

    test('delete elimina failed', () async {
      await repo.createOrder(_order(id: 'del-1', userId: 'u1'));
      await repo.markSyncFailed('del-1');
      await repo.deleteOrder('del-1');
      expect(await repo.getLocalUnsentOrdersForUser('u1'), isEmpty);
    });
  });

  group('OrderSyncFailureClassifier', () {
    void expectRetryable(Object error) {
      expect(
        OrderSyncFailureClassifier.classify(error).action,
        OrderSyncFailureAction.retryable,
      );
    }

    void expectPermanent(Object error, {String? code}) {
      final c = OrderSyncFailureClassifier.classify(error);
      expect(c.action, OrderSyncFailureAction.permanent);
      if (code != null) expect(c.errorCode, code);
    }

    test('retryable: network, timeout, 500, 429, 409 CONFLICT', () {
      expectRetryable(NetworkException('x'));
      expectRetryable(TimeoutException('x'));
      expectRetryable(ServerException('x', statusCode: 500));
      expectRetryable(RateLimitException('x'));
      expectRetryable(
        ConflictException('x', statusCode: 409, code: OrderSyncBackendCodes.conflict),
      );
    });

    test('permanent: códigos BE y fallbacks HTTP', () {
      for (final code in [
        OrderSyncBackendCodes.membershipInactive,
        OrderSyncBackendCodes.membershipUnavailable,
        OrderSyncBackendCodes.clubInactive,
        OrderSyncBackendCodes.clubUnavailable,
        OrderSyncBackendCodes.productUnavailable,
        OrderSyncBackendCodes.comboUnavailable,
        OrderSyncBackendCodes.optionInvalid,
        OrderSyncBackendCodes.invalidQuantity,
        OrderSyncBackendCodes.invalidRequest,
        OrderSyncBackendCodes.clientIdConflict,
      ]) {
        expectPermanent(
          ValidationException('x', statusCode: 400, code: code),
          code: code,
        );
      }
      expectPermanent(ValidationException('x', statusCode: 400));
      expectPermanent(NotFoundException('x', statusCode: 404));
      expectPermanent(ConflictException('x', statusCode: 409));
    });
  });

  group('SyncService + classifier', () {
    late String path;
    late _TrackingRepo repo;
    late SessionOwner owner;

    setUp(() async {
      path = p.join(
        Directory.systemTemp.path,
        'ord_sync_svc_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      await DatabaseHelper.resetForTest(databasePath: path);
      repo = _TrackingRepo(LocalOrderRepository(DatabaseHelper()));
      owner = SessionOwner()..setUserId('u1');
    });

    tearDown(() async {
      await DatabaseHelper.resetForTest();
      try {
        await File(path).delete();
      } catch (_) {}
    });

    Future<void> syncWithError(Object error, String orderId) async {
      await repo.createOrder(_order(id: orderId, userId: 'u1'));
      final remote = _RemoteStub()..error = error;
      final sync = SyncService(
        repo,
        ConnectivityService.forTest(checkConnection: () async => true),
        remote,
        owner,
      );
      await sync.syncNow();
      sync.dispose();
    }

    test('membresía inactiva marca failed y NO deleteOrder', () async {
      await syncWithError(
        ValidationException(
          'x',
          statusCode: 400,
          code: OrderSyncBackendCodes.membershipInactive,
        ),
        'mem-inactive',
      );
      expect(repo.deleteCalls, 0);
      expect(repo.markFailedCalls, 1);
      expect(await repo.getUnsyncedOrdersForUser('u1'), isEmpty);
      expect(await repo.getLocalUnsentOrdersForUser('u1'), hasLength(1));
    });

    test('timeout mantiene PENDING', () async {
      await syncWithError(TimeoutException('x'), 'retry-timeout');
      expect(repo.markFailedCalls, 0);
      expect(await repo.getUnsyncedOrdersForUser('u1'), hasLength(1));
    });
  });

  group('OrderProvider localFailed', () {
    test('FAILED_PERMANENT nunca produce remoteSynced', () async {
      final repo = _MemOrderRepo();
      final owner = SessionOwner()..setUserId('u1');
      final remote = _FailingRemote(
        ValidationException(
          'x',
          statusCode: 400,
          code: OrderSyncBackendCodes.clubInactive,
        ),
      );
      final provider = OrderProvider(
        repo,
        ConnectivityService.forTest(checkConnection: () async => true),
        SyncService(
          repo,
          ConnectivityService.forTest(checkConnection: () async => true),
          remote,
          owner,
        ),
      );

      final outcome = await provider.createOrder(_order(id: 'fail-out', userId: 'u1'));

      expect(outcome, OrderSubmitOutcome.localFailed);
      expect(outcome, isNot(OrderSubmitOutcome.remoteSynced));
    });
  });

  group('OrderOfflineMessages', () {
    test('mensajes seguros por código', () {
      expect(
        OrderOfflineMessages.failedOrderMessage(
          OrderSyncBackendCodes.membershipInactive,
        ),
        contains('membresía'),
      );
      expect(
        OrderOfflineMessages.failedOrderMessage(
          OrderSyncBackendCodes.productUnavailable,
        ),
        contains('producto'),
      );
    });
  });
}
