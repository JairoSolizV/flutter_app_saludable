import 'package:flutter_app_saludable/core/auth/secure_token_store.dart';
import 'package:flutter_app_saludable/core/auth/session_expiration_handler.dart';
import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/core/services/connectivity_service.dart';
import 'package:flutter_app_saludable/core/services/sync_service.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_app_saludable/domain/repositories/order_repository.dart';
import 'package:flutter_app_saludable/presentation/providers/counter_sale_provider.dart';
import 'package:flutter_app_saludable/presentation/providers/order_provider.dart';
import 'package:flutter_app_saludable/data/datasources/remote/product_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/product.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dart:io';

import 'in_memory_secure_storage_gateway.dart';

class _SqlOrderRepo implements OrderRepository {
  _SqlOrderRepo(this._db);
  final Database _db;

  @override
  Future<void> createOrder(OrderEntity order) async {
    final owner = order.userId.trim();
    if (owner.isEmpty) {
      throw ArgumentError('sin userId');
    }
    await _db.transaction((txn) async {
      await txn.insert('orders', order.toMap());
      for (final item in order.items) {
        await txn.insert('order_items', item.toMap());
      }
    });
  }

  @override
  Future<List<OrderEntity>> getOrdersByUser(String userId) async {
    final rows = await _db.query(
      'orders',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return rows.map((r) => OrderEntity.fromMap(r)).toList();
  }

  @override
  Future<List<OrderEntity>> getUnsyncedOrdersForUser(String userId) async {
    final owner = userId.trim();
    if (owner.isEmpty) return [];
    final res = await _db.query(
      'orders',
      where:
          'is_synced = ? AND user_id = ? AND user_id IS NOT NULL AND TRIM(user_id) != ?',
      whereArgs: [0, owner, ''],
    );
    return res.map((r) => OrderEntity.fromMap(r)).toList();
  }

  @override
  Future<int> countOrphanUnsyncedOrders() async {
    final res = await _db.rawQuery('''
      SELECT COUNT(*) AS c FROM orders
      WHERE is_synced = 0
        AND (user_id IS NULL OR TRIM(user_id) = '')
    ''');
    final value = res.first['c'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  @override
  Future<void> markAsSynced(String orderId) async {
    await markOrdersAsSynced([orderId]);
  }

  @override
  Future<void> markOrdersAsSynced(List<String> orderIds) async {
    for (final id in orderIds) {
      await _db.update(
        'orders',
        {'is_synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _db.update(
      'orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    await deleteOrders([orderId]);
  }

  @override
  Future<void> deleteOrders(List<String> orderIds) async {
    await _db.transaction((txn) async {
      for (final orderId in orderIds) {
        await txn
            .delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
        await txn.delete('orders', where: 'id = ?', whereArgs: [orderId]);
      }
    });
  }
}

class _FakeRemoteOrders implements OrderRemoteDataSource {
  final List<String> sentIds = [];
  Object? sendError;

  @override
  Future<void> sendOrder(OrderEntity order, List<OrderItem> items) async {
    if (sendError != null) throw sendError!;
    sentIds.add(order.id);
  }

  @override
  Future<void> createCounterSale({
    required int clubId,
    String? socioCodigo,
    String? tipoConsumo,
    String? observaciones,
    required List<Map<String, dynamic>> items,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getOrdersByClub(int clubId) async => [];

  @override
  Future<List<Map<String, dynamic>>> getOrdersBySocio(int membresiaId) async =>
      [];

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersByClubPage(
    int clubId, {
    int page = 0,
    int size = 20,
    String? estado,
    String? desde,
    String? hasta,
  }) async =>
      PagedResult<Map<String, dynamic>>.empty(page: page, size: size);

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersBySocioPage(
    int membresiaId, {
    int page = 0,
    int size = 20,
    String? estado,
    String? desde,
    String? hasta,
  }) async =>
      PagedResult<Map<String, dynamic>>.empty(page: page, size: size);

  @override
  Future<void> updateOrderStatus(int pedidoId, String newStatus,
      {int? estimatedTime}) async {}

  @override
  Future<List<Map<String, dynamic>>> getAllOrders() async => [];
}

class _NoopProducts implements ProductRemoteDataSource {
  @override
  Future<void> createProduct(Product product, int clubId) async {}

  @override
  Future<void> createProductProposal({
    required int hubId,
    required String nombre,
    required String descripcion,
    required String ingredientes,
    required int puntosValor,
    required double precio,
    String? imagenUrl,
    List<ProductOptionGroup>? optionGroups,
  }) async {}

  @override
  Future<void> deleteProduct(String id) async {}

  @override
  Future<List<Product>> getAvailableProductsByClub(int clubId) async => [];

  @override
  Future<List<Product>> getProducts(
          {required int hubId, required int clubId}) async =>
      [];

  @override
  Future<void> toggleProductAvailability(int clubId, String productId) async {}

  @override
  Future<Product> updateProduct(Product product) async => product;

  @override
  Future<Product?> updateClubSalePrice({
    required int clubId,
    required String productId,
    required double? precioVenta,
  }) async =>
      null;

  @override
  Future<Product> reenviarProducto(String productId) async => Product(
        id: productId,
        name: '',
        description: '',
        tipo: 'LOCAL',
        estadoAprobacion: 'PENDIENTE',
      );

  @override
  Future<String> uploadProductImage(File imageFile) async => '';
}

OrderEntity _order({
  required String id,
  required String userId,
  bool synced = false,
}) {
  return OrderEntity(
    id: id,
    userId: userId,
    clubId: 1,
    membresiaId: 1,
    status: 'pending',
    createdAt: DateTime.now(),
    isSynced: synced,
    items: const [],
  );
}

ConnectivityService _online() => ConnectivityService.forTest(
      checkConnection: () async => true,
    );

void main() {
  late Database db;
  late _SqlOrderRepo repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
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
              note TEXT
            )
          ''');
        },
      ),
    );
    repo = _SqlOrderRepo(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Aislamiento pedidos offline (SQL real)', () {
    test('pedidos de A no se devuelven al consultar pendientes de B', () async {
      await repo.createOrder(_order(id: 'a1', userId: 'A'));
      await repo.createOrder(_order(id: 'b1', userId: 'B'));

      final forB = await repo.getUnsyncedOrdersForUser('B');
      expect(forB.map((o) => o.id), ['b1']);
    });

    test('pedido huérfano/null no se asigna a B ni se sincroniza', () async {
      await db.insert('orders', {
        'id': 'orphan1',
        'user_id': null,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      });
      await db.insert('orders', {
        'id': 'orphan2',
        'user_id': '',
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      });

      expect(await repo.countOrphanUnsyncedOrders(), 2);
      expect(await repo.getUnsyncedOrdersForUser('B'), isEmpty);
    });

    test('pedidos de A permanecen tras logout (sin borrar SQLite)', () async {
      await repo.createOrder(_order(id: 'a1', userId: 'A'));
      expect(await repo.getUnsyncedOrdersForUser('B'), isEmpty);
      expect(
          (await repo.getUnsyncedOrdersForUser('A')).map((o) => o.id), ['a1']);
    });

    test('cuando A vuelve, recupera pendientes', () async {
      await repo.createOrder(_order(id: 'a1', userId: 'A'));
      await repo.createOrder(_order(id: 'a2', userId: 'A'));
      expect(await repo.getUnsyncedOrdersForUser('A'), hasLength(2));
    });

    test('confirmación fallida no marca como sincronizado', () async {
      await repo.createOrder(_order(id: 'a1', userId: 'A'));
      final owner = SessionOwner()..setUserId('A');
      final remote = _FakeRemoteOrders()..sendError = Exception('network');
      final sync = SyncService(repo, _online(), remote, owner);

      await sync.syncNow();
      expect(remote.sentIds, isEmpty);
      expect(
          (await repo.getUnsyncedOrdersForUser('A')).map((o) => o.id), ['a1']);
    });
  });

  group('SyncService aislamiento', () {
    test('sync como B no envía pedidos de A', () async {
      await repo.createOrder(_order(id: 'a1', userId: 'A'));
      await repo.createOrder(_order(id: 'b1', userId: 'B'));
      final owner = SessionOwner()..setUserId('B');
      final remote = _FakeRemoteOrders();
      final sync = SyncService(repo, _online(), remote, owner);

      await sync.syncNow();
      expect(remote.sentIds, ['b1']);
      expect(await repo.getUnsyncedOrdersForUser('A'), hasLength(1));
      expect(await repo.getUnsyncedOrdersForUser('B'), isEmpty);
    });

    test('sync sin sesión no envía nada', () async {
      await repo.createOrder(_order(id: 'a1', userId: 'A'));
      final remote = _FakeRemoteOrders();
      final sync = SyncService(repo, _online(), remote, SessionOwner());

      await sync.syncNow();
      expect(remote.sentIds, isEmpty);
    });

    test('expiración durante sync detiene nuevos envíos', () async {
      await repo.createOrder(_order(id: 'a1', userId: 'A'));
      await repo.createOrder(_order(id: 'a2', userId: 'A'));

      final storage = InMemorySecureStorageGateway();
      final tokenStore = SecureTokenStore(storage: storage);
      await tokenStore.initialize();
      await tokenStore.saveToken('jwt');
      final handler = SessionExpirationHandler(tokenStore: tokenStore);
      handler.bind(
        clearLocalSession: () async {},
        onSessionExpiredUi: () async {},
      );
      handler.markLoggedOut();

      final owner = SessionOwner()..setUserId('A');
      final remote = _FakeRemoteOrders();
      final sync = SyncService(
        repo,
        _online(),
        remote,
        owner,
        sessionExpirationHandler: handler,
      );

      await sync.syncNow();
      expect(remote.sentIds, isEmpty);
    });
  });

  group('Limpieza providers en memoria', () {
    test('OrderProvider.clearSessionState limpia lista, no SQLite', () async {
      await repo.createOrder(_order(id: 'a1', userId: 'A'));
      final owner = SessionOwner()..setUserId('A');
      final connectivity = _online();
      final sync = SyncService(repo, connectivity, _FakeRemoteOrders(), owner);
      final provider = OrderProvider(repo, connectivity, sync);
      await provider.loadOrders('A');
      expect(provider.orders, hasLength(1));

      await provider.clearSessionState();
      expect(provider.orders, isEmpty);
      expect(await repo.getUnsyncedOrdersForUser('A'), hasLength(1));
    });

    test('CounterSaleProvider.clearSessionState limpia carrito', () async {
      final p = CounterSaleProvider(_NoopProducts(), _FakeRemoteOrders());
      p.socioCodigo = 'X';
      await p.clearSessionState();
      expect(p.cartItems, isEmpty);
      expect(p.socioCodigo, '');
      expect(p.clubId, isNull);
    });
  });
}
