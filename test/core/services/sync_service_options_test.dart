import 'package:flutter_app_saludable/core/pagination/paged_result.dart';
import 'package:flutter_app_saludable/core/auth/session_owner.dart';
import 'package:flutter_app_saludable/core/errors/app_exceptions.dart';
import 'package:flutter_app_saludable/core/services/connectivity_service.dart';
import 'package:flutter_app_saludable/core/services/sync_service.dart';
import 'package:flutter_app_saludable/data/datasources/remote/order_remote_data_source.dart';
import 'package:flutter_app_saludable/domain/entities/order_entity.dart';
import 'package:flutter_app_saludable/domain/entities/order_item_option.dart';
import 'package:flutter_app_saludable/domain/repositories/order_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnectivity implements ConnectivityService {
  @override
  Stream<bool> get connectionStream => const Stream.empty();

  @override
  Future<bool> checkConnection() async => true;

  @override
  void dispose() {}
}

class _MemRepo implements OrderRepository {
  OrderEntity? lastOrder;
  List<OrderItem>? lastItems;
  int markSyncedCalls = 0;
  int deleteCalls = 0;
  final List<OrderEntity> pending;

  _MemRepo(this.pending);

  @override
  Future<void> createOrder(OrderEntity order) async {}

  @override
  Future<List<OrderEntity>> getOrdersByUser(String userId) async => [];

  @override
  Future<List<OrderEntity>> getUnsyncedOrdersForUser(String userId) async =>
      pending;

  @override
  Future<int> countOrphanUnsyncedOrders() async => 0;

  @override
  Future<void> markAsSynced(String orderId) async {
    markSyncedCalls++;
  }

  @override
  Future<void> markOrdersAsSynced(List<String> orderIds) async {
    markSyncedCalls++;
  }

  @override
  Future<void> updateOrderStatus(String orderId, String status) async {}

  @override
  Future<void> deleteOrder(String orderId) async {
    deleteCalls++;
  }

  @override
  Future<void> deleteOrders(List<String> orderIds) async {
    deleteCalls++;
  }
}

class _CapturingRemote implements OrderRemoteDataSource {
  List<Map<String, dynamic>>? lastItemsPayload;
  Object? throwOnSend;

  @override
  Future<void> sendOrder(OrderEntity order, {required List<OrderItem> items, required List<OrderCombo> combos}) async {
    if (throwOnSend != null) throw throwOnSend!;
    lastItemsPayload = items
        .map((i) => {
              'productoId': int.parse(i.productId),
              'cantidad': i.quantity,
              'nota': i.note,
              'opciones': i.options.map((o) => o.toApiMap()).toList(),
              if (i.comboId != null) 'comboId': i.comboId,
            })
        .toList();
  }

  @override
  Future<void> createCounterSale({
    required int clubId,
    required String tipoPago,
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
  Future<PagedResult<Map<String, dynamic>>> getOrdersByClubPage(int clubId,
          {int page = 0,
          int size = 20,
          String? estado,
          String? desde,
          String? hasta}) =>
      throw UnimplementedError();

  @override
  Future<PagedResult<Map<String, dynamic>>> getOrdersBySocioPage(
          int membresiaId,
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
  test('sync envía opciones con ids/cantidad y marca synced en 201', () async {
    final order = OrderEntity(
      id: 'o1',
      userId: 'u1',
      clubId: 3,
      membresiaId: 10,
      status: 'pending',
      createdAt: DateTime.now(),
      items: [
        OrderItem(
          orderId: 'o1',
          productId: '7',
          quantity: 1,
          options: const [
            OrderItemOption(groupId: 3, optionId: 6, quantity: 1),
            OrderItemOption(groupId: 4, optionId: 9, quantity: 1),
          ],
        ),
        OrderItem(
          orderId: 'o1',
          productId: '7',
          quantity: 1,
          options: const [
            OrderItemOption(groupId: 3, optionId: 7, quantity: 1),
          ],
        ),
      ],
    );
    final repo = _MemRepo([order]);
    final remote = _CapturingRemote();
    final sync = SyncService(
      repo,
      _FakeConnectivity(),
      remote,
      SessionOwner()..setUserId('u1'),
    );

    await sync.syncNow();

    expect(remote.lastItemsPayload, hasLength(2));
    expect(remote.lastItemsPayload!.first['opciones'], [
      {'grupoId': 3, 'opcionId': 6, 'cantidad': 1},
      {'grupoId': 4, 'opcionId': 9, 'cantidad': 1},
    ]);
    expect(
      (remote.lastItemsPayload!.first['opciones'] as List).first,
      isNot(contains('grupoNombre')),
    );
    expect(repo.markSyncedCalls, 1);
    expect(repo.deleteCalls, 0);
    sync.dispose();
  });

  test('400 validación no marca synced ni borra pedido', () async {
    final order = OrderEntity(
      id: 'o2',
      userId: 'u1',
      clubId: 3,
      membresiaId: 10,
      status: 'pending',
      createdAt: DateTime.now(),
      items: [
        OrderItem(
          orderId: 'o2',
          productId: '7',
          quantity: 1,
          options: const [
            OrderItemOption(groupId: 3, optionId: 999, quantity: 1),
          ],
        ),
      ],
    );
    final repo = _MemRepo([order]);
    final remote = _CapturingRemote()
      ..throwOnSend = ValidationException('Opción inválida');
    final sync = SyncService(
      repo,
      _FakeConnectivity(),
      remote,
      SessionOwner()..setUserId('u1'),
    );

    await sync.syncNow();

    expect(repo.markSyncedCalls, 0);
    expect(repo.deleteCalls, 0);
    sync.dispose();
  });

  test('producto sin grupos envía opciones vacías', () async {
    final order = OrderEntity(
      id: 'o3',
      userId: 'u1',
      clubId: 3,
      membresiaId: 10,
      status: 'pending',
      createdAt: DateTime.now(),
      items: [
        OrderItem(orderId: 'o3', productId: '1', quantity: 2),
      ],
    );
    final repo = _MemRepo([order]);
    final remote = _CapturingRemote();
    final sync = SyncService(
      repo,
      _FakeConnectivity(),
      remote,
      SessionOwner()..setUserId('u1'),
    );

    await sync.syncNow();

    expect(remote.lastItemsPayload!.first['opciones'], isEmpty);
    expect(repo.markSyncedCalls, 1);
    sync.dispose();
  });
}
